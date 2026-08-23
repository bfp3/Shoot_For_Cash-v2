class_name Player extends Node3D

@onready var mobile_controller: Node = $MobileControl
var is_mobile := OS.has_feature("mobile")
var running_on_mobile := false

const sensitivity_step := 1.0
const min_mouse_sensitivity := 1.0
const max_mouse_sensitivity := 10.0

var keyboard_velocity := Vector2.ZERO

@export_group('Scope Shrink While Holding')
@onready var scope_shrink_sfx : AudioStreamPlayer = $SFX/ScopeShrink
@export var scope_shrink_sfx_min_pitch := 1.0
@export var scope_shrink_sfx_max_pitch := 50.0
const scope_shrink_duration := 0.1 #0.5          # total seconds to fully shrink, regardless of starting size
@export var scope_shrink_large_bonus := 0.2        # extra seconds tacked on for very large scopes
const scope_shrink_reference_circle := 60.0  # "normal" size; circles above this scale toward the bonus
@export var _current_shrink_duration := 0.15
const scope_min_target_circle := 30.0 #20.0
@export var scope_return_duration := 0.3
@export var scope_shrink_delay_dur := 0.4
## Max scope size while holding right-click, as a multiple of resting radius (1.0 = no grow).
const SCOPE_EXPAND_MAX_SCALE := 1.5 #1.85

@export_group('Scope Shot Modifiers')
## Applied to upgraded base travel time while shrinking. Lower = faster bullets (travel seconds).
@export var scope_shrink_bullet_speed_scale := 0.3
## Applied to upgraded base travel time while expanding. Higher = slower bullets.
@export var scope_expand_bullet_speed_scale := 0.3
## Applied to upgraded base fire-rate cooldown while shrinking. Lower = faster fire.
@export var scope_shrink_fire_rate_scale := 0.2
## Applied to upgraded base fire-rate cooldown while expanding. Higher = slower fire.
@export var scope_expand_fire_rate_scale := 0.2
## Resting upgrade values — restored when not holding shrink/expand.
var _base_bullet_speed := 0.3
var _base_gun_fire_rate := 0.1
## True shop/upgrade values before alternate-weapon scales.
var _upgrade_bullet_speed := 0.3
var _upgrade_gun_fire_rate := 0.35
## `difficulty-*` override. -1 = use upgrades.
var _difficulty_bullet_speed := -1.0

@export var can_right_click_shoot := false

@export_group("Accuracy Streak")
## Progress bar near the bottom: +1 per accurate shot, miss resets. At max, bar resets and you gain a 4th strike slot (then take a strike).
@export var accuracy_streak_enabled := false
@export var accuracy_streak_max := 10
@export var accuracy_streak_tween_time := 0.28

@export_group("Alternate Weapon (Shift+G)")
## Press Shift+G in-round to toggle this loadout on/off.
@export var alt_weapon_enabled := true
## Bullet scene used while the alt weapon is equipped. Edit Bullet_visual_alt.tscn for look.
@export var alt_bullet_scene: PackedScene
## Multiplies upgrade travel time. Lower = faster bullets.
@export var alt_bullet_speed_scale := 0.72
## Multiplies upgrade fire-rate cooldown. Lower = shoots again sooner.
@export var alt_fire_rate_scale := 0.72
@export var alt_crosshair_color := Color(0.12, 0.95, 0.82, 1.0)

var using_alt_weapon := false

## Current bullets loaded. Starts at power_max_ammo and is refilled via shop ammo packs.
var shot_count := 0
var max_ammo := 0
## Separate magazine used only while a level-editor test round is active.
var _level_editor_ammo_active := false
var _level_editor_ammo := 99
const LEVEL_EDITOR_AMMO_MAX := 99
## Debug chat `no-ammo` — shots do not consume bullets.
var debug_infinite_ammo := false

var game_lost := false

enum ScopeMode { NONE, SHRINK, EXPAND }
var _scope_mode := ScopeMode.NONE
var _scope_at_min := false
var _scope_at_max := false
var scope_base_scale := 1.0              # resting visual scale set by tween_scope()
@export var scope_base_target_circle := 60.0     # resting real hit-radius, captured on press
var scope_hold_time := 0.0
var _is_holding_shoot := false
var _shrink_return_tween : Tween

enum State {
	INACTIVE,
	ACTIVE,
	ROUND_FINISHED,
	IN_SHOP,
	PAUSE,
	RESETING,
	}
@export var current_state := State.INACTIVE

var player_cash : int
var current_round : int

@onready var gun_center: Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun
#@onready var gun_right : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun2
#@onready var gun_left : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun

@export var roundManager : RoundManager
@export var weapon_shooting : Node3D
@export var player_gun : Node3D

var current_gun_fire_rate_cooldown := 0.0
var _is_currently_shooting := false

#@onready var _mouse_sensitivity := 0.3
#@export var keyboard_crosshair_speed := 800.0

@export_group('Player Upgradeable Stats')
var power_target_circle := 0.0
var power_gun_fire_rate := 0.0
var power_bullet_speed = 0.0
var power_bullet_damage : int = 1
var power_bullet_delay := 0.5 #0.15

var rotation_speed := 0.8

var pan_speed: float = 8.0

@onready var crosshair: Control = %Crosshair
@onready var cam_pivot: Node3D = $Cam_pivot
@onready var camera_3d:= $Cam_pivot/Camera3D

var joystick_sensitivity := 500.0

## Fine aim via controller right stick / gyro (left stick / WASD stay at ~1300 px/s).
@export_group("Right Stick Crosshair")
## Pixels per second at full right-stick (or equivalent gyro) tilt.
@export var right_stick_crosshair_speed := 320.0
## Ignore stick / gyro noise below this magnitude (0–1 after normalizing).
@export_range(0.05, 0.5, 0.01) var right_stick_deadzone := 0.15
## Higher = lighter tilts move slower / more precise (1 = linear).
@export_range(1.0, 3.0, 0.05) var right_stick_response_curve := 1.6
## How quickly fine aim ramps up / settles (higher = snappier).
@export var right_stick_accel := 40.0
@export var right_stick_decel := 22.0
## If true, also scales with the in-game reticle sensitivity setting.
@export var right_stick_uses_sensitivity_setting := true

@export_subgroup("Gyro")
## Move the crosshair with controller gyroscope (DualSense / Switch-style pads).
## Requires Godot 4.7+ joypad motion APIs; safely disabled on 4.6.
@export var gyro_aim_enabled := true
## Angular speed (rad/s) treated as "full stick" — matches right-stick max speed.
@export_range(0.5, 8.0, 0.05) var gyro_full_tilt_rad_per_sec := 2.0
@export var gyro_invert_x := false
@export var gyro_invert_y := false
## Brief still-calibration when a gyro pad connects (set controller down / hold steady).
@export var gyro_auto_calibrate_on_connect := true
@export_range(0.25, 3.0, 0.05) var gyro_calibrate_seconds := 1.0

@export_group("Grid Aim")
## When false, keyboard / left stick / D-pad keep free aim. When true, they step between A1–C8 grid cells.
@export var grid_aim_enabled := false
## Screen pixels per second while sliding the crosshair between grid cells.
@export var grid_aim_move_speed := 1800.0
## Extra vertical lanes just outside columns 1 and 8 (same A/B/C heights) for the reticle.
@export var grid_aim_side_lanes := true

@export_group("Planted Crosshair")
## When true, fire-release plants a crosshair trap instead of shooting. Overlap = hit; expires after 7s. Max 5.
@export var plant_crosshair_on_fire := false

const light_colour := Color('FFFFFF')
const light_intensity := 2.0

## Crosshair Control is 40×40; gun aim uses global_position + this offset (center).
const CROSSHAIR_CENTER_OFFSET := Vector2(20.0, 20.0)
const GRID_AIM_ON_CELL_PX := 36.0
const GRID_AIM_REPEAT_INITIAL_SEC := 0.32
const GRID_AIM_REPEAT_RATE_SEC := 0.11
const GRID_AIM_STICK_DEADZONE := 0.55

var start_rotation : Vector3

