extends Control

@export_group("Sheen")
@export var sheen_enabled := true:
	set(value):
		sheen_enabled = value
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.05, 4.0, 0.05, "or_greater") var sheen_duration := 0.85:
	set(value):
		sheen_duration = maxf(value, 0.05)
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.0, 8.0, 0.05, "or_greater") var sheen_pause := 1.35:
	set(value):
		sheen_pause = maxf(value, 0.0)
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.04, 0.8, 0.01) var sheen_width := 0.16:
	set(value):
		sheen_width = value
		_apply_sheen_params()

@export var sheen_color := Color(1.0, 0.98, 0.88, 0.82):
	set(value):
		sheen_color = value
		_apply_sheen_params()


@onready var _star: TextureRect = get_node_or_null("TextureRect") as TextureRect
@onready var _particles: GPUParticles2D = get_node_or_null("BackgroundParticles") as GPUParticles2D

var _sheen_mat: ShaderMaterial
var _sheen_tween: Tween
var _sheen_ready := false


func _ready() -> void:
	
	#hide()
	#return
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _particles:
		_particles.emitting = false

	if Engine.is_editor_hint():
		return

	_prepare_runtime_material()

	await get_tree().process_frame

	if not is_inside_tree():
		return

	_sheen_ready = _sheen_mat != null and _sheen_mat.shader != null

	_apply_sheen_params()
	_restart_sheen()

	if _particles:
		_particles.emitting = true


func _exit_tree() -> void:
	_kill_sheen()


func _prepare_runtime_material() -> void:
	if _star == null:
		return

	var existing := _star.material as ShaderMaterial

	if existing == null or existing.shader == null:
		_star.material = null
		_sheen_mat = null
		return

	_sheen_mat = existing.duplicate() as ShaderMaterial

	if _sheen_mat:
		_sheen_mat.resource_local_to_scene = true
		_star.material = _sheen_mat


func _apply_sheen_params() -> void:
	if not _can_set_sheen():
		return

	_sheen_mat.set_shader_parameter("shine_width", sheen_width)
	_sheen_mat.set_shader_parameter("shine_color", sheen_color)

	if not sheen_enabled:
		_sheen_mat.set_shader_parameter("shine_progress", -0.5)


func _restart_sheen() -> void:
	_kill_sheen()

	if Engine.is_editor_hint() or not sheen_enabled or not _can_set_sheen():
		return

	_sheen_tween = create_tween()
	_sheen_tween.set_loops()

	# Move the shine completely across the star.
	_sheen_tween.tween_method(
		_set_progress,
		-0.2,
		2.2,
		sheen_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Wait before doing it again.
	if sheen_pause > 0.0:
		_sheen_tween.tween_interval(sheen_pause)


func _set_progress(value: float) -> void:
	if _can_set_sheen():
		_sheen_mat.set_shader_parameter("shine_progress", value)


func _can_set_sheen() -> bool:
	return _sheen_ready and _sheen_mat != null and _sheen_mat.shader != null


func _kill_sheen() -> void:
	if _sheen_tween and _sheen_tween.is_valid():
		_sheen_tween.kill()
		_sheen_tween = null
