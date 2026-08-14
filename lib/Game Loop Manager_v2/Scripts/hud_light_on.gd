extends Control

#const RADAR_TELEGRAPHER = preload("res://500_sequences/Radar_Telegraph_System/Radar_telegrapher_system.tscn")
#const HUD_ON_CLICK = preload("res://400_sounds/HUD Sfx/HUD on click.wav")
#const HUD_ON_V2 = preload("res://400_sounds/HUD Sfx/HUD on_v2.wav")
#const LOW_HUMMING_SFX_SCENE = preload("res://500_sequences/Game Loop Manager_v2/low_humming_sfx_scene.tscn")
#
#
#@onready var label: Label = $Label
##@onready var hud_light: Control = $HUD_Light_Control
#
#var radar_telegrapher := false
#
#signal phase_complete
#
#
#func start_phase() -> void:
	##hide_hud_light()
	#await blink_HUD_light()
	#await show_hud_light()
	#await get_tree().create_timer(0.2).timeout
	#
	#switch_hud_crt()
	#play_sound()
	##play_rumble()
	#radar_telegrapher_start()
	#show_text()
#
#func play_rumble() -> void:
	#var launcher_zone_mesh = get_tree().get_first_node_in_group("Launcher_zone_mesh")
	#if launcher_zone_mesh:
		#launcher_zone_mesh.rumble_effect_tween()
#
#func radar_telegrapher_start() -> void:
	#var new_radar_telegrapher = RADAR_TELEGRAPHER.instantiate()
	#add_child(new_radar_telegrapher)
	#
	#if radar_telegrapher:
		#new_radar_telegrapher.start_process()
	#else:
		#new_radar_telegrapher.create_new_batch_only()
#
#func radar_telegrapher_complete() -> void:
	#await disappear_text()
	#phase_completed()
#
#func change_hud_line_colour() -> void:
	##return
	#var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
	#if HUD_lines != null:
		##HUD_lines.turn_yellow()
		##HUD_lines.vs_full()
		#HUD_lines.vs_blue()
#
##func hide_hud_light() -> void:
	##hud_light.modulate = Color('FFFFFF00')
#
#func show_hud_light() -> void:
	##var dur = 6.0
	##var tween = create_tween().set_ease(Tween.EASE_OUT)
	#
	##tween.tween_interval(1.0)
	##tween.tween_property(hud_light, "modulate", Color('FFFFFF00'), 1.0)
	##await tween.finished
	#change_hud_line_colour()
	#
#func play_sound() -> void:
	#
	#var existing_soundscape = get_tree().get_first_node_in_group("soundscape")
	#if existing_soundscape:
		#existing_soundscape.lower_sound_HUD_ON()
		#
	#CommonCode.play_sound_instance(HUD_ON_CLICK, -49.0)
		#
	#await get_tree().create_timer(0.13).timeout
	#
	#
	#CommonCode.play_sound_instance(HUD_ON_V2, -20.0)
	#
	#await get_tree().create_timer(0.05).timeout
	#
	#var low_hum = get_tree().get_first_node_in_group('Temporary_low_humming')
	#if low_hum == null:
		#var low_hum_instance = LOW_HUMMING_SFX_SCENE.instantiate()
		#get_tree().get_current_scene().add_child(low_hum_instance)
	#
	#else:
		#low_hum.play_sound()
	#
#func show_text() -> void:
	#var dur = 2.0
	#label.text = "Light On..."
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate", Color('FFFFFF'), 0.5)
	#tween.tween_interval(dur - 0.38)
	##tween.tween_property(label, "modulate", Color('FFFFFF00'), 1.0)
	#await tween.finished
	#
#func disappear_text() -> void:
	#var dur = 2.0
	##label.text = "Exiting HUD Light On Phase..."
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	##tween.tween_property(label, "modulate", Color('FFFFFF'), 0.5)
	##tween.tween_interval(dur)
	#tween.tween_property(label, "modulate", Color('FFFFFF00'), 1.0)
	#await tween.finished
#
#func blink_HUD_light() -> void:
	#var HUD_lamp = get_tree().get_first_node_in_group("HUD_lamp")
	#if HUD_lamp != null:
		#HUD_lamp.hud_lamp_on_phase()
#
#func switch_hud_crt() -> void:
	#var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
	#crt.tween_brightness(2.2)
	#crt.tween(0.1, 1.0)
	#
	##crt.tween(0.5)
#
#func phase_completed() -> void:
	#phase_complete.emit()
