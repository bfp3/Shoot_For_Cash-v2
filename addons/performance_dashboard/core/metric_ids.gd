class_name PDMetricIds
extends Object

## Canonical metric identifiers used by the profiler, profiles, and UI.
## Add new metrics here first, then register them in PDMetricRegistry.

const FPS := &"fps"
const FRAME_TIME_MS := &"frame_time_ms"
const PROCESS_TIME_MS := &"process_time_ms"
const PHYSICS_TIME_MS := &"physics_time_ms"
const NAVIGATION_TIME_MS := &"navigation_time_ms"

const DRAW_CALLS := &"draw_calls"
const RENDER_OBJECTS := &"render_objects"
const PRIMITIVES := &"primitives"
const TRIANGLES_EST := &"triangles_est"
const VISIBLE_OBJECTS := &"visible_objects"

const PHYSICS_3D_OBJECTS := &"physics_3d_objects"
const PHYSICS_3D_PAIRS := &"physics_3d_pairs"
const PHYSICS_2D_OBJECTS := &"physics_2d_objects"

const ACTIVE_LIGHTS := &"active_lights"
const SHADOW_CASTERS := &"shadow_casters"
const ACTIVE_PARTICLES := &"active_particles"

const AUDIO_VOICES := &"audio_voices"
const AUDIO_LATENCY_MS := &"audio_latency_ms"

const TEXTURE_MEM_MB := &"texture_mem_mb"
const BUFFER_MEM_MB := &"buffer_mem_mb"
const VIDEO_MEM_MB := &"video_mem_mb"
const STATIC_MEM_MB := &"static_mem_mb"

const OBJECT_COUNT := &"object_count"
const NODE_COUNT := &"node_count"
const RESOURCE_COUNT := &"resource_count"
const ORPHAN_NODE_COUNT := &"orphan_node_count"

const NAV_AGENTS := &"nav_agents"
const NAV_REGIONS := &"nav_regions"
const NAV_POLYGONS := &"nav_polygons"

const PIPELINE_COMPILATIONS_DRAW := &"pipeline_compilations_draw"

## Display / comparison category used by the bar chart (not every metric needs a bar).
const BAR_CHART_METRICS: Array[StringName] = [
	FPS,
	FRAME_TIME_MS,
	DRAW_CALLS,
	RENDER_OBJECTS,
	PRIMITIVES,
	TRIANGLES_EST,
	PHYSICS_TIME_MS,
	PROCESS_TIME_MS,
	PHYSICS_3D_OBJECTS,
	ACTIVE_LIGHTS,
	SHADOW_CASTERS,
	ACTIVE_PARTICLES,
	AUDIO_VOICES,
	TEXTURE_MEM_MB,
	VIDEO_MEM_MB,
	STATIC_MEM_MB,
	NODE_COUNT,
	VISIBLE_OBJECTS,
	NAV_AGENTS,
]
