class_name Player extends Node3D

## When true, pressing the `ctrl` action cycles gun1 → gun2 → gun3 → gun4 → gun5 → gun1.
@export var ctrl_swap_guns := true

const mouse_no_lerp := false

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
const scope_shrink_duration := 0.15 #0.5          # total seconds to fully shrink, regardless of starting size
@export var scope_shrink_large_bonus := 0.2        # extra seconds tacked on for very large scopes
const scope_shrink_reference_circle := 60.0  # "normal" size; circles above this scale toward the bonus
@export var _current_shrink_duration := 0.15
const scope_min_target_circle := 30.0 #20.0
@export var scope_return_duration := 0.3
## On shrink/expand release: ease past resting size by this factor, then settle to default.
@export_range(1.0, 15.5, 0.01) var scope_return_overshoot := 1.12
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

@export_group("Crosshair Destroy On Overlap")
## When true, overlapping the reticle pops balloons without a shot.
@export var crosshair_destroy_on_overlap_balloons := false
## When true, overlapping the reticle destroys standard / grey rocks without a shot.
@export var crosshair_destroy_on_overlap_rocks := false
## When true, overlapping the reticle destroys black hazard rocks. Red avoiders still use their own overlap explode.
@export var crosshair_destroy_on_overlap_hazards := false

func wants_crosshair_destroy_on_overlap(kind: String) -> bool:
	match kind:
		"balloons":
			return crosshair_destroy_on_overlap_balloons
		"rocks":
			return crosshair_destroy_on_overlap_rocks
		"hazards":
			return crosshair_destroy_on_overlap_hazards
		_:
			return false

## Current bullets loaded. Starts at power_max_ammo and is refilled via shop ammo packs.
var shot_count := 0
var max_ammo := 0
## Glory `six_shots_only` challenge: hard magazine cap (see get_max_ammo).
const SIX_SHOTS_AMMO_CAP := 6
## Magazine loaded when Play is pressed, and granted by an ammo balloon with no amount.
const STARTING_AMMO := 12
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

## Scripted loadouts: gun1 (Rossy), gun2 (rapid), gun3 (slow travel), gun4 (plant), gun5 (timed lead).
enum GunLoadout { GUN1 = 1, GUN2 = 2, GUN3 = 3, GUN4 = 4, GUN5 = 5 }
## Which loadout is equipped when a round starts (`start_player` / boot).
@export var starting_gun_loadout: GunLoadout = GunLoadout.GUN1
var active_gun_loadout: GunLoadout = GunLoadout.GUN1
var _gun_swap_token := 0
## When >= 0, `_apply_scope_shot_stats` uses this travel time instead of the hardcoded 0.05.
var _loadout_bullet_speed_override := -1.0
@export_range(0.05, 2.0, 0.01) var gun3_bullet_travel_sec := 0.3
## Gun5: seconds ahead to predict target positions for the bow-style lead shot.
@export_range(0.05, 2.0, 0.01) var gun5_timed_shot_sec := 0.3
## Extra forgiveness around the lead time — a hit still counts if the target is under the
## reticle anywhere in [lead − window/2, lead + window/2].
@export_range(0.0, 0.5, 0.01) var gun5_hit_window_sec := 0.1
## How high a missed gun5 projectile arcs (world units) on its way to the aim plane.
@export_range(0.0, 12.0, 0.1) var gun5_miss_lob_height := 3.0
## World Z of the aim plane gun5 miss shots fly toward (rocks typically sit near this).
@export var gun5_aim_plane_z := 23.0

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

@export_group("Grid Aim")
## When false, keyboard / left stick / D-pad keep free aim. When true, they step between A1–C8 grid cells.
@export var grid_aim_enabled := false
## Screen pixels per second while sliding the crosshair between grid cells.
@export var grid_aim_move_speed := 1800.0
## Extra vertical lanes just outside columns 1 and 8 (same A/B/C heights) for the reticle.
@export var grid_aim_side_lanes := true
## Extra aim rows below C (row 3). Crosshair only — does not change rock spawn lanes.
@export var grid_aim_extra_rows_down := 2
## World Y of the first extra row down (row 4). A/B/C are 6.5 / 3.5 / 0.5.
@export var grid_aim_extra_row_1_y := -2.5
## World Y of the second extra row down (row 5).
@export var grid_aim_extra_row_2_y := -5.5
## Extra aim columns beyond A1–C8 on each side (column 0 left, 9 right when 1).
@export var grid_aim_extra_columns_each_side := 1
## World X of the extra-left column (column 0 default is one step outside 1 → 9.0).
@export var grid_aim_extra_left_x := 9.0
## World X of the extra-right column (column 9 default is one step outside 8 → -9.0).
@export var grid_aim_extra_right_x := -9.0
## Volume for the short hovercraft clip played on each grid step.
@export_range(-80.0, 6.0, 0.5) var grid_aim_step_sfx_volume_db := -28.0
## How long each step SFX plays before stopping (full files are longer).
@export_range(0.05, 2.0, 0.05) var grid_aim_step_sfx_duration := 0.5

@export_group("Player Lean")
## When grid aim is off: how far the player peeks left/right (world units).
@export var lean_sideways := 0.45
## When grid aim is off: how far the player peeks up (world +Y).
@export var lean_upwards := 0.3
## When grid aim is off: how far the player peeks down (world −Y).
@export var lean_downwards := 0.35
## Max Z-roll (degrees) when fully leaning left/right. Negate to flip tilt direction.
@export var lean_roll_degrees := 6.0
## If true, cardinal lean yaws/pitches instead of peeking / Z-rolling.
@export var lean_use_yaw := false
## Max Y rotation (degrees) when fully leaning left/right. Negate to flip turn direction.
@export var lean_yaw_degrees := 12.0
## Max X rotation (degrees) when fully looking up/down. Negate to flip pitch direction.
@export var lean_pitch_degrees := 8.0
## How quickly the lean eases toward the held direction.
@export var lean_in_speed := 8.0
## How quickly the lean eases back to rest on release.
@export var lean_out_speed := 10.0

@export_group("Crosshair Size")
## Multiplies the resting scope size (hit radius + visual), same idea as holding expand toward SCOPE_EXPAND_MAX_SCALE.
@export_range(0.25, 3.0, 0.05) var crosshair_default_size_scale := 1.0:
	set(value):
		crosshair_default_size_scale = maxf(value, 0.05)
		if is_node_ready():
			_apply_resting_crosshair_size(0.2)

