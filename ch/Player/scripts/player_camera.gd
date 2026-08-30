extends Camera3D

const CAMERA_WAKING_UP = preload('uid://y7vecy4v88lt')

@export var amount_of_shakes := 1
@export var shake_amount := 0.01
@export var move_speed := 0.25
@export var camera_shaking := false
var camera_shaking_bomb := false
var camera_stop_all_shaking := false

@export var magnitude_of_camera_shake := 1.0

@export var temp_amount := 0.1
@export var temp_dur := 0.1
var cam_shake_tween : Tween = null
var orig_pos : Vector3
var orig_rot : Vector3

@export var zoom_tween_speed := 0.5
@export var zoom_magnitude := 2.0

@export var shoot_shake_amount := 1.0

@export_group("Hold Aim Zoom")
## While shootWeapon is held, ease FOV by hold_aim_fov_delta, then restore on release.
@export var hold_aim_zoom_enabled := true
## Added to resting FOV while held. Negative = zoom in (narrower). Positive = widen.
@export var hold_aim_fov_delta := -2.5
## Must hold this long before the FOV zoom starts.
@export var hold_aim_press_threshold_sec := 0.25
@export var hold_aim_zoom_in_sec := 0.16
@export var hold_aim_zoom_out_sec := 0.22
@export var hold_aim_ease := Tween.EASE_OUT
@export var hold_aim_trans := Tween.TRANS_CUBIC
## If true, zoom aims toward the crosshair (camera rotates so the reticle stays the focus).
## If false, only flat FOV zoom — existing behaviour unchanged.
@export var hold_aim_zoom_toward_crosshair := false
## 0 = flat FOV only, 1 = full look-at-crosshair correction (only used when toward_crosshair is on).
@export_range(0.0, 1.0, 0.05) var hold_aim_crosshair_zoom_strength := 1.0

var _rest_fov := 37.0
var _hold_aim_want := false
var _hold_aim_zoomed := false
var _hold_aim_hold_time := 0.0
var _hold_aim_tween: Tween = null
var _hold_aim_rest_rotation := Vector3.ZERO
var _hold_aim_look_rotation := Vector3.ZERO
var _orig_fov_for_shake := 37.0


func _ready() -> void:
	orig_pos = global_position
	orig_rot = rotation_degrees
	_rest_fov = fov
	_orig_fov_for_shake = fov
	set_process(false)

	EventBus.instance.add_strike.connect(on_strike)
	EventBus.instance.has_hit_three_strikes.connect(_on_three_strikes)
	_ensure_dof_attrs()
	apply_gameplay_blur()


func on_strike() -> void:
	pass


func _on_three_strikes() -> void:
	shake_camera_impact()


func _prepare_shake() -> bool:
	if camera_stop_all_shaking:
		return false
	if cam_shake_tween:
		cam_shake_tween.kill()
	global_position = orig_pos
	rotation_degrees = _hold_aim_settled_rotation()
	fov = _hold_aim_target_fov() if _hold_aim_zoomed and hold_aim_zoom_enabled else _rest_fov
	_orig_fov_for_shake = fov
	return true


func _hold_aim_target_fov() -> float:
	return _rest_fov + hold_aim_fov_delta


## Rest pose for shakes: look-at-crosshair while that zoom is active, else orig_rot.
func _hold_aim_settled_rotation() -> Vector3:
	if _hold_aim_zoomed and hold_aim_zoom_toward_crosshair and hold_aim_zoom_enabled:
		return _hold_aim_look_rotation
	return orig_rot


func _settle_shake(duration: float = 0.5) -> void:
	cam_shake_tween.tween_property(self, "rotation_degrees", _hold_aim_settled_rotation(), duration)
	cam_shake_tween.parallel().tween_property(self, "global_position", orig_pos, duration)
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake, duration)


# --- Hold aim FOV zoom -------------------------------------------------------

