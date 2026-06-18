extends Control

var tween_blinking : Tween = null
var active := false


func start() -> void:
	show()
	$SkyMineParticles2D.emitting = true
	active = true
	%Flicker_sound.play()
	%SkyMineLabel.modulate.a = 1.0
	start_blinking_tween()
	#panel_tween()
	
func panel_tween() -> void:
	var tween = create_tween()
	tween.tween_property($Panel, 'modulate', Color(4.416, 0.0, 0.0), 0.5)
	
func start_blinking_tween() -> void:
	%SkyMineLabel.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(%SkyMineLabel, 'modulate:a', 0.3, 0.1)
	tween.tween_property(%SkyMineLabel, 'modulate:a', 0.9, 0.1)
	await tween.finished
	if active:
		start_blinking_tween()
	else:
		fade_modulate_tween()


func fade_modulate_tween() -> void:
	%SkyMineLabel.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(%SkyMineLabel, 'modulate', Color('666666'), 0.5)
	tween.parallel().tween_property($Panel, 'modulate', Color.WHITE, 0.5)

	
func stop() -> void:
	active = false
	show()
	%SkyMineLabel.show()
