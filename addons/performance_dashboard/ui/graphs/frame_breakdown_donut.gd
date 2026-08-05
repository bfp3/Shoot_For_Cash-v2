class_name PDFrameBreakdownDonut
extends Control

## Live donut chart for estimated frame-time category breakdown.

const DONUT_THICKNESS_RATIO := 0.42
const LEGEND_ROW := 18.0
const CHART_MIN := 120.0

var _ms: Dictionary = {}
var _pct: Dictionary = {}
var _font: Font
var _total_ms: float = 0.0
## Reused across draws to avoid per-frame PackedVector2Array allocations.
var _slice_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	custom_minimum_size = Vector2(280, 220)


func set_breakdown(breakdown: PDFrameTimeBreakdown) -> void:
	# Copy into reused local dicts without replacing references each call.
	var src_ms := breakdown.get_milliseconds()
	var src_pct := breakdown.get_percentages()
	for cat in PDFrameTimeBreakdown.CATEGORY_ORDER:
		_ms[cat] = float(src_ms.get(cat, 0.0))
		_pct[cat] = float(src_pct.get(cat, 0.0))
	_total_ms = breakdown.get_total_ms()
	queue_redraw()


func _draw() -> void:
	var font_size := 12
	var legend_width := 168.0
	var chart_area := minf(size.y - 8.0, size.x - legend_width - 16.0)
	chart_area = maxf(chart_area, CHART_MIN * 0.5)
	var center := Vector2(chart_area * 0.5 + 8.0, size.y * 0.5)
	var outer_r := chart_area * 0.45
	var inner_r := outer_r * (1.0 - DONUT_THICKNESS_RATIO)

	var start_angle := -PI * 0.5
	for cat in PDFrameTimeBreakdown.CATEGORY_ORDER:
		var pct := float(_pct.get(cat, 0.0))
		if pct <= 0.001:
			continue
		var sweep := pct * TAU
		var color: Color = PDFrameTimeBreakdown.CATEGORY_COLORS.get(cat, Color.GRAY)
		_draw_donut_slice(center, inner_r, outer_r, start_angle, start_angle + sweep, color)
		start_angle += sweep

	# Center label
	var center_label := "%.1f ms" % _total_ms
	var label_size := _font.get_string_size(center_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2)
	draw_string(
		_font,
		center - Vector2(label_size.x * 0.5, -4.0),
		center_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size + 2,
		PDDashboardStyle.TEXT_PRIMARY
	)
	var sub := "frame"
	var sub_size := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1)
	draw_string(
		_font,
		center - Vector2(sub_size.x * 0.5, -18.0),
		sub,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size - 1,
		PDDashboardStyle.TEXT_MUTED
	)

	# Legend
	var lx := center.x + outer_r + 18.0
	var ly := 12.0
	for cat in PDFrameTimeBreakdown.CATEGORY_ORDER:
		var pct := float(_pct.get(cat, 0.0))
		var ms := float(_ms.get(cat, 0.0))
		if pct <= 0.001 and ms <= 0.01:
			continue
		var color: Color = PDFrameTimeBreakdown.CATEGORY_COLORS.get(cat, Color.GRAY)
		draw_rect(Rect2(lx, ly + 3.0, 10.0, 10.0), color)
		var label: String = PDFrameTimeBreakdown.CATEGORY_LABELS.get(cat, String(cat))
		var text := "%s  %.0f%%  (%.2f ms)" % [label, pct * 100.0, ms]
		draw_string(
			_font,
			Vector2(lx + 16.0, ly + 13.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			legend_width,
			font_size - 1,
			PDDashboardStyle.TEXT_PRIMARY
		)
		ly += LEGEND_ROW


func _draw_donut_slice(
	center: Vector2,
	inner_r: float,
	outer_r: float,
	from_angle: float,
	to_angle: float,
	color: Color
) -> void:
	# Approximate arc with a reused point buffer.
	var steps := maxi(int(ceili(absf(to_angle - from_angle) / 0.12)), 3)
	var count := (steps + 1) * 2
	if _slice_points.size() != count:
		_slice_points.resize(count)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var angle := lerpf(from_angle, to_angle, t)
		var ca := cos(angle)
		var sa := sin(angle)
		_slice_points[i] = center + Vector2(ca, sa) * outer_r
		_slice_points[count - 1 - i] = center + Vector2(ca, sa) * inner_r
	draw_colored_polygon(_slice_points, color)
