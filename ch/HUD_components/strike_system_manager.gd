extends Panel

@onready var indicators_row: HBoxContainer = $HBoxContainer
@onready var strike_sfx: AudioStreamPlayer = $StrikeSFX
@onready var three_strikes_sfx: AudioStreamPlayer = $ThreeStrikesSFX

@export var move_to_center_time := 0.35
@export var blink_count := 4
@export var blink_interval := 0.12
@export var hold_at_center_time := 0.45
@export var return_time := 0.3
@export var strike_out_hold_sec := 2.0

var strike_count := 0
var _indicators: Array[StrikeIndicator] = []
var _row_original_position: Vector2
var _row_original_modulate: Color
var _active_tween: Tween
var _is_playing_finale := false
@onready var strike_out_label: RichTextLabel = $StrikeLabel

func _ready() -> void:
	_row_original_position = indicators_row.position
	_row_original_modulate = indicators_row.modulate
	_cache_indicators()
	EventBus.instance.add_strike.connect(add_strike)
	EventBus.instance.has_hit_three_strikes.connect(three_strikes)
	_hide_strike_out_label()
	reset()

func add_strike() -> void:
	if _is_playing_finale:
		return
	var max_strikes := 3
	if gl_PlayerState and gl_PlayerState.has_method("get_max_strikes"):
		max_strikes = gl_PlayerState.get_max_strikes()
	## Non-final strikes only (final uses has_hit_three_strikes).
	if strike_count >= max_strikes - 1:
		return
	var indicator := _next_unstruck_indicator()
	if indicator == null:
		return
	strike_count += 1
	
	_start_hud_notice()
	
	indicator.reveal_strike(true)
	if strike_sfx:
		$StrikeSFX3.play()
		$StrikeSFX4.play()
		$StrikeSFX5.play()


func ensure_extra_strike_slot() -> void:
	ensure_strike_slots(4)


## Grow or shrink the strike indicator row to match this round's max strikes.
func ensure_strike_slots(count: int) -> void:
	_cache_indicators()
	var target := maxi(count, 1)
	if _indicators.is_empty():
		return
	while _indicators.size() < target:
		var template := _indicators[0]
		var clone := template.duplicate() as Control
		if clone == null:
			break
		indicators_row.add_child(clone)
		if clone.has_method("reset"):
			clone.reset()
		_cache_indicators()
	_trim_to_base_strike_slots(target)
	_cache_indicators()
		
func three_strikes() -> void:
	if _is_playing_finale:
		return

	$StrikeSFX3.play()
	$StrikeSFX4.play()
	$StrikeSFX5.play()
	stop_strike_notices()
	# Ensure every indicator is shown (3rd strike only emits this signal).
	for indicator in _indicators:
		if not indicator.is_struck:
			strike_count += 1
			indicator.reveal_strike(false)
	_play_three_strikes_sequence()

func reset() -> void:
	_kill_tween()
	_is_playing_finale = false
	strike_count = 0
	stop_strike_notices()
	_hide_strike_out_label()
	restore_row_position()
	indicators_row.modulate = _row_original_modulate
	indicators_row.scale = Vector2.ONE
	var base := 3
	if gl_PlayerState and gl_PlayerState.has_method("get_max_strikes"):
		base = gl_PlayerState.get_max_strikes()
	_trim_to_base_strike_slots(base)
	ensure_strike_slots(base)
	for indicator in _indicators:
		indicator.reset()


func restore_row_position() -> void:
	_kill_tween()
	if indicators_row:
		indicators_row.position = _row_original_position
		indicators_row.scale = Vector2.ONE
		indicators_row.modulate = _row_original_modulate


## Keep only the original 3 strike indicators after a round reset.
func _trim_to_base_strike_slots(base_count: int = 3) -> void:
	_cache_indicators()
	while _indicators.size() > base_count:
		var extra = _indicators.pop_back()
		if extra and is_instance_valid(extra):
			extra.queue_free()
	_cache_indicators()

## Balloon-check: fly the row to centre, flip off each strike, then return home.
func play_checkpoint_clear_sequence() -> void:
	await checkpoint_move_to_center()
	if not is_instance_valid(self):
		return
	await checkpoint_clear_struck()
	if not is_instance_valid(self):
		return
	await checkpoint_return_home()


