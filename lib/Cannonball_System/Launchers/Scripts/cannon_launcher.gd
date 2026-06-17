extends Node3D
class_name Launcher_Manager

@onready var cannonball_container: Node3D = $Cannonball_container
@onready var launcher_container: Node3D = $Launcher_container

@export var total_of_cannons_in_level := 3

@export var stagger_time_between_shots := 0.5

var game_over: bool = false
var next_batch: Array = []
var launchers: Array = []

var in_firing_process := true

func _ready() -> void:
	update_amount_of_launchers()
	#await get_tree().create_timer(1.0).timeout
	#fire()
	
func update_amount_of_launchers() -> void:
	
	for i in $Launcher_container.get_children():
		launchers.append(i)
		
	#launchers = launcher_container.get_children().filter(func(c): return c.has_method("prepare_shot_queue"))
	#print('DO THIS')
func set_next_batch(batch: Array) -> void:
	#stagger_time_between_shots = randf_range(0.25, 0.6)
	if game_over:
		return
	
	
	
	in_firing_process = true
	next_batch = batch
	distribute_shots_to_launchers()


func distribute_shots_to_launchers() -> void:
	if launchers.is_empty():
		print("No launchers found!")
		return

	var launcher_shot_assignments: Dictionary = {}

	# Initialize all launchers with empty arrays
	for launcher in launchers:
		launcher_shot_assignments[launcher] = []

	var launcher_index: int = 0
	var total_launchers: int = launchers.size()
	
	# Distribute each shot, rotating through launchers
	for shot_data in next_batch:
		var current_launcher = launchers[launcher_index % total_launchers]
		launcher_shot_assignments[current_launcher].append(shot_data)
		launcher_index += 1

	# Tell each launcher to prepare their queue
	for launcher in launcher_shot_assignments.keys():
		var shots_for_launcher = launcher_shot_assignments[launcher]
		if shots_for_launcher.size() > 0:
			launcher.prepare_shot_queue(shots_for_launcher, cannonball_container)
	
	
	
func fire() -> void:
	if game_over:
		return

	in_firing_process = true
	update_amount_of_launchers()
	
	EventBus.instance.cannonball_fired.emit()
	
	# Tell all launchers to start firing their prepared shots
	for launcher in launchers:
		
		launcher.fire_prepared_shots()
		await get_tree().create_timer(stagger_time_between_shots).timeout
		
	await get_tree().create_timer(0.25).timeout
	in_firing_process = false
	
	
func final_round_of_standard_cannonballs() -> void:
	$Bonus_round_launcher._on_game_won_lost()
	
	while cannonball_container.get_child_count() > 0:
		await get_tree().create_timer(0.1).timeout  # Wait briefly before checking again

	var pineapple_sequence : PineappleEndingSeqeunceManager = get_tree().get_first_node_in_group('pineapple_ending_seqeunce_manager')
	pineapple_sequence.final_rounds_shooting = false
 

func game_lost_remove_everything() -> void:
	$Bonus_round_launcher._on_game_won_lost()
	if game_over:
		return

	game_over = true
	cannonball_container.remove_everything()
	
#func contact_cms_for_pineapple_round() -> void:
	#var CMS = get_tree().get_first_node_in_group("CMS")
	#if CMS:
		#CMS.send_in_the_pineapples()
		
func send_in_the_pineapples() -> void:
	#if game_over:
		#return
	#game_over = true
	$Pineapple_launcher.send_in_the_pineapples()


func send_smokescreen() -> void:
	if game_over:
		return
	$Smokescreen_launcher.send_smokescreen()


func start_bonus_round() -> void:
	$Bonus_round_launcher/Bonus_cannon_unit/Timer.start()
