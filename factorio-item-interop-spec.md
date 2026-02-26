# Factorio Item Interop Spec v1

A convention for Factorio 2.0 mods to share item/fluid selections.

## Spec

### 1. Broadcast: Custom Event

Raise a custom event when your mod's item selection changes.

**Register:**

```lua
local on_item_selected = script.generate_event_name()

remote.add_interface("your-mod-name", {
  get_on_item_selected = function() return on_item_selected end,
})
```

**Raise:**

```lua
script.raise_event(on_item_selected, {
  player_index = player.index,  -- uint
  item_name = "iron-plate",     -- string (item or fluid name)
})
```

**Subscribe (in on_init and on_load):**

```lua
if remote.interfaces["some-mod"] and remote.interfaces["some-mod"]["get_on_item_selected"] then
  local event_id = remote.call("some-mod", "get_on_item_selected")
  script.on_event(event_id, function(e)
    -- e.player_index, e.item_name
  end)
end
```

### 2. Direct Call: open_page

For "open mod X to item Y" interactions.

```lua
remote.add_interface("your-mod-name", {
  open_page = function(player_index, prototype)
    -- player_index: uint
    -- prototype: LuaItemPrototype, LuaFluidPrototype, LuaRecipePrototype, or string name
    -- returns: true on success
  end,
})
```

Accept both string names and prototype objects. For recipe prototypes, use the first product.

### 3. Time Slice

Mods that display time-windowed data can accept a time slice label.

**Direct call:**

```lua
remote.add_interface("your-mod-name", {
  set_time_slice = function(player_index, slice_label)
    -- player_index: uint
    -- slice_label: string (e.g. "5m", "10m", "30m", "1h", "All")
    -- returns: true on success
  end,
})
```

**Broadcast:**

```lua
local on_time_slice_changed = script.generate_event_name()

remote.add_interface("your-mod-name", {
  get_on_time_slice_changed = function() return on_time_slice_changed end,
})

script.raise_event(on_time_slice_changed, {
  player_index = player.index,  -- uint
  slice_label = "30m",          -- string
})
```

Slice labels are freeform strings. Mods should ignore labels they don't recognize.

### 4. Version

```lua
remote.add_interface("your-mod-name", {
  version = function() return 1 end,
})
```

## Auto-Discovery

The standardized getter name means mods can scan all interfaces:

```lua
local function subscribe_to_all()
  for iface, functions in pairs(remote.interfaces) do
    if functions["get_on_item_selected"] then
      local event_id = remote.call(iface, "get_on_item_selected")
      script.on_event(event_id, function(e)
        -- handle e.player_index, e.item_name
      end)
    end
  end
end
```

### Loop Prevention

If your mod both publishes and subscribes:

```lua
local handling_external = false

local function raise(player_index, item_name)
  if handling_external then return end
  script.raise_event(on_item_selected, { player_index = player_index, item_name = item_name })
end

script.on_event(external_event_id, function(e)
  handling_external = true
  select_item(e.player_index, e.item_name)
  handling_external = false
end)
```

## Summary

| Function | Purpose |
|---|---|
| `get_on_item_selected()` | Returns event ID for item selection broadcast |
| `get_on_time_slice_changed()` | Returns event ID for time slice broadcast |
| `open_page(player_index, prototype)` | Open mod to a specific item |
| `set_time_slice(player_index, slice_label)` | Set time window |
| `version()` | API version number |

Item event payload: `{ player_index = uint, item_name = string }`
Time slice event payload: `{ player_index = uint, slice_label = string }`

## Adopters

- [Bottleneck Analyzer](https://mods.factorio.com/mod/bottleneck-analyzer) — v0.3.1+
