class_name Player extends Node3D

@export_group('Scope Shrink While Holding')
@onready var scope_shrink_sfx : AudioStreamPlayer = $SFX/ScopeShrink
@export var scope_shrink_sfx_min_pitch := 1.0
@export var scope_shrink_sfx_max_pitch := 1.5

@export var scope_shrink_speed := 80.0
@export var scope_min_target_circle := 20.0
@export var scope_return_duration := 0.3
@export var scope_shrink_delay_dur := 0.4

@export var can_right_click_shoot := false

@export var shot_count := 4000
var original_shot_count := 0

var game_lost := false

var _scope_at_min := false
var scope_base_scale := 1.0              # resting visual scale set by tween_scope()
var scope_base_target_circle := 60.0     # resting real hit-radius, captured on press
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

var player_cash : int
var current_round : int

@onready var gun_center: Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun
@onready var gun_right : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun2
@onready var gun_left : Node3D = $Cam_pivot/Camera3D/Player_gun/mockGun

@export var roundManager : RoundManager
@export var weapon_shooting : Node3D
@export var player_gun : Node3D

@export var current_state := State.INACTIVE
@export var facing_north := true

var current_gun_fire_rate_cooldown := 0.0
var _is_currently_shooting := false

@export var max_targeting_circle := 60.0

@onready var _mouse_sensitivity := 0.3
@export var keyboard_crosshair_speed := 800.0

@export_group('Player Upgradeable Stats')
@export var power_target_circle := 0.0
@export var power_gun_fire_rate := 0.0
@export var power_bullet_speed = 0.0
@export var power_bullet_damage : int = 1
@export var power_bullet_delay := 0.5 #0.15

@export var rotation_speed := 0.5

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
var crosshair_move_top_limit := 400
var crosshair_move_bottom_limit := 700

var cam_clamp_top := 1
var cam_clamp_bottom := 1
var cam_clamp_left := 1
var cam_clamp_right := 1
var camera_pan_able := false


func _ready() -> void:
	scope_shrink_sfx.finished.connect(_on_scope_shrink_sfx_finished)
	EventBus.instance.player_update_stats_visually.connect(update_player_stats)
	EventBus.instance.end_round_rock_missed.connect(stop_player)
	#EventBus.instance.pineapple_round_bought.connect(pineapples_start)
	var scale_multiplier = power_target_circle / gl_DataSet.dataset_float.power_target_circle[0]
	tween_scope(scale_multiplier, 0.33)

	original_shot_count = shot_count
	
	%Bullet_icon.hide()
	%Auto_fire.hide()
	$CanvasLayer/HUD_bottom_corner/TotalRocks.hide()
	$CanvasLayer/HUD_bottom_corner/PineappleRound.hide()
	$CanvasLayer/HUD_bottom_corner/SkyMine.hide()
	EventBus.instance.egg_pulsed.connect(pulse_shake_camera)
	start_rotation = rotation_degrees

	$Cam_pivot/Camera3D/SpotLight3D.light_energy = light_intensity
	$Cam_pivot/Camera3D/SpotLight3D.light_color = light_colour
	


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
	if !facing_north:
		target_rot = start_rotation + Vector3(0.0,180.0,0.0)
	
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
			Engine.time_scale = 6.0
		elif Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
	
	if current_state == State.IN_SHOP:
		return 
		
	
	if _is_currently_shooting:

		if current_gun_fire_rate_cooldown > 0.0:
			current_gun_fire_rate_cooldown -= delta
			current_gun_fire_rate_cooldown = max(current_gun_fire_rate_cooldown, 0.0)
		
		#	%Cooldown_progressBar.rotation += (2.0 * delta)

		%Cooldown_progressBar3.value = (1.0 - (current_gun_fire_rate_cooldown / power_gun_fire_rate)) * 100.0
		%Bullet_icon.value = (1.0 - (current_gun_fire_rate_cooldown / power_gun_fire_rate)) * 100.0
		
		if %Cooldown_progressBar3.value >= 100.0 && !$SFX/Reload.playing:
			$SFX/Reload.play()
			#%Cooldown_progressBar.rotation += (2.0 * delta)
			#$SFX/Reload2.play(0.12)
		#	var tween = create_tween()
		#	tween.tween_property(%Cooldown_progressBar2, 'modulate', Color.WHITE, 0.1)
		#	tween.parallel().tween_property(%Cooldown_progressBar, 'modulate', Color.WHITE, 0.1)
			
			#tween.tween_property(%Cooldown_progressBar, 'scale', Vector2(0.13,0.13), 0.05)
			#tween.tween_property(%Cooldown_progressBar, 'scale', Vector2(0.111,0.111), 0.05)
			
			#tween.tween_property(%Cooldown_progressBar2, 'scale', Vector2(0.075,0.075), 0.05)
			#tween.tween_property(%Cooldown_progressBar2, 'scale', Vector2(0.06,0.06), 0.05)
	
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
	
	crosshair.position = target_crosshair_position #This controls the movement of crosshair 2D
	
	#if Input.is_action_pressed("shootWeapon") && gl_PlayerState.dataset.power_auto_fire > 0:
		#fire_weapon()
	
	#if Input.is_action_just_pressed("shootWeapon") && gl_PlayerState.dataset.power_auto_fire == 0:
		#fire_weapon()
		
	if Input.is_action_just_released("shootWeapon"):
		weapon_shooting.shot_with_right_click = false
		fire_weapon()
	
	
	if Input.is_action_just_released("shoot_weapon_2"):
		if gl_PlayerState.dataset.power_sky_mine > 0:
			weapon_shooting.shooting_sky_mine = true
			fire_weapon()
		else:
			weapon_shooting.play_missed_sounds()
	
	if Input.is_action_just_released("shoot_weapon_2") && can_right_click_shoot:
		weapon_shooting.shot_with_right_click = true
		fire_weapon()
		
	#if Input.is_action_pressed("shoot_weapon_2"):
		#weapon_shooting.shot_with_right_click = true
		#
	#if Input.is_action_just_released("shoot_weapon_2"):
		#weapon_shooting.shot_with_right_click = false
	
	
	crosshair_position = crosshair_position.lerp(target_crosshair_position, (crosshair_lag_speed / 10) - pow(0.001, delta))
	%Crosshair.global_position = crosshair_position
	
	#handle_pan_up_and_down(delta)
	#handle_pan_left_and_right(delta)
	handle_keyboard_crosshair(delta)
	update_gun_look()
	handle_scope_shrink(delta)
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

	var joystick_motion := direction * strength * joystick_sensitivity * delta
	target_crosshair_position += joystick_motion

