extends Node

## Autoload entry point for the Performance Dashboard.
##
## When ProjectSettings `performance_dashboard/enabled` is false, this node
## disables itself immediately and never builds profiler/UI or handles hotkeys.
## Prefer removing the autoload entirely via Tools → Performance Dashboard.

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
	if not OS.is_debug_build() or not _is_master_enabled():
		_fully_disable()
		return
	_debug_available = true


func _ready() -> void:
	if not _debug_available:
		return

	_ensure_project_setting()
	# Re-check after settings are ready — stay fully off when disabled.
	if not _is_master_enabled():
		_fully_disable()
		print("[PerformanceDashboard] Disabled — not loaded. Enable via Project → Tools → Performance Dashboard.")
		return

	set_process_unhandled_input(true)
	set_tool_enabled(true, false)
	print("[PerformanceDashboard] Armed — Shift+O opens the overlay. Shift+Ctrl+O disarms for this session.")


func _unhandled_input(event: InputEvent) -> void:
	if not _debug_available or not _is_master_enabled():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key_event := event as InputEventKey

	# Session arm / disarm — only while the master project setting is on.
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
	if not _debug_available and enabled:
		return
	# Master project switch off → never arm, tear down if needed.
	if enabled and not _is_master_enabled():
		enabled = false

	if enabled == _armed:
		if persist:
			_write_setting(enabled)
		return

	_armed = enabled

	if _armed:
		_bootstrap_if_needed()
		set_process_unhandled_input(true)
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_shutdown_runtime()

	if persist:
		_write_setting(enabled)

	tool_armed_changed.emit(_armed)


func is_tool_enabled() -> bool:
	return _armed and _is_master_enabled()


func is_available() -> bool:
	return _debug_available and _is_master_enabled()


func show_dashboard() -> void:
	if not _armed or not _is_master_enabled():
		return
	_bootstrap_if_needed()
	if ui:
		ui.set_dashboard_visible(true)


func hide_dashboard() -> void:
	if ui:
		ui.set_dashboard_visible(false)


func get_profiler() -> PerformanceProfiler:
	return profiler


func _is_master_enabled() -> bool:
	return bool(ProjectSettings.get_setting(
		PDDashboardStyle.SETTING_ENABLED,
		PDDashboardStyle.SETTING_ENABLED_DEFAULT
	))


func _fully_disable() -> void:
	_debug_available = false
	_armed = false
	_shutdown_runtime()
	if is_instance_valid(profiler):
		profiler.queue_free()
		profiler = null
	if is_instance_valid(ui):
		ui.queue_free()
		ui = null
	_bootstrapped = false
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	process_mode = Node.PROCESS_MODE_DISABLED


func _bootstrap_if_needed() -> void:
	if _bootstrapped or not _is_master_enabled():
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
