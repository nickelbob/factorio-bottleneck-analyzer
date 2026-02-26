import json

f = open(r"C:\Users\nicku\AppData\Roaming\Factorio\script-output\bottleneck-analyzer-graph.json")
data = json.load(f)
recipes = data["recipes"]
print(f"Recipes: {len(recipes)}")

producer_map = {}
for name, info in recipes.items():
    for p in info["products"]:
        key = p["type"] + ":" + p["name"]
        if key not in producer_map:
            producer_map[key] = []
        producer_map[key].append(name)

edges = 0
for name, info in recipes.items():
    for ing in info["ingredients"]:
        key = ing["type"] + ":" + ing["name"]
        producers = producer_map.get(key, [])
        for p in producers:
            if p != name:
                edges += 1

print(f"Edges: {edges}")
print(f"Avg edges per recipe: {edges / len(recipes):.1f}")

multi = [k for k, v in producer_map.items() if len(v) > 5]
print(f"Items produced by >5 recipes: {len(multi)}")
for k in sorted(multi, key=lambda x: -len(producer_map[x]))[:10]:
    print(f"  {k}: {len(producer_map[k])} producers")

bn = [n for n, i in recipes.items() if "waiting_pct" in i]
print(f"Recipes with bottlenecks: {len(bn)}")

# Edge explosion: what items cause the most edges?
edge_counts = {}
for name, info in recipes.items():
    for ing in info["ingredients"]:
        key = ing["type"] + ":" + ing["name"]
        producers = producer_map.get(key, [])
        ct = sum(1 for p in producers if p != name)
        if ct > 0:
            edge_counts[ing["name"]] = edge_counts.get(ing["name"], 0) + ct

print(f"\nTop 15 ingredients by edge count:")
for name, ct in sorted(edge_counts.items(), key=lambda x: -x[1])[:15]:
    print(f"  {name}: {ct} edges")
