extends Node3D
@export_range(1, 3, 1) var starting_balloons := 3
@export var move_speed := 2.0
var current_round := 0
var new_round_checker := 0

var blue_offset_y := 0

@export var round_manager : RoundManager 

@onready var balloon: StaticBody3D = $PlayerBalloon
@onready var balloon_2: StaticBody3D = $PlayerBalloon2
@onready var balloon_3: StaticBody3D = $PlayerBalloon3

@onready var balloon_pos_1: Marker3D = $'../Balloon_wait_positions/Balloon_pos_1'
@onready var balloon_pos_2: Marker3D = $'../Balloon_wait_positions/Balloon_pos_2'
@onready var balloon_pos_3: Marker3D = $'../Balloon_wait_positions/Balloon_pos_3'

var current_balloon = null
var balloons_popped := 0
var total_balloons_remaining := 0

func _ready() -> void:
	move_all_ballons_back()
	set_physics_process(false)
	
	await get_tree().create_timer(1.0).timeout
	configure_starting_balloons()
	
func configure_starting_balloons() -> void:
	var balloon_list := [balloon, balloon_2, balloon_3]

	for i in range(balloon_list.size()):
		if i >= starting_balloons:
			balloon_list[i].queue_free()

	total_balloons_remaining = starting_balloons
	
	
func check_balloons_status() -> void:
	
	if get_children().size() > 0:
		if current_balloon == null:
			add_balloon_replacement()
		else:
			reposition_balloon()
	
func move_all_ballons_back() -> void:

	var wait_positions = [
		balloon_pos_1,
		balloon_pos_2,
		balloon_pos_3
	]

	var index := 0
	for child in get_children():
		if child is StaticBody3D:
			if index < wait_positions.size():
				child.global_position = wait_positions[index].global_position
			#child.hide()
			index += 1


func add_balloon_replacement() -> void:
	current_balloon = null
		
	#await get_tree().create_timer(2.0).timeout
	for i in get_children():
		if i is StaticBody3D:
			if i.behind_player:
				current_balloon = i
				i.move_balloon_in_front_of_player()
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(i, "global_position", i.start_pos, 4.0).as_relative()

				break

func reposition_balloon() -> void:
	return
	if current_balloon == null:
		return
		
	var target_pos: Vector3
	var distance := 0.0
	
	while true:
		var rand_x = randf_range(-13.0, 10.0)
		#var rand_y = randf_range(4.0, 6.0)
		var rand_y = current_balloon.start_pos.y - blue_offset_y
		
		target_pos = Vector3(rand_x, rand_y, current_balloon.global_position.z)
		
		distance = current_balloon.global_position.distance_to(target_pos)
		
		if distance >= 2.0 and distance <= 7.0:
			break
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	#tween.tween_interval(3.0)
	tween.tween_property(current_balloon, "global_position:x", target_pos.x, 6.0)
	tween.parallel().tween_property(current_balloon, "global_position:y", target_pos.y, 6.0)
	tween.parallel().tween_property(current_balloon, "global_position:z", 23.225, 6.0)

func red_penalty() -> void:
	blue_offset_y =  clamp(blue_offset_y + 2, 0, 12)
	#reposition_balloon()
	current_balloon.money_label_3d.print_text(current_balloon.global_position, 'BLUE DOWN')
	
	if current_balloon == null:
		return
		
	var rand_y = current_balloon.start_pos.y - blue_offset_y

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_balloon, "global_position:y", rand_y, 3.0)
	
func white_reward() -> void:
	blue_offset_y =  clamp(blue_offset_y - 2, 0, 100)
	#reposition_balloon()
	current_balloon.money_label_3d.print_text(current_balloon.global_position, 'BLUE UP!')

	if current_balloon == null:
		return
		
	var rand_y = current_balloon.start_pos.y - blue_offset_y

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_balloon, "global_position:y", rand_y, 3.0)


func add_balloon() -> void:
	into_the_distance()
	return
	#for l in range(1):
	await get_tree().create_timer(2.0).timeout
	for i in get_children():
		if i is StaticBody3D:
			if i.behind_player:
				
				i.move_balloon_in_front_of_player()
				current_balloon = i
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(i, "global_position", i.start_pos, 4.0)

				break
				
func into_the_distance() -> void:
	
	#for l in range(1):
	await get_tree().create_timer(2.0).timeout
	for i in get_children():
		if i is StaticBody3D:
			if i.behind_player:
				
				i.move_balloon_in_front_of_player()
				current_balloon = i
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(i, "global_position:y", i.start_pos.x, 5.0)
				tween.parallel().tween_property(i, "global_position:y", i.start_pos.y, 7.0)
				tween.parallel().tween_property(i, "global_position:z", 90.0, 120.0).as_relative()

				break
					
		#await get_tree().create_timer(0.5).timeout

#func _physics_process(delta: float) -> void:
	#
	#if Engine.get_physics_frames() % 60 == 0:
		#current_round = gl_PlayerState.dataset.round
		#if new_round_checker != current_round:
			#print("Current Round: ", current_round)
			#new_round_checker = current_round
			#move_ballons()
			#move_ballons_2()	
			
func player_balloon_was_popped() -> void:

	current_balloon = null
	return
	balloons_popped += 1
	if total_balloons_remaining == balloons_popped:
		round_manager.game_over()
		await get_tree().create_timer(1.5).timeout
		start_game_over()

		
func start_game_over() -> void:
	round_manager.start_game_over()
	
func move_ballons() -> void:
	var chosen_balloon = [balloon,balloon_2,balloon_3].pick_random()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chosen_balloon, "global_position:x", -12.0, 20.0)
	tween.tween_interval(randi_range(2,6))
	tween.tween_property(chosen_balloon, "global_position:x", 12.0, 20.0)
	await tween.finished
	
func move_ballons_2() -> void:
	var chosen_balloon = [balloon,balloon_2,balloon_3].pick_random()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chosen_balloon, "global_position:z", -1.0, 3.0)
	tween.tween_interval(randi_range(2,6))
	tween.tween_property(chosen_balloon, "global_position:z", 20.0, 10.0)
	await tween.finished
	
	
func restart() -> void:
	await get_tree().create_timer(1.0).timeout
	current_balloon = null
	balloons_popped = 0
	blue_offset_y = 0
	total_balloons_remaining = starting_balloons
	
	var balloon_list = [balloon] #, balloon_2, balloon_3]
	var wait_positions = [
		balloon_pos_1,
		balloon_pos_2,
		balloon_pos_3
	]
	
	for i in range(balloon_list.size()):
		var b = balloon_list[i]

		if !is_instance_valid(b):
			continue

		b.show()
		b.behind_player = true

		if b.has_method("stop_all_tweens"):
			b.stop_all_tweens()

		if i < wait_positions.size():
			b.global_position = wait_positions[i].global_position

		if i >= starting_balloons:
			b.hide()

	await get_tree().create_timer(3.0).timeout
	add_balloon()
	print('did we make it here with player balloon?')
