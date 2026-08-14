extends Control
class_name VolumeDial

## Circular volume dial.
## Navigate onto it with the stick, then press Accept / click to edit.
## While editing, the dial enlarges front-and-center; directions change volume;
## Back / click outside confirms and returns to settings navigation.

signal value_changed(value: float)
signal edit_started
signal edit_ended

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
		if _edit_label:
			_edit_label.text = "%d%%" % int(round(value))

@export var dial_size := Vector2(140, 140)
@export var edit_dial_size := Vector2(280, 280)
@export var ring_width := 14.0
@export var drag_pixels_per_full_range := 140.0

var _dragging := false
var _drag_start_y := 0.0
var _drag_start_value := 0.0
var _center_label: Label
var _editing := false

var _edit_layer: CanvasLayer
var _edit_dim: ColorRect
var _edit_dial: Control
var _edit_label: Label

var _hold_dir := 0 # +1 raise, -1 lower, 0 none
var _hold_timer := 0.0
var _hold_repeating := false

const HOLD_INITIAL_DELAY := 0.28
const HOLD_REPEAT_RATE := 0.045


func _ready() -> void:
	custom_minimum_size = dial_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_center_label()
	_center_label.text = "%d%%" % int(round(value))
	queue_redraw()


func is_editing() -> bool:
	return _editing


func set_value_no_signal(v: float) -> void:
	var clamped := clampf(v, min_value, max_value)
	if step > 0.0:
		clamped = snappedf(clamped, step)
	value = clamped


func begin_edit() -> void:
	if _editing:
		return
	_editing = true
	_dragging = false
	_reset_hold()
	_ensure_edit_overlay()
	_edit_layer.show()
	_sync_edit_visual()
	_edit_dial.grab_focus()
	edit_started.emit()
	queue_redraw()


func end_edit() -> void:
	if not _editing:
		return
	_editing = false
	_dragging = false
	_reset_hold()
	if _edit_layer:
		_edit_layer.hide()
	grab_focus()
	edit_ended.emit()
	queue_redraw()


func _reset_hold() -> void:
	_hold_dir = 0
	_hold_timer = 0.0
	_hold_repeating = false


func _process(delta: float) -> void:
	if not _editing:
		return
	_update_hold_repeat(delta)


func _update_hold_repeat(delta: float) -> void:
	var dir := 0
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_right"):
		dir = 1
	elif Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_left"):
		dir = -1

	if dir == 0:
		_reset_hold()
		return

	var amount := (step if step > 0.0 else 1.0) * float(dir)
	if dir != _hold_dir:
		# Fresh press — first nudge comes from gui_input; start hold timer here.
		_hold_dir = dir
		_hold_timer = 0.0
		_hold_repeating = false
		return

	_hold_timer += delta
	if not _hold_repeating:
		if _hold_timer >= HOLD_INITIAL_DELAY:
			_hold_repeating = true
			_hold_timer = 0.0
			_nudge(amount)
	elif _hold_timer >= HOLD_REPEAT_RATE:
		_hold_timer = 0.0
		_nudge(amount)


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


func _ensure_edit_overlay() -> void:
	if _edit_layer and is_instance_valid(_edit_layer):
		return

	_edit_layer = CanvasLayer.new()
	_edit_layer.name = "VolumeDialEditOverlay"
	_edit_layer.layer = 140
	_edit_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_edit_layer.hide()
	add_child(_edit_layer)

	_edit_dim = ColorRect.new()
	_edit_dim.name = "Dim"
	_edit_dim.color = Color(0.05, 0.05, 0.06, 0.72)
	_edit_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_edit_dim.gui_input.connect(_on_edit_dim_gui_input)
	_edit_layer.add_child(_edit_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_layer.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	var hint := Label.new()
	hint.text = "Adjust volume  ·  Back to confirm"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color(0.92, 0.88, 0.85, 1.0))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hint)

	_edit_dial = Control.new()
	_edit_dial.name = "EditDial"
	_edit_dial.custom_minimum_size = edit_dial_size
	_edit_dial.size = edit_dial_size
	_edit_dial.focus_mode = Control.FOCUS_ALL
	_edit_dial.mouse_filter = Control.MOUSE_FILTER_STOP
	_edit_dial.process_mode = Node.PROCESS_MODE_ALWAYS
	_edit_dial.draw.connect(_draw_edit_dial)
	_edit_dial.gui_input.connect(_on_edit_dial_gui_input)
	column.add_child(_edit_dial)

	_edit_label = Label.new()
	_edit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_edit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_label.add_theme_font_size_override("font_size", 48)
	_edit_label.add_theme_color_override("font_color", Color(0.08, 0.09, 0.11, 1.0))
	_edit_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit_dial.add_child(_edit_label)


