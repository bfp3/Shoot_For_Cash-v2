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
var _tracked_pool := 0
var _roll_tween: Tween
var _visible_for_round := false
var _animating_settle := false
var _ceremony_lock := false
var _move_tween: Tween
var _pool_layout: Dictionary = {}
var _banked_layout: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pool_label:
		pool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if banked_label:
		banked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_pool_color(COLOR_POOL)
	_set_pool_text(0)
	_refresh_banked_total()
	call_deferred("_cache_scene_layout")
	hide()

	if EventBus.instance:
		EventBus.instance.cash_pool_changed.connect(_on_pool_changed)
		EventBus.instance.cash_pool_banked.connect(_on_pool_banked)
		EventBus.instance.cash_pool_forfeited.connect(_on_pool_forfeited)
		EventBus.instance.open_tally_card.connect(hide_for_menus)
		EventBus.instance.open_shop.connect(hide_for_menus)
		EventBus.instance.egg_pulsed.connect(show_for_round)
		EventBus.instance.update_money.connect(_refresh_banked_total)


func show_for_round() -> void:
	_visible_for_round = true
	_ceremony_lock = false
	_animating_settle = false
	_kill_roll()
	_restore_scene_layout()
	_tracked_pool = int(gl_PlayerState.dataset.get("bonus_cash", 0))
	_displayed_pool = float(_tracked_pool)
	_set_pool_color(COLOR_POOL)
	_set_pool_text(int(_displayed_pool))
	_refresh_banked_total()
	show()
	modulate.a = 1.0


func hide_for_menus() -> void:
	_visible_for_round = false
	_ceremony_lock = false
	_animating_settle = false
	_kill_roll()
	_restore_scene_layout()
	_set_pool_color(COLOR_POOL)
	hide()


func _on_pool_changed(new_amount: int) -> void:
	var delta := new_amount - _tracked_pool
	_tracked_pool = new_amount
	var origin := Vector3.INF
	if EventBus.instance:
		origin = EventBus.instance.cash_gain_world_origin
		EventBus.instance.cash_gain_world_origin = Vector3.INF
	if not _visible_for_round or _animating_settle or _ceremony_lock:
		return
	_set_pool_color(COLOR_POOL)
	if delta > 0:
		_play_gain_chip_then_roll(delta, origin)
	else:
		_roll_pool_to(new_amount)


