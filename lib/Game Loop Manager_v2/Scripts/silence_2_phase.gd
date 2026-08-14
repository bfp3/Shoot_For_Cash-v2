extends Control
#
#@onready var label: Label = $Label
#const BIRDS_NOISES = preload("res://400_sounds/HUD Sfx/birds_noises.wav")
#
#signal phase_complete
#
#func start_phase() -> void:
	#await get_tree().create_timer(0.2).timeout
	##change_hud_line_colour()
	#CommonCode.play_sound_instance_pitch_adjusted(BIRDS_NOISES, 0.0, 0.7)
	#play_sound()
	#await show_text()
	##await disappear_text()
	#phase_completed()
#
#func change_hud_line_colour() -> void:
	#var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
	#if HUD_lines != null:
		#HUD_lines.turn_white()
		#HUD_lines.vs_half()
#
#func play_sound() -> void:
	#
	#var low_hum = get_tree().get_first_node_in_group('Temporary_low_humming')
	#low_hum.fade_out_sound()
	#
	#var existing_soundscape = get_tree().get_first_node_in_group("soundscape")
	#if existing_soundscape:
		#existing_soundscape.lower_sound_silence_2()
#
#func show_text() -> void:
	#var dur = 2.0
	#label.text = "In Silence 2 Phase..."
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate", Color('FFFFFF'), 0.5)
	##tween.tween_interval(dur)
	#tween.tween_property(label, "modulate", Color('FFFFFF00'), 1.0)
	#await tween.finished
	#
#func disappear_text() -> void:
	#var dur = 2.0
	#label.text = "Exiting Silence 2 Phase..."
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(label, "modulate", Color('FFFFFF'), 0.5)
	#tween.tween_interval(dur)
	#tween.tween_property(label, "modulate", Color('FFFFFF00'), 1.0)
	#await tween.finished
#
#func phase_completed() -> void:
	#phase_complete.emit()
