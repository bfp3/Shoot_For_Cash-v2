extends Control


func next_level_start() -> void:
	#$'../../..'.scale = Vector2.ONE * 2
	var tween = create_tween()
	tween.tween_property(self, 'modulate', Color.WHITE, 0.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished

func next_level_finish() -> void:
	#$'../../..'.scale = Vector2.ONE
	var tween = create_tween()
	tween.tween_property(self, 'modulate', Color.TRANSPARENT, 1.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished

#func instant_fade_in() -> void:
	#show()
	#self.modulate = Color.BLACK

func demo_end_fadein() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'modulate', Color.WHITE, 0.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	

func demo_end_fadeout() -> void:
	var tween = create_tween()
	tween.tween_property(self, 'modulate', Color.TRANSPARENT, 1.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
