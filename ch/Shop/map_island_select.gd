extends Control

@export var game_start_menu : Control

## Edit in data_set.gd → dataset_string.map_earn_more_money_text (fallback only).
const earn_more_money_text := "Earn More Cash"

@export_group("Test Mode")
## Turn on manually, or leave off — auto-enables when you F6 this scene alone.
@export var enable_test_mode := false
## Simulated player cash while testing this scene.
@export var test_cash := 15000
## Highest island unlocked at start of a test run (0 = Shipper).
@export_range(0, 4, 1) var test_unlocked_island_index := 0

var ticket_location := ""
var _selecting_level := false
var _viewing_island_index := 0
var _island_pages: Array[Control] = []
var _unlock_popup: Control
var _unlock_popup_dismissed := false
var _earn_more_popup_busy := false
var _test_mode := false
var _opening_pause_from_map := false

@onready var close_button: Button = $CloseMapButton
@onready var island1: Control = $Island1
@onready var current_island_label: RichTextLabel = $Island1/CurrentIslandLabel/CurrentIslandRichTextLabel
@onready var next_island_label: RichTextLabel = $Island1/NextIslandLabel/NextIslandRichTextLabel
@onready var next_island_button: BaseButton = $Island1/NextIslandLabel/NextIslandButton
@onready var previous_island_button: BaseButton = $Island1/NextIslandLabel/PreviousIslandButton
@onready var map_cash_label: RichTextLabel = %MapCashBalanceLabel
@onready var cash_needed_label: RichTextLabel = %CashNeededAmountLabel


func _ready() -> void:
	_test_mode = enable_test_mode or _is_running_as_main_scene()
	if _test_mode:
		_apply_test_mode()

	process_mode = Node.PROCESS_MODE_ALWAYS
	_fix_click_blockers()
	_collect_island_pages()
	_wire_all_level_buttons()
	_setup_nav_buttons()
	_viewing_island_index = int(gl_PlayerState.dataset.get("unlocked_island_index", 0))
	_show_island_page(_viewing_island_index)

	if _test_mode:
		## Standalone F6: open immediately so you can click around.
		await open_pop_up()
	else:
		hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _is_running_as_main_scene() -> bool:
	return get_tree() != null and get_tree().current_scene == self


func _apply_test_mode() -> void:
	gl_PlayerState.dataset.cash = test_cash
	gl_PlayerState.dataset["unlocked_island_index"] = clampi(test_unlocked_island_index, 0, 4)
	## Full-window layout when run alone.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_index = 40
	print("MapIslandSelect TEST MODE — cash=%s unlocked_island=%s" % [
		test_cash,
		gl_PlayerState.dataset["unlocked_island_index"],
	])


func _fix_click_blockers() -> void:
	## Full-screen decorative layers ate clicks meant for level buttons.
	for path in [
		"ColorRect",
		"Island1/CurrentIslandLabel",
		"Island1/NextIslandLabel",
		"Island1/MapOverlay",
		"Island1/Control",
		"Island1/Control2",
	]:
		var node := get_node_or_null(path) as Control
		if node:
			_set_mouse_ignore_recursive(node, true)

	for i in range(1, 6):
		var page := get_node_or_null("Island%d" % i) as Control
		if page == null:
			continue
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var overlay := page.get_node_or_null("MapOverlay") as Control
		if overlay:
			_set_mouse_ignore_recursive(overlay, true)
		var buttons_root := page.get_node_or_null("Buttons") as Control
		if buttons_root:
			buttons_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buttons_root.z_index = 8

	if island1:
		var buttons1 := island1.get_node_or_null("Buttons") as Control
		if buttons1:
			island1.move_child(buttons1, island1.get_child_count() - 1)

	if next_island_button:
		next_island_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if previous_island_button:
		previous_island_button.mouse_filter = Control.MOUSE_FILTER_STOP
	#if next_island_label:
		#next_island_label.mouse_filter = Control.MOUSE_FILTER_STOP
		#for child in next_island_label.get_children():
			#if child is BaseButton:
				#(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			#elif child is Control and String(child.name) == "BossRangeButton":
				#(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			#elif child is Control:
				#(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if current_island_label:
		current_island_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in current_island_label.get_children():
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var boss := get_node_or_null("Island1/NextIslandLabel/BossRangeButton") as Control
	if boss:
		boss.mouse_filter = Control.MOUSE_FILTER_STOP
		boss.z_index = 21


