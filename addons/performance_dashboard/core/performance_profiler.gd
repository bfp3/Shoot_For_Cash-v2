class_name PerformanceProfiler
extends Node

## Collects engine performance metrics. No UI — consumers read via getters / signals.
##
## Usage:
##   profiler.set_active(true)
##   var fps := profiler.get_metric(PDMetricIds.FPS)
##   var all := profiler.get_all_metrics()  # smoothed snapshot

signal metrics_updated(metrics: Dictionary)
signal active_changed(is_active: bool)

## Exponential moving average factor for smoothed values (0..1). Higher = more responsive.
@export_range(0.01, 1.0, 0.01) var smoothing_alpha: float = 0.22
## How often expensive scene walks run while active (seconds).
@export_range(0.05, 2.0, 0.05) var scene_sample_interval: float = 0.25

var registry: PDMetricRegistry = PDMetricRegistry.new()
var breakdown: PDFrameTimeBreakdown = PDFrameTimeBreakdown.new()

## GPU / device info captured once (empty strings if unavailable).
var gpu_adapter_name: String = ""
var gpu_adapter_vendor: String = ""
var gpu_api_version: String = ""
var cpu_name: String = ""
var processor_count: int = 0

var _active: bool = false
var _raw: Dictionary = {}
var _smoothed: Dictionary = {}
var _scene_sample_left: float = 0.0

# Cached scene-walk counters (updated on interval, not every frame).
var _cached_lights: float = 0.0
var _cached_shadows: float = 0.0
var _cached_particles: float = 0.0
var _cached_audio_voices: float = 0.0
## Reused DFS stack for scene cost sampling (avoids reallocating each walk).
var _walk_stack: Array[Node] = []


func _ready() -> void:
	set_process(false)
	_capture_device_info()
	_init_metric_storage()


func is_active() -> bool:
	return _active


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	set_process(value)
	if value:
		_scene_sample_left = 0.0
		_sample_scene_costs()
		_sample_frame()
	active_changed.emit(_active)


func get_registry() -> PDMetricRegistry:
	return registry


func get_breakdown() -> PDFrameTimeBreakdown:
	return breakdown


func get_metric(id: StringName) -> float:
	return float(_smoothed.get(id, 0.0))


func get_metric_raw(id: StringName) -> float:
	return float(_raw.get(id, 0.0))


## Returns the smoothed metrics dictionary (do not mutate).
func get_all_metrics() -> Dictionary:
	return _smoothed


func get_all_metrics_raw() -> Dictionary:
	return _raw


func get_metric_ids() -> Array:
	return _smoothed.keys()


func has_metric(id: StringName) -> bool:
	return _smoothed.has(id)


## Register and start tracking an extra metric id (value supplied by caller each frame).
func ensure_metric(id: StringName, initial: float = 0.0) -> void:
	if not _raw.has(id):
		_raw[id] = initial
		_smoothed[id] = initial


## Push a custom sample (for future extensions / game-specific counters).
func push_custom_sample(id: StringName, value: float) -> void:
	ensure_metric(id)
	_raw[id] = value
	_smoothed[id] = lerpf(float(_smoothed[id]), value, smoothing_alpha)


func get_device_info_text() -> String:
	var parts: PackedStringArray = []
	if not gpu_adapter_name.is_empty():
		parts.append("GPU: %s" % gpu_adapter_name)
	if not gpu_adapter_vendor.is_empty():
		parts.append("Vendor: %s" % gpu_adapter_vendor)
	if not gpu_api_version.is_empty():
		parts.append("API: %s" % gpu_api_version)
	if not cpu_name.is_empty():
		parts.append("CPU: %s (%d threads)" % [cpu_name, processor_count])
	elif processor_count > 0:
		parts.append("CPU threads: %d" % processor_count)
	return "  |  ".join(parts)


func _process(delta: float) -> void:
	if not _active:
		return
	_scene_sample_left -= delta
	if _scene_sample_left <= 0.0:
		_scene_sample_left = scene_sample_interval
		_sample_scene_costs()
	_sample_frame()
	breakdown.update_from_metrics(_smoothed)
	metrics_updated.emit(_smoothed)


func _init_metric_storage() -> void:
	for def in registry.get_all_definitions():
		_raw[def.id] = 0.0
		_smoothed[def.id] = 0.0


func _capture_device_info() -> void:
	processor_count = OS.get_processor_count()
	cpu_name = OS.get_processor_name()
	# RenderingServer GPU queries are available in Godot 4.
	if RenderingServer.has_method("get_video_adapter_name"):
		gpu_adapter_name = str(RenderingServer.get_video_adapter_name())
	if RenderingServer.has_method("get_video_adapter_vendor"):
		gpu_adapter_vendor = str(RenderingServer.get_video_adapter_vendor())
	if RenderingServer.has_method("get_video_adapter_api_version"):
		gpu_api_version = str(RenderingServer.get_video_adapter_api_version())


