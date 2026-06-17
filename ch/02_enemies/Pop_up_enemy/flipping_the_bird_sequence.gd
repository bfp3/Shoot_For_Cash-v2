extends Node

var parent: Node = null

func _ready():
	parent = get_parent()
#
#func crosshair_spotted_me() -> void:
	#if parent.crosshair_touching_me:
		#return
#
	#%Scared_face.show()
	#%Standard_face.hide()
	#parent.get_node('SFX/duck_sfx').pitch_scale = randf_range(0.9, 1.15)
	#parent.get_node('SFX/duck_sfx').play()
	#parent.get_node('Timer').stop()
	#parent.get_node('$Mesh/throw_arm').stop_tween()
	#parent.look_at(parent.player.global_position, Vector3.UP, false)
	#await parent.get_tree().create_timer(0.2).timeout
#
	#var rand_chance = randi_range(0, 10)
	#if rand_chance > 1:
		#parent.crosshair_touching_me = true
#
	#parent.looking_over_wall_sequence.take_cover_behind_wall()
#
#func reset_crosshair_on_me_timer() -> void:
	#%Crosshair_timer.stop()
	#%Crosshair_timer.start(parent.crosshair_timer_allowance)
#
#func _on_crosshair_timer_timeout() -> void:
	#parent.crosshair_touching_me = false
#
