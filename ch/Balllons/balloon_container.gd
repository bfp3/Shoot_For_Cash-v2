extends Node3D
@export var move_speed := 2.0
var balloons_in_play := 0
var started := false
const BALLOON_Z_FRONT := 22.5
## How long intro (shop / pre-wait) balloons take to fly in.
const BALLOON_APPROACH_DURATION := 4.0
## Mid-round (after `wait`) balloons arrive this much faster.
const BALLOON_MID_ROUND_APPROACH_SPEEDUP := 1.0

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
			i.global_position.z = i.start_pos.z - 20.0
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

	var duration := 1.0

	for placement in placements:
		duration = clamp(duration - 0.1, 0.2, 1.0)
		var row := int(placement.row)
		var column := int(placement.column)
		if row < 1 or column < 1:
			row = randi_range(1, 3)
			column = randi_range(1, BALLOON_COLUMN_COUNT)
		await _spawn_one_balloon(row, column, duration, BALLOON_APPROACH_DURATION)


## Balloons listed before the first `wait` in a round sequence (shop / round-start intros).
func _balloons_before_first_wait(sequence: Array) -> Array:
	var intro: Array = []
	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait' or cmd == 'wait-until-clear':
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
	var approach := maxf(BALLOON_APPROACH_DURATION - BALLOON_MID_ROUND_APPROACH_SPEEDUP, 0.5)

	if bool(entry.get('all', false)):
		for row in LANE_Y.keys():
			for column in range(1, BALLOON_COLUMN_COUNT + 1):
				await _spawn_one_balloon(int(row), column, 0.15, approach)
		return

	await _spawn_one_balloon(
		_resolve_balloon_row(entry),
		_resolve_balloon_column(entry),
		0.0,
		approach
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


func _spawn_one_balloon(row: int, column: int, stagger_sec: float = 0.0, approach_duration: float = BALLOON_APPROACH_DURATION) -> void:
	var target_x := balloon_column_to_x(column)
	var target_y := balloon_lane_to_y(row)

	var balloon := _get_next_available_balloon()
	if balloon == null:
		push_warning("BalloonManager: no available balloon for row %d column %d" % [row, column])
		return

	balloons_in_play = clamp(balloons_in_play + 1, 0, get_children().size())

	balloon.behind_player = false
	balloon.show()
	balloon.global_position.x = target_x
	balloon.global_position.y = target_y
	balloon.move_balloon_in_front_of_player()

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.2)
	tween.tween_property(balloon, "global_position:z", BALLOON_Z_FRONT, approach_duration)

	if stagger_sec > 0.0:
		await get_tree().create_timer(stagger_sec, false).timeout


func _get_next_available_balloon() -> StaticBody3D:
	for i in get_children():
		if i is StaticBody3D and i.behind_player:
			return i
	return null


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
	_balloon.hide()
	_balloon.global_position.z = _balloon.start_pos.z - 27.0
	move_child(_balloon, get_child_count() - 1)


func note_balloon_left_play() -> void:
	balloons_in_play = clamp(balloons_in_play - 1, 0, get_children().size())
