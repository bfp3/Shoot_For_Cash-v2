extends Control
## Range-cleared reward popup: title + clear bonus → cash rollup → ammo refill → map stamp.


enum State {
	INACTIVE,
	OPEN_MENU,
	CLOSE_MENU,
}
var current_state: State = State.INACTIVE

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

var _sequence_busy := false
var _cleared_place := ""
var _clear_bonus := 0
var _display_cash := 0

@onready var cash_balance_label: RichTextLabel = %CashBalanceLabel

@onready var _text_box: RichTextLabel = %TextBOX
@onready var _retry_button: Button = find_child("Retry", true, false) as Button


func _ready() -> void:
	default_scale = scale
	default_position = position
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset
	if _retry_button:
		_retry_button.visible = false
		_retry_button.disabled = true
	_ensure_cash_roll_sfx()
	hide()


func enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.INACTIVE:
			pass
		State.OPEN_MENU:
			await update_open_menu()
		State.CLOSE_MENU:
			await update_close_menu()


## Entry point from RoundManager.start_game_over().
func update_open_menu() -> void:
	if _sequence_busy:
		return
	_sequence_busy = true
	_cleared_place = gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	_clear_bonus = _resolve_clear_bonus(_cleared_place)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	CommonCode.apply_ui_overlay_blur()
	sfx_open_menu()

	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	pivot_offset = default_pivot_offset
	show()
	_prepare_title_text()

	var open_tween := create_tween()
	open_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	open_tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	open_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await open_tween.finished

	await get_tree().create_timer(0.55, false).timeout
	await _play_cash_and_ammo_sequence()
	await get_tree().create_timer(0.5, false).timeout
	await update_close_menu()
	await _finish_to_map()
	_sequence_busy = false


func update_close_menu() -> void:
	sfx_close_menu()
	pivot_offset = default_pivot_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.01, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	await tween.finished
	scale = default_scale
	modulate.a = 1.0
	position = default_position
	hide()
	current_state = State.INACTIVE


func _prepare_title_text() -> void:
	var particles := get_node_or_null("CenterContainer/FreeParticles") as GPUParticles2D
	if particles:
		particles.emitting = true
	var title := _range_display_title(_cleared_place)
	var bonus_line := "Clear Bonus Cash: [color=#a10204]%s[/color]" % CommonCode.format_money(_clear_bonus)
	_text_box.text = (
		"[pulse][color=#a10204]%s: CLEARED[/color][/pulse]\n%s"
		% [title, bonus_line]
	)


func _play_cash_and_ammo_sequence() -> void:
	var cash_before := int(gl_PlayerState.dataset.cash)
	_display_cash = cash_before
	_set_body_text(_build_body_text(cash_before, false))

	await get_tree().create_timer(0.35, false).timeout

	## Bank clear bonus, then roll the on-screen total up.
	if _clear_bonus > 0:
		gl_PlayerState.add_cash(_clear_bonus)
	var cash_after := int(gl_PlayerState.dataset.cash)
	await _roll_cash_display(cash_before, cash_after)

	await get_tree().create_timer(0.25, false).timeout
	_refill_player_ammo()
	_set_body_text(_build_body_text(cash_after, true))
	_play_ammo_refill_sfx()
	if gl_PlayerState.has_method("save_run_checkpoint_after_round"):
		gl_PlayerState.save_run_checkpoint_after_round()


func _build_body_text(cash_amount: int, ammo_refilled: bool) -> String:
	var title := _range_display_title(_cleared_place)
	var lines: PackedStringArray = [
		"[pulse][color=#a10204]%s: CLEARED[/color][/pulse]" % title,
		"Clear Bonus Cash: [color=#a10204]%s[/color]" % CommonCode.format_money(_clear_bonus),
		"",
		"Cash: [wave amp=2.0 freq=20.0 connected=1][color=#a10204]%s[/color][/wave]" % CommonCode.format_money(cash_amount),
	]
	if ammo_refilled:
		lines.append("Ammo: [color=#a10204]REFILLED[/color]")
	return "\n".join(lines)


func _set_body_text(bbcode: String) -> void:
	if _text_box:
		_text_box.text = bbcode


func _roll_cash_display(from_cash: int, to_cash: int) -> void:
	var duration := clampf(absf(float(to_cash - from_cash)) / 80.0, 0.45, 1.6)
	_play_cash_roll_sfx(duration)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float):
			_display_cash = int(value)
			_set_body_text(_build_body_text(_display_cash, false)),
		float(from_cash),
		float(to_cash),
		duration
	)
	await tween.finished
	_display_cash = to_cash
	_set_body_text(_build_body_text(to_cash, false))


func _refill_player_ammo() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if player.has_method("refill_ammo_to_max"):
		player.refill_ammo_to_max(true)
	elif player.has_method("_refill_regular_ammo_to_max"):
		player._refill_regular_ammo_to_max()
	## Keep checkpoint ammo in sync for export saves.
	if "shot_count" in player:
		gl_PlayerState.dataset["shot_count"] = int(player.shot_count)


func _finish_to_map() -> void:
	var round_manager := get_tree().get_first_node_in_group("round_manager") as RoundManager
	if round_manager == null:
		return
	round_manager.game_over_triggered = false
	if round_manager.has_method("open_island_map_after_range_clear"):
		await round_manager.open_island_map_after_range_clear(_cleared_place)
	else:
		round_manager.enter_state(round_manager.RoundState.SHOP_START)


func _range_display_title(place: String) -> String:
	place = gl_DataSet.resolve_place_name(place)
	if place.is_empty() or place == "start":
		return "SHOOTING RANGE"
	return "%s Shooting Range" % place.capitalize()


func _resolve_clear_bonus(place: String) -> int:
	if gl_DataSet.has_method("get_range_clear_reward"):
		return int(gl_DataSet.get_range_clear_reward(place))
	return int(gl_DataSet.get_value("range_clear_reward", 0))


func _ensure_cash_roll_sfx() -> void:
	if has_node("SFX/cash_roll_up"):
		return
	var sfx := AudioStreamPlayer.new()
	sfx.name = "cash_roll_up"
	sfx.stream = load("res://sfx/misc-001.ogg")
	sfx.volume_db = -30.0
	sfx.pitch_scale = 0.5
	$SFX.add_child(sfx)


func _play_cash_roll_sfx(duration: float) -> void:
	if has_node("SFX/shop_coin_sfx_01"):
		$SFX/shop_coin_sfx_01.play()
	if has_node("SFX/cash_roll_up"):
		var roll: AudioStreamPlayer = $SFX/cash_roll_up
		roll.pitch_scale = 0.5
		roll.play()
		var pitch_tween := create_tween()
		pitch_tween.tween_property(roll, "pitch_scale", 1.8, duration)


func _play_ammo_refill_sfx() -> void:
	if has_node("SFX/shop_purchase_01"):
		$SFX/shop_purchase_01.play()
	if has_node("SFX/shop_coin_sfx_01"):
		$SFX/shop_coin_sfx_01.play()


func sfx_open_menu() -> void:
	$SFX/shop_open_sfx_01.play(0.3)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.play()


func sfx_close_menu() -> void:
	$SFX/shop_close_sfx_01.play(0.5)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.stop()


## Legacy button path (hidden) — keep as manual escape if re-enabled.
func _on_retry_pressed() -> void:
	if _sequence_busy:
		return
	await update_close_menu()
	await _finish_to_map()
