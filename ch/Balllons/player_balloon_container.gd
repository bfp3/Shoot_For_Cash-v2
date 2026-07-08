extends Node3D

@export var move_speed := 2.0
var current_round := 0
var new_round_checker := 0
@onready var balloon: StaticBody3D = $Balloon
@onready var balloon_2: StaticBody3D = $Balloon2
@onready var balloon_3: StaticBody3D = $Balloon3
@onready var balloon_4: StaticBody3D = $Balloon4
@onready var balloon_pos_1: Marker3D = $'../Balloon_wait_positions/Balloon_pos_1'
@onready var balloon_pos_2: Marker3D = $'../Balloon_wait_positions/Balloon_pos_2'
@onready var balloon_pos_3: Marker3D = $'../Balloon_wait_positions/Balloon_pos_3'

var current_balloon = null

func _ready() -> void:
	move_all_ballons_back()
	set_physics_process(false)

func check_balloons_status() -> void:
	
	if get_children().size() > 0:
		if current_balloon == null:
			add_balloon_replacement()
		else:
			reposition_balloon()
	
func move_all_ballons_back() -> void:
	print("move balloons back")

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
	if current_balloon == null:
		return
		
	var target_pos: Vector3
	var distance := 0.0
	
	
	while true:
		var rand_x = randf_range(-13.0, 10.0)
		var rand_y = randf_range(4.0, 8.0)
		target_pos = Vector3(rand_x, rand_y, current_balloon.global_position.z)
		
		distance = current_balloon.global_position.distance_to(target_pos)
		
		if distance >= 2.0 and distance <= 7.0:
			break
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	#tween.tween_interval(3.0)
	tween.tween_property(current_balloon, "global_position", target_pos, 6.0)

func add_balloon() -> void:
	
	#for l in range(1):
		#await get_tree().create_timer(1.0).timeout
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
	

func move_ballons() -> void:
	var chosen_balloon = [balloon,balloon_2,balloon_3,balloon_4, $Trio_balloon, $Trio_balloon2,$Trio_balloon3].pick_random()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chosen_balloon, "global_position:x", -12.0, 20.0)
	tween.tween_interval(randi_range(2,6))
	tween.tween_property(chosen_balloon, "global_position:x", 12.0, 20.0)
	await tween.finished
	
func move_ballons_2() -> void:
	var chosen_balloon = [balloon,balloon_2,balloon_3,balloon_4].pick_random()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(chosen_balloon, "global_position:z", -1.0, 3.0)
	tween.tween_interval(randi_range(2,6))
	tween.tween_property(chosen_balloon, "global_position:z", 20.0, 10.0)
	await tween.finished
