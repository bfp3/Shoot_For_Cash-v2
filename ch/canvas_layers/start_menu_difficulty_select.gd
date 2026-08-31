extends Control

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var _busy := false

@onready var _buttons: Node = %DifficultySelectButtons
@onready var _challenge_buttons: Node = %SpecialChallengeButtons
@onready var _back_button: Button = %MapButton
@onready var _net_worth_root: Control = get_node_or_null("%NetWorth") as Control
@onready var _open_sfx: AudioStreamPlayer = get_node_or_null("SFX/shop_open_sfx_01")
@onready var _close_sfx: AudioStreamPlayer = get_node_or_null("SFX/shop_close_sfx_01")
@onready var _click_1: AudioStreamPlayer = get_node_or_null("SFX/hud_click_1")
@onready var _click_2: AudioStreamPlayer = get_node_or_null("SFX/hud_click_2")
@onready var _click_3: AudioStreamPlayer = get_node_or_null("SFX/hud_click_3")
@onready var _hum: AudioStreamPlayer = get_node_or_null("SFX/low_humming")


func _ready() -> void:
	add_to_group("difficulty_select")
	default_scale = scale
	default_position = position
	pivot_offset_ratio = Vector2(0.5, 0.5)
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _buttons and _buttons.has_signal("difficulty_chosen"):
		_buttons.difficulty_chosen.connect(_on_difficulty_chosen)
	if _buttons and _buttons.has_signal("level_chosen"):
		_buttons.level_chosen.connect(_on_legacy_level_chosen)
	if _challenge_buttons and _challenge_buttons.has_signal("level_chosen"):
		_challenge_buttons.level_chosen.connect(_on_legacy_level_chosen)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)


func open_pop_up() -> void:
	_busy = false
	_restore_badges()
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	show()
	CommonCode.apply_ui_overlay_blur()
	_sfx_open()
	_refresh_net_worth()
	_reset_level_layout_pan()
	_play_title_select_music()
	if _buttons and _buttons.has_method("refresh_unlocks"):
		_buttons.refresh_unlocks()
	if _challenge_buttons and _challenge_buttons.has_method("refresh_unlocks"):
		_challenge_buttons.refresh_unlocks()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await tween.finished
	if _buttons:
		var beginner := _buttons.get_node_or_null("Beginner") as Control
		UiFocus.grab_in(self, beginner)


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
	_restore_badges()


func _restore_badges() -> void:
	if _challenge_buttons and _challenge_buttons.has_method("reset_row_layout"):
		_challenge_buttons.reset_row_layout()
	for node in find_children("*", "DifficultyBadge", true, false):
		if node.has_method("reset_selection_state"):
			node.reset_selection_state()


func _refresh_net_worth() -> void:
	if _net_worth_root and _net_worth_root.has_method("refresh"):
		_net_worth_root.refresh()


func _reset_level_layout_pan() -> void:
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("reset_level_layout_pan"):
		rm.reset_level_layout_pan()


func _play_title_select_music() -> void:
	var music := get_tree().get_first_node_in_group("level_music")
	if music and music.has_method("play_title_select_music"):
		music.play_title_select_music()


func _on_difficulty_chosen(stage_title: String) -> void:
	if _busy:
		return
	var stage := stage_title.strip_edges().to_upper()
	stage = stage.replace("[WAVE]", "").replace("[/WAVE]", "")
	if stage.is_empty() or stage == "???":
		stage = "BEGINNER"
	_busy = true
	if gl_PlayerState and gl_PlayerState.has_method("set_select_difficulty"):
		gl_PlayerState.set_select_difficulty(stage)
	if gl_PlayerState and gl_PlayerState.has_method("set_run_difficulty"):
		gl_PlayerState.set_run_difficulty(stage)
	await close_pop_up_animated()
	await _open_level_select(stage)
	_busy = false


func _open_level_select(stage: String) -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var level_menu: Node = null
	if menus and menus.has_method("ensure_level_select"):
		level_menu = menus.ensure_level_select()
	if level_menu == null:
		level_menu = get_tree().get_first_node_in_group("level_select")
	if level_menu == null:
		push_warning("Difficulty select: level select menu missing")
		return
	if level_menu is CanvasItem:
		(level_menu as CanvasItem).z_index = 41
	if level_menu.has_method("open_pop_up"):
		await level_menu.open_pop_up(stage)


func _on_legacy_level_chosen(place: String, stage_title: String = "BEGINNER") -> void:
	if _busy:
		return
	place = place.strip_edges().to_lower()
	if place.is_empty():
		return
	_busy = true
	await close_pop_up_animated()
	if gl_PlayerState and gl_PlayerState.has_method("set_run_difficulty"):
		gl_PlayerState.set_run_difficulty(stage_title)
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("travel_to_level"):
		await rm.travel_to_level(place)
	_busy = false


func _on_back_pressed() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_pause"):
		menus.ensure_pause()
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif pause_menu and pause_menu.has_method("start"):
		pause_menu.start()


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
	if _click_1:
		_click_1.play()
	if _click_2:
		_click_2.play()
	if _click_3:
		_click_3.play()
	if _hum:
		_hum.stop()


func _sfx_close_instant() -> void:
	if _hum:
		_hum.stop()
