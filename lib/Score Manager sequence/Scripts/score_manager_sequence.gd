extends Control

signal sequence_finished
signal game_has_been_won

@onready var hud_feedback : HUD_feedback_corner = get_tree().get_first_node_in_group("HUD_feedback_corner")
@onready var coins_tracker := get_tree().get_first_node_in_group("coins_tracker")
@onready var cage_health := get_tree().get_first_node_in_group("hostage_health_bar_manager")
@onready var level_completed_sequence := get_tree().get_first_node_in_group("level_completed_sequence")
@onready var settle_phase := get_tree().get_first_node_in_group("settle_phase")
@onready var egg_cage := get_tree().get_nodes_in_group("Egg_Cage")
@onready var health_manager : HealthManager = get_tree().get_first_node_in_group('HealthManager')

func _ready() -> void:
	start_score_sequence()

func start_score_sequence() -> void:
	#fade_in_score_dials_one_by_one()
	await get_tree().create_timer(1.0).timeout  # Allow time for fade-in to finish

	run_health_calculation_phase()

	var final_score : int = calculate_combined_points()
	add_score_to_total(final_score) # 3 for a signal back
	

func run_health_calculation_phase() -> void:
	health_manager.update_damage_counters()

func calculate_combined_points() -> int:
	var total = GameManager.shots_missed_during_round
	var grand_total = total #* GlobalsPlayerStats.player_progress_bar_multi
	return grand_total

func add_score_to_total(final_score : int) -> void:
	#await get_tree().create_timer(1.0).timeout
	if coins_tracker:
		#fade_out_score_dials_one_by_one()
		#await get_tree().create_timer(1.5).timeout
		coins_tracker.update_points_total(final_score)

#func score_finished_tallying() -> void:
	#check_win_condition()

func check_win_condition() -> void:
	
	await get_tree().create_timer(0.1).timeout

	if GameManager.current_score_not_displayed >= GameManager.score_to_beat_for_the_level and GameManager.pineapples_hit >= 3:
		if level_completed_sequence:
			level_completed_sequence.start_sequence()
		emit_signal("game_has_been_won")
	else:
		await cleanup_and_finish()


#func fade_in_score_dials_one_by_one() -> void:
	#if hud_feedback:
		#hud_feedback.fade_in_score_dials_one_by_one()

func fade_out_score_dials_one_by_one() -> void:
	if hud_feedback:
		hud_feedback.fade_out_score_dials_one_by_one()

func cleanup_and_finish() -> void:
	#await get_tree().create_timer(1.0).timeout
	#fade_out_score_dials_one_by_one()
	GameManager.bombs_hit_by_player = 0
	GameManager.shots_missed_during_round = 0
	
	if hud_feedback:
		hud_feedback.fade_out_pineapple()

	#await get_tree().create_timer(0.2).timeout
#
	#if settle_phase:
		#settle_phase.fade_out_score()

	queue_free()