var target_crosshair_position: Vector2 = Vector2(980, 540)
var crosshair_position := Vector2.ZERO
var crosshair_lag_speed := 11.0  # Higher = faster catch-up
var _right_stick_velocity := Vector2.ZERO
var _gyro_velocity := Vector2.ZERO
var _gyro_device := -1
var _gyro_calibrating := false

## Grid aim lock (rows A=1…C=3; columns 1…8, plus optional side lanes 0 / 9).
var _grid_aim_row := 2
var _grid_aim_column := 4
var _grid_aim_has_cell := false
var _grid_aim_moving := false
var _grid_aim_screen_target := Vector2.ZERO
var _grid_aim_hold_dir := Vector2.ZERO
var _grid_aim_repeat_timer := 0.0
var _grid_aim_stick_dir := Vector2i.ZERO
var _grid_aim_dpad_dir := Vector2i.ZERO
var _grid_rock_manager: RockManager

var crosshair_move_left_limit := 660
var crosshair_move_right_limit := 1260
const crosshair_move_top_limit := 400
const crosshair_move_bottom_limit := 700

var cam_clamp_top := 1
var cam_clamp_bottom := 1
var cam_clamp_left := 1
var cam_clamp_right := 1
const camera_pan_able := true

## Inner_scope is a 40x40 Control; at scale 1.0 its visual radius is 20px.
## power_target_circle is a screen-pixel hit radius (same units Radius_Debug draws).
func _inner_scope_scale_for_radius(radius: float) -> float:
	var base_radius = %Inner_scope.size.x * 0.5
	if base_radius <= 0.0:
		base_radius = 20.0
	return radius / base_radius


	
func _ready() -> void:
	if is_mobile:
		running_on_mobile = true
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	%HUD_bottom_corner.hide()
	
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	
	scope_shrink_sfx.finished.connect(_on_scope_shrink_sfx_finished)
	EventBus.instance.player_update_stats_visually.connect(update_player_stats)
	EventBus.instance.end_round_rock_missed.connect(stop_player)
	#EventBus.instance.pineapple_round_bought.connect(pineapples_start)
	var start_radius := gl_DataSet.get_value(
		'power_target_circle',
		gl_PlayerState.dataset.power_target_circle
	)
	tween_scope(_inner_scope_scale_for_radius(start_radius), 0.33)
	
	_init_ammo()
	update_player_stats()
	
	#%Bullet_icon.hide()

	EventBus.instance.egg_pulsed.connect(pulse_shake_camera)
	start_rotation = rotation_degrees
	_setup_mobile_pause_button()
	if not running_on_mobile:
		Input.joy_connection_changed.connect(_on_joy_connection_changed_for_gyro)
		_refresh_gyro_device(true)


func _setup_mobile_pause_button() -> void:
	var pause_btn := get_node_or_null("%PauseGameButtonMobile") as Button
	if pause_btn == null:
		return
	if running_on_mobile:
		pause_btn.show()
		if not pause_btn.pressed.is_connected(_on_mobile_pause_pressed):
			pause_btn.pressed.connect(_on_mobile_pause_pressed)
	else:
		pause_btn.hide()


func _on_mobile_pause_pressed() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_pause"):
		menus.ensure_pause()
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif pause_menu and pause_menu.has_method("start"):
		pause_menu.start()

func enter_state(new_state : State) -> void:
	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()

		State.ACTIVE:
			update_active()
			
		State.ROUND_FINISHED:
			update_round_finished()

		State.IN_SHOP:
			update_in_shop()

		State.PAUSE:
			update_pause()


func update_inactive() -> void:
	pass
	
func update_active() -> void:
	_sync_accuracy_bar_visibility()
	
	
func update_round_finished() -> void:
	if _accuracy_bar:
		_accuracy_bar.hide()

	weapon_shooting.time_ran_out = true
	
	reset_pos()
	reset_mouse_pos()
	%Mouse_turning_SFX.mute()
	#await get_tree().create_timer(1.0).timeout
	#tween_scope(1.0, 1.0)
	#await get_tree().create_timer(1.0).timeout
	
	weapon_shooting.time_ran_out = false
	
func update_in_shop() -> void:
	if _accuracy_bar:
		_accuracy_bar.hide()
	
func update_pause() -> void:
	pass


func reset_pos() -> void:
	var target_rot : Vector3 = start_rotation
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, 'rotation_degrees', target_rot, 1.0)
	await tween.finished
	enter_state(State.INACTIVE)
	
func handle_pan_up_and_down(delta) -> void:
	
	if !camera_pan_able:
		return
	
	var viewport_size = get_viewport().size
	var screen_height = viewport_size.y
	var crosshair_y = crosshair.position.y
	
	crosshair.position.y = clamp(crosshair.position.y, 0, screen_height - crosshair.size.y)
	
	if crosshair_y <= crosshair_move_top_limit:
		cam_pivot.rotation_degrees.x += pan_speed * delta  # Apply a small pan to the left
		cam_pivot.rotation_degrees.x = clamp(cam_pivot.rotation_degrees.x, -cam_clamp_top, cam_clamp_top)
		
	elif crosshair_y >= crosshair_move_bottom_limit:
		cam_pivot.rotation_degrees.x -= pan_speed * delta  # Apply a small pan to the left
		cam_pivot.rotation_degrees.x = clamp(cam_pivot.rotation_degrees.x, -cam_clamp_top, cam_clamp_top)


func handle_pan_left_and_right(delta) -> void:
	if !camera_pan_able:
		return
	
	var viewport_size = get_viewport().size
	var screen_width = viewport_size.x
	var crosshair_x = crosshair.position.x
	
	crosshair.position.x = clamp(crosshair.position.x, 0, screen_width - crosshair.size.x)
	
	if crosshair_x <= crosshair_move_left_limit:
		cam_pivot.rotation_degrees.y += pan_speed * delta  # Apply a small pan to the left
		cam_pivot.rotation_degrees.y = clamp(cam_pivot.rotation_degrees.y, -cam_clamp_left, cam_clamp_left)
		
	elif crosshair_x >= crosshair_move_right_limit:
		cam_pivot.rotation_degrees.y -= pan_speed * delta  # Apply a small pan to the left
		cam_pivot.rotation_degrees.y = clamp(cam_pivot.rotation_degrees.y, -cam_clamp_right, cam_clamp_right)
		

func _process(delta: float) -> void:
	
	if (OS.has_feature("editor") or OS.is_debug_build()) and not game_lost:
	#if not game_lost:
		if Input.is_action_pressed("middle_mouse"):
			Engine.time_scale = 10.0
		if Input.is_action_just_released("middle_mouse"):
			var restore := 1.0
			var chat := get_tree().get_first_node_in_group("debug_tool_chatbox")
			if chat != null and "base_time_scale" in chat:
				restore = float(chat.base_time_scale)
			Engine.time_scale = restore
	
	if current_state == State.IN_SHOP:
		return 
		
	
	if _is_currently_shooting:

		if current_gun_fire_rate_cooldown > 0.0:
			current_gun_fire_rate_cooldown -= delta
			current_gun_fire_rate_cooldown = max(current_gun_fire_rate_cooldown, 0.0)

		%Cooldown_progressBar3.value = (1.0 - (current_gun_fire_rate_cooldown / power_gun_fire_rate)) * 100.0
		%Bullet_icon.value = (1.0 - (current_gun_fire_rate_cooldown / power_gun_fire_rate)) * 100.0
		
		if %Cooldown_progressBar3.value >= 100.0 && !$SFX/Reload.playing:
			$SFX/Reload.play()
			#$CanvasLayer/Crosshair/RedDot.show()

	if current_state == State.ROUND_FINISHED:
		crosshair.position = target_crosshair_position #This controls the movement of crosshair 2D
		update_gun_look() 
		return
	
	if current_state == State.INACTIVE || current_state == State.IN_SHOP:
		return
	
	var viewport_size := get_viewport().get_visible_rect().size
	var half_crosshair := (crosshair.size * crosshair.scale) * 0.5	
	
	target_crosshair_position.x = clamp(
		target_crosshair_position.x,
		half_crosshair.x,
		viewport_size.x - half_crosshair.x
	)

	target_crosshair_position.y = clamp(
		target_crosshair_position.y,
		half_crosshair.y,
		viewport_size.y - half_crosshair.y
	)
	
	if running_on_mobile:
		target_crosshair_position += mobile_controller.get_crosshair_motion()

	# Keyboard / left stick / D-pad before reticle push so grid slides apply this frame.
	handle_keyboard_and_controller_input(delta)

	crosshair.position = target_crosshair_position
	if grid_aim_enabled and _grid_aim_moving:
		crosshair_position = target_crosshair_position
	else:
		crosshair_position = crosshair_position.lerp(target_crosshair_position, (crosshair_lag_speed / 10) - pow(0.001, delta))
	%Crosshair.global_position = crosshair_position

	# Desktop: InputMap shoot / scope. Mobile: left-half touch only (ignore emulated mouse).
	if running_on_mobile:
		if mobile_controller.consume_fire_release():
			fire_weapon()
	else:
		if Input.is_action_just_pressed("switch_weapon"):
			toggle_alt_weapon()
		if Input.is_action_just_released("shootWeapon"):
			fire_weapon()

		if Input.is_action_just_released("shoot_weapon_2"):
			fire_weapon()

	handle_scope_adjust(delta)
	
	#if Input.is_action_pressed("shootWeapon"):
		#return
	
	
	#handle_pan_up_and_down(delta)
	#handle_pan_left_and_right(delta)
	handle_right_stick_crosshair(delta)
	handle_gyro_crosshair(delta)
	update_gun_look()
	
	#handle_pan_keyboard(delta)
	