@export_group("Drunken_affect")
## When true, the crosshair wobbles / sways and aim input feels heavier.
@export var drunken_affect_enabled := false
## Fast tremor amplitude in screen pixels.
@export_range(0.0, 80.0, 0.5) var drunken_wobble_amp := 2.5
## Fast tremor frequency.
@export_range(0.1, 12.0, 0.05) var drunken_wobble_speed := 2.4
## Slow sway amplitude in screen pixels.
@export_range(0.0, 80.0, 0.5) var drunken_sway_amp := 4.0
## Slow horizontal sway frequency.
@export_range(0.05, 4.0, 0.05) var drunken_sway_speed := 0.55
## Slow vertical sway frequency (offset for a looser figure-eight).
@export_range(0.05, 4.0, 0.05) var drunken_sway_speed_y := 0.4
## Multiplier on mouse / stick / keyboard aim (lower = heavier / harder to steer).
@export_range(0.15, 1.0, 0.05) var drunken_input_scale := 0.85
## Crosshair follow lag while drunk (lower = heavier catch-up).
@export_range(1.0, 20.0, 0.5) var drunken_lag_speed := 7.5
## Extra random wander amplitude (pixels).
@export_range(0.0, 40.0, 0.5) var drunken_drift_amp := 1.5
## How quickly the random wander eases toward a new offset.
@export_range(0.1, 6.0, 0.05) var drunken_drift_speed := 1.0

@export_group("Planted Crosshair")
## When true, fire-release plants a crosshair trap instead of shooting. Overlap = hit; expires after lifetime. Max 5.
@export var plant_crosshair_on_fire := false
## When true, `shoot_weapon_2` (right-click) plants a crosshair trap instead of shrinking the scope.
@export var right_click_is_planted_crosshair := false
## Seconds a planted trap stays faded and inactive before it can hit.
@export var planted_crosshair_arm_delay := 1.5
## Seconds the trap stays live after planting (including arm delay) before it dissipates on its own.
@export_range(0.5, 30.0, 0.1) var planted_crosshair_lifetime := 7.0
## Degrees per second the planted crosshair spins once it goes live.
@export var planted_crosshair_rotation_speed := 120.0
## How far the outer-ring pulse expands (multiply of outer-scope scale).
@export_range(1.2, 6.0, 0.1) var planted_crosshair_pulse_scale := 2.8
## Duration of the plant / end ring-pulse fade.
@export_range(0.1, 1.5, 0.05) var planted_crosshair_pulse_duration := 0.4
## When true, every successful shoot-release pulses a duplicate RingTexture (expand + fade).
@export var shoot_ring_pulse_on_release := false
## How far the shoot-release ring expands from the live RingTexture size (1 = no grow).
@export_range(1.0, 8.0, 0.05) var shoot_ring_pulse_scale := 2.0
## Duration of the shoot-release ring expand + fade.
@export_range(0.05, 2.0, 0.05) var shoot_ring_pulse_duration := 0.35
## Ring pulse color for `shoot_weapon_2` (right-click / orange launch).
@export var shoot_weapon_2_ring_pulse_color := Color(1.0, 0.55, 0.12, 1.0)

const light_colour := Color('FFFFFF')
const light_intensity := 2.0

## Crosshair Control is 40×40; gun aim uses global_position + this offset (center).
const CROSSHAIR_CENTER_OFFSET := Vector2(20.0, 20.0)
const GRID_AIM_ON_CELL_PX := 36.0
const GRID_AIM_REPEAT_INITIAL_SEC := 0.32
const GRID_AIM_REPEAT_RATE_SEC := 0.11
const GRID_AIM_STICK_DEADZONE := 0.55

var start_rotation : Vector3
var _lean_rest_position := Vector3.ZERO
var _lean_rest_rotation_z := 0.0
var _lean_rest_rotation_y := 0.0
var _ammo_hud_tween: Tween
var _lean_rest_rotation_x := 0.0
var _lean_offset := Vector3.ZERO
var _lean_roll := 0.0
var _lean_yaw := 0.0
var _lean_pitch := 0.0

