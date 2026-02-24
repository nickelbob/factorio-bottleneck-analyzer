local data_store = require("scripts.data-store")

local gui = {}

local TIME_SLICES = {
  { label = "1m",  ticks = 60 * 60 },
  { label = "5m",  ticks = 5 * 60 * 60 },
  { label = "10m", ticks = 10 * 60 * 60 },
  { label = "30m", ticks = 30 * 60 * 60 },
  { label = "1h",  ticks = 60 * 60 * 60 },
  { label = "All", ticks = 0 },
}

--- Initialize per-player GUI state storage.
function gui.init()
  if not storage.player_gui then
    storage.player_gui = {}
  end
end

--- Get or create player GUI state.
local function get_player_state(player_index)
  if not storage.player_gui[player_index] then
    storage.player_gui[player_index] = {
      open = false,
      selected_item = nil,
      time_slice_index = 2, -- default 5m
      selected_recipe = nil,
      history = {},  -- stack of previous selected_item values for back navigation
    }
  end
  return storage.player_gui[player_index]
end

--- Toggle button is now handled via shortcut bar prototype (data.lua).
--- No per-player button creation needed.

--- Destroy the main window if it exists.
local function destroy_main_window(player)
  local screen = player.gui.screen
  if screen["bottleneck-analyzer-main"] then
    screen["bottleneck-analyzer-main"].destroy()
  end
end

--- Build the ingredient bars for a given recipe within the time window.
local function build_ingredient_display(container, recipe_name, min_tick)
  container.clear()

  local samples = data_store.query(recipe_name, min_tick)
  if #samples == 0 then
    container.add({
      type = "label",
      caption = { "bottleneck-analyzer.no-data" },
      style = "label",
    })
    return
  end

  -- Get the recipe prototype for ingredient list
  local recipe_proto = prototypes.recipe[recipe_name]
  if not recipe_proto then return end

  -- Aggregate: total_samples (sum of total_machines), per-ingredient waiting count
  local total_machine_samples = 0
  local ingredient_waiting = {}

  for _, sample in pairs(samples) do
    total_machine_samples = total_machine_samples + sample.total_machines
    for ing_name, count in pairs(sample.waiting) do
      ingredient_waiting[ing_name] = (ingredient_waiting[ing_name] or 0) + count
    end
  end

  if total_machine_samples == 0 then
    container.add({
      type = "label",
      caption = { "bottleneck-analyzer.no-data" },
      style = "label",
    })
    return
  end

  -- Build sorted ingredient list by severity
  local sorted_ingredients = {}
  for _, ingredient in pairs(recipe_proto.ingredients) do
    local waiting_count = ingredient_waiting[ingredient.name] or 0
    local percentage = (waiting_count / total_machine_samples) * 100
    sorted_ingredients[#sorted_ingredients + 1] = {
      ingredient = ingredient,
      percentage = percentage,
    }
  end
  table.sort(sorted_ingredients, function(a, b) return a.percentage > b.percentage end)

  -- Display each ingredient with a progress bar
  local product = recipe_proto.products[1]
  local prod_prefix = product.type == "fluid" and "fluid" or "item"

  for _, entry in ipairs(sorted_ingredients) do
    local ingredient = entry.ingredient
    local percentage = entry.percentage

    local row = container.add({
      type = "flow",
      direction = "horizontal",
    })
    row.style.vertical_align = "center"
    row.style.horizontally_stretchable = true
    row.style.height = 36

    -- Ingredient icon + name (clickable to navigate)
    local ing_prefix = ingredient.type == "fluid" and "fluid" or "item"
    local proto = ingredient.type == "fluid"
        and prototypes.fluid[ingredient.name]
        or  prototypes.item[ingredient.name]
    local caption = proto
        and {"", "[" .. ing_prefix .. "=" .. ingredient.name .. "] ", proto.localised_name}
        or  "[" .. ing_prefix .. "=" .. ingredient.name .. "] " .. ingredient.name
    local btn = row.add({
      type = "button",
      name = "bottleneck-analyzer-ingredient__" .. ingredient.type .. "__" .. ingredient.name,
      caption = caption,
      style = "mini_button",
      tooltip = { "bottleneck-analyzer.click-to-view" },
    })
    btn.style.width = 200
    btn.style.height = 36
    btn.style.horizontal_align = "left"

    -- Progress bar
    local pct_str = string.format("%.1f%%", percentage)
    local tooltip = "[" .. prod_prefix .. "=" .. product.name .. "] was waiting for ["
        .. ing_prefix .. "=" .. ingredient.name .. "] " .. pct_str .. " of the time"
    local bar = row.add({
      type = "progressbar",
      value = percentage / 100,
      tooltip = tooltip,
    })
    bar.style.width = 200
    bar.style.height = 28
    bar.style.bar_width = 28
    bar.style.color = percentage > 50 and { r = 0.9, g = 0.2, b = 0.2 } or
        percentage > 20 and { r = 0.9, g = 0.7, b = 0.1 } or
        { r = 0.2, g = 0.8, b = 0.2 }

    -- Percentage text
    row.add({
      type = "label",
      caption = string.format("%.1f%%", percentage),
    }).style.width = 60
  end
