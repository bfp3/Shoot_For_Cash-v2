extends Control


func _on_timer_timeout() -> void:
	var fps = Engine.get_frames_per_second()
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	$Label.text = str(fps) + "\nDRAW CALLS: " + str(draw_calls)

func _input(event: InputEvent) -> void:
	if !Engine.is_editor_hint():
		set_process_input(false)
		return
	
	if Input.is_action_just_pressed('toggle_draw_calls'):
		visible = !visible
#hi baby
