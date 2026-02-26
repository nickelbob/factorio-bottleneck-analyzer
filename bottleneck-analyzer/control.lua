local tracker = require("scripts.tracker")
local data_store = require("scripts.data-store")
local gui = require("scripts.gui")

-- Entity type filters for build/destroy events
local ENTITY_FILTERS = {
  { filter = "type", type = "assembling-machine" },
  { filter = "type", type = "furnace" },
}

--- Full initialization.
local function full_init()
  data_store.init()
  gui.init()
  tracker.init_storage()
  tracker.scan_surfaces()
end

-- Register unconditionally so it persists across all save/load scenarios
script.on_nth_tick(1, function(event)
  tracker.sample_chunk(event.tick)
end)

-- on_init: first time mod is loaded
script.on_init(function()
  full_init()
end)

-- on_configuration_changed: mod updated or game version changed
script.on_configuration_changed(function(data)
  local mod_changes = data.mod_changes and data.mod_changes["bottleneck-analyzer"]
  if mod_changes and mod_changes.old_version then
    local current_rate = settings.global["bottleneck-analyzer-sample-rate"].value
    if current_rate < 10 then
      settings.global["bottleneck-analyzer-sample-rate"] = { value = 30.0 }
      log("Bottleneck Analyzer: sample rate was " .. current_rate .. "s, overridden to 30s for performance")
    end
  end

  full_init()
end)

-- Entity build events
local function on_entity_built(event)
  tracker.track_entity(event.entity)
end

script.on_event(defines.events.on_built_entity, on_entity_built, ENTITY_FILTERS)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, ENTITY_FILTERS)
script.on_event(defines.events.script_raised_built, on_entity_built, ENTITY_FILTERS)

-- Entity removal events
local function on_entity_removed(event)
  tracker.untrack_entity(event.entity)
end

script.on_event(defines.events.on_entity_died, on_entity_removed, ENTITY_FILTERS)
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, ENTITY_FILTERS)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, ENTITY_FILTERS)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, ENTITY_FILTERS)

-- Shortcut bar toggle
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "bottleneck-analyzer-toggle" then
    local player = game.get_player(event.player_index)
    if player then
      gui.toggle(player)
    end
  end
end)