func checkpoint_move_to_center() -> void:
	if _is_playing_finale:
		return
	stop_strike_notices()
	_is_playing_finale = true
	_kill_tween()
	_cache_indicators()
	#indicators_row.pivot_offset = indicators_row.size * 0.5
	var center_pos := _get_center_position()
	_active_tween = create_tween()
	_active_tween.tween_interval(0.12)
	_active_tween.tween_property(indicators_row, "position", center_pos, move_to_center_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(indicators_row, "scale", Vector2(1.35, 1.35), move_to_center_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(0.12)
	await _active_tween.finished


func checkpoint_clear_struck() -> void:
	_cache_indicators()
	var struck: Array[StrikeIndicator] = []
	for i in range(_indicators.size() - 1, -1, -1):
		if _indicators[i].is_struck:
			struck.append(_indicators[i])
	for indicator in struck:
		if not is_instance_valid(indicator):
			continue
		if has_node("StrikeSFX3"):
			$StrikeSFX3.play()
		elif strike_sfx:
			strike_sfx.play()
		if indicator.has_method("conceal_strike"):
			await indicator.conceal_strike()
		else:
			indicator.reset()
		strike_count = maxi(strike_count - 1, 0)
	await get_tree().create_timer(0.18, false).timeout


func checkpoint_return_home() -> void:
	if not is_instance_valid(self) or indicators_row == null:
		reset()
		return
	#indicators_row.pivot_offset = indicators_row.size * 0.5
	_active_tween = create_tween()
	_active_tween.tween_property(indicators_row, "position", _row_original_position, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_property(indicators_row, "scale", Vector2.ONE, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _active_tween.finished
	reset()


func _play_three_strikes_sequence() -> void:
	_is_playing_finale = true
	CommonCode.apply_ui_overlay_blur()
	var notice := get_node_or_null("../MakeStrikeNoticeable")
	if notice and notice.has_method("start"):
		notice.start()
	
	await get_tree().create_timer(1.0, false).timeout
	
	_kill_tween()

	# Make sure we scale/blink around the row's own center, not its top-left corner.
	#indicators_row.pivot_offset = indicators_row.size * 0.5

	#var center_pos := _get_center_position()
	var center_pos := Vector2(848,520)
	_active_tween = create_tween()
	_active_tween.tween_interval(0.2)
	_active_tween.tween_property(indicators_row, "position", center_pos, move_to_center_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(indicators_row, "scale", Vector2.ONE * 1.9, move_to_center_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(_play_three_strikes_sfx)

	_active_tween.tween_callback(_show_strike_out_label)
	for i in blink_count:
		_active_tween.tween_property(indicators_row, "modulate:a", 0.15, blink_interval * 0.5)
		_active_tween.tween_property(indicators_row, "modulate:a", _row_original_modulate.a, blink_interval * 0.5)
	_active_tween.tween_interval(maxf(strike_out_hold_sec, 0.0))
	_active_tween.tween_callback(_hide_strike_out_label)
	_active_tween.tween_property(indicators_row, "position", _row_original_position, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_property(indicators_row, "scale", Vector2.ONE, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_callback(func() -> void:
		_is_playing_finale = false
		reset()
	)


func wait_until_finale_finished() -> void:
	var waited := 0.0
	while not _is_playing_finale and waited < 0.2 and is_instance_valid(self):
		await get_tree().process_frame
		waited += get_process_delta_time()
	while _is_playing_finale and is_instance_valid(self):
		await get_tree().process_frame


func stop_strike_notices() -> void:
	var notice := get_node_or_null("../MakeStrikeNoticeable")
	if notice and notice.has_method("stop"):
		notice.stop()
	_cache_indicators()
	for indicator in _indicators:
		if indicator and indicator.has_method("stop_notice_pulses"):
			indicator.stop_notice_pulses()


func _start_hud_notice() -> void:
	var notice := get_node_or_null("../MakeStrikeNoticeable")
	if notice and notice.has_method("start"):
		notice.start()


func _show_strike_out_label() -> void:
	if strike_out_label == null:
		return
	strike_out_label.visible = true
	
	strike_out_label.text = "Oh no..."
	var tween = create_tween()
	tween.tween_property(strike_out_label, "modulate:a", 1.0, 0.15)


func _hide_strike_out_label() -> void:
	if strike_out_label:
		strike_out_label.visible = false
		strike_out_label.modulate.a = 0.0

func _next_unstruck_indicator() -> StrikeIndicator:
	for indicator in _indicators:
		if not indicator.is_struck:
			return indicator
	return null

func _cache_indicators() -> void:
	_indicators.clear()
	for child in indicators_row.get_children():
		if child is StrikeIndicator:
			_indicators.append(child)

func _get_center_position() -> Vector2:
	# self (the Panel) is full-rect, so self.size == the screen/parent area.
	# Center the row within that area, using its own current size.
	return (size - indicators_row.size) * 0.5

func _play_three_strikes_sfx() -> void:
	if three_strikes_sfx:
		three_strikes_sfx.play()
		
	if $ThreeStrikesSFX2:
		$ThreeStrikesSFX2.play()

func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

func restart() -> void:
	reset()
