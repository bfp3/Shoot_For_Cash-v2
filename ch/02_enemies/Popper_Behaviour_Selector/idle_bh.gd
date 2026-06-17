extends Node3D

signal finished
var cancelled:bool

var this_timer: SceneTreeTimer

func start(parent : CharacterBody3D) -> void:
	cancelled = false
	this_timer = get_tree().create_timer(1.0)
	await this_timer.timeout
	if not cancelled:
		finished.emit()
	
func cancel() -> void:
	this_timer.time_left = 0
