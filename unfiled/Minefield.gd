extends Node3D

@onready var t1 = $targetCreator/targetLoadPoint
@onready var tallBase = $tallBaseContainer/tallBase

var newTarget #= preload("res://200_assets/targets/target_rolling.tscn")

func _ready():
	return
	#GenerateWalls.generateSpinningPolesAndSpheres(2)
	#GenerateWalls.makeWalls(12, 28)

#func _process(delta):
	#if GameManager.score == 1:
		#$Laser.visible = false
		#$Laser/LaserSound.stop()
#
	#elif GameManager.score == 2:
		#$Laser2.visible = false
		#$Laser2/LaserSound.stop()
#
	#elif GameManager.score == 3:
		#$Laser3.visible = false
		#$Laser3/LaserSound.stop()

func target():
	var nextTarget = newTarget.instantiate()
	nextTarget.position = t1.global_transform.origin
	add_child(nextTarget)
	
func _input(event):
	if Input.is_action_just_released("newTarget"):
		target()
		
func _on_timer_timeout():
	target()
