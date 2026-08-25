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

## Same column / aim lane mapping as rocks (column 1 = +7 … column 8 = -7).
const COLUMN_1_X := 7.0
const COLUMN_STEP := 2.0
const COLUMN_COUNT := 8
const SIDE_LANE_OUTSIDE_1 := 0
const SIDE_LANE_OUTSIDE_8 := 9
const AIM_LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}
const AIM_PLANE_Z := 23.0
const STRAIGHT_UP_FORCE := 15.0
const LATERAL_LAUNCH_GRAVITY := 0.0
const LATERAL_FLIGHT_SPEED := 12.0


func start_bonus_round() -> void:
	%PerfectPineappleRound.play(0.5)
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
	for child in get_children():
		if child is RigidBody3D and child.has_method('reset_stats'):
			child.reset_stats()


func column_to_x(column: int) -> float:
	if _is_side_lane_column(column):
		return _column_to_x_unclamped(column)
	var clamped := clampi(column, 1, COLUMN_COUNT)
	if clamped != column:
		push_warning("PineappleLauncher: column %d out of range [1, %d], clamped to %d." % [column, COLUMN_COUNT, clamped])
	return _column_to_x_unclamped(clamped)


func _column_to_x_unclamped(column: int) -> float:
	var rocks := _rock_manager()
	if rocks and rocks.has_method("column_to_x_for_aim"):
		return float(rocks.column_to_x_for_aim(column))
	var half_span := float(COLUMN_COUNT - 1) * 0.5 * COLUMN_STEP
	if column < 1:
		return half_span + COLUMN_STEP * float(1 - column)
	if column > COLUMN_COUNT:
		return -half_span - COLUMN_STEP * float(column - COLUMN_COUNT)
	return COLUMN_1_X - float(column - 1) * COLUMN_STEP


func _is_side_lane_column(column: int) -> bool:
	return column == SIDE_LANE_OUTSIDE_1 or column == SIDE_LANE_OUTSIDE_8


func _is_lateral_launch(entry: Dictionary) -> bool:
	if int(entry.get("spawn_row", -1)) >= 1:
		return true
	return _is_side_lane_column(int(entry.get("column", -1)))


func _rock_manager() -> Node:
	if round_manager and round_manager.get("rocks_container") != null:
		return round_manager.rocks_container
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.get("rocks_container") != null:
		return rm.rocks_container
	return null


## Level-script launch: `pineapple 1` (straight up), `pineapple 1 A8` (aimed),
## or `pineapple A0 A8` (lateral fly-across from off-camera).
func launch_from_spawn_entry(entry: Dictionary) -> void:
	var body := _get_next_available_pineapple()
	if body == null:
		push_warning("PineappleLauncher: no available pineapple for spawn")
		return

	if _is_lateral_launch(entry):
		_launch_lateral_pineapple(body, entry)
		return

	var column := int(entry.get('column', -1))
	if _is_side_lane_column(column):
		_launch_lateral_pineapple(body, entry)
		return
	if column < 1:
		column = randi_range(1, COLUMN_COUNT)
	var x_pos := column_to_x(column)
	var aim_row := int(entry.get('aim_row', -1))
	var aim_column := int(entry.get('aim_column', -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 0:
		aim_column = randi_range(1, COLUMN_COUNT)
	launch_pineapple(body, x_pos, aim_row, aim_column)


func _launch_lateral_pineapple(body: RigidBody3D, entry: Dictionary) -> void:
	body.update_active()
	var column := int(entry.get("column", -1))
	if not _is_side_lane_column(column) and column < 1:
		column = randi_range(1, COLUMN_COUNT)
	var spawn_row := int(entry.get("spawn_row", -1))
	var aim_row := int(entry.get("aim_row", -1))
	var aim_column := int(entry.get("aim_column", -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 0:
		aim_column = randi_range(1, COLUMN_COUNT)
	if spawn_row < 1:
		spawn_row = aim_row

	var spawn := _lateral_spawn_world(column, spawn_row)
	var aim := _lateral_aim_world(aim_row, aim_column)
	body.global_position = spawn
	if spawn.x < aim.x:
		body.exit_side = body.ExitSide.LEFT
	else:
		body.exit_side = body.ExitSide.RIGHT
	if body.has_method("arm_offscreen_entry"):
		body.arm_offscreen_entry()

	BallisticAim.configure_body_for_ballistic_launch(body, LATERAL_LAUNCH_GRAVITY)
	var dist := spawn.distance_to(aim)
	var flight_t := clampf(dist / LATERAL_FLIGHT_SPEED, 0.45, 1.75)
	var impulse := BallisticAim.impulse_to_point(
		body, spawn, aim, flight_t, LATERAL_LAUNCH_GRAVITY, 1.0, 0.0
	)
	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(Vector3.RIGHT * 3000.0)
	body.start_timer()


func _lateral_spawn_world(column: int, spawn_row: int) -> Vector3:
	var x := column_to_x(column)
	var rocks := _rock_manager()
	if rocks and rocks.has_method("offscreen_spawn_x") and _is_side_lane_column(column):
		x = float(rocks.offscreen_spawn_x(column))
	return Vector3(x, float(AIM_LANE_Y.get(spawn_row, AIM_LANE_Y[1])), AIM_PLANE_Z)


func _lateral_aim_world(aim_row: int, aim_column: int) -> Vector3:
	var x := column_to_x(aim_column)
	var rocks := _rock_manager()
	if rocks and rocks.has_method("offscreen_spawn_x") and _is_side_lane_column(aim_column):
		x = float(rocks.offscreen_spawn_x(aim_column))
	return Vector3(x, float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1])), AIM_PLANE_Z)


func _get_next_available_pineapple() -> RigidBody3D:
	for child in get_children():
		if child is RigidBody3D and child.get('rock_activated') == false:
			return child
	return null


## Ballistic launch through aim cell apex (same math as RockManager).
## Callers should resolve `?` / random aim before calling when random aim is desired.
func launch_pineapple(body: RigidBody3D, x_pos: float, aim_row: int = 0, aim_column: int = 0) -> void:
	body.update_active()
	body.exit_side = body.ExitSide.TOP

	body.global_position.x = x_pos

	var impulse: Vector3
	if aim_row > 0 and aim_column > 0:
		BallisticAim.configure_body_for_ballistic_launch(body)
		impulse = _pineapple_aimed_impulse(body, aim_row, aim_column)
	else:
		body.linear_damp = 0.0
		impulse = Vector3(0.0, STRAIGHT_UP_FORCE * body.force_multiplier, 0.0) * body.pulse_magnitude

	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(Vector3.RIGHT * 3000.0)
	body.start_timer()


func _pineapple_aimed_impulse(body: RigidBody3D, aim_row: int, aim_column: int) -> Vector3:
	var aim_pos := Vector3(
		column_to_x(aim_column),
		float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1])),
		AIM_PLANE_Z
	)
	return BallisticAim.impulse_to_point(body, body.global_position, aim_pos)
