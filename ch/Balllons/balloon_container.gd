extends Node3D

@export var move_speed := 2.0
var current_round := 0
var new_round_checker := 0
@onready var balloon: StaticBody3D = $Balloon
@onready var balloon_2: StaticBody3D = $Balloon2
@onready var balloon_3: StaticBody3D = $Balloon3
@onready var balloon_4: StaticBody3D = $Balloon4

func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	
	if Engine.get_physics_frames() % 60 == 0:
		current_round = gl_PlayerState.dataset.round
		if new_round_checker != current_round:
			print("Current Round: ", current_round)
			new_round_checker = current_round
			move_ballons()
			move_ballons_2()
	
	
	
func move_ballons() -> void:
	var chosen_balloon = [balloon,balloon_2,balloon_3,balloon_4].pick_random()
	
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
