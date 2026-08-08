@tool
extends EditorPlugin

## Editor integration: registers the autoload only when enabled, Project Setting, and Tools menu toggle.

const AUTOLOAD_NAME := "PerformanceDashboard"
const AUTOLOAD_PATH := "res://addons/performance_dashboard/performance_dashboard_service.gd"
const SETTING := "performance_dashboard/enabled"
const SETTING_DEFAULT := false

var _menu_item_name: String = ""


func _enter_tree() -> void:
	_ensure_setting()
	_sync_autoload_to_setting()
	_refresh_tools_menu()


func _exit_tree() -> void:
	_clear_tools_menu()


func _ensure_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, SETTING_DEFAULT)
	ProjectSettings.set_initial_value(SETTING, SETTING_DEFAULT)
	ProjectSettings.add_property_info({
		"name": SETTING,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
	})
	# Show under Project Settings → General (basic view).
	if ProjectSettings.has_method("set_as_basic"):
		ProjectSettings.set_as_basic(SETTING, true)


func _sync_autoload_to_setting() -> void:
	var enabled := bool(ProjectSettings.get_setting(SETTING, SETTING_DEFAULT))
	var has_autoload := ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME)
	if enabled and not has_autoload:
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	elif not enabled and has_autoload:
		remove_autoload_singleton(AUTOLOAD_NAME)


func _refresh_tools_menu() -> void:
	_clear_tools_menu()
	var enabled := bool(ProjectSettings.get_setting(SETTING, SETTING_DEFAULT))
	_menu_item_name = "Performance Dashboard: %s" % ("On" if enabled else "Off")
	add_tool_menu_item(_menu_item_name, _on_tools_menu_pressed)


func _clear_tools_menu() -> void:
	if not _menu_item_name.is_empty():
		remove_tool_menu_item(_menu_item_name)
		_menu_item_name = ""


func _on_tools_menu_pressed() -> void:
	var enabled := not bool(ProjectSettings.get_setting(SETTING, SETTING_DEFAULT))
	ProjectSettings.set_setting(SETTING, enabled)
	ProjectSettings.save()
	_sync_autoload_to_setting()
	_refresh_tools_menu()

	var note := "ON (autoload added — restart play to use Shift+O)" if enabled else "OFF (autoload removed — not loaded)"
	print("[PerformanceDashboard] Master switch → %s." % note)

	# If a game is currently running with the autoload, update it live when possible.
	var tree := get_tree()
	if tree:
		var service := tree.root.get_node_or_null(AUTOLOAD_NAME)
		if service == null:
			return
		if enabled and service.has_method("set_tool_enabled"):
			service.call("set_tool_enabled", true, false)
		elif not enabled and service.has_method("_fully_disable"):
			service.call("_fully_disable")
		elif not enabled and service.has_method("set_tool_enabled"):
			service.call("set_tool_enabled", false, false)
