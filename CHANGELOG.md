# Changelog

## 0.3.5

- **Performance**: Status caching — skip `entity.status` calls on machines that were working last sweep (10% recheck rate, ~10% CPU reduction)
- **Performance**: Fisher-Yates shuffle on entity list for more even per-tick workload distribution
- **Fix**: Re-enabled building recipe filter (recipes that produce placeable items are excluded from results)
- **Cleanup**: Stripped all profiling/debug overhead from production code, moved perf testing tools to `perf-testing/`

## 0.3.1

- **Fix**: Reduced save file size by removing redundant cached data from storage
- **Fix**: GUI layout and display fixes

## 0.3.0

- **Performance**: Chunked per-tick sampling — work is spread across ticks so each tick only processes a small batch instead of all machines at once
- **Performance**: Recipe cache to avoid repeated prototype lookups

## 0.2.0

- **Performance**: Fixed major performance issue with large factories
- **Feature**: Added `/bottleneck-dump` command to export recipe data as JSON
- **Feature**: Added `/bottleneck-status` command for tracking diagnostics
- **Feature**: Added `/bottleneck-reset` command to clear sample data
- **UI**: Ingredients sorted by severity (highest bottleneck first)
- **UI**: Scrollable recipe area for recipes with many ingredients

## 0.1.3

- Keyboard shortcut (Ctrl+Shift+B) to toggle GUI
- Esc to close window
- Clickable fluid ingredients for drill-down navigation
- Fixed focus steal when GUI opens

## 0.1.2

- Sort ingredients by severity
- Scrollable recipe area
- Removed top bottlenecks panel (redundant with per-recipe view)

## 0.1.1

- Fixed item selector blanking when switching items
- Fixed signal type parsing for fluids

## 0.1.0

- Initial release
- Per-ingredient bottleneck percentages
- Time-slice filtering (1m, 5m, 10m, 30m, 1h, all)
- Multi-recipe tabbed views
- Click-through ingredient navigation with back button
- Color-coded bars (green/yellow/red)
- Configurable sample rate (0.1s – 300s)
- Ring buffer capped at 100 samples per recipe
- Works with assembling machines, furnaces, and modded crafting entities
