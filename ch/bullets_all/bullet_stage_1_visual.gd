extends Node3D

var target_node : Node3D = null
var power_bullet_damage := 1
var power_bullet_speed := 1.0 # travel time in seconds

var start_position : Vector3
var elapsed_time := 0.0

func bullet_setup(_target_node : Node3D, _bullet_speed : float) -> void:
	target_node = _target_node
	power_bullet_speed *= 0.9
	power_bullet_speed = _bullet_speed

	start_position = global_position
	elapsed_time = 0.0

	set_physics_process(true)


func _physics_process(delta: float) -> void:

	if !is_instance_valid(target_node):
		#queue_free()
		$Trails.one_shot = true
		$Bullet_mesh.hide()
		return

	elapsed_time += delta

	var progress : float = clamp(elapsed_time / power_bullet_speed, 0.0, 1.0)

	# Continuously update target position so moving targets are tracked
	global_position = start_position.lerp(target_node.global_position, progress)

	# Face movement direction
	var to_target := target_node.global_position - global_position
	if to_target.length_squared() > 0.001:
		look_at(global_position + to_target.normalized(), Vector3.UP, true)

	if progress >= 1.0:
		global_position = target_node.global_position
		cleanUp()


func cleanUp() -> void:
	target_node = null
	#$Trails.emitting = false
	$Trails.one_shot = true
	$Bullet_mesh.hide()


func _on_trails_finished() -> void:
	queue_free()
