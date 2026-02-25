local data_store = {}

local MAX_BUFFER_SIZE = 100

function data_store.init()
  if not storage.samples then
    storage.samples = {}
  end
  -- Reset any buffers from a previous larger MAX_BUFFER_SIZE
  for recipe_name, rb in pairs(storage.samples) do
    if rb.head > MAX_BUFFER_SIZE or rb.count > MAX_BUFFER_SIZE then
      storage.samples[recipe_name] = { buffer = {}, head = 1, count = 0 }
    end
  end
end

--- Ensure a ring buffer exists and is valid for the current MAX_BUFFER_SIZE.
local function ensure_buffer(recipe_name)
  local rb = storage.samples[recipe_name]
  if not rb or rb.head > MAX_BUFFER_SIZE or rb.count > MAX_BUFFER_SIZE then
    storage.samples[recipe_name] = {
      buffer = {},
      head = 1,
      count = 0,
    }
  end
end

--- Record a single aggregated sample for a recipe at a given tick.
-- @param recipe_name string
-- @param tick number
-- @param total_machines number - all machines with this recipe (working + waiting)
-- @param waiting table - { [ingredient_name] = count_of_machines_waiting }
function data_store.record_sample(recipe_name, tick, total_machines, waiting)
  ensure_buffer(recipe_name)
  local rb = storage.samples[recipe_name]

  rb.buffer[rb.head] = {
    tick = tick,
    total_machines = total_machines,
    waiting = waiting,
  }

  rb.head = rb.head + 1
  if rb.head > MAX_BUFFER_SIZE then
    rb.head = 1
  end
  if rb.count < MAX_BUFFER_SIZE then
    rb.count = rb.count + 1
  end
end

--- Query samples for a recipe within a time range.
-- @param recipe_name string
-- @param min_tick number - only return samples with tick >= min_tick (0 for all)
-- @return table - array of sample entries matching the filter
function data_store.query(recipe_name, min_tick)
  local rb = storage.samples[recipe_name]
  if not rb or rb.count == 0 then
    return {}
  end
  -- Reset oversized buffers from old MAX_BUFFER_SIZE
  if rb.head > MAX_BUFFER_SIZE or rb.count > MAX_BUFFER_SIZE then
    storage.samples[recipe_name] = { buffer = {}, head = 1, count = 0 }
    return {}
  end

  local results = {}
  -- Walk through valid entries in the ring buffer
  local start_idx
  if rb.count < MAX_BUFFER_SIZE then
    start_idx = 1
  else
    start_idx = rb.head -- oldest entry is at head (about to be overwritten next)
  end

  for i = 0, rb.count - 1 do
    local idx = ((start_idx - 1 + i) % MAX_BUFFER_SIZE) + 1
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
  return MAX_BUFFER_SIZE
end

return data_store
