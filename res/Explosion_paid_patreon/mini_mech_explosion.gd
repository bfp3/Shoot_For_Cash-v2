extends Node3D

@export var sequence_anim : AnimationPlayer
@export var preview_anim : AnimationPlayer
@export var play_preview : bool = false
@export var robot : Node3D

func _ready():
	if !play_preview:
		sequence_anim.play("sequence")
	else:
		preview_anim.play("preview")
		robot.hide()
