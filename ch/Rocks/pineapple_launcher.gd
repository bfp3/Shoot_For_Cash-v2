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
const AIM_LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}
const STRAIGHT_UP_FORCE := 15.0


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
	var clamped := clampi(column, 1, COLUMN_COUNT)
	if clamped != column:
		push_warning("PineappleLauncher: column %d out of range [1, %d], clamped to %d." % [column, COLUMN_COUNT, clamped])
	return COLUMN_1_X - float(clamped - 1) * COLUMN_STEP


## Level-script launch: `pineapple 1` (straight up) or `pineapple 1 A8` (aimed diagonal).
func launch_from_spawn_entry(entry: Dictionary) -> void:
	var body := _get_next_available_pineapple()
	if body == null:
		push_warning("PineappleLauncher: no available pineapple for spawn")
		return

	var column := int(entry.get('column', -1))
	if column < 1:
		column = randi_range(1, COLUMN_COUNT)
	var x_pos := column_to_x(column)
	var aim_row := int(entry.get('aim_row', -1))
	var aim_column := int(entry.get('aim_column', -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 1:
		aim_column = randi_range(1, COLUMN_COUNT)
	launch_pineapple(body, x_pos, aim_row, aim_column)


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
		23.0
	)
	return BallisticAim.impulse_to_point(body, body.global_position, aim_pos)