func handle_keyboard_crosshair(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("forward", "backward")
	)

	if direction == Vector2.ZERO:
		return

	target_crosshair_position += direction.normalized() * keyboard_crosshair_speed * delta

func set_power(settings:Dictionary, setting_name:String)-> float:
	return gl_DataSet.get_value(setting_name, settings[setting_name])

func update_player_stats() -> void:
	var settings : Dictionary = gl_PlayerState.get_all()
	
	#if settings['round'] % 2 == 0:
		#power_target_circle = 200.0
		#power_bullet_speed = 0.5
		#power_bullet_damage = 2
		##power_bullet_delay = 
		#power_gun_fire_rate = 0.5
#
	#else:
	
	#power_gun_fire_rate = 0.15
	#power_bullet_delay = 0.1
	
	power_target_circle = set_power(settings, 'power_target_circle')
	power_bullet_speed = set_power(settings, 'power_bullet_speed')
	power_bullet_damage = int(set_power(settings, 'power_bullet_damage'))
	power_bullet_delay = set_power(settings, 'power_bullet_delay')
	power_gun_fire_rate = set_power(settings, 'power_gun_fire_rate')

	#
	player_gun.update_guns()
	
	player_cash 		= settings.cash
	current_round 		= settings.round
	
	weapon_shooting.apply_upgrades()
	update_stats_visually()


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
	
	
	var scale_multiplier = power_target_circle / gl_DataSet.dataset_float.power_target_circle[0]

	scale_multiplier = min(scale_multiplier, 21.0)
	tween_scope(scale_multiplier, 0.33)

func display_hud() -> void:
	%HUD_bottom_corner.show()
	$CanvasLayer/HUD_bottom_corner/TotalRocks._update_for_new_round()
	
	
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
	if _scope_at_min:
		return
		
	if _is_holding_shoot and scope_hold_time >= scope_shrink_delay_dur:
		scope_shrink_sfx.play()
		
		
