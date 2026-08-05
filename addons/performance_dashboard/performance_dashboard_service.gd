extends Node

## Autoload entry point for the Performance Dashboard.
##
## Layers of gating:
## 1. Release exports — OS.is_debug_build() is false → fully inert.
## 2. Master arm switch — ProjectSettings + Shift+Ctrl+O / Tools menu.
## 3. Overlay visibility — Shift+O (only while armed); sampling only while visible.

const ProfilerScript = preload("res://addons/performance_dashboard/core/performance_profiler.gd")
const UIScript = preload("res://addons/performance_dashboard/ui/performance_profiler_ui.gd")

signal tool_armed_changed(is_armed: bool)

var profiler: PerformanceProfiler
var ui: PerformanceProfilerUI

## True only in debug builds (tool may exist at all).
var _debug_available: bool = false
## True when the tool is armed and Shift+O can open the dashboard.
var _armed: bool = false
## True once profiler/UI children have been constructed (lazy).
var _bootstrapped: bool = false


func _enter_tree() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_debug_available = true


func _ready() -> void:
	if not _debug_available:
		return

	_ensure_project_setting()
	set_process_unhandled_input(true)

	# Start from the persistent project setting (Tools menu / Project Settings).
	var start_armed := bool(ProjectSettings.get_setting(
		PDDashboardStyle.SETTING_ENABLED,
		PDDashboardStyle.SETTING_ENABLED_DEFAULT
	))
	set_tool_enabled(start_armed, false)


func _unhandled_input(event: InputEvent) -> void:
	if not _debug_available:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey

	# Master arm / disarm for this play session.
	if key_event.keycode == PDDashboardStyle.ARM_KEY and key_event.shift_pressed and key_event.ctrl_pressed:
		set_tool_enabled(not _armed, false)
		_notify_arm_state()
		get_viewport().set_input_as_handled()
		return

	# Overlay toggle — only while armed.
	if not _armed or ui == null:
		return
	if key_event.keycode == PDDashboardStyle.TOGGLE_KEY and key_event.shift_pressed and not key_event.ctrl_pressed:
		ui.toggle_dashboard()
		get_viewport().set_input_as_handled()


func _on_ui_visibility_toggled(is_visible: bool) -> void:
	if profiler:
		profiler.set_active(is_visible and _armed)


## Arms or disarms the tool. When disarmed: no Shift+O, no sampling, UI hidden.
## If persist is true, also writes ProjectSettings (and saves when running in the editor).
func set_tool_enabled(enabled: bool, persist: bool = true) -> void:
	if not _debug_available:
		return

	if enabled == _armed:
		if persist:
			_write_setting(enabled)
		return

	_armed = enabled

	if _armed:
		_bootstrap_if_needed()
	else:
		_shutdown_runtime()

	if persist:
		_write_setting(enabled)

	tool_armed_changed.emit(_armed)


func is_tool_enabled() -> bool:
	return _armed


func is_available() -> bool:
	return _debug_available


func show_dashboard() -> void:
	if not _armed:
		return
	_bootstrap_if_needed()
	if ui:
		ui.set_dashboard_visible(true)


func hide_dashboard() -> void:
	if ui:
		ui.set_dashboard_visible(false)


func get_profiler() -> PerformanceProfiler:
	return profiler


func _bootstrap_if_needed() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true

	profiler = ProfilerScript.new()
	profiler.name = "PerformanceProfiler"
	add_child(profiler)

	ui = UIScript.new()
	ui.name = "PerformanceProfilerUI"
	add_child(ui)
	ui.bind_profiler(profiler)
	ui.set_profiles(PDProfileCatalog.create_builtin_profiles(), PDProfileCatalog.PROFILE_DESKTOP)
	ui.visibility_toggled.connect(_on_ui_visibility_toggled)

	profiler.set_active(false)
	ui.set_dashboard_visible(false)


func _shutdown_runtime() -> void:
	if ui:
		ui.set_dashboard_visible(false)
	if profiler:
		profiler.set_active(false)


func _ensure_project_setting() -> void:
	if not ProjectSettings.has_setting(PDDashboardStyle.SETTING_ENABLED):
		ProjectSettings.set_setting(
			PDDashboardStyle.SETTING_ENABLED,
			PDDashboardStyle.SETTING_ENABLED_DEFAULT
		)
	ProjectSettings.set_initial_value(
		PDDashboardStyle.SETTING_ENABLED,
		PDDashboardStyle.SETTING_ENABLED_DEFAULT
	)


func _write_setting(enabled: bool) -> void:
	ProjectSettings.set_setting(PDDashboardStyle.SETTING_ENABLED, enabled)
	# Persist between runs when changed from the editor Tools menu.
	if Engine.is_editor_hint():
		ProjectSettings.save()


func _notify_arm_state() -> void:
	if _armed:
		print("[PerformanceDashboard] Armed — Shift+O opens the overlay. Shift+Ctrl+O disarms.")
	else:
		print("[PerformanceDashboard] Disarmed — overlay inaccessible until re-armed (Shift+Ctrl+O).")