func update_gun_look() -> void:

	var screen_pos = crosshair.global_position + CROSSHAIR_CENTER_OFFSET

	# Ray from camera through crosshair
	var ray_origin = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)

	# Far point in world
	var target_pos = ray_origin + ray_dir  * 100.0

	# Optional raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		target_pos
	)

	var result = space_state.intersect_ray(query)

	# If we hit something, use hit point
	if result:
		target_pos = result.position

	# Rotate gun toward target
	#player_gun.look_at(target_pos, Vector3.UP, true)
	#$Cam_pivot/Camera3D/Player_gun/mockGun2.look_at(target_pos, Vector3.UP, true)
	#$Cam_pivot/Camera3D/Player_gun/mockGun3.look_at(target_pos, Vector3.UP, true)
	
	
	# Aim whichever mesh is currently equipped (default or alt).
	var active_gun: Node3D = null
	if player_gun and player_gun.has_method("get_active_gun"):
		active_gun = player_gun.get_active_gun()
	if active_gun == null:
		active_gun = $Cam_pivot/Camera3D/Player_gun/mockGun
	active_gun.look_at(target_pos, Vector3.UP, true)
	return
	#if gl_PlayerState.dataset.power_gun == 1:
#
		#smooth_look_at(gun_center, target_pos)
#
		#gun_center.rotation_degrees.x = clamp(gun_center.rotation_degrees.x, 1.0, 5.0)
		#gun_center.rotation_degrees.y = clamp(gun_center.rotation_degrees.y, -30.0, 30.0)
#
	#else:
#
		#smooth_look_at(gun_right, target_pos)
		#smooth_look_at(gun_left, target_pos)
#
		#gun_right.rotation_degrees.x = clamp(gun_right.rotation_degrees.x, -1.0, 10.0)
		#gun_left.rotation_degrees.x = clamp(gun_left.rotation_degrees.x, -1.0, 10.0)
#
		#gun_right.rotation_degrees.y = clamp(gun_right.rotation_degrees.y, -30.0, -10.0)
		#gun_left.rotation_degrees.y = clamp(gun_left.rotation_degrees.y, 10.0, 30.0)

func smooth_look_at(node: Node3D, target_pos: Vector3, speed := 10.0):
	var target_transform = node.global_transform.looking_at(target_pos, Vector3.UP, true)
	node.global_basis = node.global_basis.slerp(target_transform.basis, speed * get_process_delta_time())

	
func handle_pan_keyboard(delta : float) -> void:
	var left := Input.get_action_strength("left")
	var right := Input.get_action_strength("right")
	var up := Input.get_action_strength("forward")
	var down := Input.get_action_strength("backward")
	
	if left:
		rotation.y += delta * rotation_speed
		
	if right:
		rotation.y += delta * -rotation_speed
		
	if up:
		rotation.x += delta * rotation_speed
		
	if down:
		rotation.x += delta * -rotation_speed
	
func handle_dpad_movement(delta: float) -> void:
	var move_vector := Vector3.ZERO

	# These are the default axis values for most gamepads
	var left := Input.get_action_strength("ui_left")
	var right := Input.get_action_strength("ui_right")
	var up := Input.get_action_strength("ui_up")
	var down := Input.get_action_strength("ui_down")

	move_vector.x = right - left
	move_vector.z = down - up

	# Normalize to avoid faster diagonal movement
	if move_vector.length() > 0:
		move_vector = move_vector.normalized()

	# Apply movement (adjust based on your setup)
	var move_speed := 5.0
	var direction := (transform.basis * move_vector).normalized()
	global_translate(direction * move_speed * delta)


func handle_joystick(delta : float) -> void:

	var axis_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var axis_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	var input_vector := Vector2(axis_x, axis_y)

	# Deadzone filter to prevent drift
	if input_vector.length() < 0.1:
		return

	# Normalize direction, scale by magnitude for strength
	var direction := input_vector.normalized()
	var strength := input_vector.length()

	# Apply nonlinear scaling for better precision
	strength = pow(strength, 1.5)  # Makes small inputs more precise, big inputs still fast

	var joystick_motion := direction * strength * joystick_sensitivity * GameSettings.crosshair_speed_multiplier() * delta
	target_crosshair_position += joystick_motion

func handle_keyboard_and_controller_input(delta: float) -> void:
	if grid_aim_enabled:
		_handle_grid_aim_input(delta)
		return

	# Raw stick axes keep full 360° aim. InputMap deadzones on left/right/forward/backward
	# snap diagonals to cardinals, so only use those for keyboard.
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	const STICK_DEADZONE := 0.12
	var raw: Vector2
	if stick.length() > STICK_DEADZONE:
		raw = stick
	else:
		raw = Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("forward", "backward")
		)
	# Stick tilt scales speed (partial push = slower). Keys read as ±1 so stay full speed.
	var magnitude := clampf(raw.length(), 0.0, 1.0)
	var has_input := magnitude > STICK_DEADZONE

	const keyboard_crosshair_speed := 1300.0
	var speed := keyboard_crosshair_speed * GameSettings.crosshair_speed_multiplier()
	if Input.is_action_pressed("sprint"):
		speed *= 0.5

	var target_velocity := Vector2.ZERO
	if has_input:
		# Mild curve: light tilts stay precise, full throw still hits max speed.
		var strength := pow(magnitude, 1.35)
		target_velocity = raw.normalized() * speed * strength

	const ACCEL := 60.0
	const DECEL := 18.0
	var lerp_speed := ACCEL if has_input else DECEL
	keyboard_velocity = keyboard_velocity.lerp(target_velocity, lerp_speed * delta)

	if keyboard_velocity.length_squared() < 0.01 and not has_input:
		keyboard_velocity = Vector2.ZERO
		return

	target_crosshair_position += keyboard_velocity * delta


## Discrete A1–C8 aim: WASD / left stick / D-pad step cells; crosshair eases between them.
func _handle_grid_aim_input(delta: float) -> void:
	keyboard_velocity = Vector2.ZERO

	var step_dir := _poll_grid_aim_step_dir(delta)
	if step_dir != Vector2.ZERO:
		_grid_aim_apply_step(step_dir)

	if not _grid_aim_moving:
		return

	_refresh_grid_aim_screen_target()
	var speed := maxf(grid_aim_move_speed, 1.0)
	target_crosshair_position = target_crosshair_position.move_toward(
		_grid_aim_screen_target, speed * delta
	)
	# Keep visual lag from fighting the intentional slide.
	crosshair_position = crosshair_position.move_toward(_grid_aim_screen_target, speed * delta)
	if target_crosshair_position.distance_to(_grid_aim_screen_target) <= 0.75:
		target_crosshair_position = _grid_aim_screen_target
		crosshair_position = _grid_aim_screen_target
		_grid_aim_moving = false