var target_crosshair_position: Vector2 = Vector2(980, 540)
var crosshair_position := Vector2.ZERO
var crosshair_lag_speed := 11.0  # Higher = faster catch-up
var _crosshair_knock_tween: Tween
var _drunken_time := 0.0
var _drunken_drift := Vector2.ZERO
var _drunken_drift_target := Vector2.ZERO
var _drunken_drift_retarget_left := 0.0

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
var _grid_aim_sfx_left: AudioStreamPlayer
var _grid_aim_sfx_right: AudioStreamPlayer
var _grid_aim_sfx_stop_timer: Timer
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
	active_gun_loadout = starting_gun_loadout
	_apply_gun_crosshair_visibility()
	_apply_gun_loadout_stats(false)
	
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	#get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	
	scope_shrink_sfx.finished.connect(_on_scope_shrink_sfx_finished)
	EventBus.instance.player_update_stats_visually.connect(update_player_stats)
	EventBus.instance.end_round_rock_missed.connect(stop_player)
	#EventBus.instance.pineapple_round_bought.connect(pineapples_start)
	var start_radius := gl_DataSet.get_value(
		'power_target_circle',
		gl_PlayerState.dataset.power_target_circle
	)
	power_target_circle = start_radius
	_apply_resting_crosshair_size(0.33)
	
	_init_ammo()
	update_player_stats()
	_setup_grid_aim_step_sfx()
	
	#%Bullet_icon.hide()

	EventBus.instance.egg_pulsed.connect(pulse_shake_camera)
	start_rotation = rotation_degrees
	_lean_rest_position = position
	_lean_rest_rotation_z = rotation.z
	_lean_rest_rotation_y = rotation.y
	_lean_rest_rotation_x = rotation.x
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
		_update_player_lean(delta, Vector2.ZERO)
		_update_hold_aim_zoom()
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
		_update_player_lean(delta, Vector2.ZERO)
		_update_hold_aim_zoom()
		return
	
	if current_state == State.INACTIVE || current_state == State.IN_SHOP:
		_update_player_lean(delta, Vector2.ZERO)
		_update_hold_aim_zoom()
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
		var mobile_motion = mobile_controller.get_crosshair_motion()
		if drunken_affect_enabled:
			mobile_motion *= drunken_input_scale
		target_crosshair_position += mobile_motion

	# Keyboard / left stick / D-pad before reticle push so grid slides apply this frame.
	handle_keyboard_and_controller_input(delta)

	crosshair.position = target_crosshair_position
	if grid_aim_enabled and _grid_aim_moving:
		crosshair_position = target_crosshair_position
	
	elif mouse_no_lerp:
		crosshair_position = target_crosshair_position
	else:
		var lag := drunken_lag_speed if drunken_affect_enabled else crosshair_lag_speed
		crosshair_position = crosshair_position.lerp(target_crosshair_position, (lag / 10) - pow(0.001, delta))
		
		
	var display_pos := crosshair_position
	if drunken_affect_enabled and current_state == State.ACTIVE:
		display_pos += _update_drunken_offset(delta)
	%Crosshair.global_position = display_pos

	# Desktop: InputMap shoot / scope. Mobile: left-half touch only (ignore emulated mouse).
	if running_on_mobile:
		if active_gun_loadout == GunLoadout.GUN2:
			if mobile_controller.is_fire_held():
				fire_weapon_auto()
		elif mobile_controller.consume_fire_release():
			fire_weapon()
	else:
		if active_gun_loadout == GunLoadout.GUN2:
			## Hold shoot = rapid fire (same as old TAB path). No release-tap shot / no scope expand.
			if Input.is_action_pressed("shootWeapon"):
				fire_weapon_auto()
				
		elif Input.is_action_just_pressed("shootWeapon"):
			fire_weapon()
			
		#elif Input.is_action_just_released("shootWeapon"):
			#fire_weapon()

		## Debug / leftover: TAB still rapid-fires on any loadout.
		if Input.is_key_label_pressed(KEY_TAB):
			fire_weapon_auto()

		if Input.is_action_just_pressed("spacebar"):
			fire_weapon()

		if Input.is_action_just_released("shoot_weapon_2"):
			#fire_oranges()
			if right_click_is_planted_crosshair:
				fire_weapon(true)
			else:
				fire_weapon()



	handle_scope_adjust(delta)
	_update_hold_aim_zoom()

	#if Input.is_action_pressed("shootWeapon"):
		#return
	
	
	#handle_pan_up_and_down(delta)
	#handle_pan_left_and_right(delta)
	update_gun_look()
	
	#handle_pan_keyboard(delta)
	

## World point under the reticle center on a fixed Z plane (e.g. orange spawn depth).
func _crosshair_world_on_z(plane_z: float) -> Vector3:
	var screen_pos := crosshair.global_position + CROSSHAIR_CENTER_OFFSET
	var origin: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var dir: Vector3 = camera_3d.project_ray_normal(screen_pos)
	if absf(dir.z) < 0.0001:
		return Vector3(origin.x, origin.y, plane_z)
	var t := (plane_z - origin.z) / dir.z
	var hit := origin + dir * t
	return Vector3(hit.x, hit.y, plane_z)


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
	if drunken_affect_enabled:
		joystick_motion *= drunken_input_scale
	target_crosshair_position += joystick_motion

func handle_keyboard_and_controller_input(delta: float) -> void:
	if grid_aim_enabled:
		_handle_grid_aim_input(delta)
		_update_player_lean(delta, Vector2.ZERO)
		return

	# Stick keeps free crosshair aim. Cardinal keys lean the player (not the reticle).
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	const STICK_DEADZONE := 0.12
	if stick.length() > STICK_DEADZONE:
		var magnitude := clampf(stick.length(), 0.0, 1.0)
		var strength := pow(magnitude, 1.35)
		var target_velocity := stick.normalized() * strength
		const ACCEL := 60.0
		keyboard_velocity = keyboard_velocity.lerp(target_velocity, ACCEL * delta)
		var motion := keyboard_velocity * delta
		if drunken_affect_enabled:
			motion *= drunken_input_scale
		target_crosshair_position += motion
	else:
		const DECEL := 18.0
		keyboard_velocity = keyboard_velocity.lerp(Vector2.ZERO, DECEL * delta)
		if keyboard_velocity.length_squared() < 0.01:
			keyboard_velocity = Vector2.ZERO
		else:
			var coast := keyboard_velocity * delta
			if drunken_affect_enabled:
				coast *= drunken_input_scale
			target_crosshair_position += coast

	_update_player_lean(delta, _player_lean_input())


## Cardinal hold strength for lean: x −1…1 left/right, y −1…1 up/down (screen-style).
func _player_lean_input() -> Vector2:
	var x := Input.get_axis("left", "right")
	if is_zero_approx(x):
		x = Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("forward", "backward")
	if is_zero_approx(y):
		y = Input.get_axis("ui_up", "ui_down")
	## Stick is for crosshair; don't also lean from stick tilts.
	return Vector2(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0))


## Smooth peek from rest toward lean_* amounts while held; ease back on release.
## When `lean_use_yaw` is on, left/right yaws and up/down pitches instead of translating / Z-rolling.
func _update_player_lean(delta: float, dir: Vector2) -> void:
	var desired := Vector3.ZERO
	var desired_roll := 0.0
	var desired_yaw := 0.0
	var desired_pitch := 0.0

	if lean_use_yaw:
		## Match sideways sign of peek mode (`dir.x * -lean_sideways`).
		desired_yaw = dir.x * -deg_to_rad(lean_yaw_degrees)
		## forward/up (dir.y < 0) pitches up; backward/down pitches down.
		desired_pitch = (-dir.y) * deg_to_rad(lean_pitch_degrees)
	else:
		desired.x = dir.x * -lean_sideways
		if dir.y < 0.0:
			## forward / up → rise
			desired.y = (-dir.y) * lean_upwards
		elif dir.y > 0.0:
			## backward / down → drop
			desired.y = (-dir.y) * lean_downwards
		## Match sideways peek: roll with the lean (negate lean_roll_degrees in the inspector to flip).
		desired_roll = dir.x * deg_to_rad(lean_roll_degrees)

	var at_rest := (
		desired.length_squared() < 0.0001
		and is_zero_approx(desired_roll)
		and is_zero_approx(desired_yaw)
		and is_zero_approx(desired_pitch)
	)
	var speed := lean_out_speed if at_rest else lean_in_speed
	speed = maxf(speed, 0.01)
	var t := 1.0 - exp(-speed * delta)
	_lean_offset = _lean_offset.lerp(desired, t)
	_lean_roll = lerpf(_lean_roll, desired_roll, t)
	_lean_yaw = lerpf(_lean_yaw, desired_yaw, t)
	_lean_pitch = lerpf(_lean_pitch, desired_pitch, t)
	position = _lean_rest_position + _lean_offset
	rotation.z = _lean_rest_rotation_z + _lean_roll
	rotation.y = _lean_rest_rotation_y + _lean_yaw
	rotation.x = _lean_rest_rotation_x + _lean_pitch


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
	var prev := Vector2i(_grid_aim_row, _grid_aim_column)
	var cell_changed := (not _grid_aim_has_cell) or dest.x != prev.x or dest.y != prev.y
	_grid_aim_row = dest.x
	_grid_aim_column = dest.y
	_grid_aim_has_cell = true
	_grid_aim_moving = true
	_refresh_grid_aim_screen_target()
	if cell_changed:
		_play_grid_aim_step_sfx(screen_dir)