func _sample_frame() -> void:
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	if fps <= 0.0:
		fps = float(Engine.get_frames_per_second())
	var frame_ms := 1000.0 / maxf(fps, 0.001)

	_set_raw(PDMetricIds.FPS, fps)
	_set_raw(PDMetricIds.FRAME_TIME_MS, frame_ms)
	_set_raw(PDMetricIds.PROCESS_TIME_MS, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_set_raw(PDMetricIds.PHYSICS_TIME_MS, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_set_raw(PDMetricIds.NAVIGATION_TIME_MS, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)

	_set_raw(PDMetricIds.DRAW_CALLS, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_set_raw(PDMetricIds.RENDER_OBJECTS, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_set_raw(PDMetricIds.VISIBLE_OBJECTS, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_set_raw(PDMetricIds.PRIMITIVES, primitives)
	_set_raw(PDMetricIds.TRIANGLES_EST, primitives / 3.0)

	_set_raw(PDMetricIds.PHYSICS_3D_OBJECTS, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	_set_raw(PDMetricIds.PHYSICS_3D_PAIRS, Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	_set_raw(PDMetricIds.PHYSICS_2D_OBJECTS, Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))

	_set_raw(PDMetricIds.ACTIVE_LIGHTS, _cached_lights)
	_set_raw(PDMetricIds.SHADOW_CASTERS, _cached_shadows)
	_set_raw(PDMetricIds.ACTIVE_PARTICLES, _cached_particles)
	_set_raw(PDMetricIds.AUDIO_VOICES, _cached_audio_voices)
	_set_raw(PDMetricIds.AUDIO_LATENCY_MS, Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0)

	const BYTES_TO_MB := 1.0 / (1024.0 * 1024.0)
	_set_raw(PDMetricIds.TEXTURE_MEM_MB, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) * BYTES_TO_MB)
	_set_raw(PDMetricIds.BUFFER_MEM_MB, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) * BYTES_TO_MB)
	_set_raw(PDMetricIds.VIDEO_MEM_MB, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * BYTES_TO_MB)
	_set_raw(PDMetricIds.STATIC_MEM_MB, Performance.get_monitor(Performance.MEMORY_STATIC) * BYTES_TO_MB)

	_set_raw(PDMetricIds.OBJECT_COUNT, Performance.get_monitor(Performance.OBJECT_COUNT))
	_set_raw(PDMetricIds.NODE_COUNT, Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_set_raw(PDMetricIds.RESOURCE_COUNT, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_set_raw(PDMetricIds.ORPHAN_NODE_COUNT, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	_set_raw(PDMetricIds.NAV_AGENTS, Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT))
	_set_raw(PDMetricIds.NAV_REGIONS, Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT))
	_set_raw(PDMetricIds.NAV_POLYGONS, Performance.get_monitor(Performance.NAVIGATION_POLYGON_COUNT))

	_set_raw(PDMetricIds.PIPELINE_COMPILATIONS_DRAW, Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))

	_apply_smoothing()


func _set_raw(id: StringName, value: float) -> void:
	_raw[id] = value


func _apply_smoothing() -> void:
	for id in _raw.keys():
		var target := float(_raw[id])
		var current := float(_smoothed.get(id, target))
		_smoothed[id] = lerpf(current, target, smoothing_alpha)


func _sample_scene_costs() -> void:
	# Tree walk is relatively expensive — only while profiler is active, on an interval.
	var lights := 0
	var shadows := 0
	var particles := 0
	var voices := 0

	var root := get_tree().root if get_tree() else null
	if root == null:
		return

	_walk_stack.clear()
	_walk_stack.append(root)
	while not _walk_stack.is_empty():
		var node: Node = _walk_stack.pop_back()
		for child in node.get_children():
			_walk_stack.append(child)

		if node is Light3D:
			lights += 1
			if (node as Light3D).shadow_enabled:
				shadows += 1
		elif node is GPUParticles3D:
			if (node as GPUParticles3D).emitting:
				particles += 1
		elif node is CPUParticles3D:
			if (node as CPUParticles3D).emitting:
				particles += 1
		elif node is GPUParticles2D:
			if (node as GPUParticles2D).emitting:
				particles += 1
		elif node is CPUParticles2D:
			if (node as CPUParticles2D).emitting:
				particles += 1
		elif node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			if node.has_method("is_playing") and node.call("is_playing"):
				voices += 1

	_cached_lights = float(lights)
	_cached_shadows = float(shadows)
	_cached_particles = float(particles)
	_cached_audio_voices = float(voices)
