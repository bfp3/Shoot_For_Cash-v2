extends Control

const RELOAD_TICK_SFX = preload("res://sfx/reload_sound_01.ogg")

@onready var ammo_label: RichTextLabel = %ShotRemainingLabel

@export_group("Low Ammo Pulse")
@export var low_ammo_threshold := 20
@export var low_ammo_pulse_sec := 0.45
@export var low_ammo_pulse_min_alpha := 0.35
@export var low_ammo_pulse_max_alpha := 1.0

var _display_ammo := 0
var _reload_tween: Tween
var _reload_tick_sfx: AudioStreamPlayer
var _last_tick_ammo := -1
var _low_ammo_pulse_active := false
var _low_ammo_pulse_tween: Tween
var _ammo_base_modulate := Color.WHITE


func _ready() -> void:
	_ammo_base_modulate = modulate
	_reload_tick_sfx = AudioStreamPlayer.new()
	_reload_tick_sfx.name = "ReloadTickSFX"
	_reload_tick_sfx.stream = RELOAD_TICK_SFX
	_reload_tick_sfx.bus = "Master"
	_reload_tick_sfx.volume_db = -26.0
	add_child(_reload_tick_sfx)


func set_ammo(amount: int, animate := false) -> void:
	if animate:
		play_reload_fill(_display_ammo, amount)
	else:
		_display_ammo = amount
		_update_label(amount)
	set_low_ammo_pulse(amount < low_ammo_threshold)


func play_reload_fill(from_amount: int, to_amount: int) -> void:
	if _reload_tween:
		_reload_tween.kill()

	from_amount = maxi(from_amount, 0)
	to_amount = maxi(to_amount, 0)
	_display_ammo = from_amount
	_last_tick_ammo = from_amount
	_update_label(from_amount)

	var bullets_added := to_amount - from_amount
	if bullets_added <= 0:
		_display_ammo = to_amount
		_update_label(to_amount)
		set_low_ammo_pulse(to_amount < low_ammo_threshold)
		return

	## Match ammo_panel magazine load pacing (~0.08s per bullet).
	var duration := clampf(0.08 * float(bullets_added), 0.25, 1.0)

	_reload_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_method(_set_display_ammo, float(from_amount), float(to_amount), duration)
	_reload_tween.tween_callback(func() -> void:
		set_low_ammo_pulse(to_amount < low_ammo_threshold)
	)

	if ammo_label:
		var base_scale := Vector2.ONE
		_reload_tween.parallel().tween_property(ammo_label, "scale", base_scale * 1.35, duration * 0.2)
		_reload_tween.tween_interval(0.18)
		_reload_tween.tween_property(ammo_label, "scale", base_scale, 0.12)


## Awaitable version used by range-clear reward / previews.
func await_reload_fill(from_amount: int, to_amount: int) -> void:
	play_reload_fill(from_amount, to_amount)
	if _reload_tween != null and is_instance_valid(_reload_tween) and _reload_tween.is_running():
		await _reload_tween.finished


func _set_display_ammo(value: float) -> void:
	var next := int(round(value))
	if next != _last_tick_ammo:
		_last_tick_ammo = next
		_play_reload_tick()
	_display_ammo = next
	_update_label(_display_ammo)


func _play_reload_tick() -> void:
	if _reload_tick_sfx == null or RELOAD_TICK_SFX == null:
		return
	_reload_tick_sfx.pitch_scale = randf_range(0.95, 1.08)
	_reload_tick_sfx.volume_db = -28.0
	_reload_tick_sfx.play()


func _update_label(amount: int) -> void:
	if ammo_label:
		ammo_label.text = '[wave]' + str(amount).pad_zeros(2)


func set_low_ammo_pulse(active: bool) -> void:
	if active == _low_ammo_pulse_active:
		return
	_low_ammo_pulse_active = active
	if _low_ammo_pulse_tween:
		_low_ammo_pulse_tween.kill()
		_low_ammo_pulse_tween = null
	if not active:
		modulate = _ammo_base_modulate
		return

	modulate.a = low_ammo_pulse_max_alpha
	_low_ammo_pulse_tween = create_tween().set_loops()
	_low_ammo_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half := maxf(low_ammo_pulse_sec, 0.05)
	_low_ammo_pulse_tween.tween_property(self, "modulate:a", low_ammo_pulse_min_alpha, half)
	_low_ammo_pulse_tween.tween_property(self, "modulate:a", low_ammo_pulse_max_alpha, half)
