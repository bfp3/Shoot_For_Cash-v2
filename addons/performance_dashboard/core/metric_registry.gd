class_name PDMetricRegistry
extends RefCounted

## Central registry of metric definitions.
## To add a metric: add an id in PDMetricIds, register it here, sample it in PerformanceProfiler,
## and (optionally) add a target in each PerformanceTargetProfile.

var _defs: Dictionary = {} # StringName -> PDMetricDefinition


func _init() -> void:
	_register_defaults()


func get_definition(id: StringName) -> PDMetricDefinition:
	return _defs.get(id) as PDMetricDefinition


func get_all_definitions() -> Array[PDMetricDefinition]:
	var out: Array[PDMetricDefinition] = []
	for id in _defs.keys():
		out.append(_defs[id])
	return out


func get_bar_chart_definitions() -> Array[PDMetricDefinition]:
	var out: Array[PDMetricDefinition] = []
	for id in PDMetricIds.BAR_CHART_METRICS:
		var def := get_definition(id)
		if def != null and def.show_in_bar_chart:
			out.append(def)
	return out


func has_metric(id: StringName) -> bool:
	return _defs.has(id)


func register(def: PDMetricDefinition) -> void:
	_defs[def.id] = def


func _register_defaults() -> void:
	_add(PDMetricIds.FPS, "FPS", "fps", true, "Frames rendered in the last second (Performance.TIME_FPS).", true)
	_add(PDMetricIds.FRAME_TIME_MS, "Frame Time", "ms", false, "Derived frame time from FPS (1000 / FPS).", true)
	_add(PDMetricIds.PROCESS_TIME_MS, "Process Time", "ms", false, "Idle/process frame duration (Performance.TIME_PROCESS).", true)
	_add(PDMetricIds.PHYSICS_TIME_MS, "Physics Time", "ms", false, "Physics step duration (Performance.TIME_PHYSICS_PROCESS).", true)
	_add(PDMetricIds.NAVIGATION_TIME_MS, "Navigation Time", "ms", false, "Navigation step duration (Performance.TIME_NAVIGATION_PROCESS).", true, false)

	_add(PDMetricIds.DRAW_CALLS, "Draw Calls", "", false, "Total draw calls last frame (includes 2D/UI).", true)
	_add(PDMetricIds.RENDER_OBJECTS, "Render Objects", "", false, "Objects submitted last frame (not frustum-culled).", true)
	_add(PDMetricIds.PRIMITIVES, "Primitives", "", false, "Vertices/indices reported by the renderer (includes depth/shadow passes).", true)
	_add(PDMetricIds.TRIANGLES_EST, "Triangles (est.)", "", false, "Primitives / 3 — approximate triangle count, not exact.", false)
	_add(PDMetricIds.VISIBLE_OBJECTS, "Visible Objects", "", false, "Same as render objects (engine visible/submitted objects).", true)

	_add(PDMetricIds.PHYSICS_3D_OBJECTS, "Physics 3D Objects", "", false, "Active RigidBody3D / VehicleBody3D count.", true)
	_add(PDMetricIds.PHYSICS_3D_PAIRS, "Physics 3D Pairs", "", false, "3D collision pairs.", true, false)
	_add(PDMetricIds.PHYSICS_2D_OBJECTS, "Physics 2D Objects", "", false, "Active RigidBody2D count.", true, false)

	_add(PDMetricIds.ACTIVE_LIGHTS, "Active Lights", "", false, "Light3D nodes currently in the tree (not GPU-active count).", false)
	_add(PDMetricIds.SHADOW_CASTERS, "Shadow Casters", "", false, "Lights with shadow_enabled (proxy for shadow cost).", false)
	_add(PDMetricIds.ACTIVE_PARTICLES, "Active Particles", "", false, "Playing GPU/CPU particle nodes in the tree.", false)

	_add(PDMetricIds.AUDIO_VOICES, "Audio Voices", "", false, "Playing AudioStreamPlayer* nodes (estimated voice count).", false)
	_add(PDMetricIds.AUDIO_LATENCY_MS, "Audio Latency", "ms", false, "AudioServer output latency.", true, false)

	_add(PDMetricIds.TEXTURE_MEM_MB, "Texture Memory", "MB", false, "RENDER_TEXTURE_MEM_USED.", true)
	_add(PDMetricIds.BUFFER_MEM_MB, "Buffer Memory", "MB", false, "RENDER_BUFFER_MEM_USED.", true, false)
	_add(PDMetricIds.VIDEO_MEM_MB, "Video Memory", "MB", false, "RENDER_VIDEO_MEM_USED (texture + vertex + misc).", true)
	_add(PDMetricIds.STATIC_MEM_MB, "Static Memory", "MB", false, "MEMORY_STATIC — debug builds only; 0 in release.", true)

	_add(PDMetricIds.OBJECT_COUNT, "Objects", "", false, "Instantiated Object count.", true, false)
	_add(PDMetricIds.NODE_COUNT, "Nodes", "", false, "Scene-tree node count.", true)
	_add(PDMetricIds.RESOURCE_COUNT, "Resources", "", false, "Loaded Resource count.", true, false)
	_add(PDMetricIds.ORPHAN_NODE_COUNT, "Orphan Nodes", "", false, "Unparented nodes (debug builds only).", true, false)

	_add(PDMetricIds.NAV_AGENTS, "Nav Agents", "", false, "Active navigation agents (2D+3D).", true)
	_add(PDMetricIds.NAV_REGIONS, "Nav Regions", "", false, "Active navigation regions (2D+3D).", true, false)
	_add(PDMetricIds.NAV_POLYGONS, "Nav Polygons", "", false, "Navigation mesh polygon count (2D+3D).", true, false)

	_add(PDMetricIds.PIPELINE_COMPILATIONS_DRAW, "Pipeline Compiles (Draw)", "", false, "Shader pipeline compilations during draw (stutter risk).", true, false)


func _add(
	id: StringName,
	display_name: String,
	unit: String,
	higher_is_better: bool,
	description: String,
	is_exact: bool,
	show_in_bar_chart: bool = true
) -> void:
	register(PDMetricDefinition.new(
		id, display_name, unit, higher_is_better, description, is_exact, show_in_bar_chart
	))
