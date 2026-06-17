extends Node3D

@onready var missile_launch_SFX = $SFX/MissileLaunch

func _ready():
	visible = false
	missile_launch_SFX.playing = false

func spotted():
	visible = true
	missile_launch_SFX.playing = true

func resetPosition():
	visible = false
	missile_launch_SFX.playing = false

