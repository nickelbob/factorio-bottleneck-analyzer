# Visualizers

Standalone browser tools for analyzing exported Bottleneck Analyzer data. These are developer/player tools that run outside Factorio — they are not part of the mod itself.

## Files

### recipe-visualizer.html

Visualizes per-recipe bottleneck data over time. Drop in the JSON from `/bottleneck-dump`.

- Top bottlenecks overview
- Per-recipe machine counts over time
- Ingredient waiting breakdowns with charts
- Bottleneck percentage timelines

**Export command:** `/bottleneck-dump` → `script-output/bottleneck-analyzer-recipes.json`

### recipe-graph.html

Interactive recipe dependency graph. Drop in the JSON from `/bottleneck-graph`. Shows recipes as nodes and ingredient relationships as edges, color-coded by bottleneck severity.

- **Progressive exploration** — pick a recipe from the sidebar, double-click nodes to expand neighbors. Does not load the full graph at once (1000+ recipes would freeze the browser).
- **Layered layout** — raw ingredients (sources) at the bottom, final products (sinks) at the top. No physics simulation; nodes stay where placed, drag to reposition.
- **Bottleneck Edges Only** toggle — hides all non-bottleneck edges and any nodes with no bottleneck connections. Useful for cutting through the noise.
- **Color coding** — green (<20%), yellow (20-50%), red (>50%) for both nodes and edges. Node size scales with machine count.
- **Detail panel** — click a node to see its ingredients, products, waiting percentages, and in-view suppliers/consumers. Links to expand hidden neighbors.

**Export command:** `/bottleneck-graph` → `script-output/bottleneck-analyzer-graph.json`

### analyze_graph.py

Quick Python script to analyze the graph JSON and understand scale before visualizing. Prints recipe count, edge count, which items cause the most edges, and which items have the most producers. Useful for debugging graph performance.

**Usage:** Edit the file path at the top, then `python analyze_graph.py`

## Where to find exported files

All exports land in Factorio's `script-output` directory:
- Windows: `%APPDATA%\Factorio\script-output\`
- Linux: `~/.factorio/script-output/`
- macOS: `~/Library/Application Support/factorio/script-output/`
