@tool
extends Control

const STAGES: Array[String] = ["BEGINNER", "ADVANCED", "EXPERT"]
const LEVEL_FILES := {
	"BEGINNER": "res://sc/level-beginner.txt",
	"ADVANCED": "res://sc/level-advanced.txt",
	"EXPERT": "res://sc/level-expert.txt",
}
const BADGE_SCENE := preload("res://ch/canvas_layers/level_select_badge_unlocked.tscn")
const LOCKED_BADGE_SCENE := preload("res://ch/canvas_layers/level_select_badge_locked.tscn")
const LEVEL_BADGE_SIZE := Vector2(118, 118)

@export_group("Level Grid")
## If true, choosing a level skips the center/blink animation and closes this menu immediately.
@export var skip_select_animation := false
@export_range(0.15, 2.5, 0.01, "or_greater") var unlocked_badge_scale := 1.0:
	set(value):
		unlocked_badge_scale = maxf(value, 0.05)
		_apply_badge_layout()
@export_range(0.15, 2.5, 0.01, "or_greater") var locked_badge_scale := 1.0:
	set(value):
		locked_badge_scale = maxf(value, 0.05)
		_apply_badge_layout()
## Extra offset from the grid's scene layout. (0, 0) keeps the authored centre placement.
@export var level_grid_position := Vector2.ZERO:
	set(value):
		level_grid_position = value
		if _grid_layout_ready:
			_apply_grid_position()

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var _busy := false
var _stage_index := 0
var _grid_layout_ready := false
var _grid_home_offset := Vector2.ZERO
var _grid_home_size := Vector2(860.0, 300.0)

@onready var _net_worth_root: Control = get_node_or_null("%NetWorth") as Control
@onready var _header_badge: DifficultyBadge = get_node_or_null("%HeaderBadge") as DifficultyBadge
@onready var _prev_button: Button = get_node_or_null("%PrevDifficultyButton") as Button
@onready var _next_button: Button = get_node_or_null("%NextDifficultyButton") as Button
@onready var _level_grid: GridContainer = get_node_or_null("%LevelGrid") as GridContainer
@onready var _locked_overlay: Control = get_node_or_null("%LockedOverlay") as Control
@onready var _locked_need_label: RichTextLabel = get_node_or_null("%LockedNeedLabel") as RichTextLabel
@onready var _back_button: Button = get_node_or_null("%MapButton") as Button
@onready var _open_sfx: AudioStreamPlayer = get_node_or_null("SFX/shop_open_sfx_01")
@onready var _close_sfx: AudioStreamPlayer = get_node_or_null("SFX/shop_close_sfx_01")
@onready var _click_1: AudioStreamPlayer = get_node_or_null("SFX/hud_click_1")
@onready var _click_2: AudioStreamPlayer = get_node_or_null("SFX/hud_click_2")
@onready var _click_3: AudioStreamPlayer = get_node_or_null("SFX/hud_click_3")
@onready var _hum: AudioStreamPlayer = get_node_or_null("SFX/low_humming")


func _ready() -> void:
	_capture_grid_home()
	_grid_layout_ready = true
	if Engine.is_editor_hint():
		call_deferred("_apply_grid_position")
		return
	add_to_group("level_select")
	default_scale = scale
	default_position = position
	pivot_offset_ratio = Vector2(0.5, 0.5)
	call_deferred("_apply_grid_position")
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	var challenges := get_node_or_null("%SpecialChallengeButtons") as CanvasItem
	if challenges:
		challenges.hide()
	var difficulty_row := get_node_or_null("%DifficultySelectButtons") as CanvasItem
	if difficulty_row:
		difficulty_row.hide()
	if _prev_button:
		_prev_button.pressed.connect(_on_prev_difficulty_pressed)
	if _next_button:
		_next_button.pressed.connect(_on_next_difficulty_pressed)
	if _header_badge:
		_header_badge.is_header = true
		_header_badge.travel_place = ""
		_header_badge.hide_subtitle = true


func open_pop_up(stage: String = "") -> void:
	if not stage.strip_edges().is_empty():
		_stage_index = _index_for_stage(stage)
		_store_select_difficulty()
	else:
		_stage_index = _index_for_stage(_current_stage_name())
	_busy = false
	if _header_badge and _header_badge.has_method("reset_selection_state"):
		_header_badge.reset_selection_state()
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	show()
	call_deferred("_apply_grid_position")
	_fade_out_ammo_hud()
	CommonCode.apply_ui_overlay_blur()
	_sfx_open()
	_refresh_net_worth()
	_pan_level_layout_for_stage()
	_play_title_select_music()
	_refresh_header()
	_refresh_arrows()
	_rebuild_level_grid()
	var challenges := get_node_or_null("%SpecialChallengeButtons") as CanvasItem
	if challenges:
		challenges.hide()
	var difficulty_row := get_node_or_null("%DifficultySelectButtons") as CanvasItem
	if difficulty_row:
		difficulty_row.hide()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await tween.finished
	_grab_level_grid_focus()


