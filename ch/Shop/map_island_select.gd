extends Control

@export var game_start_menu : Control

## Edit in data_set.gd → dataset_string.map_earn_more_money_text (fallback only).
const earn_more_money_text := "Earn More Cash"

@export_group("Island Transition")
## Total fade-out + fade-in time when changing islands on the map.
@export var island_transition_duration := 0.5
## 0–1 portion of the duration spent fading out (remainder fades in).
@export_range(0.05, 0.95, 0.05) var island_transition_fade_out_ratio := 0.5
@export var island_change_sfx: AudioStreamPlayer

@onready var boss_access_holdout: Control = $BossAccessHoldout
@onready var island_unlocked_popup: Control = $IslandUnlockedPopup

@export_group("Island Name Stamp")
const island_name_stamp_duration := 0.2
const island_name_stamp_start_scale := 8.0
## Per-island label text colours (index = island). Empty = keep scene default.
const island_name_text_colors: Array[Color] = [
	Color("5e544b"),
	Color("FFFFFF"),
	Color("5e544b"),
	Color("5e544b"),
	Color("5e544b"),
]
## Per-island panel colours behind the island name.
const island_name_panel_colors: Array[Color] = [
	Color(0.859, 0.827, 0.8, 1),
	Color(0.86, 0.723, 0.611, 1),
	Color(0.921569, 0.878431, 0.847059, 1),
	Color(0.921569, 0.878431, 0.847059, 1),
	Color(0.921569, 0.878431, 0.847059, 1),
]

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
var _earn_more_popup_busy := false
var _test_mode := false
var _opening_pause_from_map := false
var _island_transitioning := false
## Blocks map buttons / close while the post-boss stamp plays.
var _map_input_locked := false

@onready var close_button: Button = $CloseMapButton
@onready var island1: Control = $Island1
@onready var current_island_label: RichTextLabel = $Island1/CurrentIslandLabel/CurrentIslandRichTextLabel
@onready var next_island_label: RichTextLabel = $Island1/NextIslandLabel/NextIslandRichTextLabel
@onready var next_island_button: BaseButton = $Island1/NextIslandLabel/NextIslandButton
@onready var previous_island_button: BaseButton = $Island1/NextIslandLabel/PreviousIslandButton
@onready var map_cash_label: RichTextLabel = %MapCashBalanceLabel



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
	for page in _island_pages:
		if page == null:
			continue
		var page_boss := _find_boss_on_page(page)
		if page_boss and page_boss != boss:
			page_boss.mouse_filter = Control.MOUSE_FILTER_STOP
			page_boss.z_index = 21


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
	if _map_input_locked:
		return
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
	for i in _island_pages.size():
		var page := _island_pages[i]
		if page == null:
			continue
		var buttons_root := page.get_node_or_null("Buttons")
		if buttons_root:
			for child in buttons_root.get_children():
				if child is Control and child.get("level_name") != null:
					if _is_boss_button(child):
						continue
					_wire_level_button(child)
		var boss := _boss_button_for_island(i)
		if boss:
			boss.set("boss_island_index", i)
			_wire_level_button(boss)


func _is_boss_button(btn: Control) -> bool:
	if btn == null:
		return false
	if String(btn.name) == "BossRangeButton":
		return true
	var script: Script = btn.get_script()
	return script != null and String(script.resource_path).ends_with("boss_button_select.gd")


func _find_boss_on_page(page: Control) -> Control:
	if page == null:
		return null
	for path in ["BossRangeButton", "NextIslandLabel/BossRangeButton", "Buttons/BossRangeButton"]:
		var n := page.get_node_or_null(path) as Control
		if n and _is_boss_button(n):
			return n
	return null


func _boss_button_for_island(island_index: int) -> Control:
	if island_index < 0 or island_index >= _island_pages.size():
		return null
	return _find_boss_on_page(_island_pages[island_index])


func _all_boss_buttons() -> Array[Control]:
	var out: Array[Control] = []
	for i in _island_pages.size():
		var boss := _boss_button_for_island(i)
		if boss and not out.has(boss):
			out.append(boss)
	return out


