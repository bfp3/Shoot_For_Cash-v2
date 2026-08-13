extends Control

@export var sfx_1 : AudioStreamPlayer
@export var sfx_2 : AudioStreamPlayer
@export var sfx_3 : AudioStreamPlayer
@onready var black_screen: Control = $BlackScreen

@onready var wormfood_logo: Control = $WormfoodLogoContainer
@onready var presents: RichTextLabel = %Presents
@onready var copyright: RichTextLabel = $WormfoodLogoContainer/Copyright
@onready var wmf_logo: Control = %WMFLogo

func start():
	#sfx_1.play()
	copyright.modulate.a = 0.0
	wmf_logo.scale = Vector2.ONE * 10.0
	wormfood_logo.modulate.a = 0.0
	presents.modulate.a = 0.0
	wmf_logo.modulate.a = 0.0
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(wormfood_logo, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(copyright, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(wmf_logo, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(wmf_logo, "scale", Vector2.ONE, 0.35)
	#tween.parallel().tween_callback($stampSFX.play).set_delay(0.32)
	tween.parallel().tween_callback($stampSFX22.play).set_delay(0.32)
	tween.tween_property(wmf_logo, "scale", Vector2.ONE * 1.5, 0.1)
	tween.tween_property(wmf_logo, "scale", Vector2.ONE, 0.05)
	tween.tween_interval(2.0)
	tween.tween_property(wormfood_logo, "modulate:a", 0.0, 0.5)
	#tween.parallel().tween_property(presents, "modulate:a", 0.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(black_screen, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	hide()
	return
	