func _setup_grid_aim_step_sfx() -> void:
	var host := get_node_or_null("SFX")
	if host == null:
		host = self
	_grid_aim_sfx_left = host.get_node_or_null("GridAimStepLeft") as AudioStreamPlayer
	if _grid_aim_sfx_left == null:
		_grid_aim_sfx_left = AudioStreamPlayer.new()
		_grid_aim_sfx_left.name = "GridAimStepLeft"
		_grid_aim_sfx_left.stream = preload("res://sfx/Hovercraft_turning_SFX_right_v3.ogg")
		host.add_child(_grid_aim_sfx_left)
	_grid_aim_sfx_right = host.get_node_or_null("GridAimStepRight") as AudioStreamPlayer
	if _grid_aim_sfx_right == null:
		_grid_aim_sfx_right = AudioStreamPlayer.new()
		_grid_aim_sfx_right.name = "GridAimStepRight"
		_grid_aim_sfx_right.stream = preload("res://sfx/Hovercraft_turning_SFX_right_v3.ogg")
		host.add_child(_grid_aim_sfx_right)
	_grid_aim_sfx_stop_timer = host.get_node_or_null("GridAimStepStopTimer") as Timer
	if _grid_aim_sfx_stop_timer == null:
		_grid_aim_sfx_stop_timer = Timer.new()
		_grid_aim_sfx_stop_timer.name = "GridAimStepStopTimer"
		_grid_aim_sfx_stop_timer.one_shot = true
		host.add_child(_grid_aim_sfx_stop_timer)
	if not _grid_aim_sfx_stop_timer.timeout.is_connected(_on_grid_aim_step_sfx_timeout):
		_grid_aim_sfx_stop_timer.timeout.connect(_on_grid_aim_step_sfx_timeout)


func _play_grid_aim_step_sfx(screen_dir: Vector2) -> void:
	var dir := _cardinalize_screen_dir(screen_dir)
	if dir == Vector2.ZERO:
		return
	if _grid_aim_sfx_left == null or _grid_aim_sfx_right == null:
		_setup_grid_aim_step_sfx()
	## Up / left → left sample; down / right → right sample.
	var use_left := dir.x < 0.0 or dir.y < 0.0
	var player := _grid_aim_sfx_left if use_left else _grid_aim_sfx_right
	var other := _grid_aim_sfx_right if use_left else _grid_aim_sfx_left
	if other != null and other.playing:
		other.stop()
	player.volume_db = grid_aim_step_sfx_volume_db
	player.play(0.0)
	if _grid_aim_sfx_stop_timer != null:
		_grid_aim_sfx_stop_timer.stop()
		_grid_aim_sfx_stop_timer.wait_time = maxf(grid_aim_step_sfx_duration, 0.05)
		_grid_aim_sfx_stop_timer.start()


func _on_grid_aim_step_sfx_timeout() -> void:
	if _grid_aim_sfx_left != null and _grid_aim_sfx_left.playing:
		_grid_aim_sfx_left.stop()
	if _grid_aim_sfx_right != null and _grid_aim_sfx_right.playing:
		_grid_aim_sfx_right.stop()


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

	next_row = clampi(next_row, 1, _grid_aim_row_count(rocks))
	var bounds := _grid_aim_column_bounds(rocks)
	next_col = clampi(next_col, bounds.x, bounds.y)
	return Vector2i(next_row, next_col)


func _grid_aim_row_count(rocks: RockManager) -> int:
	var base := rocks.aim_grid_row_count() if rocks.has_method("aim_grid_row_count") else 3
	return base + maxi(grid_aim_extra_rows_down, 0)


func _grid_aim_column_bounds(rocks: RockManager) -> Vector2i:
	var extra := maxi(grid_aim_extra_columns_each_side, 0)
	var col_count := rocks.aim_grid_column_count() if rocks.has_method("aim_grid_column_count") else 8
	var min_c := 1 - extra
	var max_c := col_count + extra
	if grid_aim_side_lanes:
		min_c = mini(min_c, 0)
		max_c = maxi(max_c, col_count + 1)
	return Vector2i(min_c, max_c)


func _grid_aim_extra_row_y(extra_index: int) -> float:
	match extra_index:
		1:
			return grid_aim_extra_row_1_y
		2:
			return grid_aim_extra_row_2_y
		_:
			var step := grid_aim_extra_row_1_y - 0.5
			if extra_index >= 2:
				step = grid_aim_extra_row_2_y - grid_aim_extra_row_1_y
			return grid_aim_extra_row_2_y + step * float(extra_index - 2)


func _nearest_grid_cell(rocks: RockManager, from_screen: Vector2) -> Vector2i:
	var best := Vector2i(2, 4)
	var best_dist := INF
	var row_count := _grid_aim_row_count(rocks)
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


## Instant or tweened screen-space shove (e.g. wall-strike knockback). Clears grid aim lock.
func knock_crosshair_by(screen_delta: Vector2, duration: float = 0.0) -> void:
	if screen_delta.length_squared() < 0.0001:
		return
	if grid_aim_enabled:
		_clear_grid_aim_lock()
	var viewport_size := get_viewport().get_visible_rect().size
	var half_crosshair := (crosshair.size * crosshair.scale) * 0.5
	var start := target_crosshair_position
	var end := start + screen_delta
	end.x = clamp(end.x, half_crosshair.x, viewport_size.x - half_crosshair.x)
	end.y = clamp(end.y, half_crosshair.y, viewport_size.y - half_crosshair.y)

	if _crosshair_knock_tween != null and is_instance_valid(_crosshair_knock_tween):
		_crosshair_knock_tween.kill()
		_crosshair_knock_tween = null

	if duration <= 0.02:
		target_crosshair_position = end
		crosshair.position = end
		crosshair_position = end
		return

	_crosshair_knock_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_crosshair_knock_tween.tween_method(
		_apply_crosshair_knock_pos,
		start,
		end,
		duration
	)


