extends Node

func _input(event) -> void:

	if event.is_action_pressed("restart"):
		gl_PlayerState.reset_all()
		get_tree().reload_current_scene()
