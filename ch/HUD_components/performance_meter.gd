class_name PerformanceMeter
extends Control
## Guitar Hero-style round meter. Units drive the needle; money is ratio × money_base.
## Hitting 0 from a penalty strikeouts through the existing continue / fail path.
## Visuals live in the scene: Face, Needle, Shaft, Hub.
## Logical `_value` updates immediately. The needle can lag on gains (delay + wobble).

@export_group("Meter")
@export var meter_max := 30.0
@export var meter_start := 15.0

@export_group("Money")
@export var money_base := 2
@export var starting_cash := 500
@export var star_1_cash := 700
@export var star_2_cash := 800
@export var star_3_cash := 1000

@export_group("Event units")
@export var yellow_hit := 1.0
@export var grey_hit := 0.5
@export var white_hit := 3.0
@export var black_hit := -2.0
@export var balloon_pop := -2.0
@export var yellow_miss := -2.0
@export var grey_miss := 0.0
@export var white_miss := 0.0
@export var sniped := 1.0
@export var combo_double := 3.0
@export var combo_triple := 4.0
@export var combo_quad := 8.0
@export var combo_more := 20.0

@export_group("Zones")
## Fractions of meter_max. Fail / 1★ / 2★ / 3★.
@export var zone_fail_end := 0.25
@export var zone_one_star_end := 0.5
@export var zone_two_star_end := 0.75
@export var color_fail := Color("C70102")
@export var color_one_star := Color("E07A1F")
@export var color_two_star := Color("E0B01F")
@export var color_three_star := Color("3DAA3A")

@export_group("Needle")
@export var gain_delay_sec := 0.2
@export var gain_tween_sec := 0.45
@export var start_lerp_sec := 0.85
@export var idle_wobble_deg := 0.4
@export var idle_wobble_hz := 1.2

var _value := 15.0
var _display_value := 0.0
var _failed := false
var _needle_tween: Tween
var _gain_delay_tween: Tween
var _wobble_time := 0.0
var _wobble_kick := 0.0

@onready var _needle: Control = %Needle
@onready var _hub: ColorRect = %Hub
@onready var _danger_layer: CanvasLayer = get_node_or_null("DangerLayer") as CanvasLayer
@onready var _danger_vignette: DangerVignette = get_node_or_null("%DangerVignette") as DangerVignette


func _ready() -> void:
	add_to_group("performance_meter")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value = meter_start
	_display_value = 0.0
	set_process(false)
	if _danger_layer:
		_danger_layer.visible = false
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_danger_fx()


func _process(delta: float) -> void:
	_wobble_time += delta
	_wobble_kick = move_toward(_wobble_kick, 0.0, 14.0 * delta)
	_apply_needle_visual()
	_update_hub_color()
	_update_danger_fx()


func reset_for_round() -> void:
	_failed = false
	_value = clampf(meter_start, 0.0, meter_max)
	if gl_PlayerState:
		gl_PlayerState.dataset.bonus_cash = starting_cash
		if EventBus.instance:
			EventBus.instance.cash_pool_changed.emit(starting_cash)
	show()
	_play_intro_needle()


func restore_to_start() -> void:
	_failed = false
	_value = clampf(meter_start, 0.0, meter_max)
	_play_intro_needle()


func get_value() -> float:
	return _value


func get_star_count() -> int:
	return _star_count_for(_value)


func get_star_cash() -> int:
	match get_star_count():
		1:
			return star_1_cash
		2:
			return star_2_cash
		3:
			return star_3_cash
		_:
			return 0


func money_for(units: float) -> int:
	return int(round(units * float(money_base)))


func apply_yellow_hit() -> int:
	return _apply(yellow_hit, false)


func apply_grey_hit() -> int:
	return _apply(grey_hit, false)


func apply_white_hit() -> int:
	return _apply(white_hit, false)


func apply_combo(rock_count: int) -> int:
	if rock_count < 2:
		return 0
	var units := combo_double
	if rock_count == 3:
		units = combo_triple
	elif rock_count == 4:
		units = combo_quad
	elif rock_count >= 5:
		units = combo_more
	return _apply(units, false)


## Small-scope / shrink-scope hit (same moment as the SNIPED callout).
func apply_sniped() -> int:
	if is_zero_approx(sniped):
		return 0
	return _apply(sniped, sniped < 0.0)


## Penalty (black / balloon / yellow miss / other former strikes). Returns true if this emptied the meter.
func apply_generic_penalty(kind: String = "miss") -> bool:
	var units := yellow_miss
	match String(kind).to_lower():
		"black", "hazard":
			units = black_hit
		"balloon":
			units = balloon_pop
		"grey", "grey_miss", "rock-grey", "rock_type_grey":
			units = grey_miss
		"white", "white_miss", "rock-white", "rock_type_white":
			units = white_miss
		_:
			units = yellow_miss
	if is_zero_approx(units):
		return _failed
	_apply(units, true)
	return _failed


func apply_rock_hit(rock_type: int) -> int:
	var units := units_for_rock_hit(rock_type)
	if units == 0.0:
		return 0
	return _apply(units, units < 0.0)


func units_for_rock_hit(rock_type: int) -> float:
	if rock_type == RockInstance.RockSize.WHITE:
		return white_hit
	if (
		rock_type == RockInstance.RockSize.GREY
		or rock_type == RockInstance.RockSize.RICO
		or rock_type == RockInstance.RockSize.AMMO
		or rock_type == RockInstance.RockSize.BOUNCE
	):
		return grey_hit
	if (
		rock_type == RockInstance.RockSize.SMALL
		or rock_type == RockInstance.RockSize.STAY
		or rock_type == RockInstance.RockSize.INVISIBLE
	):
		return yellow_hit
	return 0.0