end

--- Compute min_tick for the current time slice.
local function get_min_tick(state)
  local slice = TIME_SLICES[state.time_slice_index]
  local min_tick = 0
  if slice.ticks > 0 then
    min_tick = game.tick - slice.ticks
    if min_tick < 0 then min_tick = 0 end
  end
  return min_tick
end

--- Build or rebuild the main window content.
local function build_main_window(player)
  local state = get_player_state(player.index)
  destroy_main_window(player)

  local frame = player.gui.screen.add({
    type = "frame",
    name = "bottleneck-analyzer-main",
    direction = "vertical",
  })
  frame.auto_center = true
  frame.style.minimal_width = 500
  frame.style.maximal_height = 600
  player.opened = frame

  -- Title bar
  local titlebar = frame.add({
    type = "flow",
    direction = "horizontal",
  })
  titlebar.style.horizontal_spacing = 8
  titlebar.style.horizontally_stretchable = true

  titlebar.add({
    type = "label",
    caption = { "bottleneck-analyzer.title" },
    style = "frame_title",
    ignored_by_interaction = true,
  })

  local drag = titlebar.add({
    type = "empty-widget",
    style = "draggable_space_header",
  })
  drag.style.horizontally_stretchable = true
  drag.style.height = 24
  drag.drag_target = frame

  titlebar.add({
    type = "sprite-button",
    name = "bottleneck-analyzer-close",
    sprite = "utility/close",
    style = "close_button",
  })

  -- Content frame
  local content = frame.add({
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  })
  content.style.horizontally_stretchable = true

  -- Item selector row
  local item_row = content.add({
    type = "flow",
    direction = "horizontal",
  })
  item_row.style.vertical_align = "center"

  item_row.add({
    type = "label",
    caption = { "bottleneck-analyzer.item-label" },
  })

  -- Back button (only visible when there's history)
  if #state.history > 0 then
    local back_btn = item_row.add({
      type = "sprite-button",
      name = "bottleneck-analyzer-back",
      sprite = "utility/reset",
      tooltip = { "bottleneck-analyzer.back-tooltip" },
      style = "tool_button",
    })
  end

  local chooser = item_row.add({
    type = "choose-elem-button",
    name = "bottleneck-analyzer-item-chooser",
    elem_type = "signal",
  })
  if state.selected_item then
    if prototypes.item[state.selected_item] then
      chooser.elem_value = { type = "item", name = state.selected_item }
    elseif prototypes.fluid[state.selected_item] then
      chooser.elem_value = { type = "fluid", name = state.selected_item }
    end
  end

  -- Separator
  content.add({ type = "line" }).style.top_margin = 4

  -- Time slice buttons
  local time_row = content.add({
    type = "flow",
    direction = "horizontal",
  })
  time_row.style.top_margin = 4

  time_row.add({
    type = "label",
    caption = { "bottleneck-analyzer.time-label" },
  }).style.right_margin = 8

  for i, slice in ipairs(TIME_SLICES) do
    local btn = time_row.add({
      type = "button",
      name = "bottleneck-analyzer-time-" .. i,
      caption = slice.label,
      style = (i == state.time_slice_index) and "menu_button_continue" or "menu_button",
    })
    btn.style.minimal_width = 30
    btn.style.height = 24
    btn.style.padding = {0, 4}
    btn.style.font = "default-small"
    btn.style.horizontal_align = "center"
  end

  -- Separator
  content.add({ type = "line" }).style.top_margin = 4

  -- Scrollable recipe content area
  local scroll = content.add({
    type = "scroll-pane",
    name = "bottleneck-analyzer-scroll",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  })
  scroll.style.maximal_height = 400
  scroll.style.horizontally_stretchable = true

  local recipe_area = scroll.add({
    type = "flow",
    name = "bottleneck-analyzer-recipe-area",
    direction = "vertical",
  })
  recipe_area.style.top_margin = 4
  recipe_area.style.horizontally_stretchable = true

  -- Populate: item detail view or top bottlenecks overview
  gui.update_recipe_area(player)
end

--- Update the chooser element to match the current selected_item state.
function gui.sync_chooser(player)
  local state = get_player_state(player.index)
  local main = player.gui.screen["bottleneck-analyzer-main"]
  if not main then return end

  -- Find the chooser nested in the content frame
  for _, child in pairs(main.children) do
    if child.type == "frame" then
      for _, sub in pairs(child.children) do
        if sub.type == "flow" then
          local chooser = sub["bottleneck-analyzer-item-chooser"]
          if chooser then
            if state.selected_item then
              if prototypes.item[state.selected_item] then
                chooser.elem_value = { type = "item", name = state.selected_item }
              elseif prototypes.fluid[state.selected_item] then
                chooser.elem_value = { type = "fluid", name = state.selected_item }
              else
                chooser.elem_value = nil
              end
            else
              chooser.elem_value = nil
            end
            return
          end
        end
      end
    end
  end
end

--- Update the recipe display area for the current selection.
function gui.update_recipe_area(player)
  local state = get_player_state(player.index)
  local main = player.gui.screen["bottleneck-analyzer-main"]
  if not main then return end

  -- Find recipe_area through the nesting: main > frame > scroll-pane > flow
  local recipe_area
  for _, child in pairs(main.children) do
    if child.type == "frame" then
      local scroll = child["bottleneck-analyzer-scroll"]
      if scroll then
        recipe_area = scroll["bottleneck-analyzer-recipe-area"]
      end
      if recipe_area then break end
    end
  end
  if not recipe_area then return end

  recipe_area.clear()

  local min_tick = get_min_tick(state)

  if not state.selected_item then
    recipe_area.add({
      type = "label",
      caption = { "bottleneck-analyzer.select-item" },
      style = "label",
    })
    return
  end

  local recipes = data_store.get_recipes_for_item(state.selected_item)
  if #recipes == 0 then
    recipe_area.add({
      type = "label",
      caption = { "bottleneck-analyzer.no-recipes" },
      style = "label",
    })
    return
  end

  -- Filter to only recipes that have data
  local recipes_with_data = {}
  for _, recipe_name in ipairs(recipes) do
    local samples = data_store.query(recipe_name, min_tick)
    if #samples > 0 then
      recipes_with_data[#recipes_with_data + 1] = recipe_name
    end
  end

  if #recipes_with_data == 0 then
    recipe_area.add({
      type = "label",
      caption = { "bottleneck-analyzer.no-data" },
      style = "label",
    })
    return
  end

  if #recipes_with_data == 1 then
    -- Single recipe, no tabs needed
    local recipe_name = recipes_with_data[1]
    local recipe_proto = prototypes.recipe[recipe_name]
    local label_text = recipe_proto and recipe_proto.localised_name or recipe_name

    recipe_area.add({
      type = "label",
      caption = { "bottleneck-analyzer.recipe-header", label_text },
      style = "heading_2_label",
    })

    local ingredient_container = recipe_area.add({
      type = "flow",
      name = "bottleneck-analyzer-ingredients",
      direction = "vertical",
    })
    ingredient_container.style.top_margin = 8

    build_ingredient_display(ingredient_container, recipe_name, min_tick)
  else
    -- Multiple recipes with data, use tabbed pane
    local tabbed_pane = recipe_area.add({
      type = "tabbed-pane",
      name = "bottleneck-analyzer-tabbed-pane",
    })

    for i, recipe_name in ipairs(recipes_with_data) do
      local recipe_proto = prototypes.recipe[recipe_name]
      local tab_caption = recipe_proto and recipe_proto.localised_name or recipe_name

      local tab = tabbed_pane.add({
        type = "tab",
        caption = tab_caption,
      })

      local tab_content = tabbed_pane.add({
        type = "flow",
        direction = "vertical",
      })
      tab_content.style.top_margin = 8

      tabbed_pane.add_tab(tab, tab_content)

      build_ingredient_display(tab_content, recipe_name, min_tick)
    end

    -- Select stored recipe tab if it exists, otherwise first
    local tab_idx = 1
    if state.selected_recipe then
      for i, rn in ipairs(recipes_with_data) do
        if rn == state.selected_recipe then
          tab_idx = i
          break
        end
      end
    end
    tabbed_pane.selected_tab_index = tab_idx
  end
end

--- Toggle the main window open/closed.
function gui.toggle(player)
  local state = get_player_state(player.index)
  if state.open then
    destroy_main_window(player)
    state.open = false
  else
    build_main_window(player)
    state.open = true
  end
end

--- Handle GUI click events.
function gui.on_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local name = element.name
  local player = game.get_player(event.player_index)
  if not player then return end

  if name == "bottleneck-analyzer-close" then
    local state = get_player_state(player.index)
    destroy_main_window(player)
    state.open = false
    return
  end

  -- Back button
  if name == "bottleneck-analyzer-back" then
    local state = get_player_state(player.index)
    if #state.history > 0 then
      state.selected_item = table.remove(state.history)
      state.selected_recipe = nil
      gui.sync_chooser(player)
      gui.update_recipe_area(player)
    end
    return
  end

  -- Time slice buttons
  local time_match = name:match("^bottleneck%-analyzer%-time%-(%d+)$")
  if time_match then
    local idx = tonumber(time_match)
    if idx and idx >= 1 and idx <= #TIME_SLICES then
      local state = get_player_state(player.index)
      state.time_slice_index = idx
      -- Update button highlights in-place
      local parent = element.parent
      if parent then
        for i = 1, #TIME_SLICES do
          local btn = parent["bottleneck-analyzer-time-" .. i]
          if btn then
            btn.style = (i == idx) and "menu_button_continue" or "menu_button"
            btn.style.minimal_width = 30
            btn.style.height = 24
            btn.style.padding = {0, 4}
            btn.style.font = "default-small"
            btn.style.horizontal_align = "center"
          end
        end
      end
      gui.update_recipe_area(player)
    end
    return
  end

  -- Ingredient navigation buttons (format: ingredient__type__name)
  local ing_type, ing_name = name:match("^bottleneck%-analyzer%-ingredient__(%a+)__(.+)$")
  if ing_name then
    local state = get_player_state(player.index)
    if state.selected_item then
      state.history[#state.history + 1] = state.selected_item
    end
    state.selected_item = ing_name
    state.selected_recipe = nil
    gui.sync_chooser(player)
    gui.update_recipe_area(player)
    return
  end

end

--- Handle item chooser changes.
function gui.on_elem_changed(event)
  local element = event.element
  if not element or not element.valid then return end
  if element.name ~= "bottleneck-analyzer-item-chooser" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local state = get_player_state(player.index)
  local val = element.elem_value
  if val then
    -- Signal chooser returns a SignalID: {type=, name=} or just a name string
    if type(val) == "table" then
      state.selected_item = val.name
    elseif type(val) == "string" then
      state.selected_item = val
    else
      state.selected_item = nil
    end
  else
    state.selected_item = nil
  end
  state.selected_recipe = nil
  state.history = {}

  gui.update_recipe_area(player)
end

--- Handle tab changes in the recipe tabbed pane.
function gui.on_tab_changed(event)
  local element = event.element
  if not element or not element.valid then return end
  if element.name ~= "bottleneck-analyzer-tabbed-pane" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local state = get_player_state(player.index)

  -- Store the selected recipe so we can restore it on rebuild.
  -- Tabs are built from the filtered recipes_with_data list, so we need
  -- to reconstruct that same filtered list to map tab index -> recipe name.
  if state.selected_item then
    local slice = TIME_SLICES[state.time_slice_index]
    local min_tick = 0
    if slice.ticks > 0 then
      min_tick = game.tick - slice.ticks
      if min_tick < 0 then min_tick = 0 end
    end
    local all_recipes = data_store.get_recipes_for_item(state.selected_item)
    local recipes_with_data = {}
    for _, rn in ipairs(all_recipes) do
      local samples = data_store.query(rn, min_tick)
      if #samples > 0 then
        recipes_with_data[#recipes_with_data + 1] = rn
      end
    end
    local idx = element.selected_tab_index
    if idx and recipes_with_data[idx] then
      state.selected_recipe = recipes_with_data[idx]
    end
  end
end

--- Handle GUI closed (Esc key).
function gui.on_closed(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if event.element and event.element.valid
      and event.element.name == "bottleneck-analyzer-main" then
    local state = get_player_state(player.index)
    destroy_main_window(player)
    state.open = false
  end
end

return gui