func _set_mouse_ignore_recursive(node: Control, include_self: bool = true) -> void:
	if include_self:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is BaseButton:
			continue
		if child is Control and String(child.name) == "BossRangeButton":
			continue
		if child is Control:
			_set_mouse_ignore_recursive(child, true)


func _setup_nav_buttons() -> void:
	if next_island_button and not next_island_button.pressed.is_connected(_on_next_island_pressed):
		next_island_button.pressed.connect(_on_next_island_pressed)
	if previous_island_button and not previous_island_button.pressed.is_connected(_on_previous_island_pressed):
		previous_island_button.pressed.connect(_on_previous_island_pressed)
	if next_island_label:
		next_island_label.mouse_filter = Control.MOUSE_FILTER_STOP
		if not next_island_label.gui_input.is_connected(_on_next_island_label_gui_input):
			next_island_label.gui_input.connect(_on_next_island_label_gui_input)


func _on_next_island_label_gui_input(event: InputEvent) -> void:
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_island_pressed()


func _collect_island_pages() -> void:
	_island_pages.clear()
	for i in range(1, 6):
		var page := get_node_or_null("Island%d" % i) as Control
		if page:
			_island_pages.append(page)
			if i > 1:
				page.hide()
	if _island_pages.is_empty() and island1:
		_island_pages.append(island1)


func _wire_all_level_buttons() -> void:
	for page in _island_pages:
		if page == null:
			continue
		var buttons_root := page.get_node_or_null("Buttons")
		if buttons_root == null:
			continue
		for child in buttons_root.get_children():
			if child is Control and child.get("level_name") != null:
				_wire_level_button(child)
	var boss := get_node_or_null("Island1/NextIslandLabel/BossRangeButton") as Control
	if boss:
		_wire_level_button(boss)


func _wire_level_button(btn: Control) -> void:
	btn.set("main_control", self)
	btn.z_index = maxi(int(btn.z_index), 9)
	var place := _place_from_level_name(String(btn.get("level_name")))
	btn.set_meta("travel_place", place)
	## Boss buttons manage their own lock/available/cleared states.
	if String(btn.name) == "BossRangeButton" or btn.get_script() and String(btn.get_script().resource_path).ends_with("boss_button_select.gd"):
		btn.set("boss_island_index", _viewing_island_index)
		if btn.has_method("refresh_boss_state"):
			btn.call_deferred("refresh_boss_state")
		return
	btn.set("level_locked", false)
	if btn.has_method("set_unlocked_visuals"):
		btn.call_deferred("set_unlocked_visuals")


func _place_from_level_name(level_name: String) -> String:
	var key := level_name.to_lower().strip_edges()
	if key == "boss range" or key == "boss_range" or key == "boss":
		return "boss"
	var resolved := gl_DataSet.resolve_place_name(key)
	if gl_DataSet.has_place(resolved) and resolved != gl_DataSet.get_start_place_name():
		return resolved
	return gl_DataSet.get_testing_place_name()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _selecting_level:
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("controller_back_button")):
			_dismiss_unlock_popup()
			get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("controller_back_button") or event.is_action("ui_cancel"):
		if _test_mode:
			## In standalone test, Esc just keeps the map open.
			get_viewport().set_input_as_handled()
			return
		_on_close_map_pressed()
		get_viewport().set_input_as_handled()


