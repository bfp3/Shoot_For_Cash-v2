extends AudioStreamPlayer
class_name Background_Soundscape

func _ready() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -40.0, 0.5)
	await tween.finished

func sound_silence_phase() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -40.0, 0.5)
	await tween.finished
	
func complete_silence() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -80.0, 0.5)
	await tween.finished
	
func lower_sound_HUD_ON() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -62.0, 0.15)
	await tween.finished
	
func lower_sound_silence_2() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -45.0, 2.0)
	await tween.finished

#func fade_out_sound() -> void:
	#var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property(self, "volume_db", -40.0, 2.0)
	#tween.parallel().tween_property(self, "pitch_scale", -0.1, 0.5).as_relative()
	#await tween.finished
	
	#self.queue_free()
