class_name PerformanceProfilerUI
extends CanvasLayer

## Visual layer for the performance dashboard.
## Reads data from a PerformanceProfiler — never collects metrics itself.

signal visibility_toggled(is_visible: bool)
signal profile_changed(profile: PerformanceTargetProfile)

const UPDATE_INTERVAL := 1.0 / PDDashboardStyle.UI_UPDATE_HZ

var profiler: PerformanceProfiler
var profiles: Array[PerformanceTargetProfile] = []
var current_profile: PerformanceTargetProfile

var _root_panel: PanelContainer
var _title_label: Label
var _fps_label: Label
var _frame_label: Label
var _device_label: Label
var _profile_option: OptionButton
var _bar_chart: PDMetricBarChart
var _donut: PDFrameBreakdownDonut
var _summary_label: RichTextLabel
var _hint_label: Label
var _metric_hint_label: Label

var _update_left: float = 0.0
var _built: bool = false
var _dashboard_visible: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visible = false
	_build_ui()


func bind_profiler(p: PerformanceProfiler) -> void:
	profiler = p
	if _bar_chart and profiler:
		_bar_chart.setup(profiler.get_registry().get_bar_chart_definitions())


func set_profiles(list: Array[PerformanceTargetProfile], select_id: StringName = &"desktop") -> void:
	profiles = list
	_profile_option.clear()
	var select_index := 0
	for i in profiles.size():
		_profile_option.add_item(profiles[i].display_name, i)
		if profiles[i].profile_id == select_id:
			select_index = i
	_profile_option.select(select_index)
	_apply_profile(profiles[select_index])


func is_dashboard_visible() -> bool:
	return _dashboard_visible


func set_dashboard_visible(show: bool) -> void:
	if _dashboard_visible == show:
		return
	_dashboard_visible = show
	visible = show
	set_process(show)
	if show:
		_update_left = 0.0
		_refresh_ui()
	visibility_toggled.emit(show)


func toggle_dashboard() -> void:
	set_dashboard_visible(not _dashboard_visible)


func _process(delta: float) -> void:
	if not _dashboard_visible or profiler == null:
		return
	_update_left -= delta
	if _update_left > 0.0:
		return
	_update_left = UPDATE_INTERVAL
	_refresh_ui()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_root_panel = PanelContainer.new()
	_root_panel.name = "RootPanel"
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.offset_left = -460
	_root_panel.offset_right = 460
	_root_panel.offset_top = -340
	_root_panel.offset_bottom = 340
	_root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_root_panel)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = PDDashboardStyle.PANEL_BG
	panel_sb.border_color = PDDashboardStyle.PANEL_BORDER
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(6)
	panel_sb.content_margin_left = 14
	panel_sb.content_margin_right = 14
	panel_sb.content_margin_top = 12
	panel_sb.content_margin_bottom = 12
	_root_panel.add_theme_stylebox_override("panel", panel_sb)

	var margin := MarginContainer.new()
	_root_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	# Header
	var header := HBoxContainer.new()
	outer.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Performance Dashboard"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_PRIMARY)
	header.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.text = "Shift+O to hide"
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_MUTED)
	header.add_child(_hint_label)

	# FPS / Frame time strip
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 24)
	outer.add_child(stats_row)

	_fps_label = Label.new()
	_fps_label.text = "FPS  --"
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_color_override("font_color", PDDashboardStyle.ACCENT)
	stats_row.add_child(_fps_label)

	_frame_label = Label.new()
	_frame_label.text = "Frame  -- ms"
	_frame_label.add_theme_font_size_override("font_size", 16)
	_frame_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_PRIMARY)
	stats_row.add_child(_frame_label)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	outer.add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "Mode:"
	mode_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_MUTED)
	mode_row.add_child(mode_label)

	_profile_option = OptionButton.new()
	_profile_option.custom_minimum_size = Vector2(280, 0)
	_profile_option.item_selected.connect(_on_profile_selected)
	mode_row.add_child(_profile_option)

	_device_label = Label.new()
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_label.add_theme_font_size_override("font_size", 11)
	_device_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_MUTED)
	outer.add_child(_device_label)

	outer.add_child(_make_section_header("Metric vs Target"))

	var legend := Label.new()
	legend.text = "Top bar = current   ·   Bottom bar = profile target   ·   Green / Yellow / Red = headroom"
	legend.add_theme_font_size_override("font_size", 10)
	legend.add_theme_color_override("font_color", PDDashboardStyle.TEXT_MUTED)
	outer.add_child(legend)

	var bar_scroll := ScrollContainer.new()
	bar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_scroll.custom_minimum_size = Vector2(0, 260)
	bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(bar_scroll)

	_bar_chart = PDMetricBarChart.new()
	_bar_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_chart.metric_hovered.connect(_on_metric_hovered)
	bar_scroll.add_child(_bar_chart)

	_metric_hint_label = Label.new()
	_metric_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metric_hint_label.add_theme_font_size_override("font_size", 10)
	_metric_hint_label.add_theme_color_override("font_color", PDDashboardStyle.TEXT_MUTED)
	_metric_hint_label.text = "Hover a metric for details."
	outer.add_child(_metric_hint_label)

	outer.add_child(_make_section_header("Frame Time Breakdown (estimated)"))

	_donut = PDFrameBreakdownDonut.new()
	_donut.custom_minimum_size = Vector2(0, 200)
	_donut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_donut)

	outer.add_child(_make_section_header("Summary"))

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.scroll_active = false
	_summary_label.custom_minimum_size = Vector2(0, 72)
	_summary_label.add_theme_color_override("default_color", PDDashboardStyle.TEXT_PRIMARY)
	outer.add_child(_summary_label)


