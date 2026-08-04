extends Node3D
@export_range(1, 3, 1) var starting_balloons := 3
@export var move_speed := 2.0
var current_round := 0
var new_round_checker := 0

var blue_offset_y := 0

@export var round_manager : RoundManager 

@onready var balloon: StaticBody3D = $PlayerBalloon
@onready var balloon_pos_1: Marker3D = $'../Balloon_wait_positions/Balloon_pos_1'

var current_balloon = null
var balloons_popped := 0
var total_balloons_remaining := 0

func _ready() -> void:
	move_all_ballons_back()
	set_physics_process(false)
	
	await get_tree().create_timer(1.0, false).timeout
	configure_starting_balloons()
	
func configure_starting_balloons() -> void:
	var balloon_list := [balloon]

	for i in range(balloon_list.size()):
		if i >= starting_balloons:
			balloon_list[i].queue_free()

	total_balloons_remaining = starting_balloons
	
	
func check_balloons_status() -> void:
	
	if get_children().size() > 0:
		if current_balloon == null:
			add_balloon_replacement()

func move_all_ballons_back() -> void:

	var wait_positions = [
		balloon_pos_1,
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
	
	const balloon_mov_dur := 1.0
	
	#await get_tree().create_timer(2.0).timeout
	for i in get_children():
		if i is StaticBody3D:
			if i.behind_player:
				current_balloon = i
				i.move_balloon_in_front_of_player()
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(i, "global_position", i.start_pos,balloon_mov_dur).as_relative()

				break

func red_penalty() -> void:
	blue_offset_y =  clamp(blue_offset_y + 2, 0, 12)

	current_balloon.money_label_3d.print_text(current_balloon.global_position, 'BLUE DOWN')
	
	if current_balloon == null:
		return
		
	var rand_y = current_balloon.start_pos.y - blue_offset_y

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_balloon, "global_position:y", rand_y, 3.0)
	
func white_reward() -> void:
	blue_offset_y =  clamp(blue_offset_y - 2, 0, 100)

	current_balloon.money_label_3d.print_text(current_balloon.global_position, 'BLUE UP!')

	if current_balloon == null:
		return
		
	var rand_y = current_balloon.start_pos.y - blue_offset_y

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_balloon, "global_position:y", rand_y, 3.0)


func add_balloon() -> void:
	into_the_distance()

				
func into_the_distance() -> void:
	
	#for l in range(1):
	await get_tree().create_timer(2.0, false).timeout
	for i in get_children():
		if i is StaticBody3D:
			if i.behind_player:
				
				i.move_balloon_in_front_of_player()
				current_balloon = i
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_property(i, "global_position:y", i.start_pos.x, 5.0)
				#tween.parallel().tween_property(i, "global_position:y", i.start_pos.y, 7.0)
				tween.parallel().tween_property(i, "global_position:y", i.start_pos.y + 20.0, 7.0)
				#tween.parallel().tween_property(i, "global_position:z", 90.0, 120.0).as_relative()

				break
					
		#await get_tree().create_timer(0.5).timeout


			
func player_balloon_was_popped() -> void:
	current_balloon = null


		
func start_game_over() -> void:
	round_manager.start_game_over()


	
	
func restart() -> void:
	await get_tree().create_timer(1.0, false).timeout
	current_balloon = null
	balloons_popped = 0
	blue_offset_y = 0
	total_balloons_remaining = starting_balloons
	
	var balloon_list = [balloon]
	var wait_positions = [
		balloon_pos_1
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

	await get_tree().create_timer(3.0, false).timeout
	add_balloon()
	print('did we make it here with player balloon?')
