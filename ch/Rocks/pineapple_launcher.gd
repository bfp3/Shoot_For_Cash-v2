extends Node3D

@onready var pineapple : RigidBody3D  = $Pineapple
@onready var pineapple_2: RigidBody3D = $Pineapple2
@onready var pineapple_3: RigidBody3D = $Pineapple3

#@onready var pineapple_4: RigidBody3D = $Pineapple4
#@onready var pineapple_5: RigidBody3D = $Pineapple5
#@onready var pineapple_6: RigidBody3D = $Pineapple6
#@onready var pineapple_7: RigidBody3D = $Pineapple7
#@onready var pineapple_8: RigidBody3D = $Pineapple8
#@onready var pineapple_9: RigidBody3D = $Pineapple9


@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

func launch_pineapple(body : RigidBody3D) -> void:
	
	#round_manager.pineapple_mode = true
	
	#var body : RigidBody3D
	#for i in get_children():
		#if i.rock_activated == false:
			#body = i
			#break

	
	body.update_active()
	# 50% chance sideways, 50% chance horizontal launch
	#var sideways := randf() < 0.5
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



func pineapple_round_1() -> void:
	print('Pineapple Round 1')
	launch_pineapple(pineapple)


func pineapple_round_2() -> void:
	launch_pineapple(pineapple_2)


func pineapple_round_3() -> void:
	launch_pineapple(pineapple_3)
	
func stop_pineapples() -> void:
	print('Stop Pineapples')
	await get_tree().create_timer(2.0).timeout
	pineapple.reset_stats()
	pineapple_2.reset_stats()
	pineapple_3.reset_stats()
	#pineapple_4.reset_stats()
	#pineapple_5.reset_stats()
	#pineapple_6.reset_stats()
	#pineapple_7.reset_stats()
	#pineapple_8.reset_stats()
	#pineapple_9.reset_stats()
