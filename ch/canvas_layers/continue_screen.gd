extends CanvasLayer

## Arcade CONTINUE overlay. All widgets live in the scene tree for editor tweaks.

signal finished(outcome: String)

const OUTCOME_PAID := "paid"
const OUTCOME_FLIP_WIN := "flip_win"
const OUTCOME_GIVE_UP := "give_up"
const OUTCOME_LEVEL_SELECT := "level_select"
const ABANDON_RUN_PROMPT_PATH := "res://ch/Shop/abandon_run_prompt.tscn"
## Coin flip only offered when the round countdown is longer than this.
const COIN_FLIP_MIN_TIMER_SEC := 60.0
## Chance the coin-flip offer appears when the timer gate passes.
const COIN_FLIP_CHANCE := 0.0

@onready var _root: Control = $Control
@onready var _title: RichTextLabel = %TitleLabel
@onready var _cash: RichTextLabel = %CashLabel
@onready var _yes: Button = %PlayButton
@onready var _coin_flip: Button = %CoinFlipButton
@onready var _give_up: Button = %GiveUpButton
@onready var _level_select: Button = get_node_or_null("%LevelSelect") as Button
@onready var _guess_panel: Control = %CoinGuessPanel
@onready var _guess_title: RichTextLabel = get_node_or_null("%GuessTitle")
@onready var _heads: Button = %HeadsButton
@onready var _tails: Button = %TailsButton
@onready var _coin_heads: Control = get_node_or_null("%CoinHeads")
@onready var _coin_tails: Control = get_node_or_null("%CoinTails")
@onready var _coin_heads_hit: Button = get_node_or_null("Control/CoinHeads/HitButton")
@onready var _coin_tails_hit: Button = get_node_or_null("Control/CoinTails/HitButton")
@onready var _result: RichTextLabel = %CoinResultLabel
@onready var _resume: RichTextLabel = %ResumeCountdownLabel
@onready var _next_fee: RichTextLabel = %NextFeeLabel
@onready var _game_over: Control = %GameOver
@onready var _game_over_label: RichTextLabel = $Control/MainPanel/GameOver/GameOverLabel
@onready var _fade_to_black: ColorRect = $Control/FadeToBlack

@export var resume_from := 3
## Kept for inspector compatibility. Round manager treats paid as replay and flip_win as resume-in-place.
@export var resume_in_place := true

var _busy := false
var _waiting := false
var _resolving := false
var _fee_amount := 0
var _cash_amount := 0
var _displayed_cash := 0.0
var _cash_roll_tween: Tween
var _countdown_token := 0
var _outcome := OUTCOME_GIVE_UP
var _holding_blackout := false
var _game_over_rest_scale := Vector2(0.874, 0.874)
var _abandon_prompt: Control = null
var _coin_heads_rest_scale := Vector2.ONE
var _coin_tails_rest_scale := Vector2.ONE
var _coin_heads_home := Vector2.ZERO
var _coin_tails_home := Vector2.ZERO
var _coin_hover_enabled := false
var _coin_token := 0
var _coin_spin_showing_heads := true
var _coin_anim_tween: Tween
var _heads_hover_tween: Tween
var _tails_hover_tween: Tween
var _coin_flip_offered := false