## Call each frame (or on press/release) while shootWeapon is held.
func set_hold_aim_pressed(pressed: bool) -> void:
	if not hold_aim_zoom_enabled:
		_hold_aim_want = false
		_hold_aim_hold_time = 0.0
		if _hold_aim_zoomed:
			_hold_aim_zoomed = false
			_tween_hold_aim_fov(_rest_fov, hold_aim_zoom_out_sec)
		set_process(false)
		return

	if pressed:
		if _hold_aim_want:
			return
		_hold_aim_want = true
		_hold_aim_hold_time = 0.0
		set_process(true)
		return

	## Released before or after zoom engaged.
	_hold_aim_want = false
	_hold_aim_hold_time = 0.0
	set_process(false)
	if _hold_aim_zoomed:
		_hold_aim_zoomed = false
		_tween_hold_aim_fov(_rest_fov, hold_aim_zoom_out_sec)


func _process(delta: float) -> void:
	if not _hold_aim_want or not hold_aim_zoom_enabled:
		set_process(false)
		return
	if _hold_aim_zoomed:
		set_process(false)
		return
	_hold_aim_hold_time += delta
	if _hold_aim_hold_time < hold_aim_press_threshold_sec:
		return
	_hold_aim_zoomed = true
	_tween_hold_aim_fov(_hold_aim_target_fov(), hold_aim_zoom_in_sec)
	set_process(false)


func _tween_hold_aim_fov(target: float, duration: float) -> void:
	if _hold_aim_tween:
		_hold_aim_tween.kill()
	duration = maxf(duration, 0.01)
	_hold_aim_tween = create_tween().set_ease(hold_aim_ease).set_trans(hold_aim_trans)

	## Flat FOV zoom only — original behaviour when the flag is off.
	if not hold_aim_zoom_toward_crosshair:
		_hold_aim_tween.tween_property(self, "fov", target, duration)
		return

	var zooming_in := not is_equal_approx(target, _rest_fov)
	if zooming_in:
		_hold_aim_rest_rotation = orig_rot
		_hold_aim_look_rotation = _rotation_for_crosshair_zoom(_rest_fov, target)
		_hold_aim_tween.tween_property(self, "fov", target, duration)
		_hold_aim_tween.parallel().tween_property(self, "rotation_degrees", _hold_aim_look_rotation, duration)
	else:
		_hold_aim_tween.tween_property(self, "fov", target, duration)
		_hold_aim_tween.parallel().tween_property(self, "rotation_degrees", _hold_aim_rest_rotation, duration)


## Rotate so the world point under the crosshair stays under it after the FOV change.
func _rotation_for_crosshair_zoom(from_fov: float, to_fov: float) -> Vector3:
	var screen := _crosshair_screen_pos()
	var prev_fov := fov
	var prev_rot := rotation_degrees
	## Sample rays from the resting pose so mid-shake / mid-tween don't skew the aim.
	rotation_degrees = _hold_aim_rest_rotation
	fov = from_fov
	var dir_from := project_ray_normal(screen)
	fov = to_fov
	var dir_to := project_ray_normal(screen)

	if dir_from.length_squared() < 0.0001 or dir_to.length_squared() < 0.0001:
		fov = prev_fov
		rotation_degrees = prev_rot
		return _hold_aim_rest_rotation
	dir_from = dir_from.normalized()
	dir_to = dir_to.normalized()
	if dir_from.dot(dir_to) > 0.999999:
		fov = prev_fov
		rotation_degrees = prev_rot
		return _hold_aim_rest_rotation

	var q := Quaternion(dir_to, dir_from)
	var strength := clampf(hold_aim_crosshair_zoom_strength, 0.0, 1.0)
	if strength <= 0.001:
		fov = prev_fov
		rotation_degrees = prev_rot
		return _hold_aim_rest_rotation
	if strength < 0.999:
		q = Quaternion.IDENTITY.slerp(q, strength)

	## Still at rest pose — apply correction to current global basis.
	var new_global_basis := Basis(q) * global_transform.basis
	var parent_node := get_parent() as Node3D
	var local_basis: Basis = (
		parent_node.global_transform.basis.inverse() * new_global_basis
		if parent_node else new_global_basis
	)
	var e := local_basis.get_euler()
	fov = prev_fov
	rotation_degrees = prev_rot
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


