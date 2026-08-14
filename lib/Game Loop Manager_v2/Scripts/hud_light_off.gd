extends Control
#
#const HUD_OFF_CLICK = preload("res://sfx/HUD off click.wav")
#const HUD_OFF_2 = preload("res://sfx/HUD off_2.wav")
#
#signal phase_complete
#
#func start_phase() -> void:
	#await get_tree().create_timer(0.2).timeout #Keep this or else you get a bug
	#change_hud_line_colour()
	#fade_hud_light()
	#phase_completed()
#
#func change_hud_line_colour() -> void:
	#var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
	#if HUD_lines != null:
		#HUD_lines.vs_blue()
#
#func fade_hud_light() -> void:
	#var HUD_lamp = get_tree().get_first_node_in_group("HUD_lamp")
	#if HUD_lamp != null:
		#HUD_lamp.hud_lamp_off_phase()
#
#func phase_completed() -> void:
	#phase_complete.emit()
