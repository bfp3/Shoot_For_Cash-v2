extends Node

## Landscape mobile controls:
## - Right half: drag to move crosshair only
## - Left half: tap = fire, hold = shrink scope then fire on release

var aim_touch := -1
var fire_touch := -1

var previous_touch_position := Vector2.ZERO
var motion := Vector2.ZERO

var fire_held := false
var _fire_just_released := false

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	if not OS.has_feature("mobile"):
		set_process_input(false)
		return
	# Prefer landscape on phones/tablets.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func _input(event: InputEvent) -> void:
	if not OS.has_feature("mobile"):
		return

	if _player == null or _player.current_state != Player.State.ACTIVE:
		_reset_touches()
		return

	var half := get_viewport().get_visible_rect().size.x * 0.5

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Right half = aim trackpad only
			if touch.position.x >= half and aim_touch == -1:
				aim_touch = touch.index
				previous_touch_position = touch.position
			# Left half = fire / scope shrink
			elif touch.position.x < half and fire_touch == -1:
				fire_touch = touch.index
				fire_held = true
				_fire_just_released = false
		else:
			if touch.index == aim_touch:
				aim_touch = -1
			elif touch.index == fire_touch:
				fire_touch = -1
				fire_held = false
				_fire_just_released = true

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != aim_touch:
			return
		# Same resolution-independent scaling as mouse look / settings level.
		motion += GameSettings.mouse_look_delta(drag.relative)
		previous_touch_position = drag.position


func get_crosshair_motion() -> Vector2:
	var result := motion
	motion = Vector2.ZERO
	return result


func is_fire_held() -> bool:
	return fire_held


func consume_fire_release() -> bool:
	if not _fire_just_released:
		return false
	_fire_just_released = false
	return true


func _reset_touches() -> void:
	aim_touch = -1
	fire_touch = -1
	fire_held = false
	_fire_just_released = false
	motion = Vector2.ZERO
	previous_touch_position = Vector2.ZERO