func _crosshair_screen_pos() -> Vector2:
	## Camera lives at Player/Cam_pivot/Camera3D.
	var player: Node = get_parent().get_parent() if get_parent() else null
	if player != null and player.has_method("_aim_screen_center"):
		return player._aim_screen_center()
	if player != null and player.get("crosshair") != null:
		var ch: Control = player.crosshair
		var off = player.get("CROSSHAIR_CENTER_OFFSET")
		if ch and off != null:
			return ch.global_position + off
		if ch:
			return ch.global_position + Vector2(20.0, 20.0)
	return get_viewport().get_visible_rect().size * 0.5


func sync_rest_fov_from_current() -> void:
	if not _hold_aim_zoomed:
		_rest_fov = fov


# --- Destroy / hit camera shakes (one named effect per caller type) -----------

## Standard white rock (rock / rock_type_1 / SMALL).
func shake_camera_rock() -> void:
	await _shake_rock()


func shake_camera_rock_stay() -> void:
	await _shake_rock_stay()


func shake_camera_rock_grey() -> void:
	await _shake_rock_grey()


func shake_camera_rock_avoider() -> void:
	await _shake_rock_avoider()


func shake_camera_rock_red_attacker() -> void:
	await _shake_rock_red_attacker()


func shake_camera_rock_hazard() -> void:
	await _shake_rock_hazard()


func shake_camera_rock_crate() -> void:
	await _shake_rock_crate()


func shake_camera_rock_smokecan() -> void:
	await _shake_rock_smokecan()


func shake_camera_rock_chaser() -> void:
	await _shake_rock_chaser()


func shake_camera_rock_mothership() -> void:
	await _shake_rock_mothership()


func shake_camera_rock_juggle() -> void:
	await _shake_rock_juggle()


func shake_camera_rock_pigeon() -> void:
	await _shake_rock_pigeon()


## Marked sky-mine / freeze-mine detonation.
func shake_camera_sky_mine() -> void:
	await _shake_sky_mine()


func shake_camera_balloon() -> void:
	await _shake_balloon()


func shake_camera_orange() -> void:
	await _shake_orange()


func shake_camera_pineapple() -> void:
	await _shake_pineapple()


func shake_camera_standing_target() -> void:
	await _shake_standing_target()


func shake_camera_bonus_target() -> void:
	await _shake_bonus_target()


func shake_camera_bonus_time() -> void:
	await _shake_bonus_time()


## Side-biased X punch when a rock escapes the screen.
## side_sign: -1 = miss on the left (kick camera left), +1 = miss on the right.
func shake_camera_oob_miss(side_sign: float = 1.0, amount: float = 0.16, duration: float = 0.1) -> void:
	await _shake_oob_miss(side_sign, amount, duration)


## Three-strikes / heavy impact (EventBus has_hit_three_strikes).
func shake_camera_impact() -> void:
	await _shake_three_strikes()


func shake_camera_shooting() -> void:
	await _shake_shooting()


func pulse_shake_camera() -> void:
	await _shake_egg_pulse()


func shake_camera_based_on_position(_distance: float) -> void:
	pass


func little_camera_movement() -> void:
	if camera_stop_all_shaking:
		return

	var target_rest := _rest_fov
	var _shake_amount = 0.25
	var little_camera_zoomy = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	little_camera_zoomy.tween_property(self, "fov", zoom_magnitude, zoom_tween_speed * 3).as_relative()
	little_camera_zoomy.tween_property(self, "fov", target_rest, zoom_tween_speed * 5)
	little_camera_zoomy.parallel().tween_callback(camera_sounds)
	little_camera_zoomy.tween_property(self, "rotation_degrees:x", -_shake_amount, zoom_tween_speed).as_relative()
	little_camera_zoomy.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount, zoom_tween_speed).as_relative()
	little_camera_zoomy.tween_property(self, "rotation_degrees:x", _shake_amount, zoom_tween_speed * 1.5).as_relative()
	little_camera_zoomy.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, zoom_tween_speed * 1.5).as_relative()

	await little_camera_zoomy.finished


func camera_sounds() -> void:
	if camera_stop_all_shaking:
		return
	CommonCode.play_sound_instance_pitch_adjusted(CAMERA_WAKING_UP, -10.0, 1.0)