func close_pop_up() -> void:
	_sfx_close_instant()
	_hide_reset()


func close_pop_up_animated() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sfx_close()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.01, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	await tween.finished
	_hide_reset()


func _hide_reset() -> void:
	hide()
	scale = default_scale
	modulate.a = 1.0
	position = default_position
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if _header_badge and _header_badge.has_method("reset_selection_state"):
		_header_badge.reset_selection_state()


func _refresh_net_worth() -> void:
	if _net_worth_root and _net_worth_root.has_method("refresh"):
		_net_worth_root.refresh()


func _pan_level_layout_for_stage() -> void:
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm == null or not rm.has_method("pan_level_layout_for_stage"):
		return
	rm.pan_level_layout_for_stage(STAGES[_stage_index])


func _play_title_select_music() -> void:
	var music := get_tree().get_first_node_in_group("level_music")
	if music and music.has_method("play_title_select_music"):
		music.play_title_select_music()


func _current_stage_name() -> String:
	if gl_PlayerState and gl_PlayerState.has_method("get_select_difficulty"):
		return String(gl_PlayerState.get_select_difficulty())
	if gl_PlayerState and gl_PlayerState.has_method("get_run_difficulty"):
		return String(gl_PlayerState.get_run_difficulty())
	return "BEGINNER"


func _index_for_stage(stage: String) -> int:
	var key := stage.strip_edges().to_upper()
	var i := STAGES.find(key)
	return i if i >= 0 else 0


func _refresh_header() -> void:
	if _header_badge == null:
		return
	var stage := STAGES[_stage_index]
	_header_badge.is_header = true
	_header_badge.hide_subtitle = true
	_header_badge.hide_icons = false
	_header_badge.travel_place = ""
	_header_badge.unlock_key = ""
	_header_badge.locked = false
	_header_badge.apply_color_scheme(stage)
	_header_badge.title = stage
	_header_badge.hide_subtitle = true
	_header_badge._apply_visuals()


func _refresh_arrows() -> void:
	_set_arrow_active(_prev_button, _can_page_to(_stage_index - 1))
	_set_arrow_active(_next_button, _can_page_to(_stage_index + 1))


func _can_page_to(index: int) -> bool:
	return index >= 0 and index < STAGES.size()


func _stage_unlocked(stage: String) -> bool:
	if stage == "BEGINNER":
		return true
	if gl_DataSet and gl_DataSet.has_method("is_difficulty_unlocked"):
		return bool(gl_DataSet.is_difficulty_unlocked(stage.to_lower()))
	return false


func _set_arrow_active(button: BaseButton, active: bool) -> void:
	if button == null:
		return
	button.visible = true
	button.disabled = not active
	button.modulate = Color.WHITE if active else Color(1.0, 1.0, 1.0, 0.35)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE


func _rebuild_level_grid() -> void:
	if _level_grid == null:
		return
	for child in _level_grid.get_children():
		_level_grid.remove_child(child)
		child.queue_free()
	var stage := STAGES[_stage_index]
	var stage_unlocked := _stage_unlocked(stage)
	var ranges := _ranges_for_stage(stage)
	var boss_seen := 0
	for i in ranges.size():
		var place := String(ranges[i]).to_lower()
		var boss := place.begins_with("boss-") or place == "boss"
		var armored := boss and boss_seen > 0
		if boss:
			boss_seen += 1
		var unlocked := stage_unlocked
		if unlocked and gl_PlayerState and gl_PlayerState.has_method("is_sequential_level_unlocked"):
			unlocked = bool(gl_PlayerState.is_sequential_level_unlocked(stage, ranges, i))
		var badge: Control
		if unlocked:
			var open_badge := BADGE_SCENE.instantiate() as DifficultyBadge
			if open_badge == null:
				continue
			open_badge.hide_icons = true
			badge = open_badge
			_level_grid.add_child(badge)
			_style_grid_badge(badge, true)
			open_badge.configure_as_level(i + 1, place, true, boss, armored, stage)
			open_badge.skip_select_animation = skip_select_animation
			open_badge.pressed.connect(_on_level_chosen.bind(place, stage))
		else:
			badge = LOCKED_BADGE_SCENE.instantiate() as Control
			if badge == null:
				continue
			_level_grid.add_child(badge)
			_style_grid_badge(badge, false)
	_refresh_locked_overlay()


