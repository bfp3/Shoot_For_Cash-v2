extends Control
## Round Editor: edit level-beginner.txt rounds in-game (Godot editor builds only).

const FONT_PATH := "res://res/marlbo.ttf"
const COLOR_CREAM := Color("EBE0D8")
const COLOR_CREAM_PANEL := Color(0.92156863, 0.8784314, 0.84705883, 1)
const COLOR_RED := Color("C70102")
const COLOR_INK := Color(0.12, 0.08, 0.06, 1)
const COLOR_TAB_IDLE := Color(0.85, 0.78, 0.72, 1)

@export var round_manager: RoundManager
@export var shop_main_menu: Control

var _font: Font
var _is_open := false
var _busy := false
var _waiting_to_focus := false
var _suppress_text_signal := false

var _current_range := ""
var _current_round := 1
## "range|round" -> draft text (unsaved edits persist while switching).
var _drafts: Dictionary = {}
## "range|round" -> last saved / loaded baseline text.
var _baselines: Dictionary = {}

var _range_tab_buttons: Array[Button] = []
var _round_buttons: Array[Button] = []

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _rounds_panel: PanelContainer = %RoundsPanel
@onready var _rounds_vbox: VBoxContainer = %RoundsVBox
@onready var _tabs_hbox: HBoxContainer = %RangeTabs
@onready var _script_edit: TextEdit = %ScriptEdit
@onready var _title_label: RichTextLabel = %TitleLabel
@onready var _hint_label: RichTextLabel = %HintLabel
@onready var _save_button: Button = %SaveButton
@onready var _test_button: Button = %TestButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	if not RoundManager.is_level_editor_available():
		queue_free()
		return

	_font = load(FONT_PATH)
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(true)

	_apply_styles()
	_save_button.disabled = true
	_save_button.pressed.connect(_on_save_pressed)
	_test_button.pressed.connect(_on_test_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_script_edit.text_changed.connect(_on_script_text_changed)
	_script_edit.gui_input.connect(_on_script_gui_input)

	if round_manager == null:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if shop_main_menu == null:
		shop_main_menu = get_tree().get_first_node_in_group("shop_main_menu") as Control

	if round_manager and round_manager.has_method("register_round_editor"):
		round_manager.register_round_editor(self)


func is_open() -> bool:
	return _is_open


func open_menu() -> void:
	if not RoundManager.is_level_editor_available():
		return
	if _busy:
		return
	if round_manager == null:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if round_manager == null:
		push_warning("Round editor: round_manager missing")
		return

	var file_path := _level_file_path()
	var start_range := String(round_manager.get_active_range_name()).to_lower()
	if start_range.is_empty() or start_range == "start":
		push_warning("Round editor: enter a shooting range first")
		return
	if not Parser.file_has_range(file_path, start_range):
		push_warning("Round editor: range '%s' not in %s" % [start_range, file_path])
		return

	_is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_rebuild_range_tabs(start_range)
	_select_range(start_range, false)
	_script_edit.release_focus()
	_focus_script_edit_after_open_key()


func close_menu() -> void:
	_stash_current_draft()
	_is_open = false
	hide()


func _level_file_path() -> String:
	if round_manager and "LEVEL_FILE_PATH" in round_manager:
		return String(round_manager.LEVEL_FILE_PATH)
	return "res://sc/level-beginner.txt"


func _draft_key(range_name: String, round_no: int) -> String:
	return "%s|%d" % [range_name.to_lower(), round_no]


func _focus_script_edit_after_open_key() -> void:
	if _waiting_to_focus:
		return
	_waiting_to_focus = true
	while _is_open and Input.is_action_pressed("toggle_round_editor"):
		await get_tree().process_frame
	_waiting_to_focus = false
	if _is_open:
		_script_edit.grab_focus()


func _rebuild_range_tabs(prefer_range: String) -> void:
	for child in _tabs_hbox.get_children():
		child.queue_free()
	_range_tab_buttons.clear()

	var ranges := Parser.list_ranges_in_file(_level_file_path())
	if ranges.is_empty():
		return
	for range_name in ranges:
		var btn := Button.new()
		btn.text = String(range_name).to_upper()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tab_button(btn)
		var captured := String(range_name).to_lower()
		btn.pressed.connect(func(): _on_range_tab_pressed(captured))
		btn.gui_input.connect(_on_range_tab_gui_input.bind(captured))
		_tabs_hbox.add_child(btn)
		_range_tab_buttons.append(btn)

	if prefer_range.is_empty() or not ranges.has(prefer_range):
		prefer_range = String(ranges[0]).to_lower()
	_highlight_range_tab(prefer_range)


func _on_range_tab_pressed(range_name: String) -> void:
	if range_name == _current_range:
		_highlight_range_tab(range_name)
		return
	_select_range(range_name, true)


func _on_range_tab_gui_input(event: InputEvent, range_name: String) -> void:
	if not _is_open or _busy:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or not mouse.double_click:
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_fast_travel_to_range(range_name)


func _fast_travel_to_range(range_name: String) -> void:
	if not _is_open or _busy:
		return
	range_name = range_name.to_lower()
	if range_name != _current_range:
		_select_range(range_name, true)
	if round_manager == null:
		round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if round_manager == null:
		push_warning("Round editor: round_manager missing")
		return
	_busy = true
	print("Round editor: fast travel → %s" % range_name)
	if round_manager.has_method("debug_editor_travel_to_range"):
		await round_manager.debug_editor_travel_to_range(range_name)
	elif round_manager.has_method("travel_to_level"):
		await round_manager.travel_to_level(range_name, false)
	keep_open_after_travel()
	_busy = false


func keep_open_after_travel() -> void:
	_is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_script_edit.release_focus()
	_focus_script_edit_after_open_key()


func _select_range(range_name: String, stash: bool) -> void:
	if stash:
		_stash_current_draft()
	_current_range = range_name.to_lower()
	_highlight_range_tab(_current_range)
	_rebuild_round_buttons()
	var count := Parser.count_rounds_in_file(_level_file_path(), _current_range)
	var target := clampi(_current_round, 1, maxi(count, 1))
	_select_round(target, false)
	_title_label.text = "ROUND EDITOR — %s" % _current_range.to_upper()


func _highlight_range_tab(range_name: String) -> void:
	for btn in _range_tab_buttons:
		var active := String(btn.text).to_lower() == range_name.to_lower()
		btn.button_pressed = active
		_style_tab_button(btn, active)


func _rebuild_round_buttons() -> void:
	for child in _rounds_vbox.get_children():
		child.queue_free()
	_round_buttons.clear()

	var count := Parser.count_rounds_in_file(_level_file_path(), _current_range)
	for i in range(1, count + 1):
		var btn := Button.new()
		btn.text = "ROUND %d" % i
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 48)
		_style_round_button(btn)
		var captured := i
		btn.pressed.connect(func(): _on_round_button_pressed(captured))
		_rounds_vbox.add_child(btn)
		_round_buttons.append(btn)