-- GUI events
script.on_event(defines.events.on_gui_click, function(event)
  gui.on_click(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  gui.on_elem_changed(event)
end)

script.on_event(defines.events.on_gui_selected_tab_changed, function(event)
  gui.on_tab_changed(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  gui.on_closed(event)
end)

-- Console commands
commands.add_command("bottleneck-status", "Show tracking diagnostics", function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end
  player.print("Enabled: " .. tostring(settings.global["bottleneck-analyzer-enabled"].value))
  player.print("Entity list: " .. #storage.entity_list)
  player.print("Cursor: " .. storage.sample_cursor)
  player.print("Tick: " .. game.tick)
  local recipe_count = 0
  for _ in pairs(storage.samples or {}) do recipe_count = recipe_count + 1 end
  player.print("Recipes with data: " .. recipe_count)
  local cache_count = 0
  for _ in pairs(storage.recipe_cache or {}) do cache_count = cache_count + 1 end
  player.print("Recipe cache entries: " .. cache_count)
end)

commands.add_command("bottleneck-reset", "Clear all collected sample data", function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end
  local count = 0
  for _ in pairs(storage.samples or {}) do count = count + 1 end
  storage.samples = {}
  storage.sample_cursor = 1
  player.print("Cleared " .. count .. " recipes of sample data")
end)

commands.add_command("bottleneck-dump", "Export recipe sample data to JSON file", function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end

  local parts = {}
  parts[#parts + 1] = '{"game_tick":' .. game.tick .. ',"recipes":{'

  local first_recipe = true
  local recipe_count = 0
  for recipe_name, _ in pairs(storage.samples or {}) do
    local samples = data_store.query(recipe_name, 0)
    if #samples > 0 then
      if not first_recipe then parts[#parts + 1] = ',' end
      first_recipe = false
      recipe_count = recipe_count + 1

      parts[#parts + 1] = '"' .. recipe_name .. '":['
      for j, s in ipairs(samples) do
        if j > 1 then parts[#parts + 1] = ',' end
        parts[#parts + 1] = '{"tick":' .. s.tick .. ',"total":' .. s.total_machines
        if s.waiting then
          parts[#parts + 1] = ',"w":{'
          local first_w = true
          for ing, count in pairs(s.waiting) do
            if not first_w then parts[#parts + 1] = ',' end
            first_w = false
            parts[#parts + 1] = '"' .. ing .. '":' .. count
          end
          parts[#parts + 1] = '}'
        end
        parts[#parts + 1] = '}'
      end
      parts[#parts + 1] = ']'
    end
  end

  parts[#parts + 1] = '}}'
  local file = "bottleneck-analyzer-recipes.json"
  helpers.write_file(file, table.concat(parts), false)
  player.print("Exported " .. recipe_count .. " recipes -> script-output/" .. file)
end)

commands.add_command("bottleneck-graph", "Export recipe dependency graph to JSON file", function(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end

  local parts = {}
  parts[#parts + 1] = '{"game_tick":' .. game.tick .. ',"recipes":{'

  local first_recipe = true
  local recipe_count = 0
  for recipe_name, _ in pairs(storage.samples or {}) do
    local samples = data_store.query(recipe_name, 0)
    if #samples == 0 then goto continue end

    local recipe_proto = prototypes.recipe[recipe_name]
    if not recipe_proto then goto continue end

    if not first_recipe then parts[#parts + 1] = ',' end
    first_recipe = false
    recipe_count = recipe_count + 1

    parts[#parts + 1] = '"' .. recipe_name .. '":{'

    -- Ingredients
    parts[#parts + 1] = '"ingredients":['
    for k, ing in ipairs(recipe_proto.ingredients) do
      if k > 1 then parts[#parts + 1] = ',' end
      parts[#parts + 1] = '{"name":"' .. ing.name .. '","type":"' .. ing.type .. '","amount":' .. ing.amount .. '}'
    end
    parts[#parts + 1] = '],'

    -- Products
    parts[#parts + 1] = '"products":['
    for k, prod in ipairs(recipe_proto.products) do
      if k > 1 then parts[#parts + 1] = ',' end
      local amount = prod.amount or ((prod.amount_min + prod.amount_max) / 2)
      parts[#parts + 1] = '{"name":"' .. prod.name .. '","type":"' .. prod.type .. '","amount":' .. amount .. '}'
    end
    parts[#parts + 1] = '],'

    -- Compute avg machines and waiting percentages from samples
    local total_machines = 0
    local waiting_totals = {}
    for _, s in ipairs(samples) do
      total_machines = total_machines + s.total_machines
      if s.waiting then
        for ing_name, count in pairs(s.waiting) do
          waiting_totals[ing_name] = (waiting_totals[ing_name] or 0) + count
        end
      end
    end
    local avg_machines = total_machines / #samples

    parts[#parts + 1] = '"machines":' .. string.format("%.1f", avg_machines)

    -- Waiting percentages: (total waiting for X) / (total machines across all samples) * 100
    if next(waiting_totals) and total_machines > 0 then
      parts[#parts + 1] = ',"waiting_pct":{'
      local first_w = true
      for ing_name, wtotal in pairs(waiting_totals) do
        if not first_w then parts[#parts + 1] = ',' end
        first_w = false
        local pct = wtotal / total_machines * 100
        parts[#parts + 1] = '"' .. ing_name .. '":' .. string.format("%.1f", pct)
      end
      parts[#parts + 1] = '}'
    end

    parts[#parts + 1] = '}'
    ::continue::
  end

  parts[#parts + 1] = '}}'
  local file = "bottleneck-analyzer-graph.json"
  helpers.write_file(file, table.concat(parts), false)
  player.print("Exported " .. recipe_count .. " recipes -> script-output/" .. file)
end)
