extends MeshInstance3D
## Invisible until the reticle covers it. Only the disc under the crosshair is drawn
## (crosshair as x-ray). Place this scene in a layout; it hides itself in play.



const WOOD_ALBEDO := preload("res://res/crateMesh2_CrateWoodAlbedo.png")
const CAMO_MAT := preload("res://res/camo_material.tres")
const XRAY_SHADER := preload("res://ch/HiddenCrate/hidden_crate_xray.gdshader")
const WOOD_TINT := Color(0.7, 0.5105334, 0.294, 1.0)
const CAMO_TINT := Color(1.0, 1.0, 1.0, 1.0)
const CAMO_GLOW := Color(0.45, 0.95, 0.18, 1.0)

@export var enabled := true

## 1 = same size as the live hit-radius. Lower = a smaller peek through the scope.
@export_range(0.2, 1.5, 0.05) var reveal_radius_scale := 0.85
@export_range(0.0, 48.0, 1.0) var reveal_softness_px := 14.0
@export_range(0.0, 4.0, 0.05) var reveal_emission := 0.45

@onready var _glow: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D

var _mat: ShaderMaterial
var _glow_rest_energy := 1.0
var _glow_wood_color := Color(1.0, 0.6166667, 0.0, 1.0)


func _ready() -> void:
	add_to_group("hidden_crate")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = XRAY_SHADER
	if _glow:
		_glow_rest_energy = _glow.light_energy
		_glow_wood_color = _glow.light_color
		_glow.light_energy = 0.0
	material_override = _mat
	_apply_version_look()
	_apply_xray(Vector2.ZERO, 0.0, false)


func _apply_version_look() -> void:
	if _mat == null:
		return

	_mat.set_shader_parameter("use_albedo_tex", 1.0)
	_mat.set_shader_parameter("albedo_tex", WOOD_ALBEDO)
	_mat.set_shader_parameter("albedo_tint", WOOD_TINT)
	_mat.set_shader_parameter("use_triplanar", 0.0)
	_mat.set_shader_parameter("surface_roughness", 0.78)
	if _glow:
		_glow.light_color = _glow_wood_color
		_mat.set_shader_parameter("emission_color", _glow_wood_color)
	else:
		_mat.set_shader_parameter("emission_color", WOOD_TINT)


func _process(_delta: float) -> void:
	if not enabled or _mat == null:
		return
	if not _player_can_reveal():
		_apply_xray(Vector2.ZERO, 0.0, false)
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		_apply_xray(Vector2.ZERO, 0.0, false)
		return

	var player := get_tree().get_first_node_in_group("Player")
	var aim := _aim_center_px(player)
	var radius := _aim_radius_px(player) * reveal_radius_scale
	var overlapping := _crate_overlaps_aim(cam, aim, radius)
	_apply_xray(aim, radius if overlapping else 0.0, overlapping)


func _player_can_reveal() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	if "current_state" in player and "State" in player:
		return player.current_state == player.State.ACTIVE
	return true


func _aim_center_px(player: Node) -> Vector2:
	var canvas := Vector2.ZERO
	if player != null:
		var weapon = player.get("weapon_shooting")
		if weapon and weapon.get("crosshair") is Control:
			canvas = (weapon.crosshair as Control).global_position
		elif player.has_method("_aim_screen_center"):
			canvas = player._aim_screen_center()
		else:
			canvas = get_viewport().get_visible_rect().size * 0.5
	else:
		canvas = get_viewport().get_visible_rect().size * 0.5
	return _canvas_to_viewport_px(canvas)


func _aim_radius_px(player: Node) -> float:
	var radius := 60.0
	if player != null and player.has_method("get_current_crosshair_hit_radius"):
		radius = float(player.get_current_crosshair_hit_radius())
	return radius * _viewport_px_scale()


func _canvas_to_viewport_px(canvas_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return canvas_pos
	return vp.get_screen_transform() * canvas_pos


func _viewport_px_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var scale := vp.get_screen_transform().get_scale()
	return scale.x if scale.x > 0.001 else 1.0


func _crate_overlaps_aim(cam: Camera3D, aim_px: Vector2, radius_px: float) -> bool:
	var crate_screen := _canvas_to_viewport_px(cam.unproject_position(global_position))
	var aabb := get_aabb()
	var world_radius := maxf(aabb.size.length() * 0.5 * maxf(global_transform.basis.get_scale().x, 0.01), 0.2)
	var edge := _canvas_to_viewport_px(cam.unproject_position(global_position + cam.global_basis.x * world_radius))
	var screen_radius := crate_screen.distance_to(edge)
	return crate_screen.distance_to(aim_px) <= radius_px + screen_radius


func _apply_xray(center_px: Vector2, radius_px: float, overlapping: bool) -> void:
	var softness := maxf(reveal_softness_px * _viewport_px_scale(), radius_px * 0.12)
	_mat.set_shader_parameter("xray_center_px", center_px)
	_mat.set_shader_parameter("xray_radius_px", radius_px if overlapping else 0.0)
	_mat.set_shader_parameter("xray_softness_px", softness)
	_mat.set_shader_parameter("emission_mul", reveal_emission if overlapping else 0.0)
	if _glow:
		_glow.light_energy = _glow_rest_energy if overlapping else 0.0
