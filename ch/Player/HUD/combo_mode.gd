extends Control

func start() -> void:
	show()
	$ComboModeTimer.start(3.0)
	$TimerTickingSFX.play()


func end() -> void:
	await get_tree().create_timer(0.5).timeout
	$TimerTickingSFX.stop()
	$TimeRanOut4.play()
	hide()
	$ComboModeTimer.stop()
	
func _on_combo_mode_timer_timeout() -> void:
	$TimerTickingSFX.stop()
	$TimeRanOut4.play()
	hide()
