extends Node3D

## Must match player_shooting_weapon.BULLET_REFERENCE_DISTANCE.
## _bullet_speed is seconds to cover this many units; travel duration scales with distance.
const BULLET_REFERENCE_DISTANCE := 23.0

var target_node : Node3D = null
var target_position : Vector3
var has_target_node := false

var power_bullet_damage := 1
var power_bullet_speed := 1.0 # travel duration for this shot (seconds)
var start_position : Vector3
var elapsed_time := 0.0


func _travel_duration(distance: float, seconds_per_reference: float) -> float:
	if seconds_per_reference <= 0.0:
		return 0.0
	return distance * seconds_per_reference / BULLET_REFERENCE_DISTANCE


func bullet_setup(_target_node : Node3D, _bullet_speed : float) -> void:
	target_node = _target_node
	has_target_node = true
	start_position = global_position
	elapsed_time = 0.0
	power_bullet_speed = _travel_duration(
		start_position.distance_to(_target_node.global_position),
		_bullet_speed
	)
	set_physics_process(true)


func bullet_setup_no_target(_target_position : Vector3, _bullet_speed : float) -> void:
	target_node = null
	has_target_node = false
	target_position = _target_position
	start_position = global_position
	elapsed_time = 0.0
	power_bullet_speed = _travel_duration(
		start_position.distance_to(target_position),
		_bullet_speed
	)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if has_target_node and !is_instance_valid(target_node):
		$Bullet_mesh.hide()
		return

	elapsed_time += delta
	var progress : float
	if power_bullet_speed <= 0.0:
		progress = 1.0
	else:
		progress = clamp(elapsed_time / power_bullet_speed, 0.0, 1.0)

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


#func _on_area_3d_body_entered(body: Node3D) -> void:
	#if body.name.contains('Balloon'):
		#if body.balloon_type == body.BalloonType.BLUE:
			#body.rock_pop_balloon()
			#return
		#else:
			#body.start_destroyed_process()
