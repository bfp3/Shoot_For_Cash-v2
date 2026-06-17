extends Node

@onready var CMS: Node = $".."

@export var time_between_rounds := 5.0
@export var stagger_time_between_launcher_rounds := 0.5 #1.0

var launcher_nodes: Array = []
var total_launchers := 0
var first_round := true
var counter := 0
var is_pineapple_round := false

var next_batch: Array = []
var game_over := false

@export var smokescreen_mode := false
@export var smokescreen_threshold := 3
var already_run_smokescreen := false
var launcher_is_smokescreen := false
var total_rounds_shot := 0

var active_bombs := 0
var currently_shooting = false

func send_in_the_pineapples() -> void:

	var pineapple_shots := 3
	var launchers_available := launcher_nodes.filter(func(l): return l.pineapple_launcher)
	
	if launchers_available.size() < pineapple_shots:
		push_warning("Not enough pineapple launchers available! Using all we have.")
		pineapple_shots = launchers_available.size()

	for i in range(pineapple_shots):
		
		if i > 2:
			break
		
		var launcher = launchers_available[i]
		launcher.pineapple_shot = true
		launcher.visual_fire()

		var dummy_shot := {
			"type": "GREY"  # Pineapples act like high-threat shots
		}
		prepare_target_for_launch(launcher, dummy_shot)
		
		await get_tree().create_timer(stagger_time_between_launcher_rounds).timeout
	
	#%Bomb_container_array.start_checking_empty()
	currently_shooting = false
	already_run_smokescreen = false


func prepare_target_for_launch(launcher: Node, shot_data: Dictionary) -> void:
	var target_instance = preload("res://300_assets/100_targets/Launching_target.tscn").instantiate()
	
	if launcher_is_smokescreen:
		target_instance.smokescreen = true
		target_instance.slow_travel_time = launcher.launch_speed * 1.0
		target_instance.fast_travel_time = launcher.launch_speed * 0.6
		target_instance.travel_time = launcher.launch_speed
		target_instance.arc_strength = launcher.arc_strength
		
	else:   
		target_instance.slow_travel_time = launcher.launch_speed * 2
		target_instance.fast_travel_time = launcher.launch_speed * 0.5
		target_instance.travel_time = launcher.launch_speed
		target_instance.arc_strength = launcher.arc_strength

	var bomb_container = get_tree().get_first_node_in_group("bomb_container_array")
	bomb_container.add_child(target_instance)
	
	target_instance.bomb_destroyed.connect(CMS._on_bomb_destroyed)
	CMS.active_bombs += 1

	if launcher.pineapple_shot:
		target_instance.pineapple.show()
		target_instance.bomb_mesh.hide()
	else:
		target_instance.pineapple.hide()
		target_instance.bomb_mesh.show()

	target_instance.global_position = launcher.marker_3d.global_position
	launcher.play_launch_animation(target_instance)
	
	if !launcher_is_smokescreen:
		target_instance.target_launcher_fire(shot_data["type"])

	else:
		target_instance.target_launcher_fire("GREY")
		target_instance.particles.amount = 500





#var target_launcher_operator = get_tree().get_first_node_in_group("target_launcher_operator")
	#if target_launcher_operator:
		#target_launcher_operator.send_in_the_pineapples()
