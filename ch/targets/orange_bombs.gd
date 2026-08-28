extends Node3D

@onready var orange: RigidBody3D = $Orange
@onready var orange_2: RigidBody3D = $Orange2
@onready var orange_3: RigidBody3D = $Orange3
@onready var orange_4: RigidBody3D = $Orange4
@onready var orange_5: RigidBody3D = $Orange5
@onready var orange_6: RigidBody3D = $Orange6


@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

func launch_orange(pos : Vector3) -> void:
	#return
	var body : Node3D
	for i in get_children():
		if i is not RigidBody3D:
			continue
		if i.rock_activated == false:
			body = i
			break
			
	if body == null:
		return
	body.update_active()

	if body.has_method("configure_multi_launch"):
		body.configure_multi_launch(pos)
	else:
		body.global_position.x = pos.x
		body.global_position.z = pos.z
	
	#if sideways:
	body.exit_side = body.ExitSide.TOP
	
	round_manager.orange_active += 1
	
	var x_variation = randf_range(-1.0, 1.0)
	# Keep a little horizontal drift unless column-snap is locking X to a lane.
	if body.get("snap_x_to_nearest_column") == true:
		x_variation = 0.0
	#var upward_force = randf_range(9.5, 10.0)
	
	var upward_force = 30.0

	var impulse = Vector3(
		x_variation,
		upward_force * body.force_multiplier,
		0.0
	) * body.pulse_magnitude

	body.apply_central_impulse(impulse)
	body.start_timer()



	
func stop_pineapples() -> void:
	await get_tree().create_timer(2.0, false).timeout
	orange.reset_stats()
	orange_2.reset_stats()
	orange_3.reset_stats()
	orange_3.reset_stats()
	orange_4.reset_stats()
	orange_5.reset_stats()
	orange_6.reset_stats()
