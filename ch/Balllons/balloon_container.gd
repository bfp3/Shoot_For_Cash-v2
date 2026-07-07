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
	set_physics_process(false)


	
func move_all_ballons_back() -> void:
	print("move balloons back")
	for i in get_children():
		i.global_position.z -= 27.0
		i.hide()
	
func add_balloon() -> void:
	
	for l in range(2):
		for i in get_children():
			if i is StaticBody3D:
				if i.behind_player:
					i.move_balloon_in_front_of_player()
					var tween = create_tween()
					tween.set_ease(Tween.EASE_IN_OUT)
					tween.set_trans(Tween.TRANS_SINE)
					tween.tween_property(i, "global_position:z", 27.0, 5.0).as_relative()

					break

func _physics_process(delta: float) -> void:
	
	if Engine.get_physics_frames() % 60 == 0:
		current_round = gl_PlayerState.dataset.round
		if new_round_checker != current_round:
			print("Current Round: ", current_round)
			new_round_checker = current_round
			move_ballons()
			move_ballons_2()	
	

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
