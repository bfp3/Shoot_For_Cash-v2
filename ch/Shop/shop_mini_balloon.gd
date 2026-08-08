class_name ShopMiniBalloon
extends Node2D
## Hazard balloon — pans in from below, sits in front of rocks, shooting it = strike.

signal popped(balloon: ShopMiniBalloon, pos: Vector2, counts_as_strike: bool)
signal drifted_away(balloon: ShopMiniBalloon)

@export var fill_color := Color(0.86, 0.18, 0.22, 1.0)
@export var outline_color := Color(0.08, 0.09, 0.11, 1.0)
@export var outline_width := 2.0
@export_range(0.2, 4.0, 0.05) var approach_duration := 0.85
@export_range(0.0, 80.0, 1.0) var pan_distance := 18.0
@export_range(0.5, 6.0, 0.05) var pan_duration := 2.4
@export_range(0.0, 3.0, 0.05) var pan_start_delay := 0.35
@export_range(40.0, 400.0, 1.0) var drift_speed := 120.0

var radius := 22.0
var hit := false
var arrived := false
var drifting := false
var rest_position := Vector2.ZERO

var _approach_tween: Tween
var _pan_tween: Tween
var _drift_tween: Tween


func setup(p_radius: float) -> void:
	radius = p_radius
	hit = false
	arrived = false
	drifting = false
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
	if hit or drifting:
		return
	arrived = true
	position = rest_position
	_start_gentle_pan()


func _start_gentle_pan() -> void:
	if hit or drifting or pan_distance <= 0.01:
		return
	_stop_gentle_pan()
	_pan_tween = create_tween()
	_pan_tween.tween_interval(pan_start_delay)
	_pan_tween.tween_callback(_run_pan_loop)


func _run_pan_loop() -> void:
	if hit or drifting or not is_instance_valid(self):
		return
	_stop_gentle_pan()
	_pan_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_loops()
	_pan_tween.tween_property(self, "position:x", rest_position.x - pan_distance, pan_duration)
	_pan_tween.tween_property(self, "position:x", rest_position.x + pan_distance, pan_duration)


func _stop_gentle_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


## End of wave: float up and off the top of the screen (no strike).
func begin_drift_away(offscreen_y: float = -80.0) -> void:
	if hit or drifting:
		return
	drifting = true
	arrived = false
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	_stop_gentle_pan()
	if _drift_tween and _drift_tween.is_valid():
		_drift_tween.kill()
	var dist := maxf(position.y - offscreen_y, 1.0)
	var duration := clampf(dist / maxf(drift_speed, 1.0), 0.35, 4.0)
	var sway := randf_range(-28.0, 28.0)
	_drift_tween = create_tween().set_parallel(true)
	_drift_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_drift_tween.tween_property(self, "position:y", offscreen_y, duration)
	_drift_tween.tween_property(self, "position:x", position.x + sway, duration)
	_drift_tween.set_parallel(false)
	_drift_tween.tween_callback(_finish_drift)


func _finish_drift() -> void:
	if hit:
		return
	hit = true
	drifting = false
	hide()
	drifted_away.emit(self)


func apply_shot(counts_as_strike: bool = true) -> bool:
	if hit or drifting:
		return false
	hit = true
	arrived = false
	drifting = false
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	_stop_gentle_pan()
	if _drift_tween and _drift_tween.is_valid():
		_drift_tween.kill()
	var pos := position
	popped.emit(self, pos, counts_as_strike)
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