func _ready() -> void:
	add_to_group("continue_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	hide()
	if _yes:
		_yes.pressed.connect(_on_yes_pressed)
	if _coin_flip:
		_coin_flip.pressed.connect(_on_coin_flip_pressed)
		_coin_flip.hide()
	if _give_up:
		_give_up.pressed.connect(_on_give_up_pressed)
		_give_up.hide()
	if _level_select:
		_level_select.pressed.connect(_on_level_select_pressed)
		_level_select.show()
	_setup_coin_choice_buttons()
	_setup_abandon_run_prompt()
	_reset_visuals()
	if _game_over_label:
		_game_over_rest_scale = _game_over_label.scale


func play(fee: int, cash: int) -> String:
	if _busy:
		return OUTCOME_GIVE_UP
	_busy = true
	_waiting = true
	_resolving = false
	_holding_blackout = false
	_outcome = OUTCOME_GIVE_UP
	_fee_amount = maxi(fee, 0)
	## Cash may already be negative (debt from a prior continue).
	_cash_amount = cash
	_displayed_cash = float(_cash_amount)
	_coin_flip_offered = _roll_coin_flip_offer()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reset_visuals()
	_refresh_money_labels(_cash_amount, _fee_amount)
	show()
	_play_open_sfx()
	_raise_shop_music()
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP

	if _coin_flip_offered:
		_hide_pay_buttons()
		_clear_oh_no_and_strikes()
		await _present_coin_choices()
	else:
		_show_pay_ui()
		_focus_primary()

	while _waiting and is_inside_tree():
		await get_tree().process_frame

	_busy = false
	if not _holding_blackout:
		hide()
		_reset_visuals()
	finished.emit(_outcome)
	return _outcome


func close_now() -> void:
	_waiting = false
	_busy = false
	_holding_blackout = false
	_countdown_token += 1
	_coin_token += 1
	_close_abandon_prompt()
	_lower_shop_music()
	hide()
	_reset_visuals()


func play_run_loss_overlay() -> void:
	if _busy:
		return
	_busy = true
	_waiting = true
	_resolving = true
	_holding_blackout = false
	_outcome = OUTCOME_GIVE_UP
	var prev_layer := layer
	layer = 110
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_continue_chrome_instant()
	if _game_over:
		_game_over.hide()
		_game_over.modulate.a = 1.0
	if _game_over_label:
		_game_over_label.scale = _game_over_rest_scale
	if _fade_to_black:
		_fade_to_black.hide()
		_fade_to_black.modulate.a = 0.0
		_fade_to_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show()
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	await _play_game_over_sequence()
	layer = prev_layer
	_busy = false


func _hide_continue_chrome_instant() -> void:
	_hide_overlay_strikes()
	_reset_coin_nodes()
	var panel := _root.get_node_or_null("MainPanel") as Control if _root else null
	if panel == null:
		return
	for child in panel.get_children():
		if child == _game_over:
			continue
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 0.0


func _reset_visuals() -> void:
	_close_abandon_prompt()
	if _cash_roll_tween and _cash_roll_tween.is_valid():
		_cash_roll_tween.kill()
	_cash_roll_tween = null
	if _cash:
		_cash.scale = Vector2.ONE

	if _guess_panel:
		_guess_panel.hide()
		_guess_panel.modulate.a = 1.0
	if _guess_title:
		_guess_title.modulate.a = 0.0
	_reset_coin_nodes()
	if _result:
		_result.hide()
		_result.text = ""
	if _resume:
		_resume.hide()
		_resume.text = ""
	if _next_fee:
		_next_fee.hide()
		_next_fee.text = ""

	if _title:
		#_title.text = "[center][wave]CONTINUE?"
		_title.text = ""
	if _yes:
		_yes.disabled = false
		_yes.show()
	if _coin_flip:
		_coin_flip.disabled = true
		_coin_flip.hide()
	if _give_up:
		## Bail / give-up is retired — continue is pay (or coin flip) only.
		_give_up.disabled = true
		_give_up.hide()
	if _level_select:
		_level_select.disabled = false
		_level_select.show()
	if _heads:
		_heads.disabled = false
		_heads.hide()
	if _tails:
		_tails.disabled = false
		_tails.hide()
	_set_coin_buttons_enabled(false)
	_restore_continue_chrome()
	if _game_over:
		_game_over.hide()
		_game_over.modulate.a = 1.0
	if _game_over_label:
		_game_over_label.scale = _game_over_rest_scale
		_game_over_label.modulate.a = 1.0
	if _fade_to_black:
		_fade_to_black.hide()
		_fade_to_black.modulate.a = 0.0
		_fade_to_black.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_money_labels(cash: int, fee: int) -> void:
	_displayed_cash = float(cash)
	_set_cash_text(float(cash))
	_set_play_button_cost(fee)

func _set_play_button_cost(price: int) -> void:
	if _yes == null:
		return
	var cost := _yes.find_child("CostLabel", true, false) as RichTextLabel
	if cost:
		if price <= 0:
			cost.text = "[wave]FREE"
		else:
			cost.text = "[wave]%s" % CommonCode.format_money(price)


func _set_cash_text(value: float) -> void:
	_displayed_cash = value
	if _cash:
		_cash.text = "[wave]" + CommonCode.format_money(int(round(value)))


func _roll_cash_to(target: int, duration: float = 0.45) -> void:
	## Allow negative targets so debt from continue is visible.
	var to := float(target)
	var from := _displayed_cash
	if _cash_roll_tween and _cash_roll_tween.is_valid():
		_cash_roll_tween.kill()
	_cash_roll_tween = null
	if _cash == null or is_equal_approx(from, to):
		_set_cash_text(to)
		return
	_cash_roll_tween = create_tween()
	_cash_roll_tween.tween_method(_set_cash_text, from, to, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cash.pivot_offset = _cash.size * 0.5
	var punch := create_tween()
	punch.tween_property(_cash, "scale", Vector2.ONE * 1.08, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(_cash, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _cash_roll_tween.finished


func _roll_coin_flip_offer() -> bool:
	var timer_sec := _current_round_timer_seconds()
	if timer_sec <= COIN_FLIP_MIN_TIMER_SEC:
		return false
	return randf() < COIN_FLIP_CHANCE


func _current_round_timer_seconds() -> float:
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm == null:
		return 0.0
	if rm.has_method("get_current_countdown_seconds"):
		return float(rm.get_current_countdown_seconds())
	if rm.has_method("get_active_timer_seconds"):
		var s := float(rm.get_active_timer_seconds())
		if s > 0.0:
			return s
	var timer = rm.get("round_timer") if "round_timer" in rm else null
	if timer and float(timer.get("start_time")) > 0.0:
		return float(timer.start_time)
	return 0.0


func _hide_pay_buttons() -> void:
	if _yes:
		_yes.hide()
		_yes.disabled = true
	if _coin_flip:
		_coin_flip.hide()
		_coin_flip.disabled = true
	if _give_up:
		_give_up.hide()
		_give_up.disabled = true


func _show_pay_ui() -> void:
	if _yes:
		_yes.visible = true
		_yes.disabled = false
	if _coin_flip:
		_coin_flip.hide()
		_coin_flip.disabled = true
	if _give_up:
		_give_up.hide()
		_give_up.disabled = true
	if _level_select:
		_level_select.visible = true
		_level_select.disabled = false


func _focus_primary() -> void:
	if _yes and _yes.visible:
		UiFocus.grab_in(_root, _yes)
	elif _coin_heads_hit and _coin_heads_hit.visible and not _coin_heads_hit.disabled:
		UiFocus.grab_in(_root, _coin_heads_hit)


func _on_yes_pressed() -> void:
	if not _waiting or _resolving:
		return
	_resolving = true
	if gl_PlayerState == null or not gl_PlayerState.has_method("pay_continue_fee"):
		_finish(OUTCOME_GIVE_UP)
		return
	var from_cash := _cash_amount
	## Always succeeds; may put the wallet into debt.
	gl_PlayerState.pay_continue_fee()
	_lock_actions()
	_cash_amount = int(gl_PlayerState.get_spendable_cash()) if gl_PlayerState.has_method("get_spendable_cash") else from_cash - _fee_amount
	_displayed_cash = float(from_cash)
	_set_cash_text(float(from_cash))
	_play_coin_sfx()
	await _roll_cash_to(_cash_amount)
	if not _waiting:
		return

	await get_tree().create_timer(1.0, true).timeout
	if not _waiting:
		return
	_finish(OUTCOME_PAID)


func _on_coin_flip_pressed() -> void:
	if not _waiting or _resolving:
		return
	_hide_pay_buttons()
	_clear_oh_no_and_strikes()
	await _present_coin_choices()


func _on_guess(picked_heads: bool) -> void:
	if not _waiting or _resolving:
		return
	_resolving = true
	_coin_hover_enabled = false
	_lock_actions()
	var token := _coin_token
	if _guess_title:
		var title_fade := create_tween()
		title_fade.tween_property(_guess_title, "modulate:a", 0.0, 0.15)
	var other := _coin_tails if picked_heads else _coin_heads
	if other:
		var other_fade := create_tween()
		other_fade.tween_property(other, "modulate:a", 0.0, 0.2)
	var picked := _coin_heads if picked_heads else _coin_tails
	if picked:
		await _blink_coin(picked, 1.0)
	if not _coin_still_active(token):
		return
	await _play_coin_spin(picked_heads)
	if not _coin_still_active(token):
		return
	var landed_heads := _coin_spin_showing_heads
	var won := picked_heads == landed_heads
	if won:
		_play_named_sfx("coin_win_jingle")
		if gl_PlayerState and gl_PlayerState.has_method("continue_from_coin_flip"):
			gl_PlayerState.continue_from_coin_flip()
		await _fade_coin_toss_out(1.0)
		if not _coin_still_active(token):
			return
		_finish(OUTCOME_FLIP_WIN)
	else:
		_play_named_sfx("coin_fail_jingle")
		await get_tree().create_timer(1.0, true).timeout
		if not _coin_still_active(token):
			return
		await _return_to_pay_ui_after_failed_flip()


func _return_to_pay_ui_after_failed_flip() -> void:
	await _fade_coin_toss_out(0.35)
	_reset_coin_nodes()
	if _guess_panel:
		_guess_panel.hide()
		_guess_panel.modulate.a = 1.0
	if _guess_title:
		_guess_title.modulate.a = 0.0
	_restore_continue_chrome()
	_resolving = false
	_show_pay_ui()
	_unlock_actions()
	_focus_primary()


func _on_level_select_pressed() -> void:
	if not _waiting or _resolving:
		return
	_resolving = true
	_lock_actions()
	_finish(OUTCOME_LEVEL_SELECT)


func _on_give_up_pressed() -> void:
	if not _waiting or _resolving:
		return
	if _abandon_prompt and _abandon_prompt.visible:
		return
	_lock_actions()
	_open_abandon_prompt()


func _setup_abandon_run_prompt() -> void:
	if _abandon_prompt and is_instance_valid(_abandon_prompt):
		return
	var packed := load(ABANDON_RUN_PROMPT_PATH) as PackedScene
	if packed == null:
		push_warning("Continue screen: abandon run prompt missing")
		return
	_abandon_prompt = packed.instantiate() as Control
	if _abandon_prompt == null:
		return
	_abandon_prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_abandon_prompt.z_index = 120
	if _root:
		_root.add_child(_abandon_prompt)
	else:
		add_child(_abandon_prompt)
	_abandon_prompt.hide()
	if _abandon_prompt.has_signal("confirmed"):
		_abandon_prompt.confirmed.connect(_on_abandon_run_confirmed)
	if _abandon_prompt.has_signal("cancelled"):
		_abandon_prompt.cancelled.connect(_on_abandon_run_cancelled)


func _open_abandon_prompt() -> void:
	if _abandon_prompt and _abandon_prompt.has_method("open_prompt"):
		_abandon_prompt.open_prompt()
		return
	_on_abandon_run_confirmed()


func _close_abandon_prompt() -> void:
	if _abandon_prompt and _abandon_prompt.has_method("close_prompt"):
		_abandon_prompt.close_prompt()


func _on_abandon_run_cancelled() -> void:
	_unlock_actions()
	_focus_primary()


func _on_abandon_run_confirmed() -> void:
	if _resolving:
		return
	_resolving = true
	if _abandon_prompt and _abandon_prompt.has_method("close_prompt"):
		await _abandon_prompt.close_prompt()
	_lock_actions()
	await _play_game_over_sequence()
	if not _waiting:
		return
	_finish(OUTCOME_GIVE_UP)


func _unlock_actions() -> void:
	_show_pay_ui()
	if _heads:
		_heads.disabled = false
	if _tails:
		_tails.disabled = false


func _lock_actions() -> void:
	_countdown_token += 1
	if _yes:
		_yes.disabled = true
	if _coin_flip:
		_coin_flip.disabled = true
	if _give_up:
		_give_up.disabled = true
	if _level_select:
		_level_select.disabled = true
	if _heads:
		_heads.disabled = true
	if _tails:
		_tails.disabled = true
	_set_coin_buttons_enabled(false)


func _finish(outcome: String) -> void:
	if not _waiting:
		return
	_outcome = outcome
	_waiting = false
	_countdown_token += 1
	_lower_shop_music()
	if not _holding_blackout:
		hide()
		_play_close_sfx()


func _play_open_sfx() -> void:
	var open_sfx := get_node_or_null("SFX/shop_open_sfx_01") as AudioStreamPlayer
	if open_sfx:
		open_sfx.play(0.3)
	for name in ["hud_click_1", "hud_click_2", "hud_click_3"]:
		var player := get_node_or_null("SFX/%s" % name) as AudioStreamPlayer
		if player:
			player.play()


func _play_close_sfx() -> void:
	var close_sfx := get_node_or_null("SFX/shop_close_sfx_01") as AudioStreamPlayer
	if close_sfx:
		close_sfx.play(0.5)


func _play_coin_sfx() -> void:
	var coin := get_node_or_null("SFX/coin_sfx") as AudioStreamPlayer
	if coin:
		coin.play()
	var click := get_node_or_null("SFX/hud_click_1") as AudioStreamPlayer
	if click:
		click.play()


func _setup_coin_choice_buttons() -> void:
	_cache_coin_homes()
	call_deferred("_cache_coin_homes")
	if _coin_heads_hit:
		_coin_heads_hit.pressed.connect(_on_guess.bind(true))
		_coin_heads_hit.mouse_entered.connect(_on_coin_hover.bind(true, true))
		_coin_heads_hit.mouse_exited.connect(_on_coin_hover.bind(true, false))
	elif _heads:
		_heads.pressed.connect(_on_guess.bind(true))
	if _coin_tails_hit:
		_coin_tails_hit.pressed.connect(_on_guess.bind(false))
		_coin_tails_hit.mouse_entered.connect(_on_coin_hover.bind(false, true))
		_coin_tails_hit.mouse_exited.connect(_on_coin_hover.bind(false, false))
	elif _tails:
		_tails.pressed.connect(_on_guess.bind(false))


func _cache_coin_homes() -> void:
	if _coin_heads:
		_coin_heads_rest_scale = _coin_heads.scale
		_coin_heads_home = _coin_heads.position
	if _coin_tails:
		_coin_tails_rest_scale = _coin_tails.scale
		_coin_tails_home = _coin_tails.position


func _reset_coin_nodes() -> void:
	_coin_token += 1
	_coin_hover_enabled = false
	if _coin_anim_tween and _coin_anim_tween.is_valid():
		_coin_anim_tween.kill()
	_coin_anim_tween = null
	if _heads_hover_tween and _heads_hover_tween.is_valid():
		_heads_hover_tween.kill()
	_heads_hover_tween = null
	if _tails_hover_tween and _tails_hover_tween.is_valid():
		_tails_hover_tween.kill()
	_tails_hover_tween = null
	if _coin_heads:
		_coin_heads.hide()
		_coin_heads.visible = false
		_coin_heads.modulate.a = 1.0
		_coin_heads.scale = _coin_heads_rest_scale
		_coin_heads.position = _coin_heads_home
	if _coin_tails:
		_coin_tails.hide()
		_coin_tails.visible = false
		_coin_tails.modulate.a = 1.0
		_coin_tails.scale = _coin_tails_rest_scale
		_coin_tails.position = _coin_tails_home
	_set_coin_buttons_enabled(false)


func _set_coin_buttons_enabled(enabled: bool) -> void:
	if _coin_heads_hit:
		_coin_heads_hit.disabled = not enabled
		_coin_heads_hit.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _coin_tails_hit:
		_coin_tails_hit.disabled = not enabled
		_coin_tails_hit.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _coin_still_active(token: int) -> bool:
	return _waiting and token == _coin_token and is_inside_tree()


func _clear_oh_no_and_strikes() -> void:
	_hide_overlay_strikes()
	var rm := get_tree().get_first_node_in_group("round_manager")
	var feedback = rm.get("wave_progress_feedback") if rm else null
	if feedback and feedback.has_method("hide_strike_hud"):
		feedback.hide_strike_hud()
	if feedback:
		var notice = feedback.get_node_or_null("MakeStrikeNoticeable")
		if notice:
			if notice.has_method("stop"):
				notice.stop()
			notice.hide()
	var strike_hud = feedback.get("strike_hud") if feedback else null
	if strike_hud and strike_hud.has_method("stop_strike_notices"):
		strike_hud.stop_strike_notices()


func _present_coin_choices() -> void:
	var token := _coin_token
	_coin_hover_enabled = false
	_set_coin_buttons_enabled(false)
	if _heads:
		_heads.hide()
	if _tails:
		_tails.hide()
	if _guess_panel:
		_guess_panel.show()
		_guess_panel.modulate.a = 1.0
	if _guess_title:
		_guess_title.show()
		_guess_title.modulate.a = 0.0
	if _coin_anim_tween and _coin_anim_tween.is_valid():
		_coin_anim_tween.kill()
	_coin_anim_tween = create_tween()
	_coin_anim_tween.set_parallel(true)
	if _guess_title:
		_coin_anim_tween.tween_property(_guess_title, "modulate:a", 1.0, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _coin_heads:
		_prepare_coin_for_pop(_coin_heads, _coin_heads_home)
		_coin_anim_tween.tween_property(_coin_heads, "scale", _coin_heads_rest_scale, 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_coin_anim_tween.tween_callback(_play_coin_appear_sfx)
	if _coin_tails:
		_coin_tails.position = _coin_tails_home
		_coin_tails.modulate.a = 1.0
		_coin_tails.scale = Vector2.ONE / 99.0
		_coin_tails.hide()
		_coin_anim_tween.tween_callback(_coin_tails.show).set_delay(0.25)
		_coin_anim_tween.tween_property(_coin_tails, "scale", _coin_tails_rest_scale, 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
		_coin_anim_tween.tween_callback(_play_coin_appear_sfx).set_delay(0.25)
	if _coin_anim_tween.is_valid():
		await _coin_anim_tween.finished
	if not _coin_still_active(token):
		return
	_coin_hover_enabled = true
	_set_coin_buttons_enabled(true)
	if _coin_heads_hit:
		UiFocus.grab_in(_root, _coin_heads_hit)


func _prepare_coin_for_pop(coin: Control, home: Vector2) -> void:
	if coin == null:
		return
	coin.position = home
	coin.modulate.a = 1.0
	coin.scale = Vector2.ONE / 99.0
	coin.show()


func _play_coin_appear_sfx() -> void:
	var open_sfx := get_node_or_null("SFX/shop_open_sfx_01") as AudioStreamPlayer
	if open_sfx:
		open_sfx.stop()
		open_sfx.play(0.3)
	var click := get_node_or_null("SFX/hud_click_1") as AudioStreamPlayer
	if click:
		click.stop()
		click.play()


func _on_coin_hover(is_heads: bool, inside: bool) -> void:
	if not _coin_hover_enabled or _resolving or not is_inside_tree():
		return
	var coin := _coin_heads if is_heads else _coin_tails
	if coin == null or not coin.visible:
		return
	var rest := _coin_heads_rest_scale if is_heads else _coin_tails_rest_scale
	_play_coin_node_sfx(coin, "focus_enter_sfx" if inside else "focus_exit")
	var hover_tween := _heads_hover_tween if is_heads else _tails_hover_tween
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := rest * (1.06 if inside else 1.0)
	hover_tween.tween_property(coin, "scale", target, 0.12)
	if is_heads:
		_heads_hover_tween = hover_tween
	else:
		_tails_hover_tween = hover_tween


func _play_coin_node_sfx(coin: Control, sfx_name: String) -> void:
	if coin == null:
		return
	var player := coin.get_node_or_null("SFX/%s" % sfx_name) as AudioStreamPlayer
	if player == null:
		return
	player.stop()
	player.play()


func _blink_coin(coin: Control, duration: float) -> void:
	if coin == null:
		return
	var token := _coin_token
	var elapsed := 0.0
	var shown := true
	while elapsed < duration and _coin_still_active(token):
		shown = not shown
		coin.visible = shown
		var step := 0.08
		await get_tree().create_timer(step, true).timeout
		elapsed += step
	if _coin_still_active(token) and coin:
		coin.visible = true
		coin.show()


func _play_coin_spin(start_heads: bool) -> void:
	var token := _coin_token
	if _guess_title:
		var fade := create_tween()
		fade.tween_property(_guess_title, "modulate:a", 0.0, 0.15)
	_place_coins_for_spin()
	_show_spin_face(start_heads)
	_play_named_sfx("coin_flicker")
	var landed_heads := randi() % 2 == 0
	var showing := start_heads
	var flips := 12 if showing == landed_heads else 13
	for i in flips:
		if not _coin_still_active(token):
			return
		var t := 0.0 if flips <= 1 else float(i) / float(flips - 1)
		var half := lerpf(0.035, 0.2, t * t)
		showing = not showing
		await _animate_spin_flip(showing, half)
	if not _coin_still_active(token):
		return
	var flicker := get_node_or_null("SFX/coin_flicker") as AudioStreamPlayer
	if flicker and flicker.playing:
		flicker.stop()
	if _coin_spin_showing_heads != landed_heads:
		await _animate_spin_flip(landed_heads, 0.22)
	await get_tree().create_timer(0.35, true).timeout


func _place_coins_for_spin() -> void:
	var spin_pos := _coin_heads_home
	if _coin_heads and _coin_tails:
		spin_pos = (_coin_heads_home + _coin_tails_home) * 0.5
	elif _coin_tails:
		spin_pos = _coin_tails_home
	if _heads_hover_tween and _heads_hover_tween.is_valid():
		_heads_hover_tween.kill()
	if _tails_hover_tween and _tails_hover_tween.is_valid():
		_tails_hover_tween.kill()
	if _coin_heads:
		_coin_heads.position = spin_pos
		_coin_heads.scale = _coin_heads_rest_scale
		_coin_heads.modulate.a = 1.0
	if _coin_tails:
		_coin_tails.position = spin_pos
		_coin_tails.scale = _coin_tails_rest_scale
		_coin_tails.modulate.a = 1.0


func _show_spin_face(heads: bool) -> void:
	_coin_spin_showing_heads = heads
	if _coin_heads:
		_coin_heads.visible = heads
		if heads:
			_coin_heads.show()
		else:
			_coin_heads.hide()
	if _coin_tails:
		_coin_tails.visible = not heads
		if heads:
			_coin_tails.hide()
		else:
			_coin_tails.show()


func _animate_spin_flip(to_heads: bool, half: float) -> void:
	if to_heads == _coin_spin_showing_heads:
		return
	var from := _coin_heads if _coin_spin_showing_heads else _coin_tails
	var to := _coin_heads if to_heads else _coin_tails
	var from_rest := _coin_heads_rest_scale if _coin_spin_showing_heads else _coin_tails_rest_scale
	var to_rest := _coin_heads_rest_scale if to_heads else _coin_tails_rest_scale
	if from == null or to == null:
		_show_spin_face(to_heads)
		return
	var edge := Vector2(0.001, from_rest.y * 1.12)
	if _coin_anim_tween and _coin_anim_tween.is_valid():
		_coin_anim_tween.kill()
	_coin_anim_tween = create_tween()
	_coin_anim_tween.tween_property(from, "scale", edge, maxf(half, 0.01))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _coin_anim_tween.finished
	if not _waiting or from == null or to == null:
		return
	from.hide()
	from.scale = from_rest
	to.scale = Vector2(0.001, to_rest.y * 1.12)
	to.show()
	_coin_anim_tween = create_tween()
	_coin_anim_tween.tween_property(to, "scale", to_rest, maxf(half, 0.01))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _coin_anim_tween.finished
	if not _waiting:
		return
	_coin_spin_showing_heads = to_heads


func _fade_coin_toss_out(duration: float) -> void:
	if _coin_anim_tween and _coin_anim_tween.is_valid():
		_coin_anim_tween.kill()
	_coin_anim_tween = create_tween()
	_coin_anim_tween.set_parallel(true)
	for coin in [_coin_heads, _coin_tails]:
		if coin and coin.visible:
			_coin_anim_tween.tween_property(coin, "modulate:a", 0.0, duration)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _guess_title:
		_coin_anim_tween.tween_property(_guess_title, "modulate:a", 0.0, minf(duration, 0.35))\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _guess_panel:
		_coin_anim_tween.tween_property(_guess_panel, "modulate:a", 0.0, minf(duration, 0.35))\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _coin_anim_tween.finished
	if _coin_heads:
		_coin_heads.hide()
	if _coin_tails:
		_coin_tails.hide()


func _play_named_sfx(sfx_name: String) -> void:
	var player := get_node_or_null("SFX/%s" % sfx_name) as AudioStreamPlayer
	if player == null:
		return
	player.stop()
	player.play()


func _raise_shop_music() -> void:
	_music_call("ensure_shop_music_playing")
	_music_call("raise_shop_menu_music")


func _lower_shop_music() -> void:
	_music_call("lower_shop_menu_music")


func _music_call(method_name: String) -> void:
	var music := get_tree().get_first_node_in_group("level_music")
	if music == null:
		var rm := get_tree().get_first_node_in_group("round_manager")
		if rm:
			music = rm.get("music_manager")
	if music and music.has_method(method_name):
		music.call(method_name)


func _hide_gameplay_strikes() -> void:
	_hide_overlay_strikes()
	var rm := get_tree().get_first_node_in_group("round_manager")
	var feedback = rm.get("wave_progress_feedback") if rm else null
	if feedback and feedback.has_method("hide_strike_hud_now"):
		feedback.hide_strike_hud_now()
	elif feedback and feedback.has_method("hide_strike_hud"):
		feedback.hide_strike_hud()
	if feedback is CanvasItem:
		(feedback as CanvasItem).hide()


func _overlay_strike_host() -> Control:
	return _root.get_node_or_null("MainPanel/Control") as Control if _root else null


func _hide_overlay_strikes() -> void:
	var host := _overlay_strike_host()
	if host == null:
		return
	var pulse := host.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if pulse:
		pulse.stop()
	host.hide()
	host.modulate.a = 0.0


func _play_game_over_sequence() -> void:
	_hide_gameplay_strikes()
	_lock_actions()
	await _fade_continue_chrome()
	if not _waiting:
		return
	await _stamp_game_over()
	if not _waiting:
		return
	await get_tree().create_timer(2.0, true).timeout
	if not _waiting:
		return
	_holding_blackout = true
	await _fade_screen_to_black()
	if not _waiting:
		return
	await get_tree().create_timer(2.0, true).timeout


func _fade_continue_chrome() -> void:
	_hide_overlay_strikes()
	var panel := _root.get_node_or_null("MainPanel") as Control if _root else null
	if panel == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_interval(0.01)
	for child in panel.get_children():
		if child == _game_over:
			continue
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.4)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for coin in [_coin_heads, _coin_tails]:
		if coin and coin.visible:
			tween.tween_property(coin, "modulate:a", 0.0, 0.4)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished


func _restore_continue_chrome() -> void:
	var panel := _root.get_node_or_null("MainPanel") as Control if _root else null
	if panel == null:
		return
	for child in panel.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 1.0
	var host := _overlay_strike_host()
	if host:
		host.show()
		host.modulate.a = 1.0
		var pulse := host.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if pulse:
			pulse.play("pulse")


func _stamp_game_over() -> void:
	if _game_over == null:
		return
	_game_over.show()
	_game_over.modulate.a = 0.0
	if _game_over_label:
		_game_over_label.scale = _game_over_rest_scale * 3.0
	var stamp_sfx := get_node_or_null("SFX/Stamp_sfx") as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(_game_over, "modulate:a", 1.0, 0.2)
	if _game_over_label:
		tween.parallel().tween_property(_game_over_label, "scale", _game_over_rest_scale, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	await tween.finished


func _fade_screen_to_black() -> void:
	if _fade_to_black == null:
		return
	_fade_to_black.show()
	_fade_to_black.modulate.a = 0.0
	_fade_to_black.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade_to_black, "modulate:a", 1.0, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
