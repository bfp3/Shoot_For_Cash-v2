class_name PDFrameTimeBreakdown
extends RefCounted

## Estimated frame-time category breakdown for the donut chart.
##
## Godot does not expose per-system GPU/CPU timers to scripts (those live in the
## editor profiler). This class uses exact monitors where available and splits the
## remaining frame budget with documented heuristics.

const CATEGORY_RENDERING := &"rendering"
const CATEGORY_PHYSICS := &"physics"
const CATEGORY_SCRIPTS := &"scripts"
const CATEGORY_AUDIO := &"audio"
const CATEGORY_PARTICLES := &"particles"
const CATEGORY_LIGHTING := &"lighting"
const CATEGORY_NAVIGATION := &"navigation"
const CATEGORY_ANIMATION := &"animation"
const CATEGORY_UI := &"ui"
const CATEGORY_OTHER := &"other"

const CATEGORY_ORDER: Array[StringName] = [
	CATEGORY_RENDERING,
	CATEGORY_PHYSICS,
	CATEGORY_SCRIPTS,
	CATEGORY_LIGHTING,
	CATEGORY_PARTICLES,
	CATEGORY_NAVIGATION,
	CATEGORY_AUDIO,
	CATEGORY_ANIMATION,
	CATEGORY_UI,
	CATEGORY_OTHER,
]

const CATEGORY_LABELS := {
	CATEGORY_RENDERING: "Rendering",
	CATEGORY_PHYSICS: "Physics",
	CATEGORY_SCRIPTS: "Scripts",
	CATEGORY_AUDIO: "Audio",
	CATEGORY_PARTICLES: "Particles",
	CATEGORY_LIGHTING: "Lighting",
	CATEGORY_NAVIGATION: "Navigation",
	CATEGORY_ANIMATION: "Animation",
	CATEGORY_UI: "UI",
	CATEGORY_OTHER: "Other",
}

const CATEGORY_COLORS := {
	CATEGORY_RENDERING: Color(0.35, 0.62, 0.95),
	CATEGORY_PHYSICS: Color(0.95, 0.55, 0.28),
	CATEGORY_SCRIPTS: Color(0.45, 0.82, 0.55),
	CATEGORY_AUDIO: Color(0.72, 0.45, 0.90),
	CATEGORY_PARTICLES: Color(0.95, 0.78, 0.30),
	CATEGORY_LIGHTING: Color(0.95, 0.88, 0.55),
	CATEGORY_NAVIGATION: Color(0.35, 0.78, 0.82),
	CATEGORY_ANIMATION: Color(0.90, 0.45, 0.55),
	CATEGORY_UI: Color(0.55, 0.70, 0.75),
	CATEGORY_OTHER: Color(0.45, 0.48, 0.55),
}

## Reused result dictionary: category -> milliseconds
var _ms: Dictionary = {}
## Reused percentages: category -> 0..1
var _pct: Dictionary = {}


func get_milliseconds() -> Dictionary:
	return _ms


func get_percentages() -> Dictionary:
	return _pct


func get_total_ms() -> float:
	var total := 0.0
	for key in _ms.keys():
		total += float(_ms[key])
	return total


## Rebuilds breakdown from smoothed profiler metrics. Avoids allocating new dicts.
func update_from_metrics(metrics: Dictionary) -> void:
	var frame_ms: float = maxf(float(metrics.get(PDMetricIds.FRAME_TIME_MS, 16.67)), 0.001)
	var physics_ms: float = maxf(float(metrics.get(PDMetricIds.PHYSICS_TIME_MS, 0.0)), 0.0)
	var nav_ms: float = maxf(float(metrics.get(PDMetricIds.NAVIGATION_TIME_MS, 0.0)), 0.0)
	var process_ms: float = maxf(float(metrics.get(PDMetricIds.PROCESS_TIME_MS, 0.0)), 0.0)

	# Exact slices from engine monitors.
	_ms[CATEGORY_PHYSICS] = physics_ms
	_ms[CATEGORY_NAVIGATION] = nav_ms

	# Remaining budget inside the displayed frame time.
	var accounted := physics_ms + nav_ms
	var remainder := maxf(frame_ms - accounted, 0.0)

	# Weight heuristics for subdividing the idle/process remainder.
	# process_ms overlaps conceptually with rendering+scripts; use it as a soft guide.
	var draw_calls: float = maxf(float(metrics.get(PDMetricIds.DRAW_CALLS, 0.0)), 0.0)
	var lights: float = maxf(float(metrics.get(PDMetricIds.ACTIVE_LIGHTS, 0.0)), 0.0)
	var shadows: float = maxf(float(metrics.get(PDMetricIds.SHADOW_CASTERS, 0.0)), 0.0)
	var particles: float = maxf(float(metrics.get(PDMetricIds.ACTIVE_PARTICLES, 0.0)), 0.0)
	var voices: float = maxf(float(metrics.get(PDMetricIds.AUDIO_VOICES, 0.0)), 0.0)
	var nodes: float = maxf(float(metrics.get(PDMetricIds.NODE_COUNT, 1.0)), 1.0)

	var w_render := 3.0 + draw_calls * 0.01
	var w_lighting := 0.5 + lights * 0.35 + shadows * 0.8
	var w_particles := 0.2 + particles * 0.45
	var w_audio := 0.15 + voices * 0.03
	var w_animation := 0.35 + nodes * 0.00015
	var w_ui := 0.4 + draw_calls * 0.002
	var w_scripts := 1.2 + maxf(process_ms - physics_ms, 0.0) * 0.05
	var w_other := 0.5

	var weight_sum := w_render + w_lighting + w_particles + w_audio + w_animation + w_ui + w_scripts + w_other
	if weight_sum <= 0.0:
		weight_sum = 1.0

	_ms[CATEGORY_RENDERING] = remainder * (w_render / weight_sum)
	_ms[CATEGORY_LIGHTING] = remainder * (w_lighting / weight_sum)
	_ms[CATEGORY_PARTICLES] = remainder * (w_particles / weight_sum)
	_ms[CATEGORY_AUDIO] = remainder * (w_audio / weight_sum)
	_ms[CATEGORY_ANIMATION] = remainder * (w_animation / weight_sum)
	_ms[CATEGORY_UI] = remainder * (w_ui / weight_sum)
	_ms[CATEGORY_SCRIPTS] = remainder * (w_scripts / weight_sum)
	_ms[CATEGORY_OTHER] = remainder * (w_other / weight_sum)

	var total := get_total_ms()
	if total <= 0.0:
		total = frame_ms
	for cat in CATEGORY_ORDER:
		_pct[cat] = float(_ms.get(cat, 0.0)) / total