# =============================================================================
# Per-type shake implementations
# =============================================================================

func _shake_rock() -> void:
	if not _prepare_shake():
		return
	var _shake_amount := 0.5
	var _max_shake := _shake_amount * 2.0

	rotation_degrees.x = clamp(rotation_degrees.x, -_max_shake, _max_shake)
	rotation_degrees.z = clamp(rotation_degrees.z, -_max_shake, _max_shake)

	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount, temp_dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount, temp_dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, temp_dur * 1.5).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, temp_dur * 1.5).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees", _hold_aim_settled_rotation(), 0.75)

	await cam_shake_tween.finished
	camera_shaking_bomb = false


func _shake_rock_stay() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -0.18, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:y", 0.03, 0.06).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.22, 0.09).as_relative()
	_settle_shake(0.28)
	await cam_shake_tween.finished


func _shake_rock_grey() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	for i in 4:
		var s := 1.0 if i % 2 == 0 else -1.0
		var a := 0.12 * (1.0 - float(i) * 0.18)
		cam_shake_tween.tween_property(self, "rotation_degrees:x", a * s, 0.035).as_relative()
		cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", a * -s * 0.7, 0.035).as_relative()
		cam_shake_tween.parallel().tween_property(self, "position:x", 0.015 * s, 0.035).as_relative()
	_settle_shake(0.3)
	await cam_shake_tween.finished


func _shake_rock_avoider() -> void:
	if not _prepare_shake():
		return
	camera_shaking = true
	var rot_kick := maxf(shake_amount * magnitude_of_camera_shake * 8.0, 2.2)
	var pos_kick := maxf(shoot_shake_amount * 3.5, 0.55)
	var dur := maxf(temp_dur, 0.08)
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", rot_kick, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -rot_kick * 0.85, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:y", rot_kick * 0.35, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", pos_kick, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:y", -pos_kick * 0.35, dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -rot_kick * 1.8, dur * 1.15).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", rot_kick * 1.6, dur * 1.15).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:y", -rot_kick * 0.55, dur * 1.15).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", pos_kick * 0.55, dur * 1.15).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", rot_kick * 1.1, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -rot_kick * 0.9, dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", -pos_kick * 0.4, dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -rot_kick * 0.55, dur * 0.9).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", rot_kick * 0.45, dur * 0.9).as_relative()
	_settle_shake(0.75)
	await cam_shake_tween.finished
	camera_shaking = false


func _shake_rock_red_attacker() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	cam_shake_tween.tween_property(self, "position:y", -0.35, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", 0.4, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", 1.8, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake + 4.0, 0.06)
	cam_shake_tween.tween_property(self, "position:y", 0.18, 0.1).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", -1.1, 0.1).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake - 1.0, 0.1)
	_settle_shake(0.65)
	await cam_shake_tween.finished


func _shake_rock_hazard() -> void:
	if not _prepare_shake():
		return
	camera_shaking = true
	var _shake_amount := shake_amount * magnitude_of_camera_shake * 3.0
	var _pos_shake := shoot_shake_amount * 1.5
	var _dur := temp_dur
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", _pos_shake, _dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount * 1.6, _dur * 1.2).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount * 1.6, _dur * 1.2).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount * 0.8, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount * 0.8, _dur).as_relative()
	_settle_shake(0.6)
	await cam_shake_tween.finished
	camera_shaking = false


func _shake_rock_crate() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	cam_shake_tween.tween_property(self, "position:z", 0.22, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", 0.55, 0.05).as_relative()
	cam_shake_tween.tween_property(self, "position:z", -0.12, 0.08).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", -0.35, 0.08).as_relative()
	_settle_shake(0.35)
	await cam_shake_tween.finished


func _shake_rock_smokecan() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake - 3.5, 0.07)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", 0.35, 0.07).as_relative()
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake + 1.5, 0.1)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -0.45, 0.1).as_relative()
	_settle_shake(0.4)
	await cam_shake_tween.finished


