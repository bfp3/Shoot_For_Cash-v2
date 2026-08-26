extends CanvasLayer

## Arcade CONTINUE overlay. All widgets live in the scene tree for editor tweaks.

signal finished(outcome: String)

const OUTCOME_PAID := "paid"
const OUTCOME_FLIP_WIN := "flip_win"
const OUTCOME_GIVE_UP := "give_up"

@onready var _root: Control = $Control
@onready var _title: RichTextLabel = %TitleLabel
@onready var _countdown: RichTextLabel = %CountdownLabel
@onready var _cash: RichTextLabel = %CashLabel
@onready var _fee: RichTextLabel = %FeeLabel
@onready var _left: RichTextLabel = %LeftLabel
@onready var _status: RichTextLabel = %StatusLabel
@onready var _yes: Button = %PlayButton
#@onready var _yes: Button = %YesButton
@onready var _coin_flip: Button = %CoinFlipButton
@onready var _give_up: Button = %GiveUpButton
@onready var _guess_panel: Control = %CoinGuessPanel
@onready var _heads: Button = %HeadsButton
@onready var _tails: Button = %TailsButton
@onready var _result: RichTextLabel = %CoinResultLabel
@onready var _resume: RichTextLabel = %ResumeCountdownLabel
@onready var _next_fee: RichTextLabel = %NextFeeLabel

@export var resume_from := 3
## When true (default), a paid continue resumes mid-wave. When false, PLAY / YES
## restarts the current round from the beginning (no shop, no checkpoint resume).
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


