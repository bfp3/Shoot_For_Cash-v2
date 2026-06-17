extends CanvasLayer
#
#const PISTOL_SFX = preload("res://sfx/Pistol_SFX.wav")
#const LOSING_WIND_FULL = preload("res://sfx/windFull.WAV")
#
#@onready var control_node: Control = $Control_node
#@onready var large_background_radar: Control = $Large_background_radar
#@onready var button: Button = $Button
#@onready var smoke_sprite: AnimatedSprite2D = $Smoke_sprite
#@onready var label: Label = $Control_node/Label
#@onready var label_2: Label = $Control_node/Label2
#
#@export var next_scene: String
#
#var sequence_start := false
#var retry_pressed := false
#
#var mission_failure_text : Array = [
	#"Oops!",
	#"Flattened...",
	#"Pancake'd...",
	#"Mission: Squashed...",
	#"Cause of Death, Incompetence...",
	#"Yikes. That’s Gonna Leave a Mark…",
	#"Hope nobody saw that...",
	#"Will I Still Be Getting Paid For This?",
	#"Welp… That’s One Less Problem?",
	#"Smushed Like a Bug!",
	#"Wonder If Our Insurance Will Cover That…",
	#"You Get An F...... F Is For Failures."
#]
#
#func _ready() -> void:
	#
	#control_node.modulate = Color.TRANSPARENT
	##large_background_radar.modulate = Color.TRANSPARENT
	#button.modulate = Color.TRANSPARENT
	#label.modulate = Color.TRANSPARENT
	#label_2.modulate = Color.TRANSPARENT
#
	#EventBus.instance.zoom_out_finished.connect(continue_sequence)
#
	#var hostage_health_bar_manager = get_tree().get_first_node_in_group('hostage_health_bar_manager')
	#if hostage_health_bar_manager:
		#hostage_health_bar_manager.out_of_health.connect(start_sequence_losing)
#
	#start_sequence_losing()
	#
#func start_sequence_losing() -> void:
	#if sequence_start: 
		#return
	#
		#
	#sequence_start = true
	#var zoom_out_sequence = get_tree().get_first_node_in_group('camera_zoom_out_node')
	#if zoom_out_sequence:
		#zoom_out_sequence.begin_zoom_out_process_death()
	#
	#
#
#func continue_sequence() -> void:
	#$"../TV_hud".tween(50.0, 2.0)
	#$"../TV_hud".crt_brightness_tween(0.1, 5.0)
	#fade_in()
	#stop_player()
	#stop_target_launcher()
	#lower_the_music()
	##display_failure_retry()
	#game_over_text_tween()
#
#func fade_in() -> void:
	#var dur : float = 0.5
	#var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	#tween.tween_property(large_background_radar, "scale", Vector2.ONE * 3.0, 3.0).set_ease(Tween.EASE_OUT)
	##tween.tween_interval(2.0) #wait for the HUD to close up a little
	#tween.tween_property(control_node, "modulate", Color('FFFFFF'), dur)
	#tween.parallel().tween_property(label, "modulate", Color('FFFFFF'), dur).set_delay(0.25)
	#tween.tween_property(button, "modulate", Color('FFFFFF'), dur + dur + dur)
	#tween.parallel().tween_property(label_2, "modulate", Color('FFFFFF'), dur* 2).set_delay(1.5)
	#
	#tween.parallel().tween_callback(display_mouse)
	#await tween.finished
#
#func display_mouse() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#
#func stop_player() -> void:
	#var player = get_tree().get_first_node_in_group('Player')
	#if player:
		#player.set_process(false)
		#player.set_physics_process(false)
		#player.set_process_input(false)
#
#
#func stop_target_launcher() -> void:
	#var target_launchers = get_tree().get_nodes_in_group('Target_launcher')
	#if target_launchers.size() > 0:
		#for target_launcher in target_launchers:
			#target_launcher.process_mode = Node.PROCESS_MODE_DISABLED
			#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			#tween.tween_property(target_launcher, "global_position:y", -2.0, 10.0)
#
#
#func lower_the_music() -> void:
#
	#return
	#var dur : float = 2.0
	#var level_song : AudioStreamPlayer = get_tree().get_first_node_in_group("level_song")
	#if level_song:
		#var tween = create_tween()
		#tween.tween_property(level_song, "volume_db", -40.0, 3.0)
		#await tween.finished
		#CommonCode.play_sound_instance_await_time(LOSING_WIND_FULL, 0.0, 0.0, 4.0)
		#
		#
#func reset_music_volumes() -> void:
	#var dur : float = 1.0
	#var level_song : AudioStreamPlayer = get_tree().get_first_node_in_group("level_song")
	#if level_song:
		#var tween = create_tween()
		#tween.tween_property(level_song, "volume_db", -30.0, dur)
		#await tween.finished
#
#
##func display_failure_retry() -> void:
	##Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#
	##var failure_label = $Label
	##failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	##failure_label.text = mission_failure_text[randi() % mission_failure_text.size()]
	##
	##var word_count = failure_label.text.split(" ").size()
	##var font_size = 80
	##if word_count > 4:
		##font_size = 30
	##if word_count > 8:
		##font_size = 10
	##
	##var font = $Label.label_settings
	##failure_label.add_theme_font_size_override("font_size", font_size)
#
#func game_over_text_tween() -> void:
#
	#var text : TextureRect = $Control_node/Game_over
	#var dur : float = 1.5
	#var tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	#tween.tween_property(text, "self_modulate", Color('ff0000'), dur)  # Fade in over 2 seconds
	#tween.tween_interval(2.0)
	#tween.tween_property(text, "self_modulate", Color('ff000050'), 0.05)  # Fade in over 2 seconds
	#tween.tween_property(text, "self_modulate", Color('ff000099'), 0.05)  # Fade in over 2 seconds
	#tween.tween_property(text, "self_modulate", Color('ff000050'), 0.05)  # Fade in over 2 seconds
	#tween.tween_property(text, "self_modulate", Color('ff000099'), 0.05)  # Fade in over 2 seconds
	##tween.parallel().tween_property(control_node, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_BACK)
	#
#func retry_mission() -> void:
	#if retry_pressed:
		#return
	#retry_pressed = true
	#
	#var dur : float = 0.3
	#var control_node : Control = $Control_node
	#
	#$"../TV_hud".crt_brightness_tween(0.0, 0.1)
	#
	#smoke_sprite.global_position = get_viewport().size / 2
	#smoke_sprite.show()
	#smoke_sprite.play("default")
	#CommonCode.play_sound_instance_pitch_adjusted(PISTOL_SFX, -40.0, 3.0)
	#var tween = create_tween()
	#tween.tween_property(control_node, "modulate", Color('FFFFFF00'), dur)  # Fade in over 2 seconds
	#tween.parallel().tween_property(control_node, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_BACK)
	#tween.parallel().tween_property(large_background_radar, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_BACK)
	#tween.parallel().tween_property(button, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK)
	#tween.parallel().tween_property(smoke_sprite, "modulate", Color('FFFFFF00'), dur).set_delay(0.25)
	##await tween.finished
	#await smoke_sprite.animation_finished
	#hide()
	##var current_level = get_tree().get_first_node_in_group('level_root')
	##current_level.restart_scene()
	#get_tree().reload_current_scene()
