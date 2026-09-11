class_name DangerVignette
extends ColorRect
## Full-screen red-zone overlay. Tune size / intensity / wander / aberration here.

@export_group("Vignette")
@export var vignette_color := Color(0.74, 0.03, 0.02, 1.0)
@export_range(0.0, 2.0, 0.01) var intensity := 0.9
@export_range(0.05, 1.5, 0.01) var _size := 0.58
@export_range(0.01, 1.5, 0.01) var softness := 0.48
@export_range(0.0, 1.0, 0.01) var opacity := 0.92
@export_range(0.0, 2.0, 0.01) var fade_speed := 2.4

@export_group("Motion")
@export_range(0.0, 0.45, 0.005) var wander_amount := 0.11
@export_range(0.0, 3.0, 0.05) var wander_speed := 0.48
@export_range(0.0, 0.4, 0.005) var pulse_amount := 0.12
@export_range(0.0, 5.0, 0.05) var pulse_speed := 1.35

@export_group("Aberration")
@export_range(0.0, 0.02, 0.0001) var aberration := 0.0022
@export_range(0.0, 1.0, 0.01) var aberration_fluctuate := 0.55
@export_range(0.0, 10.0, 0.05) var aberration_speed := 2.6

var _danger := 0.0
var _shown := 0.0
var _time := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("danger_vignette")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = material as ShaderMaterial
	if _mat:
		_mat = _mat.duplicate() as ShaderMaterial
		material = _mat
	set_process(true)
	_apply_shader(0.0)
	hide()


func set_danger_amount(amount: float) -> void:
	_danger = clampf(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, _danger, maxf(fade_speed, 0.1) * delta)
	if _shown <= 0.004:
		if visible:
			hide()
		return
	if not visible:
		show()
	_apply_shader(_shown)


func _apply_shader(amount: float) -> void:
	if _mat == null:
		return
	var wander := Vector2(
		sin(_time * TAU * wander_speed) * wander_amount,
		cos(_time * TAU * wander_speed * 0.73 + 1.1) * wander_amount * 0.72
	)
	var pulse := 1.0 + sin(_time * TAU * pulse_speed) * pulse_amount
	var ab_wobble := 1.0 + sin(_time * TAU * aberration_speed) * aberration_fluctuate * 0.5
	ab_wobble += sin(_time * TAU * aberration_speed * 1.7 + 0.4) * aberration_fluctuate * 0.25
	_mat.set_shader_parameter("vignette_color", vignette_color)
	_mat.set_shader_parameter("intensity", intensity * pulse)
	_mat.set_shader_parameter("size", _size)
	_mat.set_shader_parameter("softness", softness)
	_mat.set_shader_parameter("opacity", opacity)
	_mat.set_shader_parameter("center_offset", wander)
	_mat.set_shader_parameter("aberration", aberration * ab_wobble)
	_mat.set_shader_parameter("danger", amount)
