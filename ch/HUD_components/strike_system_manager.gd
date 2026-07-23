extends Panel

@onready var indicators_row: HBoxContainer = $HBoxContainer
@onready var strike_sfx: AudioStreamPlayer = $StrikeSFX
@onready var three_strikes_sfx: AudioStreamPlayer = $ThreeStrikesSFX

@export var move_to_center_time := 0.35
@export var blink_count := 4
@export var blink_interval := 0.12
@export var hold_at_center_time := 0.45
@export var return_time := 0.3

var strike_count := 0
var _indicators: Array[StrikeIndicator] = []
var _original_position: Vector2
var _original_modulate: Color
var _active_tween: Tween
var _is_playing_finale := false


func _ready() -> void:
	_original_position = position
	_original_modulate = modulate
	_cache_indicators()

	EventBus.instance.add_strike.connect(add_strike)
	EventBus.instance.has_hit_three_strikes.connect(three_strikes)

	reset()


func add_strike() -> void:
	if strike_count > 2:

		return
	
	if _is_playing_finale:
		return

	var indicator := _next_unstruck_indicator()
	if indicator == null:
		return

	strike_count += 1
	indicator.reveal_strike()
	if strike_sfx:
		strike_sfx.play()
		$StrikeSFX2.play()

func three_strikes() -> void:
	if _is_playing_finale:
		return
		
	strike_sfx.play()
	$StrikeSFX2.play()
	# Ensure every indicator is shown (3rd strike only emits this signal).
	for indicator in _indicators:
		if not indicator.is_struck:
			strike_count += 1
			indicator.reveal_strike()

	_play_three_strikes_sequence()


func reset() -> void:
	_kill_tween()
	_is_playing_finale = false
	strike_count = 0

	position = _original_position
	modulate = _original_modulate
	scale = Vector2.ONE

	for indicator in _indicators:
		indicator.reset()


func _play_three_strikes_sequence() -> void:
	_is_playing_finale = true
	_kill_tween()

	var center_pos := _get_center_position()
	_active_tween = create_tween()

	_active_tween.tween_interval(0.2)
	_active_tween.tween_property(self, "position", center_pos, move_to_center_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(self, "scale", Vector2(1.35, 1.35), move_to_center_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(_play_three_strikes_sfx)

	for i in blink_count:
		_active_tween.tween_property(self, "modulate:a", 0.15, blink_interval * 0.5)
		_active_tween.tween_property(self, "modulate:a", _original_modulate.a, blink_interval * 0.5)

	_active_tween.tween_interval(hold_at_center_time)
	_active_tween.tween_property(self, "position", _original_position, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_property(self, "scale", Vector2.ONE, return_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_callback(reset)


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
	var parent_control := get_parent() as Control
	if parent_control == null:
		return _original_position

	# Pivot is centered, so unscaled size keeps the visual center correct while we scale up.
	return (parent_control.size - size) * 0.5


func _play_three_strikes_sfx() -> void:
	if three_strikes_sfx:
		three_strikes_sfx.play()


func _kill_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

func restart() -> void:
	reset()