func _on_round_button_pressed(round_no: int) -> void:
	if round_no == _current_round:
		_highlight_round_button(round_no)
		return
	_select_round(round_no, true)


func _select_round(round_no: int, stash: bool) -> void:
	if stash:
		_stash_current_draft()
	_current_round = round_no
	_highlight_round_button(round_no)
	_load_round_into_editor(_current_range, _current_round)
	_refresh_save_enabled()


func _highlight_round_button(round_no: int) -> void:
	for i in _round_buttons.size():
		var btn := _round_buttons[i]
		var active := (i + 1) == round_no
		btn.button_pressed = active
		_style_round_button(btn, active)


func _load_round_into_editor(range_name: String, round_no: int) -> void:
	var key := _draft_key(range_name, round_no)
	var text := ""
	if _drafts.has(key):
		text = String(_drafts[key])
	else:
		text = Parser.get_raw_round_body(_level_file_path(), range_name, round_no)
		_drafts[key] = text
		_baselines[key] = text
	_suppress_text_signal = true
	_script_edit.text = text
	_suppress_text_signal = false


func _stash_current_draft() -> void:
	if _current_range.is_empty() or _current_round <= 0:
		return
	_drafts[_draft_key(_current_range, _current_round)] = _script_edit.text


func _on_script_text_changed() -> void:
	if _suppress_text_signal or not _is_open:
		return
	_drafts[_draft_key(_current_range, _current_round)] = _script_edit.text
	_refresh_save_enabled()


func _has_unsaved_changes() -> bool:
	_stash_current_draft()
	for key in _drafts.keys():
		var draft := String(_drafts[key])
		var base := String(_baselines.get(key, draft))
		if draft != base:
			return true
	return false


func _refresh_save_enabled() -> void:
	_save_button.disabled = not _has_unsaved_changes()


func _on_save_pressed() -> void:
	if _busy or _save_button.disabled:
		return
	_stash_current_draft()
	var edits: Array = []
	for key in _drafts.keys():
		var draft := String(_drafts[key])
		var base := String(_baselines.get(key, ""))
		if draft == base:
			continue
		var parts := String(key).split("|")
		if parts.size() != 2:
			continue
		edits.append({
			"range": parts[0],
			"round": int(parts[1]),
			"body": draft,
		})
	if edits.is_empty():
		_refresh_save_enabled()
		return

	var path := _level_file_path()
	if not Parser.write_round_edits(path, edits):
		push_error("Round editor: failed to write %s" % path)
		return

	for edit in edits:
		var k := _draft_key(String(edit.range), int(edit.round))
		_baselines[k] = String(edit.body)
		_drafts[k] = String(edit.body)

	if round_manager and round_manager.has_method("load_level_sequence"):
		round_manager.load_level_sequence()
	_refresh_save_enabled()
	print("Round editor: saved %d round(s) → %s" % [edits.size(), path])


