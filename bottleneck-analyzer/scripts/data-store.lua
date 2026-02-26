local data_store = {}

local function get_max_buffer_size()
  return settings.global["bottleneck-analyzer-max-samples"].value
end

function data_store.init()
  if not storage.samples then
    storage.samples = {}
  end
  local max = get_max_buffer_size()
  for recipe_name, rb in pairs(storage.samples) do
    if rb.head > max or rb.count > max then
      storage.samples[recipe_name] = { buffer = {}, head = 1, count = 0 }
    end
  end
end

local function ensure_buffer(recipe_name, max)
  local rb = storage.samples[recipe_name]
  if not rb or rb.head > max or rb.count > max then
    storage.samples[recipe_name] = {
      buffer = {},
      head = 1,
      count = 0,
    }
  end
end

--- Record a single aggregated sample for a recipe at a given tick.
function data_store.record_sample(recipe_name, tick, total_machines, waiting)
  local max = get_max_buffer_size()
  ensure_buffer(recipe_name, max)
  local rb = storage.samples[recipe_name]

  rb.buffer[rb.head] = {
    tick = tick,
    total_machines = total_machines,
    waiting = waiting,
  }

  rb.head = rb.head + 1
  if rb.head > max then
    rb.head = 1
  end
  if rb.count < max then
    rb.count = rb.count + 1
  end
end

--- Query samples for a recipe within a time range.
function data_store.query(recipe_name, min_tick)
  local max = get_max_buffer_size()
  local rb = storage.samples[recipe_name]
  if not rb or rb.count == 0 then
    return {}
  end
  if rb.head > max or rb.count > max then
    storage.samples[recipe_name] = { buffer = {}, head = 1, count = 0 }
    return {}
  end

  local results = {}
  local start_idx
  if rb.count < max then
    start_idx = 1
  else
    start_idx = rb.head
  end

  for i = 0, rb.count - 1 do
    local idx = ((start_idx - 1 + i) % max) + 1
    local sample = rb.buffer[idx]
    if sample and sample.tick >= min_tick then
      results[#results + 1] = sample
    end
  end

  return results
end

--- Get all recipe names that produce a given item.
-- @param item_name string
-- @return table - array of recipe prototype names
function data_store.get_recipes_for_item(item_name)
  local recipes = {}
  local all_recipes = prototypes.recipe
  for name, recipe in pairs(all_recipes) do
    for _, product in pairs(recipe.products) do
      if product.name == item_name then
        recipes[#recipes + 1] = name
        break
      end
    end
  end
  return recipes
end

function data_store.get_max_samples()
  return get_max_buffer_size()
end

return data_store
