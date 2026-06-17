extends Control

func display_tally() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color('FFFFFF79'), 0.5)
	tween.parallel().tween_property($Scale_control/Light, "modulate", Color.GOLD, 0.5)
	await tween.finished
