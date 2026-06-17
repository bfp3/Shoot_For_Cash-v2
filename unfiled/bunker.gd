extends Node3D

@onready var anim = $AnimationPlayer
@onready var control = $Control
@onready var area_3d = $Area3D


func _input(event):

	if event.is_action_pressed("enterButton"):
		for body in area_3d.get_overlapping_bodies():
			if "player-v2" in body.name:
				anim.play("open_hatch")
