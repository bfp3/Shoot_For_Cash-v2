@tool
extends Control
## Bottom-right round cash HUD.
## TotalCash2 = unbanked round pool only. Each round starts at $0. Hits fly a
## chip into it and roll the number up. Wallet cash is not shown here — it
## cashes in at tally. Strikeout scatters the round total back to $0.
## PoolLabel is kept for checkpoint / bank internals but can stay hidden.
## MultiplierLabel = current cash multiplier.

const COLOR_POOL := Color("EBE0D8")
const COLOR_BANK := Color("cf9e5bff")
const COLOR_LOSE := Color("C70102")

@onready var pool_label: RichTextLabel = $PoolLabel
@onready var total_cash_label: RichTextLabel = $TotalCash2
@onready var multiplier_label: RichTextLabel = $MultiplierLabel
@onready var continue_fee_label: RichTextLabel = $ContinueFeeLabel
@onready var coin_sfx: AudioStreamPlayer = $CoinSfx
@onready var kaching_sfx: AudioStreamPlayer = $KachingSfx
@onready var kaching_sfx_2: AudioStreamPlayer = $KachingSfx2

@export_group("Gain Chip")
## How far above TotalCash2 the flying "$N" starts (pixels).
@export var gain_chip_start_height_px := 200.0
## How fast the chip travels down into TotalCash2 (pixels per second).
@export var gain_chip_move_speed_px := 500.0
## TotalCash2 scale punch when a chip lands.
@export var gain_chip_absorb_scale := 1.12
@export var gain_chip_absorb_up_sec := 0.08
@export var gain_chip_absorb_down_sec := 0.12
@export_tool_button("Test Cash Chip") var test_cash_chip: Callable = _on_test_cash_chip

@export_group("Loss Scatter")
## How many leftover-cash chips fly out on strikeout.
@export var loss_scatter_count := 18
## How far chips travel away from TotalCash2 (pixels).
@export var loss_scatter_distance_px := 220.0
## How long each flying chip lasts.
@export var loss_scatter_fly_sec := 0.7

@export_group("Checkpoint Ceremony")
## Added to the screen-centre rest pose (pixels). Raise X to shift right.
const checkpoint_center_offset := Vector2(-125.0, 175.0)
## Pause after the HUD reaches centre, before pool rolls into TotalCash2.
@export var checkpoint_bank_delay_sec := 0.5


var _displayed_pool := 0.0
var _tracked_pool := 0
var _tracked_total := 0
var _displayed_total := 0.0
var _roll_tween: Tween
var _total_roll_tween: Tween
var _visible_for_round := false
var _animating_settle := false
var _ceremony_lock := false
var _move_tween: Tween
var _pool_layout: Dictionary = {}
var _total_layout: Dictionary = {}
var _punch_tween: Tween
var _fade_tween: Tween
var _live_chips: Array[Control] = []
var _loss_scatter_active := false


func _ready() -> void:
	#hide()
	#return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pool_label:
		pool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if total_cash_label:
		total_cash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if multiplier_label:
		multiplier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if continue_fee_label:
		continue_fee_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_pool_color(COLOR_POOL)
	_set_pool_text(0)
	_sync_total_from_state(true)
	call_deferred("_cache_scene_layout")
	hide()

	if EventBus.instance:
		EventBus.instance.cash_pool_changed.connect(_on_pool_changed)
		EventBus.instance.cash_pool_banked.connect(_on_pool_banked)
		EventBus.instance.cash_pool_forfeited.connect(_on_pool_forfeited)
		if EventBus.instance.has_signal("cash_multiplier_changed"):
			EventBus.instance.cash_multiplier_changed.connect(_on_multiplier_changed)
		EventBus.instance.update_money.connect(_on_wallet_changed)
		if EventBus.instance.has_signal("continue_fee_changed"):
			EventBus.instance.continue_fee_changed.connect(_on_continue_fee_changed)
		EventBus.instance.open_tally_card.connect(hide_for_menus)
		EventBus.instance.open_shop.connect(hide_for_menus)
		EventBus.instance.egg_pulsed.connect(show_for_round)


func show_for_round() -> void:
	#return
	_visible_for_round = true
	_ceremony_lock = false
	_animating_settle = false
	_kill_roll()
	_kill_fade()
	_restore_scene_layout()
	_tracked_pool = int(gl_PlayerState.dataset.get("bonus_cash", 0))
	_displayed_pool = float(_tracked_pool)
	_sync_total_from_state(true)
	_set_pool_color(COLOR_POOL)
	_set_pool_text(int(_displayed_pool))
	_refresh_multiplier()
	_refresh_continue_fee()
	show()
	modulate.a = 1.0


