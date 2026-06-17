extends Control
const POINTS_ADDED_SFX = preload("res://400_sounds/00_sfx/Camera_SFX/Camera_waking_up_3.wav")
var current_score := 0
var temp_final_score := 0

var calculating_score := false
var last_bonus_100_milestone := 0
var await_time: float = 0.01
var countdown_await_time : float = 0.01

var adding_points_increment := 4

var start_points_for_countdown := 0
var game_won := false

func _ready() -> void:
	EventBus.instance.cannonball_destroyed.connect(update_hidden_score)
	
	GameManager.current_score_displayed = 0
	$Coins_label.text = str(GameManager.current_score_displayed).pad_zeros(2)
	$Coins_label.modulate = Color('FFFFFF00')
	start_tween()
	
func start_tween() -> void:
	start_points_for_countdown = ScoreGl.winning_score
	$Coins_label.text = str(start_points_for_countdown).pad_zeros(2)
	
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(2.0)
	tween.tween_property($Coins_label, "modulate", Color('FFFFFF99'), 0.25)
	tween.tween_interval(2.0)
	await tween.finished
	start_countdown()
	
func start_countdown() -> void:
	var pitch_volume: float = 4.0
	while start_points_for_countdown > 0:
		if start_points_for_countdown == 0:
			break
		
		var points_remaining = start_points_for_countdown
	
		if points_remaining < 10:

			countdown_await_time += 0.04 * (3 - points_remaining)  # slows down to 0.07, 0.09 for last 2 points
			countdown_await_time = abs(countdown_await_time)

		CommonCode.play_sound_instance_pitch_adjusted(POINTS_ADDED_SFX, -69.0, pitch_volume)
		start_points_for_countdown = clamp(start_points_for_countdown - 23, 0, ScoreGl.winning_score)

		$Coins_label.text = str(start_points_for_countdown).pad_zeros(2)
		$"../../Main_score_Tally".pulse_ring()
		var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($Coins_label, "scale", Vector2.ONE * 1.1, countdown_await_time)
		tween.parallel().tween_property($Coins_label, "modulate", Color('FFFFFF'), countdown_await_time)
		tween.tween_property($Coins_label, "scale", Vector2.ONE, countdown_await_time)
		tween.parallel().tween_property($Coins_label, "modulate", Color('FFFFDD'), countdown_await_time)
		await tween.finished

		pitch_volume -= 0.05
		

func update_hidden_score() -> void:
	if game_won:
		return
	var orig_score : float = GameManager.current_score_not_displayed
	orig_score += (GameManager.bombs_hit_by_player + GameManager.shots_missed_during_round) * ScoreGl.score_multiplier
	if orig_score >= ScoreGl.winning_score:
		game_won = true
		temp_final_score = orig_score
		#GameManager.current_score_displayed = ScoreGl.winning_score
		#GameManager.current_score_not_displayed = ScoreGl.winning_score
		#GameManager.player_has_winning_score = true
		#EventBus.instance.player_has_hit_winning_score.emit()
		var level = get_tree().get_first_node_in_group('level_root')
		level.process_mode = Node.PROCESS_MODE_DISABLED
		while_loop()
	#GameManager.current_score_not_displayed += (GameManager.bombs_hit_by_player + GameManager.shots_missed_during_round)
	print('hidden score = ' , orig_score)
	
func update_points_total(final_score : int) -> void:
	if calculating_score:
		return
	
	adding_points_increment = 4
	
	calculating_score = true
	GameManager.current_score_not_displayed += (GameManager.bombs_hit_by_player + GameManager.shots_missed_during_round) * ScoreGl.score_multiplier
	temp_final_score = GameManager.current_score_not_displayed #GameManager.shots_missed_during_round + GameManager.current_score_not_displayed + GameManager.bombs_hit_by_player
	temp_final_score = clamp(temp_final_score, 0, ScoreGl.winning_score)
	check_win_condition()


	while_loop()

func while_loop():
	var pitch_volume: float = 1.0

	while GameManager.current_score_displayed < temp_final_score:
		
		if GameManager.current_score_displayed == ScoreGl.winning_score:
			#EventBus.instance.player_has_hit_winning_score.emit()
			GameManager.current_score_displayed = ScoreGl.winning_score
			GameManager.current_score_not_displayed = ScoreGl.winning_score
			GameManager.player_has_winning_score = true
			EventBus.instance.player_has_hit_winning_score.emit()
			if game_won:
				var level = get_tree().get_first_node_in_group('level_root')
				level.process_mode = Node.PROCESS_MODE_INHERIT

			break

		var points_remaining = temp_final_score - GameManager.current_score_displayed
	
		if points_remaining < 12:
			adding_points_increment = 2
			await_time += 0.04 * (3 - points_remaining)  # slows down to 0.07, 0.09 for last 2 points
			await_time = abs(await_time)

		CommonCode.play_sound_instance_pitch_adjusted(POINTS_ADDED_SFX, -65.0, pitch_volume)
		GameManager.current_score_displayed = clamp(GameManager.current_score_displayed + adding_points_increment, 0, ScoreGl.winning_score)
		#$"../../Main_score_Tally".progress_bar_texture.value += 1

		if GameManager.current_score_displayed % (ScoreGl.winning_score / 10) == 0 \
		and GameManager.current_score_displayed != ScoreGl.winning_score - 1 \
		and GameManager.current_score_displayed > last_bonus_100_milestone:
			
			last_bonus_100_milestone = GameManager.current_score_displayed
			give_player_ammo_bonus()

			# Pause momentarily and emit signal
			await get_tree().create_timer(0.35).timeout
			multiple_of_a_hundred()


		$Coins_label.text = str(GameManager.current_score_displayed).pad_zeros(2)
		$"../../Main_score_Tally".pulse_ring()
		var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($Coins_label, "scale", Vector2.ONE * 1.1, await_time)
		tween.parallel().tween_property($Coins_label, "modulate", Color('FFFFFF'), await_time)
		tween.tween_property($Coins_label, "scale", Vector2.ONE, await_time)
		tween.parallel().tween_property($Coins_label, "modulate", Color('FFFFDD'), await_time)
		await tween.finished

		pitch_volume += 0.1

	$Coins_label.text = str(GameManager.current_score_displayed).pad_zeros(2)
	$"../../Main_score_Tally".fully_realised_score_indicator()
	reset_score()


func give_player_ammo_bonus() -> void:
	var ammo_management_sytem := get_tree().get_first_node_in_group("Ammo_management_system")
	if ammo_management_sytem:
		ammo_management_sytem.received_bonus_ammo()
	else:
		print_debug("ERROR: Can't find the ammo system")

func tween_score() -> void:
	current_score += 1
	var dur := 0.2
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Coins_label, "text", str(current_score).pad_zeros(2), dur)
	await tween.finished
	while_loop()
	
func reset_score() -> void:
	
	var new_feedback = get_tree().get_first_node_in_group("HUD_feedback_corner")
	if new_feedback:
		new_feedback.fade_out_score()
		await get_tree().create_timer(0.25).timeout
		new_feedback.red_damage_hud_feedback_return_to_normal()
	
	await_time = 0.02

	temp_final_score = 0
	calculating_score = false

func check_win_condition() -> void:
	var SMS = get_tree().get_first_node_in_group('score_feedback_node')
	if SMS:
		SMS.check_win_condition()
		
func multiple_of_a_hundred() -> void:
	var new_feedback : HUD_feedback_corner = get_tree().get_first_node_in_group("HUD_feedback_corner")
	if new_feedback:
		new_feedback.feedback_on_a_hundred()
