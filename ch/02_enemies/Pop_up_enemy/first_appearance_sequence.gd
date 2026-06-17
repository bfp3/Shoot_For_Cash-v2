extends Node

@onready var parent: Poppers = $'../..'
@export var waiting_first_throw := 3.5


func first_appearance() -> void:
	await get_tree().create_timer(5.5).timeout
	peeking_over_wall_sequence()
	%Motif.play()
	%facials_anim_player.play('blinking_once')
	await get_tree().create_timer(1.0).timeout
	parent.head_look_away_tween()
	
	
func peeking_over_wall_sequence() -> void:
	
	parent.taken_cover = false
	parent.currently_peeking = true
	
	parent.look_at(parent.egg.global_position, Vector3.UP, false)
	parent.orig_pos = parent.global_position
	
	var random_dur : float = 0.5
	var tween = create_tween()
	tween.tween_property(parent, "global_position:y", parent.first_up_dist, parent.spotter_reveal_dur / 4).as_relative().set_trans(parent.trans_popping_up).set_ease(parent.ease_popping_up)
	tween.tween_property(parent, "global_position:y", parent.second_up_dist, parent.spotter_reveal_dur).as_relative().set_trans(parent.trans_popping_up).set_ease(parent.ease_popping_up)
	tween.tween_interval(random_dur)
	await tween.finished
	
	parent.set_physics_process(true)
	%body_movement.play('moving_around')
	
	
func angry_peek_over_wall() -> void:
	parent.taken_cover = false
	parent.currently_peeking = true
	
	parent.look_at(parent.egg.global_position, Vector3.UP, false)
	parent.orig_pos = parent.global_position
	
	var random_dur : float = 0.5
	var tween = create_tween()
	tween.tween_property(parent, "global_position:y", parent.first_up_dist, parent.spotter_reveal_dur).as_relative().set_trans(parent.trans_popping_up).set_ease(parent.ease_popping_up)
	tween.tween_property(parent, "global_position:y", parent.second_up_dist , parent.spotter_reveal_dur).as_relative().set_trans(parent.trans_popping_up).set_ease(parent.ease_popping_up)
	tween.tween_interval(random_dur)
	await tween.finished
	%facials_anim_player.play('blinking_once')
	parent.set_physics_process(true)
	%body_movement.play('moving_around')
	parent.going_through_first_sequence = false
	
	
func finished_first_throw() -> void:
	await get_tree().create_timer(waiting_first_throw).timeout
	angry_peek_over_wall()
	
	# Then we will add new animation where he looks up and gets angry.
	
	
	
	
