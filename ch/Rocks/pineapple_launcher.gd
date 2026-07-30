extends Node3D

@onready var pineapple : RigidBody3D  = $Pineapple
@onready var pineapple_2: RigidBody3D = $Pineapple2
@onready var pineapple_3: RigidBody3D = $Pineapple3

@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

var pineapple_positions: Array[float] = []
var x_positions : Array = [-7,-5,-3,-1,1,3,5,7]
var starting_pos_x := 0.0

func start_bonus_round() -> void:
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	%PerfectParticles.emitting = true
	%PerfectParticles2.emitting = true
	
	# Pick a random starting position
	var start_index := randi() % x_positions.size()

	var direction = [-1, 1].pick_random()

	pineapple_positions.clear()

	for i in range(3):
		var index = (start_index + i * direction) % x_positions.size()

		# Godot's % can return negative numbers
		if index < 0:
			index += x_positions.size()

		pineapple_positions.append(x_positions[index])
	
	
	await get_tree().create_timer(1.0, false).timeout
	
	await get_tree().create_timer(1.0, false).timeout
	launch_pineapple(pineapple, pineapple_positions[0])

	await get_tree().create_timer(2.0, false).timeout
	launch_pineapple(pineapple_2, pineapple_positions[1])

	await get_tree().create_timer(2.0, false).timeout
	launch_pineapple(pineapple_3, pineapple_positions[2])


func stop_pineapples() -> void:
	await get_tree().create_timer(2.0, false).timeout
	pineapple.reset_stats()
	pineapple_2.reset_stats()
	pineapple_3.reset_stats()


func launch_pineapple(body: RigidBody3D, x_pos: float) -> void:

	body.update_active()
	body.exit_side = body.ExitSide.TOP

	body.global_position.x = x_pos

	var x_variation = 0
	var upward_force = 15.0

	var impulse = Vector3(
		x_variation,
		upward_force * body.force_multiplier,
		0.0
	) * body.pulse_magnitude

	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(Vector3.RIGHT * 3000.0)
	body.start_timer()

	
	
