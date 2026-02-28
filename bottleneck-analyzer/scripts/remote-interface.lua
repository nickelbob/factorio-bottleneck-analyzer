local gui = require("scripts.gui")

local remote_interface = {}

-- Custom events (per the interop spec)
local on_item_selected = script.generate_event_name()
local on_time_slice_changed = script.generate_event_name()

-- Re-entrancy guard: suppress re-broadcast when handling external events
local handling_external = false

-- Callback for when an external item arrives (set by control.lua)
local on_external_item_callback = nil

--- Accepted prototype types for open_page.
local allowed_types = {
  LuaItemPrototype = true,
  LuaFluidPrototype = true,
  LuaRecipePrototype = true,
}

--- Resolve an item/fluid name from a prototype object or string.
local function resolve_name(prototype)
  if type(prototype) == "string" then
    if prototypes.item[prototype] or prototypes.fluid[prototype] then
      return prototype
    end
    return nil
  end
  if type(prototype) == "table" and prototype.object_name then
    if not allowed_types[prototype.object_name] then
      return nil
    end
    if prototype.object_name == "LuaRecipePrototype" then
      local products = prototype.products
      if products and products[1] then
        return products[1].name
      end
      return nil
    end
    return prototype.name
  end
  return nil
end

-----------------------------------------------------------------------
-- Remote interface functions
-----------------------------------------------------------------------

--- open_page(player_index, prototype)
--- Accepts string name or LuaItemPrototype/LuaFluidPrototype/LuaRecipePrototype.
function remote_interface.open_page(player_index, prototype)
  if type(player_index) ~= "number" then
    error("bad argument #1 to 'open_page' (expected number, got " .. type(player_index) .. ")")
  end
  local player = game.get_player(player_index)
  if not player then
    error("bad argument #1 to 'open_page' (invalid player index " .. player_index .. ")")
  end
  if prototype == nil then
    error("bad argument #2 to 'open_page' (expected prototype or string, got nil)")
  end

  local name = resolve_name(prototype)
  if not name then
    if type(prototype) == "table" and prototype.object_name then
      error("bad argument #2 to 'open_page' (unsupported type '" .. prototype.object_name .. "')")
    else
      error("bad argument #2 to 'open_page' (could not resolve item/fluid name)")
    end
  end

  gui.select_item(player, name)
  return true
end

--- set_time_slice(player_index, slice_label)
--- slice_label: "5m", "10m", "30m", "1h", "All"
function remote_interface.set_time_slice(player_index, slice_label)
  if type(player_index) ~= "number" then
    error("bad argument #1 to 'set_time_slice' (expected number, got " .. type(player_index) .. ")")
  end
  local player = game.get_player(player_index)
  if not player then
    error("bad argument #1 to 'set_time_slice' (invalid player index " .. player_index .. ")")
  end
  if type(slice_label) ~= "string" then
    error("bad argument #2 to 'set_time_slice' (expected string, got " .. type(slice_label) .. ")")
  end

  local ok = gui.select_time_slice(player, slice_label)
  if not ok then
    error("bad argument #2 to 'set_time_slice' (unknown slice label '" .. slice_label .. "', expected 5m/10m/30m/1h/All)")
  end
  return true
end

--- show(player_index, prototype, slice_label)
--- Convenience: open_page + set_time_slice in one call.
function remote_interface.show(player_index, prototype, slice_label)
  remote_interface.open_page(player_index, prototype)
  if slice_label then
    remote_interface.set_time_slice(player_index, slice_label)
  end
  return true
end

function remote_interface.get_on_item_selected()
  return on_item_selected
end

function remote_interface.get_on_time_slice_changed()
  return on_time_slice_changed
end

function remote_interface.interop_version()
  return 1
end

remote.add_interface("bottleneck-analyzer", remote_interface)

-----------------------------------------------------------------------
-- Event publishing (called from gui.lua via callbacks)
-----------------------------------------------------------------------

local function raise_item_selected(player_index, item_name)
  if handling_external then return end
  script.raise_event(on_item_selected, {
    player_index = player_index,
    item_name = item_name,
  })
end

local function raise_time_slice_changed(player_index, slice_label)
  if handling_external then return end
  script.raise_event(on_time_slice_changed, {
    player_index = player_index,
    slice_label = slice_label,
  })
end

-----------------------------------------------------------------------
-- Auto-discovery: subscribe to any mod exposing interop spec events
-----------------------------------------------------------------------

local function subscribe_to_events()
  for iface, functions in pairs(remote.interfaces) do
    if iface == "bottleneck-analyzer" then goto continue end

    if functions["get_on_item_selected"] then
      local event_id = remote.call(iface, "get_on_item_selected")
      if event_id then
        local source_iface = iface
        script.on_event(event_id, function(e)
          local player = game.get_player(e.player_index)
          if not player then return end
          local item_name = e.item_name
          if item_name and (prototypes.item[item_name] or prototypes.fluid[item_name]) then
            if on_external_item_callback then
              on_external_item_callback(e.player_index, item_name, source_iface)
            end
          end
        end)
        log("Bottleneck Analyzer: subscribed to " .. iface .. ".get_on_item_selected")
      end
    end

    if functions["get_on_time_slice_changed"] then
      local event_id = remote.call(iface, "get_on_time_slice_changed")
      if event_id then
        script.on_event(event_id, function(e)
          local player = game.get_player(e.player_index)
          if not player then return end
          if e.slice_label and type(e.slice_label) == "string" then
            handling_external = true
            gui.select_time_slice(player, e.slice_label)
            handling_external = false
          end
        end)
        log("Bottleneck Analyzer: subscribed to " .. iface .. ".get_on_time_slice_changed")
      end
    end

    ::continue::
  end
end

local function set_on_external_item_callback(cb)
  on_external_item_callback = cb
end

return {
  raise_item_selected = raise_item_selected,
  raise_time_slice_changed = raise_time_slice_changed,
  subscribe_to_events = subscribe_to_events,
  set_on_external_item_callback = set_on_external_item_callback,
}
