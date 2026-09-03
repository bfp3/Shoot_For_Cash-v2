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

## Multi-shot oranges sit on a random aim-grid cell and only peek through the reticle.
@export var invisible_oranges := false

const INVISIBLE_COLUMN_COUNT := 8
const INVISIBLE_AIM_LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}
const INVISIBLE_AIM_PLANE_Z := 23.0


func launch_orange(pos : Vector3) -> void:
	return
	var body : Node3D
	for i in get_children():
		if i is not RigidBody3D:
			continue
		if i.rock_activated == false:
			body = i
			break
			
	if body == null:
		return
	if invisible_oranges:
		if body.has_method("prepare_invisible_launch"):
			body.prepare_invisible_launch()
		body.update_active()
		_launch_invisible_orange(body)
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
	#body.start_timer()


func _launch_invisible_orange(body: Node3D) -> void:
	return
	var column := randi_range(1, INVISIBLE_COLUMN_COUNT)
	var aim_row := randi_range(1, 3)
	var aim_pos := _invisible_aim_world(aim_row, column)
	if body.has_method("configure_invisible_launch"):
		body.configure_invisible_launch(aim_pos)
	else:
		body.global_position = aim_pos
	body.exit_side = body.ExitSide.TOP
	if round_manager:
		round_manager.orange_active += 1
	## Hang on the cell — do not ballistic-launch from the pool Y (below the board).
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		rb.linear_damp = 0.0
		rb.gravity_scale = 0.0
		rb.linear_velocity = Vector3.ZERO
		rb.sleeping = false


func _invisible_aim_world(aim_row: int, column: int) -> Vector3:
	var rocks := _rock_manager()
	if rocks and rocks.has_method("aim_cell_world_position"):
		return rocks.aim_cell_world_position(aim_row, column)
	var x := 7.0 - float(column - 1) * 2.0
	var y := float(INVISIBLE_AIM_LANE_Y.get(aim_row, INVISIBLE_AIM_LANE_Y[1]))
	return Vector3(x, y, INVISIBLE_AIM_PLANE_Z)


func _rock_manager() -> Node:
	if round_manager and round_manager.get("rocks_container") != null:
		return round_manager.rocks_container
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.get("rocks_container") != null:
		return rm.rocks_container
	return get_tree().get_first_node_in_group("rocks_container")



	
func stop_pineapples() -> void:
	clear_live_oranges()


func clear_live_oranges() -> void:
	for child in get_children():
		if child is RigidBody3D and child.has_method("dismiss_quietly_for_round_end"):
			child.dismiss_quietly_for_round_end()
		elif child is RigidBody3D and child.has_method("reset_stats"):
			child.reset_stats()