func _shake_rock_chaser() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	cam_shake_tween.tween_property(self, "rotation_degrees:y", 0.9, 0.08).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", 0.1, 0.08).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:y", -1.4, 0.12).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", -0.14, 0.12).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake - 1.5, 0.12)
	cam_shake_tween.tween_property(self, "rotation_degrees:y", 0.5, 0.09).as_relative()
	_settle_shake(0.4)
	await cam_shake_tween.finished


func _shake_rock_mothership() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake - 5.0, 0.08)
	cam_shake_tween.parallel().tween_property(self, "position:z", -0.15, 0.08).as_relative()
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake + 2.0, 0.12)
	cam_shake_tween.parallel().tween_property(self, "position:z", 0.2, 0.12).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", -0.4, 0.12).as_relative()
	_settle_shake(0.4)
	await cam_shake_tween.finished


func _shake_rock_juggle() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	cam_shake_tween.tween_property(self, "rotation_degrees:z", 1.4, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", 0.08, 0.06).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:z", -2.2, 0.1).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:x", -0.12, 0.1).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:z", 0.7, 0.08).as_relative()
	_settle_shake(0.45)
	await cam_shake_tween.finished


func _shake_rock_pigeon() -> void:
	## Lighter cousin of the standard rock punch.
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -0.28, temp_dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", 0.22, temp_dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.32, temp_dur * 1.3).as_relative()
	_settle_shake(0.4)
	await cam_shake_tween.finished


func _shake_sky_mine() -> void:
	var _shake_amount: float = clamp(1.1, -2.0, 2.0)
	var _dur: float = 0.1
	if cam_shake_tween:
		cam_shake_tween.kill()
	cam_shake_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, _dur)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount, _dur)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.0, _dur + 0.1)
	await cam_shake_tween.finished


func _shake_balloon() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -0.14, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:y", 0.04, 0.05).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.18, 0.08).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake - 1.2, 0.08)
	_settle_shake(0.3)
	await cam_shake_tween.finished


func _shake_orange() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake - 2.8, 0.06)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", 0.28, 0.06).as_relative()
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake + 1.2, 0.1)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -0.35, 0.1).as_relative()
	_settle_shake(0.35)
	await cam_shake_tween.finished


func _shake_pineapple() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	cam_shake_tween.tween_property(self, "position:y", -0.28, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", 0.32, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", 1.4, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake + 3.0, 0.05)
	cam_shake_tween.tween_property(self, "position:y", 0.14, 0.09).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", -0.9, 0.09).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake - 0.8, 0.09)
	_settle_shake(0.55)
	await cam_shake_tween.finished


func _shake_standing_target() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	cam_shake_tween.tween_property(self, "position:z", 0.18, 0.05).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", 0.45, 0.05).as_relative()
	cam_shake_tween.tween_property(self, "position:z", -0.1, 0.08).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:x", -0.28, 0.08).as_relative()
	_settle_shake(0.32)
	await cam_shake_tween.finished


func _shake_bonus_target() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake - 4.0, 0.07)
	cam_shake_tween.parallel().tween_property(self, "position:z", -0.12, 0.07).as_relative()
	cam_shake_tween.tween_property(self, "fov", _orig_fov_for_shake + 1.5, 0.11)
	cam_shake_tween.parallel().tween_property(self, "position:z", 0.15, 0.11).as_relative()
	_settle_shake(0.38)
	await cam_shake_tween.finished


func _shake_bonus_time() -> void:
	if not _prepare_shake():
		return
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -0.2, 0.06).as_relative()
	cam_shake_tween.parallel().tween_property(self, "fov", _orig_fov_for_shake - 2.0, 0.06)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.24, 0.09).as_relative()
	_settle_shake(0.3)
	await cam_shake_tween.finished