func _apply_crosshair_knock_pos(pos: Vector2) -> void:
	target_crosshair_position = pos
	if crosshair != null:
		crosshair.position = pos
	crosshair_position = pos


func _grid_cell_aim_screen(rocks: RockManager, row: int, column: int) -> Vector2:
	var world := rocks.aim_cell_world_position(row, column)
	var base_rows := rocks.aim_grid_row_count() if rocks.has_method("aim_grid_row_count") else 3
	if row > base_rows:
		world.y = _grid_aim_extra_row_y(row - base_rows)
	var bounds := _grid_aim_column_bounds(rocks)
	if grid_aim_extra_columns_each_side > 0:
		if column == bounds.x:
			world.x = grid_aim_extra_left_x
		elif column == bounds.y:
			world.x = grid_aim_extra_right_x
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
		player_gun.set_weapon_slot(false)
	else:
		player_gun.update_guns()

	#full_power_mode()
	
	player_cash 		= settings.cash
	current_round 		= settings.round
	
	_sync_weapon_bullet_scene()
	weapon_shooting.apply_upgrades()
	_apply_resting_crosshair_size(0.33)
	_refresh_crosshair_weapon_style()
	update_stats_visually()
	## Re-apply place ammo caps (e.g. Glory six-ammo) after travel / shop.
	_sync_ammo_to_max_cap()


func _rebuild_weapon_bases_from_upgrades() -> void:
	var speed := _upgrade_bullet_speed
	var rate := _upgrade_gun_fire_rate
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
	weapon_shooting.set_active_bullet_scene(null)


func _refresh_crosshair_weapon_style() -> void:
	if crosshair and crosshair.has_method("apply_weapon_style"):
		crosshair.apply_weapon_style(false, Color.WHITE)


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
	
	
	var scale_multiplier := _inner_scope_scale_for_radius(get_resting_target_circle())

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


## Resting hit-radius after upgrades × inspector default size scale.
func get_resting_target_circle() -> float:
	return maxf(power_target_circle, 1.0) * crosshair_default_size_scale


func _apply_resting_crosshair_size(tween_dur: float = 0.33) -> void:
	var resting := get_resting_target_circle()
	scope_base_target_circle = resting
	if weapon_shooting:
		weapon_shooting.power_target_circle = resting
	tween_scope(_inner_scope_scale_for_radius(resting), tween_dur)


func _on_scope_shrink_sfx_finished() -> void:
	if _scope_at_min or _scope_at_max:
		return
		
	if _is_holding_shoot and scope_hold_time >= scope_shrink_delay_dur:
		scope_shrink_sfx.play()
		
		
func handle_scope_adjust(delta: float) -> void:
	var shrink_held := false
	var expand_held := false

	if running_on_mobile:
		## Gun2 hold-fire should not drive scope expand via the fire finger.
		if active_gun_loadout == GunLoadout.GUN1:
			shrink_held = mobile_controller.is_fire_held()
	else:
		if active_gun_loadout == GunLoadout.GUN1:
			expand_held = Input.is_action_pressed("shootWeapon")
		if not right_click_is_planted_crosshair:
			shrink_held = Input.is_action_pressed("shoot_weapon_2")

	# Start from upgraded resting values (normal tap-fire).
	var bullet_speed := _base_bullet_speed
	var fire_rate := _base_gun_fire_rate

	if shrink_held and _scope_mode != ScopeMode.EXPAND:
		_update_scope_hold(ScopeMode.SHRINK, delta)
		# Smaller scope = faster fire + faster bullets (lower travel time).
		#bullet_speed = _base_bullet_speed * scope_shrink_bullet_speed_scale
		#fire_rate = _base_gun_fire_rate * scope_shrink_fire_rate_scale

	elif expand_held and _scope_mode != ScopeMode.SHRINK:
		_update_scope_hold(ScopeMode.EXPAND, delta)
		
		
		# Larger scope = slower fire + slower bullets (higher travel time).
		#bullet_speed = _base_bullet_speed * scope_expand_bullet_speed_scale
		#fire_rate = _base_gun_fire_rate * scope_expand_fire_rate_scale

	elif _is_holding_shoot:
		_release_scope_hold()

	_apply_scope_shot_stats(bullet_speed, fire_rate)


## Keep Player + Weapon_shooting in sync. Bullets read weapon_shooting.power_bullet_speed.
func _apply_scope_shot_stats(bullet_speed: float, fire_rate: float) -> void:
	## Gun3 override must stick — the old path always forced 0.05 every frame.
	if _loadout_bullet_speed_override >= 0.0:
		bullet_speed = _loadout_bullet_speed_override
	else:
		bullet_speed = 0.001 #0.05
	if active_gun_loadout == GunLoadout.GUN2:
		fire_rate = 0.05
	elif active_gun_loadout == GunLoadout.GUN3:
		fire_rate = 0.5
	elif active_gun_loadout == GunLoadout.GUN5:
		fire_rate = 0.15
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


## "" / "shrink" / "expand" — only after the hold delay so the mechanic has actually engaged.
func get_scope_mechanic_kind() -> String:
	if scope_hold_time < scope_shrink_delay_dur:
		return ""
	if _scope_mode == ScopeMode.SHRINK:
		return "shrink"
	if _scope_mode == ScopeMode.EXPAND:
		return "expand"
	return ""


