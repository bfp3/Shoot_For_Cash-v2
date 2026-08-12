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

func _ready() -> void:
	orig_pos = global_position
	orig_rot = rotation_degrees
	
	EventBus.instance.add_strike.connect(on_strike)
	EventBus.instance.has_hit_three_strikes.connect(_on_three_strikes)
	_ensure_dof_attrs()
	apply_gameplay_blur()

func on_strike() -> void:
	pass

func _on_three_strikes() -> void:
	shake_camera_impact()


## Side-biased X punch when a rock escapes the screen.
## side_sign: -1 = miss on the left (kick camera left), +1 = miss on the right.
func shake_camera_oob_miss(side_sign: float = 1.0, amount: float = 0.16, duration: float = 0.1) -> void:
	if camera_stop_all_shaking:
		return
	if is_zero_approx(side_sign):
		side_sign = 1.0
	side_sign = signf(side_sign)

	if cam_shake_tween:
		cam_shake_tween.kill()

	# Start from a known-good transform so stacked shakes don't drift.
	global_position = orig_pos
	rotation_degrees = orig_rot

	var kick_x := amount * side_sign
	var dur := maxf(duration, 0.02)

	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	cam_shake_tween.tween_property(self, "position:x", kick_x, dur).as_relative()
	cam_shake_tween.tween_property(self, "position:x", -kick_x * 1.35, dur * 1.15).as_relative()
	cam_shake_tween.tween_property(self, "position:x", kick_x * 0.45, dur * 0.9).as_relative()
	cam_shake_tween.tween_property(self, "global_position", orig_pos, 0.35)
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees", orig_rot, 0.35)

	await cam_shake_tween.finished


func shake_camera_impact() -> void:
	# Stronger shake — overrides any shake currently running because it
	# shares cam_shake_tween with the others below.
	if camera_stop_all_shaking:
		return

	camera_shaking = true

	if cam_shake_tween:
		cam_shake_tween.kill()

	# Snap to the known-good transform first, so if we interrupted another
	# shake mid-motion we don't start this one from a skewed offset.
	global_position = orig_pos
	rotation_degrees = orig_rot

	var _shake_amount := shake_amount * magnitude_of_camera_shake * 3.0
	var _pos_shake := shoot_shake_amount * 1.5
	var _dur := temp_dur

	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Punchy rotational + positional kick
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "position:z", _pos_shake, _dur).as_relative()

	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount * 1.6, _dur * 1.2).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount * 1.6, _dur * 1.2).as_relative()

	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount * 0.8, _dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount * 0.8, _dur).as_relative()

	# Absolute (not relative) settle back to the exact saved transform —
	# this is what guarantees no permanent tilt, even if this shake itself
	# gets interrupted by something else calling kill() on cam_shake_tween.
	cam_shake_tween.tween_property(self, "rotation_degrees", orig_rot, 0.6)
	cam_shake_tween.parallel().tween_property(self, "global_position", orig_pos, 0.6)

	await cam_shake_tween.finished
	camera_shaking = false


## Heavy multi-axis punch when a rock-avoider detonates on the crosshair.
func shake_camera_avoider_hit() -> void:
	if camera_stop_all_shaking:
		return

	camera_shaking = true
	if cam_shake_tween:
		cam_shake_tween.kill()

	global_position = orig_pos
	rotation_degrees = orig_rot

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

	cam_shake_tween.tween_property(self, "rotation_degrees", orig_rot, 0.75)
	cam_shake_tween.parallel().tween_property(self, "global_position", orig_pos, 0.75)

	await cam_shake_tween.finished
	camera_shaking = false


func shake_camera_sky_mines() -> void:
	var _shake_amount :float= clamp(1.1, -2.0, 2.0)
	var _dur : float = 0.1
	if cam_shake_tween:
		cam_shake_tween.kill()
	cam_shake_tween = create_tween().set_trans(Tween.TRANS_CUBIC) #.set_trans(Tween.TRANS_CUBIC)
	#for i in range(amount_of_shakes):
	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, _dur)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount, _dur)
	cam_shake_tween.tween_property(self, "rotation_degrees:x", 0.0, _dur + 0.1)
	await cam_shake_tween.finished

