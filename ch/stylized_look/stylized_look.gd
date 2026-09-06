@tool
extends Node
## Illustrated look director for a layout.
## Pushes look uniforms onto stylized mesh ShaderMaterials and optionally
## enables architecture shadows. Water is left alone — tune SimpleWater yourself.
##
## Shade is how much a face points at the DirectionalLight (0–1), and 0
## when the face is in a cast shadow.
##
##   shade < shadow_threshold  →  shadow_color (black by default)
##   between the two cuts      →  mid_color
##   shade >= light_threshold  →  light_color
##
## Keep shadow_threshold below light_threshold. Raising shadow_threshold
## eats mid into black. Lowering light_threshold makes more faces “lit”.

const _SHADER_PATHS: PackedStringArray = [
	"res://res/Shaders/stylized_illustrated.gdshader",
]

@export_group("Shadow")
## Fully unlit / occluded faces. Set to black for a hard ink shadow.
@export var shadow_color: Color = Color(0, 0, 0, 1.0):
	set(value):
		shadow_color = value
		_push()
## 1 = replace with shadow_color. 0 = keep a hint of albedo in shade.
@export_range(0.0, 1.0, 0.01) var shadow_strength: float = 1.0:
	set(value):
		shadow_strength = value
		_push()
## Faces darker than this (and anything in a cast shadow) become shadow_color.
@export_range(0.0, 1.0, 0.01) var shadow_threshold: float = 0.22:
	set(value):
		shadow_threshold = value
		_push()

@export_group("Mid / Light")
## Grazing light / “light shadow”. Faces between the two thresholds.
@export var mid_color: Color = Color(0.42, 0.4, 0.4, 1.0):
	set(value):
		mid_color = value
		_push()
## Lit faces. Full sun-facing surfaces become this colour.
@export var light_color: Color = Color(1.0, 0.94, 0.82, 1.0):
	set(value):
		light_color = value
		_push()
## 1 = replace with light_color. 0 = keep albedo on lit faces.
@export_range(0.0, 1.0, 0.01) var light_strength: float = 1.0:
	set(value):
		light_strength = value
		_push()
## Faces brighter than this become light_color. Must stay above shadow_threshold.
@export_range(0.0, 1.0, 0.01) var light_threshold: float = 0.55:
	set(value):
		light_threshold = value
		_push()
## 0 = hard painted bands. Raise a little if edges shimmer.
@export_range(0.0, 0.2, 0.001) var band_softness: float = 0.01:
	set(value):
		band_softness = value
		_push()

@export_group("Grading")
## 1 = original saturation. Below 1 mutes the palette.
@export_range(0.0, 1.5, 0.01) var saturation: float = 0.92:
	set(value):
		saturation = value
		_push()
@export_range(0.5, 1.8, 0.01) var contrast: float = 1.08:
	set(value):
		contrast = value
		_push()

@export_group("Atmosphere")
@export var fog_color: Color = Color(0.45, 0.62, 0.78, 1.0):
	set(value):
		fog_color = value
		_push()
@export_range(0.0, 1.5, 0.01) var fog_strength: float = 0.55:
	set(value):
		fog_strength = value
		_push()
@export var fog_start: float = 28.0:
	set(value):
		fog_start = value
		_push()
@export var fog_end: float = 260.0:
	set(value):
		fog_end = value
		_push()
## Also write fog/grading onto the active Environment so editor and play match.
@export var sync_environment: bool = true:
	set(value):
		sync_environment = value
		_push()

@export_group("Lighting helpers")
## Turn on mesh shadow-casting for fortress geometry (clouds/water stay off).
@export var enable_architecture_shadows: bool = true:
	set(value):
		enable_architecture_shadows = value
		_apply_architecture_shadows()


func _ready() -> void:
	_push()
	_apply_architecture_shadows()


func _enter_tree() -> void:
	_push()


func _push() -> void:
	if not is_inside_tree():
		return
	var params := {
		"sty_shadow_color": shadow_color,
		"sty_shadow_strength": shadow_strength,
		"sty_shadow_threshold": shadow_threshold,
		"sty_mid_color": mid_color,
		"sty_light_color": light_color,
		"sty_light_strength": light_strength,
		"sty_light_threshold": light_threshold,
		"sty_band_softness": band_softness,
		"sty_saturation": saturation,
		"sty_contrast": contrast,
		"sty_fog_color": fog_color,
		"sty_fog_strength": fog_strength,
		"sty_fog_start": fog_start,
		"sty_fog_end": fog_end,
	}
	var root := get_parent()
	if root:
		_apply_look_to_node(root, params)
	if sync_environment:
		_sync_environment()


func _apply_look_to_node(node: Node, params: Dictionary) -> void:
	if node is SimpleWater or String(node.name).begins_with("SimpleWater"):
		return
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		_apply_look_to_material(gi.material_override, params)
		_apply_look_to_material(gi.material_overlay, params)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					_apply_look_to_material(mi.mesh.surface_get_material(i), params)
					_apply_look_to_material(mi.get_surface_override_material(i), params)
		elif node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			if mmi.multimesh and mmi.multimesh.mesh:
				for i in mmi.multimesh.mesh.get_surface_count():
					_apply_look_to_material(mmi.multimesh.mesh.surface_get_material(i), params)
	for child in node.get_children():
		_apply_look_to_node(child, params)


func _apply_look_to_material(mat: Variant, params: Dictionary) -> void:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null:
		return
	if not _SHADER_PATHS.has(sm.shader.resource_path):
		return
	for key in params:
		sm.set_shader_parameter(String(key), params[key])


func _sync_environment() -> void:
	var env := _find_environment()
	if env == null:
		return
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = fog_color
	env.fog_depth_begin = fog_start
	env.fog_depth_end = fog_end
	env.fog_aerial_perspective = 0.42
	env.adjustment_enabled = true
	env.adjustment_saturation = saturation
	env.adjustment_contrast = contrast


func _find_environment() -> Environment:
	var parent := get_parent()
	if parent:
		var we := parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we and we.environment:
			return we.environment
	if is_inside_tree():
		var cam := get_tree().get_first_node_in_group("player_cam")
		if cam:
			var env = cam.get("environment")
			if env is Environment:
				return env
	return null


func _apply_architecture_shadows() -> void:
	if not is_inside_tree() or not enable_architecture_shadows:
		return
	var level1 := get_parent().get_node_or_null("Level1") if get_parent() else null
	if level1:
		_enable_mesh_shadows(level1)


func _enable_mesh_shadows(node: Node) -> void:
	var n := String(node.name)
	if node is Sprite3D or node is Decal:
		return
	if n.begins_with("Cloud") or n.begins_with("Mountain") or n == "Moon" or n == "ShadowBlocker":
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_mesh_shadows(child)
