extends Node3D

var target_node : Node3D = null
var target_position : Vector3
var has_target_node := false

var power_bullet_damage := 1
var power_bullet_speed := 1.0 # travel time in seconds
var start_position : Vector3
var elapsed_time := 0.0
## Peak height (world units) of a parabolic arc for no-target / miss shots. 0 = straight lerp.
var lob_height := 0.0


func bullet_setup(_target_node : Node3D, _bullet_speed : float) -> void:
	target_node = _target_node
	has_target_node = true
	lob_height = 0.0
	power_bullet_speed *= 0.9
	power_bullet_speed = _bullet_speed
	start_position = global_position
	elapsed_time = 0.0
	set_physics_process(true)


func bullet_setup_no_target(_target_position : Vector3, _bullet_speed : float, _lob_height: float = 0.0) -> void:
	target_node = null
	has_target_node = false
	target_position = _target_position
	lob_height = maxf(_lob_height, 0.0)
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
	var travel := maxf(power_bullet_speed, 0.001)
	var progress : float = clamp(elapsed_time / travel, 0.0, 1.0)

	var current_target_pos : Vector3
	if has_target_node:
		current_target_pos = target_node.global_position
	else:
		current_target_pos = target_position

	# Continuously update target position so moving targets are tracked
	var pos := start_position.lerp(current_target_pos, progress)
	if lob_height > 0.0 and not has_target_node:
		pos.y += sin(progress * PI) * lob_height
	global_position = pos

	# Face movement direction
	var look_at_pos := current_target_pos
	if lob_height > 0.0 and not has_target_node:
		# Aim along the arc tangent so the mesh follows the lob
		var next_progress = clamp(progress + 0.02, 0.0, 1.0)
		var next_pos := start_position.lerp(current_target_pos, next_progress)
		next_pos.y += sin(next_progress * PI) * lob_height
		look_at_pos = next_pos
	var to_target := look_at_pos - global_position
	if to_target.length_squared() > 0.001:
		look_at(global_position + to_target.normalized(), Vector3.UP, true)

	if progress >= 1.0:
		global_position = current_target_pos
		cleanUp()


func cleanUp() -> void:
	target_node = null
	self.queue_free()
