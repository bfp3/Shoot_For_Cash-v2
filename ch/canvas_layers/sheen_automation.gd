extends Control
class_name SheenMaterialAutomation

@export_group("Target")
@export var target: TextureRect:
	set(value):
		target = value
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_group("Sheen")
@export var sheen_enabled := true:
	set(value):
		sheen_enabled = value
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.05, 4.0, 0.05, "or_greater")
var sheen_duration := 0.85:
	set(value):
		sheen_duration = maxf(value, 0.05)
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.0, 8.0, 0.05, "or_greater")
var sheen_pause := 1.35:
	set(value):
		sheen_pause = maxf(value, 0.0)
		if is_node_ready() and not Engine.is_editor_hint():
			_restart_sheen()

@export_range(0.04, 0.8, 0.01)
var sheen_width := 0.16:
	set(value):
		sheen_width = value
		_apply_sheen_params()

@export var sheen_color := Color(1.0, 0.98, 0.88, 0.82):
	set(value):
		sheen_color = value
		_apply_sheen_params()


var _sheen_mat: ShaderMaterial
var _sheen_tween: Tween
var _sheen_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if Engine.is_editor_hint():
		return

	_prepare_runtime_material()

	await get_tree().process_frame

	if not is_inside_tree():
		return

	_sheen_ready = (
		_sheen_mat != null
		and _sheen_mat.shader != null
	)

	_apply_sheen_params()
	_restart_sheen()


func _exit_tree() -> void:
	_kill_sheen()


func _prepare_runtime_material() -> void:
	if target == null:
		return

	var existing := target.material as ShaderMaterial

	if existing == null or existing.shader == null:
		push_warning(
			"SheenMaterialAutomation: Target has no ShaderMaterial with a shader."
		)
		return

	# Duplicate the material so every target gets its own
	# independent shader parameters.
	_sheen_mat = existing.duplicate() as ShaderMaterial

	if _sheen_mat:
		_sheen_mat.resource_local_to_scene = true
		target.material = _sheen_mat


func _apply_sheen_params() -> void:
	if not _can_set_sheen():
		return

	_sheen_mat.set_shader_parameter(
		"shine_width",
		sheen_width
	)

	_sheen_mat.set_shader_parameter(
		"shine_color",
		sheen_color
	)

	if not sheen_enabled:
		_sheen_mat.set_shader_parameter(
			"shine_progress",
			-0.2
		)


func _restart_sheen() -> void:
	_kill_sheen()

	if (
		Engine.is_editor_hint()
		or not sheen_enabled
		or not _can_set_sheen()
	):
		return

	_sheen_tween = create_tween()
	_sheen_tween.set_loops()

	# Start just outside the star.
	# Move completely across it.
	_sheen_tween.tween_method(
		_set_progress,
		-0.2,
		2.2,
		sheen_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	# Wait before repeating.
	if sheen_pause > 0.0:
		_sheen_tween.tween_interval(sheen_pause)


func _set_progress(value: float) -> void:
	if _can_set_sheen():
		_sheen_mat.set_shader_parameter(
			"shine_progress",
			value
		)


func _can_set_sheen() -> bool:
	return (
		_sheen_ready
		and _sheen_mat != null
		and _sheen_mat.shader != null
	)


func _kill_sheen() -> void:
	if _sheen_tween and _sheen_tween.is_valid():
		_sheen_tween.kill()

	_sheen_tween = null
