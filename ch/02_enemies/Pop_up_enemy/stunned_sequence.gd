extends Node

var parent: Node = null

func _ready():
	parent = get_parent()
#
#func stunned_by_egg_pulse() -> void:
	#parent.projectile_throw_cancelled = true
#
	#if parent.currently_peeking:
		#if parent.tween_peaking_head:
			#parent.tween_peaking_head.kill()
		#if parent.tween_ducking_cover:
			#parent.tween_ducking_cover.kill()
		#if parent.tween_rotate_head:
			#parent.tween_rotate_head.kill()
#
		#parent.currently_peeking = true
		#parent.hit_able = true
		#parent.stunned = true
		#parent.anim.stop()
		#parent.anim_wobble.stop()
		#parent.anim.play("scared")
		#%Standard_face.hide()
		#%Blinking_face.show()
		#var orig_rot: Vector3 = parent.rotation_degrees
		#parent.rotation_degrees = Vector3(45, 45, 45)
#
		#var _stunned_time = randf_range(3.0, 6.0)
		#await parent.get_tree().create_timer(_stunned_time).timeout
#
		#parent.anim_wobble.play("wobble")
		#parent.anim.play("blinking_twice")
		#parent.stunned = false
		#parent.rotation_degrees = orig_rot
		#%Standard_face.show()
		#%Blinking_face.hide()
		#%Scared_face.hide()
#
		#parent.looking_over_wall_sequence.take_cover_behind_wall()
#
#func head_look_away_tween() -> void:
	#if parent.stunned:
		#%Timer.start(3.0)
		#return
#
	#var target_rot: Vector3 = await pick_turn_rot()
	#var orig_rot: Vector3 = parent.rotation_degrees
	#var rand_duration: float = randf_range(0.1, 0.3)
	#parent.anim.play("blinking_once")
	#parent.hit_able = true
#
	#parent.tween_rotate_head = parent.create_tween()
	#parent.tween_rotate_head.tween_property(parent, "rotation_degrees", -target_rot / 10, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	#parent.tween_rotate_head.tween_property(parent, "rotation_degrees", target_rot, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	#parent.tween_rotate_head.tween_interval(rand_duration)
	#parent.tween_rotate_head.tween_property(parent, "rotation_degrees", orig_rot, 0.25).set_ease(Tween.EASE_OUT).set_delay(0.5).set_trans(Tween.TRANS_SPRING)
	#parent.tween_rotate_head.parallel().tween_property(parent, "hit_able", false, 0.1).set_delay(0.1)
#
	#await parent.tween_rotate_head.finished
	#var rand_timer_dur: float = randf_range(0.5, 2.0)
	#%Timer.start(rand_timer_dur)
#
#func pick_turn_rot() -> Vector3:
	#var rand_num: int = randi_range(0, 4)
	#match rand_num:
		#0:
			#return Vector3.ZERO
		#1:
			#return Vector3(-45.0, 0.0, 0.0)
		#2:
			#return Vector3(45.0, 0.0, 0.0)
		#3:
			#return Vector3(0.0, 45.0, 0.0)
		#4:
			#return Vector3(0.0, -45.0, 0.0)
		#_:
			#return Vector3(0.0, 45.0, 0.0)
#
#
#func play_bobble() -> void:
	#parent.anim_wobble.speed_scale = 0.75
	#parent.anim_wobble.play("nodding")
	#await parent.anim_wobble.animation_finished
	#parent.anim_wobble.speed_scale = 1.0
#
#func play_sound() -> void:
	#parent.get_node('$SFX/Poking_sfx').play()