func _shake_oob_miss(side_sign: float = 1.0, amount: float = 0.16, duration: float = 0.1) -> void:
	if camera_stop_all_shaking:
		return
	if is_zero_approx(side_sign):
		side_sign = 1.0
	side_sign = signf(side_sign)

	if cam_shake_tween:
		cam_shake_tween.kill()

	global_position = orig_pos
	rotation_degrees = _hold_aim_settled_rotation()

	var kick_x := amount * side_sign
	var dur := maxf(duration, 0.02)

	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "position:x", kick_x, dur).as_relative()
	cam_shake_tween.tween_property(self, "position:x", -kick_x * 1.35, dur * 1.15).as_relative()
	cam_shake_tween.tween_property(self, "position:x", kick_x * 0.45, dur * 0.9).as_relative()
	cam_shake_tween.tween_property(self, "global_position", orig_pos, 0.35)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees", _hold_aim_settled_rotation(), 0.35)

	await cam_shake_tween.finished


func _shake_three_strikes() -> void:
	## Same body as former impact shake (strikeout camera punch).
	if not _prepare_shake():
		return
	camera_shaking = true
	var _shake_amount := shake_amount * magnitude_of_camera_shake * 3.0
	var _pos_shake := shoot_shake_amount * 1.5
	var _dur := temp_dur
	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", _pos_shake, _dur).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount * 1.6, _dur * 1.2).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount * 1.6, _dur * 1.2).as_relative()
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount * 0.8, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount * 0.8, _dur).as_relative()
	_settle_shake(0.6)
	await cam_shake_tween.finished
	camera_shaking = false


func _shake_shooting() -> void:
	if cam_shake_tween:
		cam_shake_tween.kill()
	var max_recoil := shoot_shake_amount * 2.0
	var target_z = min(position.z + shoot_shake_amount, max_recoil)
	cam_shake_tween = create_tween()
	cam_shake_tween.tween_property(self, "position:z", target_z, move_speed)
	cam_shake_tween.tween_property(self, "position:z", 0.0, move_speed * 1.5)
	cam_shake_tween.parallel().tween_property(self, "position:y", 0.0, move_speed * 1.5)
	await cam_shake_tween.finished


func _shake_egg_pulse() -> void:
	var _orig_pos_y: float = self.global_position.y
	var tween_pulse_shake = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_pulse_shake.tween_interval(0.1)
	tween_pulse_shake.tween_property(self, "global_position:y", -0.2, move_speed).as_relative()
	tween_pulse_shake.tween_interval(0.1)
	tween_pulse_shake.tween_property(self, "global_position:y", _orig_pos_y, 1.0)
	await tween_pulse_shake.finished


# --- Depth of field blur (menus / travel / gameplay) -------------------------
## Blur while shop, tally, pause, or map is up. Edit in the inspector.
@export var UI_overlay_blur_amount := 0.2
## Blur while travelling between levels.
@export var transition_blur_amount := 1.0
## Blur while actively playing a round.
@export var gameplay_blur_amount := 0.0
## Default tween time when switching blur amounts.
@export var blur_tween_duration := 0.33
## DOF amount while black-hazard smoke is on screen.
const hazard_smoke_blur_amount := 0.1
## How long hazard smoke blur lasts; each new black-rock destroy refreshes this window.
@export var hazard_smoke_blur_duration := 5.0

var _dof_attrs: CameraAttributesPractical = null
var _dof_default_amount := 0.0
var _blur_tween: Tween
var _env_cache: Dictionary = {} # path -> Environment
var _hazard_smoke_blur_token := 0


func set_level_environment_from_path(path: String) -> void:
	if path.is_empty():
		return
	var env: Environment = null
	if _env_cache.has(path):
		env = _env_cache[path] as Environment
	else:
		env = load(path) as Environment
		if env:
			_env_cache[path] = env
	if env == null:
		push_warning("PlayerCamera: failed to load environment '%s'" % path)
		return
	set("environment", env)


func set_level_environment(env: Environment) -> void:
	if env == null:
		return
	set("environment", env)