func _style_grid_badge(badge: Control, unlocked: bool) -> void:
	if badge == null:
		return
	var s := unlocked_badge_scale if unlocked else locked_badge_scale
	badge.custom_minimum_size = LEVEL_BADGE_SIZE * s
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.pivot_offset_ratio = Vector2(0.5, 0.5)
	badge.scale = Vector2.ONE
	badge.set_meta("level_badge_unlocked", unlocked)


func _grid_node() -> GridContainer:
	if _level_grid:
		return _level_grid
	return get_node_or_null("%LevelGrid") as GridContainer


func _capture_grid_home() -> void:
	var grid := _grid_node()
	if grid == null:
		return
	_grid_home_offset = Vector2(grid.offset_left, grid.offset_top)
	var size := Vector2(grid.offset_right - grid.offset_left, grid.offset_bottom - grid.offset_top)
	if size.x > 1.0 and size.y > 1.0:
		_grid_home_size = size
	elif grid.size.x > 1.0 and grid.size.y > 1.0:
		_grid_home_size = grid.size


func _apply_grid_position() -> void:
	var grid := _grid_node()
	if grid == null:
		return
	var pos := _grid_home_offset + level_grid_position
	var size := _grid_home_size
	if size.x < 1.0 or size.y < 1.0:
		size = grid.size
	if size.x < 1.0 or size.y < 1.0:
		return
	grid.offset_left = pos.x
	grid.offset_top = pos.y
	grid.offset_right = pos.x + size.x
	grid.offset_bottom = pos.y + size.y


func _apply_badge_layout() -> void:
	var grid := _grid_node()
	if grid == null:
		return
	for child in grid.get_children():
		if not child is Control:
			continue
		var badge := child as Control
		var unlocked := true
		if badge.has_meta("level_badge_unlocked"):
			unlocked = bool(badge.get_meta("level_badge_unlocked"))
		elif badge is LevelSelectBadgeLocked:
			unlocked = false
		_style_grid_badge(badge, unlocked)


func _refresh_locked_overlay() -> void:
	var locked := not _stage_unlocked(STAGES[_stage_index])
	if _locked_overlay:
		_locked_overlay.visible = locked
		_locked_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
		_locked_overlay.modulate.a = 1.0 if locked else 0.0
	if _locked_need_label:
		_locked_need_label.text = _stage_need_text(STAGES[_stage_index]) if locked else ""


func _stage_need_text(stage: String) -> String:
	var amount := 0
	if gl_DataSet and gl_DataSet.has_method("get_unlock_net_worth"):
		amount = int(gl_DataSet.get_unlock_net_worth(stage.to_lower()))
	var money := "$" + str(amount)
	if CommonCode and CommonCode.has_method("format_money"):
		money = String(CommonCode.format_money(amount))
	return "[center][pulse freq=8 color=#FFFFFF90]NEED %s[/pulse]" % money


func _grab_level_grid_focus() -> void:
	var first := _first_unlocked_grid_badge()
	if first:
		UiFocus.grab_in(self, first.get_node_or_null("HitButton"))
		return
	if _next_button and not _next_button.disabled:
		UiFocus.grab_in(self, _next_button)
		return
	if _prev_button and not _prev_button.disabled:
		UiFocus.grab_in(self, _prev_button)
		return
	if _header_badge:
		UiFocus.grab_in(self, _header_badge)


func _ranges_for_stage(stage: String) -> PackedStringArray:
	var path := String(LEVEL_FILES.get(stage, LEVEL_FILES["BEGINNER"]))
	if Parser and Parser.has_method("list_ranges_in_file"):
		return Parser.list_ranges_in_file(path)
	return PackedStringArray()


func _first_unlocked_grid_badge() -> DifficultyBadge:
	if _level_grid == null:
		return null
	for child in _level_grid.get_children():
		if child is DifficultyBadge and not (child as DifficultyBadge).locked:
			return child as DifficultyBadge
	return null


func _on_prev_difficulty_pressed() -> void:
	await _page_to(_stage_index - 1)


func _on_next_difficulty_pressed() -> void:
	await _page_to(_stage_index + 1)


func _page_to(index: int) -> void:
	if _busy or not _can_page_to(index):
		return
	_busy = true
	_sfx_page()
	_stage_index = index
	_store_select_difficulty()
	await _play_page_transition()
	_busy = false
	if not visible:
		return
	_grab_level_grid_focus()


func _play_page_transition() -> void:
	_pan_level_layout_for_stage()
	await _fade_out_level_badges()
	_refresh_header()
	_refresh_arrows()
	_rebuild_level_grid()
	_prepare_badges_for_appear()
	await get_tree().process_frame
	await _appear_level_badges()


