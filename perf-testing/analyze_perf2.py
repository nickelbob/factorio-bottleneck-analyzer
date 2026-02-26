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

# Analyze per-sweep: group ticks by which sweep they belong to
# A sweep starts when cursor resets to 1
sweep_groups = []
current_group = []
for t in ticks:
    if t["cur"] == 1 and current_group:
        sweep_groups.append(current_group)
        current_group = []
    current_group.append(t)
if current_group:
    sweep_groups.append(current_group)

print(f"Total ticks: {len(ticks)}, Sweeps: {len(sweep_groups)}")
print()
print(f"{'Sweep':>5} {'Ticks':>5} {'AvgWait':>8} {'StdDev':>8} {'Min':>5} {'Max':>5} {'StartTick':>12}")
print("-" * 60)

for i, group in enumerate(sweep_groups):
    waits = [t["wait"] for t in group]
    avg = sum(waits) / len(waits)
    std = (sum((w - avg)**2 for w in waits) / len(waits)) ** 0.5
    print(f"{i+1:5d} {len(group):5d} {avg:8.1f} {std:8.1f} {min(waits):5d} {max(waits):5d} {group[0]['tick']:12d}")

# Check if the perf file has data from multiple sessions (big tick gaps)
print()
print("Checking for session boundaries (tick gaps > 1000):")
for i in range(1, len(ticks)):
    gap = ticks[i]["tick"] - ticks[i-1]["tick"]
    if gap > 1000:
        print(f"  Gap of {gap} ticks between tick {ticks[i-1]['tick']} and {ticks[i]['tick']}")

# Autocorrelation of wait - do consecutive batches have correlated wait counts?
if len(ticks) > 10:
    waits = [t["wait"] for t in ticks]
    avg = sum(waits) / len(waits)
    var = sum((w - avg)**2 for w in waits) / len(waits)
    if var > 0:
        autocorr_1 = sum((waits[i] - avg) * (waits[i+1] - avg) for i in range(len(waits)-1)) / ((len(waits)-1) * var)
        autocorr_2 = sum((waits[i] - avg) * (waits[i+2] - avg) for i in range(len(waits)-2)) / ((len(waits)-2) * var)
        print()
        print(f"Wait autocorrelation lag-1: {autocorr_1:.3f} (0 = random, 1 = perfectly correlated)")
        print(f"Wait autocorrelation lag-2: {autocorr_2:.3f}")
