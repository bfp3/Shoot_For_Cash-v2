## Legacy level progression helper — NOT used by Main / Main-lofi.
## Paths below point at old 100_levels assets and must stay off the Main load path.
## Prefer RoundManager + sc/All_level_layouts/* instead.
extends Node
const RETRY_STAGE_ENVIRONMENT = preload('res://res/skyEnvironments/Retry_stage_environment.tres')
@onready var world_env : WorldEnvironment # = get_tree().get_first_node_in_group('world_env')

#var score : int =  0
#var mine : int = 0
#var battery : float = 0.0
#var health : int = 100
#var spotted = false
#var respawn = 0
#var shelterDoorOpen = false
#var player_in_shelter = false
#var sirenEnd = false
#var holdPositionAudio = true
#var is_sensor_affected = false

var silence_phase_done := false

var score_to_beat_for_the_level : int = 801
var current_score_displayed : int = 0
var current_score_not_displayed : int = 0
var shots_missed_during_round : int = 0
var bombs_hit_by_player : int = 0
var pineapples_hit := 0
var pineapples_missed_in_previous_round := 0
var player_has_winning_score := false
var pineapples_missed_this_round := 0

var total_number_of_pineapples_collected := 0
var in_retry_world := false
var current_level_index := 0
var pineapples_available_within_level := 3
var pineapples_per_level := [3, 3, 3, 1]  # Level 1-3: 3 pineapples, Level 4: 1 pineapple

var amount_of_levels := 4

func _ready():
	reset_score()
	EventBus.instance.player_has_hit_winning_score.connect(_player_has_reached_winning_score)

func _player_has_reached_winning_score() -> void:
	player_has_winning_score = true

func reset_score() -> void:
	player_has_winning_score = false
	current_score_displayed = 0
	current_score_not_displayed = 0
	shots_missed_during_round = 0
	bombs_hit_by_player = 0
	pineapples_hit = 0
	silence_phase_done = false
	
	# Set pineapples available based on current level
	if current_level_index < pineapples_per_level.size():
		pineapples_available_within_level = pineapples_per_level[current_level_index]
	else:
		pineapples_available_within_level = 1  # Default if level index is out of bounds
	
func apply_retry_environment_if_needed():
	if in_retry_world: #and world_env:
		#world_env.environment = RETRY_STAGE_ENVIRONMENT
		var level = get_tree().get_first_node_in_group('level_root')
		level.retry_version()
		#in_retry_world = false


	
func reset_score_retry() -> void:
	player_has_winning_score = false
	current_score_displayed = 0
	current_score_not_displayed = 0
	shots_missed_during_round = 0
	bombs_hit_by_player = 0
	pineapples_hit = 0
	silence_phase_done = false
	
func update_pineapples() -> void:
	total_number_of_pineapples_collected += pineapples_hit
	pineapples_hit = 0


func next_level_directory() -> String:
	var next_level : String
	
	match current_level_index:
		0: next_level = 'res://100_levels/2025_Levels/Level_1.tscn'
		1: next_level = 'res://100_levels/2025_Levels/Level_2.tscn'
		2: next_level = 'res://100_levels/2025_Levels/Level_2_red_sky.tscn'
		3: next_level = 'res://100_levels/2025_Levels/Level_7.tscn'
		4: next_level = 'res://100_levels/2025_Levels/Level_2_red_sky.tscn'
		5: next_level = 'res://100_levels/2025_Levels/Level_3.tscn'
		6: next_level = 'res://100_levels/2025_Levels/Level_4.tscn'
		_:
			
			
		#1: next_level = 'res://100_levels/2025_Levels/Level_1_ROUND_2.tscn'
		#2: next_level = 'res://100_levels/2025_Levels/Level_1_ROUND_3.tscn'
		
		#

			next_level = 'res://100_levels/2025_Levels/Level_1.tscn'
			print_debug('No level could be found')

	return next_level

	


func choose_retry_world() -> String:
	in_retry_world = true
	return next_level_directory()
