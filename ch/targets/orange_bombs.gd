extends Node3D

@onready var orange: RigidBody3D = $Orange
@onready var orange_2: RigidBody3D = $Orange2
@onready var orange_3: RigidBody3D = $Orange3
@onready var orange_4: RigidBody3D = $Orange4
@onready var orange_5: RigidBody3D = $Orange5
@onready var orange_6: RigidBody3D = $Orange6
@onready var orange_7: RigidBody3D = $Orange7
@onready var orange_8: RigidBody3D = $Orange8
@onready var orange_9: RigidBody3D = $Orange9

@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

func launch_pineapple(body) -> void:
	return
	round_manager.pineapple_mode = true
	body.update_active()
	
	# 50% chance sideways, 50% chance horizontal launch
	var sideways := randf() < 0.5

	#if sideways:
	body.exit_side = body.ExitSide.TOP
	# Original vertical/sideways launch
	body.global_position.x = randi_range(-8, 8)

	var x_variation = randf_range(-1.0, 1.0)
	var upward_force = randf_range(9.5, 10.0)

	var impulse = Vector3(
		x_variation,
		upward_force * body.force_multiplier,
		0.0
	) * body.pulse_magnitude

	body.apply_central_impulse(impulse)
	body.start_timer()

	#else:
		## 50/50 chance of left->right or right->left
		#var shoot_from_left := randf() < 0.5
#
		#var force = (
			#randf_range(9.5, 10.0)
			#* body.force_multiplier
			#* 1.5
			#* body.pulse_magnitude
		#)
#
		#if shoot_from_left:
			#body.exit_side = body.ExitSide.RIGHT
			#body.global_position = left_marker.global_position
			#body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
			#body.start_timer()
		#else:
			#body.exit_side = body.ExitSide.LEFT
			#body.global_position = right_marker.global_position
			#body.apply_central_impulse(Vector3(force, 0.0, 0.0))
			#body.start_timer()



func pineapple_round_1() -> void:
	launch_pineapple(orange)


func pineapple_round_2() -> void:
	launch_pineapple(orange_2)


func pineapple_round_3() -> void:
	launch_pineapple(orange_3)
	
func stop_pineapples() -> void:
	await get_tree().create_timer(2.0).timeout
	orange.reset_stats()
	orange_2.reset_stats()
	orange_3.reset_stats()
	orange_3.reset_stats()
	orange_4.reset_stats()
	orange_5.reset_stats()
	orange_6.reset_stats()
	orange_7.reset_stats()
	orange_8.reset_stats()
