local tracker = require("scripts.tracker")
local data_store = require("scripts.data-store")
local gui = require("scripts.gui")

-- Entity type filters for build/destroy events
local ENTITY_FILTERS = {
  { filter = "type", type = "assembling-machine" },
  { filter = "type", type = "furnace" },
  { filter = "type", type = "rocket-silo" },
}

--- Register the per-tick handler for chunked sampling.
local function register_nth_tick()
  script.on_nth_tick(nil)
  script.on_nth_tick(1, function(event)
    tracker.sample_chunk(event.tick)
  end)
end

--- Full initialization.
local function full_init()
  data_store.init()
  gui.init()
  tracker.init_storage()
  tracker.scan_surfaces()
  register_nth_tick()
end

-- on_init: first time mod is loaded
script.on_init(function()
  full_init()
end)

-- on_configuration_changed: mod updated or game version changed
script.on_configuration_changed(function(data)
  local mod_changes = data.mod_changes and data.mod_changes["bottleneck-analyzer"]
  if mod_changes and mod_changes.old_version then
    -- Force sample rate to 30s for users upgrading from old versions with bad defaults
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
-- Remote interface for profiling
remote.add_interface("bottleneck-analyzer", {
  profile_on = function() tracker.enable_profiling(true) end,
  profile_off = function() tracker.enable_profiling(false) end,
})

-- Settings changed (batch size adapts automatically, no re-registration needed)
