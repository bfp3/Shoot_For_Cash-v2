extends Node

@export_range(0.1, 15.0, 0.05)
var sensitivity := 1.0

@export var fire_action : StringName = &"shootWeapon"

var aim_touch := -1
var fire_touch := -1

var previous_touch_position := Vector2.ZERO
var motion := Vector2.ZERO


func _input(event: InputEvent) -> void:

	if !OS.has_feature("mobile"):
		return

	var half := get_viewport().get_visible_rect().size.x * 0.5

	#
	# Finger pressed
	#
	if event is InputEventScreenTouch:

		if event.pressed:

			# Right half = aiming trackpad
			if event.position.x >= half and aim_touch == -1:
				aim_touch = event.index
				previous_touch_position = event.position

			# Left half = fire button
			elif event.position.x < half and fire_touch == -1:
				fire_touch = event.index
				Input.action_press(fire_action)

		else:

			# Released aiming finger
			if event.index == aim_touch:
				aim_touch = -1

			# Released firing finger
			elif event.index == fire_touch:
				fire_touch = -1
				Input.action_release(fire_action)


	#
	# Finger dragged
	#
	elif event is InputEventScreenDrag:

		if event.index != aim_touch:
			return

		motion += event.position - previous_touch_position
		previous_touch_position = event.position


func get_crosshair_motion() -> Vector2:

	var result := motion * sensitivity

	motion = Vector2.ZERO

	return result
