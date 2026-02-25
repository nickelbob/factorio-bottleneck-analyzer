local data_store = require("scripts.data-store")

local tracker = {}

local TRACKED_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true,
}

local MAX_BATCH_SIZE = 500
local RECHECK_COUNT = 50  -- random recipe cache re-checks per sweep

-- Transient state (not saved, rebuilt each sweep)
local current_aggregation = {}
local sweep_entity_count = 0
local sweep_invalid_count = 0
local sweep_waiting_count = 0
local sweep_cache_hits = 0
local sweep_cache_misses = 0
local sweep_start_tick = 0

-- Profiling
local profile_enabled = true
local profile_count = 0
local PROFILE_INTERVAL = 5
local p_total_sweep, p_validity_sweep, p_status_sweep, p_ingredients_sweep, p_datastore_sweep

------------------------------------------------------------------------
-- Recipe helpers
------------------------------------------------------------------------

local function get_entity_recipe_safe(entity)
  if entity.type == "furnace" then
    local prev = entity.previous_recipe
    if prev then return prev.recipe end
    return entity.get_recipe()
  end
  return entity.get_recipe()
end

------------------------------------------------------------------------
-- Entity list management
------------------------------------------------------------------------

function tracker.init_storage()
  if not storage.tracked_entities then storage.tracked_entities = {} end
  if not storage.entity_list then storage.entity_list = {} end
  if not storage.entity_list_index then storage.entity_list_index = {} end
  if not storage.recipe_cache then storage.recipe_cache = {} end
  if not storage.sample_cursor then storage.sample_cursor = 1 end
end

local function add_to_entity_list(unit_number)
  local list = storage.entity_list
  local idx = #list + 1
  list[idx] = unit_number
  storage.entity_list_index[unit_number] = idx
end

local function remove_from_entity_list(unit_number)
  local index = storage.entity_list_index[unit_number]
  if not index then return end
  local list = storage.entity_list
  local last = #list
  if index ~= last then
    local last_un = list[last]
    list[index] = last_un
    storage.entity_list_index[last_un] = index
  end
  list[last] = nil
  storage.entity_list_index[unit_number] = nil
end

function tracker.track_entity(entity)
  if not entity or not entity.valid then return end
  if not TRACKED_TYPES[entity.type] then return end
  local un = entity.unit_number
  if storage.tracked_entities[un] then return end
  storage.tracked_entities[un] = entity
  add_to_entity_list(un)
  local recipe = get_entity_recipe_safe(entity)
  storage.recipe_cache[un] = recipe and recipe.name or false
end

function tracker.untrack_entity(entity)
  if not entity then return end
  local un = entity.unit_number
  if not un then return end
  storage.tracked_entities[un] = nil
  remove_from_entity_list(un)
  storage.recipe_cache[un] = nil
end

function tracker.scan_surfaces()
  storage.tracked_entities = {}
  storage.entity_list = {}
  storage.entity_list_index = {}
  storage.recipe_cache = {}
  storage.sample_cursor = 1
  for _, surface in pairs(game.surfaces) do
    for etype, _ in pairs(TRACKED_TYPES) do
      local entities = surface.find_entities_filtered({ type = etype })
      for _, entity in pairs(entities) do
        if entity.valid and entity.unit_number then
          local un = entity.unit_number
          storage.tracked_entities[un] = entity
          add_to_entity_list(un)
          local recipe = get_entity_recipe_safe(entity)
          storage.recipe_cache[un] = recipe and recipe.name or false
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- Ingredient checking
------------------------------------------------------------------------

local function get_short_ingredients(entity, recipe_proto)
  local short = {}
  local found_any = false

  for _, ingredient in pairs(recipe_proto.ingredients) do
    if ingredient.type == "item" then
      local input_inv = entity.get_inventory(defines.inventory.crafter_input)
      if input_inv then
        local count = input_inv.get_item_count(ingredient.name)
        if count < ingredient.amount then
          short[ingredient.name] = true
          found_any = true
        end
      end
    elseif ingredient.type == "fluid" then
      local fluid_count = entity.get_fluid_count(ingredient.name)
      if fluid_count < ingredient.amount then
        short[ingredient.name] = true
        found_any = true
      end
    end
  end

  return found_any and short or nil
end

------------------------------------------------------------------------
-- Profiling
------------------------------------------------------------------------

function tracker.enable_profiling(enabled)
  profile_enabled = enabled
  profile_count = 0
  log("Bottleneck Analyzer: profiling " .. (enabled and "ENABLED" or "DISABLED"))
end

local function reset_sweep_profilers()
  if not profile_enabled then return end
  p_total_sweep = game.create_profiler()
  p_validity_sweep = game.create_profiler()
  p_validity_sweep.stop()
  p_status_sweep = game.create_profiler()
  p_status_sweep.stop()
  p_ingredients_sweep = game.create_profiler()
  p_ingredients_sweep.stop()
  p_datastore_sweep = game.create_profiler()
  p_datastore_sweep.stop()
end