func _poll_grid_aim_step_dir(delta: float) -> Vector2:
	var pressed := _grid_aim_held_screen_dir()

	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	var stick_active := stick.length() >= GRID_AIM_STICK_DEADZONE

	# Fresh press — skip action just_pressed while the stick is tilted so we don't
	# double-fire (InputMap deadzone edge + our stick edge).
	var edge := Vector2.ZERO
	if not stick_active:
		if Input.is_action_just_pressed("right") or Input.is_action_just_pressed("ui_right"):
			edge.x += 1.0
		if Input.is_action_just_pressed("left") or Input.is_action_just_pressed("ui_left"):
			edge.x -= 1.0
		if Input.is_action_just_pressed("backward") or Input.is_action_just_pressed("ui_down"):
			edge.y += 1.0
		if Input.is_action_just_pressed("forward") or Input.is_action_just_pressed("ui_up"):
			edge.y -= 1.0

	var stick_dir := Vector2i.ZERO
	if stick_active:
		if absf(stick.x) >= absf(stick.y):
			stick_dir.x = 1 if stick.x > 0.0 else -1
		else:
			stick_dir.y = 1 if stick.y > 0.0 else -1
	if stick_dir != _grid_aim_stick_dir:
		_grid_aim_stick_dir = stick_dir
		if stick_dir != Vector2i.ZERO:
			edge = Vector2(stick_dir)

	var dpad := _grid_aim_dpad_vector()
	if dpad != _grid_aim_dpad_dir:
		_grid_aim_dpad_dir = dpad
		if dpad != Vector2i.ZERO:
			edge = Vector2(dpad)

	if edge != Vector2.ZERO:
		_grid_aim_hold_dir = _cardinalize_screen_dir(edge)
		_grid_aim_repeat_timer = GRID_AIM_REPEAT_INITIAL_SEC
		return _grid_aim_hold_dir

	# Hold-to-repeat while a direction stays held.
	if pressed == Vector2.ZERO:
		_grid_aim_hold_dir = Vector2.ZERO
		_grid_aim_repeat_timer = 0.0
		return Vector2.ZERO

	var hold := _cardinalize_screen_dir(pressed)
	if hold != _grid_aim_hold_dir:
		_grid_aim_hold_dir = hold
		_grid_aim_repeat_timer = GRID_AIM_REPEAT_INITIAL_SEC
		return hold

	_grid_aim_repeat_timer -= delta
	if _grid_aim_repeat_timer <= 0.0:
		_grid_aim_repeat_timer = GRID_AIM_REPEAT_RATE_SEC
		return hold
	return Vector2.ZERO


func _grid_aim_held_screen_dir() -> Vector2:
	var dir := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("forward", "backward")
	)
	# Arrow keys / default UI actions (often where D-pad lands).
	dir.x += Input.get_axis("ui_left", "ui_right")
	dir.y += Input.get_axis("ui_up", "ui_down")
	var dpad := _grid_aim_dpad_vector()
	dir += Vector2(dpad)
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if stick.length() >= GRID_AIM_STICK_DEADZONE:
		dir = stick
	return dir


func _grid_aim_dpad_vector() -> Vector2i:
	var x := 0
	var y := 0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		x += 1
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		x -= 1
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		y += 1
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		y -= 1
	if x != 0 and y != 0:
		# Prefer the stronger axis when both are somehow held.
		if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) >= absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)):
			y = 0
		else:
			x = 0
	return Vector2i(x, y)


