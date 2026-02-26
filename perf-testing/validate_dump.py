import json
import sys

path = r"C:\Users\nicku\AppData\Roaming\Factorio\script-output\bottleneck-analyzer-recipes.json"
with open(path) as f:
    data = json.load(f)

print("Valid JSON")
recipes = data["recipes"]
print(f"Recipes: {len(recipes)}")
total = sum(len(s) for s in recipes.values())
print(f"Total samples: {total}")

for name in recipes:
    if "'" in name or '"' in name or "<" in name:
        print(f"Special chars in: {name}")

empty = [n for n, s in recipes.items() if len(s) == 0]
if empty:
    print(f"Empty recipes: {empty}")
else:
    print("No empty recipes")
