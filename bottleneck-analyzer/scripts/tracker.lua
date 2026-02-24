local data_store = require("scripts.data-store")

local tracker = {}

local TRACKED_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true,
}

--- Add an entity to tracking.
function tracker.track_entity(entity)
  if not entity or not entity.valid then return end
  if not TRACKED_TYPES[entity.type] then return end
  storage.tracked_entities[entity.unit_number] = entity
end

--- Remove an entity from tracking.
function tracker.untrack_entity(entity)
  if not entity or not entity.valid then return end
  storage.tracked_entities[entity.unit_number] = nil
end

--- Scan all surfaces for existing crafting machines and track them.
function tracker.scan_surfaces()
  storage.tracked_entities = {}
  for _, surface in pairs(game.surfaces) do
    for etype, _ in pairs(TRACKED_TYPES) do
      local entities = surface.find_entities_filtered({ type = etype })
      for _, entity in pairs(entities) do
        if entity.valid and entity.unit_number then
          storage.tracked_entities[entity.unit_number] = entity
        end
      end
    end
  end
end

--- Determine which ingredients are short for a machine.
-- Returns a table of ingredient names that are below required amounts, or nil if none.
local function get_short_ingredients(entity, recipe)
  local short = {}
  local found_any = false

  for _, ingredient in pairs(recipe.ingredients) do
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

  if found_any then
    return short
  end
  return nil
end

--- Get the recipe for an entity, handling furnaces specially.
local function get_entity_recipe(entity)
  if entity.type == "furnace" then
    local prev = entity.previous_recipe
    if prev then
      return prev.recipe
    end
    return entity.get_recipe()
  end
  return entity.get_recipe()
end

--- Run one sampling pass across all tracked entities.
function tracker.sample(tick)
  -- Aggregate data: recipe_name -> { total = N, waiting = { [ingredient] = count } }
  local aggregated = {}

  for unit_number, entity in pairs(storage.tracked_entities) do
    if not entity.valid then
      storage.tracked_entities[unit_number] = nil
    else
      local recipe = get_entity_recipe(entity)
      if recipe then
        local recipe_name = recipe.name
        if not aggregated[recipe_name] then
          aggregated[recipe_name] = {
            total = 0,
            waiting = {},
            recipe = recipe,
          }
        end
        local agg = aggregated[recipe_name]
        agg.total = agg.total + 1

        local status = entity.status
        if status == defines.entity_status.item_ingredient_shortage
            or status == defines.entity_status.fluid_ingredient_shortage
            or status == defines.entity_status.no_ingredients then
          local short = get_short_ingredients(entity, recipe)
          if short then
            for ingredient_name, _ in pairs(short) do
              agg.waiting[ingredient_name] = (agg.waiting[ingredient_name] or 0) + 1
            end
          end
        end
      end
    end
  end

  -- Write aggregated samples into ring buffers
  for recipe_name, agg in pairs(aggregated) do
    data_store.record_sample(recipe_name, tick, agg.total, agg.waiting)
  end
end

--- Get the sample interval in ticks from mod settings.
function tracker.get_sample_ticks()
  local rate_seconds = settings.global["bottleneck-analyzer-sample-rate"].value
  local ticks = math.floor(rate_seconds * 60)
  if ticks < 1 then ticks = 1 end
  return ticks
end

return tracker
