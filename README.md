# Bottleneck Analyzer

A Factorio 2.0 mod that answers the question: **"Why is this machine not working?"**

Bottleneck Analyzer continuously samples every crafting building in your factory, records which ingredients are missing when machines stall, and shows you aggregate statistics so you can pinpoint your supply chain's weakest links. Works with all assembling machines, furnaces, rocket silos, and any modded buildings that use these types (Pyanodons, Krastorio, etc.).

## How It Works

Every second (configurable), the mod snapshots every crafting machine's status. For machines that are starved of ingredients, it checks exactly which inputs are missing. These samples are aggregated per recipe and stored in a ring buffer, giving you a rolling history of bottleneck data.

When you open the GUI, you pick an item and instantly see what percentage of the time each ingredient was the bottleneck — across all machines producing that item.

## Features

- **Per-ingredient bottleneck percentages** — see at a glance whether iron plates or copper wire is the real problem
- **Time-slice filtering** — view bottleneck data for the last 1m, 5m, 10m, 30m, 1h, or all time
- **Multi-recipe support** — items produced by multiple recipes get tabbed views (only recipes with data are shown)
- **Click-through navigation** — click any ingredient to drill down into its bottlenecks, with a back button to retrace your steps
- **Color-coded bars** — green (<20%), yellow (20-50%), red (>50%) at a glance
- **Informative tooltips** — hover over any bar to see e.g. *"[iron-gear-wheel] was waiting for [iron-plate] 73.2% of the time"*
- **Bounded memory** — ring buffer caps at 500 samples per recipe, old data is automatically overwritten
- **Configurable sample rate** — adjust from 0.1s to 60s in mod settings

## Usage

1. Click the Bottleneck Analyzer button in the **bottom shortcut bar** (you may need to pin it via the shortcut bar's configure menu)
2. Select an item using the item chooser
3. View the ingredient breakdown — taller bars mean bigger bottlenecks
4. Click an ingredient name to navigate to that item's bottleneck view
5. Use the back button to return to the previous item
6. Adjust the time window with the filter buttons

## Compatibility

Works with any building that uses Factorio's crafting machine types — assembling machines, furnaces, and rocket silos. This includes modded buildings like Pyanodons complexes, Krastorio machines, and any other mod that adds crafting entities.

## Settings

| Setting | Default | Range | Description |
|---|---|---|---|
| Sample Rate (seconds) | 1.0 | 0.1 – 60.0 | How often machines are sampled. Lower = more granular data, higher CPU/memory usage. |

## Requirements

- Factorio 2.0+
- Base mod
