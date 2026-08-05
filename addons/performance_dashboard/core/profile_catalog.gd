class_name PDProfileCatalog
extends RefCounted

## Loads optimisation target profiles from res://addons/performance_dashboard/profiles/.
## Falls back to built-in defaults if a .tres file is missing.

const PROFILE_DESKTOP := &"desktop"
const PROFILE_MOBILE := &"mobile"
const PROFILE_WEB := &"web"

const PATH_DESKTOP := "res://addons/performance_dashboard/profiles/desktop_forward_plus.tres"
const PATH_MOBILE := "res://addons/performance_dashboard/profiles/mobile.tres"
const PATH_WEB := "res://addons/performance_dashboard/profiles/compatibility_web.tres"


static func create_builtin_profiles() -> Array[PerformanceTargetProfile]:
	var desktop := _try_load(PATH_DESKTOP)
	var mobile := _try_load(PATH_MOBILE)
	var web := _try_load(PATH_WEB)
	return [
		desktop if desktop else _desktop(),
		mobile if mobile else _mobile(),
		web if web else _web(),
	]


static func _try_load(path: String) -> PerformanceTargetProfile:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is PerformanceTargetProfile:
		return (res as PerformanceTargetProfile).duplicate_profile()
	return null


static func _desktop() -> PerformanceTargetProfile:
	var p := PerformanceTargetProfile.new()
	p.profile_id = PROFILE_DESKTOP
	p.display_name = "Forward+ (Desktop / Low-End PC)"
	p.description = "Targets for Forward+ on a modest desktop GPU."
	p.targets = {
		PDMetricIds.FPS: 60.0,
		PDMetricIds.FRAME_TIME_MS: 16.67,
		PDMetricIds.PROCESS_TIME_MS: 12.0,
		PDMetricIds.PHYSICS_TIME_MS: 4.0,
		PDMetricIds.NAVIGATION_TIME_MS: 1.5,
		PDMetricIds.DRAW_CALLS: 800.0,
		PDMetricIds.RENDER_OBJECTS: 1500.0,
		PDMetricIds.PRIMITIVES: 1_500_000.0,
		PDMetricIds.TRIANGLES_EST: 500_000.0,
		PDMetricIds.VISIBLE_OBJECTS: 1500.0,
		PDMetricIds.PHYSICS_3D_OBJECTS: 250.0,
		PDMetricIds.PHYSICS_3D_PAIRS: 500.0,
		PDMetricIds.PHYSICS_2D_OBJECTS: 100.0,
		PDMetricIds.ACTIVE_LIGHTS: 24.0,
		PDMetricIds.SHADOW_CASTERS: 8.0,
		PDMetricIds.ACTIVE_PARTICLES: 20.0,
		PDMetricIds.AUDIO_VOICES: 48.0,
		PDMetricIds.AUDIO_LATENCY_MS: 40.0,
		PDMetricIds.TEXTURE_MEM_MB: 512.0,
		PDMetricIds.BUFFER_MEM_MB: 256.0,
		PDMetricIds.VIDEO_MEM_MB: 1024.0,
		PDMetricIds.STATIC_MEM_MB: 1024.0,
		PDMetricIds.OBJECT_COUNT: 8000.0,
		PDMetricIds.NODE_COUNT: 5000.0,
		PDMetricIds.RESOURCE_COUNT: 2500.0,
		PDMetricIds.ORPHAN_NODE_COUNT: 0.0,
		PDMetricIds.NAV_AGENTS: 64.0,
		PDMetricIds.NAV_REGIONS: 32.0,
		PDMetricIds.NAV_POLYGONS: 20000.0,
		PDMetricIds.PIPELINE_COMPILATIONS_DRAW: 0.0,
	}
	return p


