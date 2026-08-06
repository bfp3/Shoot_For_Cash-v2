class_name ShopMiniBalloon
extends Node2D
## Hazard balloon — pans in from below, sits in front of rocks, shooting it = strike.

signal popped(balloon: ShopMiniBalloon, pos: Vector2)

@export var fill_color := Color(0.86, 0.18, 0.22, 1.0)
@export var outline_color := Color(0.08, 0.09, 0.11, 1.0)
@export var outline_width := 2.0
@export_range(0.2, 4.0, 0.05) var approach_duration := 0.85
@export_range(0.0, 80.0, 1.0) var pan_distance := 18.0
@export_range(0.5, 6.0, 0.05) var pan_duration := 2.4
@export_range(0.0, 3.0, 0.05) var pan_start_delay := 0.35

var radius := 22.0
var hit := false
var arrived := false
var rest_position := Vector2.ZERO

var _approach_tween: Tween
var _pan_tween: Tween


func setup(p_radius: float) -> void:
	radius = p_radius
	hit = false
	arrived = false
	z_index = 80
	z_as_relative = false
	queue_redraw()


func begin_approach(from_pos: Vector2, to_pos: Vector2) -> void:
	rest_position = to_pos
	position = from_pos
	show()
	if _approach_tween:
		_approach_tween.kill()
	_approach_tween = create_tween()
	_approach_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_approach_tween.tween_property(self, "position", to_pos, approach_duration)
	_approach_tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	if hit:
		return
	arrived = true
	position = rest_position
	_start_gentle_pan()


func _start_gentle_pan() -> void:
	if hit or pan_distance <= 0.01:
		return
	_stop_gentle_pan()
	_pan_tween = create_tween()
	_pan_tween.tween_interval(pan_start_delay)
	_pan_tween.tween_callback(_run_pan_loop)


func _run_pan_loop() -> void:
	if hit or not is_instance_valid(self):
		return
	_stop_gentle_pan()
	_pan_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_loops()
	_pan_tween.tween_property(self, "position:x", rest_position.x - pan_distance, pan_duration)
	_pan_tween.tween_property(self, "position:x", rest_position.x + pan_distance, pan_duration)


func _stop_gentle_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


func apply_shot() -> bool:
	if hit:
		return false
	hit = true
	arrived = false
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	_stop_gentle_pan()
	var pos := position
	popped.emit(self, pos)
	hide()
	return true


func _draw() -> void:
	var body := Vector2(0.0, -radius * 0.15)
	draw_circle(body, radius, fill_color)
	draw_arc(body, radius, 0.0, TAU, 28, outline_color, outline_width, true)
	draw_circle(body + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.18, Color(1, 1, 1, 0.35))
	var knot := Vector2(0.0, radius * 0.75)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, radius * 0.55),
		Vector2(4.0, radius * 0.55),
		knot,
	]), fill_color)
	draw_line(knot, Vector2(0.0, radius * 1.55), outline_color, 1.5, true)
