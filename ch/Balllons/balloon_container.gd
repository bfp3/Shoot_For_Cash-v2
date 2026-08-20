extends Node3D
@export var move_speed := 2.0
## If true, shooting a round balloon costs a strike. If false, it is a $10 penalty.
@export var shooting_balloon_gives_strike := true
## Seconds to fly from spawn depth to the rest position. Lower = faster.
@export var approach_duration := 1.2
## Pause before the balloon starts flying in.
@export var spawn_start_delay := 0.0
## How far behind the rest position balloons spawn (world Z).
@export var spawn_distance := 12.0
## Stagger between intro balloons at round/shop start.
@export var intro_stagger := 0.15
var balloons_in_play := 0
var started := false
const BALLOON_Z_FRONT := 22.5
const BALLOON_SCENE := preload("res://ch/Rocks/Balloon.tscn")

# Column 1 -> -7, column 2 -> -5, ... column 8 -> 7 (mirrored vs RockManager)
const BALLOON_COLUMN_1_X := 7.0
const BALLOON_COLUMN_STEP := -2.0
const BALLOON_COLUMN_COUNT := 8

const LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}

func _ready() -> void:
	move_all_ballons_back()
	set_physics_process(false)

func move_all_ballons_back() -> void:
	for i in get_children():
		if i is StaticBody3D:
			i.global_position.z = _spawn_z()
			i.hide()

func balloon_column_to_x(column: int) -> float:
	var clamped_column := clampi(column, 1, BALLOON_COLUMN_COUNT)
	if clamped_column != column:
		push_warning("BalloonManager: column %d out of range [1, %d], clamped to %d." % [column, BALLOON_COLUMN_COUNT, clamped_column])
	return BALLOON_COLUMN_1_X + float(clamped_column - 1) * BALLOON_COLUMN_STEP

func balloon_lane_to_y(lane: int) -> float:
	if not LANE_Y.has(lane):
		push_warning("BalloonManager: lane %d out of range [1,3], defaulting to lane 1." % lane)
		return LANE_Y[1]
	return LANE_Y[lane]


func balloon_cell_world_position(row: int, column: int) -> Vector3:
	return Vector3(balloon_column_to_x(column), balloon_lane_to_y(row), BALLOON_Z_FRONT)

func add_balloon(_balloon_array : Array) -> void:
	# Only balloons that appear before the first `wait` arrive at round/shop start.
	# Balloons after a wait are spawned mid-round by RockManager.
	var balloon_array := _balloons_before_first_wait(_balloon_array)

	if balloon_array.is_empty():
		return

	if started:
		return

	started = true

	# Collect balloon placements from spawn dicts and legacy int codes.
	var placements: Array = []
	var spawn_all := false

	for entry in balloon_array:
		if entry is Dictionary:
			if String(entry.get('cmd', '')).to_lower() != 'balloon':
				continue
			if bool(entry.get('all', false)):
				spawn_all = true
				break
			placements.append({
				'row': int(entry.get('row', -1)),
				'column': int(entry.get('column', -1)),
			})
			continue

		if typeof(entry) != TYPE_INT:
			continue

		var code: int = entry
		if code == 399:
			spawn_all = true
			break
		if code <= 300 or code > 400:
			continue

		var _offset: int = code - 300
		placements.append({
			'row': int(_offset / 10),
			'column': _offset % 10,
		})

	if spawn_all:
		placements.clear()
		for row in LANE_Y.keys():
			for column in range(1, BALLOON_COLUMN_COUNT + 1):
				placements.append({'row': row, 'column': column})

	if placements.is_empty():
		started = false
		return

	var duration := intro_stagger

	for placement in placements:
		var row := int(placement.row)
		var column := int(placement.column)
		if row < 1 or column < 1:
			row = randi_range(1, 3)
			column = randi_range(1, BALLOON_COLUMN_COUNT)
		await _spawn_one_balloon(row, column, duration, approach_duration)


## Balloons listed before the first `wait` in a round sequence (shop / round-start intros).
func _balloons_before_first_wait(sequence: Array) -> Array:
	var intro: Array = []
	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait' or cmd == 'wait-until-clear' or cmd == 'clear' or cmd == 'clear-balloon':
				break
			if cmd == 'balloon':
				intro.append(entry)
			continue
		if typeof(entry) == TYPE_INT:
			var code: int = entry
			if code == 399 or (code > 300 and code <= 400):
				intro.append(entry)
	return intro


## Mid-round spawn for a single `balloon` command (after a wait).
func spawn_balloon_entry(entry: Dictionary) -> void:
	if String(entry.get('cmd', '')).to_lower() != 'balloon':
		return

	started = true
	if bool(entry.get('all', false)):
		for row in LANE_Y.keys():
			for column in range(1, BALLOON_COLUMN_COUNT + 1):
				await _spawn_one_balloon(int(row), column, intro_stagger, approach_duration)
		return

	await _spawn_one_balloon(
		_resolve_balloon_row(entry),
		_resolve_balloon_column(entry),
		0.0,
		approach_duration
	)


func _resolve_balloon_row(entry: Dictionary) -> int:
	var row := int(entry.get('row', -1))
	if row < 1:
		return randi_range(1, 3)
	return row


func _resolve_balloon_column(entry: Dictionary) -> int:
	var column := int(entry.get('column', -1))
	if column < 1:
		return randi_range(1, BALLOON_COLUMN_COUNT)
	return column