func _update_scope_hold(mode: ScopeMode, delta: float) -> void:
	if not _is_holding_shoot or _scope_mode != mode:
		_is_holding_shoot = true
		_scope_mode = mode
		scope_hold_time = 0.0
		scope_base_target_circle = get_resting_target_circle()
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

	## Gun1/2 resting size is upgrade-driven, not a hardcoded scale.
	if active_gun_loadout != GunLoadout.GUN3:
		var resting := get_resting_target_circle()
		scope_base_target_circle = resting
		scope_base_scale = _inner_scope_scale_for_radius(resting)

	var overshoot := maxf(scope_return_overshoot, 1.0)
	var overshoot_scale := scope_base_scale * overshoot
	var overshoot_circle := scope_base_target_circle * overshoot
	var total := maxf(scope_return_duration, 0.05)
	var to_overshoot := total * 0.55
	var to_rest := total * 0.45

	_shrink_return_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shrink_return_tween.tween_interval(0.1)
	_shrink_return_tween.tween_property(%Inner_scope, "scale", Vector2.ONE * overshoot_scale, to_overshoot)
	_shrink_return_tween.parallel().tween_property(weapon_shooting, "power_target_circle", overshoot_circle, to_overshoot)
	_shrink_return_tween.tween_property(%Inner_scope, "scale", Vector2.ONE * scope_base_scale, to_rest).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_shrink_return_tween.parallel().tween_property(weapon_shooting, "power_target_circle", scope_base_target_circle, to_rest).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)



func get_max_ammo() -> int:
	if _level_editor_ammo_active:
		return LEVEL_EDITOR_AMMO_MAX

	var base := int(gl_DataSet.get_value('power_max_ammo', gl_PlayerState.dataset.power_max_ammo))
	## Glory special challenge: magazine capacity is 6 for the whole place.
	if gl_DataSet.has_special_challenge("six_shots_only", String(gl_PlayerState.dataset.level_name)):
		return mini(base, SIX_SHOTS_AMMO_CAP) if base > 0 else SIX_SHOTS_AMMO_CAP
	return base


func get_displayed_ammo() -> int:
	if _level_editor_ammo_active:
		return _level_editor_ammo
	return shot_count


func is_ammo_full() -> bool:
	return get_displayed_ammo() >= get_max_ammo()


func get_starting_ammo() -> int:
	var pack := int(gl_DataSet.get_value("power_ammo", 0))
	if pack <= 0:
		pack = STARTING_AMMO
	return mini(pack, get_max_ammo())


func _init_ammo() -> void:
	max_ammo = get_max_ammo()
	## Shop Play loads the starting pack. Travel / restart / fail leave the mag empty.
	shot_count = 0
	_refresh_ammo_display()


## Clamp loaded ammo when max capacity changes (Glory 6-ammo challenge, etc.).
func _sync_ammo_to_max_cap() -> void:
	if _level_editor_ammo_active:
		return
	max_ammo = get_max_ammo()
	var before := shot_count
	shot_count = clampi(shot_count, 0, max_ammo)
	if shot_count != before:
		_refresh_ammo_display()


func _refresh_ammo_display(animate := false) -> void:
	var shown := get_displayed_ammo()
	var hud := $CanvasLayer/HUD_bottom_corner/AmmoCorner/ShotRemaining
	if hud and hud.has_method('set_ammo'):
		hud.set_ammo(shown, animate)
	else:
		%ShotRemainingLabel.text = str(shown).pad_zeros(2)

	%Crosshair.out_of_ammo_hide()
	_update_low_ammo_warning(shown)


func _update_low_ammo_warning(ammo_amount: int = -1) -> void:
	if ammo_amount < 0:
		ammo_amount = get_displayed_ammo()
	var crosshair := %Crosshair
	if crosshair == null:
		return
	var threshold := 20
	if "low_ammo_threshold" in crosshair:
		threshold = int(crosshair.low_ammo_threshold)
	## Blink LOW AMMO while critically low but not empty (empty uses OUT).
	var show_low := ammo_amount > 0 and ammo_amount < threshold
	if crosshair.has_method("set_low_ammo_warning"):
		crosshair.set_low_ammo_warning(show_low)


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
			out_of_ammo()
		return true

	if shot_count < amount:
		return false

	max_ammo = get_max_ammo()
	shot_count = clampi(shot_count - amount, 0, max_ammo)
	_refresh_ammo_display()

	if shot_count <= 0:
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
	var pack := int(gl_DataSet.get_value('ammo_pack_size', 0))
	if pack <= 0:
		pack = get_starting_ammo()
	return pack


func set_ammo(amount: int, animate := false) -> void:
	if _level_editor_ammo_active:
		return
	max_ammo = get_max_ammo()
	shot_count = clampi(amount, 0, max_ammo)
	_refresh_ammo_display(animate)


func clear_ammo(animate := false) -> void:
	set_ammo(0, animate)


func refill_starting_ammo(animate := true) -> void:
	var before := shot_count
	set_ammo(get_starting_ammo(), false)
	if animate and shot_count != before:
		_refresh_ammo_display(true)


func refill_starting_ammo_animated() -> void:
	max_ammo = get_max_ammo()
	var before := shot_count
	shot_count = get_starting_ammo()
	var hud := $CanvasLayer/HUD_bottom_corner/AmmoCorner/ShotRemaining
	if hud and hud.has_method("await_reload_fill"):
		ensure_ammo_panel_visible()
		await hud.await_reload_fill(before, shot_count)
	else:
		_refresh_ammo_display(true)
		await get_tree().create_timer(0.5, false).timeout


func fire_oranges() -> void:
	var orange_container := get_tree().get_first_node_in_group('orange_container')
	if orange_container and orange_container.has_method("launch_orange"):
		orange_container.launch_orange(_crosshair_world_on_z(23.0))
		%Crosshair.pulse_ring_texture(-1.0, -1.0, shoot_weapon_2_ring_pulse_color)


func fire_weapon_auto(force_plant: bool = false) -> void:
	power_gun_fire_rate = 0.05
	if current_state != State.ACTIVE:
		return
		
	if _is_currently_shooting:
		return
		
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not running_on_mobile:
		return

	if get_displayed_ammo() <= 0 and not debug_infinite_ammo:
		if weapon_shooting.shoot_early_exit_if_aimed():
			player_did_not_miss()
			return
		out_of_ammo()
		weapon_shooting.play_missed_sounds()
		register_accuracy_miss()
		return

	## Glory six-ammo is enforced via get_max_ammo() / magazine, not a separate fire counter.
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("try_register_weapon_shot") and not bool(rm.try_register_weapon_shot()):
		weapon_shooting.play_missed_sounds()
		return

	if force_plant or plant_crosshair_on_fire or active_gun_loadout == GunLoadout.GUN4:
		if not debug_infinite_ammo and not consume_ammo(1):
			out_of_ammo()
			#weapon_shooting.play_missed_sounds()
			register_accuracy_miss()
			return
		if not %Crosshair.plant_crosshair_trap(planted_crosshair_arm_delay):
			#weapon_shooting.play_missed_sounds()
			return
		player_did_not_miss()
		return

	weapon_shooting.shoot_target()
	player_did_not_miss()
	if shoot_ring_pulse_on_release:
		%Crosshair.pulse_ring_texture()

