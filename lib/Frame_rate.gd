extends Control


func _on_timer_timeout() -> void:
	var fps = Engine.get_frames_per_second()
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	$Label.text = str(fps) + "\nDRAW CALLS: " + str(draw_calls)

func _input(event: InputEvent) -> void:
	if Input.is_key_label_pressed(KEY_0):
		visible = !visible