func _make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", PDDashboardStyle.ACCENT)
	return label


func _on_profile_selected(index: int) -> void:
	if index < 0 or index >= profiles.size():
		return
	_apply_profile(profiles[index])


func _apply_profile(profile: PerformanceTargetProfile) -> void:
	current_profile = profile
	if _bar_chart:
		_bar_chart.set_profile(profile)
	profile_changed.emit(profile)
	if _dashboard_visible:
		_refresh_ui()


func _on_metric_hovered(metric_id: StringName) -> void:
	if profiler == null:
		return
	var def := profiler.get_registry().get_definition(metric_id)
	if def == null:
		return
	var exact := "exact" if def.is_exact else "estimated"
	_metric_hint_label.text = "%s (%s): %s" % [def.display_name, exact, def.description]


func _refresh_ui() -> void:
	if profiler == null or current_profile == null:
		return

	var metrics := profiler.get_all_metrics()
	var fps := float(metrics.get(PDMetricIds.FPS, 0.0))
	var frame_ms := float(metrics.get(PDMetricIds.FRAME_TIME_MS, 0.0))

	_fps_label.text = "FPS  %.0f" % fps
	_fps_label.add_theme_color_override(
		"font_color",
		PDDashboardStyle.status_color(fps, current_profile.get_target(PDMetricIds.FPS, 60.0), true)
	)
	_frame_label.text = "Frame  %.2f ms" % frame_ms
	_device_label.text = profiler.get_device_info_text()

	_bar_chart.set_metrics(metrics)
	_donut.set_breakdown(profiler.get_breakdown())
	_update_summary(metrics)


func _update_summary(metrics: Dictionary) -> void:
	var exceeding: PackedStringArray = []
	var warning: PackedStringArray = []

	for def in profiler.get_registry().get_bar_chart_definitions():
		var current := float(metrics.get(def.id, 0.0))
		var target := current_profile.get_target(def.id, 0.0)
		if target <= 0.0:
			continue
		if PDDashboardStyle.is_exceeding(current, target, def.higher_is_better):
			exceeding.append(def.display_name)
		else:
			var color := PDDashboardStyle.status_color(current, target, def.higher_is_better)
			if color == PDDashboardStyle.STATUS_WARN:
				warning.append(def.display_name)

	var parts: PackedStringArray = []
	if exceeding.is_empty() and warning.is_empty():
		parts.append("[color=#4dc785]All tracked metrics within profile targets.[/color]")
	else:
		if not exceeding.is_empty():
			parts.append("[color=#e65a5a]Exceeding:[/color] %s" % ", ".join(exceeding))
		if not warning.is_empty():
			parts.append("[color=#ebc247]Approaching:[/color] %s" % ", ".join(warning))

	var note := "\n[color=#9aa3ad]Donut categories other than Physics/Navigation are estimated — see docs/LIMITATIONS.md[/color]"
	_summary_label.text = "\n".join(parts) + note
