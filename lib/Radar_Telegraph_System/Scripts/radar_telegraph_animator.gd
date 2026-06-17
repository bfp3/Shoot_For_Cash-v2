extends Node

signal animation_complete

func play_animation(batch: Array) -> void:
	pass
	#for shot in batch:
		#var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		#tween.tween_property(shot, "modulate", Color('FFFFFF00'),0.1)
		#tween.tween_property(shot, "modulate", Color('FFFFFF'),0.5)
		#await tween.finished
	#emit_signal("animation_complete")
