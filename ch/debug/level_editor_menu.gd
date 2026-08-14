extends Control
## Debug level editor: type island-shipper commands, TEST one round, return here with text preserved.

const FONT_PATH := "res://res/marlbo.ttf"
const COLOR_CREAM := Color("EBE0D8")
const COLOR_CREAM_PANEL := Color(0.92156863, 0.8784314, 0.84705883, 1)
const COLOR_RED := Color("C70102")
const COLOR_INK := Color(0.12, 0.08, 0.06, 1)

## Keywords inserted by the right-hand command panel (one per button).
const COMMAND_BUTTONS: PackedStringArray = [
	"rock",
	"rock-black",
	"rock-pigeon",
	"rock-avoider",
	"rock-chaser",
	"smokecan",
	"pineapple",
	"balloon",
	"wait",
	"repeat",
	"shuffle",
	"no-lives",
	"surprise-me",
	"bonus-type1",
	"bonus-target",
]

@export var round_manager: RoundManager
@export var shop_main_menu: Control

var _font: Font
var _is_open := false
var _busy := false
var _waiting_to_focus := false

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _rules_panel: PanelContainer = %RulesPanel
@onready var _rules_list: RichTextLabel = %RulesList
@onready var _keys_panel: PanelContainer = %KeysPanel
@onready var _keys_list: RichTextLabel = %KeysList
@onready var _commands_panel: PanelContainer = %CommandsPanel
@onready var _commands_vbox: VBoxContainer = %CommandsVBox
@onready var _script_edit: TextEdit = %ScriptEdit
@onready var _test_button: Button = %TestButton
@onready var _back_button: Button = %BackButton
@onready var _title_label: RichTextLabel = %TitleLabel


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	_font = load(FONT_PATH)
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	set_process_unhandled_input(true)

	_build_command_buttons()
	_apply_styles()
	_keys_panel.hide()
	_rules_panel.hide()
	_test_button.pressed.connect(_on_test_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_script_edit.gui_input.connect(_on_script_gui_input)

	if round_manager == null:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if shop_main_menu == null:
		shop_main_menu = get_tree().get_first_node_in_group("shop_main_menu") as Control

	if round_manager and round_manager.has_method("register_level_editor"):
		round_manager.register_level_editor(self)


func is_open() -> bool:
	return _is_open


func get_script_text() -> String:
	return _script_edit.text if _script_edit else ""


func open_menu() -> void:
	if not RoundManager.ENABLE_LEVEL_EDITOR:
		## Publish builds: editor entry is disabled (see RoundManager.ENABLE_LEVEL_EDITOR).
		return
	if not OS.is_debug_build():
		return
	if _busy:
		return
	_is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	# Wait for the open key to release before focusing, so it isn't typed in.
	_script_edit.release_focus()
	_focus_script_edit_after_open_key()


func _focus_script_edit_after_open_key() -> void:
	if _waiting_to_focus:
		return
	_waiting_to_focus = true
	# Hold until toggle keys are released (Shift+K / Shift+D).
	while _is_open and (
		Input.is_action_pressed("toggle_key_editor")
		or Input.is_action_pressed("toggle_level_editor")
	):
		await get_tree().process_frame
	_waiting_to_focus = false
	if _is_open:
		_focus_script_edit()


func _focus_script_edit() -> void:
	_script_edit.grab_focus()
	# Place caret at end so returning from a test feels continuous.
	_script_edit.set_caret_line(_script_edit.get_line_count() - 1)
	_script_edit.set_caret_column(_script_edit.get_line(_script_edit.get_line_count() - 1).length())


func close_menu() -> void:
	_is_open = false
	_waiting_to_focus = false
	_keys_panel.hide()
	_rules_panel.hide()
	hide()


func toggle_keys_panel() -> void:
	if not _is_open:
		return
	var show_help := not _keys_panel.visible
	_keys_panel.visible = show_help
	_rules_panel.visible = show_help


func _build_command_buttons() -> void:
	if _commands_vbox == null:
		return
	for child in _commands_vbox.get_children():
		child.queue_free()

	for command in COMMAND_BUTTONS:
		var button := Button.new()
		button.text = command
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_command_button_pressed.bind(command))
		_commands_vbox.add_child(button)


## Insert `command` on a new line directly below the caret's current line.
func _on_command_button_pressed(command: String) -> void:
	if not _is_open or _script_edit == null:
		return

	var caret_line := _script_edit.get_caret_line()
	var insert_line := caret_line + 1
	var line_count := _script_edit.get_line_count()

	# Empty editor — just place the command as the first line.
	if _script_edit.text.strip_edges() == "" and line_count <= 1 and _script_edit.get_line(0) == "":
		_script_edit.text = command
		_script_edit.set_caret_line(0)
		_script_edit.set_caret_column(command.length())
	elif insert_line >= line_count:
		# insert_line_at only accepts line < line_count, so append after the last line.
		var last_line := line_count - 1
		var last_col := _script_edit.get_line(last_line).length()
		_script_edit.insert_text("\n" + command, last_line, last_col)
		_script_edit.set_caret_line(last_line + 1)
		_script_edit.set_caret_column(command.length())
	else:
		_script_edit.insert_line_at(insert_line, command)
		_script_edit.set_caret_line(insert_line)
		_script_edit.set_caret_column(command.length())

	_script_edit.grab_focus()


