extends Control

var tween_blinking : Tween = null
var active := false
@onready var texture: TextureRect = $Texture


func start() -> void:
	show()
	%SkyMineLabel.text = str(gl_PlayerState.dataset.power_sky_mine)
	$SkyMineParticles2D.emitting = true
	active = true
	%Flicker_sound.play()
	texture.modulate.a = 1.0
	start_blinking_tween()
	#panel_tween()
	
func panel_tween() -> void:
	var tween = create_tween()
	tween.tween_property($Panel, 'modulate', Color(4.416, 0.0, 0.0), 0.5)
	
func start_blinking_tween() -> void:
	texture.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(texture, 'modulate:a', 0.3, 0.1)
	tween.tween_property(texture, 'modulate:a', 0.9, 0.1)
	await tween.finished
	if active:
		start_blinking_tween()
	else:
		fade_modulate_tween()


func fade_modulate_tween() -> void:
	texture.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(texture, 'modulate', Color('666666'), 0.5)
	tween.parallel().tween_property($Panel, 'modulate', Color.WHITE, 0.5)
	await tween.finished
	hide()
	
func stop() -> void:

	active = false
	#show()
	#%SkyMineLabel.show()
	hide()