func open_pop_up() -> void:
	_selecting_level = false
	ticket_location = String(gl_PlayerState.dataset.level_name).to_lower()
	_viewing_island_index = clampi(
		int(gl_PlayerState.dataset.get("unlocked_island_index", 0)),
		0,
		maxi(gl_DataSet.get_island_count() - 1, 0)
	)
	_show_island_page(_viewing_island_index)
	_refresh_level_buttons()
	_refresh_island_labels()
	_refresh_map_cash_labels()
	_refresh_nav_button_visibility()

	modulate.a = 0.0
	show()
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	await tween.finished
	var preferred: Control = _first_visible_level_button()
	if preferred == null:
		preferred = close_button
	if preferred:
		UiFocus.grab_in(self, preferred)


func close_pop_up() -> void:
	if not visible:
		return
	if _test_mode:
		## Keep map visible while testing this scene alone.
		return
	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween2.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_restore_focus_after_close()


func _restore_focus_after_close() -> void:
	if _opening_pause_from_map:
		return
	var shop := get_tree().get_first_node_in_group("shop_main_menu") as Control
	if shop and shop.is_visible_in_tree():
		UiFocus.grab_in(shop)
		return
	if game_start_menu and game_start_menu.is_visible_in_tree():
		UiFocus.grab_in(game_start_menu)
		return
	if _selecting_level:
		return
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and "current_round_state" in rm and "RoundState" in rm:
		if rm.current_round_state == rm.RoundState.START_START:
			call_deferred("open_pop_up")


func _on_next_round_pressed() -> void:
	await close_pop_up()


func _on_close_map_pressed() -> void:
	## Close map, then open the pause menu (don't auto-reopen the map).
	_opening_pause_from_map = true
	await close_pop_up()
	_open_pause_menu_from_map()
	_opening_pause_from_map = false


func _open_pause_menu_from_map() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_pause"):
		menus.ensure_pause()
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu == null:
		return
	if pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif pause_menu.has_method("start"):
		pause_menu.start()


func display_ticket() -> void:
	await open_pop_up()


func _unlocked_island_index() -> int:
	return int(gl_PlayerState.dataset.get("unlocked_island_index", 0))


func _set_unlocked_island_index(index: int) -> void:
	gl_PlayerState.dataset["unlocked_island_index"] = clampi(index, 0, maxi(gl_DataSet.get_island_count() - 1, 0))
	gl_PlayerState.save_meta_progress()


func _show_beat_boss_popup() -> void:
	if _earn_more_popup_busy:
		return
	_earn_more_popup_busy = true

	var popup := RichTextLabel.new()
	popup.bbcode_enabled = true
	popup.fit_content = true
	popup.scroll_active = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 40
	popup.theme_type_variation = "WhiteRichText"
	popup.top_level = true
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.autowrap_mode = TextServer.AUTOWRAP_OFF
	popup.add_theme_font_size_override("normal_font_size", 42)
	popup.text = "[wave]Defeat the Boss first"
	popup.modulate = Color(0.63, 0.006, 0.017, 0.0)
	add_child(popup)

	await get_tree().process_frame
	var anchor: Control = next_island_button if next_island_button else next_island_label
	if anchor:
		var center := anchor.get_global_rect().get_center()
		popup.global_position = center - popup.size * 0.5 + Vector2(0, -80)
	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.1)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35)
	await tween.finished
	popup.queue_free()
	_earn_more_popup_busy = false


func _show_island_page(index: int) -> void:
	_viewing_island_index = clampi(index, 0, maxi(_island_pages.size() - 1, 0))
	for i in _island_pages.size():
		var page := _island_pages[i]
		if page:
			page.visible = (i == _viewing_island_index)

	## Nav chrome lives under Island1 — keep it visible while browsing other islands.
	var current_wrap := get_node_or_null("Island1/CurrentIslandLabel") as Control
	var next_wrap := get_node_or_null("Island1/NextIslandLabel") as Control
	if current_wrap:
		current_wrap.visible = true
		current_wrap.z_index = 20
	if next_wrap:
		next_wrap.visible = true
		next_wrap.z_index = 20

	if island1 and _viewing_island_index != 0:
		var map_overlay := island1.get_node_or_null("MapOverlay") as CanvasItem
		var buttons := island1.get_node_or_null("Buttons") as CanvasItem
		var decor := island1.get_node_or_null("Control") as CanvasItem
		if map_overlay:
			map_overlay.visible = false
		if buttons:
			buttons.visible = false
		if decor:
			decor.visible = false
		island1.visible = true
	elif island1:
		var map_overlay2 := island1.get_node_or_null("MapOverlay") as CanvasItem
		var buttons2 := island1.get_node_or_null("Buttons") as CanvasItem
		var decor2 := island1.get_node_or_null("Control") as CanvasItem
		if map_overlay2:
			map_overlay2.visible = true
		if buttons2:
			buttons2.visible = true
		if decor2:
			decor2.visible = true