static func _mobile() -> PerformanceTargetProfile:
	var p := PerformanceTargetProfile.new()
	p.profile_id = PROFILE_MOBILE
	p.display_name = "Mobile"
	p.description = "Aggressive budgets for mid-range mobile GPUs."
	p.targets = {
		PDMetricIds.FPS: 30.0,
		PDMetricIds.FRAME_TIME_MS: 33.33,
		PDMetricIds.PROCESS_TIME_MS: 22.0,
		PDMetricIds.PHYSICS_TIME_MS: 6.0,
		PDMetricIds.NAVIGATION_TIME_MS: 2.0,
		PDMetricIds.DRAW_CALLS: 200.0,
		PDMetricIds.RENDER_OBJECTS: 400.0,
		PDMetricIds.PRIMITIVES: 300_000.0,
		PDMetricIds.TRIANGLES_EST: 100_000.0,
		PDMetricIds.VISIBLE_OBJECTS: 400.0,
		PDMetricIds.PHYSICS_3D_OBJECTS: 80.0,
		PDMetricIds.PHYSICS_3D_PAIRS: 150.0,
		PDMetricIds.PHYSICS_2D_OBJECTS: 50.0,
		PDMetricIds.ACTIVE_LIGHTS: 4.0,
		PDMetricIds.SHADOW_CASTERS: 1.0,
		PDMetricIds.ACTIVE_PARTICLES: 6.0,
		PDMetricIds.AUDIO_VOICES: 24.0,
		PDMetricIds.AUDIO_LATENCY_MS: 60.0,
		PDMetricIds.TEXTURE_MEM_MB: 192.0,
		PDMetricIds.BUFFER_MEM_MB: 96.0,
		PDMetricIds.VIDEO_MEM_MB: 320.0,
		PDMetricIds.STATIC_MEM_MB: 512.0,
		PDMetricIds.OBJECT_COUNT: 3000.0,
		PDMetricIds.NODE_COUNT: 2000.0,
		PDMetricIds.RESOURCE_COUNT: 1000.0,
		PDMetricIds.ORPHAN_NODE_COUNT: 0.0,
		PDMetricIds.NAV_AGENTS: 16.0,
		PDMetricIds.NAV_REGIONS: 8.0,
		PDMetricIds.NAV_POLYGONS: 4000.0,
		PDMetricIds.PIPELINE_COMPILATIONS_DRAW: 0.0,
	}
	return p


static func _web() -> PerformanceTargetProfile:
	var p := PerformanceTargetProfile.new()
	p.profile_id = PROFILE_WEB
	p.display_name = "Compatibility / Web"
	p.description = "Budgets for Compatibility renderer and browser constraints."
	p.targets = {
		PDMetricIds.FPS: 30.0,
		PDMetricIds.FRAME_TIME_MS: 33.33,
		PDMetricIds.PROCESS_TIME_MS: 24.0,
		PDMetricIds.PHYSICS_TIME_MS: 8.0,
		PDMetricIds.NAVIGATION_TIME_MS: 2.5,
		PDMetricIds.DRAW_CALLS: 150.0,
		PDMetricIds.RENDER_OBJECTS: 300.0,
		PDMetricIds.PRIMITIVES: 200_000.0,
		PDMetricIds.TRIANGLES_EST: 70_000.0,
		PDMetricIds.VISIBLE_OBJECTS: 300.0,
		PDMetricIds.PHYSICS_3D_OBJECTS: 60.0,
		PDMetricIds.PHYSICS_3D_PAIRS: 120.0,
		PDMetricIds.PHYSICS_2D_OBJECTS: 40.0,
		PDMetricIds.ACTIVE_LIGHTS: 3.0,
		PDMetricIds.SHADOW_CASTERS: 1.0,
		PDMetricIds.ACTIVE_PARTICLES: 4.0,
		PDMetricIds.AUDIO_VOICES: 16.0,
		PDMetricIds.AUDIO_LATENCY_MS: 80.0,
		PDMetricIds.TEXTURE_MEM_MB: 128.0,
		PDMetricIds.BUFFER_MEM_MB: 64.0,
		PDMetricIds.VIDEO_MEM_MB: 256.0,
		PDMetricIds.STATIC_MEM_MB: 384.0,
		PDMetricIds.OBJECT_COUNT: 2500.0,
		PDMetricIds.NODE_COUNT: 1500.0,
		PDMetricIds.RESOURCE_COUNT: 800.0,
		PDMetricIds.ORPHAN_NODE_COUNT: 0.0,
		PDMetricIds.NAV_AGENTS: 8.0,
		PDMetricIds.NAV_REGIONS: 4.0,
		PDMetricIds.NAV_POLYGONS: 2500.0,
		PDMetricIds.PIPELINE_COMPILATIONS_DRAW: 0.0,
	}
	return p