func _ready() -> void:
	add_to_group("continue_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	hide()
	if _yes:
		_yes.pressed.connect(_on_yes_pressed)
	if _coin_flip:
		_coin_flip.pressed.connect(_on_coin_flip_pressed)
	if _give_up:
		_give_up.pressed.connect(_on_give_up_pressed)
	if _heads:
		_heads.pressed.connect(_on_guess.bind(true))
	if _tails:
		_tails.pressed.connect(_on_guess.bind(false))
	_reset_visuals()


func play(fee: int, cash: int) -> String:
	if _busy:
		return OUTCOME_GIVE_UP
	_busy = true
	_waiting = true
	_resolving = false
	_outcome = OUTCOME_GIVE_UP
	_fee_amount = maxi(fee, 0)
	_cash_amount = maxi(cash, 0)
	_displayed_cash = float(_cash_amount)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reset_visuals()
	_refresh_money_labels(_cash_amount, _fee_amount)
	_show_afford_or_flip()
	show()
	_play_open_sfx()
	_raise_shop_music()
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_focus_primary()

	while _waiting and is_inside_tree():
		await get_tree().process_frame

	_busy = false
	hide()
	_reset_visuals()
	finished.emit(_outcome)
	return _outcome


func close_now() -> void:
	_waiting = false
	_busy = false
	_countdown_token += 1
	_lower_shop_music()
	hide()
	_reset_visuals()


func _reset_visuals() -> void:
	if _cash_roll_tween and _cash_roll_tween.is_valid():
		_cash_roll_tween.kill()
	_cash_roll_tween = null
	if _cash:
		_cash.scale = Vector2.ONE
	if _countdown:
		_countdown.hide()
		_countdown.text = ""
	if _guess_panel:
		_guess_panel.hide()
	if _result:
		_result.hide()
		_result.text = ""
	if _resume:
		_resume.hide()
		_resume.text = ""
	if _next_fee:
		_next_fee.hide()
		_next_fee.text = ""
	if _status:
		_status.text = ""
	if _title:
		#_title.text = "[center][wave]CONTINUE?"
		_title.text = ""
	if _yes:
		_yes.disabled = false
		_yes.show()
	if _coin_flip:
		_coin_flip.disabled = false
		_coin_flip.hide()
	if _give_up:
		_give_up.disabled = false
		#_give_up.show()
		_give_up.hide()
	if _heads:
		_heads.disabled = false
	if _tails:
		_tails.disabled = false


func _refresh_money_labels(cash: int, fee: int) -> void:
	_displayed_cash = float(cash)
	_set_cash_text(float(cash))
	if _fee:
		#_fee.text = "[pulse]CONTINUE −%s" % CommonCode.format_money(fee)
		_fee.text = "CONTINUE"
	_set_play_button_cost(fee)
	var leftover := cash - fee
	if _left:
		if leftover >= 0:
			_left.text = "LEFT      %s" % CommonCode.format_money(leftover)
		else:
			_left.text = "LEFT      %s" % CommonCode.format_money(cash)


func _set_play_button_cost(price: int) -> void:
	if _yes == null:
		return
	var cost := _yes.find_child("CostLabel", true, false) as RichTextLabel
	if cost:
		cost.text = "[wave]%s" % CommonCode.format_money(price)


func _set_cash_text(value: float) -> void:
	_displayed_cash = value
	if _cash:
		_cash.text = "[wave]" + CommonCode.format_money(int(round(value)))


func _roll_cash_to(target: int, duration: float = 0.45) -> void:
	var to := float(maxi(target, 0))
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


func _show_afford_or_flip() -> void:
	var can_pay := _cash_amount >= _fee_amount
	if _yes:
		_yes.visible = can_pay
		_yes.disabled = not can_pay
	if _coin_flip:
		_coin_flip.visible = not can_pay
		_coin_flip.disabled = can_pay
	if _status:
		if can_pay:
			_status.text = ""
		else:
			_status.text = "[center]NOT ENOUGH — FLIP TO STAY IN"


func _focus_primary() -> void:
	if _yes and _yes.visible:
		UiFocus.grab_in(_root, _yes)
	elif _coin_flip and _coin_flip.visible:
		UiFocus.grab_in(_root, _coin_flip)
	elif _give_up:
		UiFocus.grab_in(_root, _give_up)


func _on_yes_pressed() -> void:
	if not _waiting or _resolving:
		return
	_resolving = true
	if gl_PlayerState == null or not gl_PlayerState.has_method("pay_continue_fee"):
		_finish(OUTCOME_GIVE_UP)
		return
	var from_cash := _cash_amount
	if not bool(gl_PlayerState.pay_continue_fee()):
		_resolving = false
		_cash_amount = int(gl_PlayerState.get_spendable_cash()) if gl_PlayerState.has_method("get_spendable_cash") else 0
		_refresh_money_labels(_cash_amount, _fee_amount)
		_show_afford_or_flip()
		return
	_lock_actions()
	_cash_amount = int(gl_PlayerState.get_spendable_cash()) if gl_PlayerState.has_method("get_spendable_cash") else 0
	_displayed_cash = float(from_cash)
	_set_cash_text(float(from_cash))
	_play_coin_sfx()
	await _roll_cash_to(_cash_amount)
	if not _waiting:
		return
	if _left:
		_left.text = "LEFT      %s" % CommonCode.format_money(_cash_amount)
	await get_tree().create_timer(1.0, true).timeout
	if not _waiting:
		return
	_finish(OUTCOME_PAID)


func _on_coin_flip_pressed() -> void:
	if not _waiting or _resolving:
		return
	if _yes:
		_yes.hide()
	if _coin_flip:
		_coin_flip.hide()
	if _guess_panel:
		_guess_panel.show()
	if _status:
		_status.text = "[center]WRONG = GAME OVER"
	if _heads:
		UiFocus.grab_in(_root, _heads)


func _on_guess(picked_heads: bool) -> void:
	if not _waiting or _resolving:
		return
	_resolving = true
	_lock_actions()
	if _guess_panel:
		_guess_panel.hide()
	var landed_heads := randi() % 2 == 0
	var won := picked_heads == landed_heads
	if _result:
		var side := "HEADS" if landed_heads else "TAILS"
		var verdict := "YOU WIN" if won else "YOU LOSE"
		_result.text = "[center][wave]%s\n%s" % [side, verdict]
		_result.show()
	_play_coin_sfx()
	await get_tree().create_timer(1.15, true).timeout
	if not _waiting:
		return
	if won:
		if gl_PlayerState and gl_PlayerState.has_method("continue_from_coin_flip"):
			gl_PlayerState.continue_from_coin_flip()
		var from_cash := _cash_amount
		_cash_amount = 0
		_displayed_cash = float(from_cash)
		_set_cash_text(float(from_cash))
		if _status:
			_status.text = "[center]ALL CASH LOST"
		await _roll_cash_to(0)
		if not _waiting:
			return
		if _left:
			_left.text = "LEFT      $0"
		await get_tree().create_timer(1.0, true).timeout
		if not _waiting:
			return
		_finish(OUTCOME_FLIP_WIN)
	else:
		_finish(OUTCOME_GIVE_UP)


func _on_give_up_pressed() -> void:
	if not _waiting:
		return
	_finish(OUTCOME_GIVE_UP)


func _lock_actions() -> void:
	_countdown_token += 1
	if _yes:
		_yes.disabled = true
	if _coin_flip:
		_coin_flip.disabled = true
	if _give_up:
		_give_up.disabled = true
	if _heads:
		_heads.disabled = true
	if _tails:
		_tails.disabled = true


func _finish(outcome: String) -> void:
	if not _waiting:
		return
	_outcome = outcome
	_waiting = false
	_countdown_token += 1
	_lower_shop_music()
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
