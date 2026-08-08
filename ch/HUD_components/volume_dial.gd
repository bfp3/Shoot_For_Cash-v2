extends Control
class_name VolumeDial

## Circular volume dial. Drag up to raise, down to lower. Percentage shown in the center.

signal value_changed(value: float)

@export var min_value := 0.0
@export var max_value := 100.0
@export var step := 1.0
@export var value := 100.0:
	set(v):
		var clamped := clampf(v, min_value, max_value)
		if step > 0.0:
			clamped = snappedf(clamped, step)
		if is_equal_approx(value, clamped):
			return
		value = clamped
		queue_redraw()
		if _center_label:
			_center_label.text = "%d%%" % int(round(value))

@export var dial_size := Vector2(140, 140)
@export var ring_width := 14.0
@export var drag_pixels_per_full_range := 140.0

var _dragging := false
var _drag_start_y := 0.0
var _drag_start_value := 0.0
var _center_label: Label


func _ready() -> void:
	custom_minimum_size = dial_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_center_label()
	_center_label.text = "%d%%" % int(round(value))
	queue_redraw()


func set_value_no_signal(v: float) -> void:
	var clamped := clampf(v, min_value, max_value)
	if step > 0.0:
		clamped = snappedf(clamped, step)
	value = clamped


func _ensure_center_label() -> void:
	if _center_label and is_instance_valid(_center_label):
		return
	_center_label = Label.new()
	_center_label.name = "CenterPercent"
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.add_theme_font_size_override("font_size", 28)
	_center_label.add_theme_color_override("font_color", Color(0.08, 0.09, 0.11, 1.0))
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position.y)
			accept_event()
		else:
			_end_drag()
			accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(step if step > 0.0 else 1.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(-(step if step > 0.0 else 1.0))
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position.y)
			accept_event()
		else:
			_end_drag()
			accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_apply_drag(event.position.y)
		accept_event()


func _input(event: InputEvent) -> void:
	# Keep dragging even when the cursor leaves the dial bounds.
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_apply_drag(get_local_mouse_position().y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
		get_viewport().set_input_as_handled()


func _begin_drag(local_y: float) -> void:
	_dragging = true
	_drag_start_y = local_y
	_drag_start_value = value


func _end_drag() -> void:
	_dragging = false


func _apply_drag(local_y: float) -> void:
	# Drag up = louder, drag down = quieter.
	var delta_y: float = _drag_start_y - local_y
	var range_span := maxf(max_value - min_value, 1.0)
	var next := _drag_start_value + (delta_y / maxf(drag_pixels_per_full_range, 1.0)) * range_span
	_set_from_interaction(next)


func _nudge(amount: float) -> void:
	_set_from_interaction(value + amount)


func _set_from_interaction(next: float) -> void:
	var previous := value
	set_value_no_signal(next)
	if not is_equal_approx(previous, value):
		value_changed.emit(value)


func _draw() -> void:
	var center := size * 0.5
	var radius := mini(size.x, size.y) * 0.5 - 4.0
	var track := Color(0.21, 0.23, 0.25, 0.35)
	var fill := Color(0.78, 0.004, 0.008, 1.0)
	var knob := Color(0.92, 0.88, 0.85, 1.0)
	var ink := Color(0.08, 0.09, 0.11, 1.0)

	draw_circle(center, radius, track)
	draw_arc(center, radius - ring_width * 0.5, -PI * 0.5, -PI * 0.5 + TAU, 64, Color(0.21, 0.23, 0.25, 0.55), ring_width, true)

	var t := 0.0
	if max_value > min_value:
		t = (value - min_value) / (max_value - min_value)
	var end_angle := -PI * 0.5 + TAU * t
	if t > 0.001:
		draw_arc(center, radius - ring_width * 0.5, -PI * 0.5, end_angle, 64, fill, ring_width, true)

	var inner_r := radius - ring_width - 4.0
	draw_circle(center, maxf(inner_r, 8.0), knob)
	draw_arc(center, maxf(inner_r, 8.0), 0.0, TAU, 48, ink, 2.0, true)

	# Small indicator tick on the rim.
	var tick_angle := end_angle
	var tick_pos := center + Vector2(cos(tick_angle), sin(tick_angle)) * (radius - ring_width * 0.5)
	draw_circle(tick_pos, 6.0, fill)
	draw_circle(tick_pos, 3.0, knob)