func _spawn_one_balloon(row: int, column: int, stagger_sec: float = 0.5, approach_duration: float = 3.5) -> void:
	var target_x := balloon_column_to_x(column)
	var target_y := balloon_lane_to_y(row)

	## Cell already has a live balloon — keep it, do not drift it away or spawn a replacement.
	if _balloon_occupying_slot(row, column):
		return

	var balloon := _get_next_available_balloon()
	if balloon == null:
		balloon = _instantiate_extra_balloon()
	if balloon == null:
		push_warning("BalloonManager: no available balloon for row %d column %d" % [row, column])
		return

	balloons_in_play = clamp(balloons_in_play + 1, 0, get_children().size())

	balloon.occupy_row = row
	balloon.occupy_column = column
	balloon.behind_player = false
	balloon.show()
	balloon.global_position.x = target_x
	balloon.global_position.y = target_y
	balloon.global_position.z = _spawn_z()
	balloon.move_balloon_in_front_of_player()

	if balloon.has_method("kill_slot_tween"):
		balloon.kill_slot_tween()
	balloon.slot_tween = balloon.create_tween()
	balloon.slot_tween.set_ease(Tween.EASE_IN_OUT)
	balloon.slot_tween.set_trans(Tween.TRANS_SINE)
	if spawn_start_delay > 0.0:
		balloon.slot_tween.tween_interval(spawn_start_delay)
	balloon.slot_tween.tween_property(balloon, "global_position:z", BALLOON_Z_FRONT, maxf(approach_duration, 0.05))

	if stagger_sec > 0.0:
		await get_tree().create_timer(stagger_sec, false).timeout


## Send every live round balloon away. Each leftover awards +$10 into the cash pool.
func clear_live_balloons() -> void:
	for child in get_children():
		if not (child is StaticBody3D):
			continue
		if bool(child.get("behind_player")):
			continue
		if not bool(child.get("rock_activated")):
			continue
		gl_PlayerState.add_to_cash_pool(10, child.global_position)
		if child.has_method("drift_away_for_checkpoint"):
			child.drift_away_for_checkpoint()


## Drift the live balloon occupying this grid cell, if any. Same +$10 as `clear`.
func clear_balloon_at(row: int, column: int) -> void:
	var balloon := _balloon_occupying_slot(row, column)
	if balloon == null:
		return
	gl_PlayerState.add_to_cash_pool(10, balloon.global_position)
	if balloon.has_method("drift_away_for_checkpoint"):
		balloon.drift_away_for_checkpoint()


func _balloon_occupying_slot(row: int, column: int) -> StaticBody3D:
	var target_x := balloon_column_to_x(column)
	var target_y := balloon_lane_to_y(row)
	for child in get_children():
		if not (child is StaticBody3D):
			continue
		if bool(child.get("behind_player")):
			continue
		if not bool(child.get("rock_activated")):
			continue
		if int(child.get("occupy_row")) == row and int(child.get("occupy_column")) == column:
			return child
		var pos: Vector3 = child.global_position
		if absf(pos.x - target_x) < 0.75 and absf(pos.y - target_y) < 0.75:
			return child
	return null


func _get_next_available_balloon() -> StaticBody3D:
	for i in get_children():
		if i is StaticBody3D and i.behind_player:
			return i
	return null


func _instantiate_extra_balloon() -> StaticBody3D:
	var extra: StaticBody3D = BALLOON_SCENE.instantiate()
	for child in get_children():
		if child is StaticBody3D and "balloon_type" in child:
			extra.balloon_type = child.balloon_type
			break
	add_child(extra)
	extra.behind_player = true
	extra.hide()
	if extra.has_method("configure_balloon_colour"):
		extra.configure_balloon_colour()
	return extra


func restart() -> void:
	await get_tree().create_timer(1.0, false).timeout
	for child in get_children():
		if child is StaticBody3D:
			child.show()
			child.behind_player = true
	move_all_ballons_back()


func add_all_balloons() -> void:
	var full_array: Array = []
	for row in LANE_Y.keys():
		for column in range(1, BALLOON_COLUMN_COUNT + 1):
			full_array.append({'cmd': 'balloon', 'row': row, 'column': column})
	await add_balloon(full_array)

func add_bonuses() -> void:
	var bonus_counter := 0
	for i in get_children():
		if i is StaticBody3D and not i.behind_player:
			bonus_counter += 1
			gl_PlayerState.add_bonus(bonus_counter)

			
			
	await get_tree().create_timer(0.05, false).timeout
	return



func end_round() -> void:
	#await add_bonuses()
	started = false
	var counter := 0
	var dur := 0.3
	var dur_increment := 0.05
	for i in get_children():
		if i is StaticBody3D and not i.behind_player:
			counter += 1
			i.end_of_the_round_pop_balloon(counter)
			await get_tree().create_timer(dur, false).timeout
			dur = clamp(dur - dur_increment, 0.05,dur)


func add_balloon_back_into_list(_balloon: StaticBody3D) -> void:
	if !is_instance_valid(_balloon):
		return

	await get_tree().create_timer(4.0, false).timeout
	_balloon.behind_player = true
	_balloon.occupy_row = -1
	_balloon.occupy_column = -1
	_balloon.hide()
	_balloon.global_position.z = _spawn_z()
	move_child(_balloon, get_child_count() - 1)


func _spawn_z() -> float:
	return BALLOON_Z_FRONT - spawn_distance


func note_balloon_left_play() -> void:
	balloons_in_play = clamp(balloons_in_play - 1, 0, get_children().size())