func fire_weapon(force_plant: bool = false) -> void:

	if current_state != State.ACTIVE:
		return
		
	if _is_currently_shooting:
		weapon_shooting.play_missed_sounds()
		#penalize_early_fire()
		return
		
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not running_on_mobile:
		return

	if get_displayed_ammo() <= 0 and not debug_infinite_ammo:
		if weapon_shooting.shoot_early_exit_if_aimed():
			player_did_not_miss()
			return
		out_of_ammo()
		weapon_shooting.play_missed_sounds()
		register_accuracy_miss()
		return

	## Glory six-ammo is enforced via get_max_ammo() / magazine, not a separate fire counter.
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("try_register_weapon_shot") and not bool(rm.try_register_weapon_shot()):
		weapon_shooting.play_missed_sounds()
		return

	if force_plant or plant_crosshair_on_fire or active_gun_loadout == GunLoadout.GUN4:
		if not debug_infinite_ammo and not consume_ammo(1):
			out_of_ammo()
			weapon_shooting.play_missed_sounds()
			register_accuracy_miss()
			return
		if not %Crosshair.plant_crosshair_trap(planted_crosshair_arm_delay):
			weapon_shooting.play_missed_sounds()
			return
		player_did_not_miss()
		return

	_apply_active_gun_shot_stats()
	weapon_shooting.shoot_target()

	
	player_did_not_miss()
	if shoot_ring_pulse_on_release:
		%Crosshair.pulse_ring_texture()
	

func out_of_ammo() -> void:
	%Crosshair.set_low_ammo_warning(false)
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

	if ctrl_swap_guns and InputMap.has_action("ctrl") and event.is_action_pressed("ctrl", false):
		_cycle_gun_loadout()
	
	if !running_on_mobile and event is InputEventMouseMotion:
		# Resolution-independent look: same screen-fraction motion on any monitor.
		if grid_aim_enabled:
			_clear_grid_aim_lock()
		var look := GameSettings.mouse_look_delta(event.relative)
		if drunken_affect_enabled:
			look *= drunken_input_scale
		target_crosshair_position += look


## Procedural wobble + sway + drift for drunken aim (screen pixels).
func _update_drunken_offset(delta: float) -> Vector2:
	_drunken_time += delta
	var t := _drunken_time

	var wobble := Vector2(
		sin(t * TAU * drunken_wobble_speed) * drunken_wobble_amp,
		cos(t * TAU * drunken_wobble_speed * 1.37 + 1.1) * drunken_wobble_amp * 0.85
	)
	var sway := Vector2(
		sin(t * TAU * drunken_sway_speed) * drunken_sway_amp,
		sin(t * TAU * drunken_sway_speed_y + 0.8) * drunken_sway_amp * 0.75
	)

	_drunken_drift_retarget_left -= delta
	if _drunken_drift_retarget_left <= 0.0:
		_drunken_drift_retarget_left = randf_range(0.45, 1.1)
		var amp := maxf(drunken_drift_amp, 0.0)
		_drunken_drift_target = Vector2(
			randf_range(-amp, amp),
			randf_range(-amp, amp)
		)
	var drift_lerp := 1.0 - exp(-maxf(drunken_drift_speed, 0.01) * delta)
	_drunken_drift = _drunken_drift.lerp(_drunken_drift_target, drift_lerp)

	var offset := wobble + sway + _drunken_drift
	## Hard cap so cranked exports cannot flip the gun look_at behind the camera.
	const MAX_OFFSET_PX := 18.0
	if offset.length() > MAX_OFFSET_PX:
		offset = offset.normalized() * MAX_OFFSET_PX
	return offset


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
	## Fresh round starts on the chosen starting loadout.
	active_gun_loadout = starting_gun_loadout
	_loadout_bullet_speed_override = -1.0
	_apply_gun_crosshair_visibility()
	_apply_gun_loadout_stats(false)
	if _level_editor_ammo_active:
		end_level_editor_ammo()
	max_ammo = get_max_ammo()
	shot_count = clampi(shot_count, 0, max_ammo)
	_is_currently_shooting = false
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


## Hold shootWeapon → camera FOV ease (see PlayerCamera Hold Aim Zoom exports).
func _update_hold_aim_zoom() -> void:
	if camera_3d == null or not camera_3d.has_method("set_hold_aim_pressed"):
		return
	var held := false
	if current_state == State.ACTIVE and active_gun_loadout == GunLoadout.GUN1:
		if running_on_mobile:
			held = mobile_controller.is_fire_held()
		else:
			held = Input.is_action_pressed("shootWeapon")
	camera_3d.set_hold_aim_pressed(held)

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
	_kill_ammo_hud_tween()
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud:
		hud.modulate.a = 0.0
		hud.show()
	if ammo:
		ammo.modulate.a = 0.0
		ammo.show()
	_ammo_hud_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if hud:
		_ammo_hud_tween.tween_property(hud, "modulate:a", 1.0, 0.45)
	if ammo:
		if hud:
			_ammo_hud_tween.parallel().tween_property(ammo, "modulate:a", 1.0, 0.45)
		else:
			_ammo_hud_tween.tween_property(ammo, "modulate:a", 1.0, 0.45)


func fade_out_ammo_panel(duration: float = 0.33) -> void:
	_kill_ammo_hud_tween()
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud == null and ammo == null:
		return
	if hud and (not hud.visible or hud.modulate.a <= 0.01) and (ammo == null or not ammo.visible or ammo.modulate.a <= 0.01):
		hide_ammo_panel_instant()
		return
	if hud:
		hud.show()
	if ammo:
		ammo.show()
	_ammo_hud_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if hud:
		_ammo_hud_tween.tween_property(hud, "modulate:a", 0.0, duration)
	if ammo:
		if hud:
			_ammo_hud_tween.parallel().tween_property(ammo, "modulate:a", 0.0, duration)
		else:
			_ammo_hud_tween.tween_property(ammo, "modulate:a", 0.0, duration)
	_ammo_hud_tween.tween_callback(hide_ammo_panel_instant)