func _on_multiplier_changed(_new_multiplier: int = 0) -> void:
	_refresh_multiplier()


func _refresh_multiplier() -> void:
	if multiplier_label == null:
		return
	var mult := 2
	if gl_PlayerState and gl_PlayerState.has_method("get_cash_multiplier"):
		mult = int(gl_PlayerState.get_cash_multiplier())
	elif gl_PlayerState:
		mult = int(gl_PlayerState.get("cash_multiplier"))
	multiplier_label.text = "x%d" % maxi(mult, 1)


func _on_continue_fee_changed(_new_fee: int = 0) -> void:
	_refresh_continue_fee()


func _refresh_continue_fee() -> void:
	if continue_fee_label == null:
		return
	var fee := 0
	if gl_PlayerState and gl_PlayerState.has_method("get_continue_fee"):
		fee = int(gl_PlayerState.get_continue_fee())
	continue_fee_label.text = "CONTINUE %s" % CommonCode.format_money(fee)
	var cash := 0
	if gl_PlayerState and gl_PlayerState.has_method("get_spendable_cash"):
		cash = int(gl_PlayerState.get_spendable_cash())
	else:
		cash = _live_total_amount()
	if cash >= fee:
		continue_fee_label.add_theme_color_override("default_color", COLOR_BANK)
	else:
		continue_fee_label.add_theme_color_override("default_color", COLOR_LOSE)


func hide_for_menus() -> void:
	_visible_for_round = false
	_ceremony_lock = false
	_animating_settle = false
	_kill_roll()
	_kill_fade()
	_free_live_chips()
	_restore_scene_layout()
	_set_pool_color(COLOR_POOL)
	modulate.a = 1.0
	hide()


func fade_out_for_continue(duration: float = 0.35) -> void:
	_visible_for_round = false
	_kill_roll()
	_kill_fade()
	if not visible:
		modulate.a = 0.0
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func fade_in_for_continue(duration: float = 0.55) -> void:
	_ceremony_lock = false
	_animating_settle = false
	_kill_roll()
	_kill_fade()
	_restore_scene_layout()
	_tracked_pool = int(gl_PlayerState.dataset.get("bonus_cash", 0))
	_displayed_pool = float(_tracked_pool)
	_sync_total_from_state(true)
	_set_pool_color(COLOR_POOL)
	_set_pool_text(int(_displayed_pool))
	_refresh_multiplier()
	_refresh_continue_fee()
	_visible_for_round = true
	show()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _on_pool_changed(new_amount: int) -> void:
	var delta := new_amount - _tracked_pool
	_tracked_pool = new_amount
	_tracked_total = _live_total_amount()
	_refresh_continue_fee()
	if not _visible_for_round or _animating_settle or _ceremony_lock:
		_set_pool_text(new_amount)
		_set_total_text(float(_tracked_total))
		return
	_set_pool_color(COLOR_POOL)
	if delta > 0:
		_play_gain_chip_then_roll(delta)
	else:
		_set_pool_text(new_amount)
		_roll_total_to(float(_tracked_total))


func _on_wallet_changed() -> void:
	_refresh_continue_fee()
	## Round HUD is pool-only; wallet updates belong to the shop / tally.


func _on_pool_banked(_amount: int, _previous_cash: int, _new_total_cash: int) -> void:
	if _ceremony_lock:
		return
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_tracked_pool = 0
	_tracked_total = 0
	_set_pool_color(COLOR_BANK)
	if coin_sfx:
		coin_sfx.play()
	_play_bank_kaching()
	_punch_label()
	_set_pool_text(0)
	_displayed_pool = 0.0
	_roll_total_to(0.0, 0.4)
	_roll_pool_to(0, 0.4, _finish_settle_to_pool_color)


func _play_gain_chip_then_roll(delta: int) -> void:
	await _spawn_gain_chip(delta)
	if not _visible_for_round or _ceremony_lock or _animating_settle:
		return
	_punch_label()
	_set_pool_text(_tracked_pool)
	_displayed_pool = float(_tracked_pool)
	_roll_total_to(float(_tracked_total))


