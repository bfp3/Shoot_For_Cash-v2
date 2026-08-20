class_name StrikeIndicator
extends Control

@onready var circle_duplicate: TextureRect = $Control/CircleDuplicate

@export var notice_pulse_count := 3
@export var notice_pulse_stagger_sec := 0.5
@export var notice_pulse_expand_scale := 1.85
@export var notice_pulse_expand_sec := 0.55



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
var _notice_token := 0
var _notice_rings: Array[TextureRect] = []


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


func reveal_strike(play_notice: bool = true) -> void:
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
	
	for i in range(4):
		_active_tween.tween_property(size_control, 'visible', false, 0.1)
		_active_tween.tween_property(size_control, 'visible', true, 0.1)
	_active_tween.tween_property(size_control, 'visible', false, 0.2)
	_active_tween.tween_property(size_control, 'visible', true, 0.2)
	if play_notice:
		_play_notice_pulses()
	
func conceal_strike() -> void:
	if not is_struck:
		return
	stop_notice_pulses()
	_kill_tween()

	set_to_strike_colour()
	cross.visible = true
	cross_front.visible = true
	cross.modulate.a = _cross_modulate.a
	cross_front.modulate.a = _cross_front_modulate.a
	size_control.scale = _size_control_scale

	var edge_scale := Vector2(0.001, _size_control_scale.y * flip_edge_y_scale)
	var half := maxf(flip_half_time, 0.01)
	var up_height := 50.0

	_active_tween = create_tween()
	_active_tween.tween_property(size_control, "scale", edge_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.parallel().tween_property(miss_text_label, "modulate:a", 0.0, half)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.parallel().tween_property(size_control, "position:y", -up_height, 0.1).as_relative()
	_active_tween.tween_callback(_hide_struck_face)
	_active_tween.tween_callback(set_to_no_strike_colour)
	_active_tween.tween_property(size_control, "scale", _size_control_scale, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(size_control, "position:y", up_height, 0.1).as_relative()
	await _active_tween.finished
	is_struck = false
	miss_text_label.modulate.a = 0.0


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
	stop_notice_pulses()
	_kill_tween()
	is_struck = false
	miss_text_label.modulate.a = 0.0
	_hide_struck_face()
	size_control.scale = _size_control_scale
	set_to_no_strike_colour()


func stop_notice_pulses() -> void:
	_notice_token += 1
	for ring in _notice_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_notice_rings.clear()


func _play_notice_pulses() -> void:
	if circle_duplicate == null:
		return
	stop_notice_pulses()
	circle_duplicate.visible = false
	var token := _notice_token
	_run_notice_pulses(token)


func _run_notice_pulses(token: int) -> void:
	var host := circle_duplicate.get_parent()
	if host == null:
		return
	for i in range(maxi(notice_pulse_count, 1)):
		if token != _notice_token:
			return
		_spawn_notice_ring(host, token)
		if i < notice_pulse_count - 1 and notice_pulse_stagger_sec > 0.0:
			await get_tree().create_timer(notice_pulse_stagger_sec, false).timeout


func _spawn_notice_ring(host: Node, token: int) -> void:
	if token != _notice_token or circle_duplicate == null:
		return
	var ring := circle_duplicate.duplicate() as TextureRect
	if ring == null:
		return
	host.add_child(ring)
	_notice_rings.append(ring)
	ring.visible = true
	ring.modulate.a = circle_duplicate.modulate.a
	ring.scale = circle_duplicate.scale
	ring.global_position = circle_duplicate.global_position
	var start_scale := ring.scale
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", start_scale * notice_pulse_expand_scale, notice_pulse_expand_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, notice_pulse_expand_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_notice_rings.erase(ring)
		if is_instance_valid(ring):
			ring.queue_free()
	)


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func restart() -> void:
	reset()