func _refresh_nav_button_visibility() -> void:
	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	var can_go_prev := _viewing_island_index > 0
	var can_go_next := _viewing_island_index < last_i
	## Always visible — inactive arrows are dulled + disabled (not hidden).
	_set_nav_arrow_active(previous_island_button, can_go_prev)
	_set_nav_arrow_active(next_island_button, can_go_next)


func _set_nav_arrow_active(button: BaseButton, active: bool) -> void:
	if button == null:
		return
	button.visible = true
	button.disabled = not active
	button.modulate = Color.WHITE if active else Color(1.0, 1.0, 1.0, 0.35)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE


func _on_previous_island_pressed() -> void:
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	if _viewing_island_index <= 0:
		return
	if previous_island_button and previous_island_button.disabled:
		return
	_show_island_page(_viewing_island_index - 1)
	_refresh_island_labels()
	_refresh_map_cash_labels()
	_refresh_nav_button_visibility()
	_refresh_level_buttons()


func _on_next_island_pressed() -> void:
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	if _viewing_island_index >= last_i:
		return

	var target := _viewing_island_index + 1
	var unlocked := _unlocked_island_index()

	if target <= unlocked:
		_show_island_page(target)
		_refresh_island_labels()
		_refresh_map_cash_labels()
		_refresh_nav_button_visibility()
		_refresh_level_buttons()
		return

	## Next island unlocks by defeating this island's boss — not by cash.
	if not gl_PlayerState.is_boss_cleared(_viewing_island_index):
		await _show_beat_boss_popup()
		return

	_set_unlocked_island_index(target)
	gl_PlayerState.save_meta_progress()
	await _show_island_unlocked_popup(gl_DataSet.get_island_name(target))
	_show_island_page(target)
	_refresh_island_labels()
	_refresh_map_cash_labels()
	_refresh_nav_button_visibility()
	_refresh_level_buttons()


func _format_cash(amount: int) -> String:
	var raw := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = raw[i] + out
		count += 1
	if amount < 0:
		out = "-" + out
	return "$" + out


func _refresh_island_labels() -> void:
	var current_name := gl_DataSet.get_island_name(_viewing_island_index)
	if current_island_label:
		current_island_label.text = current_name.to_upper()

	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	if _viewing_island_index >= last_i:
		if next_island_label:
			next_island_label.text = "FINAL ISLAND"
		return

	var next_name := gl_DataSet.get_island_name(_viewing_island_index + 1)
	var status_line := "DEFEAT BOSS"
	if _viewing_island_index + 1 <= _unlocked_island_index():
		status_line = "UNLOCKED"
	elif gl_PlayerState.is_boss_cleared(_viewing_island_index):
		status_line = "READY"
	if next_island_label:
		next_island_label.text = "%s\n[font_size=40] %s[/font_size]" % [next_name.to_upper(), status_line]


func _refresh_map_cash_labels() -> void:
	var cash := int(gl_PlayerState.dataset.cash)
	if map_cash_label:
		map_cash_label.text = _format_cash(cash)
	## Earn-more / cash-needed messaging lives on the boss button now.
	#var cash_needed_display := get_node_or_null("CashNeededDisplay") as CanvasItem
	#if cash_needed_display:
		#cash_needed_display.visible = false
	#if cash_needed_label:
		#cash_needed_label.visible = false


