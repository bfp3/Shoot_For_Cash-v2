extends Node3D
## One fluffy cloud made of soft overlapping noise quads.
## Drifts in world space and wraps inside an optional field bounds.

class_name FluffyCloud

@export var puff_count := 6
@export var puff_spread := Vector3(3.5, 1.2, 1.8)
@export var puff_size_min := Vector2(8.0, 5.0)
@export var puff_size_max := Vector2(16.0, 10.0)
@export var face_camera := true

@export_group("Look")
@export var cloud_color := Color(0.98, 0.99, 1.0, 1.0)
@export var cloud_shadow := Color(0.78, 0.84, 0.94, 1.0)
@export_range(0.0, 1.0) var opacity := 0.92
@export_range(0.0, 1.0) var density := 0.28
@export_range(0.02, 0.8) var softness := 0.35
@export_range(0.5, 8.0) var noise_scale := 2.0
@export_range(0.0, 1.0) var morph_speed := 0.07

@export_group("Motion")
@export var drift_velocity := Vector3(1.6, 0.0, 0.25)
@export var bob_amplitude := 0.45
@export var bob_speed := 0.3
@export var randomize_on_ready := true

const SHADER: Shader = preload("res://res/shaders/fluffy_cloud.gdshader")

var _base_y := 0.0
var _bob_phase := 0.0
var _wrap_min := Vector3.ZERO
var _wrap_max := Vector3.ZERO
var _has_wrap := false


func _ready() -> void:
	_base_y = global_position.y
	_bob_phase = randf() * TAU
	if randomize_on_ready:
		drift_velocity *= randf_range(0.75, 1.35)
		drift_velocity.z = absf(drift_velocity.z) * randf_range(-1.0, 1.0)
		morph_speed *= randf_range(0.7, 1.4)
		noise_scale *= randf_range(0.85, 1.2)
		density = clampf(density + randf_range(-0.04, 0.04), 0.12, 0.45)
	_build_puffs()


func configure_wrap(area_min: Vector3, area_max: Vector3) -> void:
	_wrap_min = area_min
	_wrap_max = area_max
	_has_wrap = true


func reset_bob_anchor() -> void:
	_base_y = global_position.y


func _build_puffs() -> void:
	for child in get_children():
		child.queue_free()

	for i in maxi(puff_count, 1):
		var mi := MeshInstance3D.new()
		mi.name = "Puff_%d" % i
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## QuadMesh faces +Z — billboarded toward camera in _face_camera.
		var quad := QuadMesh.new()
		quad.size = Vector2(
			randf_range(puff_size_min.x, puff_size_max.x),
			randf_range(puff_size_min.y, puff_size_max.y)
		)
		mi.mesh = quad

		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.render_priority = -5
		mat.set_shader_parameter("cloud_color", cloud_color)
		mat.set_shader_parameter("cloud_shadow", cloud_shadow)
		mat.set_shader_parameter("opacity", opacity * randf_range(0.88, 1.0))
		mat.set_shader_parameter("density", density + randf_range(-0.04, 0.04))
		mat.set_shader_parameter("softness", softness)
		mat.set_shader_parameter("noise_scale", noise_scale * randf_range(0.8, 1.2))
		mat.set_shader_parameter("morph_speed", morph_speed * randf_range(0.6, 1.3))
		mat.set_shader_parameter("detail_strength", randf_range(0.35, 0.55))
		mat.set_shader_parameter("edge_falloff", randf_range(0.9, 1.2))
		mat.set_shader_parameter("brightness", randf_range(1.0, 1.12))
		mi.material_override = mat

		mi.position = Vector3(
			randf_range(-puff_spread.x, puff_spread.x),
			randf_range(-puff_spread.y, puff_spread.y),
			randf_range(-puff_spread.z, puff_spread.z)
		)
		add_child(mi)

	_face_camera()


func _process(delta: float) -> void:
	global_position += drift_velocity * delta
	_bob_phase += bob_speed * delta
	global_position.y = _base_y + sin(_bob_phase) * bob_amplitude

	if face_camera:
		_face_camera()
	if _has_wrap:
		_wrap_position()


func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for child in get_children():
		if not (child is Node3D):
			continue
		## QuadMesh faces +Z; look_at aims -Z, so aim at a point opposite the camera.
		var away: Vector3 = child.global_position * 2.0 - cam.global_position
		if child.global_position.is_equal_approx(away):
			continue
		child.look_at(away, Vector3.UP)


func _wrap_position() -> void:
	var p := global_position
	var moved := false
	if p.x > _wrap_max.x:
		p.x = _wrap_min.x
		moved = true
	elif p.x < _wrap_min.x:
		p.x = _wrap_max.x
		moved = true
	if p.z > _wrap_max.z:
		p.z = _wrap_min.z
		moved = true
	elif p.z < _wrap_min.z:
		p.z = _wrap_max.z
		moved = true
	if moved:
		global_position = p
		_base_y = clampf(p.y, _wrap_min.y, _wrap_max.y)
