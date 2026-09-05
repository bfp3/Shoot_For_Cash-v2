extends Node3D
## Scale / look state machine for threat mine light ring (`LightsContainer`).

class_name ThreatLightsContainer

enum State {
	DORMANT, ## Armed / idle ring size.
	ALARM, ## Crosshair wound-up — expanded ring.
	DEACTIVATED, ## Post-smoke cooldown — shrunk ring.
}

@export var dormant_scale := Vector3.ONE * 0.905
@export var alarm_scale := Vector3.ONE * 1.474
@export var deactivated_scale := Vector3.ONE * 0.5
@export_range(0.02, 1.0, 0.01) var alarm_lerp_sec := 0.15
@export_range(0.02, 1.0, 0.01) var deactivate_lerp_sec := 0.22
@export_range(0.02, 1.0, 0.01) var dormant_lerp_sec := 0.28

@export_group("Alarm Shake")
## How far the light ring jitters while ALARM is active (local units).
@export_range(0.0, 0.35, 0.005) var alarm_shake_intensity := 0.06
## How quickly the shake oscillates (higher = more frantic).
@export_range(1.0, 60.0, 0.5) var alarm_shake_speed := 28.0
## Extra roll jitter in degrees while alarming.
@export_range(0.0, 25.0, 0.5) var alarm_shake_rotation_deg := 8.0

var current_state: State = State.DORMANT
var _scale_tween: Tween
var _rest_position := Vector3.ZERO
var _rest_rotation := Vector3.ZERO
var _shake_t := 0.0
var _shaking := false


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation_degrees
	enter_state(State.DORMANT, true)


func _process(delta: float) -> void:
	if not _shaking or alarm_shake_intensity <= 0.0:
		return
	_shake_t += delta * alarm_shake_speed
	var amp := alarm_shake_intensity
	## Cheap chaotic jitter (not a single sine) so it feels like a warning buzz.
	var ox := sin(_shake_t * 1.7) * amp + cos(_shake_t * 3.1) * amp * 0.45
	var oy := cos(_shake_t * 2.3) * amp + sin(_shake_t * 4.0) * amp * 0.35
	var oz := sin(_shake_t * 2.9) * amp * 0.55
	position = _rest_position + Vector3(ox, oy, oz)
	if alarm_shake_rotation_deg > 0.0:
		var r := alarm_shake_rotation_deg
		rotation_degrees = _rest_rotation + Vector3(
			sin(_shake_t * 2.1) * r,
			cos(_shake_t * 1.8) * r * 0.7,
			sin(_shake_t * 3.4) * r * 0.5
		)


func enter_state(new_state: State, instant: bool = false) -> void:
	current_state = new_state
	match new_state:
		State.DORMANT:
			_set_shaking(false)
			_tween_to(dormant_scale, 0.0 if instant else dormant_lerp_sec)
		State.ALARM:
			_set_shaking(true)
			_tween_to(alarm_scale, 0.0 if instant else alarm_lerp_sec)
		State.DEACTIVATED:
			_set_shaking(false)
			_tween_to(deactivated_scale, 0.0 if instant else deactivate_lerp_sec)


func is_dormant() -> bool:
	return current_state == State.DORMANT


func _set_shaking(on: bool) -> void:
	_shaking = on
	if not on:
		_shake_t = 0.0
		position = _rest_position
		rotation_degrees = _rest_rotation


func _tween_to(target: Vector3, duration: float) -> void:
	if _scale_tween != null and is_instance_valid(_scale_tween):
		_scale_tween.kill()
	_scale_tween = null
	if duration <= 0.02:
		scale = target
		return
	_scale_tween = create_tween()
	_scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_scale_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", target, duration)