func handle_scope_shrink(delta: float) -> void:
	if Input.is_action_pressed("shootWeapon"):
		if not _is_holding_shoot:
			_is_holding_shoot = true
			scope_hold_time = 0.0
			scope_base_target_circle = weapon_shooting.power_target_circle
			_scope_at_min = false
			if _shrink_return_tween:
				_shrink_return_tween.kill()

		scope_hold_time += delta

		if scope_hold_time < scope_shrink_delay_dur:
			return

		if _scope_at_min:
			return

		if not scope_shrink_sfx.playing && scope_hold_time < (scope_shrink_delay_dur + 0.2):
			scope_shrink_sfx.play()

		var new_target_circle : float = clamp(
			scope_base_target_circle - ((scope_hold_time - scope_shrink_delay_dur) * scope_shrink_speed),
			scope_min_target_circle,
			scope_base_target_circle
		)

		var shrink_ratio := new_target_circle / scope_base_target_circle

		scope_shrink_sfx.pitch_scale += lerp(
			scope_shrink_sfx_min_pitch,
			scope_shrink_sfx_max_pitch,
			0.005
		)

		weapon_shooting.power_target_circle = new_target_circle
		%Inner_scope.scale = Vector2.ONE * (scope_base_scale * shrink_ratio)
		# %Target_circle.scale = Vector2.ONE * (scope_base_scale * shrink_ratio)

		if new_target_circle <= scope_min_target_circle:
			_scope_at_min = true

	elif _is_holding_shoot:
		_is_holding_shoot = false
		_scope_at_min = false
		scope_shrink_sfx.stop()
		scope_shrink_sfx.pitch_scale = scope_shrink_sfx_min_pitch
		_tween_scope_back_to_base()


func _tween_scope_back_to_base() -> void:
	if _shrink_return_tween:
		_shrink_return_tween.kill()

	_shrink_return_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shrink_return_tween.tween_interval(0.1)
	_shrink_return_tween.tween_property(%Inner_scope, "scale", Vector2.ONE * scope_base_scale, scope_return_duration)
	_shrink_return_tween.parallel().tween_property(weapon_shooting, "power_target_circle", scope_base_target_circle, scope_return_duration)
	# _shrink_return_tween.parallel().tween_property(%Target_circle, "scale", Vector2.ONE * scope_base_scale, scope_return_duration)



func fire_weapon() -> void:
	
	if current_state != State.ACTIVE:
		return
		
	if _is_currently_shooting:
		weapon_shooting.play_missed_sounds()
		#penalize_early_fire()
		return
		
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
		
	weapon_shooting.shoot_target()
	player_did_not_miss()
	
	
	
	shot_count = clamp(shot_count - 1, 0, 100)
	%ShotRemaining.text = str(shot_count).pad_zeros(2)
	if shot_count <= 0:
		await get_tree().create_timer(0.5).timeout
		print("shot count reached")
		EventBus.instance.end_round_rock_missed.emit()
	


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
	
	if current_state != State.ACTIVE:
		return

	if Input.is_action_just_pressed("switch_viewport"):
		if get_viewport().debug_draw == Viewport.DebugDraw.DEBUG_DRAW_UNSHADED:
			get_viewport().debug_draw = Viewport.DebugDraw.DEBUG_DRAW_DISABLED
		else:
			get_viewport().debug_draw = Viewport.DebugDraw.DEBUG_DRAW_UNSHADED
		
	if event is InputEventMouseMotion:
		target_crosshair_position += event.relative * _mouse_sensitivity * gl_PlayerState.mouse_sensitivity
		
		
func flip_around() -> void:
	if !facing_north:
		var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, 'rotation_degrees', start_rotation, 1.0)
		await tween.finished
		facing_north = true
		
	else:
		var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, 'rotation_degrees', start_rotation + Vector3(0,180,0), 1.0)
		await tween.finished
		facing_north = false
		
	
func little_camera_movement() -> void:
	camera_3d.little_camera_movement()

func title_screen_start() -> void:
	stop_player()
	#$HUD_display.hide()
	#process_mode = Node.PROCESS_MODE_DISABLED
	
func title_screen_end() -> void:
	#process_mode = Node.PROCESS_MODE_INHERIT
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if !facing_north:
		facing_north = true
		reset_pos()
		
	#$HUD_display.show()
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
	shot_count = original_shot_count
	%ShotRemaining.text = str(shot_count).pad_zeros(2)
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
	var center : Vector2 = get_viewport().size / 2
	center -= Vector2(20.0, 20.0)
	center += Vector2(0.0, 140.0)
	center += Vector2(0.0, 140.0)
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
	#$SFX/PerfectScore.play()
	#$SFX/Flicker_sound.play()
	#$SFX/PerfectScore4.play(0.5)
	#await get_tree().create_timer(0.25).timeout

	
	
func round_finished(_round_finished : bool) -> void:
	if _round_finished == true:
		weapon_shooting.can_shoot(false)
		
	if _round_finished == false:
		weapon_shooting.can_shoot(true)
