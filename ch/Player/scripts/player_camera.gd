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

func on_strike() -> void:
	pass

func _on_three_strikes() -> void:
	shake_camera_impact()


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
