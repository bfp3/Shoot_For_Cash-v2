extends Control

#const RADAR_TELEGRAPHER = preload("res://500_sequences/Radar_Telegraph_System/Radar_telegrapher_system.tscn")
#const HUD_ON_CLICK = preload("res://400_sounds/HUD Sfx/HUD on click.wav")
#const SOUNDSCAPE_SFX = preload("res://500_sequences/Game Loop Manager_v2/soundscape_sfx.tscn")
#const BIRDS_NOISES = preload("res://400_sounds/HUD Sfx/birds_noises.wav")
#const HUD_OFF_2 = preload("res://400_sounds/HUD Sfx/HUD off_2.wav")
#
#@onready var label: Label = $Label
#var radar_telegrapher := false
#
#signal phase_complete
#
#func _ready() -> void:
	#var cannonball_container = get_tree().get_nodes_in_group('cannonball_container')[0]
	#if cannonball_container:
		#cannonball_container.all_bombs_empty.connect(phase_completed)
#
#func start_phase() -> void:
	##radar_telegrapher_start()
	#await get_tree().create_timer(0.13).timeout
	#change_hud_line_colour()
	#GlobalMusic.turn_up_music()
	#make_crosshair_brighter()
	#
	#fire_next_batch()
	#
	#await get_tree().create_timer(0.2).timeout
	#turn_humming_off()
	#await show_text()
#
#func fire_next_batch() -> void:
	#
	#var launcher_manager = get_tree().get_nodes_in_group('launcher_manager')[0]
	#if launcher_manager:
		#launcher_manager.fire()
	#
#
#func radar_telegrapher_complete() -> void:
	##if GameManager.current_score_displayed <= GameManager.score_to_beat_for_the_level:
	#if GameManager.current_score_not_displayed <= GameManager.score_to_beat_for_the_level:
		#var target_launcher = get_tree().get_nodes_in_group('target_launcher_operator')[0]
		#if target_launcher:
			#target_launcher.start_round_loop()
#
#func radar_telegrapher_start() -> void:
	##await get_tree().create_timer(0.13).timeout
	#var new_radar_telegrapher = RADAR_TELEGRAPHER.instantiate()
	#add_child(new_radar_telegrapher)
	#new_radar_telegrapher.create_new_batch_only()
	##if radar_telegrapher:
		##new_radar_telegrapher.start_process()
	##else:
		##new_radar_telegrapher.create_new_batch_only()
#
#func turn_humming_off() -> void:
	#await get_tree().create_timer(2.0).timeout
	#
	#var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
	#if crt:
		#crt.crt_vignette_intensity(0.0, 3.0)
	#
	#
	#var low_hum = get_tree().get_first_node_in_group('Temporary_low_humming')
	#if low_hum:
		#low_hum.HUD_off_mode()
	#await get_tree().create_timer(0.5).timeout
	#CommonCode.play_sound_instance(HUD_OFF_2, -20.0)
#
#func make_crosshair_brighter() -> void:
	#var crosshair = get_tree().get_nodes_in_group('HUD_crosshair')[0]
	#if crosshair:
		#crosshair.crosshair_active_mode()
		#
	#var player = get_tree().get_nodes_in_group('Player')[0]
	#if player:
		#player.toggle_player_shooting_on()
		#
		#
#func change_hud_line_colour() -> void:
	#
	##await get_tree().create_timer(1.5).timeout
	#
	#var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
	#if HUD_lines != null:
		#HUD_lines.turn_red()
		#HUD_lines.vs_off()
	#
	##await get_tree().create_timer(1.5).timeout
	#await get_tree().create_timer(2.0).timeout
	#
	#var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
	#if crt:
		#crt.tween_brightness(1.8)
		#crt.tween(0.0, 1.0)
#
#func play_click_sound() -> void:
	#for i in range(2):
		#await get_tree().create_timer(0.2).timeout
		#CommonCode.play_sound_instance_pitch_adjusted(HUD_ON_CLICK, -30.0, 1.1)
		#await get_tree().create_timer(0.1).timeout
		#
#
#func show_text() -> void:
	#var dur = 2.0
	#label.text = "In Target Launching Phase..."
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate", Color('FFFFFF'), 0.5)
	#await tween.finished
	#
#func disappear_text() -> void:
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate", Color('FFFFFF00'), 0.25)
	#await tween.finished
#
#func silence_soundscape() -> void:
	#var existing_soundscape = get_tree().get_first_node_in_group("soundscape")
	#if existing_soundscape == null:
		#var new_soundscape = SOUNDSCAPE_SFX.instantiate()
		#new_soundscape.add_to_group('soundscape')
		#get_tree().get_current_scene().add_child(new_soundscape)
		#new_soundscape.complete_silence()
	#else:
		#existing_soundscape.complete_silence()
#
#
#func phase_completed() -> void:
	#silence_soundscape()
	#await disappear_text()
	#phase_complete.emit()
#
#func _on_timer_timeout() -> void:
	#var bomb_container_array = get_tree().get_nodes_in_group('cannonball_container')[0]
	#if bomb_container_array:
		#if bomb_container_array.get_children().size() > 0:
			#$Timer.start(2)
		#
		#else:
			#bomb_container_array.manually_check_if_empty()
			#print('ERROR: Launching phase ran on timer')
