extends Control

@export var sfx_1 : AudioStreamPlayer
@export var sfx_2 : AudioStreamPlayer
@export var sfx_3 : AudioStreamPlayer
@onready var black_screen: Control = $BlackScreen

@onready var wormfood_logo: TextureRect = %Wormfood_Logo
@onready var presents: RichTextLabel = %Presents

func start():
	#sfx_1.play()
	
	wormfood_logo.modulate.a = 0.0
	presents.modulate.a = 0.0
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(wormfood_logo, "modulate:a", 1.0, 0.5)
	#tween.tween_interval(1.0)
	#tween.tween_property(presents, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(wormfood_logo, "modulate:a", 0.0, 0.5)
	#tween.parallel().tween_property(presents, "modulate:a", 0.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_property(black_screen, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	hide()
	return
	
