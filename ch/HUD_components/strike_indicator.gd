class_name StrikeIndicator
extends Control

@onready var miss_text_label: RichTextLabel = $MissTextLabel
@onready var size_control: Control = $Control
@onready var cross: TextureRect = $Control/CrossFront/Cross
@onready var cross_front: TextureRect = $Control/CrossFront
@onready var circle: TextureRect = $Control/Circle
@onready var back_circle: TextureRect = %BackCircle
@onready var front_most_circle: TextureRect = %FrontMostCircle

const inactive_colour_front := Color('ebe0d828') #Color('ebe0d8')
const inactive_colour_back := Color('dbc4b2') # Color('c60102')
const active_colour_front := Color('940104')
const active_colour_back := Color('dbc4b2')

## Duration of each half of the coin-flip (empty → edge, then edge → struck).
@export var flip_half_time := 0.1
## Slight vertical squash at the edge-on midpoint for a bit of 3D feel.
@export var flip_edge_y_scale := 1.12
@export var hold_time := 0.15

var is_struck := false
var _cross_modulate: Color
var _cross_front_modulate: Color
var _size_control_scale: Vector2
var _active_tween: Tween


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
	miss_text_label.modulate.a = 0.0
	set_to_no_strike_colour()
	_hide_struck_face()


func reveal_strike() -> void:
	if is_struck:
		return
	is_struck = true
	_kill_tween()

	# Start on the empty face; swap contents at the edge-on midpoint.
	set_to_no_strike_colour()
	_hide_struck_face()
	size_control.scale = _size_control_scale

	var edge_scale := Vector2(0.001, _size_control_scale.y * flip_edge_y_scale)
	var half := maxf(flip_half_time, 0.01)
	var up_height := 50.0

	_active_tween = create_tween()
	# Flip empty face to edge-on.
	_active_tween.tween_property(size_control, "scale", edge_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	_active_tween.parallel().tween_property(size_control, "position:y", -up_height, 0.1).as_relative()
	# Swap to the struck face while it's a thin line.
	_active_tween.tween_callback(_show_struck_face)
	# Flip edge-on out to the struck face.
	_active_tween.tween_property(size_control, "scale", _size_control_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(miss_text_label, "modulate:a", 1.0, half)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(hold_time)
	_active_tween.tween_property(size_control, "position:y", up_height, 0.1).as_relative()


func _hide_struck_face() -> void:
	cross.visible = false
	cross_front.visible = false
	cross.modulate.a = 0.0
	cross_front.modulate.a = 0.0


func _show_struck_face() -> void:
	set_to_strike_colour()
	cross.visible = true
	cross_front.visible = true
	cross.modulate.a = _cross_modulate.a
	cross_front.modulate.a = _cross_front_modulate.a


func reset() -> void:
	_kill_tween()
	is_struck = false
	miss_text_label.modulate.a = 0.0
	_hide_struck_face()
	size_control.scale = _size_control_scale
	set_to_no_strike_colour()


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func restart() -> void:
	reset()