func _sync_edit_visual() -> void:
	if _edit_label:
		_edit_label.text = "%d%%" % int(round(value))
	if _edit_dial:
		_edit_dial.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree() and _editing:
			end_edit()


func _gui_input(event: InputEvent) -> void:
	# Not editing: Accept / click opens the editor. Directions stay free for menu nav.
	if event.is_action_pressed("ui_accept"):
		begin_edit()
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin_edit()
		accept_event()
		return

	if event is InputEventScreenTouch and event.pressed:
		begin_edit()
		accept_event()


func _on_edit_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		end_edit()
		_edit_dim.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		end_edit()
		_edit_dim.accept_event()


func _on_edit_dial_gui_input(event: InputEvent) -> void:
	if not _editing:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back_button"):
		end_edit()
		_edit_dial.accept_event()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_right"):
		_nudge(step if step > 0.0 else 1.0)
		_edit_dial.accept_event()
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left"):
		_nudge(-(step if step > 0.0 else 1.0))
		_edit_dial.accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position.y)
			_edit_dial.accept_event()
		else:
			_end_drag()
			_edit_dial.accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(step if step > 0.0 else 1.0)
			_edit_dial.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(-(step if step > 0.0 else 1.0))
			_edit_dial.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position.y)
			_edit_dial.accept_event()
		else:
			_end_drag()
			_edit_dial.accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_apply_drag(event.position.y)
		_edit_dial.accept_event()


func _input(event: InputEvent) -> void:
	if _editing:
		# Global back while the large dial is open (in case focus slipped).
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back_button"):
			if not event.is_echo():
				end_edit()
				get_viewport().set_input_as_handled()
			return
		# Keep dragging even when the cursor leaves the dial bounds.
		if _dragging:
			if event is InputEventMouseMotion:
				_apply_drag(_edit_dial.get_local_mouse_position().y)
				get_viewport().set_input_as_handled()
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_end_drag()
				get_viewport().set_input_as_handled()
		return

	# Keep original drag tracking unused outside edit (click opens editor instead).


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
	_sync_edit_visual()
	if not is_equal_approx(previous, value):
		value_changed.emit(value)


func _draw() -> void:
	_draw_dial_on(self, size, ring_width, has_focus() and not _editing, 28)


func _draw_edit_dial() -> void:
	if _edit_dial == null:
		return
	_draw_dial_on(_edit_dial, _edit_dial.size, ring_width * 1.6, true, 48)


func _draw_dial_on(target: Control, draw_size: Vector2, width: float, show_focus: bool, _label_size: int) -> void:
	var center := draw_size * 0.5
	var _radius := mini(draw_size.x, draw_size.y) * 0.5 - 4.0
	var track := Color(0.21, 0.23, 0.25, 0.35)
	var fill := Color(0.78, 0.004, 0.008, 1.0)
	var knob := Color(0.92, 0.88, 0.85, 1.0)
	var ink := Color(0.08, 0.09, 0.11, 1.0)

	target.draw_circle(center, _radius, track)
	target.draw_arc(center, _radius - width * 0.5, -PI * 0.5, -PI * 0.5 + TAU, 64, Color(0.21, 0.23, 0.25, 0.55), width, true)

	var t := 0.0
	if max_value > min_value:
		t = (value - min_value) / (max_value - min_value)
	var end_angle := -PI * 0.5 + TAU * t
	if t > 0.001:
		target.draw_arc(center, _radius - width * 0.5, -PI * 0.5, end_angle, 64, fill, width, true)

	var inner_r := _radius - width - 4.0
	target.draw_circle(center, maxf(inner_r, 8.0), knob)
	target.draw_arc(center, maxf(inner_r, 8.0), 0.0, TAU, 48, ink, 2.0 if not show_focus else 3.5, true)
	if show_focus:
		target.draw_arc(center, _radius + 2.0, 0.0, TAU, 48, fill, 3.0, true)

	var tick_pos := center + Vector2(cos(end_angle), sin(end_angle)) * (_radius - width * 0.5)
	target.draw_circle(tick_pos, 6.0 if target == self else 10.0, fill)
	target.draw_circle(tick_pos, 3.0 if target == self else 5.0, knob)
