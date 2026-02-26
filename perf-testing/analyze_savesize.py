import json

# Load actual recipe data to measure sample sizes
path = r"C:\Users\nicku\AppData\Roaming\Factorio\script-output\bottleneck-analyzer-recipes.json"
with open(path) as f:
    data = json.load(f)

recipes = data["recipes"]
ENTITY_COUNT = 14831
MAX_BUFFER = 100

# Factorio Lua serialization estimates per entry:
# number: ~9 bytes (type tag + 8 byte double)
# string: ~5 + len(str) bytes (type tag + length + data)
# table overhead: ~16 bytes (type tag + array/hash sizes)
# table entry overhead: ~2 bytes (key/value type tags)
# entity reference: ~12 bytes (type tag + surface + unit_number)

OVERHEAD_NUM = 9
OVERHEAD_STR = lambda s: 5 + len(s)
OVERHEAD_TABLE = 16
OVERHEAD_ENTRY = 2

# 1. storage.tracked_entities: { [unit_number] = entity_ref }
te_size = OVERHEAD_TABLE + ENTITY_COUNT * (OVERHEAD_NUM + 12 + OVERHEAD_ENTRY)
print(f"tracked_entities:  {te_size/1024:7.1f} KB  ({ENTITY_COUNT} entity refs)")

# 2. storage.entity_list: array of unit_numbers
el_size = OVERHEAD_TABLE + ENTITY_COUNT * (OVERHEAD_NUM + OVERHEAD_ENTRY)
print(f"entity_list:       {el_size/1024:7.1f} KB  ({ENTITY_COUNT} numbers)")

# 3. storage.entity_list_index: { [unit_number] = index }
eli_size = OVERHEAD_TABLE + ENTITY_COUNT * (OVERHEAD_NUM + OVERHEAD_NUM + OVERHEAD_ENTRY)
print(f"entity_list_index: {eli_size/1024:7.1f} KB  ({ENTITY_COUNT} number->number)")

# 4. storage.recipe_cache: { [unit_number] = recipe_name_string | false }
# Estimate avg recipe name length from actual data
all_names = list(recipes.keys())
avg_name_len = sum(len(n) for n in all_names) / len(all_names)
rc_size = OVERHEAD_TABLE + ENTITY_COUNT * (OVERHEAD_NUM + OVERHEAD_STR("x" * int(avg_name_len)) + OVERHEAD_ENTRY)
print(f"recipe_cache:      {rc_size/1024:7.1f} KB  ({ENTITY_COUNT} entries, avg name {avg_name_len:.0f} chars)")

# 5. storage.samples: { [recipe_name] = { buffer = {...}, head = N, count = N } }
samples_size = OVERHEAD_TABLE  # outer table
total_samples = 0
total_waiting_entries = 0
for name, samples in recipes.items():
    # ring buffer wrapper: table + head + count + buffer table
    rb_overhead = OVERHEAD_TABLE + 3 * (OVERHEAD_STR("buffer") + OVERHEAD_ENTRY) + OVERHEAD_NUM * 2
    # recipe key
    rb_overhead += OVERHEAD_STR(name) + OVERHEAD_ENTRY

    # each sample: table + tick + total_machines + optional waiting table
    sample_bytes = 0
    for s in samples:
        sample_bytes += OVERHEAD_TABLE + OVERHEAD_ENTRY  # slot in buffer array
        sample_bytes += OVERHEAD_STR("tick") + OVERHEAD_NUM + OVERHEAD_ENTRY
        sample_bytes += OVERHEAD_STR("total_machines") + OVERHEAD_NUM + OVERHEAD_ENTRY
        total_samples += 1
        if "w" in s and s["w"]:
            sample_bytes += OVERHEAD_STR("waiting") + OVERHEAD_TABLE + OVERHEAD_ENTRY
            for ing_name, count in s["w"].items():
                sample_bytes += OVERHEAD_STR(ing_name) + OVERHEAD_NUM + OVERHEAD_ENTRY
                total_waiting_entries += 1

    samples_size += rb_overhead + sample_bytes

print(f"samples:           {samples_size/1024:7.1f} KB  ({len(recipes)} recipes, {total_samples} samples, {total_waiting_entries} waiting entries)")

# 6. sample_cursor: single number
print(f"sample_cursor:     {OVERHEAD_NUM/1024:7.1f} KB")

print(f"{'':19s}-------")
total = te_size + el_size + eli_size + rc_size + samples_size + OVERHEAD_NUM
print(f"TOTAL:             {total/1024:7.1f} KB")
print()

# Breakdown of samples by component
print("--- samples breakdown ---")
# Recalculate with breakdown
size_keys = 0
size_rb_overhead = 0
size_sample_fixed = 0
size_waiting = 0
for name, samples in recipes.items():
    size_keys += OVERHEAD_STR(name) + OVERHEAD_ENTRY
    size_rb_overhead += OVERHEAD_TABLE + 3 * (OVERHEAD_STR("buffer") + OVERHEAD_ENTRY) + OVERHEAD_NUM * 2
    for s in samples:
        size_sample_fixed += OVERHEAD_TABLE + OVERHEAD_ENTRY + OVERHEAD_STR("tick") + OVERHEAD_NUM + OVERHEAD_ENTRY + OVERHEAD_STR("total_machines") + OVERHEAD_NUM + OVERHEAD_ENTRY
        if "w" in s and s["w"]:
            size_waiting += OVERHEAD_STR("waiting") + OVERHEAD_TABLE + OVERHEAD_ENTRY
            for ing_name, count in s["w"].items():
                size_waiting += OVERHEAD_STR(ing_name) + OVERHEAD_NUM + OVERHEAD_ENTRY

print(f"  recipe keys:     {size_keys/1024:7.1f} KB")
print(f"  ring buf overhead:{size_rb_overhead/1024:6.1f} KB")
print(f"  sample fixed:    {size_sample_fixed/1024:7.1f} KB  (tick + total_machines per sample)")
print(f"  waiting tables:  {size_waiting/1024:7.1f} KB  ({total_waiting_entries} ingredient entries)")
print()

# What if MAX_BUFFER = 30?
ratio = 30 / MAX_BUFFER
print(f"--- with MAX_BUFFER=30 ---")
print(f"  samples would be ~{samples_size * ratio / 1024:.1f} KB (vs {samples_size/1024:.1f} KB)")
print(f"  total would be   ~{(total - samples_size + samples_size * ratio)/1024:.1f} KB (vs {total/1024:.1f} KB)")
