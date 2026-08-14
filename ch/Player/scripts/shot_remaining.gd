extends Control

const RELOAD_TICK_SFX = preload("res://sfx/reload_sound_01.ogg")

@onready var ammo_label: RichTextLabel = %ShotRemainingLabel

var _display_ammo := 0
var _reload_tween: Tween
var _reload_tick_sfx: AudioStreamPlayer
var _last_tick_ammo := -1


func _ready() -> void:
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
		return

	## Match ammo_panel magazine load pacing (~0.08s per bullet).
	var duration := clampf(0.08 * float(bullets_added), 0.25, 1.0)

	_reload_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_method(_set_display_ammo, float(from_amount), float(to_amount), duration)

	if ammo_label:
		var base_scale := Vector2.ONE
		_reload_tween.parallel().tween_property(ammo_label, "scale", base_scale * 1.35, duration * 0.2)
		_reload_tween.tween_interval(0.18)
		_reload_tween.tween_property(ammo_label, "scale", base_scale, 0.12)


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