func hide_ammo_panel_instant() -> void:
	_kill_ammo_hud_tween()
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
	_kill_ammo_hud_tween()
	var hud := get_node_or_null("%HUD_bottom_corner") as CanvasItem
	var ammo := get_node_or_null("CanvasLayer/HUD_bottom_corner/AmmoCorner") as CanvasItem
	if hud:
		hud.show()
		hud.modulate.a = 1.0
	if ammo:
		ammo.show()
		ammo.modulate.a = 1.0


func _kill_ammo_hud_tween() -> void:
	if _ammo_hud_tween and _ammo_hud_tween.is_valid():
		_ammo_hud_tween.kill()
	_ammo_hud_tween = null
	
	
	
func gun_stats() -> void:
	## Do not touch scope_base_scale — resting size comes from upgrades via
	## `_apply_resting_crosshair_size()`. Forcing 1.0 here made every shot
	## snap the reticle too small on release.
	power_gun_fire_rate = 0.1
	#_loadout_bullet_speed_override = -1.0
	weapon_shooting.power_bullet_speed = 0.1

	if weapon_shooting:
		weapon_shooting.power_bullet_delay = 0.1


func gun_2_stats() -> void:
	## Rapid-fire hold gun — same travel as default; fire rate matches fire_weapon_auto.
	power_gun_fire_rate = 0.05
	_loadout_bullet_speed_override = -1.0
	if weapon_shooting:
		weapon_shooting.power_bullet_delay = 0.1


func gun_3_stats() -> void:
	power_gun_fire_rate = 0.15
	scope_base_scale = 2.0
	_loadout_bullet_speed_override = gun3_bullet_travel_sec
	power_bullet_speed = gun3_bullet_travel_sec
	if weapon_shooting:
		weapon_shooting.power_bullet_delay = 0.1
		weapon_shooting.power_bullet_speed = gun3_bullet_travel_sec


func gun_4_stats() -> void:
	## Plant-trap gun — same resting scope / fire cadence as gun1; shoot plants a trap.
	power_gun_fire_rate = 0.1
	_loadout_bullet_speed_override = -1.0
	if weapon_shooting:
		weapon_shooting.power_bullet_delay = 0.1


func gun_5_stats() -> void:
	## Timed lead shot — bullet travel matches the prediction window.
	power_gun_fire_rate = 0.15
	var travel := maxf(gun5_timed_shot_sec, 0.05)
	_loadout_bullet_speed_override = travel
	power_bullet_speed = travel
	if weapon_shooting:
		weapon_shooting.power_bullet_delay = 0.1
		weapon_shooting.power_bullet_speed = travel


func _apply_active_gun_shot_stats() -> void:
	match active_gun_loadout:
		GunLoadout.GUN2:
			gun_2_stats()
		GunLoadout.GUN3:
			gun_3_stats()
		GunLoadout.GUN4:
			gun_4_stats()
		GunLoadout.GUN5:
			gun_5_stats()
		_:
			gun_stats()


func _cycle_gun_loadout() -> void:
	var next_id := int(active_gun_loadout) + 1
	if next_id > int(GunLoadout.GUN5):
		next_id = int(GunLoadout.GUN1)
	switch_gun_loadout(next_id)


## Script command `gun1` … `gun5`: dip the mesh, swap HUD, raise with new stats.
func switch_gun_loadout(gun_id: int) -> void:
	var next: GunLoadout = GunLoadout.GUN1
	match clampi(gun_id, 1, 5):
		2:
			next = GunLoadout.GUN2
		3:
			next = GunLoadout.GUN3
		4:
			next = GunLoadout.GUN4
		5:
			next = GunLoadout.GUN5
		_:
			next = GunLoadout.GUN1
	if next == active_gun_loadout:
		_apply_gun_crosshair_visibility()
		_apply_gun_loadout_stats(false)
		return

	_gun_swap_token += 1
	var token := _gun_swap_token
	if player_gun and player_gun.has_method("end_position"):
		player_gun.end_position()
	await get_tree().create_timer(0.5, false).timeout
	if token != _gun_swap_token:
		return

	active_gun_loadout = next
	if _is_holding_shoot:
		_release_scope_hold()
	_apply_gun_crosshair_visibility()
	_apply_gun_loadout_stats(true)

	if player_gun and player_gun.has_method("start_position"):
		player_gun.start_position()


func _apply_gun_crosshair_visibility() -> void:
	var ch := %Crosshair if has_node("%Crosshair") else get_node_or_null("CanvasLayer/Crosshair")
	if ch == null:
		return
	var rossy := ch.get_node_or_null("Rossy") as CanvasItem
	var gun2 := ch.get_node_or_null("Gun2") as CanvasItem
	var gun3 := ch.get_node_or_null("Gun3") as CanvasItem
	var gun4 := ch.get_node_or_null("Gun4") as CanvasItem
	var gun5 := ch.get_node_or_null("Gun5") as CanvasItem
	if rossy:
		## Gun5 reuses Rossy until a dedicated Gun5 HUD art exists.
		rossy.visible = active_gun_loadout == GunLoadout.GUN1 or (active_gun_loadout == GunLoadout.GUN5 and gun5 == null)
	if gun2:
		gun2.visible = active_gun_loadout == GunLoadout.GUN2
	if gun3:
		gun3.visible = active_gun_loadout == GunLoadout.GUN3
	if gun4:
		gun4.visible = active_gun_loadout == GunLoadout.GUN4
	if gun5:
		gun5.visible = active_gun_loadout == GunLoadout.GUN5


func _apply_gun_loadout_stats(animate_scope: bool) -> void:
	match active_gun_loadout:
		GunLoadout.GUN2:
			gun_2_stats()
			if animate_scope:
				_apply_resting_crosshair_size(0.25)
		GunLoadout.GUN3:
			gun_3_stats()
			if animate_scope:
				tween_scope(scope_base_scale, 0.35)
			elif %Inner_scope:
				%Inner_scope.scale = Vector2.ONE * scope_base_scale
		GunLoadout.GUN4:
			gun_4_stats()
			if animate_scope:
				_apply_resting_crosshair_size(0.25)
		GunLoadout.GUN5:
			gun_5_stats()
			if animate_scope:
				_apply_resting_crosshair_size(0.25)
		_:
			gun_stats()
			if animate_scope:
				_apply_resting_crosshair_size(0.25)
	_apply_scope_shot_stats(_base_bullet_speed, power_gun_fire_rate)
