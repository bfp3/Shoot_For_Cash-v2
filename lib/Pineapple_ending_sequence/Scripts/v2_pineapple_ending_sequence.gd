extends Node

class_name PineappleEndingSeqeunceManager

@onready var ammo_management_system = get_tree().get_first_node_in_group('Ammo_management_system')
@onready var launcher_manager : Launcher_Manager = get_tree().get_first_node_in_group("launcher_manager")
#@onready var HUD_feedback : HUD_feedback_corner = get_tree().get_first_node_in_group("HUD_feedback_corner")
@onready var player_crosshair : Player_Crosshair = get_tree().get_first_node_in_group("HUD_crosshair")

var final_rounds_shooting := false



func prepare_for_pineapple_sequence() -> void:
	
	final_rounds_shooting = true # This is to ensure that the last round completes
	
	launcher_manager.final_round_of_standard_cannonballs()
	
	#while final_rounds_shooting:
		#await get_tree().create_timer(0.25).timeout
	
	silence_everything_sequence()
	
	
func silence_everything_sequence() -> void:
	#HUD_feedback.player_has_reached_winning_score()
	
	var soundscape : Background_Soundscape = get_tree().get_first_node_in_group("soundscape")
	var low_humming : Low_Humming_HUD_Noise = get_tree().get_first_node_in_group("Temporary_low_humming")
	
	if soundscape:
		soundscape.complete_silence()
	
	if low_humming:
		low_humming.HUD_off_mode()
		
	if ammo_management_system:
		ammo_management_system.reset_ammo_after_round_delay()
		
	play_transporter_beat()
	
	$Clear_away_panels.check_if_game_over()
	dim_the_lights()
	$Pineapple_telegraph_same_as_intro.first_phase()
	player_crosshair.change_crosshair_colours()


	await get_tree().create_timer(0.65).timeout
	send_in_the_pineapples()
	

	await get_tree().create_timer(2.75).timeout
	$Trumpets.play()
	
	#await get_tree().create_timer(1.0).timeout
	#CommonCode.bird_fly_by()
	
	
	
	

	

func pineapple_collected() -> void:
	
	$Pineapple_telegraph_same_as_intro.show_next_pineapple(GameManager.pineapples_hit)
	
	#$Player_shoot_pineapple.show()
	#$Player_shoot_pineapple.show_next_pineapple(GameManager.pineapples_hit)
	
	
func dim_the_lights() -> void:
	#var light : DirectionalLight3D = get_tree().get_first_node_in_group('directional_light')
	var world_env : WorldEnvironment = get_tree().get_first_node_in_group('world_env')
	var tween = create_tween()
	tween.tween_property(world_env, "environment:background_energy_multiplier", 0.25, 3.0).set_delay(0.5)
	tween.parallel().tween_property(world_env, "environment:glow_bloom", 1.0, 3.0).set_delay(0.5)
	await tween.finished
	
func send_in_the_pineapples() -> void:
	launcher_manager.send_in_the_pineapples()

func wrap_up_pineapples() -> void:
	return
	#$Player_shoot_pineapple.wrap_up_sequence()

func play_transporter_beat() -> void:
	
	var level_completed_sequence = get_tree().get_first_node_in_group("level_completed_sequence")
	if level_completed_sequence:
		level_completed_sequence.player_won()
	
	EventBus.instance.game_won.emit()
	
	for i in range(3):
		$NoEffects120bpmNoLoop.pitch_scale += 0.05
		$NoEffects120bpmNoLoop.play()
		await $NoEffects120bpmNoLoop.finished
		
	#$Trumpets.play()
	#await $Trumpets.finished
	
	await get_tree().create_timer(0.5).timeout

	
	#var level_completed_sequence = get_tree().get_first_node_in_group("level_completed_sequence")
	#level_completed_sequence.player_won()




func silence_everything_sequence_old() -> void:
	#HUD_feedback.player_has_reached_winning_score()
	
	var soundscape : Background_Soundscape = get_tree().get_first_node_in_group("soundscape")
	var low_humming : Low_Humming_HUD_Noise = get_tree().get_first_node_in_group("Temporary_low_humming")
	
	#GlobalMusic.silence_music()
	if soundscape:
		soundscape.complete_silence()
	
	if low_humming:
		low_humming.HUD_off_mode()
		
	if ammo_management_system:
		ammo_management_system.reset_ammo_after_round_delay()
		
		
	play_transporter_beat()
	#player_crosshair.crosshair_dull_mode()
	#CommonCode.set_all_particles_blow_away(Vector3(0.0, 1.0, 5.0), 5.0) 
	
	$Clear_away_panels.check_if_game_over()
	#await get_tree().create_timer(0.25).timeout
	#await dim_the_lights()
	dim_the_lights()
	#await get_tree().create_timer(0.5).timeout
	$Pineapple_telegraph_same_as_intro.first_phase()
	#await get_tree().create_timer(1.0).timeout
	player_crosshair.change_crosshair_colours()
	#GlobalMusic.pineapple_bring_music_up()
	await get_tree().create_timer(1.2).timeout
	send_in_the_pineapples()
	
	await get_tree().create_timer(1.55).timeout
	$Trumpets.play()
	
	await get_tree().create_timer(2.5).timeout
	CommonCode.bird_fly_by()
