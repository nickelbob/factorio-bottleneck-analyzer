import json

path = r"C:\Users\nicku\AppData\Roaming\Factorio\script-output\bottleneck-analyzer-perf.jsonl"
ticks = []
sweeps = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        if obj["t"] == "tk":
            ticks.append(obj)
        elif obj["t"] == "sw":
            sweeps.append(obj)

waits = [t["wait"] for t in ticks]
procs = [t["proc"] for t in ticks]
print(f"Ticks: {len(ticks)}")
print(f"Sweeps: {len(sweeps)}")
print(f"Wait - min={min(waits)}, max={max(waits)}, avg={sum(waits)/len(waits):.1f}")
std = (sum((w - sum(waits)/len(waits))**2 for w in waits)/len(waits))**0.5
print(f"Wait std dev: {std:.1f}")
print(f"Proc - min={min(procs)}, max={max(procs)}, avg={sum(procs)/len(procs):.1f}")
print()

# Show wait values for first 60 ticks (roughly one sweep)
print("First 60 tick waits:")
print(waits[:60])
print()
print("Last 60 tick waits:")
print(waits[-60:])
print()

# Check if this data is pre or post shuffle by looking at sweep ticks
if sweeps:
    print(f"First sweep at tick {sweeps[0]['tick']}, last at {sweeps[-1]['tick']}")
    print(f"First tick data at {ticks[0]['tick']}, last at {ticks[-1]['tick']}")

# Distribution histogram
buckets = {}
for w in waits:
    b = (w // 10) * 10
    buckets[b] = buckets.get(b, 0) + 1
print()
print("Wait distribution (bucket: count):")
for b in sorted(buckets.keys()):
    bar = "#" * (buckets[b] // 5)
    print(f"  {b:3d}-{b+9:3d}: {buckets[b]:4d} {bar}")