func _wire_level_button(btn: Control) -> void:
	btn.set("main_control", self)
	btn.z_index = maxi(int(btn.z_index), 9)
	var place := _place_from_level_name(String(btn.get("level_name")))
	btn.set_meta("travel_place", place)
	## Boss buttons keep a fixed island index — do not rewrite to viewing island.
	if _is_boss_button(btn):
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
	if _map_input_locked and _unlock_popup == null:
		get_viewport().set_input_as_handled()
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		## Popup scene owns Esc / Close.
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
	_map_input_locked = false
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
	CommonCode.apply_ui_overlay_blur()
	_fade_out_ammo_panel()

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


## After boss tally: stamp CLEAR on the boss button, unlock popup, then island transition.
func open_pop_up_after_boss_clear(cleared_island: int) -> void:
	_selecting_level = false
	_map_input_locked = true
	ticket_location = String(gl_PlayerState.dataset.level_name).to_lower()
	_viewing_island_index = clampi(
		cleared_island,
		0,
		maxi(gl_DataSet.get_island_count() - 1, 0)
	)
	_show_island_page(_viewing_island_index)
	_refresh_level_buttons()
	_refresh_island_labels()
	_refresh_map_cash_labels()
	_refresh_nav_button_visibility()
	CommonCode.apply_ui_overlay_blur()
	_fade_out_ammo_panel()
	_set_map_chrome_interactive(false)

	var boss := _boss_button()
	if boss and boss.has_method("prepare_clear_ceremony_visuals"):
		boss.set("boss_island_index", _viewing_island_index)
		boss.prepare_clear_ceremony_visuals()

	modulate.a = 0.0
	show()
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	await tween.finished

	if boss and boss.has_method("play_clear_stamp_ceremony"):
		await boss.play_clear_stamp_ceremony()
	elif boss and boss.has_method("refresh_boss_state"):
		await boss.refresh_boss_state(true)

	await get_tree().create_timer(1.0).timeout

	var next_island := _viewing_island_index + 1
	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	if next_island > last_i:
		_map_input_locked = false
		_set_map_chrome_interactive(true)
		_refresh_nav_button_visibility()
		_refresh_boss_button()
		return

	## Unlock popup can receive Close / Esc; rest of map stays locked until after transition.
	_map_input_locked = false
	var next_name := gl_DataSet.get_island_name(next_island)
	await _show_island_unlocked_popup(next_name)

	_map_input_locked = true
	_set_map_chrome_interactive(false)

	_set_unlocked_island_index(next_island)
	gl_PlayerState.save_meta_progress()
	_refresh_nav_button_visibility()
	_refresh_island_labels()

	await _transition_to_island(next_island)

	_map_input_locked = false
	_set_map_chrome_interactive(true)
	_refresh_boss_button()
	var preferred: Control = _first_visible_level_button()
	if preferred == null:
		preferred = close_button
	if preferred:
		UiFocus.grab_in(self, preferred)


func _boss_button() -> Control:
	return _boss_button_for_island(_viewing_island_index)


func _set_map_chrome_interactive(enabled: bool) -> void:
	if close_button:
		close_button.disabled = not enabled
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if next_island_button:
		next_island_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if previous_island_button:
		previous_island_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button in _map_level_buttons():
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for boss in _all_boss_buttons():
		if boss == null:
			continue
		boss.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		boss.disabled = not enabled
	if enabled:
		_refresh_nav_button_visibility()
	else:
		if next_island_button:
			next_island_button.disabled = true
		if previous_island_button:
			previous_island_button.disabled = true


func _fade_out_ammo_panel() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("fade_out_ammo_panel"):
		player.fade_out_ammo_panel(0.33)


func close_pop_up() -> void:
	if not visible:
		return
	_force_close_unlock_popup()
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
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("consume_reopen_shop_after_map") and rm.consume_reopen_shop_after_map():
		rm.enter_state(rm.RoundState.SHOP_START)
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
	if rm and "current_round_state" in rm and "RoundState" in rm:
		if rm.current_round_state == rm.RoundState.START_START:
			call_deferred("open_pop_up")