func _spawn_gain_chip(amount: int) -> void:
	var dest_label := _gain_chip_target()
	if dest_label == null:
		return
	var chip := Label.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.text = "$%d" % amount
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var font := dest_label.get_theme_font("normal_font")
	if font:
		chip.add_theme_font_override("font", font)
	chip.add_theme_font_size_override("font_size", 72)
	chip.add_theme_color_override("font_color", COLOR_POOL)
	chip.add_theme_constant_override("outline_size", 2)
	chip.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.85))
	add_child(chip)
	chip.reset_size()
	_live_chips.append(chip)
	var dest := _label_corner_for_chip(dest_label, chip)
	var start := dest + Vector2(0.0, -gain_chip_start_height_px)
	chip.global_position = start
	chip.modulate.a = 1.0
	var dist := start.distance_to(dest)
	var duration := dist / maxf(gain_chip_move_speed_px, 1.0)
	var tween := create_tween()
	tween.tween_property(chip, "global_position", dest, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(chip):
		var fade := create_tween()
		fade.tween_property(chip, "modulate:a", 0.0, 0.12)
		await fade.finished
	if is_instance_valid(chip):
		_free_chip(chip)


func _gain_chip_target() -> RichTextLabel:
	if total_cash_label:
		return total_cash_label
	return pool_label


func _label_corner_for_chip(label: Control, chip: Control) -> Vector2:
	var rect := label.get_global_rect()
	return Vector2(rect.end.x - chip.size.x, rect.end.y - chip.size.y)


func _on_test_cash_chip() -> void:
	if not is_node_ready():
		return
	_spawn_gain_chip(25)
	_punch_label()


func _wallet_amount() -> int:
	if gl_PlayerState == null:
		return 0
	return int(gl_PlayerState.dataset.get("cash", 0))


func _live_total_amount() -> int:
	if gl_PlayerState == null:
		return 0
	return int(gl_PlayerState.dataset.get("bonus_cash", 0))


func _sync_total_from_state(snap: bool = false) -> void:
	_tracked_total = _live_total_amount()
	if snap:
		_displayed_total = float(_tracked_total)
	_set_total_text(float(_tracked_total) if snap else _displayed_total)


func _on_pool_forfeited(_amount: int) -> void:
	if _loss_scatter_active:
		return
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_tracked_pool = 0
	_tracked_total = 0
	_set_pool_color(COLOR_LOSE)
	_punch_label()
	_roll_total_to(0.0, 0.35)
	_roll_pool_to(0, 0.35, _finish_settle_to_pool_color)


## Strikeout: fly lots of small dollar chips out of the corner total, then $0.
func play_round_loss_scatter() -> void:
	_loss_scatter_active = true
	_kill_fade()
	_visible_for_round = true
	show()
	modulate.a = 1.0
	var lost := int(round(_displayed_total))
	if lost <= 0:
		lost = _live_total_amount()
	if gl_PlayerState and gl_PlayerState.has_method("forfeit_cash_pool"):
		gl_PlayerState.forfeit_cash_pool()
	_tracked_pool = 0
	_tracked_total = 0
	_set_pool_color(COLOR_LOSE)
	_punch_label()
	if coin_sfx:
		coin_sfx.play()
	_spawn_loss_scatter_chips(lost)
	var roll_sec := clampf(0.35 + float(lost) / 400.0, 0.4, 0.85)
	_roll_total_to(0.0, roll_sec)
	_roll_pool_to(0, roll_sec)
	await get_tree().create_timer(maxf(roll_sec, loss_scatter_fly_sec), false).timeout
	_displayed_total = 0.0
	_displayed_pool = 0.0
	_set_total_text(0.0)
	_set_pool_text(0)
	_loss_scatter_active = false
	_animating_settle = false


func _spawn_loss_scatter_chips(total: int) -> void:
	var dest_label := _gain_chip_target()
	if dest_label == null:
		return
	var origin := _label_corner_for_chip(dest_label, dest_label)
	origin.x += dest_label.size.x * 0.35
	origin.y += dest_label.size.y * 0.15
	var count := loss_scatter_count
	if total <= 0:
		count = mini(count, 8)
	var pieces: Array[int] = _split_loss_amounts(maxi(total, 0), count)
	for i in pieces.size():
		var amount: int = pieces[i]
		var chip := Label.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.text = "$%d" % amount
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var font := dest_label.get_theme_font("normal_font")
		if font:
			chip.add_theme_font_override("font", font)
		chip.add_theme_font_size_override("font_size", 36)
		chip.add_theme_color_override("font_color", COLOR_LOSE)
		chip.add_theme_constant_override("outline_size", 2)
		chip.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.85))
		add_child(chip)
		chip.reset_size()
		_live_chips.append(chip)
		chip.global_position = origin
		chip.pivot_offset = chip.size * 0.5
		var angle := randf_range(-PI * 0.9, -PI * 0.1)
		var dist := randf_range(loss_scatter_distance_px * 0.55, loss_scatter_distance_px)
		var target := origin + Vector2(cos(angle), sin(angle)) * dist
		var dur := randf_range(loss_scatter_fly_sec * 0.7, loss_scatter_fly_sec)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(chip, "global_position", target, dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(chip, "modulate:a", 0.0, dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(chip, "rotation", randf_range(-0.6, 0.6), dur)
		tween.set_parallel(false)
		tween.tween_callback(_free_chip.bind(chip))


func _split_loss_amounts(total: int, count: int) -> Array[int]:
	var out: Array[int] = []
	if total <= 0:
		for _i in count:
			out.append(1)
		return out
	var remaining := total
	for i in count:
		var left := count - i
		if left <= 1:
			out.append(maxi(remaining, 1))
			break
		var chunk := maxi(int(round(float(remaining) / float(left))), 1)
		chunk = mini(chunk, remaining)
		# Prefer small familiar amounts so the scatter reads as lots of little bills.
		if chunk > 25:
			chunk = 25 if remaining > 25 else chunk
		elif chunk > 10:
			chunk = 10 if remaining > 10 else chunk
		elif chunk > 5:
			chunk = 5 if remaining > 5 else chunk
		out.append(chunk)
		remaining -= chunk
		if remaining <= 0:
			break
	while out.size() < count and total > 0:
		out.append(1)
	return out


func _finish_settle_to_pool_color() -> void:
	if _visible_for_round:
		_set_pool_color(COLOR_POOL)
	_animating_settle = false


func _roll_pool_to(target: int, duration: float = 0.28, on_done: Callable = Callable()) -> void:
	_kill_pool_roll()
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


func _roll_total_to(target: float, duration: float = 0.28) -> void:
	if _total_roll_tween and _total_roll_tween.is_valid():
		_total_roll_tween.kill()
	_total_roll_tween = null
	var from := _displayed_total
	if is_equal_approx(from, target):
		_displayed_total = target
		_set_total_text(target)
		return
	_total_roll_tween = create_tween()
	_total_roll_tween.tween_method(_set_total_text, from, target, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_displayed_pool(value: float) -> void:
	_displayed_pool = value
	_set_pool_text(int(round(value)))


func _set_total_text(value: float) -> void:
	_displayed_total = value
	if total_cash_label:
		total_cash_label.text = "$%d" % int(round(value))
		total_cash_label.text = "[wave]" + CommonCode.format_money(value)

func _set_pool_text(amount: int) -> void:
	if pool_label:
		pool_label.text = "$%d" % amount


func _set_pool_color(color: Color) -> void:
	if pool_label:
		pool_label.add_theme_color_override("default_color", color)


func _punch_label() -> void:
	var label := _gain_chip_target()
	if label == null:
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	label.scale = Vector2.ONE
	_punch_tween = create_tween()
	_punch_tween.tween_property(label, "scale", Vector2.ONE * gain_chip_absorb_scale, gain_chip_absorb_up_sec)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(label, "scale", Vector2.ONE, gain_chip_absorb_down_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kill_pool_roll() -> void:
	if _roll_tween and _roll_tween.is_valid():
		_roll_tween.kill()
	_roll_tween = null


func _kill_roll() -> void:
	_kill_pool_roll()
	if _total_roll_tween and _total_roll_tween.is_valid():
		_total_roll_tween.kill()
	_total_roll_tween = null


func begin_checkpoint_ceremony() -> void:
	_ceremony_lock = true
	_animating_settle = true
	_cache_scene_layout()


func end_checkpoint_ceremony() -> void:
	_ceremony_lock = false
	_animating_settle = false
	_restore_scene_layout()


func checkpoint_move_to_center() -> void:
	if not _visible_for_round:
		return
	_cache_scene_layout()
	_kill_move()
	var home_label := total_cash_label if total_cash_label else pool_label
	if home_label == null:
		return
	var home := _top_left(home_label)
	var target := _checkpoint_center_for(home_label)
	var delta := target - home
	_set_total_text(float(_tracked_total))
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_tween_offsets_to(_move_tween, home_label, target, 0.35)
	if pool_label and pool_label != home_label and pool_label.visible:
		_tween_offsets_to(_move_tween, pool_label, _top_left(pool_label) + delta, 0.35)
	await _move_tween.finished


func checkpoint_play_bank(amount: int, _previous_cash: int, _new_total_cash: int) -> void:
	if not _visible_for_round:
		return
	if checkpoint_bank_delay_sec > 0.0:
		await get_tree().create_timer(checkpoint_bank_delay_sec, false).timeout
	if not _visible_for_round:
		return
	_tracked_pool = 0
	_tracked_total = _wallet_amount()
	_set_pool_color(COLOR_BANK)
	_play_bank_kaching()
	_punch_label()
	_set_pool_text(0)
	_displayed_pool = 0.0
	_roll_total_to(float(_tracked_total), 0.45)
	_roll_pool_to(0, 0.45)
	if amount > 0:
		await get_tree().create_timer(0.73, false).timeout
	else:
		await get_tree().create_timer(0.4, false).timeout
	_set_pool_color(COLOR_POOL)


func checkpoint_return_home() -> void:
	_kill_move()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	if pool_label and not _pool_layout.is_empty():
		_tween_layout_to(_move_tween, pool_label, _pool_layout, 0.3)
	if total_cash_label and not _total_layout.is_empty():
		_tween_layout_to(_move_tween, total_cash_label, _total_layout, 0.3)
	await _move_tween.finished
	_restore_scene_layout()


func _cache_scene_layout() -> void:
	if pool_label and _pool_layout.is_empty():
		_pool_layout = _snapshot_layout(pool_label)
	if total_cash_label and _total_layout.is_empty():
		_total_layout = _snapshot_layout(total_cash_label)


func _snapshot_layout(ctrl: Control) -> Dictionary:
	return {
		"anchor_left": ctrl.anchor_left,
		"anchor_top": ctrl.anchor_top,
		"anchor_right": ctrl.anchor_right,
		"anchor_bottom": ctrl.anchor_bottom,
		"offset_left": ctrl.offset_left,
		"offset_top": ctrl.offset_top,
		"offset_right": ctrl.offset_right,
		"offset_bottom": ctrl.offset_bottom,
	}


func _apply_layout(ctrl: Control, snap: Dictionary) -> void:
	if ctrl == null or snap.is_empty():
		return
	ctrl.anchor_left = float(snap.anchor_left)
	ctrl.anchor_top = float(snap.anchor_top)
	ctrl.anchor_right = float(snap.anchor_right)
	ctrl.anchor_bottom = float(snap.anchor_bottom)
	ctrl.offset_left = float(snap.offset_left)
	ctrl.offset_top = float(snap.offset_top)
	ctrl.offset_right = float(snap.offset_right)
	ctrl.offset_bottom = float(snap.offset_bottom)


func _restore_scene_layout() -> void:
	_kill_move()
	_apply_layout(pool_label, _pool_layout)
	_apply_layout(total_cash_label, _total_layout)
	if pool_label:
		pool_label.scale = Vector2.ONE
	if total_cash_label:
		total_cash_label.scale = Vector2.ONE
	_sync_total_from_state(true)


func _top_left(ctrl: Control) -> Vector2:
	return Vector2(
		size.x * ctrl.anchor_left + ctrl.offset_left,
		size.y * ctrl.anchor_top + ctrl.offset_top
	)


func _checkpoint_center_for(label: Control) -> Vector2:
	var area := size
	if area.x <= 1.0 or area.y <= 1.0:
		area = get_viewport_rect().size
	return (area - label.size) * 0.5 + checkpoint_center_offset


func _tween_offsets_to(tween: Tween, ctrl: Control, desired_tl: Vector2, duration: float) -> void:
	var w := ctrl.size.x
	var h := ctrl.size.y
	var ol := desired_tl.x - size.x * ctrl.anchor_left
	var ot := desired_tl.y - size.y * ctrl.anchor_top
	var oright := desired_tl.x + w - size.x * ctrl.anchor_right
	var ob := desired_tl.y + h - size.y * ctrl.anchor_bottom
	tween.tween_property(ctrl, "offset_left", ol, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ctrl, "offset_top", ot, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ctrl, "offset_right", oright, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ctrl, "offset_bottom", ob, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tween_layout_to(tween: Tween, ctrl: Control, snap: Dictionary, duration: float) -> void:
	tween.tween_property(ctrl, "offset_left", float(snap.offset_left), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ctrl, "offset_top", float(snap.offset_top), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ctrl, "offset_right", float(snap.offset_right), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ctrl, "offset_bottom", float(snap.offset_bottom), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _play_bank_kaching() -> void:
	if kaching_sfx:
		kaching_sfx.play()
	if kaching_sfx_2:
		kaching_sfx_2.play()


func _kill_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


func _free_chip(chip: Control) -> void:
	_live_chips.erase(chip)
	if is_instance_valid(chip):
		chip.queue_free()


func _free_live_chips() -> void:
	for chip in _live_chips:
		if is_instance_valid(chip):
			chip.queue_free()
	_live_chips.clear()