func _cardinalize_screen_dir(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2.ZERO
	if absf(dir.x) >= absf(dir.y):
		return Vector2(signf(dir.x), 0.0)
	return Vector2(0.0, signf(dir.y))


func _grid_aim_apply_step(screen_dir: Vector2) -> void:
	var rocks := _get_rock_manager()
	if rocks == null:
		return

	var dest := _resolve_grid_aim_destination(rocks, screen_dir)
	_grid_aim_row = dest.x
	_grid_aim_column = dest.y
	_grid_aim_has_cell = true
	_grid_aim_moving = true
	_refresh_grid_aim_screen_target()


func _resolve_grid_aim_destination(rocks: RockManager, screen_dir: Vector2) -> Vector2i:
	var aim := _aim_screen_center()
	var dir := _cardinalize_screen_dir(screen_dir)
	if dir == Vector2.ZERO:
		return _nearest_grid_cell(rocks, aim)

	# Prefer the locked cell while sliding / sitting on it; otherwise the nearest to the reticle.
	var from := _nearest_grid_cell(rocks, aim)
	if _grid_aim_has_cell:
		var locked_screen := _grid_cell_aim_screen(rocks, _grid_aim_row, _grid_aim_column)
		if _grid_aim_moving or aim.distance_to(locked_screen) <= GRID_AIM_ON_CELL_PX:
			from = Vector2i(_grid_aim_row, _grid_aim_column)

	# From that cell, apply the input (right → B4 becomes B5).
	return _grid_step_from_cell(rocks, from.x, from.y, dir)


## Index step: right → +column (B4→B5), left → −column, up → toward A, down → toward C.
## With side lanes: column 0 sits outside 1, column 9 outside 8.
func _grid_step_from_cell(
	rocks: RockManager, row: int, column: int, screen_dir: Vector2
) -> Vector2i:
	var next_row := row
	var next_col := column
	if screen_dir.x > 0.0:
		next_col += 1
	elif screen_dir.x < 0.0:
		next_col -= 1
	elif screen_dir.y > 0.0:
		next_row += 1
	elif screen_dir.y < 0.0:
		next_row -= 1

	next_row = clampi(next_row, 1, rocks.aim_grid_row_count())
	var bounds := _grid_aim_column_bounds(rocks)
	next_col = clampi(next_col, bounds.x, bounds.y)
	return Vector2i(next_row, next_col)


func _grid_aim_column_bounds(rocks: RockManager) -> Vector2i:
	if rocks.has_method("aim_grid_column_bounds"):
		return rocks.aim_grid_column_bounds(grid_aim_side_lanes)
	if grid_aim_side_lanes:
		return Vector2i(0, rocks.aim_grid_column_count() + 1)
	return Vector2i(1, rocks.aim_grid_column_count())


func _nearest_grid_cell(rocks: RockManager, from_screen: Vector2) -> Vector2i:
	var best := Vector2i(2, 4)
	var best_dist := INF
	var row_count := rocks.aim_grid_row_count()
	var bounds := _grid_aim_column_bounds(rocks)

	for row in range(1, row_count + 1):
		for col in range(bounds.x, bounds.y + 1):
			var dist := from_screen.distance_to(_grid_cell_aim_screen(rocks, row, col))
			if dist < best_dist:
				best_dist = dist
				best = Vector2i(row, col)
	return best


func _aim_screen_center() -> Vector2:
	# Prefer the visible reticle; fall back to the logical target.
	if crosshair != null:
		return crosshair.global_position + CROSSHAIR_CENTER_OFFSET
	return target_crosshair_position + CROSSHAIR_CENTER_OFFSET


func _grid_cell_aim_screen(rocks: RockManager, row: int, column: int) -> Vector2:
	var world := rocks.aim_cell_world_position(row, column)
	return camera_3d.unproject_position(world)


func _refresh_grid_aim_screen_target() -> void:
	var rocks := _get_rock_manager()
	if rocks == null or not _grid_aim_has_cell:
		return
	_grid_aim_screen_target = (
		_grid_cell_aim_screen(rocks, _grid_aim_row, _grid_aim_column) - CROSSHAIR_CENTER_OFFSET
	)


func _clear_grid_aim_lock() -> void:
	_grid_aim_has_cell = false
	_grid_aim_moving = false
	_grid_aim_hold_dir = Vector2.ZERO
	_grid_aim_repeat_timer = 0.0


func _get_rock_manager() -> RockManager:
	if _grid_rock_manager != null and is_instance_valid(_grid_rock_manager):
		return _grid_rock_manager

	var rm = roundManager
	if rm == null:
		rm = get_tree().get_first_node_in_group("round_manager")
	if rm != null:
		var rocks = rm.get("rocks_container")
		if rocks is RockManager:
			_grid_rock_manager = rocks
			return _grid_rock_manager

	var scene := get_tree().current_scene
	if scene != null:
		var node := scene.get_node_or_null("Rocks")
		if node is RockManager:
			_grid_rock_manager = node
			return _grid_rock_manager

	return null


## Slow precision aim from the right stick (stacks with gyro / left stick / WASD / mouse).
func handle_right_stick_crosshair(delta: float) -> void:
	if running_on_mobile:
		return

	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	_right_stick_velocity = _fine_aim_integrate(stick, _right_stick_velocity, delta)
	if grid_aim_enabled and _right_stick_velocity.length_squared() > 0.01:
		_clear_grid_aim_lock()
	target_crosshair_position += _right_stick_velocity * delta


## Controller gyro aim — same speed / curve / deadzone as the right stick.
## Native joypad gyro APIs ship in Godot 4.7+; on 4.6 this no-ops safely.
func handle_gyro_crosshair(delta: float) -> void:
	if running_on_mobile or not gyro_aim_enabled:
		_gyro_velocity = Vector2.ZERO
		return
	if not _joy_motion_api_available():
		_gyro_velocity = Vector2.ZERO
		return
	if _gyro_device < 0 or _gyro_calibrating:
		_gyro_velocity = Vector2.ZERO
		return
	if not bool(Input.call("is_joy_motion_sensors_calibrated", _gyro_device)):
		_gyro_velocity = Vector2.ZERO
		return

	var stick := _gyro_as_stick(_gyro_device)
	_gyro_velocity = _fine_aim_integrate(stick, _gyro_velocity, delta)
	if grid_aim_enabled and _gyro_velocity.length_squared() > 0.01:
		_clear_grid_aim_lock()
	target_crosshair_position += _gyro_velocity * delta


## Shared right-stick / gyro velocity integration (same speeds for both).
func _fine_aim_integrate(stick: Vector2, current: Vector2, delta: float) -> Vector2:
	var magnitude := clampf(stick.length(), 0.0, 1.0)
	var has_input := magnitude > right_stick_deadzone

	var speed := right_stick_crosshair_speed
	if right_stick_uses_sensitivity_setting:
		speed *= GameSettings.crosshair_speed_multiplier()

	var target_velocity := Vector2.ZERO
	if has_input:
		var strength := pow(magnitude, right_stick_response_curve)
		target_velocity = stick.normalized() * speed * strength

	var lerp_speed := right_stick_accel if has_input else right_stick_decel
	current = current.lerp(target_velocity, lerp_speed * delta)
	if current.length_squared() < 0.01 and not has_input:
		return Vector2.ZERO
	return current


## Map joypad gyro (rad/s) into the same -1..1 stick space the right stick uses.
func _gyro_as_stick(device: int) -> Vector2:
	var gyro: Vector3 = Input.call("get_joy_gyroscope", device)
	var full := maxf(gyro_full_tilt_rad_per_sec, 0.01)
	# Yaw → screen X, pitch → screen Y (Godot: +gyro is counter-clockwise).
	var stick := Vector2(-gyro.y, -gyro.x) / full
	if gyro_invert_x:
		stick.x = -stick.x
	if gyro_invert_y:
		stick.y = -stick.y
	return stick.limit_length(1.0)


func _joy_motion_api_available() -> bool:
	return (
		Input.has_method("has_joy_motion_sensors")
		and Input.has_method("set_joy_motion_sensors_enabled")
		and Input.has_method("get_joy_gyroscope")
		and Input.has_method("is_joy_motion_sensors_calibrated")
		and Input.has_method("start_joy_motion_sensors_calibration")
		and Input.has_method("stop_joy_motion_sensors_calibration")
	)


func _on_joy_connection_changed_for_gyro(_device: int, _connected: bool) -> void:
	_refresh_gyro_device(true)


func _refresh_gyro_device(calibrate_if_needed: bool) -> void:
	if running_on_mobile or not gyro_aim_enabled or not _joy_motion_api_available():
		_gyro_device = -1
		_gyro_velocity = Vector2.ZERO
		return

	var found := -1
	for device in Input.get_connected_joypads():
		if bool(Input.call("has_joy_motion_sensors", device)):
			found = int(device)
			break
	_gyro_device = found
	if _gyro_device < 0:
		return

	Input.call("set_joy_motion_sensors_enabled", _gyro_device, true)
	if calibrate_if_needed and gyro_auto_calibrate_on_connect:
		if not bool(Input.call("is_joy_motion_sensors_calibrated", _gyro_device)):
			_calibrate_gyro_device(_gyro_device)


func _calibrate_gyro_device(device: int) -> void:
	if _gyro_calibrating or not _joy_motion_api_available():
		return
	_gyro_calibrating = true
	Input.call("start_joy_motion_sensors_calibration", device)
	await get_tree().create_timer(gyro_calibrate_seconds).timeout
	if is_instance_valid(self) and device == _gyro_device and _joy_motion_api_available():
		Input.call("stop_joy_motion_sensors_calibration", device)
	_gyro_calibrating = false


func set_power(settings:Dictionary, setting_name:String)-> float:
	return gl_DataSet.get_value(setting_name, settings[setting_name])

func update_player_stats() -> void:
	var settings : Dictionary = gl_PlayerState.get_all()
	
	
	power_target_circle = set_power(settings, 'power_target_circle')
	power_bullet_speed = set_power(settings, 'power_bullet_speed')
	power_bullet_damage = int(set_power(settings, 'power_bullet_damage'))
	power_bullet_delay = set_power(settings, 'power_bullet_delay')
	power_gun_fire_rate = set_power(settings, 'power_gun_fire_rate')

	# Remember upgrade defaults so scope hold can temporarily override, then restore.
	_upgrade_bullet_speed = power_bullet_speed
	_upgrade_gun_fire_rate = power_gun_fire_rate
	if _difficulty_bullet_speed > 0.0:
		_upgrade_bullet_speed = _difficulty_bullet_speed
	_rebuild_weapon_bases_from_upgrades()

	#power_gun_fire_rate = 0.05
	#power_bullet_speed = 0.01

	
	if player_gun and player_gun.has_method("set_weapon_slot"):
		player_gun.set_weapon_slot(using_alt_weapon)
	else:
		player_gun.update_guns()

	#full_power_mode()
	
	player_cash 		= settings.cash
	current_round 		= settings.round
	
	_sync_weapon_bullet_scene()
	weapon_shooting.apply_upgrades()
	_refresh_crosshair_weapon_style()
	update_stats_visually()


func toggle_alt_weapon() -> void:
	if not alt_weapon_enabled:
		return
	if current_state != State.ACTIVE and current_state != State.ROUND_FINISHED:
		return
	using_alt_weapon = not using_alt_weapon
	if player_gun and player_gun.has_method("set_weapon_slot"):
		player_gun.set_weapon_slot(using_alt_weapon)
	_rebuild_weapon_bases_from_upgrades()
	_sync_weapon_bullet_scene()
	if weapon_shooting:
		weapon_shooting.power_bullet_speed = power_bullet_speed
	_refresh_crosshair_weapon_style()


func _rebuild_weapon_bases_from_upgrades() -> void:
	var speed := _upgrade_bullet_speed
	var rate := _upgrade_gun_fire_rate
	if using_alt_weapon:
		speed *= alt_bullet_speed_scale
		rate *= alt_fire_rate_scale
	_base_bullet_speed = speed
	_base_gun_fire_rate = rate
	power_bullet_speed = speed
	power_gun_fire_rate = rate
	_apply_scope_shot_stats(speed, rate)


func set_difficulty_bullet_speed(value: float) -> void:
	_difficulty_bullet_speed = value
	_upgrade_bullet_speed = value
	_rebuild_weapon_bases_from_upgrades()


func clear_difficulty_bullet_speed() -> void:
	if _difficulty_bullet_speed < 0.0:
		return
	_difficulty_bullet_speed = -1.0
	update_player_stats()


func _sync_weapon_bullet_scene() -> void:
	if weapon_shooting == null:
		return
	if using_alt_weapon and alt_bullet_scene:
		weapon_shooting.set_active_bullet_scene(alt_bullet_scene)
	else:
		weapon_shooting.set_active_bullet_scene(null)


func _refresh_crosshair_weapon_style() -> void:
	if crosshair and crosshair.has_method("apply_weapon_style"):
		crosshair.apply_weapon_style(using_alt_weapon, alt_crosshair_color)


func full_power_mode() -> void:
	power_target_circle = gl_DataSet.get_value('power_target_circle', 9)
	power_bullet_speed = gl_DataSet.get_value('power_bullet_speed', 9)
	power_bullet_damage = int(gl_DataSet.get_value('power_bullet_damage', 9))
	power_bullet_delay =  gl_DataSet.get_value('power_bullet_delay', 9)
	power_gun_fire_rate = gl_DataSet.get_value('power_gun_fire_rate', 9)

func update_stats_visually() -> void:
	await get_tree().create_timer(0.5, false).timeout
	
	#if gl_PlayerState.dataset.power_bullet_damage >= 1:
		#$CanvasLayer/Crosshair/Inner_scope/Inner_scope3.show()
		#
	#if gl_PlayerState.dataset.power_bullet_damage >= 3:
		#$CanvasLayer/Crosshair/Inner_scope/Inner_scope4.show()
		#
	#if gl_PlayerState.dataset.power_bullet_damage >= 5:
		#$CanvasLayer/Crosshair/Inner_scope/Inner_scope4.modulate = Color('ff7700')
	
	#if gl_PlayerState.dataset.power_bullet_damage > 2:
		#pass
	#await get_tree().create_timer(1.5).timeout
	
	
	var scale_multiplier := _inner_scope_scale_for_radius(power_target_circle)

	tween_scope(scale_multiplier, 0.33)

func display_hud() -> void:
	%HUD_bottom_corner.show()
	#$CanvasLayer/HUD_bottom_corner/TotalRocks._update_for_new_round()
	
	
func hide_hud() -> void:
	%HUD_bottom_corner.hide()

func apply_sky_mine() -> void:
	$CanvasLayer/HUD_bottom_corner/SkyMine.start()
	await get_tree().create_timer(0.5, false).timeout
	$CanvasLayer/HUD_bottom_corner/SkyMine.start()
	%Cooldown_progressBar3.self_modulate = Color('d10000')
	$CanvasLayer/Crosshair/Inner_scope/center_container.modulate = Color('d10000')
	
	
func remove_sky_mine() -> void:
	#await get_tree().create_timer(0.25).timeout
	$CanvasLayer/HUD_bottom_corner/SkyMine.stop()
	%Cooldown_progressBar3.self_modulate = Color('FFFFFF')
	$CanvasLayer/Crosshair/Inner_scope/center_container.modulate = Color('FFFFFF')



func tween_scope(_scale_multiplier : float, _dur : float = 0.75) -> void:
	scope_base_scale = _scale_multiplier
	var increase_scope_tween : Tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	increase_scope_tween.tween_property(%Inner_scope, "scale", Vector2.ONE * _scale_multiplier, _dur)

func _on_scope_shrink_sfx_finished() -> void:
	if _scope_at_min or _scope_at_max:
		return
		
	if _is_holding_shoot and scope_hold_time >= scope_shrink_delay_dur:
		scope_shrink_sfx.play()
		
		
func handle_scope_adjust(delta: float) -> void:
	var shrink_held := false
	var expand_held := false

	if running_on_mobile:
		shrink_held = mobile_controller.is_fire_held()
	else:
		expand_held = Input.is_action_pressed("shootWeapon")
		shrink_held = Input.is_action_pressed("shoot_weapon_2")

	# Start from upgraded resting values (normal tap-fire).
	var bullet_speed := _base_bullet_speed
	var fire_rate := _base_gun_fire_rate

	if shrink_held and _scope_mode != ScopeMode.EXPAND:
		_update_scope_hold(ScopeMode.SHRINK, delta)
		# Smaller scope = faster fire + faster bullets (lower travel time).
		bullet_speed = _base_bullet_speed * scope_shrink_bullet_speed_scale
		fire_rate = _base_gun_fire_rate * scope_shrink_fire_rate_scale

	elif expand_held and _scope_mode != ScopeMode.SHRINK:
		_update_scope_hold(ScopeMode.EXPAND, delta)
		# Larger scope = slower fire + slower bullets (higher travel time).
		bullet_speed = _base_bullet_speed * scope_expand_bullet_speed_scale
		fire_rate = _base_gun_fire_rate * scope_expand_fire_rate_scale

	elif _is_holding_shoot:
		_release_scope_hold()

	_apply_scope_shot_stats(bullet_speed, fire_rate)


## Keep Player + Weapon_shooting in sync. Bullets read weapon_shooting.power_bullet_speed.
func _apply_scope_shot_stats(bullet_speed: float, fire_rate: float) -> void:
	power_bullet_speed = bullet_speed
	#bullet_speed = [0.1,0.25,0.3].pick_random()
	bullet_speed = 0.05
	power_gun_fire_rate = fire_rate
	if weapon_shooting:
		weapon_shooting.power_bullet_speed = bullet_speed


## Live reticle hit radius in screen pixels (shrink/expand updates Weapon_shooting).
func get_current_crosshair_hit_radius() -> float:
	if weapon_shooting and weapon_shooting.power_target_circle > 0.0:
		return weapon_shooting.power_target_circle
	if power_target_circle > 0.0:
		return power_target_circle
	return scope_base_target_circle if scope_base_target_circle > 0.0 else 40.0


func _update_scope_hold(mode: ScopeMode, delta: float) -> void:
	if not _is_holding_shoot or _scope_mode != mode:
		_is_holding_shoot = true
		_scope_mode = mode
		scope_hold_time = 0.0
		scope_base_target_circle = power_target_circle
		_scope_at_min = false
		_scope_at_max = false
		if _shrink_return_tween:
			_shrink_return_tween.kill()

		var size_ratio : float = clamp(
			(scope_base_target_circle - scope_shrink_reference_circle) / scope_shrink_reference_circle,
			0.0, 1.0
		)
		_current_shrink_duration = scope_shrink_duration + (size_ratio * scope_shrink_large_bonus)

	scope_hold_time += delta

	if scope_hold_time < scope_shrink_delay_dur:
		return

	if (mode == ScopeMode.SHRINK and _scope_at_min) or (mode == ScopeMode.EXPAND and _scope_at_max):
		return

	if not scope_shrink_sfx.playing and scope_hold_time < (scope_shrink_delay_dur + 0.2):
		scope_shrink_sfx.play()

	var t : float = clamp(
		(scope_hold_time - scope_shrink_delay_dur) / maxf(_current_shrink_duration, 0.001),
		0.0,
		1.0
	)
	var goal_circle := scope_min_target_circle
	if mode == ScopeMode.EXPAND:
		goal_circle = scope_base_target_circle * SCOPE_EXPAND_MAX_SCALE

	var new_target_circle : float = lerp(scope_base_target_circle, goal_circle, t)
	var scale_ratio := new_target_circle / maxf(scope_base_target_circle, 0.001)

	scope_shrink_sfx.pitch_scale += lerp(
		scope_shrink_sfx_min_pitch,
		scope_shrink_sfx_max_pitch,
		0.005
	)

	weapon_shooting.power_target_circle = new_target_circle
	%Inner_scope.scale = Vector2.ONE * (scope_base_scale * scale_ratio)

	if t >= 1.0:
		if mode == ScopeMode.SHRINK:
			_scope_at_min = true
		else:
			_scope_at_max = true


func _release_scope_hold() -> void:
	_is_holding_shoot = false
	_scope_mode = ScopeMode.NONE
	_scope_at_min = false
	_scope_at_max = false
	scope_shrink_sfx.stop()
	scope_shrink_sfx.pitch_scale = scope_shrink_sfx_min_pitch
	_tween_scope_back_to_base()


## Backward-compatible alias.
func handle_scope_shrink(delta: float) -> void:
	handle_scope_adjust(delta)


func _tween_scope_back_to_base() -> void:
	if _shrink_return_tween:
		_shrink_return_tween.kill()

	_shrink_return_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shrink_return_tween.tween_interval(0.1)
	_shrink_return_tween.tween_property(%Inner_scope, "scale", Vector2.ONE * scope_base_scale, scope_return_duration)
	_shrink_return_tween.parallel().tween_property(weapon_shooting, "power_target_circle", scope_base_target_circle, scope_return_duration)
	# _shrink_return_tween.parallel().tween_property(%Target_circle, "scale", Vector2.ONE * scope_base_scale, scope_return_duration)



func get_max_ammo() -> int:
	if _level_editor_ammo_active:
		return LEVEL_EDITOR_AMMO_MAX
	return int(gl_DataSet.get_value('power_max_ammo', gl_PlayerState.dataset.power_max_ammo))


func get_displayed_ammo() -> int:
	if _level_editor_ammo_active:
		return _level_editor_ammo
	return shot_count


func is_ammo_full() -> bool:
	return get_displayed_ammo() >= get_max_ammo()


func _init_ammo() -> void:
	max_ammo = get_max_ammo()
	## Export resume: restore magazine from checkpoint when present.
	if gl_PlayerState.dataset.has("shot_count"):
		shot_count = clampi(int(gl_PlayerState.dataset.shot_count), 0, max_ammo)
	else:
		shot_count = max_ammo
	_refresh_ammo_display()


func _refresh_ammo_display(animate := false) -> void:
	var shown := get_displayed_ammo()
	var hud := $CanvasLayer/HUD_bottom_corner/AmmoCorner/ShotRemaining
	if hud and hud.has_method('set_ammo'):
		hud.set_ammo(shown, animate)
	else:
		%ShotRemainingLabel.text = str(shown).pad_zeros(2)

	%Crosshair.out_of_ammo_hide()


## Adds pack bullets up to max capacity. Returns how many were actually added.
func add_ammo(amount: int, animate := true) -> int:
	if _level_editor_ammo_active:
		return 0
	max_ammo = get_max_ammo()
	var before := shot_count
	shot_count = mini(shot_count + amount, max_ammo)
	var added := shot_count - before
	_refresh_ammo_display(animate and added > 0)
	return added


## Spend ammo for each projectile fired. Returns false if not enough bullets.
func consume_ammo(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if debug_infinite_ammo:
		return true

	if _level_editor_ammo_active:
		if _level_editor_ammo < amount:
			return false
		_level_editor_ammo = maxi(_level_editor_ammo - amount, 0)
		_refresh_ammo_display()
		if _level_editor_ammo <= 0:
			# Editor rounds keep a full separate mag — never block the test.
			_level_editor_ammo = LEVEL_EDITOR_AMMO_MAX
			_refresh_ammo_display()
		return true

	if shot_count < amount:
		if _is_in_testing_room():
			_refill_regular_ammo_to_max()
			if shot_count < amount:
				return false
		else:
			return false

	max_ammo = get_max_ammo()
	shot_count = clampi(shot_count - amount, 0, max_ammo)
	_refresh_ammo_display()

	if shot_count <= 0:
		if _is_in_testing_room():
			_refill_regular_ammo_to_max()
		else:
			out_of_ammo()

	return true


func _is_in_testing_room() -> bool:
	return gl_DataSet.is_testing_place(String(gl_PlayerState.dataset.level_name))


func _refill_regular_ammo_to_max() -> void:
	max_ammo = get_max_ammo()
	shot_count = max_ammo
	_refresh_ammo_display()


## Public full magazine refill (range-clear reward, etc.).
func refill_ammo_to_max(animate := true) -> void:
	max_ammo = get_max_ammo()
	var before := shot_count
	shot_count = max_ammo
	_refresh_ammo_display(animate and before != shot_count)


## Awaitable full refill that rolls the HUD like a shop ammo purchase.
func refill_ammo_to_max_animated() -> void:
	max_ammo = get_max_ammo()
	var before := shot_count
	shot_count = max_ammo
	var hud := $CanvasLayer/HUD_bottom_corner/AmmoCorner/ShotRemaining
	if hud and hud.has_method("await_reload_fill"):
		## Make sure HUD is visible during the clear reward.
		ensure_ammo_panel_visible()
		await hud.await_reload_fill(before, shot_count)
	else:
		_refresh_ammo_display(true)
		await get_tree().create_timer(0.5, false).timeout


## Start a level-editor-only ammo pool (does not touch regular shot_count).
func begin_level_editor_ammo(amount: int = LEVEL_EDITOR_AMMO_MAX) -> void:
	_level_editor_ammo_active = true
	_level_editor_ammo = maxi(amount, 1)
	_refresh_ammo_display()


func end_level_editor_ammo() -> void:
	_level_editor_ammo_active = false
	_refresh_ammo_display()


func get_ammo_pack_size() -> int:
	return int(gl_DataSet.get_value('ammo_pack_size', 0))


func fire_weapon() -> void:
	
	if current_state != State.ACTIVE:
		return
		
	if _is_currently_shooting:
		weapon_shooting.play_missed_sounds()
		#penalize_early_fire()
		return
		
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not running_on_mobile:
		return

	if get_displayed_ammo() <= 0 and not debug_infinite_ammo:
		if _is_in_testing_room() and not _level_editor_ammo_active:
			_refill_regular_ammo_to_max()
		elif _level_editor_ammo_active:
			_level_editor_ammo = LEVEL_EDITOR_AMMO_MAX
			_refresh_ammo_display()
		else:
			# Empty magazine: still allow shooting early-exit / ammo-reload targets.
			if weapon_shooting.shoot_special_midround_target_if_aimed():
				return
			out_of_ammo()
			weapon_shooting.play_missed_sounds()
			register_accuracy_miss()
			return

	## Glory: 6 weapon fires per round (not magazine ammo).
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("try_register_weapon_shot") and not bool(rm.try_register_weapon_shot()):
		weapon_shooting.play_missed_sounds()
		return

	if plant_crosshair_on_fire:
		if not debug_infinite_ammo and not consume_ammo(1):
			out_of_ammo()
			weapon_shooting.play_missed_sounds()
			register_accuracy_miss()
			return
		if not %Crosshair.plant_crosshair_trap():
			weapon_shooting.play_missed_sounds()
			return
		player_did_not_miss()
		return

	weapon_shooting.shoot_target()
	player_did_not_miss()
	

func out_of_ammo() -> void:
	%Crosshair.out_of_ammo_display()
	

func penalize_early_fire() -> void:
	current_gun_fire_rate_cooldown = power_gun_fire_rate
	%Bullet_icon.value = 0.0
	%Cooldown_progressBar3.value = 0.0
	weapon_shooting.play_missed_sounds()
	
	
	
func player_did_not_miss() -> void:
	
		
	%Bullet_icon.value = 0.0
	_is_currently_shooting = true
	current_gun_fire_rate_cooldown = power_gun_fire_rate
	#await get_tree().create_timer(power_gun_fire_rate).timeout
	while %Bullet_icon.value != 100.0:
		await get_tree().process_frame
	_is_currently_shooting = false


# --- Accuracy streak bar -----------------------------------------------------
var _accuracy_streak := 0
var _accuracy_bar: ProgressBar
var _accuracy_bar_tween: Tween
var _accuracy_extra_strike_granted := false


func _ensure_accuracy_bar() -> void:
	if _accuracy_bar != null and is_instance_valid(_accuracy_bar):
		return
	var layer := get_node_or_null("CanvasLayer") as CanvasLayer
	if layer == null:
		return
	var bar := ProgressBar.new()
	bar.name = "AccuracyStreakBar"
	bar.min_value = 0.0
	bar.max_value = float(maxi(accuracy_streak_max, 1))
	bar.value = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(420, 18)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -210.0
	bar.offset_right = 210.0
	bar.offset_top = -96.0
	bar.offset_bottom = -78.0
	bar.modulate = Color(0.95, 0.85, 0.35, 0.95)
	bar.visible = accuracy_streak_enabled
	layer.add_child(bar)
	_accuracy_bar = bar


func _sync_accuracy_bar_visibility() -> void:
	_ensure_accuracy_bar()
	if _accuracy_bar:
		_accuracy_bar.visible = accuracy_streak_enabled and current_state == State.ACTIVE


func register_accurate_shot() -> void:
	if not accuracy_streak_enabled:
		return
	if current_state != State.ACTIVE:
		return
	_ensure_accuracy_bar()
	_accuracy_streak = mini(_accuracy_streak + 1, accuracy_streak_max)
	_tween_accuracy_bar(float(_accuracy_streak))
	if _accuracy_streak >= accuracy_streak_max:
		_on_accuracy_streak_complete()


func register_accuracy_miss() -> void:
	if not accuracy_streak_enabled:
		return
	if _accuracy_streak <= 0:
		return
	_accuracy_streak = 0
	_tween_accuracy_bar(0.0)


func reset_accuracy_streak() -> void:
	_accuracy_streak = 0
	_accuracy_extra_strike_granted = false
	if gl_PlayerState and gl_PlayerState.has_method("set_max_strikes"):
		gl_PlayerState.set_max_strikes(3)
	_ensure_accuracy_bar()
	if _accuracy_bar:
		if _accuracy_bar_tween:
			_accuracy_bar_tween.kill()
		_accuracy_bar.max_value = float(maxi(accuracy_streak_max, 1))
		_accuracy_bar.value = 0.0
	_sync_accuracy_bar_visibility()


func _tween_accuracy_bar(to_value: float) -> void:
	_ensure_accuracy_bar()
	if _accuracy_bar == null:
		return
	_accuracy_bar.visible = accuracy_streak_enabled
	if _accuracy_bar_tween:
		_accuracy_bar_tween.kill()
	_accuracy_bar_tween = create_tween()
	_accuracy_bar_tween.tween_property(_accuracy_bar, "value", to_value, accuracy_streak_tween_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_accuracy_streak_complete() -> void:
	## Grant a 4th strike slot once, then apply a strike — total allowed becomes 4.
	if not _accuracy_extra_strike_granted:
		_accuracy_extra_strike_granted = true
		if gl_PlayerState.has_method("set_max_strikes"):
			gl_PlayerState.set_max_strikes(4)
		var rm = get_tree().get_first_node_in_group("round_manager")
		if rm and rm.get("wave_progress_feedback"):
			var wpf = rm.wave_progress_feedback
			if wpf and wpf.has_method("ensure_extra_strike_slot"):
				wpf.ensure_extra_strike_slot()

	_accuracy_streak = 0
	_tween_accuracy_bar(0.0)
	gl_PlayerState.add_strike()
	
	

func _input(event: InputEvent) -> void:
	# Reticle sensitivity only while actively playing a level (not title/shop).
	if current_state == State.ACTIVE:
		if Input.is_action_just_pressed('increase_scope_speed'):
			GameSettings.bump_mouse_sensitivity(1)
			$SFX/scopeSpeedAdjustSpeedSfx.play()
			_notify_reticle_sensitivity_popup(event)
		if Input.is_action_just_pressed('decrease_scope_speed'):
			GameSettings.bump_mouse_sensitivity(-1)
			$SFX/scopeSpeedAdjustSpeedSfx.play()
			_notify_reticle_sensitivity_popup(event)

	if current_state != State.ACTIVE:
		return
	
	if !running_on_mobile and event is InputEventMouseMotion:
		# Resolution-independent look: same screen-fraction motion on any monitor.
		if grid_aim_enabled:
			_clear_grid_aim_lock()
		target_crosshair_position += GameSettings.mouse_look_delta(event.relative)


func _notify_reticle_sensitivity_popup(event: InputEvent) -> void:
	var popup := get_node_or_null("CanvasLayer/ReticleSensitivityPopup")
	if popup == null or not popup.has_method("show_sensitivity"):
		return
	var from_controller := event is InputEventJoypadButton or event is InputEventJoypadMotion
	popup.show_sensitivity(GameSettings.mouse_sensitivity_level, from_controller)
	
	
	
	

func little_camera_movement() -> void:
	camera_3d.little_camera_movement()

func title_screen_start() -> void:
	stop_player()

	
func title_screen_end() -> void:
	## Leave the gun hidden until the player presses Play in a level shop.
	if player_gun and player_gun.has_method("hide_for_menus"):
		player_gun.hide_for_menus()
	else:
		stop_player()


func stop_player() -> void:
	if player_gun and player_gun.has_method("hide_for_menus"):
		player_gun.hide_for_menus()
	elif player_gun:
		player_gun.end_position()
	enter_state(State.ROUND_FINISHED)
	weapon_shooting.can_shoot(false)
	_scope_at_min = true
	await get_tree().create_timer(0.5, false).timeout
	_scope_at_min = false
	
	
func start_player() -> void:
	
	if gl_PlayerState.dataset.power_gun == 0:
		return
	game_lost = false
	weapon_shooting.shot_with_right_click = false
	if _level_editor_ammo_active:
		_level_editor_ammo = LEVEL_EDITOR_AMMO_MAX
	else:
		max_ammo = get_max_ammo()
		shot_count = clampi(shot_count, 0, max_ammo)
	_refresh_ammo_display()
	weapon_shooting.can_shoot(true)

	%Bullet_icon.value  = 100.0
	
	CommonCode.apply_gameplay_blur()
	if player_gun and player_gun.has_method("show_for_play"):
		player_gun.show_for_play()
	elif player_gun:
		player_gun.start_position()
	%Crosshair.cross_hair_fade_in()
	#reset_mouse_pos()
	
	await get_tree().create_timer(0.5, false).timeout
	%Mouse_turning_SFX.unmute()
	
	enter_state(State.ACTIVE)
	reset_accuracy_streak()
	_sync_accuracy_bar_visibility()
	
func reset_mouse_pos() -> void:
	print(' get_viewport().size / 2 ',  get_viewport().size / 2)
	var center : Vector2 = get_viewport().size / 2
	center -= Vector2(20.0, 20.0)
	center += Vector2(0.0, 140.0)
	#center += Vector2(0.0, 140.0)
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.2)
	tween.tween_property(self, "target_crosshair_position", center, 0.75)
	tween.parallel().tween_callback(%Crosshair.crosshair_fade_out_mode).set_delay(0.25)
	#tween.tween_interval(0.2)
	await tween.finished
	crosshair_position = center

	

func pulse_shake_camera() -> void:
	camera_3d.pulse_shake_camera()

func perfect_score() -> void:
	$SFX/PerfectScore4.play(0.5)
	$SFX/Flicker_sound.play()
	
	await get_tree().create_timer(0.1, false).timeout
	# Effects once fully visible
	pulse_shake_camera()



func play_perfect_sfx() -> void:
	pass

	
	
func round_finished(_round_finished : bool) -> void:
	if _round_finished == true:
		weapon_shooting.can_shoot(false)
		
	if _round_finished == false:
		weapon_shooting.can_shoot(true)
		
		
func show_ammo_panel() -> void:
	%HUD_bottom_corner.modulate.a = 0.0
	%HUD_bottom_corner.show()
	$CanvasLayer/HUD_bottom_corner/AmmoCorner.modulate.a = 0.0
	$CanvasLayer/HUD_bottom_corner/AmmoCorner.show()
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.2)
	tween.tween_property(%HUD_bottom_corner, 'modulate:a', 1.0, 1.0)
	tween.parallel().tween_property($CanvasLayer/HUD_bottom_corner/AmmoCorner, 'modulate:a', 1.0, 1.0)


func fade_out_ammo_panel(duration: float = 0.33) -> void:
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud == null and ammo == null:
		return
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if hud:
		tween.tween_property(hud, "modulate:a", 0.0, duration)
	if ammo:
		if hud:
			tween.parallel().tween_property(ammo, "modulate:a", 0.0, duration)
		else:
			tween.tween_property(ammo, "modulate:a", 0.0, duration)
	tween.tween_callback(func() -> void:
		if ammo:
			ammo.hide()
		if hud:
			hud.hide()
	)


func hide_ammo_panel_instant() -> void:
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud:
		hud.modulate.a = 0.0
		hud.hide()
	if ammo:
		ammo.modulate.a = 0.0
		ammo.hide()


## Shop / tally / gameplay — bullets visible without the delayed intro fade.
func ensure_ammo_panel_visible() -> void:
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud:
		hud.show()
		hud.modulate.a = 1.0
	if ammo:
		ammo.show()
		ammo.modulate.a = 1.0
