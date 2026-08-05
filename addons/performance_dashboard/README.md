# Performance Dashboard

Debug-only in-game profiler and optimisation target dashboard for Godot 4.

## Usage

### Master switch (arm / disarm)

The tool can sit completely inert even in debug builds:

| Control | Effect |
|---|---|
| **Project → Project Settings → `performance_dashboard/enabled`** | Persistent on/off between runs |
| **Project → Tools → Performance Dashboard: On/Off** | Same setting, one click |
| **Shift + Ctrl + O** (during play) | Arm/disarm for the **current session** only |

When **disarmed**: no overlay, no sampling, Shift+O does nothing.

### Overlay (while armed)

- **Shift + O** — show / hide the dashboard.
- When the overlay is hidden, sampling and UI updates stop.
- Release exports never construct the tool (`OS.is_debug_build()` gate).

## Architecture

```
performance_dashboard_service.gd   Autoload — arm switch, profiler + UI, input
core/
  performance_profiler.gd          Data collection only
  metric_ids.gd / registry / ...   Metric system
ui/
  performance_profiler_ui.gd       Dashboard layout
  graphs/                          Bar + donut charts
docs/LIMITATIONS.md                What each metric really means
```

## Script API

```gdscript
PerformanceDashboard.set_tool_enabled(false)        # disarm + persist setting
PerformanceDashboard.set_tool_enabled(true, false)  # arm this session only
PerformanceDashboard.is_tool_enabled()
PerformanceDashboard.show_dashboard()
PerformanceDashboard.hide_dashboard()
```

## Adding a metric

1. Id in `core/metric_ids.gd`
2. Definition in `core/metric_registry.gd`
3. Sample in `PerformanceProfiler`
4. Target in `profiles/*.tres`
