extends Node3D
@export var move_speed := 2.0
var balloons_in_play := 0
var started := false
const BALLOON_Z_FRONT := 22.5

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
			i.global_position.z = i.start_pos.z - 27.0
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
	var balloon_array = _balloon_array
	
	if balloon_array.is_empty():
		return
	
	if started:
		return
		
	started = true

	
	if 399 in balloon_array:
		await add_all_balloons()
		return
	
	for i in balloon_array:
		if i <= 300 || i > 400:
			balloon_array.erase(i)
		#else:
			#i -= 300

	if balloon_array.is_empty():
		return
	
	#print('Balloon Codes --- ', balloon_array )
	
	for code in balloon_array:
		if code < 300:
			continue

		var _offset : int = code - 300
		var column : int = int(_offset / 10)
		var lane : int = _offset % 10

		var target_x := balloon_column_to_x(lane)
		var target_y := balloon_lane_to_y(column)

		var balloon := _get_next_available_balloon()
		if balloon == null:
			push_warning("BalloonManager: no available balloon for code %d" % code)
			continue

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
		tween.tween_property(balloon, "global_position:z", BALLOON_Z_FRONT, 5.0)

		await get_tree().create_timer(1.5).timeout

func _get_next_available_balloon() -> StaticBody3D:
	for i in get_children():
		if i is StaticBody3D and i.behind_player:
			return i
	return null


func restart() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in get_children():
		if child is StaticBody3D:
			child.show()
			child.behind_player = true
	move_all_ballons_back()


func add_all_balloons() -> void:
	var full_array : Array = []
	for column in range(1, BALLOON_COLUMN_COUNT + 1):
		for lane in LANE_Y.keys():
			full_array.append(300 + (column * 10) + lane)
	
	await add_balloon(full_array)

func add_bonuses() -> void:
	var bonus_counter := 0
	for i in get_children():
		if i is StaticBody3D and not i.behind_player:
			bonus_counter += 1
			gl_PlayerState.add_bonus(bonus_counter)

			
			
	await get_tree().create_timer(0.05).timeout
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
			await get_tree().create_timer(dur).timeout
			dur = clamp(dur - dur_increment, 0.05,dur)


func add_balloon_back_into_list(_balloon: StaticBody3D) -> void:
	if !is_instance_valid(_balloon):
		return

	balloons_in_play = clamp(balloons_in_play - 1, 0, get_children().size())

	await get_tree().create_timer(4.0).timeout
	_balloon.behind_player = true
	_balloon.hide()
	_balloon.global_position.z = _balloon.start_pos.z - 27.0
	move_child(_balloon, get_child_count() - 1)
