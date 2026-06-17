extends Node

class_name CMS

@onready var batch_creator: Node = $BatchCreator
@onready var smokescreen_odds: Node = $SmokescreenOdds
@onready var check_if_player_won: Node = $CheckIfPlayerWon
@onready var player_lost: Node = $Player_lost_the_game_sequence
@onready var pineapple_ending_sequence: Node = $Pineapple_ending_sequence
@onready var v_2_pineapple_ending_sequence_2: Node = $V2_Pineapple_ending_sequence2

@onready var launcher_manager : Launcher_Manager = get_tree().get_first_node_in_group("launcher_manager")

var player_has_won := false
var player_has_lost := false
var pineapple_has_started := false

var active_cannonballs := 0
var active_pineapple := 0
var currently_shooting := false

var current_round := 0

func _ready() -> void:
	#EventBus.instance.player_has_hit_winning_score.connect(_on_player_won)
	EventBus.instance.game_lost.connect(_on_player_lost)
	#cms_start_process()
	
func start_bonus_round() -> void:
	if launcher_manager:
		launcher_manager.start_bonus_round()


func cms_start_process() -> void:
	
	await check_if_player_won.start_checking_for_score()
	
	if player_has_won or player_has_lost:
		return
	
	if current_round == 0:
		current_round += 1
		
	if current_round >= 1:
		var rand_chance = randi_range(0, 1)
		if rand_chance > 0:
			current_round += 1
		else:
			print('no round added to CMS script')
			pass
	
	EventBus.instance.next_round.emit(current_round)
	
	var smokescreen = smokescreen_odds.check_for_smokescreen_odds()
	if smokescreen && !player_has_won:
		print('Putting this here in case there are any issues in the future')
		run_smokescreen()
		return
	
	batch_creator.create_new_batch()
	print('batch created')
	
func smokescreen_finished() -> void:
	batch_creator.create_new_batch()
	
func run_smokescreen() -> void:
	
	if launcher_manager:
		launcher_manager.send_smokescreen()
	
func send_data_to_launchers(shot_data: Array) -> void:
	currently_shooting = true
	
	if launcher_manager:
		launcher_manager.set_next_batch(shot_data)
		

		
func _on_cannonball_created() -> void:
	active_cannonballs = clamp(active_cannonballs + 1, 0, 99)

func _on_pineapple_created() -> void:
	active_pineapple = clamp(active_pineapple + 1, 0, 3)
	if !pineapple_has_started:
		await get_tree().create_timer(1.0).timeout
		pineapple_has_started = true

func _on_cannonball_destroyed() -> void:
	if player_has_won && pineapple_has_started:
		active_pineapple = clamp(active_pineapple - 1, 0, 3)
		if active_pineapple <= 0:
			active_pineapple = 0
			#await get_tree().create_timer(3.0).timeout
			#var level_completed_sequence = get_tree().get_first_node_in_group("level_completed_sequence")
			#level_completed_sequence.player_won()
	else:
		active_cannonballs = clamp(active_cannonballs - 1, 0, 99)
		if active_cannonballs <= 0: # && !currently_shooting:
			active_cannonballs = 0

			var cannonball_container = get_tree().get_first_node_in_group("cannonball_container")
			cannonball_container.manually_check_if_empty()

func _on_player_won() -> void:
	if player_has_won:
		return

	player_has_won = true
	#pineapple_ending_sequence.prepare_for_pineapple_sequence()
	v_2_pineapple_ending_sequence_2.prepare_for_pineapple_sequence()

func _on_player_lost() -> void:
	#player_lost.remove_all_active_bombs()
	if player_has_lost:
		return
	player_has_lost = true
	
	var current_level := get_tree().get_first_node_in_group("level_root")
	if current_level:
		var failed_sequence_scene = preload('res://900_Data/Win_and_lose_scripts/level_failure.tscn')
		var failed_sequence_instance = failed_sequence_scene.instantiate()
		current_level.add_child(failed_sequence_instance)
