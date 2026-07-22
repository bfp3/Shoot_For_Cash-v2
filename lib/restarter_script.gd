extends Node

func _input(event) -> void:

	if event.is_action_pressed("restart"):
		get_tree().call_group("restartable", "restart")
		gl_PlayerState.reset_all()
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame
		get_tree().reload_current_scene()
