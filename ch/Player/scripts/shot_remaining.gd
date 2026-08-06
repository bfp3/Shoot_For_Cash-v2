extends Control

@onready var ammo_label: RichTextLabel = $ShotRemaining

var _display_ammo := 0
var _reload_tween: Tween


func _ready() -> void:
	pass


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
	_update_label(from_amount)

	#if ammo_label:
		#ammo_label.pivot_offset = ammo_label.size * 0.5

	var bullets_added := to_amount - from_amount
	var duration := clampf(0.08 * float(bullets_added), 0.25, 1.0)

	_reload_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reload_tween.tween_method(_set_display_ammo, float(from_amount), float(to_amount), duration)

	if ammo_label:
		var base_scale := Vector2.ONE
		_reload_tween.parallel().tween_property(ammo_label, "scale", base_scale * 1.5, duration * 0.4)
		_reload_tween.tween_interval(0.25)
		_reload_tween.tween_property(ammo_label, "scale", base_scale, 0.12)


func _set_display_ammo(value: float) -> void:
	_display_ammo = int(round(value))
	_update_label(_display_ammo)


func _update_label(amount: int) -> void:
	if ammo_label:
		ammo_label.text = str(amount).pad_zeros(2)
