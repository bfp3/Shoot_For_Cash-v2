extends Node3D

signal finished

var tween_ducking: Tween = null

func start(parent : CharacterBody3D) -> void:
	start_ducking(parent)
	await get_tree().create_timer(1.0).timeout
	_on_finished()

func _on_finished() -> void:
	finished.emit()

func cancel() -> void:
	if tween_ducking:
		tween_ducking.kill()

func start_ducking(parent : CharacterBody3D) -> void:
	tween_ducking = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween_ducking.tween_interval(0.75)
	tween_ducking.tween_property(parent, "global_position:y", -0.25, 0.3).as_relative()
	tween_ducking.parallel().tween_property(%Mesh, "global_position:y", parent.global_position.y, 0.3)
	tween_ducking.tween_interval(1.0)
	tween_ducking.tween_property(parent, "global_position:y", 0.25, 0.3).as_relative()
	tween_ducking.parallel().tween_property(%Mesh, "global_position:y", parent.global_position.y, 0.3)
	await tween_ducking.finished
	
	_on_finished()
