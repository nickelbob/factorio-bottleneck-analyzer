local tracker = require("scripts.tracker")
local data_store = require("scripts.data-store")
local gui = require("scripts.gui")

-- Entity type filters for build/destroy events
local ENTITY_FILTERS = {
  { filter = "type", type = "assembling-machine" },
  { filter = "type", type = "furnace" },
  { filter = "type", type = "rocket-silo" },
}

--- Register the nth_tick handler based on current settings.
local function register_nth_tick()
  -- Clear any existing nth_tick handlers
  script.on_nth_tick(nil)

  local ticks = tracker.get_sample_ticks()
  script.on_nth_tick(ticks, function(event)
    tracker.sample(event.tick)
  end)
end

--- Full initialization.
local function full_init()
  data_store.init()
  gui.init()

  if not storage.tracked_entities then
    storage.tracked_entities = {}
  end

  tracker.scan_surfaces()
  register_nth_tick()
end

-- on_init: first time mod is loaded
script.on_init(function()
  full_init()
end)

-- on_configuration_changed: mod updated or game version changed
script.on_configuration_changed(function(data)
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

-- Settings changed
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "bottleneck-analyzer-sample-rate" then
    register_nth_tick()
  end
end)