func _on_next_round_pressed() -> void:
	await close_pop_up()


func _on_close_map_pressed() -> void:
	if _map_input_locked:
		return
	## Bottom-left close always opens pause (not shop), even if we arrived via shop MapButton.
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and "_reopen_shop_after_map" in rm:
		rm._reopen_shop_after_map = false

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
	## Resume should fade the map back in.
	if "reopen_map_on_resume" in pause_menu:
		pause_menu.reopen_map_on_resume = true
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
	var _anchor: Control = next_island_button if next_island_button else next_island_label
	if _anchor:
		var center := _anchor.get_global_rect().get_center()
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

	_apply_map_overlay_visibility(_viewing_island_index)

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

	## One boss button per island — only the viewed island's boss is shown.
	for i in _island_pages.size():
		var boss := _boss_button_for_island(i)
		if boss:
			boss.visible = (i == _viewing_island_index)


func _refresh_nav_button_visibility() -> void:
	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	var unlocked := _unlocked_island_index()
	## First island only, nothing else unlocked — hide both arrows.
	if unlocked <= 0:
		_set_nav_arrow_hidden(previous_island_button)
		_set_nav_arrow_hidden(next_island_button)
		return

	var can_go_prev := _viewing_island_index > 0
	var can_go_next := _viewing_island_index < last_i and (_viewing_island_index + 1) <= unlocked
	## Once another island is unlocked: both visible; inactive arrow stays dimmed.
	_set_nav_arrow_active(previous_island_button, can_go_prev)
	_set_nav_arrow_active(next_island_button, can_go_next)


func _set_nav_arrow_hidden(button: BaseButton) -> void:
	if button == null:
		return
	button.visible = false
	button.disabled = true
	button.modulate = Color(1.0, 1.0, 1.0, 0.35)
	button.focus_mode = Control.FOCUS_NONE


func _set_nav_arrow_active(button: BaseButton, active: bool) -> void:
	if button == null:
		return
	button.visible = true
	button.disabled = not active
	button.modulate = Color.WHITE if active else Color(1.0, 1.0, 1.0, 0.35)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE


func _on_previous_island_pressed() -> void:
	if _map_input_locked:
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	if _island_transitioning:
		return
	if _viewing_island_index <= 0:
		return
	if previous_island_button and previous_island_button.disabled:
		return
	await _transition_to_island(_viewing_island_index - 1)


func _on_next_island_pressed() -> void:
	if _map_input_locked:
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	if _island_transitioning:
		return
	var last_i := maxi(gl_DataSet.get_island_count() - 1, 0)
	if _viewing_island_index >= last_i:
		return

	var target := _viewing_island_index + 1
	var unlocked := _unlocked_island_index()

	if target <= unlocked:
		await _transition_to_island(target)
		return

	## Next island unlocks by defeating this island's boss — not by cash.
	if not gl_PlayerState.is_boss_cleared(_viewing_island_index):
		await _show_beat_boss_popup()
		return

	_set_unlocked_island_index(target)
	gl_PlayerState.save_meta_progress()
	await _show_island_unlocked_popup(gl_DataSet.get_island_name(target))
	await _transition_to_island(target)


## Island button chrome to fade. Root MapOverlay / MapOverlay2 are faded separately.
func _island_fade_targets(index: int) -> Array[CanvasItem]:
	var targets: Array[CanvasItem] = []
	if index < 0 or index >= _island_pages.size():
		return targets
	var page := _island_pages[index]
	if page == null:
		return targets
	if index == 0:
		for child_name in ["Buttons", "Control"]:
			var n := page.get_node_or_null(child_name)
			if n is CanvasItem:
				targets.append(n as CanvasItem)
		return targets
	targets.append(page)
	return targets


