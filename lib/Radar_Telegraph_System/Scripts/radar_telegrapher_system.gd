extends Node

@onready var batch_handler = $BatchProbabilityHandler
@onready var bonus_handler = $BonusShotHandler
@onready var animator = $RadarTelegraphAnimator

const MAX_SHOTS := 6

var pineapple_round := false
var current_round := 1
var final_batch := []

func check_if_score_has_been_beaten():
	if GameManager.current_score_not_displayed >= GameManager.score_to_beat_for_the_level:
		return true
		
func send_in_the_pineapples():
	var target_launcher_operator = get_tree().get_first_node_in_group("target_launcher_operator")
	if target_launcher_operator:
		target_launcher_operator.send_in_the_pineapples()
		#set_next_batch(final_batch)
	

func create_new_batch_only() -> void:
	if check_if_score_has_been_beaten():
		$Pineapples.display_pineapples()
		pineapple_round = true
		var player = get_tree().get_nodes_in_group('Player')[0]
		if player:
			if player.has_method('show_ammo_display'):
				player.show_ammo_display()
		phase_completed()
		return

	var game_manager = get_tree().get_first_node_in_group("game_loop_manager")
	if game_manager:
		current_round = game_manager.game_loop_current_round

	var min_shots = clamp(3 + current_round - 1, 3, MAX_SHOTS)
	var bonus_chance = clamp(0.1 + (current_round * 0.03), 0.1, 0.5)

	final_batch.clear()
	var red_count = 0

	for i in range(min_shots):
		var shot_type = batch_handler.generate_single_shot()

		if shot_type == "RED" || shot_type == "ORANGE":
			if red_count >= 6:
				# Force pick a non-RED if 6 REDs already
				#while shot_type == "RED":
					#shot_type = batch_handler.generate_single_shot()
				shot_type = "GREY"
			else:
				red_count += 1

		var shot_data = {
			"type": shot_type
		}
		final_batch.append(shot_data)

	if randf() < bonus_chance:
		var bonus_type = bonus_handler.generate_bonus_shot()
		var bonus_data = {
			"type": bonus_type
		}
		final_batch.append(bonus_data)

	var target_launcher_operator = get_tree().get_first_node_in_group("target_launcher_operator")
	if target_launcher_operator:
		target_launcher_operator.set_next_batch(final_batch)

	phase_completed()

	
func start_process():
	$Dots_presentation.hide()
	#await get_tree().create_timer(0.5).timeout  # HUD light delay

	if check_if_score_has_been_beaten():
		$Pineapples.display_pineapples()
		pineapple_round = true
		var player = get_tree().get_nodes_in_group('Player')[0]
		if player:
			player.show_ammo_display()
		return
	

	var game_manager = get_tree().get_first_node_in_group("game_loop_manager")
	if game_manager:
		current_round =  game_manager.game_loop_current_round

	var min_shots = clamp(3 + current_round - 1, 3, MAX_SHOTS)
	var bonus_chance = clamp(0.1 + (current_round * 0.03), 0.1, 0.5)

	final_batch.clear()

	for i in range(min_shots):
		var shot_type = batch_handler.generate_single_shot()
		var shot_data = {
			"type": shot_type  # only "type" is needed now
		}
		final_batch.append(shot_data)

	if randf() < bonus_chance:
		var bonus_type = bonus_handler.generate_bonus_shot()
		var bonus_data = {
			"type": bonus_type
		}
		final_batch.append(bonus_data)

	var target_launcher_operator = get_tree().get_first_node_in_group("target_launcher_operator")
	if target_launcher_operator:
		target_launcher_operator.set_next_batch(final_batch)
	
	$Dots_presentation.show()
	$Dots.generate_dots_from_batch(final_batch)
	animator.play_animation(final_batch)
	

	phase_completed()

func player_has_selected_ammo() -> void:
	var RUMBLE_SOUND_1 = preload("res://sfx//Rumble_sound_1.wav")
	var CLICK_SFX = preload("res://sfx/Radar_telegrapher.wav")
	CommonCode.play_sound_instance_pitch_adjusted(RUMBLE_SOUND_1, -25.0, 0.1)
	CommonCode.play_sound_instance_pitch_adjusted(CLICK_SFX, -15.0, 1.0)
	phase_completed()



func phase_completed() -> void:
	
	if pineapple_round:
		send_in_the_pineapples()
		$Pineapples.hide_display()
	
	await get_tree().create_timer(0.01).timeout
	
	#if $Dots:
		#$Dots.clear_existing_dots()
	
	#var HUD_light_on_phase = get_tree().get_first_node_in_group('HUD_light_on_phase')
	#if HUD_light_on_phase:
		#HUD_light_on_phase.radar_telegrapher_complete()
		
	var launching_phase = get_tree().get_first_node_in_group('launching_phase')
	if launching_phase:
		launching_phase.radar_telegrapher_complete()
	#else:
		#print_debug('ERROR: calling the phase ended on radar telegrapher')
		
	await get_tree().create_timer(0.1).timeout
	#$Dots_presentation.hide()
	queue_free()