func dim_final_round_environment(amount: float, duration: float) -> void:
	var env := get("environment") as Environment
	if env == null:
		return
	var working := env.duplicate() as Environment
	if working == null:
		return
	set("environment", working)
	var ambient_to := maxf(working.ambient_light_energy - amount, 0.0)
	var bg_to := maxf(working.background_energy_multiplier - amount, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(working, "ambient_light_energy", ambient_to, duration)
	tween.tween_property(working, "background_energy_multiplier", bg_to, duration)


func _ensure_dof_attrs() -> void:
	if _dof_attrs != null and is_instance_valid(_dof_attrs):
		return
	## Use get/set so analyzers that miss Camera3D.attributes still parse cleanly.
	var attrs: Variant = get("attributes")
	if attrs is CameraAttributesPractical:
		## Duplicate so we don't mutate the shared .tres on disk.
		_dof_attrs = (attrs as CameraAttributesPractical).duplicate(true) as CameraAttributesPractical
		set("attributes", _dof_attrs)
		_dof_default_amount = _dof_attrs.dof_blur_amount
		return
	_dof_attrs = CameraAttributesPractical.new()
	_dof_attrs.dof_blur_far_enabled = true
	_dof_attrs.dof_blur_near_enabled = true
	_dof_attrs.dof_blur_far_distance = 0.01
	_dof_attrs.dof_blur_near_distance = 0.01
	_dof_attrs.dof_blur_amount = 0.0
	set("attributes", _dof_attrs)
	_dof_default_amount = 0.0


func _apply_dof_blur_amount(amount: float) -> void:
	if _dof_attrs == null:
		return
	_dof_attrs.dof_blur_amount = maxf(amount, 0.0)
	var on := _dof_attrs.dof_blur_amount > 0.001
	if on:
		_dof_attrs.dof_blur_far_enabled = true
		_dof_attrs.dof_blur_near_enabled = true


func set_dof_blur(amount: float) -> void:
	_ensure_dof_attrs()
	if _blur_tween:
		_blur_tween.kill()
		_blur_tween = null
	_apply_dof_blur_amount(amount)


## Smoothly tween DOF blur to `amount`. Pass duration < 0 to use blur_tween_duration.
func tween_dof_blur(amount: float, duration: float = -1.0) -> void:
	_ensure_dof_attrs()
	if _dof_attrs == null:
		return
	if duration < 0.0:
		duration = blur_tween_duration
	var target := maxf(amount, 0.0)
	if duration <= 0.0:
		set_dof_blur(target)
		return
	if _blur_tween:
		_blur_tween.kill()
	## Turning blur on: enable DOF before the tween so the ramp is visible.
	if target > 0.001:
		_dof_attrs.dof_blur_far_enabled = true
		_dof_attrs.dof_blur_near_enabled = true
	_blur_tween = create_tween()
	_blur_tween.tween_method(_apply_dof_blur_amount, _dof_attrs.dof_blur_amount, target, duration)


func apply_ui_overlay_blur() -> void:
	tween_dof_blur(UI_overlay_blur_amount)


func apply_transition_blur() -> void:
	tween_dof_blur(transition_blur_amount)


func apply_gameplay_blur() -> void:
	tween_dof_blur(gameplay_blur_amount)


## Black hazard smoke: blur to hazard_smoke_blur_amount, then restore after duration
## unless another hazard smoke blur refreshes the timer.
func apply_hazard_smoke_blur() -> void:
	_hazard_smoke_blur_token += 1
	var token := _hazard_smoke_blur_token
	tween_dof_blur(hazard_smoke_blur_amount)
	var wait := maxf(hazard_smoke_blur_duration, 0.01)
	await get_tree().create_timer(wait).timeout
	if token != _hazard_smoke_blur_token:
		return
	_restore_blur_after_hazard_smoke()


func _restore_blur_after_hazard_smoke() -> void:
	var shop := get_tree().get_first_node_in_group("shop_main_menu") as CanvasItem
	var map_menu := get_tree().get_first_node_in_group("map_menu") as CanvasItem
	var tally := get_tree().get_first_node_in_group("tally_card_menu") as CanvasItem
	var pause := get_tree().get_first_node_in_group("pause_menu") as CanvasItem
	if (shop and shop.visible) or (map_menu and map_menu.visible) or (tally and tally.visible) or (pause and pause.visible):
		apply_ui_overlay_blur()
	else:
		apply_gameplay_blur()


func reset_dof_blur_to_default() -> void:
	_ensure_dof_attrs()
	tween_dof_blur(_dof_default_amount)
