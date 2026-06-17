extends Node3D

var _cancelled := false
signal finished


func start(parent : CharacterBody3D) -> void:
	_cancelled = false
	$Duck_anim.start()


func _on_finished() -> void:
	finished.emit()


func cancel() -> void:
	_cancelled = true
	#$Duck_anim.cancel()


func can_interrupt() -> bool:
	return false
	
