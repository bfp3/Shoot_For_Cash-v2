extends Node3D

signal finished

func start(parent : CharacterBody3D) -> void:
	pass

func _on_finished() -> void:
	finished.emit()

func cancel() -> void:
	pass