## Root MapOverlay = island 0, MapOverlay2 = island 1, MapOverlay3 = island 2, …
func _map_overlay_for_island(index: int) -> CanvasItem:
	if index <= 0:
		return get_node_or_null("MapOverlay") as CanvasItem
	return get_node_or_null("MapOverlay%d" % (index + 1)) as CanvasItem


func _all_map_overlays() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	var first := get_node_or_null("MapOverlay") as CanvasItem
	if first:
		out.append(first)
	for i in range(2, 12):
		var n := get_node_or_null("MapOverlay%d" % i) as CanvasItem
		if n:
			out.append(n)
	return out


func _apply_map_overlay_visibility(active_index: int) -> void:
	var active := _map_overlay_for_island(active_index)
	for overlay in _all_map_overlays():
		if overlay == null:
			continue
		var is_active := overlay == active
		overlay.visible = is_active
		var c := overlay.modulate
		c.a = 1.0 if is_active else 0.0
		overlay.modulate = c


func _set_targets_modulate_a(targets: Array[CanvasItem], a: float) -> void:
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		var c := t.modulate
		c.a = a
		t.modulate = c


func _tween_targets_modulate_a(targets: Array[CanvasItem], a: float, duration: float) -> void:
	if targets.is_empty() or duration <= 0.0:
		_set_targets_modulate_a(targets, a)
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for t in targets:
		if t and is_instance_valid(t):
			tween.tween_property(t, "modulate:a", a, duration)
	await tween.finished


## Fade current island art out → swap page → fade next island art 0→1.
func _transition_to_island(index: int) -> void:
	if _island_transitioning:
		return
	index = clampi(index, 0, maxi(_island_pages.size() - 1, 0))
	if index == _viewing_island_index:
		_refresh_island_labels()
		_refresh_map_cash_labels()
		_refresh_nav_button_visibility()
		_refresh_level_buttons()
		return

	_island_transitioning = true
	## Keep map chrome / root fully visible — only island pages + map overlays fade.
	modulate.a = 1.0
	var duration := maxf(island_transition_duration, 0.05)
	var out_ratio := clampf(island_transition_fade_out_ratio, 0.05, 0.95)
	var fade_out_t := duration * out_ratio
	var fade_in_t := duration * (1.0 - out_ratio)

	#i

	var from_index := _viewing_island_index
	var from_targets := _island_fade_targets(from_index)
	var from_overlay := _map_overlay_for_island(from_index)
	var to_overlay := _map_overlay_for_island(index)

	var fade_out_list: Array[CanvasItem] = []
	fade_out_list.append_array(from_targets)
	if from_overlay:
		fade_out_list.append(from_overlay)
	await _tween_targets_modulate_a(fade_out_list, 0.0, fade_out_t)

	_show_island_page(index)
	## Destination overlay fades in from 0 (show_island_page would force opaque).
	if to_overlay:
		to_overlay.visible = true
		var oc := to_overlay.modulate
		oc.a = 0.0
		to_overlay.modulate = oc
	if from_overlay and from_overlay != to_overlay:
		from_overlay.visible = false

	_refresh_island_labels(true)
	_refresh_map_cash_labels()
	_refresh_nav_button_visibility()
	_refresh_level_buttons()

	var to_targets := _island_fade_targets(index)
	_set_targets_modulate_a(to_targets, 0.0)
	var fade_in_list: Array[CanvasItem] = []
	fade_in_list.append_array(to_targets)
	if to_overlay:
		fade_in_list.append(to_overlay)
	await _tween_targets_modulate_a(fade_in_list, 1.0, fade_in_t)

	## Reset hidden island so the next visit starts fully opaque.
	_set_targets_modulate_a(from_targets, 1.0)
	_island_transitioning = false


## Level/boss clears can unlock nav — refresh next/prev visibility.
func notify_level_cleared() -> void:
	_refresh_nav_button_visibility()
	_refresh_island_labels()
	_refresh_boss_button()


