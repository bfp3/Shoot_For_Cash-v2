extends Control

@onready var transition = $transitionAnimation
@onready var color_rect = $transitionAnimation/ColorRect

func play_intro() -> void:
	$dateCard.visible = true
	transition.play("fadeIn")
	$dateCardSong.play()
	await transition.animation_finished
	transition.play("fadeOut")
	await transition.animation_finished
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color('FFFFFF00'), 2.0)
	await tween.finished
	await get_tree().create_timer(1.0).timeout
	return
	
	#get_tree().change_scene_to_file("res://100_levels/00_levels/Prototype_distance_and_shooting_arcs.tscn")
	#
#func _on_end_timer_timeout():
	#get_tree().change_scene_to_file("res://100_levels/00_levels/Prototype_distance_and_shooting_arcs.tscn")
	#
#func _on_start_timer_timeout():
	#transition.play("fadeIn")
	#
#
#func _on_fade_out_timer_timeout():
	#transition.play("fadeOut")
