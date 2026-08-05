class_name PDMetricDefinition
extends RefCounted

## Metadata for a single optimisation metric.
## The profiler stores values; this class describes how to display and compare them.

var id: StringName
var display_name: String
var unit: String
var higher_is_better: bool = false
var description: String = ""
## true = value comes from an engine monitor; false = estimated / scene walk.
var is_exact: bool = true
## Include in the dual-bar optimisation chart.
var show_in_bar_chart: bool = true


func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_unit: String = "",
	p_higher_is_better: bool = false,
	p_description: String = "",
	p_is_exact: bool = true,
	p_show_in_bar_chart: bool = true
) -> void:
	id = p_id
	display_name = p_display_name
	unit = p_unit
	higher_is_better = p_higher_is_better
	description = p_description
	is_exact = p_is_exact
	show_in_bar_chart = p_show_in_bar_chart


func format_value(value: float) -> String:
	if unit == "ms":
		return "%.2f ms" % value
	if unit == "MB":
		return "%.1f MB" % value
	if unit == "fps":
		return "%.0f" % value
	if absf(value) >= 1000.0:
		return "%s" % _format_compact(value)
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.2f" % value


func _format_compact(value: float) -> String:
	var abs_v := absf(value)
	if abs_v >= 1_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if abs_v >= 1_000.0:
		return "%.1fK" % (value / 1_000.0)
	return "%.0f" % value
