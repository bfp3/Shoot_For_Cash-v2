extends Node3D

@onready var choose_available_marker_logic: Node = %Choose_available_marker_logic

var walk_speed := 3.0
var bob_amount := 0.2
var bob_speed := 4.0

var _cancelled := false
var walk_tween: Tween = null
var bob_tween: Tween = null
var turn_tween_ref: Tween = null

func start(parent : CharacterBody3D) -> void:
	_cancelled = false
	await get_tree().create_timer(1.0).timeout


func cancel() -> void:
	_cancelled = true

	

func _on_finished() -> void:
	if not _cancelled:
		get_parent().walking = false
		get_parent()._on_finished()