## Large centered hold-out message when the boss fee can't be paid.
func show_boss_access_holdout(cost: int = -1) -> void:
	if cost < 0:
		cost = gl_DataSet.get_boss_unlock_cost(_viewing_island_index)

	## Don't free the authored scene instance — only clear other dynamic popups.
	if _unlock_popup != null and is_instance_valid(_unlock_popup) and _unlock_popup != boss_access_holdout:
		_unlock_popup.queue_free()
		_unlock_popup = null

	if boss_access_holdout == null:
		return
	_unlock_popup = boss_access_holdout
	if boss_access_holdout.has_method("play"):
		await boss_access_holdout.play(cost)
	if _unlock_popup == boss_access_holdout:
		_unlock_popup = null


func _format_cash(amount: int) -> String:
	return CommonCode.format_money(amount)


func _refresh_island_labels(animate_name_stamp: bool = false) -> void:
	var current_name := gl_DataSet.get_island_name(_viewing_island_index)
	_apply_island_name_colors(_viewing_island_index)
	if current_island_label:
		current_island_label.text = current_name.to_upper()
		if animate_name_stamp:
			_play_island_name_stamp()

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


func _apply_island_name_colors(island_index: int) -> void:
	if current_island_label == null:
		return
	if island_index >= 0 and island_index < island_name_text_colors.size():
		current_island_label.self_modulate = island_name_text_colors[island_index]
	var panel := current_island_label.get_node_or_null("Panel") as CanvasItem
	if panel and island_index >= 0 and island_index < island_name_panel_colors.size():
		panel.self_modulate = island_name_panel_colors[island_index]


func _play_island_name_stamp() -> void:
	if current_island_label == null:
		return
	var stamp_root := current_island_label.get_parent() as Control
	if stamp_root == null:
		stamp_root = current_island_label
	var start_scale := maxf(island_name_stamp_start_scale, 1.0)
	var dur := maxf(island_name_stamp_duration, 0.05)
	#current_island_label.pivot_offset = current_island_label.size * 0.5
	#stamp_root.pivot_offset = stamp_root.size * 0.5
	stamp_root.scale = Vector2.ONE * start_scale
	stamp_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, dur)
	tween.parallel().tween_property(stamp_root, "scale", Vector2.ONE, dur)
	tween.parallel().tween_callback(island_change_sfx.play).set_delay(dur - 0.1)
	

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
	for i in _island_pages.size():
		var boss := _boss_button_for_island(i)
		if boss == null:
			continue
		boss.set("main_control", self)
		boss.set("boss_island_index", i)
		var on_page := (i == _viewing_island_index)
		boss.visible = on_page
		if on_page:
			if boss.has_method("refresh_boss_state"):
				boss.refresh_boss_state(false)
			elif boss.has_method("refresh_map_progress"):
				boss.refresh_map_progress()
		elif boss.has_method("_stop_available_idle"):
			boss._stop_available_idle()


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
		notify_level_cleared()
		return
	_apply_completion_stamps(false)
	notify_level_cleared()


func _apply_completion_stamps(animate: bool) -> void:
	for button in _map_level_buttons():
		if button and button.has_method("_refresh_completion_stamp"):
			button._refresh_completion_stamp(animate)


func _travel_place_for_button(button: Control) -> String:
	if button.has_meta("travel_place"):
		return String(button.get_meta("travel_place")).to_lower()
	return _place_from_level_name(String(button.level_name))


func select_level(level_id: String, progress_bar: Range = null) -> void:
	if _selecting_level:
		return
	if _unlock_popup != null and is_instance_valid(_unlock_popup):
		return
	_selecting_level = true
	level_id = level_id.to_lower().strip_edges()

	if level_id == "boss range" or level_id == "boss_range" or level_id == "boss":
		await _try_enter_boss(progress_bar)
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

	if game_start_menu and game_start_menu.visible:
		if game_start_menu.has_method("sfx_close_shop"):
			game_start_menu.sfx_close_shop()
		game_start_menu.hide()
		game_start_menu.current_state = game_start_menu.State.INACTIVE

	## Keep the map open while the layout loads; button progress bar tracks load.
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and "_reopen_shop_after_map" in rm:
		rm._reopen_shop_after_map = false
	if rm and rm.has_method("travel_to_level"):
		await rm.travel_to_level(place, false, progress_bar)
	else:
		gl_PlayerState.change_location(place)

	if progress_bar and is_instance_valid(progress_bar):
		progress_bar.value = 100.0
	await _finish_map_travel_then_open_shop()
	_selecting_level = false