func _on_test_pressed() -> void:
	if not _is_open or _busy:
		return
	_busy = true
	_stash_current_draft()
	if round_manager == null:
		push_warning("Round editor: round_manager missing")
		_busy = false
		return
	var text := _get_test_script_text()
	if text.strip_edges().is_empty():
		push_warning("Round editor: nothing to test (empty selection / round)")
		_busy = false
		return
	var selection_only := _has_nonempty_selection()
	print("========== ROUND EDITOR TEST (%s round %d%s) ==========" % [
		_current_range,
		_current_round,
		" — selection" if selection_only else "",
	])
	print(text)
	print("=====================================================")
	close_menu()
	if round_manager.has_method("begin_round_editor_test"):
		await round_manager.begin_round_editor_test(text)
	elif round_manager.has_method("begin_level_editor_test"):
		await round_manager.begin_level_editor_test(text)
	_busy = false


## Prefer the current TextEdit selection so you can TEST a snippet of the round.
func _get_test_script_text() -> String:
	if _has_nonempty_selection():
		return _script_edit.get_selected_text()
	return _script_edit.text


func _has_nonempty_selection() -> bool:
	if _script_edit == null:
		return false
	var selected := _script_edit.get_selected_text()
	return not selected.strip_edges().is_empty()


func _on_back_pressed() -> void:
	if not _is_open or _busy:
		return
	_busy = true
	close_menu()
	if round_manager and round_manager.has_method("exit_round_editor_to_shop"):
		round_manager.exit_round_editor_to_shop()
	elif round_manager and round_manager.has_method("exit_level_editor_to_shop"):
		round_manager.exit_level_editor_to_shop()
	_busy = false


func _unhandled_input(event: InputEvent) -> void:
	if not RoundManager.is_level_editor_available() or not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.shift_pressed:
				_on_test_pressed()
				get_viewport().set_input_as_handled()


func _on_script_gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed and (event.keycode == KEY_F or event.physical_keycode == KEY_F):
			_script_edit.accept_event()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.shift_pressed:
				_on_test_pressed()
				_script_edit.accept_event()


func _apply_styles() -> void:
	_style_panel(_main_panel)
	_style_panel(_rounds_panel)

	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = COLOR_CREAM_PANEL
	edit_style.set_border_width_all(2)
	edit_style.border_color = COLOR_RED
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
		_title_label.add_theme_font_override("font", _font)
		_hint_label.add_theme_font_override("normal_font", _font)
		_save_button.add_theme_font_override("font", _font)
		_test_button.add_theme_font_override("font", _font)
		_back_button.add_theme_font_override("font", _font)

	_title_label.add_theme_color_override("font_color", COLOR_CREAM)
	_style_action_button(_save_button, true)
	_style_action_button(_test_button, true)
	_style_action_button(_back_button, false)


func _style_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CREAM_PANEL
	style.set_border_width_all(3)
	style.border_color = COLOR_RED
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)


func _style_tab_button(button: Button, active: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_RED if active else COLOR_TAB_IDLE
	normal.set_border_width_all(2)
	normal.border_color = COLOR_RED
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_top = 6
	normal.content_margin_right = 10
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_RED if active else Color(0.95, 0.9, 0.86, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_CREAM if active else COLOR_RED)
	button.add_theme_color_override("font_hover_color", COLOR_CREAM if active else COLOR_RED)
	button.add_theme_font_size_override("font_size", 34)
	if _font:
		button.add_theme_font_override("font", _font)


func _style_round_button(button: Button, active: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_RED if active else COLOR_CREAM
	normal.set_border_width_all(2)
	normal.border_color = COLOR_RED
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_top = 8
	normal.content_margin_right = 10
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.85, 0.02, 0.03, 1) if active else Color(0.95, 0.9, 0.86, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_CREAM if active else COLOR_RED)
	button.add_theme_color_override("font_hover_color", COLOR_CREAM if active else COLOR_RED)
	button.add_theme_font_size_override("font_size", 24)
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
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_CREAM if primary else COLOR_RED)
	button.add_theme_color_override("font_hover_color", COLOR_CREAM if primary else COLOR_RED)
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.65, 0.6, 0.55))
	button.add_theme_font_size_override("font_size", 28)