func _map_level_buttons() -> Array:
	var out: Array = []
	for page in _island_pages:
		if page == null:
			continue
		var buttons_root := page.get_node_or_null("Buttons")
		if buttons_root == null:
			continue
		for child in buttons_root.get_children():
			if not (child is Control):
				continue
			if String(child.name) == "BossRangeButton":
				continue
			var has_level_name := child.get("level_name") != null
			var is_level_btn := String(child.name).begins_with("Level_button")
			if is_level_btn or has_level_name:
				out.append(child)
	return out


func _first_visible_level_button() -> Control:
	for page in _island_pages:
		if page == null or not page.visible:
			continue
		var buttons_root := page.get_node_or_null("Buttons") as Control
		if buttons_root == null or not buttons_root.visible:
			continue
		for child in buttons_root.get_children():
			if child is Control and child.visible and child.get("level_name") != null:
				return child
	return null


func _refresh_level_buttons() -> void:
	for button in _map_level_buttons():
		if button == null or not is_instance_valid(button):
			continue
		if not button.visible:
			continue
		_unlock_map_button(button)
		if button.has_method("refresh_map_progress"):
			button.refresh_map_progress()
	_apply_completion_stamps(false)
	_refresh_boss_button()


func _refresh_boss_button() -> void:
	var boss := get_node_or_null("Island1/NextIslandLabel/BossRangeButton") as Control
	if boss == null:
		return
	boss.set("main_control", self)
	boss.set("boss_island_index", _viewing_island_index)
	if boss.has_method("refresh_boss_state"):
		boss.refresh_boss_state(false)
	elif boss.has_method("refresh_map_progress"):
		boss.refresh_map_progress()


func _unlock_map_button(button: Control) -> void:
	if button == null:
		return
	button.level_locked = false
	if button.has_method("set_unlocked_visuals"):
		button.set_unlocked_visuals()
	elif button.has_method("refresh_map_progress"):
		button.refresh_map_progress()
	elif button.get("level_name_label"):
		button.level_name_label.text = "[wave]" + String(button.level_name).to_upper()


func mark_place_completed(place_id: String, animate: bool = true) -> void:
	place_id = gl_DataSet.resolve_place_name(place_id)
	for button in _map_level_buttons():
		if button == null:
			continue
		var button_place := _travel_place_for_button(button)
		if button_place != place_id:
			continue
		if button.has_method("mark_completed"):
			await button.mark_completed(animate)
		return
	_apply_completion_stamps(false)


func _apply_completion_stamps(animate: bool) -> void:
	for button in _map_level_buttons():
		if button and button.has_method("_refresh_completion_stamp"):
			button._refresh_completion_stamp(animate)


func _travel_place_for_button(button: Control) -> String:
	if button.has_meta("travel_place"):
		return String(button.get_meta("travel_place")).to_lower()
	return _place_from_level_name(String(button.level_name))


func select_level(level_id: String) -> void:
	if _selecting_level:
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	_selecting_level = true
	level_id = level_id.to_lower().strip_edges()

	if level_id == "boss range" or level_id == "boss_range" or level_id == "boss":
		await _try_enter_boss()
		return

	var place := _resolve_travel_place(level_id)
	ticket_location = place

	if _test_mode:
		print("MapIslandSelect TEST: would travel to '%s' (from button '%s')" % [place, level_id])
		_selecting_level = false
		return

	var current := String(gl_PlayerState.dataset.level_name).to_lower()
	if place == gl_DataSet.resolve_place_name(current):
		await close_pop_up()
		_selecting_level = false
		return

	await close_pop_up()

	var moved := gl_PlayerState.change_location(place)
	if moved and game_start_menu and game_start_menu.visible:
		if game_start_menu.has_method("sfx_close_shop"):
			game_start_menu.sfx_close_shop()
		game_start_menu.hide()
		game_start_menu.current_state = game_start_menu.State.INACTIVE

	_selecting_level = false


