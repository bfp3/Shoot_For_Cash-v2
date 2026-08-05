# Performance Dashboard — Engine Limitations

This tool uses Godot's public `Performance` / `RenderingServer` / scene APIs.
Several requested numbers are **not** exposed as exact GPU/CPU timers. Below is what each important metric actually represents.

## Exact (or near-exact) engine monitors

| Metric | Source | Notes |
|---|---|---|
| FPS | `Performance.TIME_FPS` | Updated about once per second by the engine. |
| Frame Time | `1000 / FPS` | Derived display frame time, not a GPU timestamp. |
| Process Time | `Performance.TIME_PROCESS` | Idle/process frame duration (seconds→ms). Includes a lot of non-script work. |
| Physics Time | `Performance.TIME_PHYSICS_PROCESS` | Physics step duration. |
| Navigation Time | `Performance.TIME_NAVIGATION_PROCESS` | Navigation map + avoidance step. |
| Draw Calls | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | **All** draw calls (3D + 2D + UI). UI glyphs inflate this. |
| Render / Visible Objects | `RENDER_TOTAL_OBJECTS_IN_FRAME` | Submitted objects; culled objects are excluded. |
| Primitives | `RENDER_TOTAL_PRIMITIVES_IN_FRAME` | Vertices/indices; includes depth prepass + shadow passes (often 2–3× scene geometry). |
| Video / Texture / Buffer Memory | `RENDER_*_MEM_USED` | Bytes reported by the renderer. |
| Static Memory | `MEMORY_STATIC` | **Debug builds only** — returns 0 in release. |
| Node / Object / Resource counts | `OBJECT_*` | Engine object tallies. |
| Orphan Nodes | `OBJECT_ORPHAN_NODE_COUNT` | Debug builds only. |
| Physics 2D/3D objects & pairs | `PHYSICS_*` | Active rigid bodies / collision pairs. |
| Navigation agents/regions/polygons | `NAVIGATION_*` | Combined 2D+3D server counts. |
| Audio Latency | `AUDIO_OUTPUT_LATENCY` | Not voice count. |
| Pipeline Compiles (Draw) | `PIPELINE_COMPILATIONS_DRAW` | Useful stutter detector; not a continuous cost. |
| GPU name / vendor / API | `RenderingServer.get_video_adapter_*` | Informational, not a utilisation %. |
| CPU name / thread count | `OS.get_processor_*` | Informational. **No OS CPU utilisation %** is available from Godot. |

## Estimated / proxied metrics

| Metric | How it is measured | Limitation |
|---|---|---|
| Triangles (est.) | `primitives / 3` | Wrong for strips/lines/points and still includes extra passes. Treat as a rough scale. |
| Active Lights | Count of `Light3D` nodes in the tree | Not the number of lights affecting the current view / GPU light list. |
| Shadow Casters | Lights with `shadow_enabled` | Does not equal shadow-casting mesh count. |
| Active Particles | Emitting `GPU/CPUParticles* ` nodes | Node count, not particle instance count or GPU cost. |
| Audio Voices | Playing `AudioStreamPlayer*` nodes | Not hardware voices / polyphony inside a single player. |
| Frame breakdown donut | See below | Most slices are **heuristic**, not profiler timers. |

## Frame-time donut categories

Godot does not expose script-accessible per-pass timings for Rendering, Lighting, Particles, Animation, UI, etc. (those exist in the editor Debugger profiler, not as `Performance` monitors).

This dashboard therefore:

1. Uses **exact** ms for **Physics** and **Navigation**.
2. Takes the remaining display frame budget (`frame_time − physics − navigation`).
3. Splits that remainder across Rendering / Scripts / Lighting / Particles / Audio / Animation / UI / Other using weights derived from draw calls, light counts, particle nodes, audio players, and node count.

**Interpret the donut as a live relative hint**, not a substitute for Godot's built-in Profiler or Remotery/RenderDoc.

## CPU / GPU utilisation

- **CPU %**: not available through Godot's scripting API in a portable way.
- **GPU % / GPU time**: not available without vendor tools or engine profiler instrumentation.
- Use process/physics times + FPS as CPU-side pressure indicators; use draw calls, primitives, lights, and shadows as GPU-side pressure indicators.

## Cost of this tool

- Inactive (hidden): no `_process` on the profiler, UI not updating.
- Active: engine monitors every frame; scene walks for lights/particles/audio on a short interval; UI refresh ~8 Hz with EMA smoothing.
- Always disabled in release via `OS.is_debug_build()`.
