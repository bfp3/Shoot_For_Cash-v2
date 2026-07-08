extends Node3D

var target_node : Node3D = null
var target_position : Vector3
var has_target_node := false

var power_bullet_damage := 1
var power_bullet_speed := 1.0 # travel time in seconds
var start_position : Vector3
var elapsed_time := 0.0


func bullet_setup(_target_node : Node3D, _bullet_speed : float) -> void:
	target_node = _target_node
	has_target_node = true
	power_bullet_speed *= 0.9
	power_bullet_speed = _bullet_speed
	start_position = global_position
	elapsed_time = 0.0
	set_physics_process(true)


func bullet_setup_no_target(_target_position : Vector3, _bullet_speed : float) -> void:
	target_node = null
	has_target_node = false
	target_position = _target_position
	power_bullet_speed *= 0.9
	power_bullet_speed = _bullet_speed
	start_position = global_position
	elapsed_time = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if has_target_node and !is_instance_valid(target_node):
		$Bullet_mesh.hide()
		return

	elapsed_time += delta
	var progress : float = clamp(elapsed_time / power_bullet_speed, 0.0, 1.0)

	var current_target_pos : Vector3
	if has_target_node:
		current_target_pos = target_node.global_position
	else:
		current_target_pos = target_position

	# Continuously update target position so moving targets are tracked
	global_position = start_position.lerp(current_target_pos, progress)

	# Face movement direction
	var to_target := current_target_pos - global_position
	if to_target.length_squared() > 0.001:
		look_at(global_position + to_target.normalized(), Vector3.UP, true)

	if progress >= 1.0:
		global_position = current_target_pos
		cleanUp()


func cleanUp() -> void:
	target_node = null
	self.queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name.contains('Balloon'):
		body.start_destroyed_process()
