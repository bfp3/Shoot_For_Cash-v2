@tool
extends EditorPlugin

## Editor integration: registers the autoload, Project Setting, and a Tools menu toggle.

const AUTOLOAD_NAME := "PerformanceDashboard"
const AUTOLOAD_PATH := "res://addons/performance_dashboard/performance_dashboard_service.gd"
const SETTING := "performance_dashboard/enabled"
const SETTING_DEFAULT := true

var _menu_item_name: String = ""


func _enter_tree() -> void:
	_ensure_autoload()
	_ensure_setting()
	_refresh_tools_menu()


func _exit_tree() -> void:
	_clear_tools_menu()


func _ensure_autoload() -> void:
	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


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
	_refresh_tools_menu()

	var note := "ON (armed at next play — Shift+O)" if enabled else "OFF (inert at next play)"
	print("[PerformanceDashboard] Master switch → %s. Use Shift+Ctrl+O during play to arm/disarm the session." % note)

	# If a game is currently running with the autoload, update it live when possible.
	var tree := get_tree()
	if tree:
		var service := tree.root.get_node_or_null(AUTOLOAD_NAME)
		if service and service.has_method("set_tool_enabled"):
			service.call("set_tool_enabled", enabled, false)
