extends Control
## Bottom-right round cash pool. Rolls up as you earn. Banks into real cash at
## a balloon-check or a successful round end. Forfeited on a 3-strike fail.

const COLOR_POOL := Color("EBE0D8")
const COLOR_BANK := Color("cf9e5bff")
const COLOR_LOSE := Color("C70102")

@onready var pool_label: RichTextLabel = $PoolLabel
@onready var banked_label: RichTextLabel = $BankedLabel
@onready var coin_sfx: AudioStreamPlayer = $CoinSfx

var _displayed_pool := 0.0
var _roll_tween: Tween
var _visible_for_round := false
var _animating_settle := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pool_label:
		pool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if banked_label:
		banked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_pool_color(COLOR_POOL)
	_set_pool_text(0)
	if banked_label:
		banked_label.modulate.a = 0.0
	hide()

	if EventBus.instance:
		EventBus.instance.cash_pool_changed.connect(_on_pool_changed)
		EventBus.instance.cash_pool_banked.connect(_on_pool_banked)
		EventBus.instance.cash_pool_forfeited.connect(_on_pool_forfeited)
		EventBus.instance.open_tally_card.connect(hide_for_menus)
		EventBus.instance.open_shop.connect(hide_for_menus)
		EventBus.instance.egg_pulsed.connect(show_for_round)


func show_for_round() -> void:
	_visible_for_round = true
	_animating_settle = false
	_kill_roll()
	_displayed_pool = float(int(gl_PlayerState.dataset.get("bonus_cash", 0)))
	_set_pool_color(COLOR_POOL)
	_set_pool_text(int(_displayed_pool))
	if banked_label:
		banked_label.modulate.a = 0.0
	show()
	modulate.a = 1.0


func hide_for_menus() -> void:
	_visible_for_round = false
	_animating_settle = false
	_kill_roll()
	_set_pool_color(COLOR_POOL)
	hide()


func _on_pool_changed(new_amount: int) -> void:
	if not _visible_for_round or _animating_settle:
		return
	_set_pool_color(COLOR_POOL)
	_roll_pool_to(new_amount)


func _on_pool_banked(amount: int, previous_cash: int, new_total_cash: int) -> void:
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_set_pool_color(COLOR_BANK)
	if coin_sfx:
		coin_sfx.play()
	if amount > 0 and banked_label and previous_cash != new_total_cash:
		banked_label.text = "$%d" % previous_cash
		banked_label.modulate = Color(COLOR_BANK.r, COLOR_BANK.g, COLOR_BANK.b, 1.0)
		var tween := create_tween()
		tween.tween_method(_set_banked_text, float(previous_cash), float(new_total_cash), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.35)
		tween.tween_property(banked_label, "modulate:a", 0.0, 0.25)
	_punch_label()
	_roll_pool_to(0, 0.4, _finish_settle_to_pool_color)


func _on_pool_forfeited(_amount: int) -> void:
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_set_pool_color(COLOR_LOSE)
	_punch_label()
	_roll_pool_to(0, 0.35, _finish_settle_to_pool_color)


func _finish_settle_to_pool_color() -> void:
	if _visible_for_round:
		_set_pool_color(COLOR_POOL)
	_animating_settle = false


func _roll_pool_to(target: int, duration: float = 0.28, on_done: Callable = Callable()) -> void:
	_kill_roll()
	var from := _displayed_pool
	var to := float(target)
	if is_equal_approx(from, to):
		_displayed_pool = to
		_set_pool_text(target)
		if on_done.is_valid():
			on_done.call()
		return
	_roll_tween = create_tween()
	_roll_tween.tween_method(_set_displayed_pool, from, to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if on_done.is_valid():
		_roll_tween.finished.connect(on_done, CONNECT_ONE_SHOT)


func _set_displayed_pool(value: float) -> void:
	_displayed_pool = value
	_set_pool_text(int(round(value)))


func _set_banked_text(value: float) -> void:
	if banked_label:
		banked_label.text = "$%d" % int(round(value))


func _set_pool_text(amount: int) -> void:
	if pool_label:
		pool_label.text = "$%d" % amount


func _set_pool_color(color: Color) -> void:
	if pool_label:
		pool_label.add_theme_color_override("default_color", color)


func _punch_label() -> void:
	if pool_label == null:
		return
	var tween := create_tween()
	tween.tween_property(pool_label, "scale", Vector2.ONE * 1.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pool_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kill_roll() -> void:
	if _roll_tween and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = null
