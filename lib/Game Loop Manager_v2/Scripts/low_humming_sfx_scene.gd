extends AudioStreamPlayer
class_name Low_Humming_HUD_Noise

func _ready() -> void:
	play_sound()

func play_sound() -> void:

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", 15.0, 0.15)
	tween.parallel().tween_property(self, "pitch_scale", 0.6, 0.15)
	await tween.finished

func HUD_off_mode() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	
	tween.tween_property(self, "volume_db", 20.0, 0.4)
	tween.parallel().tween_property(self, "pitch_scale", 0.15, 0.5)
	tween.parallel().tween_callback(silence_buzzing_noise).set_delay(0.4)
	await tween.finished
	#silence_buzzing_noise()
	
func settle_phase_buzzing() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", 10.0, 1.5)
	tween.parallel().tween_property(self, "pitch_scale", 0.15, 0.5)
	await tween.finished
	
func silence_buzzing_noise() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "volume_db", -20.0, 2.5)
	tween.parallel().tween_property(self, "pitch_scale", 0.2, 0.5)
	tween.tween_property(self, "volume_db", -80.0, 1.0)
	#tween.parallel().tween_property(self, "pitch_scale", 0.4, 0.5)
	await tween.finished

func fade_out_sound() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "volume_db", -80.0, 2.0)
	tween.parallel().tween_property(self, "pitch_scale", 0.3, 2.0)
	await tween.finished
	
	#self.queue_free()
