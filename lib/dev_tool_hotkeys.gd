# DEV TOOLS SCRIPT
extends Node
#
#@onready var menu_control: Control = $Control
#@onready var grid_container := $"Control/GridContainer"
#
#var original_time_scale := 1.0
#var last_selected_panel: Control = null
#
#var transitioning := false
#
#var key_actions : Dictionary = {
	#KEY_KP_9: {"panel": "9", "action": _toggle_mouse_mode},
	#KEY_KP_8: {"panel": "8", "action": _slow_game},
	#KEY_KP_7: {"panel": "7", "action": _fast_forward},
	#KEY_KP_6: {"panel": "6", "action": _win_game},
	#KEY_KP_5: {"panel": "5", "action": _unpause_game},
	#KEY_KP_4: {"panel": "4", "action": _pause_game},
	#KEY_KP_3: {"panel": "3", "action": _toggle_dev_mode},
	#KEY_KP_2: {"panel": "2", "action": _skip_to_pineapples},
	##KEY_KP_1: {"panel": "1", "action": _return_speed_to_normal},
	#KEY_KP_0: {"panel": "0", "action": _show_hide_menu}
#}
#
#func _ready():
	#menu_control.visible = false
	#$Dev_mode_control/Label.hide()
#
#func _input(event: InputEvent) -> void:
#
	#for key in key_actions.keys():
		#if Input.is_key_pressed(key):
			#var info = key_actions[key]
			#_highlight_panel(info.panel)
			#info.action.call()
			#break
#
#
#
#func _highlight_panel(panel_name: String) -> void:
	#if last_selected_panel:
		#last_selected_panel.modulate = Color("ffffff")
	#last_selected_panel = grid_container.get_node(panel_name)
	#last_selected_panel.modulate = Color("ffffff80")
#
## Menu and time control functions
#func _toggle_mouse_mode():
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#$menu_sfx.play()
#
#func _pause_game():
	#var CRT = get_tree().get_first_node_in_group('TV_CRT_Filter')
	#if CRT:
		#CRT.pause_filter()
	#
	#get_tree().paused = true
	#$menu_sfx.play()
#
#func _unpause_game():
	#var CRT = get_tree().get_first_node_in_group('TV_CRT_Filter')
	#if CRT:
		#CRT.unpause_filter()
	#get_tree().paused = false
	#$menu_sfx.play()
#
#func _slow_game():
	#Engine.time_scale = 0.25
	#$menu_sfx.play()
#
#func _return_speed_to_normal():
	#Engine.time_scale = 1.0
	#$menu_sfx.play()
#
#func _fast_forward():
	#Engine.time_scale = clamp(Engine.time_scale + 1.0, 1.0, 15.0)
	#$menu_sfx.play()
#
#func _win_game() -> void:
	#GameManager.pineapples_hit = 3
	#var level_complete_sequence = get_tree().get_first_node_in_group('level_completed_sequence')
	#if level_complete_sequence:
		#level_complete_sequence.start_sequence()
#
#func _skip_to_pineapples() -> void:
	#GameManager.current_score_displayed = ScoreGl.winning_score
	#GameManager.current_score_not_displayed = ScoreGl.winning_score
	#GameManager.player_has_winning_score = true
	#EventBus.instance.player_has_hit_winning_score.emit()
#
#func _show_hide_menu() -> void:
	#
	#if transitioning:
		#return
	#
	#var dur : float = 0.25
	#$menu_sfx.play()
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#
	#if !menu_control.visible:
		#transitioning = true
		#menu_control.visible = true
		#menu_control.scale = Vector2.ZERO
		#menu_control.modulate = Color.WHITE
		#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		#tween.tween_property(menu_control, "scale", Vector2.ONE * 1.1, 0.25)
		##tween.tween_property(control, "modulate", Color('FFFFFF'), 0.15)
		#tween.tween_property(menu_control, "scale", Vector2.ONE, 0.25)
		#await tween.finished
		#transitioning = false
		#return
	#
	#else:
		#transitioning = true
		#menu_control.scale = Vector2.ONE
		#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		#tween.tween_property(menu_control, "scale", Vector2.ONE * 1.1, 0.15)
		#tween.tween_property(menu_control, "modulate", Color('FFFFFF00'), dur)
		#tween.parallel().tween_property(menu_control, "scale", Vector2.ZERO, dur)
		#await tween.finished
		#transitioning = false
		#menu_control.visible = false
		#return
	#
	#
#func _toggle_dev_mode() -> void:
	#if $Dev_mode_control/Label.visible:
		#return
	#EventBus.instance.in_dev_mode.emit()
	#$Dev_mode_control/Label.show()
	#
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	#tween.tween_interval(2.0)
	#tween.tween_property(menu_control, "scale", Vector2.ONE * 1.1, 0.5)
	#await tween.finished
	#$Dev_mode_control.hide()