func _on_pool_banked(amount: int, previous_cash: int, new_total_cash: int) -> void:
	if _ceremony_lock:
		return
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_tracked_pool = 0
	_set_pool_color(COLOR_BANK)
	if coin_sfx:
		coin_sfx.play()
	if amount > 0 and banked_label and previous_cash != new_total_cash:
		banked_label.text = "$%d" % previous_cash
		banked_label.modulate = Color(COLOR_BANK.r, COLOR_BANK.g, COLOR_BANK.b, 1.0)
		var tween := create_tween()
		tween.tween_method(_set_banked_text, float(previous_cash), float(new_total_cash), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_label()
	_roll_pool_to(0, 0.4, _finish_settle_to_pool_color)


func _play_gain_chip_then_roll(delta: int, world_origin: Vector3 = Vector3.INF) -> void:
	await _spawn_gain_chip(delta, world_origin)
	if not _visible_for_round or _ceremony_lock or _animating_settle:
		return
	_roll_pool_to(_tracked_pool)


func _spawn_gain_chip(amount: int, world_origin: Vector3 = Vector3.INF) -> void:
	if pool_label == null:
		return
	var chip := Label.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.text = "$%d" % amount
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var font := pool_label.get_theme_font("normal_font")
	if font:
		chip.add_theme_font_override("font", font)
	chip.add_theme_font_size_override("font_size", 72)
	chip.add_theme_color_override("font_color", COLOR_POOL)
	chip.add_theme_constant_override("outline_size", 2)
	chip.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.85))
	add_child(chip)
	chip.reset_size()
	var dest := _pool_corner_for_chip(chip)
	var start := _screen_pos_from_world(world_origin)
	if not start.is_finite():
		start = dest + Vector2(-40.0, -80.0)
	else:
		start -= chip.size * 0.5
	chip.global_position = start
	chip.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(chip, "global_position", dest, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	var fade := create_tween()
	fade.tween_property(chip, "modulate:a", 0.0, 0.12)
	await fade.finished
	if is_instance_valid(chip):
		chip.queue_free()


func _pool_corner_for_chip(chip: Control) -> Vector2:
	## Land on the bottom-right of the pool number, not the centre of the wide label.
	var rect := pool_label.get_global_rect()
	return Vector2(rect.end.x - chip.size.x, rect.end.y - chip.size.y)


func _screen_pos_from_world(world_origin: Vector3) -> Vector2:
	if not world_origin.is_finite():
		return Vector2.INF
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.INF
	if cam.is_position_behind(world_origin):
		return Vector2.INF
	return cam.unproject_position(world_origin)


func _refresh_banked_total() -> void:
	if banked_label == null:
		return
	banked_label.text = "$%d" % int(gl_PlayerState.dataset.get("cash", 0))
	banked_label.modulate = Color(COLOR_BANK.r, COLOR_BANK.g, COLOR_BANK.b, 1.0)


func _on_pool_forfeited(_amount: int) -> void:
	if not _visible_for_round:
		return
	_animating_settle = true
	_kill_roll()
	_tracked_pool = 0
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


func begin_checkpoint_ceremony() -> void:
	_ceremony_lock = true
	_animating_settle = true
	_cache_scene_layout()


func end_checkpoint_ceremony() -> void:
	_ceremony_lock = false
	_animating_settle = false
	_restore_scene_layout()


func checkpoint_move_to_center() -> void:
	if not _visible_for_round or pool_label == null:
		return
	_cache_scene_layout()
	_kill_move()
	var pool_home := _top_left(pool_label)
	var target_pool := _checkpoint_center_for(pool_label)
	var delta := target_pool - pool_home
	if banked_label:
		banked_label.text = "$%d" % int(gl_PlayerState.dataset.get("cash", 0))
		banked_label.modulate = Color(COLOR_BANK.r, COLOR_BANK.g, COLOR_BANK.b, 1.0)
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_tween_offsets_to(_move_tween, pool_label, target_pool, 0.35)
	if banked_label:
		_tween_offsets_to(_move_tween, banked_label, _top_left(banked_label) + delta, 0.35)
	await _move_tween.finished


func checkpoint_play_bank(amount: int, previous_cash: int, new_total_cash: int) -> void:
	if not _visible_for_round:
		return
	_tracked_pool = 0
	_set_pool_color(COLOR_BANK)
	if coin_sfx and amount > 0:
		coin_sfx.play()
	_punch_label()
	if amount > 0 and banked_label and previous_cash != new_total_cash:
		banked_label.text = "$%d" % previous_cash
		banked_label.modulate = Color(COLOR_BANK.r, COLOR_BANK.g, COLOR_BANK.b, 1.0)
		var bank_tween := create_tween()
		bank_tween.tween_method(_set_banked_text, float(previous_cash), float(new_total_cash), 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bank_tween.tween_interval(0.28)
		_roll_pool_to(0, 0.45)
		await bank_tween.finished
	else:
		_roll_pool_to(0, 0.35)
		await get_tree().create_timer(0.4, false).timeout
	_set_pool_color(COLOR_POOL)


func checkpoint_return_home() -> void:
	_kill_move()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	if pool_label and not _pool_layout.is_empty():
		_tween_layout_to(_move_tween, pool_label, _pool_layout, 0.3)
	if banked_label and not _banked_layout.is_empty():
		_tween_layout_to(_move_tween, banked_label, _banked_layout, 0.3)
	await _move_tween.finished
	_restore_scene_layout()


func _cache_scene_layout() -> void:
	if pool_label and _pool_layout.is_empty():
		_pool_layout = _snapshot_layout(pool_label)
	if banked_label and _banked_layout.is_empty():
		_banked_layout = _snapshot_layout(banked_label)


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
	_apply_layout(banked_label, _banked_layout)
	_refresh_banked_total()


func _top_left(ctrl: Control) -> Vector2:
	return Vector2(
		size.x * ctrl.anchor_left + ctrl.offset_left,
		size.y * ctrl.anchor_top + ctrl.offset_top
	)


func _checkpoint_center_for(label: Control) -> Vector2:
	var area := size
	if area.x <= 1.0 or area.y <= 1.0:
		area = get_viewport_rect().size
	var pos := (area - label.size) * 0.5
	pos.y += 118.0
	return pos


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


func _kill_move() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