func _apply_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_CREAM_PANEL
	panel_style.set_border_width_all(3)
	panel_style.border_color = COLOR_RED
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 16
	_main_panel.add_theme_stylebox_override("panel", panel_style)
	_keys_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_rules_panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	_commands_panel.add_theme_stylebox_override("panel", panel_style.duplicate())

	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = COLOR_CREAM
	edit_style.set_border_width_all(2)
	edit_style.border_color = Color(0.58, 0.0058, 0.0154, 1)
	edit_style.set_corner_radius_all(4)
	edit_style.content_margin_left = 10
	edit_style.content_margin_top = 8
	edit_style.content_margin_right = 10
	edit_style.content_margin_bottom = 8
	_script_edit.add_theme_stylebox_override("normal", edit_style)
	_script_edit.add_theme_stylebox_override("focus", edit_style)
	_script_edit.add_theme_color_override("font_color", COLOR_INK)
	_script_edit.add_theme_color_override("caret_color", COLOR_RED)
	if _font:
		_script_edit.add_theme_font_override("font", _font)
		#_script_edit.add_theme_font_size_override("font_size", 22)
		_title_label.add_theme_font_override("font", _font)
		_test_button.add_theme_font_override("font", _font)
		_back_button.add_theme_font_override("font", _font)
		_keys_list.add_theme_font_override("normal_font", _font)
		_keys_list.add_theme_font_size_override("normal_font_size", 18)
		_rules_list.add_theme_font_override("normal_font", _font)
		_rules_list.add_theme_font_size_override("normal_font_size", 16)

	_title_label.add_theme_color_override("font_color", COLOR_CREAM)
	_title_label.add_theme_font_size_override("font_size", 36)

	_style_action_button(_test_button, true)
	_style_action_button(_back_button, false)
	_style_command_buttons()


func _style_command_buttons() -> void:
	if _commands_vbox == null:
		return
	for child in _commands_vbox.get_children():
		if child is Button:
			_style_command_button(child)


func _style_command_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_CREAM
	normal.set_border_width_all(2)
	normal.border_color = COLOR_RED
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_top = 8
	normal.content_margin_right = 10
	normal.content_margin_bottom = 8

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.95, 0.9, 0.86, 1)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_RED)
	button.add_theme_color_override("font_hover_color", COLOR_RED)
	button.add_theme_font_size_override("font_size", 30)
	if _font:
		button.add_theme_font_override("font", _font)


func _style_action_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_RED if primary else COLOR_CREAM
	normal.set_border_width_all(2)
	normal.border_color = COLOR_RED
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 18
	normal.content_margin_top = 10
	normal.content_margin_right = 18
	normal.content_margin_bottom = 10

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.85, 0.02, 0.03, 1) if primary else Color(0.95, 0.9, 0.86, 1)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_CREAM if primary else COLOR_RED)
	button.add_theme_color_override("font_hover_color", COLOR_CREAM if primary else COLOR_RED)
	button.add_theme_font_size_override("font_size", 28)


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not _is_open:
		return
	# While open, Shift+K toggles the keys help panel (does not close the editor).
	if event.is_action_pressed("toggle_key_editor") and not event.is_echo():
		toggle_keys_panel()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _is_open and event.shift_pressed:
				_on_test_pressed()
				get_viewport().set_input_as_handled()


func _on_script_gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Block Shift+K from typing into the script while the action toggles help.
		if event.shift_pressed and (event.keycode == KEY_K or event.physical_keycode == KEY_K):
			_script_edit.accept_event()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not event.shift_pressed:
				# Enter inserts a newline (default TextEdit behaviour).
				return
			_on_test_pressed()
			_script_edit.accept_event()


func _on_test_pressed() -> void:
	if not _is_open or _busy:
		return
	_busy = true

	if round_manager == null:
		push_warning("Level editor: round_manager missing")
		_busy = false
		return

	var text := _script_edit.text
	print("========== LEVEL EDITOR TEST ==========")
	print("island test")
	print("range test")
	print("round")
	print(text)
	print("=======================================")

	close_menu()
	await round_manager.begin_level_editor_test(text)
	_busy = false


func _on_back_pressed() -> void:
	if not _is_open or _busy:
		return
	_busy = true
	close_menu()
	if round_manager and round_manager.has_method("exit_level_editor_to_shop"):
		round_manager.exit_level_editor_to_shop()
	elif shop_main_menu and shop_main_menu.has_method("soft_show_from_level_editor"):
		shop_main_menu.soft_show_from_level_editor()
	_busy = false