func handles_rock_hit(rock_type: int) -> bool:
	return units_for_rock_hit(rock_type) != 0.0


static func find_meter(from: Node) -> PerformanceMeter:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group("performance_meter") as PerformanceMeter


func _apply(units: float, is_penalty: bool) -> int:
	if _failed:
		return 0
	if is_penalty:
		units = -absf(units)
	var money := money_for(units)
	if money != 0 and gl_PlayerState:
		gl_PlayerState.add_to_cash_pool(money)
	_value = clampf(_value + units, 0.0, meter_max)
	if units < 0.0:
		_drop_needle()
	elif units > 0.0:
		_queue_gain_needle()
	if is_penalty and not _no_lives() and _value <= 0.001:
		_fail()
	return money


func _no_lives() -> bool:
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager != null and round_manager.has_method("is_current_round_no_lives"):
		return bool(round_manager.is_current_round_no_lives())
	return false


func _fail() -> void:
	if _failed:
		return
	_failed = true
	_value = 0.0
	_drop_needle()
	if EventBus.instance:
		EventBus.instance.has_hit_three_strikes.emit()


func _danger_amount() -> float:
	if not visible or meter_max <= 0.0:
		return 0.0
	var t := _value / meter_max
	if t >= zone_fail_end:
		return 0.0
	return clampf(1.0 - t / zone_fail_end, 0.0, 1.0)


func _update_danger_fx() -> void:
	if not is_node_ready():
		return
	var amount := _danger_amount() if visible else 0.0
	if _danger_layer:
		_danger_layer.visible = visible
	if _danger_vignette:
		_danger_vignette.set_danger_amount(amount)


func _star_count_for(v: float) -> int:
	var t := 0.0 if meter_max <= 0.0 else v / meter_max
	if t < zone_fail_end:
		return 0
	if t < zone_one_star_end:
		return 1
	if t < zone_two_star_end:
		return 2
	return 3


func _units_to_rotation(v: float) -> float:
	var t := 0.0 if meter_max <= 0.0 else clampf(v / meter_max, 0.0, 1.0)
	return lerp(-90.0, 90.0, t)


func _apply_needle_visual() -> void:
	if _needle == null:
		return
	var idle := sin(_wobble_time * TAU * idle_wobble_hz) * idle_wobble_deg
	idle += sin(_wobble_time * TAU * idle_wobble_hz * 2.15 + 0.7) * idle_wobble_deg * 0.28
	_needle.rotation_degrees = _units_to_rotation(_display_value) + idle + _wobble_kick


func _update_hub_color() -> void:
	if _hub == null:
		return
	match _star_count_for(_display_value):
		0:
			_hub.color = color_fail
		1:
			_hub.color = color_one_star
		2:
			_hub.color = color_two_star
		_:
			_hub.color = color_three_star


func _play_intro_needle() -> void:
	_kill_needle_motion()
	_display_value = 0.0
	_wobble_kick = 0.0
	set_process(true)
	_apply_needle_visual()
	_update_hub_color()
	_animate_needle_up(_value, start_lerp_sec)


func _queue_gain_needle() -> void:
	set_process(true)
	if _gain_delay_tween != null and _gain_delay_tween.is_valid():
		return
	if _needle_tween != null and _needle_tween.is_valid() and _display_value < _value:
		_animate_needle_up(_value, gain_tween_sec)
		return
	_gain_delay_tween = create_tween()
	_gain_delay_tween.tween_interval(maxf(gain_delay_sec, 0.0))
	_gain_delay_tween.tween_callback(_play_gain_needle)


func _play_gain_needle() -> void:
	_animate_needle_up(_value, gain_tween_sec)


func _drop_needle() -> void:
	_kill_needle_motion()
	_display_value = _value
	_wobble_kick = 0.0
	set_process(true)
	_apply_needle_visual()
	_update_hub_color()


func _animate_needle_up(target: float, duration: float) -> void:
	if _needle_tween != null and _needle_tween.is_valid():
		_needle_tween.kill()
	target = clampf(target, 0.0, meter_max)
	var delta_u := target - _display_value
	if delta_u <= 0.001:
		_display_value = target
		return
	duration = maxf(duration, 0.05)
	var overshoot := minf(target + maxf(delta_u * 0.16, 0.28), meter_max + meter_max * 0.03)
	var undershoot := maxf(target - maxf(delta_u * 0.05, 0.1), 0.0)
	var up_sec := duration * 0.58
	var back_sec := duration * 0.24
	var settle_sec := duration * 0.18
	_wobble_kick = clampf(delta_u * 0.55, 1.2, 3.2)
	_needle_tween = create_tween()
	_needle_tween.tween_property(self, "_display_value", overshoot, up_sec)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_needle_tween.tween_property(self, "_display_value", undershoot, back_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_needle_tween.tween_property(self, "_display_value", target, settle_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_needle_motion() -> void:
	if _gain_delay_tween != null and _gain_delay_tween.is_valid():
		_gain_delay_tween.kill()
	_gain_delay_tween = null
	if _needle_tween != null and _needle_tween.is_valid():
		_needle_tween.kill()
	_needle_tween = null