func _try_enter_boss(progress_bar: Range = null) -> void:
	var cost := gl_DataSet.get_boss_unlock_cost(_viewing_island_index)
	var cash := int(gl_PlayerState.dataset.cash)
	var unlocked := gl_PlayerState.is_boss_unlocked(_viewing_island_index) \
		or gl_PlayerState.is_boss_cleared(_viewing_island_index)

	if not unlocked and cash < cost:
		_selecting_level = false
		_refresh_boss_button()
		await show_boss_access_holdout(cost)
		return

	## First successful afford (or prior unlock) → permanent access, no cash spent.
	if not unlocked and cash >= cost:
		gl_PlayerState.mark_boss_unlocked(_viewing_island_index)

	if _test_mode:
		print(
			"MapIslandSelect TEST: boss ready (island=%s cost=%s cash=%s unlocked=%s)"
			% [_viewing_island_index, cost, cash, unlocked]
		)
		_selecting_level = false
		return

	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and "_reopen_shop_after_map" in rm:
		rm._reopen_shop_after_map = false
	if rm and rm.has_method("travel_to_boss"):
		await rm.travel_to_boss(_viewing_island_index, false, progress_bar)
	else:
		push_warning("MapIslandSelect: round_manager.travel_to_boss missing")

	if progress_bar and is_instance_valid(progress_bar):
		progress_bar.value = 100.0
	await _finish_map_travel_then_open_shop()
	_selecting_level = false


## Load finished  brief hold → longer pause → fade map → wait → open shop.
## Tweak these three waits to change how long until the shop appears.
@export_group("Map Shop Timing")
@export var map_to_shop_hold_after_load := 0.25
@export var map_to_shop_pause_before_fade := 1.0
const map_to_shop_wait_after_fade := 0.25


func _finish_map_travel_then_open_shop() -> void:
	await get_tree().create_timer(map_to_shop_hold_after_load).timeout
	await get_tree().create_timer(map_to_shop_pause_before_fade).timeout
	await close_pop_up()
	await get_tree().create_timer(map_to_shop_wait_after_fade).timeout

	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and "RoundState" in rm:
		rm.enter_state(rm.RoundState.SHOP_START)
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("show_ammo_panel"):
		player.show_ammo_panel()


func _resolve_travel_place(level_id: String) -> String:
	for button in _map_level_buttons():
		if button and String(button.level_name).to_lower() == level_id:
			return _travel_place_for_button(button)
	var boss := _boss_button()
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
	var _anchor: Control = next_island_button if next_island_button else next_island_label
	var start_pos := Vector2.ZERO
	if _anchor:
		start_pos = _anchor.global_position + (_anchor.size * _anchor.scale * 0.5)
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


func _force_close_unlock_popup() -> void:
	if island_unlocked_popup and island_unlocked_popup.has_method("force_close"):
		island_unlocked_popup.force_close()
	if _unlock_popup == island_unlocked_popup:
		_unlock_popup = null
	elif _unlock_popup != null and is_instance_valid(_unlock_popup) and _unlock_popup != boss_access_holdout:
		_unlock_popup.queue_free()
		_unlock_popup = null


func _show_island_unlocked_popup(island_name: String) -> void:
	if island_unlocked_popup == null:
		push_warning("MapIslandSelect: IslandUnlockedPopup missing")
		return
	if _unlock_popup == boss_access_holdout:
		_unlock_popup = null
	_unlock_popup = island_unlocked_popup
	if island_unlocked_popup.has_method("play"):
		await island_unlocked_popup.play(island_name)
	_unlock_popup = null