local function write_sweep_profile(tick)
  if not profile_enabled then return end
  p_total_sweep.stop()
  profile_count = profile_count + 1
  if profile_count % PROFILE_INTERVAL ~= 0 then return end

  local header = "=== Bottleneck Analyzer Sweep (tick " .. tick .. ") ===\n"
      .. "  Entities: " .. sweep_entity_count .. " processed, "
      .. sweep_invalid_count .. " invalid, "
      .. sweep_waiting_count .. " waiting\n"
      .. "  Cache: " .. sweep_cache_hits .. " hits, "
      .. sweep_cache_misses .. " misses\n"
      .. "  Sweep duration: " .. (tick - sweep_start_tick) .. " ticks\n"
  helpers.write_file("bottleneck-analyzer-profile.txt", header, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", {"", "  TOTAL:        ", p_total_sweep, "\n"}, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", {"", "  validity:     ", p_validity_sweep, "\n"}, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", {"", "  status:       ", p_status_sweep, "\n"}, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", {"", "  ingredients:  ", p_ingredients_sweep, "\n"}, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", {"", "  data_store:   ", p_datastore_sweep, "\n"}, true)
  helpers.write_file("bottleneck-analyzer-profile.txt", "================================================\n", true)
end

------------------------------------------------------------------------
-- Chunked sampling
------------------------------------------------------------------------

local function get_batch_size()
  local rate_seconds = settings.global["bottleneck-analyzer-sample-rate"].value
  local total_ticks = math.floor(rate_seconds * 60)
  if total_ticks < 1 then total_ticks = 1 end
  local entity_count = #storage.entity_list
  if entity_count == 0 then return 0 end
  local batch = math.ceil(entity_count / total_ticks)
  if batch > MAX_BATCH_SIZE then batch = MAX_BATCH_SIZE end
  if batch < 1 then batch = 1 end
  return batch
end

local function do_staleness_recheck()
  local list = storage.entity_list
  local count = #list
  if count == 0 then return end
  local checks = math.min(RECHECK_COUNT, count)
  for _ = 1, checks do
    local idx = math.random(1, count)
    local un = list[idx]
    local entity = storage.tracked_entities[un]
    if entity and entity.valid then
      local recipe = get_entity_recipe_safe(entity)
      storage.recipe_cache[un] = recipe and recipe.name or false
    end
  end
end

function tracker.sample_chunk(tick)
  if not settings.global["bottleneck-analyzer-enabled"].value then return end

  local list = storage.entity_list
  local total = #list
  if total == 0 then return end

  local cursor = storage.sample_cursor
  local profiling = profile_enabled

  -- Start of new sweep?
  if cursor == 1 then
    current_aggregation = {}
    sweep_entity_count = 0
    sweep_invalid_count = 0
    sweep_waiting_count = 0
    sweep_cache_hits = 0
    sweep_cache_misses = 0
    sweep_start_tick = tick
    if profiling then reset_sweep_profilers() end
  end

  if profiling then p_total_sweep.restart() end

  local batch_size = get_batch_size()
  local end_idx = cursor + batch_size - 1
  if end_idx > total then end_idx = total end

  local to_remove = {}

  for i = cursor, end_idx do
    local un = list[i]
    local entity = storage.tracked_entities[un]
    sweep_entity_count = sweep_entity_count + 1

    if profiling then p_validity_sweep.restart() end
    local valid = entity and entity.valid
    if profiling then p_validity_sweep.stop() end

    if not valid then
      to_remove[#to_remove + 1] = un
      sweep_invalid_count = sweep_invalid_count + 1
    else
      local recipe_name = storage.recipe_cache[un]
      if recipe_name == nil then
        local recipe = get_entity_recipe_safe(entity)
        recipe_name = recipe and recipe.name or false
        storage.recipe_cache[un] = recipe_name
        sweep_cache_misses = sweep_cache_misses + 1
      else
        sweep_cache_hits = sweep_cache_hits + 1
      end

      if recipe_name then
        local recipe_proto = prototypes.recipe[recipe_name]
        if recipe_proto then
          if not current_aggregation[recipe_name] then
            current_aggregation[recipe_name] = { total = 0, waiting = {} }
          end
          local agg = current_aggregation[recipe_name]
          agg.total = agg.total + 1

          if profiling then p_status_sweep.restart() end
          local status = entity.status
          if profiling then p_status_sweep.stop() end

          if status == defines.entity_status.item_ingredient_shortage
              or status == defines.entity_status.fluid_ingredient_shortage
              or status == defines.entity_status.no_ingredients then
            sweep_waiting_count = sweep_waiting_count + 1

            if profiling then p_ingredients_sweep.restart() end
            local short = get_short_ingredients(entity, recipe_proto)
            if profiling then p_ingredients_sweep.stop() end

            if short then
              for ingredient_name, _ in pairs(short) do
                agg.waiting[ingredient_name] = (agg.waiting[ingredient_name] or 0) + 1
              end
            end
          end
        end
      end
    end
  end

  if profiling then p_total_sweep.stop() end

  -- Clean up invalid entities (after iteration to avoid messing with indices)
  for _, un in ipairs(to_remove) do
    storage.tracked_entities[un] = nil
    remove_from_entity_list(un)
    storage.recipe_cache[un] = nil
  end

  -- Advance cursor
  cursor = end_idx + 1
  if cursor > #storage.entity_list then
    -- Sweep complete: write aggregated data to ring buffers
    if profiling then p_datastore_sweep.restart() end
    for recipe_name, agg in pairs(current_aggregation) do
      local waiting = next(agg.waiting) and agg.waiting or nil
      data_store.record_sample(recipe_name, tick, agg.total, waiting)
    end
    if profiling then p_datastore_sweep.stop() end

    write_sweep_profile(tick)

    -- Staleness recheck
    do_staleness_recheck()

    -- Reset for next sweep
    current_aggregation = {}
    cursor = 1
  end

  storage.sample_cursor = cursor
end

--- Get the sample interval in ticks from mod settings.
function tracker.get_sample_ticks()
  local rate_seconds = settings.global["bottleneck-analyzer-sample-rate"].value
  local ticks = math.floor(rate_seconds * 60)
  if ticks < 1 then ticks = 1 end
  return ticks
end

return tracker