func shake_camera_shooting() -> void:
	
	
	if cam_shake_tween:
		cam_shake_tween.kill()

	# Prevent more than 2 recoil pushes from stacking
	var max_recoil := shoot_shake_amount * 2.0

	# Clamp the target position before tweening
	#var target_z : float = max(position.z + shoot_shake_amount, max_recoil)
	var target_z = min(position.z + shoot_shake_amount, max_recoil)
	cam_shake_tween = create_tween() #.set_trans(Tween.TRANS_CUBIC)

	cam_shake_tween.tween_property(self, "position:z", target_z, move_speed)
	cam_shake_tween.tween_property(self, "position:z", 0.0, move_speed * 1.5)
	cam_shake_tween.parallel().tween_property(self, "position:y", 0.0, move_speed * 1.5)

	await cam_shake_tween.finished
	#global_position = orig_pos
	
func pulse_shake_camera() -> void:
	var _orig_pos_y : float = self.global_position.y
	var tween_pulse_shake = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_pulse_shake.tween_interval(0.1)
	tween_pulse_shake.tween_property(self, "global_position:y", -0.2, move_speed).as_relative()
	tween_pulse_shake.tween_interval(0.1)
	tween_pulse_shake.tween_property(self, "global_position:y", _orig_pos_y, 1.0)
	await tween_pulse_shake.finished
	

func shake_camera_rock_destroyed() -> void:
	var _shake_amount := 0.5
	var _max_shake := _shake_amount * 2.0

	if cam_shake_tween:
		cam_shake_tween.kill()

	# Prevent the camera from drifting too far.
	rotation_degrees.x = clamp(rotation_degrees.x, -_max_shake, _max_shake)
	rotation_degrees.z = clamp(rotation_degrees.z, -_max_shake, _max_shake)

	cam_shake_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	cam_shake_tween.tween_property(self, "rotation_degrees:x", -_shake_amount, temp_dur).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount, temp_dur).as_relative()

	cam_shake_tween.tween_property(self, "rotation_degrees:x", _shake_amount, temp_dur * 1.5).as_relative()
	cam_shake_tween.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, temp_dur * 1.5).as_relative()

	cam_shake_tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 0.75)

	await cam_shake_tween.finished
	camera_shaking_bomb = false



func shake_camera_based_on_position(distance : float) -> void:
	pass
	
	
	
func little_camera_movement() -> void:
	
	if camera_stop_all_shaking: return

	var orig_fov = 70
	var _shake_amount = 0.25
	var little_camera_zoomy = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	little_camera_zoomy.tween_property(self, "fov", zoom_magnitude, zoom_tween_speed * 3).as_relative()
	little_camera_zoomy.tween_property(self, "fov", orig_fov, zoom_tween_speed * 5)
	little_camera_zoomy.parallel().tween_callback(camera_sounds)
	little_camera_zoomy.tween_property(self, "rotation_degrees:x", -_shake_amount, zoom_tween_speed).as_relative()
	little_camera_zoomy.parallel().tween_property(self, "rotation_degrees:z", -_shake_amount, zoom_tween_speed).as_relative()
	little_camera_zoomy.tween_property(self, "rotation_degrees:x", _shake_amount, zoom_tween_speed * 1.5).as_relative()
	little_camera_zoomy.parallel().tween_property(self, "rotation_degrees:z", _shake_amount, zoom_tween_speed * 1.5).as_relative()

	await little_camera_zoomy.finished


func camera_sounds() -> void:
	if camera_stop_all_shaking: return  # ✅ Added check
	CommonCode.play_sound_instance_pitch_adjusted(CAMERA_WAKING_UP, -10.0, 1.0)


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
