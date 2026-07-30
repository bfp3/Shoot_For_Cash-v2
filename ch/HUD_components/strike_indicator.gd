class_name StrikeIndicator
extends Control

@onready var miss_text_label: RichTextLabel = $MissTextLabel
@onready var size_control: Control = $Control
@onready var cross: TextureRect = $Control/CrossFront/Cross
@onready var cross_front: TextureRect = $Control/CrossFront
@onready var circle: TextureRect = $Control/Circle
@onready var back_circle: TextureRect = %BackCircle
@onready var front_most_circle: TextureRect = %FrontMostCircle

const inactive_colour_front := Color('ebe0d8')
const inactive_colour_back := Color('c60102')
const active_colour_front := Color('940104')
const active_colour_back := Color('dbc4b2')

@export var reveal_time := 0.22
@export var punch_scale := 1.35
@export var move_distance := 75.0
@export var move_time := 0.2
@export var hold_time := 0.2

var is_struck := false
var _cross_modulate: Color
var _cross_front_modulate: Color
var _size_control_scale: Vector2
var _active_tween: Tween
var _original_position: Vector2

func set_to_no_strike_colour() -> void:
	back_circle.modulate = inactive_colour_back
	front_most_circle.modulate = inactive_colour_front

func set_to_strike_colour() -> void:
	back_circle.modulate = active_colour_back
	front_most_circle.modulate = active_colour_front

func _ready() -> void:
	_cross_modulate = cross.modulate
	_cross_front_modulate = cross_front.modulate
	_size_control_scale = size_control.scale
	_original_position.y = position.y

	miss_text_label.modulate.a = 0.0
	set_to_no_strike_colour()

func reveal_strike() -> void:
	if is_struck:
		return
	is_struck = true
	_kill_tween()

	set_to_strike_colour()

	cross.visible = true
	cross_front.visible = true
	cross.modulate.a = 0.0
	cross_front.modulate.a = 0.0
	size_control.scale = _size_control_scale * 0.55
	position.y = _original_position.y

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(miss_text_label, "modulate:a", 1.0, reveal_time)
	_active_tween.tween_property(self, "position:y", _original_position.y - move_distance, move_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(size_control, "scale", _size_control_scale * punch_scale, reveal_time * 0.55)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(cross, "modulate:a", _cross_modulate.a, reveal_time)
	_active_tween.tween_property(cross_front, "modulate:a", _cross_front_modulate.a, reveal_time)
	_active_tween.set_parallel(false)
	_active_tween.tween_property(size_control, "scale", _size_control_scale, reveal_time * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(hold_time)
	_active_tween.tween_property(self, "position:y", _original_position.y, move_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func reset() -> void:
	_kill_tween()
	is_struck = false
	position.y = _original_position.y
	miss_text_label.modulate.a = 0.0
	cross.visible = false
	cross_front.visible = false
	cross.modulate = Color(_cross_modulate.r, _cross_modulate.g, _cross_modulate.b, 0.0)
	cross_front.modulate = Color(
		_cross_front_modulate.r,
		_cross_front_modulate.g,
		_cross_front_modulate.b,
		0.0
	)
	size_control.scale = _size_control_scale
	set_to_no_strike_colour()

func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

func restart() -> void:
	reset()
