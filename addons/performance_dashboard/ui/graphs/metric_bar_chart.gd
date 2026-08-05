class_name PDMetricBarChart
extends Control

## Dual-bar chart: current value vs profile target for each metric.
## Reuses internal row data — call set_profile() / set_metrics() without rebuilding controls.

signal metric_hovered(metric_id: StringName)

const ROW_HEIGHT := 28.0
const LABEL_WIDTH := 150.0
const VALUE_WIDTH := 72.0
const BAR_GAP := 3.0
const PAD_X := 8.0
const PAD_Y := 6.0

var _defs: Array[PDMetricDefinition] = []
var _currents: PackedFloat32Array = PackedFloat32Array()
var _targets: PackedFloat32Array = PackedFloat32Array()
var _scale_max: PackedFloat32Array = PackedFloat32Array()
var _profile: PerformanceTargetProfile
var _font: Font
var _hover_index: int = -1


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(definitions: Array[PDMetricDefinition]) -> void:
	_defs = definitions
	var n := _defs.size()
	_currents.resize(n)
	_targets.resize(n)
	_scale_max.resize(n)
	for i in n:
		_currents[i] = 0.0
		_targets[i] = 0.0
		_scale_max[i] = 1.0
	custom_minimum_size = Vector2(0, PAD_Y * 2.0 + n * ROW_HEIGHT)
	queue_redraw()


func set_profile(profile: PerformanceTargetProfile) -> void:
	_profile = profile
	_refresh_targets()
	queue_redraw()


func set_metrics(metrics: Dictionary) -> void:
	var n := _defs.size()
	for i in n:
		var id: StringName = _defs[i].id
		_currents[i] = float(metrics.get(id, 0.0))
		var t := _targets[i]
		var c := _currents[i]
		# Auto-scale so both bars stay readable when values spike.
		_scale_max[i] = maxf(maxf(t, c) * 1.15, 0.0001)
	queue_redraw()


func _refresh_targets() -> void:
	if _profile == null:
		return
	for i in _defs.size():
		_targets[i] = _profile.get_target(_defs[i].id, 0.0)


func _draw() -> void:
	if _defs.is_empty():
		return
	var font_size := 12
	var y := PAD_Y

	for i in _defs.size():
		var def := _defs[i]
		var current := _currents[i]
		var target := _targets[i]
		var scale_max := _scale_max[i]
		var status := PDDashboardStyle.status_color(current, target, def.higher_is_better)

		if i % 2 == 1:
			draw_rect(Rect2(0, y, size.x, ROW_HEIGHT), PDDashboardStyle.ROW_ALT)

		draw_string(
			_font,
			Vector2(PAD_X, y + ROW_HEIGHT * 0.68),
			def.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			LABEL_WIDTH - 4.0,
			font_size,
			PDDashboardStyle.TEXT_PRIMARY
		)

		var bar_x := PAD_X + LABEL_WIDTH
		var bar_w := maxf(size.x - bar_x - VALUE_WIDTH * 2.0 - PAD_X * 2.0, 40.0)
		var bar_h := (ROW_HEIGHT - BAR_GAP * 3.0) * 0.5
		var current_w := clampf(current / scale_max, 0.0, 1.0) * bar_w
		var target_w := clampf(target / scale_max, 0.0, 1.0) * bar_w

		draw_rect(Rect2(bar_x, y + BAR_GAP, bar_w, bar_h), Color(0.12, 0.13, 0.15))
		draw_rect(Rect2(bar_x, y + BAR_GAP * 2.0 + bar_h, bar_w, bar_h), Color(0.12, 0.13, 0.15))

		draw_rect(Rect2(bar_x, y + BAR_GAP, current_w, bar_h), status)
		draw_rect(Rect2(bar_x, y + BAR_GAP * 2.0 + bar_h, target_w, bar_h), PDDashboardStyle.BAR_TARGET)

		var value_x := bar_x + bar_w + 8.0
		draw_string(
			_font,
			Vector2(value_x, y + ROW_HEIGHT * 0.45),
			def.format_value(current),
			HORIZONTAL_ALIGNMENT_LEFT,
			VALUE_WIDTH,
			font_size - 1,
			status
		)
		draw_string(
			_font,
			Vector2(value_x, y + ROW_HEIGHT * 0.82),
			def.format_value(target),
			HORIZONTAL_ALIGNMENT_LEFT,
			VALUE_WIDTH,
			font_size - 1,
			PDDashboardStyle.TEXT_MUTED
		)

		y += ROW_HEIGHT


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := int((event.position.y - PAD_Y) / ROW_HEIGHT)
		if idx != _hover_index and idx >= 0 and idx < _defs.size():
			_hover_index = idx
			metric_hovered.emit(_defs[idx].id)
