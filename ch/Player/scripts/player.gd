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
@export var scope_shrink_sfx_max_pitch := 1.5
@export var scope_shrink_duration := 0.5          # total seconds to fully shrink, regardless of starting size
@export var scope_shrink_large_bonus := 0.2        # extra seconds tacked on for very large scopes
@export var scope_shrink_reference_circle := 60.0  # "normal" size; circles above this scale toward the bonus
var _current_shrink_duration := 0.5
@export var scope_min_target_circle := 20.0
@export var scope_return_duration := 0.3
@export var scope_shrink_delay_dur := 0.4
## Max scope size while holding right-click, as a multiple of resting radius (1.0 = no grow).
const SCOPE_EXPAND_MAX_SCALE := 1.85

@export_group('Scope Shot Modifiers')
## Applied to upgraded base travel time while shrinking. Lower = faster bullets (travel seconds).
@export var scope_shrink_bullet_speed_scale := 0.5
## Applied to upgraded base travel time while expanding. Higher = slower bullets.
@export var scope_expand_bullet_speed_scale := 7.0
## Applied to upgraded base fire-rate cooldown while shrinking. Lower = faster fire.
@export var scope_shrink_fire_rate_scale := 0.14
## Applied to upgraded base fire-rate cooldown while expanding. Higher = slower fire.
@export var scope_expand_fire_rate_scale := 5.7
## Resting upgrade values — restored when not holding shrink/expand.
var _base_bullet_speed := 0.3
var _base_gun_fire_rate := 0.35

@export var can_right_click_shoot := false

## Current bullets loaded. Starts at power_max_ammo and is refilled via shop ammo packs.
var shot_count := 0
var max_ammo := 0
## Separate magazine used only while a level-editor test round is active.
var _level_editor_ammo_active := false
var _level_editor_ammo := 99
const LEVEL_EDITOR_AMMO_MAX := 99

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
@onready var gun_right : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun2
@onready var gun_left : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun

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

const light_colour := Color('FFFFFF')
const light_intensity := 2.0


var start_rotation : Vector3

var target_crosshair_position: Vector2 = Vector2(980, 540)
var crosshair_position := Vector2.ZERO
var crosshair_lag_speed := 11.0  # Higher = faster catch-up

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
	
	%Bullet_icon.hide()
	%Auto_fire.hide()
	$CanvasLayer/HUD_bottom_corner/TotalRocks.hide()
	$CanvasLayer/HUD_bottom_corner/PineappleRound.hide()
	$CanvasLayer/HUD_bottom_corner/SkyMine.hide()
	EventBus.instance.egg_pulsed.connect(pulse_shake_camera)
	start_rotation = rotation_degrees
	_setup_mobile_pause_button()


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
	pass
	
	
func update_round_finished() -> void:
	weapon_shooting.time_ran_out = true
	
	reset_pos()
	reset_mouse_pos()
	%Mouse_turning_SFX.mute()
	#await get_tree().create_timer(1.0).timeout
	#tween_scope(1.0, 1.0)
	#await get_tree().create_timer(1.0).timeout
	
	weapon_shooting.time_ran_out = false
	
func update_in_shop() -> void:
	pass
	
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
	
	if OS.has_feature("editor") && !game_lost:
		if Input.is_action_pressed("middle_mouse"):
			Engine.time_scale = 10.0
			#Engine.time_scale = 0.25
		if Input.is_action_just_released("middle_mouse"):
			if Engine.time_scale != 1.0:
				Engine.time_scale = 1.0
	
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

	crosshair.position = target_crosshair_position
	crosshair_position = crosshair_position.lerp(target_crosshair_position, (crosshair_lag_speed / 10) - pow(0.001, delta))
	%Crosshair.global_position = crosshair_position

	# Desktop: InputMap shoot / scope. Mobile: left-half touch only (ignore emulated mouse).
	if running_on_mobile:
		if mobile_controller.consume_fire_release():
			fire_weapon()
	else:
		if Input.is_action_just_released("shootWeapon"):
			fire_weapon()

		if Input.is_action_just_released("shoot_weapon_2"):
			fire_weapon()

	handle_scope_adjust(delta)
	
	#if Input.is_action_pressed("shootWeapon"):
		#return
	
	
	#handle_pan_up_and_down(delta)
	#handle_pan_left_and_right(delta)
	handle_keyboard_and_controller_input(delta)
	update_gun_look()
	
	#handle_pan_keyboard(delta)
	
