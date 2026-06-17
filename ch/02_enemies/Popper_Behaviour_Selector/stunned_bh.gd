extends Node3D

@onready var stunned_anim: Node3D = $Stunned_anim
signal finished


func start(parent : CharacterBody3D) -> void:
	%Rigidbody_doppleganger.start_stun(parent)

func _on_finished() -> void:
	finished.emit()
	

func cancel() -> void:
	pass
	

func can_interrupt() -> bool:
	return false
	