func _prepare_badges_for_appear() -> void:
	if _level_grid == null:
		return
	for child in _level_grid.get_children():
		if child is Control:
			var badge := child as Control
			badge.modulate.a = 0.0
			badge.scale = Vector2.ONE * 0.01
	if _locked_overlay and _locked_overlay.visible:
		_locked_overlay.modulate.a = 0.0


func _fade_out_level_badges() -> void:
	if _level_grid == null:
		return
	var kids := _level_grid.get_children()
	if kids.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for child in kids:
		if child is Control:
			var badge := child as Control
			badge.pivot_offset = badge.size * 0.5
			tween.tween_property(badge, "modulate:a", 0.0, 0.14)
			tween.tween_property(badge, "scale", Vector2.ONE * 0.2, 0.16)
	if _locked_overlay and _locked_overlay.visible:
		tween.tween_property(_locked_overlay, "modulate:a", 0.0, 0.14)
	await tween.finished


func _appear_level_badges() -> void:
	if _level_grid == null:
		return
	var kids := _level_grid.get_children()
	if kids.is_empty():
		return
	for child in kids:
		if child is Control:
			var badge := child as Control
			badge.pivot_offset = badge.size * 0.5
			badge.modulate.a = 0.0
			badge.scale = Vector2.ONE * 0.01
	var tween := create_tween()
	tween.set_parallel(true)
	for i in kids.size():
		var child = kids[i]
		if not child is Control:
			continue
		var badge := child as Control
		var delay := float(i) * 0.055
		tween.tween_property(badge, "modulate:a", 1.0, 0.18).set_delay(delay)
		tween.tween_property(badge, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	if _locked_overlay and _locked_overlay.visible:
		tween.tween_property(_locked_overlay, "modulate:a", 1.0, 0.22).set_delay(0.08)
	await tween.finished


func _sfx_page() -> void:
	if _open_sfx:
		_open_sfx.play(0.35)
	#if _click_1:
		#_click_1.play()
	#if _click_2:
		#_click_2.play()
	#if _click_3:
		#_click_3.play()


func _store_select_difficulty() -> void:
	var stage := STAGES[_stage_index]
	if gl_PlayerState and gl_PlayerState.has_method("set_select_difficulty"):
		gl_PlayerState.set_select_difficulty(stage)
	elif gl_PlayerState:
		gl_PlayerState.dataset.select_difficulty = stage


func _on_level_chosen(place: String, stage_title: String = "BEGINNER") -> void:
	if _busy:
		return
	if not _stage_unlocked(stage_title):
		return
	place = place.strip_edges().to_lower()
	if place.is_empty():
		return
	_busy = true
	_store_select_difficulty()
	if skip_select_animation:
		close_pop_up()
	else:
		await close_pop_up_animated()
	if gl_PlayerState and gl_PlayerState.has_method("set_run_difficulty"):
		gl_PlayerState.set_run_difficulty(stage_title)
	else:
		gl_PlayerState.dataset.run_difficulty = stage_title
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("travel_to_level"):
		await rm.travel_to_level(place)
	_busy = false


func _on_back_pressed() -> void:
	if _busy:
		return
	_busy = true
	await close_pop_up_animated()
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var select_menu: Node = null
	if menus and menus.has_method("ensure_difficulty_select"):
		select_menu = menus.ensure_difficulty_select()
	if select_menu == null:
		select_menu = get_tree().get_first_node_in_group("difficulty_select")
	if select_menu == null:
		push_warning("Level select: difficulty select menu missing")
		_busy = false
		return
	if select_menu is CanvasItem:
		(select_menu as CanvasItem).z_index = 41
	if select_menu.has_method("open_pop_up"):
		await select_menu.open_pop_up()
	_busy = false


func _sfx_open() -> void:
	if _open_sfx:
		_open_sfx.play(0.3)
	if _click_1:
		_click_1.play()
	if _click_2:
		_click_2.play()
	if _click_3:
		_click_3.play()
	if _hum:
		_hum.play()


func _sfx_close() -> void:
	if _close_sfx:
		_close_sfx.play(0.5)
	#if _click_1:
		#_click_1.play()
	#if _click_2:	
		#_click_2.play()
	#if _click_3:
		#_click_3.play()
	if _hum:
		_hum.stop()


func _sfx_close_instant() -> void:
	if _hum:
		_hum.stop()


func _fade_out_ammo_hud() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("fade_out_ammo_panel"):
		player.fade_out_ammo_panel(0.33)
	elif player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
