extends Control

@onready var color_rect := $Background_control

@export_group("Transition")
@export var slide_duration: float = 0.7
@export var transition: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Debug")
@export var enable_debug_input := true
@export var debug_action := "ui_accept"

var _toggled := false


func _ready() -> void:
	modulate = Color.WHITE
	_position_offscreen_bottom()


func _unhandled_input(event: InputEvent) -> void:
	if !enable_debug_input:
		return

	if event.is_action_pressed(debug_action):
		if _toggled:
			await next_level_finish()
		else:
			await next_level_start()

		_toggled = !_toggled


func next_level_start() -> void:
	var screen_height := get_viewport_rect().size.y

	color_rect.position.y = screen_height
	$TopRedPanel.position.y = -450.0
	
	var tween := create_tween()
	tween.set_trans(transition)
	tween.set_ease(ease)

	tween.tween_property(
		color_rect,
		"position:y",
		0.0,
		slide_duration
	)
	tween.parallel().tween_property($TopRedPanel, "position:y", 0.0,slide_duration) #.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT_IN)#.set_delay(0.5)

	await tween.finished


func next_level_finish() -> void:
	

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(ease)
	#tween.tween_interval(2.0)
	tween.tween_property($Background_control/CoatArms, "modulate:a", 0.0,1.0)
	tween.parallel().tween_property($Background_control/CoatArms, "modulate:a", 0.0,1.0)
	tween.parallel().tween_property($Background_control/Control, "modulate:a", 0.0,1.0)
	tween.parallel().tween_property($TopRedPanel, "position:y", -450.0,1.0).set_trans(Tween.TRANS_LINEAR)
	tween.parallel().tween_property($Background_control/Control, "position:x", 1920.0,0.5).as_relative().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.parallel().tween_callback($Background_control/Background.fade_in).set_delay(1.15)
	
	await tween.finished
	$TopRedPanel.modulate.a = 0.0
	return
	#var screen_height := get_viewport_rect().size.y
	
	
	
	
	#
	#var tween := create_tween()
	#tween.set_trans(Tween.TRANS_BACK)
	#tween.set_ease(ease)
#
	#tween.tween_property(
		#color_rect,
		#"position:y",
		#screen_height,
		#1.0
	#)
#
	#await tween.finished
#
	#_position_offscreen_bottom()


func demo_end_fadein() -> void:
	await next_level_start()


func demo_end_fadeout() -> void:
	await next_level_finish()


func _position_offscreen_bottom() -> void:
	var screen_height := get_viewport_rect().size.y
	color_rect.position.y = screen_height
