extends Node3D
#
#@onready var target_spinning_pole = $TargetSpinningPole
#@onready var t3 = $targetCreator/targetLoadPoint
#@onready var targetTimer = $TargetTimer
#
#@onready var hole_in_the_wall = $Gate1/wallContainer
#@onready var gate1 = $Gate1
#@onready var points_sfx = $SFX/Points_added
#@onready var t1 = $targetCreator/targetLoadPoint2
#
#var hole_movement_speed = 1.5
#var hole_direction = 1
#var hole_movement_limit = 6
#var hole_movement_accumulator = 0
#
#var target_count = 0
#var newTarget = preload("res://200_assets/targets/target_rolling.tscn")
#var redTargetInst = preload("res://200_assets/targets/target_rolling_red.tscn")
#
#var trapDoor = false
#
#func _process(delta):
	#
##
##	if GameManager.powerPoints > 300:
##		gate1.visible = false
	#
	#hole_in_the_wall.position.x += hole_movement_speed * hole_direction * delta
#
	#hole_movement_accumulator += hole_movement_speed * delta
#
	#if hole_movement_accumulator >= hole_movement_limit or hole_movement_accumulator <= -hole_movement_limit:
#
		#hole_direction *= -1
		#hole_movement_accumulator = 0
#
	#else:
		#return
#
#func blueTarget():
	#target_count += 1
	#var nextTarget = newTarget.instantiate()
	#nextTarget.position = t3.position
	#nextTarget.name = "target_rolling_blue" + str(target_count)
	#add_child(nextTarget)
	#
#func redTarget():
	#target_count += 1
	#var nextTarget = redTargetInst.instantiate()
	#nextTarget.position = t1.position
	#nextTarget.name = "target_rolling_red" + str(target_count)
	#add_child(nextTarget)
	#
#func _on_target_timer_timeout():
	#blueTarget()
#
#func _on_area_3d_body_entered(body):
	#if "target_rolling" in body.name:
		#points_sfx.play()
		#GameManager.powerPoints += 3
		#PowerCounter.updatePower()
#
#
#func _on_red_timer_timeout():
	#redTarget()