func update_gun_look() -> void:

	var screen_pos = crosshair.global_position + Vector2(20.0,20.0)

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
	
	
	$Cam_pivot/Camera3D/Player_gun/mockGun.look_at(target_pos, Vector3.UP, true)
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
	_base_bullet_speed = power_bullet_speed
	_base_gun_fire_rate = power_gun_fire_rate

	#power_gun_fire_rate = 0.05
	#power_bullet_speed = 0.01
	#power_target_circle = 60.0
	
	player_gun.update_guns()

	#full_power_mode()
	
	player_cash 		= settings.cash
	current_round 		= settings.round
	
	weapon_shooting.apply_upgrades()
	update_stats_visually()


func full_power_mode() -> void:
	power_target_circle = gl_DataSet.get_value('power_target_circle', 9)
	power_bullet_speed = gl_DataSet.get_value('power_bullet_speed', 9)
	power_bullet_damage = int(gl_DataSet.get_value('power_bullet_damage', 9))
	power_bullet_delay =  gl_DataSet.get_value('power_bullet_delay', 9)
	power_gun_fire_rate = gl_DataSet.get_value('power_gun_fire_rate', 9)

func update_stats_visually() -> void:
	await get_tree().create_timer(0.5).timeout
	
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
	await get_tree().create_timer(0.5).timeout
	$CanvasLayer/HUD_bottom_corner/SkyMine.start()
	%Cooldown_progressBar3.self_modulate = Color('d10000')
	$CanvasLayer/Crosshair/Inner_scope/center_container.modulate = Color('d10000')
	
	
func remove_sky_mine() -> void:
	#await get_tree().create_timer(0.25).timeout
	$CanvasLayer/HUD_bottom_corner/SkyMine.stop()
	%Cooldown_progressBar3.self_modulate = Color('FFFFFF')
	$CanvasLayer/Crosshair/Inner_scope/center_container.modulate = Color('FFFFFF')


func apply_auto_fire() -> void:
	%Auto_fire.start()

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
		shrink_held = Input.is_action_pressed("shootWeapon")
		expand_held = Input.is_action_pressed("shoot_weapon_2")

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
	shot_count = max_ammo
	_refresh_ammo_display()


func _refresh_ammo_display(animate := false) -> void:
	var shown := get_displayed_ammo()
	var hud := $CanvasLayer/HUD_bottom_corner/ShotRemaining
	if hud and hud.has_method('set_ammo'):
		hud.set_ammo(shown, animate)
	else:
		%ShotRemaining.text = str(shown).pad_zeros(2)

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

	if get_displayed_ammo() <= 0:
		if _is_in_testing_room() and not _level_editor_ammo_active:
			_refill_regular_ammo_to_max()
		elif _level_editor_ammo_active:
			_level_editor_ammo = LEVEL_EDITOR_AMMO_MAX
			_refresh_ammo_display()
		else:
			# Empty magazine: still allow shooting the early-exit retreat target.
			if weapon_shooting.shoot_early_exit_if_aimed():
				return
			out_of_ammo()
			weapon_shooting.play_missed_sounds()
			return
	
	#set_process(false)
	#set_process_input(false)
	weapon_shooting.shoot_target()
	player_did_not_miss()
	
	#$CanvasLayer/Crosshair/RedDot.hide()
	
	#await get_tree().create_timer(0.25).timeout
	#set_process_input(true)
	#set_process(true)
	
	#%Crosshair.duplicate_inner_scope()
	

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
	#reset_pos()
	start_player()


func stop_player() -> void:
	player_gun.end_position()
	enter_state(State.ROUND_FINISHED)
	weapon_shooting.can_shoot(false)
	_scope_at_min = true
	await get_tree().create_timer(0.5).timeout
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

	%Cooldown_progressBar3.value = 100.0
	%Bullet_icon.value  = 100.0
	
	#await get_tree().create_timer(0.5).timeout
	player_gun.start_position()
	%Crosshair.cross_hair_fade_in()
	#reset_mouse_pos()
	
	await get_tree().create_timer(0.5).timeout
	%Mouse_turning_SFX.unmute()
	
	enter_state(State.ACTIVE)

	
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
	
	await get_tree().create_timer(0.1).timeout
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
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(2.0)
	tween.tween_property(%HUD_bottom_corner, 'modulate:a', 1.0, 1.0)
