extends Node3D

@export var move_speed := 2.0
var current_round := 0
var new_round_checker := 0
@onready var balloon: StaticBody3D = $Balloon
@onready var balloon_2: StaticBody3D = $Balloon2
@onready var balloon_3: StaticBody3D = $Balloon3
@onready var balloon_4: StaticBody3D = $Balloon4

func _ready() -> void:
	move_all_ballons_back()
	#move_all_ballons_below()
	set_physics_process(false)

func move_all_ballons_below() -> void:
	for i in get_children():
		if i is StaticBody3D:
			#i.global_position = i.start_pos
			i.global_position.z = i.start_pos.z - 11.0
			i.hide()
	
func move_all_ballons_back() -> void:
	for i in get_children():
		if i is StaticBody3D:
			i.global_position.z = i.start_pos.z - 27.0
			i.hide()
	
func add_white_balloon_back_into_list(_balloon: StaticBody3D) -> void:
	if !is_instance_valid(balloon):
		return
	
	await get_tree().create_timer(4.0).timeout
	# Return to initial state
	_balloon.behind_player = true
	_balloon.hide()
	_balloon.global_position.z = _balloon.start_pos.z - 27.0

	# Move to the end of the child list
	move_child(_balloon, get_child_count() - 1)
	
func add_balloon() -> void:
	for l in range(2):
		for i in get_children():
			if i is StaticBody3D and i.behind_player:
				i.move_balloon_in_front_of_player()

				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_interval(0.2)
				#tween.tween_property(i, "global_position:y", -11.0, 5.0).as_relative()
				tween.tween_property(i, "global_position:z", 27.0, 5.0).as_relative()
				break

		await get_tree().create_timer(1.5).timeout

	## Check if every balloon has been added
	#var all_added := true
	#for i in get_children():
		#if i is StaticBody3D and i.behind_player:
			#all_added = false
			#break
#
	## Grow one balloon at a time in child order
	#if all_added:
		#for i in get_children():
			#if i is StaticBody3D and i.scale.x < 3.0:
				#var tween = create_tween()
				#tween.set_trans(Tween.TRANS_BACK)
				#tween.set_ease(Tween.EASE_OUT)
				#tween.tween_property(
					#i,
					#"scale",
					#Vector3(
						#min(i.scale.x + 1.0, 3.0),
						#min(i.scale.y + 1.0, 3.0),
						#min(i.scale.z + 1.0, 3.0)
					#),
					#0.3
				#)
				#break

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



func restart() -> void:
	await get_tree().create_timer(1.0).timeout
	current_round = 0
	new_round_checker = 0

	for child in get_children():
		if child is StaticBody3D:
			child.show()
			child.behind_player = true



	# Return all balloons to their starting hidden position.
	#move_all_ballons_below()
	move_all_ballons_back()
	
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('backward'):
		for i in get_children():
			if i is StaticBody3D and i.behind_player:
				i.move_balloon_in_front_of_player()

				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.set_trans(Tween.TRANS_SINE)
				tween.tween_interval(0.2)
				#tween.tween_property(i, "global_position:y", -11.0, 5.0).as_relative()
				tween.tween_property(i, "global_position:z", 27.0, 5.0).as_relative()
				break
