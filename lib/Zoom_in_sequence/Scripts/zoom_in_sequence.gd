extends Node3D

@onready var player: Node3D = %Player
#var new_camera: Camera3D = null

func _ready() -> void:
	await get_tree().process_frame  # ensure player exists
	if player == null:
		push_error("Player not found in scene tree.")
		return
	begin_zoom_out_process()



func begin_zoom_out_process() -> void:
	#await get_tree().process_frame  # ensures player camera is fully initialized
	var new_camera = copy_player_camera()
	new_camera.current = true
	await camera_tween(new_camera)
#func begin_zoom_out_process() -> void:
	##if new_camera:
	#await camera_tween(new_camera)

func copy_player_camera() -> Camera3D:

	var camera_copy = player.camera_3d
	player.camera_pan_able = true
	#var player_camera = player.camera_3d
	#var camera_copy = player_camera.duplicate()
	#add_child(camera_copy)

	# Match position and add 180 degrees to Y rotation
	#camera_copy.rotation_degrees.y = -180.0
	camera_copy.rotation_degrees.x = -45.0
	camera_copy.global_position = Vector3(0, 20, -20)
	camera_copy.fov = 70.0

	return camera_copy

func camera_tween(camera_copy: Camera3D) -> void:
	var dur : float = 5.0
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera_copy, "global_position", player.global_position, dur)
	tween.parallel().tween_property(camera_copy, "rotation_degrees:x", camera_copy.rotation_degrees.x + 45.0, dur - 1.0).set_trans(Tween.TRANS_LINEAR)
	#tween.parallel().tween_property(self, "global_position", player.global_position, dur)
	#tween.parallel().tween_property(camera_copy, "rotation_degrees:x", camera_copy.rotation_degrees.x + 45.0, dur).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	#camera_copy.current = false
	self.queue_free()

#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		#begin_zoom_out_process()
