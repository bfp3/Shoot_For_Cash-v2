extends Node3D

@onready var pineapple : RigidBody3D  = $Pineapple
@onready var pineapple_2: RigidBody3D = $Pineapple2
@onready var pineapple_3: RigidBody3D = $Pineapple3

@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

func start_bonus_round() -> void:
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	%PerfectParticles.emitting = true
	%PerfectParticles2.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	
	await get_tree().create_timer(1.0).timeout
	launch_pineapple(pineapple)

	await get_tree().create_timer(2.0).timeout
	launch_pineapple(pineapple_2)

	await get_tree().create_timer(2.0).timeout
	launch_pineapple(pineapple_3)


func stop_pineapples() -> void:
	await get_tree().create_timer(2.0).timeout
	pineapple.reset_stats()
	pineapple_2.reset_stats()
	pineapple_3.reset_stats()


func launch_pineapple(body : RigidBody3D) -> void:
		
	body.update_active()
	var sideways := true
	if sideways:
		body.exit_side = body.ExitSide.TOP
		# Original vertical/sideways launch
		body.global_position.x = [-7,-5,-3,-1,1,3,5,7].pick_random()

		var x_variation = 0 #randf_range(-1.0, 1.0)
		var upward_force = randf_range(9.5, 10.0)

		var impulse = Vector3(
			x_variation,
			upward_force * body.force_multiplier,
			0.0
		) * body.pulse_magnitude

		body.apply_central_impulse(impulse)
		body.start_timer()

	else:
		# 50/50 chance of left->right or right->left
		var shoot_from_left := randf() < 0.5

		var force = (
			randf_range(9.5, 10.0)
			* body.force_multiplier
			* 1.5
			* body.pulse_magnitude
		)

		if shoot_from_left:
			body.exit_side = body.ExitSide.RIGHT
			body.global_position = left_marker.global_position
			body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
			body.start_timer()
		else:
			body.exit_side = body.ExitSide.LEFT
			body.global_position = right_marker.global_position
			body.apply_central_impulse(Vector3(force, 0.0, 0.0))
			body.start_timer()

	