func _try_enter_boss() -> void:
	var cost := gl_DataSet.get_boss_unlock_cost(_viewing_island_index)
	var cash := int(gl_PlayerState.dataset.cash)
	if cash < cost:
		_selecting_level = false
		## Message is shown on the boss button itself — just refresh it.
		_refresh_boss_button()
		return

	if _test_mode:
		print(
			"MapIslandSelect TEST: boss ready (island=%s cost=%s cash=%s)"
			% [_viewing_island_index, cost, cash]
		)
		_selecting_level = false
		return

	## Pay the boss entry fee.
	if cost > 0:
		gl_PlayerState.dataset.cash = cash - cost
		if EventBus.instance.has_signal("purchase_made"):
			EventBus.instance.purchase_made.emit("boss_entry")

	await close_pop_up()
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("travel_to_boss"):
		rm.travel_to_boss(_viewing_island_index)
	else:
		push_warning("MapIslandSelect: round_manager.travel_to_boss missing")
	_selecting_level = false


func _resolve_travel_place(level_id: String) -> String:
	for button in _map_level_buttons():
		if button and String(button.level_name).to_lower() == level_id:
			return _travel_place_for_button(button)
	var boss := get_node_or_null("Island1/NextIslandLabel/BossRangeButton")
	if boss and String(boss.get("level_name")).to_lower() == level_id:
		return "boss"
	return _place_from_level_name(level_id)


func ticket_used() -> void:
	await select_level(ticket_location if ticket_location != "" else gl_DataSet.get_default_range_name())


func _show_earn_more_money_popup() -> void:
	if _earn_more_popup_busy:
		return
	_earn_more_popup_busy = true

	var msg := gl_DataSet.get_map_earn_more_money_text()
	if msg.is_empty():
		msg = earn_more_money_text

	var popup := RichTextLabel.new()
	popup.bbcode_enabled = true
	popup.fit_content = true
	popup.scroll_active = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 40
	popup.theme_type_variation = "WhiteRichText"
	popup.top_level = true
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.autowrap_mode = TextServer.AUTOWRAP_OFF
	popup.add_theme_font_size_override("normal_font_size", 42)
	popup.text = "[wave]%s" % msg
	popup.modulate = Color(0.63, 0.006, 0.017, 0.0)
	add_child(popup)

	await get_tree().process_frame
	var anchor: Control = next_island_button if next_island_button else next_island_label
	var start_pos := Vector2.ZERO
	if anchor:
		start_pos = anchor.global_position + (anchor.size * anchor.scale * 0.5)
		start_pos.x -= popup.size.x * 0.5
		start_pos.y -= 40.0
	else:
		start_pos = global_position + size * 0.5
	popup.global_position = start_pos

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(popup, "global_position:y", start_pos.y - 100.0, 0.9)
	tween.parallel().tween_property(popup, "global_position:x", start_pos.x + 30.0, 0.9)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35)
	await tween.finished
	popup.queue_free()
	_earn_more_popup_busy = false


func _dismiss_unlock_popup() -> void:
	_unlock_popup_dismissed = true


func _show_island_unlocked_popup(island_name: String) -> void:
	if _unlock_popup and is_instance_valid(_unlock_popup):
		_unlock_popup.queue_free()
		_unlock_popup = null

	_unlock_popup_dismissed = false

	var dim := ColorRect.new()
	dim.name = "IslandUnlockPopup"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.92, 0.877, 0.846, 0.416)
	dim.z_index = 80
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_unlock_popup = dim

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 72)
	label.theme_type_variation = "WhiteRichText"
	label.text = "You've unlocked [wave]%s[/wave]" % island_name
	label.modulate = Color("a10204ff")
	label.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(160, 48)
	close_btn.add_theme_font_size_override("font_size", 72)
	close_btn.add_theme_color_override("font_color", Color("c70102ff"))
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(close_btn)

	close_btn.pressed.connect(_dismiss_unlock_popup)
	## Clicking the dim backdrop also dismisses.
	dim.gui_input.connect(func (event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_unlock_popup()
	)

	await get_tree().process_frame
	if is_instance_valid(close_btn):
		close_btn.grab_focus()

	while not _unlock_popup_dismissed and is_instance_valid(dim):
		await get_tree().process_frame

	if is_instance_valid(dim):
		dim.queue_free()
	_unlock_popup = null
	_unlock_popup_dismissed = false
