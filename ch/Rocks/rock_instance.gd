extends RigidBody3D
class_name RockInstance

@onready var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
var _rocks_sfx: Node = null

@export var freeze_mine := false
## Keep RigidBody torque/spin; visually aim mesh +Y along travel velocity.
@export var mesh_face_velocity := true
## Min speed before the mesh starts tracking travel direction.
@export_range(0.01, 2.0, 0.01) var mesh_face_velocity_min_speed := 0.15
## Alt-gun freeze burst: how far the ice pulse reaches from the rock you shot.
@export var freeze_burst_radius := 4.0
## How long rocks stay frozen after being caught in the burst.
@export var freeze_burst_duration := 1.0
## Visual size of the freeze pulse (Explosion_area scale).
@export var freeze_burst_visual_scale := 3.0
var sky_mine_blast_radius := 5.0 #15.0

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
var start_exploding := false
var pitch_adjustment := 0.02
var _freeze_shot_pending := false

var rock_type := 0

var current_particles : GPUParticles3D = null

const ROCK_01 = preload('uid://c2pmyrm3e4ty5')
const ROCK_02 = preload('uid://84ianb3xwjp7')
const ROCK_03 = preload('uid://lxbrgqaovv68')
const AIM_BONUS_SFX = preload('uid://d2xxjh7ysnnfr')



const ROCK_MESHES = [
	ROCK_01,
	ROCK_02,
	ROCK_03,

]

enum RockSize {
	SMALL,
	SMALL_2,
	MEDIUM,
	LARGE,
	HAZARD,
	HUGE,
	HAZARD_SMALL,
	RED_ROCK_ERROR,
	SMOKECAN,
	## Homing hazard: steers toward the crosshair; reticle overlap = explode + strike.
	AVOIDER,
	## Flees the crosshair; must stay in scope for `chaser_lock_time_sec` before it can be shot.
	CHASER,
	## Independent tank rock: health 100; ignored by wait-clear / splash miss / OOB strike.
	JUGGLE,
	## $1 rock: counts toward wave clear, but missing it does not strike.
	GREY,
	## Flees the reticle and bounces in the playfield. Bonus cash on destroy. Not compulsory.
	MOTHERSHIP,
	CRATE,
	## Flies straight to aim rapidly, brakes, then hangs (pace-* ignored).
	STAY,
	## Like avoider launch, but at apex locks crosshair and dashes straight at that point.
	RED_ATTACKER,
}

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}

var current_state : State = State.INACTIVE
var _pool_setup_token := 0

var rock_has_been_logged := false

@onready var money_label_3d: Label3D = $Money_Label3D

@onready var main_col: CollisionShape3D = $main_col
@onready var mesh_container: Node3D = %Mesh

@onready var small_rock: MeshInstance3D = %small_rock
@onready var clay_pigeon: MeshInstance3D = %clay_pigeon
@onready var grey_rock: MeshInstance3D = %grey_rock

@onready var medium_rock: MeshInstance3D = %medium_rock
@onready var large_rock: MeshInstance3D = %Large_rock

@onready var red_rock: MeshInstance3D = %Red_rock
@onready var red_rock_attack: MeshInstance3D = %Red_rock_attack
@onready var blue_rock: MeshInstance3D = %blue_rock
@onready var smokecan: MeshInstance3D = %Smokecan
@onready var crate: MeshInstance3D = get_node_or_null("%Crate")

@onready var hazard_large: MeshInstance3D = %Hazard_large
@onready var rock_red_attack_mode: GPUParticles3D = get_node_or_null("rock_red_attack_mode") as GPUParticles3D

@onready var current_mesh: MeshInstance3D = small_rock
## Scene-file visual materials so grey/mothership tints never wipe yellow rocks.
var _mesh_original_overrides: Dictionary = {}


var hit_torque_strength := 5.0
var max_health : int = 0
var tween_sight_icon : Tween = null 

var cash_value := 0
var current_cash_multiplier := 1
## Aim-hold bonus on basic rocks: extra $ stacked while reticle overlaps (paid only on shoot).
var _aim_bonus_extra := 0
var _aim_bonus_hold_accum := 0.0
var _aim_bonus_off_timer := 0.0
var _aim_bonus_mesh_base_scale := Vector3.ONE
var _aim_bonus_scale_tween: Tween
var rock_activated := false

var force_mult : Array = [3,4]
var force_mult_index := 0

var rock_type_gravity_scale := 0.4
var cash_per_hit := 0
var health := 0

var is_deactivated := false
var rock_destroyed := true
var player_has_marked_rock := false
var start_pos : Vector3
var target_x_position : float = 0.0


var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false
## Aimed rocks: damp-free ascent, then `aim_descent_linear_damp` once past the apex.
var ballistic_aim_active := false
var _ballistic_descent_damp := 0.5
var _ballistic_in_descent := false
## When true, camera out-of-bounds does not count as a miss (e.g. smokecan fly-off).
var ignores_x_out_of_bounds := false
## Direct player shot already applied the black-rock strike (don't strike again on explode).
var _hazard_strike_from_direct_shot := false
## Set by RockManager once this rock has been inside the camera viewport.
## Off-screen spawns won't miss until they've entered play at least once.
var has_entered_camera_view := false
## Bumps to cancel a pending airborne rock–rock collision schedule.
var _airborne_collision_token := 0

@export_group("Hazard / Black Rock")
## When true, destroying a black hazard that releases smoke blurs the player camera.
@export var hazard_smoke_blurs_camera := true
## Local fallback only. The Player scene "Crosshair Destroy On Overlap / Hazards" flag is the live toggle.
@export var hazard_strike_on_crosshair_overlap := false
## Delay after launch before crosshair overlap can strike (avoids instant spawn kills).
@export_range(0.0, 3.0, 0.05) var hazard_crosshair_arm_delay_sec := 0.45
## Set when an orange neutralized this black rock (blow-away or instant explode).
## Prevents strikes and hazard fail particles on the follow-up destroy.
var _orange_neutralized_hazard := false
var _hazard_crosshair_armed := false
var _hazard_crosshair_arm_token := 0

@export_group("Aim Hold Bonus (Basic Rock)")
## While the crosshair overlaps a basic rock, add this much cash every interval (paid only if shot).
@export var aim_bonus_enabled := true
@export_range(0.1, 5.0, 0.05) var aim_bonus_interval_sec := 1.0
@export var aim_bonus_cash_per_tick := 1
## Brief leave without pausing the hold timer (seconds).
@export_range(0.0, 1.0, 0.05) var aim_bonus_leave_grace_sec := 0.35
@export var aim_bonus_torque := 650.0
@export_range(1.0, 1.5, 0.01) var aim_bonus_scale_punch := 1.14
@export_range(0.05, 0.5, 0.01) var aim_bonus_scale_punch_sec := 0.12
@export var aim_bonus_sfx_volume_db := -18.0

@export_group("Orbit 360 Bonus")
## Master switch: circle the crosshair fully around an active rock to earn cash + "360!" label.
@export var orbit_bonus_enabled := true
## Inspector readout — true while this rock is currently tracking a circle around it.
@export var orbit_bonus_tracking := false
@export var orbit_bonus_cash := 1
## Max screen-px from rock center for the orbit to count (rock radius is added on top).
@export_range(40.0, 500.0, 1.0) var orbit_bonus_outer_px := 160.0
## Min screen-px from rock center (ignore dead-center sitting).
@export_range(0.0, 120.0, 1.0) var orbit_bonus_inner_px := 12.0
## Radians of travel needed (TAU = one full loop).
@export_range(1.0, 12.57, 0.01) var orbit_bonus_required_radians := TAU

var _orbit_last_angle := 0.0
var _orbit_accum := 0.0

@export_group("Destroy On Crosshair Overlap (Basic Rock)")
## Local fallback only. The Player scene "Crosshair Destroy On Overlap / Rocks" flag is the live toggle.
@export var destroy_on_crosshair_overlap := false
## Delay after launch before overlap can destroy (avoids instant spawn pops).
@export_range(0.0, 3.0, 0.05) var destroy_on_crosshair_arm_delay_sec := 0.15

var _destroy_on_crosshair_armed := false
var _destroy_on_crosshair_arm_token := 0

@export_group("rock-stay settings")
## Cruise speed toward the aim cell (world units / sec). Pace-* does not affect this.
@export_range(4.0, 80.0, 0.5) var rock_stay_speed := 32.0
## How quickly velocity is pulled down while braking (units / sec²). Higher = snappier stop.
@export_range(4.0, 200.0, 1.0) var rock_stay_brake := 55.0
## Start decelerating when this close to the aim point.
@export_range(0.25, 10.0, 0.05) var rock_stay_brake_distance := 2.75
## Snap / hang when within this radius of the aim point.
@export_range(0.02, 1.0, 0.01) var rock_stay_lock_radius := 0.12
## When true, rock-stay self-destructs after `rock_stay_lifetime_sec` (no cash).
@export var rock_stay_self_destruct := true
## Seconds after launch before an unshot rock-stay pops with $0.
@export_range(0.5, 30.0, 0.1) var rock_stay_lifetime_sec := 3.0
## When true, lifetime expire counts as a miss strike.
@export var rock_stay_expire_gives_strike := false
## Seconds before expire when the mesh starts shaking / swelling.
@export_range(0.15, 5.0, 0.05) var rock_stay_burst_warn_sec := 1.0
## Scale multiplier reached at the end of the burst warn (1 = no grow).
@export_range(1.0, 2.5, 0.05) var rock_stay_burst_grow := 1.4
## World-unit shake amplitude at the end of the warn (ramps up from ~0).
@export_range(0.01, 0.5, 0.01) var rock_stay_burst_shake := 0.14
## Launch spin impulse so it keeps tumbling while hanging.
@export var rock_stay_spin_torque := 1200.0
## Near-zero damp so the launch torque keeps spinning.
@export_range(0.0, 2.0, 0.01) var rock_stay_angular_damp := 0.05

## Soft hang at aim after rock-stay brakes (like orange apex lock).
var _stay_flight_active := false
var _stay_locked := false
var _stay_target := Vector3.ZERO
var _stay_life_token := 0
var _stay_burst_warning := false
var _stay_burst_warn_elapsed := 0.0
var _stay_burst_warn_duration := 1.0
var _stay_mesh_base_scale := Vector3.ONE
var _stay_mesh_base_pos := Vector3.ZERO

# --- Rock Avoider (rock-avoider) ---------------------------------------------
@export_group("Rock Avoider")
## How hard the avoider steers toward the crosshair (X/Y only).
@export var avoider_seek_accel := 22.0
## Caps horizontal/vertical chase speed so it stays readable.
@export var avoider_max_speed_xy := 16.0
## Delay after launch before seeking / overlap checks (avoids instant spawn kills).
@export var avoider_arm_delay_sec := 0.45
## How long the avoider keeps chasing its last aim point before sampling the crosshair again.
## 0 = track every frame (old behaviour). Raise for a delayed / laggy retarget.
@export var avoider_retarget_delay_sec := 0.35
## How long the avoider stays alive before it explodes on its own (no strike).
@export var avoider_lifetime_sec := 4.0
## If true, avoider + rock both explode on contact. If false, only the other rock blows up.
@export var avoider_explodes_when_hitting_rock := false
## If true, two avoiders destroy each other on contact. If false, they pass through each other.
@export var avoider_explodes_when_hitting_avoider := false
## If true, avoider is culled when leaving camera bounds or hitting the splash zone.
## If false, it keeps flying; StaticBody3D / rock contacts still explode as above.
@export var avoider_destroys_on_out_of_bounds := true
## Lock avoiders to this world Z so they share a collision plane with other rocks.
@export var avoider_lock_z := 23.0
var _avoider_plane_z := 23.0
var _avoider_armed := false
var _avoider_arm_token := 0
var _avoider_life_token := 0
var _avoider_seek_xy := Vector2.ZERO
var _avoider_has_seek_target := false
var _avoider_retarget_timer := 0.0
var _avoider_humming := false

# --- Rock Red Attacker (rock-red-attacker) -----------------------------------
@export_group("Rock Red Attacker")
## Min time after launch before apex-lock can fire (0 = as soon as apex).
@export_range(0.0, 3.0, 0.05) var red_attacker_arm_delay_sec := 0.0
## Extra pause after apex (lock crosshair + VFX) before the dash starts.
@export_range(0.0, 2.0, 0.05) var red_attacker_apex_wait_sec := 0.12
## Straight-line dash top speed (world units / sec).
@export_range(8.0, 120.0, 0.5) var red_attacker_dash_speed := 58.0
## Seconds to accelerate from 0 up to `red_attacker_dash_speed` (0 = instant).
@export_range(0.0, 3.0, 0.05) var red_attacker_dash_ramp_sec := 0.45
## Self-destruct if still alive this long after going ACTIVE (no strike).
@export_range(0.5, 12.0, 0.1) var red_attacker_lifetime_sec := 3.0
## RocksSFXManager child name played when it locks and dashes.
@export var red_attacker_lock_sfx := "rock_marked_sfx"
var _red_attacker_armed := false
var _red_attacker_dashing := false
var _red_attacker_locking := false
var _red_attacker_saw_ascent := false
var _red_attacker_arm_token := 0
var _red_attacker_life_token := 0
var _red_attacker_dash_target := Vector3.ZERO
var _red_attacker_dash_dir := Vector3(0.0, -1.0, 0.0)
var _red_attacker_dash_speed_current := 0.0

# --- Rock Chaser (rock-chaser) -----------------------------------------------
@export_group("Rock Chaser")
@export var chaser_flee_accel := 22.0
@export var chaser_max_speed_xy := 16.0
@export var chaser_arm_delay_sec := 0.35
## How long the reticle must stay on the chaser before it becomes shootable.
@export var chaser_lock_time_sec := 2.0
## Padding inside the column 1–8 / row A–C play rectangle.
@export var chaser_bounds_padding := 0.35
## Gravity while dodging (near 0 keeps it in the lane band).
@export var chaser_float_gravity := 0.04
## One-shot spin impulse when the chaser locks (ready to shoot).
@export var chaser_lock_torque := 18.0
var _chaser_armed := false
var _chaser_arm_token := 0
var _chaser_lock_progress := 0.0
var _chaser_locked := false
var _chaser_saved_gravity := 0.12
var _chaser_lock_pos := Vector3.ZERO
var _chaser_lock_spin_applied := false


func _ready() -> void:
	_cache_mesh_original_overrides()
	start_pos = global_position
	target_x_position = start_pos.x
	# Own a unique physics material so bounce tweaks never leak across pooled rocks.
	if physics_material_override != null:
		physics_material_override = physics_material_override.duplicate()
	else:
		physics_material_override = PhysicsMaterial.new()

	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_rock_body_entered):
		body_entered.connect(_on_rock_body_entered)
	
	await get_tree().create_timer(0.2, false).timeout
	
	#EventBus.instance.all_rocks_destroyed.connect(hazard_disappear)
	enter_state(State.INACTIVE)


func begin_ballistic_aim_feel(descent_damp: float = 0.5) -> void:
	ballistic_aim_active = true
	_ballistic_descent_damp = descent_damp
	_ballistic_in_descent = false
	linear_damp = 0.0


## rock-stay: fly straight at `aim_pos`, brake, then hang (no fall / pace ignored).
func begin_rock_stay_flight(aim_pos: Vector3) -> void:
	_stay_flight_active = true
	_stay_locked = false
	_stay_target = aim_pos
	ballistic_aim_active = false
	_ballistic_in_descent = false
	falling = false
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = rock_stay_angular_damp
	constant_force = Vector3.ZERO
	var from := global_position
	var to_target := aim_pos - from
	var dist := to_target.length()
	var dir := to_target / maxf(dist, 0.001)
	var cruise := maxf(rock_stay_speed, 1.0)
	linear_velocity = dir * cruise
	## Continuous tumble while hanging / in flight.
	apply_torque_impulse(Vector3.FORWARD * rock_stay_spin_torque)
	_start_rock_stay_lifetime()


func _update_rock_stay(delta: float) -> void:
	if not _stay_flight_active or rock_destroyed or _freeze_shot_pending:
		return
	_update_rock_stay_burst_warn(delta)
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = rock_stay_angular_damp
	constant_force = Vector3.ZERO

	if _stay_locked:
		global_position = _stay_target
		linear_velocity = Vector3.ZERO
		## Keep spinning — do not zero angular_velocity.
		return

	var to_target := _stay_target - global_position
	var dist := to_target.length()
	var lock_r := maxf(rock_stay_lock_radius, 0.02)
	if dist <= lock_r:
		_lock_rock_stay()
		return

	var dir := to_target / maxf(dist, 0.001)
	var cruise := maxf(rock_stay_speed, 1.0)
	var brake_dist := maxf(rock_stay_brake_distance, lock_r * 2.0)
	var desired_speed := cruise
	if dist < brake_dist:
		desired_speed = cruise * clampf(dist / brake_dist, 0.0, 1.0)
	var desired_vel := dir * desired_speed
	var brake := maxf(rock_stay_brake, 1.0)
	linear_velocity = linear_velocity.move_toward(desired_vel, brake * delta)
	## Kill stray depth drift so it settles on the aim plane.
	if absf(linear_velocity.z) > 0.01 and absf(_stay_target.z - global_position.z) < 0.05:
		linear_velocity.z = move_toward(linear_velocity.z, 0.0, brake * delta)

	if dist <= lock_r * 2.0 and linear_velocity.length() < cruise * 0.08:
		_lock_rock_stay()


func _lock_rock_stay() -> void:
	_stay_locked = true
	global_position = _stay_target
	linear_velocity = Vector3.ZERO
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = rock_stay_angular_damp
	falling = false


func _clear_rock_stay() -> void:
	_stay_flight_active = false
	_stay_locked = false
	_stay_target = Vector3.ZERO
	_stay_life_token += 1
	_stop_rock_stay_burst_warn(true)


func _start_rock_stay_lifetime() -> void:
	_stay_life_token += 1
	if not rock_stay_self_destruct:
		return
	var token := _stay_life_token
	var lifetime := maxf(rock_stay_lifetime_sec, 0.1)
	var warn_dur := clampf(rock_stay_burst_warn_sec, 0.0, lifetime)
	var cruise := lifetime - warn_dur
	if cruise > 0.0:
		await get_tree().create_timer(cruise, false).timeout
		if token != _stay_life_token:
			return
		if current_state != State.ACTIVE or rock_type != RockSize.STAY:
			return
		if not rock_activated or rock_destroyed:
			return
	_begin_rock_stay_burst_warn(warn_dur)
	if warn_dur > 0.0:
		await get_tree().create_timer(warn_dur, false).timeout
		if token != _stay_life_token:
			return
		if current_state != State.ACTIVE or rock_type != RockSize.STAY:
			return
		if not rock_activated or rock_destroyed:
			return
	_expire_rock_stay_lifetime()


func _begin_rock_stay_burst_warn(duration: float) -> void:
	_stop_rock_stay_burst_warn(false)
	if duration <= 0.0 or current_mesh == null:
		return
	_stay_burst_warning = true
	_stay_burst_warn_elapsed = 0.0
	_stay_burst_warn_duration = duration
	_stay_mesh_base_scale = current_mesh.scale
	_stay_mesh_base_pos = current_mesh.position


func _stop_rock_stay_burst_warn(reset_mesh: bool) -> void:
	_stay_burst_warning = false
	_stay_burst_warn_elapsed = 0.0
	if reset_mesh and current_mesh != null and is_instance_valid(current_mesh):
		current_mesh.position = _stay_mesh_base_pos
		## Leave scale alone if we already swelled — expire shrinks $Mesh parent.


func _update_rock_stay_burst_warn(delta: float) -> void:
	if not _stay_burst_warning or current_mesh == null:
		return
	_stay_burst_warn_elapsed += delta
	var t := clampf(_stay_burst_warn_elapsed / maxf(_stay_burst_warn_duration, 0.001), 0.0, 1.0)
	## Ease-in so it swells harder near the pop.
	var ease_t := t * t
	var grow := maxf(rock_stay_burst_grow, 1.0)
	current_mesh.scale = _stay_mesh_base_scale.lerp(_stay_mesh_base_scale * grow, ease_t)
	var amp := lerpf(0.015, maxf(rock_stay_burst_shake, 0.01), ease_t)
	current_mesh.position = _stay_mesh_base_pos + Vector3(
		randf_range(-amp, amp),
		randf_range(-amp, amp),
		randf_range(-amp * 0.35, amp * 0.35)
	)


## Timed out without a shot — destroy smoke + hit sfx, no cash.
## Optional strike via `rock_stay_expire_gives_strike`.
func _expire_rock_stay_lifetime() -> void:
	if rock_type != RockSize.STAY:
		return
	if current_state != State.ACTIVE or not rock_activated or rock_destroyed:
		return

	_clear_rock_stay()
	rock_activated = false
	rock_destroyed = true
	cash_value = 0
	_aim_bonus_extra = 0

	var rm := _find_rock_manager()
	if rm and rm.has_method("notify_clearable_destroyed"):
		rm.notify_clearable_destroyed()

	if not rock_has_been_logged:
		rock_has_been_logged = true
		gl_PlayerState.log_hit(rock_type_name, current_rock_type, 0, global_position)

	remove_from_group("Target")
	disable_collision()
	if current_particles != null:
		current_particles.emitting = false
	var red := get_node_or_null("%RedParticles") as GPUParticles3D
	if red:
		red.emitting = false

	smoke_particles()
	_play_rocks_sfx("rock_hit_sound")

	if rock_stay_expire_gives_strike:
		_set_strike_feedback_origin_here()
		gl_PlayerState.add_strike()

	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.12)
	await tween.finished
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


func _physics_process(delta: float) -> void:
	if current_state == State.ACTIVE and rock_activated:
		_update_orbit_bonus(delta)
		_update_mesh_face_velocity()
		if rock_type == RockSize.STAY:
			_update_rock_stay(delta)
			_update_destroy_on_crosshair_overlap()
		elif rock_type == RockSize.AVOIDER:
			## Always pin depth so collisions stay on the rock plane.
			linear_velocity.z = 0.0
			global_position.z = _avoider_plane_z
			_update_rock_stay_burst_warn(delta)
			if not _freeze_shot_pending:
				_check_threat_crosshair()
				_update_avoider(delta)
		elif rock_type == RockSize.RED_ATTACKER:
			linear_velocity.z = 0.0
			global_position.z = _avoider_plane_z
			if not _freeze_shot_pending:
				_check_threat_crosshair()
				_update_red_attacker(delta)
		elif rock_type == RockSize.CHASER:
			if not _freeze_shot_pending:
				_update_chaser(delta)
		elif rock_type == RockSize.MOTHERSHIP:
			linear_velocity.z = 0.0
			global_position.z = _avoider_plane_z
			if not _freeze_shot_pending:
				_update_mothership(delta)
		elif rock_type == RockSize.SMALL or rock_type == RockSize.GREY:
			if rock_type == RockSize.SMALL:
				_update_aim_hold_bonus(delta)
			_update_destroy_on_crosshair_overlap()
		elif rock_type == RockSize.HAZARD or rock_type == RockSize.HAZARD_SMALL:
			_update_hazard_crosshair_overlap()

	if not ballistic_aim_active or _ballistic_in_descent:
		return
	if current_state != State.ACTIVE:
		return
	if linear_velocity.y > 0.0:
		return
	_ballistic_in_descent = true
	linear_damp = _ballistic_descent_damp


## Point mesh local +Y along travel; RigidBody can keep spinning underneath.
func _update_mesh_face_velocity() -> void:
	if not mesh_face_velocity:
		return
	if mesh_container == null or not is_instance_valid(mesh_container):
		return
	if not mesh_container.visible:
		return
	var speed_sq := linear_velocity.length_squared()
	var min_sp := mesh_face_velocity_min_speed
	if speed_sq < min_sp * min_sp:
		return
	var forward := linear_velocity.normalized()
	## Rotate so mesh +Y maps onto travel direction.
	var q := Quaternion(Vector3.UP, forward)
	var kept_scale := mesh_container.scale
	mesh_container.global_basis = Basis(q)
	mesh_container.scale = kept_scale


func enter_state(new_state : State) -> void:

	current_state = new_state
	
	
	match new_state:
		State.INACTIVE:
			update_inactive()
			
		State.PREPARE_ROCK:
			update_prepare_rock()
			
		State.ACTIVE:
			update_active()

		State.MISSED:
			update_missed()
		
		State.HIT:
			update_hit()
			
		State.DISABLED:
			update_disabled()

		
			

func update_inactive() -> void:
	hide_all_meshes()
	force_mult.shuffle()
	disable_collision()
	reset_stats()
	# EventBus.instance.rock_created.emit()
	
func update_prepare_rock() -> void:
	var token := _pool_setup_token
	reset_stats()
	if token != _pool_setup_token:
		return
	await get_tree().process_frame
	if token != _pool_setup_token or current_state != State.PREPARE_ROCK:
		return
	hide_all_meshes()
	force_mult.shuffle()
	await get_tree().process_frame
	if token != _pool_setup_token or current_state != State.PREPARE_ROCK:
		return
	setup_rock_type()
	# Hazards / smokecans / avoiders / juggle are obstacles — not required to clear the round.
	if (
		rock_type_name != 'hazard_type_1'
		and rock_type != RockSize.SMOKECAN
		and rock_type != RockSize.AVOIDER
		and rock_type != RockSize.RED_ATTACKER
		and rock_type != RockSize.JUGGLE
		and rock_type != RockSize.MOTHERSHIP
	):
		gl_PlayerState.log_rocks(1, rock_type_name)
		
	await get_tree().create_timer(0.2, false).timeout
	if token != _pool_setup_token or current_state != State.PREPARE_ROCK:
		return
	global_position.x = target_x_position
	
func update_active() -> void:
	if rock_type != RockSize.SMALL_2:
		constant_force.x = 0.01
	
	if  rock_type == RockSize.SMOKECAN:
		constant_force.x = 0.5
	elif rock_type == RockSize.AVOIDER:
		constant_force.x = 1.5
		rotation_degrees = Vector3.ZERO
	elif rock_type == RockSize.RED_ATTACKER:
		constant_force.x = 1.5
		rotation_degrees = Vector3.ZERO
	elif rock_type == RockSize.CHASER:
		constant_force.x = 1.5
		rotation_degrees = Vector3.ZERO
	elif rock_type == RockSize.STAY:
		constant_force = Vector3.ZERO
		rotation_degrees = Vector3.ZERO
		gravity_scale = 0.0
		linear_damp = 0.0
		angular_damp = rock_stay_angular_damp
		falling = false
	else:
		constant_force.x = 0.01
		rotation_degrees = Vector3.ZERO
		apply_torque_impulse(Vector3.LEFT * 1500)
		
	enable_collision()
	add_to_rocks_round()
	if rock_type == RockSize.AVOIDER:
		_avoider_plane_z = avoider_lock_z
		global_position.z = _avoider_plane_z
		linear_velocity.z = 0.0
		_set_threat_fire(false)
		_arm_avoider()
		_start_avoider_lifetime()
		_sync_avoider_collision_exceptions()
	elif rock_type == RockSize.RED_ATTACKER:
		_avoider_plane_z = avoider_lock_z
		global_position.z = _avoider_plane_z
		linear_velocity.z = 0.0
		_set_red_attack_mesh_particles(true)
		_set_threat_fire(false)
		_arm_red_attacker()
		_start_red_attacker_lifetime()
		_sync_avoider_collision_exceptions()
	elif rock_type == RockSize.CHASER:
		_arm_chaser()
	elif rock_type == RockSize.MOTHERSHIP:
		_avoider_plane_z = avoider_lock_z
		global_position.z = _avoider_plane_z
		linear_velocity.z = 0.0
		gravity_scale = 0.0
		_arm_mothership()
	elif rock_type == RockSize.HAZARD or rock_type == RockSize.HAZARD_SMALL:
		if _player_wants_overlap_destroy("hazards"):
			_arm_hazard_crosshair()
	elif rock_type == RockSize.SMALL or rock_type == RockSize.GREY or rock_type == RockSize.STAY:
		if _player_wants_overlap_destroy("rocks"):
			_arm_destroy_on_crosshair()
	
	#%rock_launch_sound.pitch_scale = randf_range(3.0,3.2)
	_play_rocks_sfx("rock_launch_sound")
	



func update_hit() -> void:
	var token := _pool_setup_token
	update_gravity(1.0)
	#linear_velocity = Vector3.ZERO
	gravity_scale = 0.0
	await get_tree().create_timer(1.0, false).timeout
	if token != _pool_setup_token or current_state != State.HIT:
		return
	disable_collision()
	

func update_missed() -> void:
	disable_collision()
	remove_from_group('Target')
	rock_destroyed = true
	reset_stats()
	release_to_pool()

func round_end_check_rock_status() -> void:
	
	match current_state:
		State.HIT:
			pass
			
		State.MISSED:
			pass
			
		State.INACTIVE:
			pass
			
		State.ACTIVE:
			# Black hazards / smokecans / avoiders should keep falling or orange-drift motion
			# across wave clears; only normal rocks get parked as DISABLED.
			if (
				rock_type == RockSize.HAZARD
				or rock_type == RockSize.HAZARD_SMALL
				or rock_type == RockSize.SMOKECAN
				or rock_type == RockSize.AVOIDER
				or rock_type == RockSize.RED_ATTACKER
			):
				pass
			else:
				enter_state(State.DISABLED)
			
		State.PREPARE_ROCK:
			pass
			
		State.DISABLED:
			pass
			
		_:
			print("We are in some other state rock instance ", current_state)


func update_disabled() -> void:
	update_gravity(1.0)
	# Keep layer 1 for remaining interactions, but stop rock–rock bounce while parked.
	_cancel_airborne_rock_collisions()
	#await get_tree().create_timer(2.0).timeout
	#disable_collision()
	#remove_from_group('Target')



func disable_collision() -> void:
	_cancel_airborne_rock_collisions()
	set_collision_layer_value(1, false)
	$Explosion_area.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true

func enable_collision() -> void:
	# Layer 1 only — rock–rock mask stays off until schedule_airborne_rock_collisions().
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, false)


## After launch settles: allow this rock to collide / bounce with other airborne rocks.
## Safe to call during pulse — delay keeps dormant launch stacking from shoving neighbors.
func schedule_airborne_rock_collisions(delay_sec: float, bounce: float) -> void:
	_airborne_collision_token += 1
	var token := _airborne_collision_token
	set_collision_mask_value(1, false)

	if delay_sec <= 0.0:
		if current_state == State.ACTIVE and rock_activated:
			_enable_airborne_rock_collisions(bounce)
		return

	get_tree().create_timer(delay_sec).timeout.connect(
		func () -> void:
			if token != _airborne_collision_token:
				return
			if current_state != State.ACTIVE or not rock_activated:
				return
			_enable_airborne_rock_collisions(bounce),
		CONNECT_ONE_SHOT
	)


func _enable_airborne_rock_collisions(bounce: float) -> void:
	set_collision_mask_value(1, true)
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = clampf(bounce, 0.0, 1.0)
	if rock_type == RockSize.AVOIDER or rock_type == RockSize.RED_ATTACKER:
		_sync_avoider_collision_exceptions()


func _cancel_airborne_rock_collisions() -> void:
	_airborne_collision_token += 1
	set_collision_mask_value(1, false)
	if physics_material_override != null:
		physics_material_override.bounce = 0.0


func update_gravity(_gravity_scale : float) -> void:
	for i in range(3):
		#gravity_scale = _gravity_scale
		gravity_scale = 0.15
		#linear_damp = 0.0
		await get_tree().create_timer(0.1, false).timeout
	
	if rock_activated:
		await get_tree().create_timer(1.5, false).timeout
		linear_damp = 0.0

func _visual_meshes() -> Array:
	return [small_rock, grey_rock, clay_pigeon, medium_rock, large_rock, hazard_large, red_rock, red_rock_attack, blue_rock, smokecan, crate]


func _cache_mesh_original_overrides() -> void:
	if not _mesh_original_overrides.is_empty():
		return
	for mesh in _visual_meshes():
		if mesh == null:
			continue
		_mesh_original_overrides[mesh] = mesh.material_override


func hide_all_meshes() -> void:
	_cache_mesh_original_overrides()
	for mesh in _visual_meshes():
		if mesh == null:
			continue
		mesh.visible = false
		if _mesh_original_overrides.has(mesh):
			mesh.material_override = _mesh_original_overrides[mesh]




func reset_rock_back_on() -> void:
	enter_state(State.MISSED)


func _tint_mesh(color: Color) -> void:
	if current_mesh == null:
		return
	_cache_mesh_original_overrides()
	var src = _mesh_original_overrides.get(current_mesh)
	if src is BaseMaterial3D:
		var tinted: BaseMaterial3D = src.duplicate()
		tinted.albedo_color = color
		current_mesh.material_override = tinted
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.metallic = 0.08
	current_mesh.material_override = mat


func setup_rock_type() -> void:
	current_mesh.scale = Vector3.ONE
	
	angular_damp = 1.0
	force_mult.clear()
	force_mult_index = 0
	linear_damp = 0.5
	$Mesh.scale = Vector3.ONE
	
	$Mesh/Crate/CrateAnimplayer.stop()
	
	match rock_type:
		# 0
		RockSize.SMALL:
			# Base values

			current_rock_type 	= "Small Rock"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.2 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1

			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			small_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)

			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
			
			current_particles = $Mesh/small_rock/GoldParticles
			current_particles.amount += 1
			current_particles.amount -= 1
			current_particles.emitting = true
			_reset_aim_hold_bonus()
			_aim_bonus_mesh_base_scale = current_mesh.scale

		
		
		RockSize.SMALL_2:
			current_rock_type 	= "Pigeon"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			#var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			var size_multiplier_float : float = 1.4 #randf_range (1.2, 1.35) * 2
			#var size_multiplier_int : int = 2
		
			health = 1 #base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			clay_pigeon.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = clay_pigeon
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
		
			current_particles = $Mesh/clay_pigeon/GoldParticles
			current_particles.amount += 1
			current_particles.amount -= 1
			current_particles.emitting = true
	
		
		# Rock Type 4
		RockSize.HAZARD:
			var size_multiplier_float : float = 1.0
			var base_scale  := Vector3.ONE * 0.35
			current_rock_type 	= "Game Ender"
			rock_type_name 		= "hazard_type_1"
			health 				= int(gl_DataSet.get_value("hazard_type_1", 1))
			cash_value 			= int(gl_DataSet.get_value("hazard_type_1", 0))
		
			hazard_large.visible = true
			current_mesh.scale = base_scale * size_multiplier_float
			main_col.scale = Vector3.ONE * 0.2 #* size_multiplier_float

			current_mesh 		= hazard_large
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.625
			max_health = health
			rock_type_gravity_scale = 0.1

			
		RockSize.HAZARD_SMALL:
			current_rock_type 	= "Hazard Large"
			rock_type_name		= "hazard_type_1"
			health 				= int(gl_DataSet.get_value("hazard_type_1", 1))
			#cash_value 			= int(gl_DataSet.get_value("hazard_type_1", 0))
			cash_value 			= int(gl_PlayerState.dataset.cash / 8)
			hazard_large.visible = true
			main_col.scale = Vector3.ONE * 0.75
			current_mesh 		= hazard_large
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 1.5 #* 0.399
			max_health = health
			rock_type_gravity_scale = 0.1
			gl_PlayerState.log_hazard()
			linear_damp = 1.0

			
			
			
		RockSize.RED_ROCK_ERROR:
			# Base values
			current_rock_type 	= "Red Rock"
			rock_type_name 		= "rock_type_9"
			gl_PlayerState.log_white_rock()
			var base_health :=  int(gl_DataSet.get_value("rock_type_9", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_9", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.2 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1

			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			red_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 2.5 # + (size_multiplier / 10)
			linear_damp = 1.5
			force_mult.clear()
			force_mult = [0, 1]
			force_mult_index = 0
			
		
		RockSize.SMOKECAN:
			# Base values — obstacle only; does not count toward round progress (like HAZARD).
			current_rock_type 	= "Smokecan"
			rock_type_name 		= "rock_type_8"
			var base_health := int(gl_DataSet.get_value("rock_type_8", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_8", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.5 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1
			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			smokecan.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = smokecan
			#assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 2.5 # + (size_multiplier / 10)
			linear_damp = 1.5
			force_mult.clear()
			force_mult = [0, 1]
			force_mult_index = 0

		RockSize.AVOIDER:
			# Homing hazard — chase the reticle; contact = strike. Not a clearable rock.
			current_rock_type = "Rock Avoider"
			rock_type_name = "rock_type_avoider"
			var avoider_scale := Vector3.ONE * 0.35
			var avoider_size := 1.8

			health = 1
			cash_value = 0
			max_health = health
			red_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125 * avoider_size * 1.5
			current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = avoider_scale * avoider_size
			rock_type_gravity_scale = 0.12
			linear_damp = 0.35
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			current_particles = $Mesh/Red_rock/GoldParticles if $Mesh/Red_rock.has_node("GoldParticles") else null
			if current_particles:
				current_particles.emitting = true
			_avoider_armed = false
			_avoider_has_seek_target = false
			_avoider_retarget_timer = 0.0
			_avoider_plane_z = avoider_lock_z
			global_position.z = _avoider_plane_z
			_set_threat_fire(false)

		RockSize.CHASER:
			current_rock_type = "Rock Chaser"
			rock_type_name = "rock_type_chaser"
			gl_PlayerState.log_white_rock()
			var chaser_scale := Vector3.ONE * 0.35
			var chaser_size := 1.35
			health = 1
			cash_value = 0
			max_health = health
			if blue_rock:
				blue_rock.visible = true
				current_mesh = blue_rock
			else:
				red_rock.visible = true
				current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = chaser_scale * chaser_size
			main_col.scale = Vector3.ONE * 0.125 * chaser_size
			rock_type_gravity_scale = 0.12
			linear_damp = 0.35
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			_chaser_armed = false
			_chaser_lock_progress = 0.0
			_chaser_locked = false
			if blue_rock and blue_rock.has_node("RedParticles"):
				current_particles = blue_rock.get_node("RedParticles")
				current_particles.emitting = true

		RockSize.JUGGLE:
			## High-HP rock that does not block wait-until-clear or count as a splash/OOB miss.
			current_rock_type = "Rock Juggle"
			rock_type_name = "rock_type_juggle"
			var juggle_scale := Vector3.ONE * 0.45
			var juggle_size := 1.6
			health = 400
			cash_value = 0
			max_health = health
			if medium_rock:
				medium_rock.visible = true
				current_mesh = medium_rock
			else:
				small_rock.visible = true
				current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = juggle_scale * juggle_size
			main_col.scale = Vector3.ONE * 0.125 * juggle_size
			rock_type_gravity_scale = 0.12
			linear_damp = 0.4
			force_mult.clear()
			force_mult = [6, 8]
			force_mult_index = 0
			ignores_x_out_of_bounds = true
			if current_mesh.has_node("GoldParticles"):
				current_particles = current_mesh.get_node("GoldParticles")
				current_particles.emitting = true
	
		RockSize.CRATE:
			current_rock_type = "Crate"
			rock_type_name = "rock_type_crate"
			gl_PlayerState.log_white_rock()
			var crate_scale := Vector3.ONE * 0.5
			var crate_size := 1.2
			health = 3
			## Award this range's script `reward $N` (not rock_type_crate dataset cash).
			cash_value = _crate_range_reward_amount()
			max_health = health
			if crate:
				crate.visible = true
				current_mesh = crate
			else:
				small_rock.visible = true
				current_mesh = small_rock
			current_mesh.scale = crate_scale * crate_size
			main_col.scale = Vector3.ONE * 0.125 * crate_size
			rock_type_gravity_scale = 0.1
			force_mult.clear()
			force_mult = [12]
			angular_damp = 3.0
			force_mult_index = 0
			if has_node("Mesh/Crate/CrateAnimplayer"):
				$Mesh/Crate/CrateAnimplayer.play("flashing_dollar")

		RockSize.STAY:
			## Hang at aim after a fast straight approach. Pace commands do not affect flight.
			current_rock_type = "Rock Stay"
			rock_type_name = "rock_type_stay"
			gl_PlayerState.log_white_rock()
			var stay_health := int(gl_DataSet.get_value("rock_type_stay", 1))
			var stay_cash := int(gl_DataSet.get_value("rock_type_stay", 0))
			health = maxi(stay_health, 1)
			cash_value = stay_cash
			max_health = health
			small_rock.visible = true
			current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = Vector3.ONE * 0.42
			main_col.scale = Vector3.ONE * 0.125 * 1.2
			rock_type_gravity_scale = 0.0
			gravity_scale = 0.0
			linear_damp = 0.0
			angular_damp = rock_stay_angular_damp
			force_mult.clear()
			force_mult = [4]
			force_mult_index = 0
			if current_mesh.has_node("GoldParticles"):
				current_particles = current_mesh.get_node("GoldParticles")
				current_particles.emitting = true
				
		RockSize.GREY:
			current_rock_type = "Grey Rock"
			rock_type_name = "rock_type_grey"
			var grey_health := int(gl_DataSet.get_value("rock_type_grey", 1))
			var grey_cash := int(gl_DataSet.get_value("rock_type_grey", 0))
			health = maxi(grey_health, 1)
			cash_value = grey_cash
			max_health = health
			if grey_rock:
				grey_rock.visible = true
				current_mesh = grey_rock
			else:
				small_rock.visible = true
				current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = Vector3.ONE * randf_range(0.42, 0.6)
			main_col.scale = Vector3.ONE * 0.125 * 1.2
			rock_type_gravity_scale = 0.1
			force_mult.clear()
			force_mult = [5]
			force_mult_index = 0

		RockSize.RED_ATTACKER:
			## Launch like avoider; at apex lock crosshair and dash straight at it.
			current_rock_type = "Rock Red Attacker"
			rock_type_name = "rock_type_red_attacker"
			var atk_scale := Vector3.ONE * 0.35
			var atk_size := 1.8
			health = 1
			cash_value = 0
			max_health = health
			if red_rock_attack:
				red_rock_attack.visible = true
				current_mesh = red_rock_attack
			else:
				red_rock.visible = true
				current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = atk_scale * atk_size
			main_col.scale = Vector3.ONE * 0.125 * atk_size * 1.5
			rock_type_gravity_scale = 0.12
			linear_damp = 0.35
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			_red_attacker_armed = false
			_red_attacker_dashing = false
			_red_attacker_locking = false
			_red_attacker_saw_ascent = false
			_red_attacker_dash_speed_current = 0.0
			_avoider_plane_z = avoider_lock_z
			global_position.z = _avoider_plane_z
			_set_red_attack_mesh_particles(false)
			_set_threat_fire(false)

		RockSize.MOTHERSHIP:
			current_rock_type = "Mothership"
			rock_type_name = "mothership_reward"
			health = maxi(int(gl_DataSet.get_value("mothership_reward", 1)), 1)
			cash_value = int(gl_DataSet.get_value("mothership_reward", 0))
			max_health = health
			if large_rock:
				large_rock.visible = true
				current_mesh = large_rock
			elif medium_rock:
				medium_rock.visible = true
				current_mesh = medium_rock
			else:
				small_rock.visible = true
				current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = Vector3.ONE * 0.7
			main_col.scale = Vector3.ONE * 0.22
			rock_type_gravity_scale = 0.0
			gravity_scale = 0.0
			linear_damp = 0.2
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			ignores_x_out_of_bounds = true
			if current_mesh.has_node("GoldParticles"):
				current_particles = current_mesh.get_node("GoldParticles")
				current_particles.emitting = true
			_tint_mesh(Color(0.62, 0.42, 0.18))

func reset_stats() -> void:
	var token := _pool_setup_token
	ignores_x_out_of_bounds = false
	_hazard_strike_from_direct_shot = false
	_orange_neutralized_hazard = false
	_hazard_crosshair_armed = false
	_hazard_crosshair_arm_token += 1
	_destroy_on_crosshair_armed = false
	_destroy_on_crosshair_arm_token += 1
	has_entered_camera_view = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1
	_avoider_has_seek_target = false
	_avoider_retarget_timer = 0.0
	_set_avoider_hum(false)
	_set_threat_fire(false)
	_set_marked_embers(false)
	_red_attacker_armed = false
	_red_attacker_dashing = false
	_red_attacker_locking = false
	_red_attacker_arm_token += 1
	_red_attacker_life_token += 1
	_chaser_armed = false
	_chaser_arm_token += 1
	_chaser_lock_progress = 0.0
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	_stay_life_token += 1
	can_sleep = true
	$Mesh.scale = Vector3.ONE
	$Mesh.position = Vector3.ZERO
	$Mesh.rotation = Vector3.ZERO
	$Marked.hide()
	$Freeze.hide()
	$Mesh.hide()
	start_exploding = false
	
	await get_tree().process_frame
	if token != _pool_setup_token:
		return

	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = small_rock
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = 0
	_reset_aim_hold_bonus()
	_reset_orbit_bonus()
	linear_damp = 0.5
	rock_has_been_logged = false
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	falling = false
	rock_destroyed = false
	player_has_marked_rock = false
	is_deactivated = false
	ballistic_aim_active = false
	_ballistic_in_descent = false
	_freeze_shot_pending = false
	_clear_rock_stay()
	_cancel_airborne_rock_collisions()
	global_position = start_pos
	await get_tree().process_frame
	if token != _pool_setup_token:
		return
	
	$Mesh.show()


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	if rock_type == RockSize.CRATE:
		tween.tween_callback(crate_particles)
	else:
		tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished


## Return this instance to the 36-rock pool so a later spawn can reuse it.
func release_to_pool() -> void:
	if current_state == State.INACTIVE:
		return
	_pool_setup_token += 1
	disable_collision()
	remove_from_group("Target")
	rock_activated = false
	rock_destroyed = true
	_set_avoider_hum(false)
	_cancel_airborne_rock_collisions()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if has_node("Mesh"):
		$Mesh.scale = Vector3.ONE
	enter_state(State.INACTIVE)
	global_position = start_pos


## Claim an inactive pool rock for a later launch without the async PREPARE wait.
func setup_for_pool_launch(new_type: int, spawn_x: float, spawn_y: float = -INF, spawn_z: float = -INF) -> void:
	_pool_setup_token += 1
	disable_collision()
	remove_from_group("Target")
	rock_activated = false
	rock_destroyed = false
	rock_has_been_logged = false
	is_deactivated = false
	has_entered_camera_view = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gravity_scale = rock_type_gravity_scale
	if has_node("Mesh"):
		$Mesh.scale = Vector3.ONE
		$Mesh.position = Vector3.ZERO
		$Mesh.rotation = Vector3.ZERO
	rock_type = new_type
	target_x_position = spawn_x
	hide_all_meshes()
	setup_rock_type()
	if (
		rock_type_name != 'hazard_type_1'
		and rock_type != RockSize.SMOKECAN
		and rock_type != RockSize.AVOIDER
		and rock_type != RockSize.RED_ATTACKER
	):
		gl_PlayerState.log_rocks(1, rock_type_name)
	var y := start_pos.y if spawn_y == -INF else spawn_y
	var z := start_pos.z if spawn_z == -INF else spawn_z
	global_position = Vector3(spawn_x, y, z)
	current_state = State.PREPARE_ROCK

	
func detonate_rock() -> void:
	start_destroyed_process()
	expand_blast_radius()

	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_sky_mine"):
		player_cam.shake_camera_sky_mine()


## Alt-gun hit: pulse a small freeze radius; every rock inside gets iced.
func apply_freeze_shot_effect(damage: int = 1, screen_offset: Vector2 = Vector2.ZERO) -> void:
	if rock_destroyed or not rock_activated:
		return

	if rock_type_name.contains("hazard_type"):
		health -= 1
	else:
		health -= damage

	play_hit_sfx()
	apply_hit_reaction(screen_offset)

	var should_destroy := health <= 0
	release_freeze_burst()

	if should_destroy:
		await get_tree().create_timer(freeze_burst_duration, false).timeout
		if is_instance_valid(self) and not rock_destroyed and rock_activated:
			start_destroyed_process()


## Small AOE ice pulse from this rock. Caught rocks (including avoiders) call apply_aoe_freeze().
func release_freeze_burst() -> void:
	_play_freeze_burst_visual()
	_play_rocks_sfx("Freeze_sfx")

	var origin := global_position
	var radius_sq := freeze_burst_radius * freeze_burst_radius
	# Prefer Target group, but also sweep RockInstance siblings so avoiders always count.
	var candidates: Array = get_tree().get_nodes_in_group("Target")
	var parent_rocks := get_parent()
	if parent_rocks:
		for child in parent_rocks.get_children():
			if child is RockInstance and child not in candidates:
				candidates.append(child)

	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is RockInstance):
			continue
		var rock := node as RockInstance
		if rock.global_position.distance_squared_to(origin) > radius_sq:
			continue
		rock.apply_aoe_freeze(freeze_burst_duration)


## Freeze this rock in place for duration, then thaw.
## Avoiders / chasers also stop seeking while iced.
func apply_aoe_freeze(duration: float = 1.0) -> void:
	if _freeze_shot_pending or rock_destroyed or not rock_activated:
		return
	if current_state != State.ACTIVE:
		return

	_freeze_shot_pending = true
	if has_node("Freeze"):
		$Freeze.show()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = true

	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Pause avoider / rock-stay lifetime so it can't expire mid-freeze.
	if rock_type == RockSize.AVOIDER:
		_avoider_life_token += 1
		_set_avoider_hum(false)
	elif rock_type == RockSize.RED_ATTACKER:
		_red_attacker_life_token += 1
		_red_attacker_arm_token += 1
	elif rock_type == RockSize.STAY:
		_stay_life_token += 1
		_stop_rock_stay_burst_warn(true)
		if current_mesh != null and is_instance_valid(current_mesh):
			current_mesh.scale = _stay_mesh_base_scale
			current_mesh.position = _stay_mesh_base_pos

	await get_tree().create_timer(duration, false).timeout

	if not is_instance_valid(self):
		return
	_freeze_shot_pending = false
	freeze = false
	if has_node("Freeze"):
		$Freeze.hide()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = false

	# Resume avoider / rock-stay lifetime after thaw.
	if rock_type == RockSize.AVOIDER and rock_activated and current_state == State.ACTIVE:
		_start_avoider_lifetime()
		if _avoider_armed:
			_set_avoider_hum(true)
	elif rock_type == RockSize.RED_ATTACKER and rock_activated and current_state == State.ACTIVE:
		_start_red_attacker_lifetime()
		_arm_red_attacker()
	elif rock_type == RockSize.STAY and rock_activated and current_state == State.ACTIVE:
		_start_rock_stay_lifetime()


func _play_freeze_burst_visual() -> void:
	if not has_node("Explosion_area"):
		return
	var blast_node: Area3D = $Explosion_area
	# Visual only — freeze is applied via distance check, not body_entered.
	blast_node.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	blast_node.show()
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(blast_node, "scale", Vector3.ONE * freeze_burst_visual_scale, 0.28)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.28)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		blast_node.scale = Vector3.ONE
		blast_node.hide()
		%explosion_radius_mesh.transparency = 0.0
		%explosion_radius_mesh.hide()
	)


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam == null:
		return
	match rock_type:
		RockSize.STAY:
			if player_cam.has_method("shake_camera_rock_stay"):
				player_cam.shake_camera_rock_stay()
		RockSize.GREY:
			if player_cam.has_method("shake_camera_rock_grey"):
				player_cam.shake_camera_rock_grey()
		RockSize.AVOIDER:
			if player_cam.has_method("shake_camera_rock_avoider"):
				player_cam.shake_camera_rock_avoider()
		RockSize.RED_ATTACKER:
			if player_cam.has_method("shake_camera_rock_red_attacker"):
				player_cam.shake_camera_rock_red_attacker()
		RockSize.HAZARD, RockSize.HAZARD_SMALL:
			if player_cam.has_method("shake_camera_rock_hazard"):
				player_cam.shake_camera_rock_hazard()
		RockSize.CRATE:
			if player_cam.has_method("shake_camera_rock_crate"):
				player_cam.shake_camera_rock_crate()
		RockSize.SMOKECAN:
			if player_cam.has_method("shake_camera_rock_smokecan"):
				player_cam.shake_camera_rock_smokecan()
		RockSize.CHASER:
			if player_cam.has_method("shake_camera_rock_chaser"):
				player_cam.shake_camera_rock_chaser()
		RockSize.MOTHERSHIP:
			if player_cam.has_method("shake_camera_rock_mothership"):
				player_cam.shake_camera_rock_mothership()
		RockSize.JUGGLE:
			if player_cam.has_method("shake_camera_rock_juggle"):
				player_cam.shake_camera_rock_juggle()
		RockSize.SMALL_2:
			if player_cam.has_method("shake_camera_rock_pigeon"):
				player_cam.shake_camera_rock_pigeon()
		_:
			if player_cam.has_method("shake_camera_rock"):
				player_cam.shake_camera_rock()

func apply_marked_ability() -> void:
	#if player_has_marked_rock:
		#return
	
	player_has_marked_rock = true
	#freeze = true
	apply_slow_linear_damp()
	
	if freeze_mine:
		$Freeze.show()
		$freeze_embers.emitting = true
	
	else:
		$Marked.show()
		$marked_embers.emitting = true
	
	
	
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.remove_sky_mine()

	
	
	await get_tree().create_timer(0.15, false).timeout
	_play_rocks_sfx("rock_marked_sfx")
	
	
	await get_tree().create_timer(1.0, false).timeout
	detonate_rock()
	
	
func apply_slow_linear_damp() -> void:
	var torque_dir := Vector3(
		500.0,
		1.0,
		-500.0
	).normalized()

	apply_torque_impulse(
		torque_dir * hit_torque_strength
	)
	
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_interval(0.2)
	tween.tween_property(self, "linear_damp", 18.0, 0.15).as_relative()
	tween.parallel().tween_property(self, "angular_damp", 18.0, 0.15).as_relative()
	
func apply_hit_reaction(screen_offset: Vector2, accurate_direction := true) -> void:
	_clear_rock_stay()
	#
	#gravity_scale = 0.1
	linear_damp = 1.3
	linear_velocity = Vector3.ZERO
	
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var force_dir := get_hit_force_direction(
		camera,
		screen_offset,
		accurate_direction
	)

	if force_mult_index >= force_mult.size() - 1:
		force_mult_index = 0
	else:
		force_mult_index += 1

	apply_central_impulse(force_dir * force_mult[force_mult_index])

	# Spin the rock
	var torque_dir := Vector3(
		force_dir.z,
		1.0,
		-force_dir.x
	).normalized()

	apply_torque_impulse(
		torque_dir * force_mult[force_mult_index] * hit_torque_strength
	)

	if rock_type != RockSize.CRATE:
		smoke_particles_duplicates()


func get_hit_force_direction(
	camera: Camera3D,
	screen_offset: Vector2,
	accurate_direction: bool
) -> Vector3:

	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y

	var force_dir := right * screen_offset.x
	force_dir += up * -screen_offset.y

	if !accurate_direction:
		# Remove downward movement while still allowing upward movement.
		var vertical := force_dir.dot(up)

		if vertical < 0.0:
			force_dir -= up * vertical

	return force_dir.normalized()


	
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO, freeze_shot := false) -> void:	
	
	#freeze_mine = true

	# Avoiders / red-attackers: unarmed or frozen shots destroy them with no strike.
	# Once they enter attack mode, a shot or reticle overlap is a hazard strike.
	if rock_type == RockSize.AVOIDER or rock_type == RockSize.RED_ATTACKER:
		if _freeze_shot_pending or not _is_threat_hazardous():
			_destroy_pre_arm_threat()
			return
		_trigger_avoider_crosshair_contact()
		return

	# Chaser must be locked (held in scope) before shots count.
	if rock_type == RockSize.CHASER and not _chaser_locked:
		return

	## Alt weapon: release a freeze burst — nearby rocks ice up.
	if freeze_shot:
		await apply_freeze_shot_effect(damage, screen_offset)
		return
	
	if rock_type_name.contains("hazard_type"):
		health -= 1
		
	else:
		health -= damage
		#if damage == 0:
			#cash_value += 10
			#health += 10
			#var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			#tween.tween_property(
				#current_mesh, "scale", current_mesh.scale * 1.1, 0.08)
		

	
	
	#Rock Takes Damage But Is Not Destroyed Process
	#if gl_PlayerState.dataset.power_sky_mine > 0:
	if player_has_marked_rock:
		if gl_PlayerState.dataset.total_hazards > 0:
			gl_PlayerState.dataset.total_hazards = 0
			rock_type_name = 'rock_type_4'
		apply_marked_ability()
		play_hit_sfx()
		return

	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)

		#%explosion_radius_mesh.hide()
		return
	
	
	if rock_type == RockSize.SMOKECAN:
		apply_torque_impulse(Vector3.BACK * 100.0)
		play_hit_sfx()
		#%rock_launch_sound.play()
		_play_rocks_sfx("rock_flicker_sfx")
		_play_rocks_sfx("launched_into_distance_3d", 0.25)
		fly_off_into_distance()
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property($Mesh, "position:y", 0.5, 0.5)
		return
		
	#Rock Destroyed Process
	
	if rock_type == RockSize.HAZARD or rock_type == RockSize.HAZARD_SMALL:
		## Strike immediately on a direct shot — don't wait for the explode delay.
		_apply_direct_hazard_strike()

	if rock_type == RockSize.HAZARD:
		$Marked.show()
		#$marked_embers.emitting = true
		_play_rocks_sfx("rock_marked_sfx")
		apply_slow_linear_damp()
		await get_tree().create_timer(1.5, false).timeout
	
	
	start_destroyed_process()
	
	
	
func fly_off_into_distance() -> void:
	ignores_x_out_of_bounds = true
	
	var strength : float = 4.0 # [4.0].pick_random()
	var x_direction := 0.0
	var player := get_tree().get_first_node_in_group('Player')
	
	if !player:
		apply_central_impulse(Vector3(x_direction,-0.0,35) * strength)

	else:
		#strength = 4.0
		var dir : Vector3= self.global_position - player.global_position.normalized()
		dir.y /= 3
		apply_central_impulse(dir * strength)
	
	
	
func add_to_rocks_round() -> void:
	play_piano_note()
	# Avoiders punish reticle overlap — keep them out of the shootable Target group.
	# Chasers join Target only after the lock timer completes.
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.CHASER:
		add_to_group('Target')
	%explosion_radius_mesh.hide()

	# Hazards can never be gold

	rock_activated = true

	$Start_falling_timer.start(2.2)


func bounce_rocks() -> void:
	linear_damp = 0.5
	update_gravity(0.04)
	#apply_torque_impulse(Vector3.LEFT * 3000.0)



func start_destroyed_process() -> void:

	if !rock_activated:
		return
	if rock_destroyed:
		return

	_clear_rock_stay()
	_shutdown_threat_fx()
	%RedParticles.emitting = false
	rock_activated = false
	var rm := _find_rock_manager()
	if rm and rm.has_method("notify_clearable_destroyed"):
		rm.notify_clearable_destroyed()
	
	if current_particles != null:
		current_particles.emitting = false

	
	#if player_has_marked_rock == false:
	expand_blast_radius()
	enter_state(State.HIT)
	var destroyed_as_hazard := rock_type == RockSize.HAZARD or rock_type == RockSize.HAZARD_SMALL
	
	if rock_type == RockSize.SMALL || rock_type == RockSize.STAY:
		_play_rocks_sfx("rock_flicker_sfx")
		_play_rocks_pitch_shift()

	
	# This is to score bonus cash for shooting rocks beneath the Cash Zones / ZoneA, ZoneB
	#if rock_type != RockSize.HAZARD:
		#var bonus_cash_reward := 0
		#var bonus_zones := get_tree().get_first_node_in_group('multi_shot')
		#if bonus_zones:
			#bonus_cash_reward = bonus_zones.check_if_within_zone(global_position.y)
			
		#cash_value += bonus_cash_reward
		

	
	
	if rock_type == RockSize.CRATE:
		cash_value = _crate_range_reward_amount()

	if !rock_has_been_logged:
		rock_has_been_logged = true

		gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value, global_position)
			
	
	remove_from_group('Target')
	
	play_destroy_sfx()
	$Marked.hide()
	if has_node("Freeze"):
		$Freeze.hide()

	if rock_type == RockSize.CRATE and cash_value > 0:
		if money_label_3d and money_label_3d.has_method("money_is_money"):
			money_label_3d.money_is_money(global_position, cash_value)

	#if cash_value > 0:
		#money_label_3d.money_is_money(global_position, cash_value)
		
	
			
	set_collision_layer_value(1, false)

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
		
			
	if current_state != State.HIT:
		return

	if destroyed_as_hazard:
		#$Marked.show()
		##$marked_embers.emitting = true
		#%rock_marked_sfx.play()
		#apply_slow_linear_damp()
		#await get_tree().create_timer(1.0).timeout
		#
		#await get_tree().create_timer(0.5).timeout
		
		if cash_value < 0:
			money_label_3d.money_is_money(global_position, cash_value)
		## Positive cash already shown above via cash_value > 0.

		## Direct shots already struck above; orange-neutralized blacks never strike.
		## Blast/indirect destroys of live hazards still strike here.
		if not _hazard_strike_from_direct_shot and not _orange_neutralized_hazard:
			_play_rocks_sfx("hazard_hit_sound")
			play_destroy_sfx()
			EventBus.instance.hazard_hit.emit()
			_set_strike_feedback_origin_here()
			gl_PlayerState.add_strike()
		_hazard_strike_from_direct_shot = false
	
	if rock_type == RockSize.SMOKECAN:
		_play_rocks_sfx("hazard_hit_sound")

	if !player_has_marked_rock:
		shake_camera()
	round_manager.bullet_active = false

	if current_state == State.HIT:
		await was_hit_tween()
		if current_state == State.HIT:
			release_to_pool()


## Script `reward $N` for the active range (level-*.txt). Falls back to dataset range_clear_reward.
func _crate_range_reward_amount() -> int:
	if round_manager and round_manager.has_method("get_current_range_reward"):
		return maxi(int(round_manager.get_current_range_reward()), 0)
	if gl_DataSet and gl_DataSet.has_method("get_range_clear_reward"):
		return maxi(int(gl_DataSet.get_range_clear_reward()), 0)
	return maxi(int(gl_DataSet.get_value("range_clear_reward", 0)), 0)


func play_hit_sfx() -> void:
	var vol := randf_range(-25.0, -20.0)
	var pitch := randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05, false).timeout
	_play_rocks_sfx("rock_hit_sound", 0.01, pitch, vol)
	await get_tree().create_timer(0.1, false).timeout
	_play_rocks_sfx("rock_hit_sound", 0.02, pitch, vol)


func play_destroy_sfx() -> void:
	_play_rocks_sfx("rock_hit_sound", 0.02)
	await get_tree().create_timer(0.1, false).timeout
	_play_rocks_sfx("rock_hitSound")
	await get_tree().create_timer(0.1, false).timeout
	_play_rocks_sfx("rock_explosion_sfx")



		

func _on_start_falling_timer_timeout() -> void:
	falling = true
	# Rock–rock collision is scheduled after launch via schedule_airborne_rock_collisions().
	
	if rock_type == RockSize.SMOKECAN:
		var damage_mesh = current_mesh.get_child(0) 
		for i in range(3):
			damage_mesh.show()
			await get_tree().create_timer(0.1, false).timeout
			damage_mesh.hide()
			await get_tree().create_timer(0.1, false).timeout
			
		damage_mesh.show()
		await get_tree().create_timer(0.1, false).timeout
		damage_mesh.hide()
		start_destroyed_process()
		#gravity_scale = 0.4
		#return


func assign_random_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
		
	var rand_selection = ROCK_MESHES.pick_random()
	mesh_instance.mesh = rand_selection
	if mesh_instance.has_node('damage_mesh'):
		mesh_instance.get_child(0).mesh = rand_selection


func _on_explosion_area_body_entered(body: Node3D) -> void:
	#if rock_destroyed:
		#return

	# PUSH ROCKS AWAY IN BLAST
	if player_has_marked_rock == false:
		if body is RigidBody3D:

			var force_dir = (body.global_position - global_position)
			force_dir = force_dir.normalized()	
			#body.apply_central_impulse(force_dir * 2)
			#body.apply_central_impulse(force_dir / 2)
			body.apply_torque_impulse(force_dir * 500.0)
			return
	
	if body.name.contains('Rock_Instance'):
		if body.current_state != body.State.ACTIVE:
			return
		
		if body.current_rock_type.contains("Ender"):
			body.rock_type_name = 'rock_type_4'
			body.current_rock_type = 'neutralised'
			
		if freeze_mine:
			# Prefer the shared freeze helper so avoiders ice instead of striking.
			if body.has_method("apply_aoe_freeze"):
				body.apply_aoe_freeze(3.5)
			else:
				body.hit_by_player(0, Vector2.ZERO)
				if body.has_node("Freeze"):
					body.get_node("Freeze").show()
				await get_tree().create_timer(0.25, false).timeout
				body.freeze = true
				await get_tree().create_timer(3.5, false).timeout
				if is_instance_valid(body):
					body.freeze = false
					if body.has_node("Freeze"):
						body.get_node("Freeze").hide()
				
		else:
			body.start_destroyed_process()
			body.hit_by_player(1, Vector2.ZERO)
	
	#if body.name.contains('Balloon'):
		#return
		#if freeze_mine:
			#return
		#if player_has_marked_rock == false:
			#return
		#body.destroyed_by_shratnel()



func expand_blast_radius() -> void:

	if rock_type == RockSize.CRATE:
		return

	if !player_has_marked_rock && !start_exploding:
		#gl_PlayerState.dataset.power_sky_mine = clamp(gl_PlayerState.dataset.power_sky_mine -1,0,3)
		standard_blast()
		return
	start_exploding = true
	var _blast_radius := 7.5
	#if gl_PlayerState.dataset.power_sky_mine == 2:
		#blast_radius = 15.0
		#
	#if gl_PlayerState.dataset.power_sky_mine >= 3:
		#blast_radius = 25.0
	if current_rock_type.contains("Ender"):
		_blast_radius = 15.0

	player_has_marked_rock = false
	gl_PlayerState.dataset.power_sky_mine = clamp(gl_PlayerState.dataset.power_sky_mine - 1,0,3)
	#gl_PlayerState.dataset.power_sky_mine = 0
	
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.0

	var blast_node : Area3D = $Explosion_area
	blast_node.scale = Vector3.ONE
	blast_node.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 27.5, 0.4)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.45)
	#tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	%explosion_radius_mesh.transparency = 0.4
	blast_node.hide()
	blast_node.monitoring = false
	
func standard_blast() -> void:

	var blast_node : Area3D = $Explosion_area

	# #endregion
	blast_node.show()
	%explosion_radius_mesh.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 4.0, 0.35) #0.25
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.25)
	tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	%explosion_radius_mesh.transparency = 0.0
	%explosion_radius_mesh.hide()
	blast_node.hide()
	blast_node.monitoring = false

func hazard_aoe_delayed() -> void:
	_play_vfx(&"hazard_destroy")

func crate_particles() -> void:
	_play_vfx(&"crate_destroy")


func smoke_particles() -> void:
	if rock_type == RockSize.CRATE:
		crate_particles()
		return
	
	if rock_type == RockSize.SMOKECAN:
		_play_vfx(&"smokecan_destroy")
		return
		
	if rock_type_name.contains('hazard'):
		## Orange-neutralized blacks: normal rock burst only — no hazard fail particles.
		if _orange_neutralized_hazard:
			_play_vfx(&"rock_destroy")
		else:
			_play_vfx(&"hazard_destroy")
			#_try_apply_hazard_smoke_blur()
	else:
		_play_vfx(&"rock_destroy")


func _try_apply_hazard_smoke_blur() -> void:
	if not hazard_smoke_blurs_camera:
		return
	if rock_type != RockSize.HAZARD and rock_type != RockSize.HAZARD_SMALL:
		return
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("apply_hazard_smoke_blur"):
		player_cam.apply_hazard_smoke_blur()




func smoke_particles_duplicates() -> void:
	_play_vfx(&"rock_hit")


func hazard_smoke_particles_duplicates() -> void:
	_play_vfx(&"rock_hit")


func _play_vfx(cue: StringName) -> void:
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("play"):
		pool.play(cue, global_position)


func start_bullet_to_target() -> void:
	play_accurate_sounds()
	if rock_type_name.contains('hazard'):
		gl_PlayerState.dataset.total_hazards += 1
		
func play_accurate_sounds() -> void:
	_play_rocks_stream(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05
	pitch_adjustment += 0.05


func create_shot_instance(sound_file : AudioStream, volume_db : float, pitch_scale : float = 0.02) -> void:
	_play_rocks_stream(sound_file, volume_db, pitch_scale)


func play_piano_note() -> void:
	_play_rocks_piano("launch_flick", randf_range(0.8, 0.9))
	match global_position.x:
		-7.0:
			_play_rocks_piano("1")
		-5.0:
			_play_rocks_piano("2")
		-3.0:
			_play_rocks_piano("3")
		-1.0:
			_play_rocks_piano("4")
		1.0:
			_play_rocks_piano("5")
		3.0:
			_play_rocks_piano("6")
		5.0:
			_play_rocks_piano("7")
		7.0:
			_play_rocks_piano("8")


func out_of_bounds() -> void:
	_play_rocks_sfx("outofBoundsSFX")


func _rocks_sfx_manager() -> Node:
	if _rocks_sfx != null and is_instance_valid(_rocks_sfx):
		return _rocks_sfx
	var tree := get_tree()
	if tree:
		_rocks_sfx = tree.get_first_node_in_group("rocks_sfx")
	return _rocks_sfx


func _play_rocks_sfx(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	var mgr := _rocks_sfx_manager()
	if mgr and mgr.has_method("play"):
		mgr.play(sfx_name, from_position, pitch_scale, volume_db)


func _play_rocks_piano(note_name: String, pitch_scale: float = -1.0) -> void:
	var mgr := _rocks_sfx_manager()
	if mgr and mgr.has_method("play_piano"):
		mgr.play_piano(note_name, pitch_scale)


func _play_rocks_pitch_shift() -> void:
	var mgr := _rocks_sfx_manager()
	if mgr and mgr.has_method("play_pitch_shift"):
		mgr.play_pitch_shift()


func _play_rocks_stream(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var mgr := _rocks_sfx_manager()
	if mgr and mgr.has_method("play_stream"):
		mgr.play_stream(stream, volume_db, pitch_scale)


## Same impact sting used when a rock leaves play — also used for any strike.
func play_strike_impact_sfx() -> void:
	out_of_bounds()


func _apply_direct_hazard_strike() -> void:
	if _hazard_strike_from_direct_shot:
		return
	_hazard_strike_from_direct_shot = true
	_play_rocks_sfx("hazard_hit_sound")
	EventBus.instance.hazard_hit.emit()
	_set_strike_feedback_origin_here()
	gl_PlayerState.add_strike()


func _arm_hazard_crosshair() -> void:
	_hazard_crosshair_armed = false
	_hazard_crosshair_arm_token += 1
	var token := _hazard_crosshair_arm_token
	await get_tree().create_timer(maxf(hazard_crosshair_arm_delay_sec, 0.0), false).timeout
	if token != _hazard_crosshair_arm_token:
		return
	if current_state != State.ACTIVE:
		return
	if rock_type != RockSize.HAZARD and rock_type != RockSize.HAZARD_SMALL:
		return
	if not _player_wants_overlap_destroy("hazards"):
		return
	_hazard_crosshair_armed = true


func _update_hazard_crosshair_overlap() -> void:
	if not _hazard_crosshair_armed:
		return
	if _orange_neutralized_hazard or _freeze_shot_pending:
		return
	if _avoider_overlaps_crosshair():
		_trigger_hazard_crosshair_contact()


## Black-rock reticle contact: same strike + destroy as a direct shot, no seek motion.
func _trigger_hazard_crosshair_contact() -> void:
	if not _player_wants_overlap_destroy("hazards"):
		return
	if rock_type != RockSize.HAZARD and rock_type != RockSize.HAZARD_SMALL:
		return
	if _orange_neutralized_hazard:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	_hazard_crosshair_armed = false
	_hazard_crosshair_arm_token += 1
	## Same strike path as shooting a black rock (prevents a second strike in destroy).
	_apply_direct_hazard_strike()
	start_destroyed_process()


func _set_strike_feedback_origin_here() -> void:
	var rocks_container = null
	if round_manager:
		rocks_container = round_manager.get("rocks_container")
	if rocks_container == null:
		rocks_container = get_tree().get_first_node_in_group("rocks_container")
	if rocks_container and rocks_container.has_method("set_strike_feedback_origin"):
		rocks_container.set_strike_feedback_origin(global_position)


# --- Rock Avoider ------------------------------------------------------------

func _arm_avoider() -> void:
	_avoider_armed = false
	_avoider_has_seek_target = false
	_avoider_retarget_timer = 0.0
	_avoider_arm_token += 1
	%RedParticles.emitting = true
	var token := _avoider_arm_token
	await get_tree().create_timer(avoider_arm_delay_sec, false).timeout
	if token != _avoider_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.AVOIDER:
		return
	_avoider_armed = true
	## First sample immediately once armed; later samples wait for retarget delay.
	_avoider_seek_xy = _crosshair_world_xy_at_depth(global_position.z)
	_avoider_has_seek_target = true
	_avoider_retarget_timer = maxf(avoider_retarget_delay_sec, 0.0)
	_activate_threat_mode()
	# Detect rock contacts for destroy-on-hit (independent of bounce toggle timing).
	set_collision_mask_value(1, true)
	_sync_avoider_collision_exceptions()


## One-shot / restart of this rock's `rock_red_attack_mode` particle (also used by avoiders).
func _emit_avoider_hone_particles() -> void:
	var burst := rock_red_attack_mode
	if burst == null:
		burst = get_node_or_null("rock_red_attack_mode") as GPUParticles3D
	if burst == null:
		return
	burst.one_shot = true
	burst.emitting = false
	burst.restart()
	burst.emitting = true


func _set_red_attack_mesh_particles(emitting: bool) -> void:
	if red_rock_attack == null:
		return
	for child in red_rock_attack.get_children():
		## Fire stays off until attack mode — see `_set_threat_fire`.
		if String(child.name).to_lower() == "fire":
			continue
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = emitting
	if not emitting:
		_set_threat_fire(false)


func _set_threat_fire(active: bool) -> void:
	var mesh := current_mesh
	if mesh == null:
		if rock_type == RockSize.RED_ATTACKER:
			mesh = red_rock_attack
		else:
			mesh = red_rock
	if mesh == null:
		return
	var fire := mesh.get_node_or_null("Fire")
	if fire == null:
		return
	fire.visible = active
	if fire is GPUParticles3D:
		(fire as GPUParticles3D).emitting = active


func _set_red_attack_fire(active: bool) -> void:
	_set_threat_fire(active)


func _is_threat_hazardous() -> bool:
	if _freeze_shot_pending:
		return false
	if rock_type == RockSize.AVOIDER:
		return _avoider_armed
	if rock_type == RockSize.RED_ATTACKER:
		return _red_attacker_dashing or _red_attacker_locking
	return false


func _activate_threat_mode() -> void:
	_set_threat_fire(true)
	_emit_avoider_hone_particles()
	_set_marked_embers(true)
	if rock_type == RockSize.AVOIDER:
		_set_avoider_hum(true)


func _shutdown_threat_fx() -> void:
	_set_threat_fire(false)
	_set_marked_embers(false)
	_set_avoider_hum(false)
	_stop_rock_stay_burst_warn(true)


func _set_marked_embers(active: bool) -> void:
	var embers := get_node_or_null("marked_embers") as GPUParticles3D
	if embers == null:
		return
	if active:
		embers.emitting = false
		embers.restart()
		embers.emitting = true
	else:
		embers.emitting = false


func _set_avoider_hum(on: bool) -> void:
	if on == _avoider_humming:
		return
	_avoider_humming = on
	var mgr := _rocks_sfx_manager()
	if mgr == null:
		return
	if on and mgr.has_method("start_loop"):
		mgr.start_loop("low_humming")
	elif (not on) and mgr.has_method("stop_loop"):
		mgr.stop_loop("low_humming")


func _check_threat_crosshair() -> void:
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.RED_ATTACKER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return
	if not _avoider_overlaps_crosshair():
		return
	if _is_threat_hazardous():
		_trigger_avoider_crosshair_contact()
	else:
		_destroy_pre_arm_threat()


func _arm_red_attacker() -> void:
	_red_attacker_armed = false
	_red_attacker_dashing = false
	_red_attacker_saw_ascent = false
	_red_attacker_arm_token += 1
	var token := _red_attacker_arm_token
	var delay := maxf(red_attacker_arm_delay_sec, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if token != _red_attacker_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.RED_ATTACKER:
		return
	_red_attacker_armed = true
	set_collision_mask_value(1, true)
	_sync_avoider_collision_exceptions()


func _start_red_attacker_lifetime() -> void:
	_red_attacker_life_token += 1
	var token := _red_attacker_life_token
	var lifetime := maxf(red_attacker_lifetime_sec, 0.1)
	await get_tree().create_timer(lifetime, false).timeout
	if token != _red_attacker_life_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.RED_ATTACKER:
		return
	if not rock_activated:
		return
	_expire_red_attacker_lifetime()


## Timed out without a hit — pop with no strike.
func _expire_red_attacker_lifetime() -> void:
	if rock_type != RockSize.RED_ATTACKER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	rock_activated = false
	_red_attacker_armed = false
	_red_attacker_dashing = false
	_red_attacker_arm_token += 1
	_red_attacker_life_token += 1
	_shutdown_threat_fx()

	remove_from_group("Target")
	disable_collision()
	_set_red_attack_mesh_particles(false)
	if current_particles != null:
		current_particles.emitting = false

	expand_blast_radius()
	play_destroy_sfx()
	await was_hit_tween()
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


func _begin_red_attacker_dash() -> void:
	if _red_attacker_dashing or _red_attacker_locking or not rock_activated:
		return
	_red_attacker_locking = true
	_red_attacker_armed = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gravity_scale = 0.0

	var aim_xy := _crosshair_world_xy_at_depth(_avoider_plane_z)
	_red_attacker_dash_target = Vector3(aim_xy.x, aim_xy.y, _avoider_plane_z)

	_play_rocks_sfx(red_attacker_lock_sfx)
	_activate_threat_mode()

	var wait := maxf(red_attacker_apex_wait_sec, 0.0)
	if wait > 0.0:
		await get_tree().create_timer(wait, false).timeout
	if not rock_activated or current_state != State.ACTIVE or rock_type != RockSize.RED_ATTACKER:
		_red_attacker_locking = false
		return

	_red_attacker_locking = false
	_red_attacker_dashing = true
	_red_attacker_dash_speed_current = 0.0
	linear_damp = 0.0
	angular_damp = 0.05
	constant_force = Vector3.ZERO
	## Crosshair lock only sets the heading — keep flying past that point in a straight line.
	var to_target := _red_attacker_dash_target - global_position
	to_target.z = 0.0
	_red_attacker_dash_dir = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3(0.0, -1.0, 0.0)
	linear_velocity = Vector3.ZERO
	global_position.z = _avoider_plane_z


func _update_red_attacker(delta: float) -> void:
	if _freeze_shot_pending:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	global_position.z = _avoider_plane_z
	linear_velocity.z = 0.0

	if _red_attacker_locking:
		linear_velocity = Vector3.ZERO
		return

	if _red_attacker_dashing:
		## Ramp toward top speed along the locked heading (does not home onto the aim point).
		var top := maxf(red_attacker_dash_speed, 1.0)
		var ramp := maxf(red_attacker_dash_ramp_sec, 0.0)
		if ramp <= 0.0:
			_red_attacker_dash_speed_current = top
		else:
			_red_attacker_dash_speed_current = move_toward(
				_red_attacker_dash_speed_current,
				top,
				(top / ramp) * delta
			)
		linear_velocity = _red_attacker_dash_dir * _red_attacker_dash_speed_current
		linear_velocity.z = 0.0
		return

	if not _red_attacker_armed:
		if linear_velocity.y > 0.15:
			_red_attacker_saw_ascent = true
		return

	if linear_velocity.y > 0.15:
		_red_attacker_saw_ascent = true
		return
	## Apex: was ascending (or arm delay finished mid-air) and vertical speed has peaked.
	if _red_attacker_saw_ascent or linear_velocity.y <= 0.0:
		_begin_red_attacker_dash()


func _start_avoider_lifetime() -> void:
	_avoider_life_token += 1
	var token := _avoider_life_token
	var lifetime := maxf(avoider_lifetime_sec, 0.1)
	var warn_dur := clampf(rock_stay_burst_warn_sec, 0.0, lifetime)
	var cruise := lifetime - warn_dur
	if cruise > 0.0:
		await get_tree().create_timer(cruise, false).timeout
		if token != _avoider_life_token:
			return
		if current_state != State.ACTIVE or rock_type != RockSize.AVOIDER:
			return
		if not rock_activated or rock_destroyed:
			return
	_begin_rock_stay_burst_warn(warn_dur)
	if warn_dur > 0.0:
		await get_tree().create_timer(warn_dur, false).timeout
		if token != _avoider_life_token:
			return
		if current_state != State.ACTIVE or rock_type != RockSize.AVOIDER:
			return
		if not rock_activated or rock_destroyed:
			return
	_expire_avoider_lifetime()


## Timed out without touching the reticle — pop with no strike.
func _expire_avoider_lifetime() -> void:
	if rock_type != RockSize.AVOIDER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	rock_activated = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1
	_shutdown_threat_fx()

	remove_from_group("Target")
	disable_collision()

	if current_particles != null:
		current_particles.emitting = false

	var red := get_node_or_null("%RedParticles") as GPUParticles3D
	if red:
		red.emitting = false

	expand_blast_radius()
	play_destroy_sfx()
	await was_hit_tween()
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


func _update_avoider(delta: float) -> void:
	if not _avoider_armed:
		return
	if _freeze_shot_pending:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	_avoider_retarget_timer -= delta
	if not _avoider_has_seek_target or _avoider_retarget_timer <= 0.0:
		_avoider_seek_xy = _crosshair_world_xy_at_depth(global_position.z)
		_avoider_has_seek_target = true
		_avoider_retarget_timer = maxf(avoider_retarget_delay_sec, 0.0)

	var to_aim := Vector2(
		_avoider_seek_xy.x - global_position.x,
		_avoider_seek_xy.y - global_position.y
	)
	if to_aim.length_squared() > 0.0001:
		var desired := to_aim.normalized() * avoider_max_speed_xy
		var vel_xy := Vector2(linear_velocity.x, linear_velocity.y)
		var steered := vel_xy.move_toward(desired, avoider_seek_accel * delta)
		linear_velocity.x = steered.x
		linear_velocity.y = steered.y
		## Pin to the spawn depth plane — no Z drift from launch / collisions.
		linear_velocity.z = 0.0
		global_position.z = _avoider_plane_z


func _arm_mothership() -> void:
	_avoider_armed = false
	_avoider_has_seek_target = false
	_avoider_retarget_timer = 0.0
	_avoider_arm_token += 1
	var token := _avoider_arm_token
	await get_tree().create_timer(avoider_arm_delay_sec, false).timeout
	if token != _avoider_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.MOTHERSHIP:
		return
	_avoider_armed = true
	linear_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 8.0), 0.0)


func _update_mothership(delta: float) -> void:
	if not _avoider_armed:
		return
	if _freeze_shot_pending:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	_avoider_retarget_timer -= delta
	if not _avoider_has_seek_target or _avoider_retarget_timer <= 0.0:
		_avoider_seek_xy = _crosshair_world_xy_at_depth(global_position.z)
		_avoider_has_seek_target = true
		_avoider_retarget_timer = maxf(avoider_retarget_delay_sec, 0.0)

	var away := Vector2(
		global_position.x - _avoider_seek_xy.x,
		global_position.y - _avoider_seek_xy.y
	)
	if away.length_squared() < 0.01:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	var desired := away.normalized() * avoider_max_speed_xy
	var vel_xy := Vector2(linear_velocity.x, linear_velocity.y)
	var steered := vel_xy.move_toward(desired, avoider_seek_accel * delta)
	linear_velocity.x = steered.x
	linear_velocity.y = steered.y
	linear_velocity.z = 0.0
	global_position.z = _avoider_plane_z

	const MIN_X := -7.5
	const MAX_X := 7.5
	const MIN_Y := 0.5
	const MAX_Y := 8.5
	if global_position.x < MIN_X:
		global_position.x = MIN_X
		linear_velocity.x = absf(linear_velocity.x)
	elif global_position.x > MAX_X:
		global_position.x = MAX_X
		linear_velocity.x = -absf(linear_velocity.x)
	if global_position.y < MIN_Y:
		global_position.y = MIN_Y
		linear_velocity.y = absf(linear_velocity.y)
	elif global_position.y > MAX_Y:
		global_position.y = MAX_Y
		linear_velocity.y = -absf(linear_velocity.y)


## Project the player's crosshair onto the rock's depth plane; return world X/Y only.
func _crosshair_world_xy_at_depth(depth_z: float) -> Vector2:
	var fallback := Vector2(global_position.x, global_position.y)
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return fallback

	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return fallback

	var screen_pos := _player_crosshair_screen_pos(player)
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.z) < 0.00001:
		return fallback
	var t := (depth_z - origin.z) / dir.z
	if t < 0.0:
		return fallback
	return Vector2(origin.x + dir.x * t, origin.y + dir.y * t)


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	# Prefer the same TextureRect the gun uses for hit tests.
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		var rect: Control = weapon.crosshair
		return rect.global_position

	var crosshair: Control = player.get_node_or_null("%Crosshair") as Control
	if crosshair:
		return crosshair.global_position + (crosshair.size * 0.5)
	return get_viewport().get_visible_rect().size * 0.5


func _avoider_overlaps_crosshair() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return false

	var rock_screen := cam.unproject_position(global_position)
	var crosshair_screen := _player_crosshair_screen_pos(player)

	var world_radius := 0.5
	if main_col and main_col.shape is SphereShape3D:
		world_radius = (main_col.shape as SphereShape3D).radius * main_col.scale.x
	elif current_mesh:
		world_radius = maxf(current_mesh.scale.x, 0.2) * 0.5

	var edge_screen := cam.unproject_position(
		global_position + cam.global_basis.x * world_radius
	)
	var screen_radius := rock_screen.distance_to(edge_screen)

	# Use the live shrink/expand hit radius (weapon), not the resting upgrade value.
	var hit_radius := _player_live_crosshair_hit_radius(player)

	return rock_screen.distance_to(crosshair_screen) <= hit_radius + screen_radius


## Matches what shooting uses: Weapon_shooting.power_target_circle updates while holding shrink/expand.
func _player_live_crosshair_hit_radius(player: Node) -> float:
	if player == null:
		return 40.0
	if player.has_method("get_current_crosshair_hit_radius"):
		return float(player.get_current_crosshair_hit_radius())
	var weapon = player.get("weapon_shooting")
	if weapon and "power_target_circle" in weapon and float(weapon.power_target_circle) > 0.0:
		return float(weapon.power_target_circle)
	if "power_target_circle" in player and float(player.power_target_circle) > 0.0:
		return float(player.power_target_circle)
	return 40.0


func _reset_aim_hold_bonus() -> void:
	_aim_bonus_extra = 0
	_aim_bonus_hold_accum = 0.0
	_aim_bonus_off_timer = 0.0
	if _aim_bonus_scale_tween:
		_aim_bonus_scale_tween.kill()
		_aim_bonus_scale_tween = null


func _reset_orbit_bonus() -> void:
	_orbit_last_angle = 0.0
	_orbit_accum = 0.0
	orbit_bonus_tracking = false


## Circle the crosshair around this rock (~360°) → cash + "360!" popup via BonusCash / multi_shot.
func _update_orbit_bonus(_delta: float) -> void:
	if not orbit_bonus_enabled or rock_destroyed or not rock_activated:
		_reset_orbit_bonus()
		return
	if current_state != State.ACTIVE or _freeze_shot_pending:
		_reset_orbit_bonus()
		return

	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		_reset_orbit_bonus()
		return
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		_reset_orbit_bonus()
		return

	var rock_screen := cam.unproject_position(global_position)
	var crosshair_screen := _player_crosshair_screen_pos(player)
	var offset := crosshair_screen - rock_screen
	var dist := offset.length()

	var world_radius := 0.5
	if main_col and main_col.shape is SphereShape3D:
		world_radius = (main_col.shape as SphereShape3D).radius * main_col.scale.x
	elif current_mesh:
		world_radius = maxf(current_mesh.scale.x, 0.2) * 0.5
	var edge_screen := cam.unproject_position(global_position + cam.global_basis.x * world_radius)
	var rock_px := rock_screen.distance_to(edge_screen)
	var outer := rock_px + maxf(orbit_bonus_outer_px, 1.0)
	var inner := maxf(orbit_bonus_inner_px, 0.0)

	if dist < inner or dist > outer:
		_reset_orbit_bonus()
		return

	var angle := atan2(offset.y, offset.x)
	if not orbit_bonus_tracking:
		orbit_bonus_tracking = true
		_orbit_last_angle = angle
		_orbit_accum = 0.0
		return

	var step := absf(angle_difference(_orbit_last_angle, angle))
	_orbit_last_angle = angle
	## Ignore huge jumps (teleport / first frame after leave).
	if step > PI * 0.75:
		return
	_orbit_accum += step
	var need := maxf(orbit_bonus_required_radians, 0.5)
	if _orbit_accum < need:
		return

	_orbit_accum = 0.0
	_award_orbit_bonus()


func _award_orbit_bonus() -> void:
	var cash := maxi(orbit_bonus_cash, 0)
	var label_pos := global_position + Vector3(0.0, 1.15, 0.0)
	if cash > 0:
		gl_PlayerState.add_to_cash_pool(cash, label_pos)
		if money_label_3d and money_label_3d.has_method("money_is_money"):
			money_label_3d.money_is_money(label_pos, cash)
	var bonus := get_tree().get_first_node_in_group("multi_shot")
	if bonus and bonus.has_method("show_360"):
		bonus.show_360(label_pos)
	_play_rocks_sfx("cash_bonus_sfx", 0.05)


## Basic rock only: charge +$1 per second of reticle overlap (graceful if you briefly leave).
## Bonus is kept on the rock and only banked when you destroy it with a shot.
func _update_aim_hold_bonus(delta: float) -> void:
	if not aim_bonus_enabled or rock_destroyed or not rock_activated:
		return
	if rock_type != RockSize.SMALL:
		return

	var overlapping := _avoider_overlaps_crosshair()
	if overlapping:
		_aim_bonus_off_timer = 0.0
	else:
		_aim_bonus_off_timer += delta
		if _aim_bonus_off_timer > aim_bonus_leave_grace_sec:
			return

	_aim_bonus_hold_accum += delta
	var interval := maxf(aim_bonus_interval_sec, 0.05)
	while _aim_bonus_hold_accum >= interval:
		_aim_bonus_hold_accum -= interval
		_apply_aim_hold_bonus_tick()


func _player_wants_overlap_destroy(kind: String) -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("wants_crosshair_destroy_on_overlap"):
		return bool(player.wants_crosshair_destroy_on_overlap(kind))
	if kind == "rocks":
		return destroy_on_crosshair_overlap
	if kind == "hazards":
		return hazard_strike_on_crosshair_overlap
	return false


func _arm_destroy_on_crosshair() -> void:
	_destroy_on_crosshair_armed = false
	_destroy_on_crosshair_arm_token += 1
	var token := _destroy_on_crosshair_arm_token
	var delay := maxf(destroy_on_crosshair_arm_delay_sec, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if token != _destroy_on_crosshair_arm_token:
		return
	if current_state != State.ACTIVE:
		return
	if rock_type != RockSize.SMALL and rock_type != RockSize.GREY and rock_type != RockSize.STAY:
		return
	if not _player_wants_overlap_destroy("rocks"):
		return
	_destroy_on_crosshair_armed = true


func _update_destroy_on_crosshair_overlap() -> void:
	if not _player_wants_overlap_destroy("rocks"):
		return
	if not _destroy_on_crosshair_armed:
		return
	if rock_destroyed or not rock_activated:
		return
	if rock_type != RockSize.SMALL and rock_type != RockSize.GREY and rock_type != RockSize.STAY:
		return
	if _freeze_shot_pending:
		return
	if not _avoider_overlaps_crosshair():
		return
	_destroy_on_crosshair_armed = false
	_destroy_on_crosshair_arm_token += 1
	start_destroyed_process()


func _apply_aim_hold_bonus_tick() -> void:
	var add := maxi(aim_bonus_cash_per_tick, 0)
	if add <= 0:
		return
	_aim_bonus_extra += add
	cash_value += add
	_play_aim_hold_bonus_feedback()


func _play_aim_hold_bonus_feedback() -> void:
	## Spin impulse so the rock visibly reacts.
	var axis := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(0.35, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
	apply_torque_impulse(axis * aim_bonus_torque)

	if current_mesh:
		if _aim_bonus_scale_tween:
			_aim_bonus_scale_tween.kill()
		var base := _aim_bonus_mesh_base_scale
		if base == Vector3.ZERO:
			base = current_mesh.scale
			_aim_bonus_mesh_base_scale = base
		var punch := base * aim_bonus_scale_punch
		_aim_bonus_scale_tween = create_tween()
		_aim_bonus_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_aim_bonus_scale_tween.tween_property(current_mesh, "scale", punch, aim_bonus_scale_punch_sec * 0.45)
		_aim_bonus_scale_tween.tween_property(current_mesh, "scale", base, aim_bonus_scale_punch_sec * 0.55)
		_aim_bonus_scale_tween.tween_callback(_play_rocks_sfx.bind("cash_bonus_sfx", 0.05))

	#create_shot_instance(
		#AIM_BONUS_SFX,
		#aim_bonus_sfx_volume_db,
		#randf_range(0.95, 1.15)
	#)


func _trigger_avoider_crosshair_contact() -> void:
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.RED_ATTACKER:
		return
	# Frozen avoiders are inert — no strike from reticle touch.
	if _freeze_shot_pending:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	## Stop seeking, then snap onto the reticle center before the pop.
	rock_activated = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1
	_red_attacker_armed = false
	_red_attacker_dashing = false
	_red_attacker_locking = false
	_red_attacker_arm_token += 1
	_red_attacker_life_token += 1
	_shutdown_threat_fx()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

	var aim_xy := _crosshair_world_xy_at_depth(_avoider_plane_z)
	global_position = Vector3(aim_xy.x, aim_xy.y, _avoider_plane_z)
	## One short beat so the snap reads before the burst.
	await get_tree().create_timer(0.08, false).timeout
	if current_state != State.ACTIVE or rock_destroyed:
		return

	remove_from_group("Target")
	disable_collision()

	if current_particles != null:
		current_particles.emitting = false

	_set_red_attack_mesh_particles(false)

	var red := get_node_or_null("%RedParticles") as GPUParticles3D
	if red:
		red.emitting = false

	var player := get_tree().get_first_node_in_group("Player")
	var cross = player.get("crosshair") if player else null
	if cross and cross.has_method("play_avoider_hit_feedback"):
		cross.play_avoider_hit_feedback()

	expand_blast_radius()
	play_destroy_sfx()
	_shake_camera_avoider_hit()
	_set_strike_feedback_origin_here()
	gl_PlayerState.add_strike()
	await was_hit_tween()
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


## Shoot a frozen / pre-arm avoider to destroy it with no strike.
func _destroy_frozen_avoider() -> void:
	_destroy_pre_arm_threat()


func _destroy_pre_arm_threat() -> void:
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.RED_ATTACKER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	_freeze_shot_pending = false
	freeze = false
	if has_node("Freeze"):
		$Freeze.hide()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = false

	play_hit_sfx()
	if rock_type == RockSize.RED_ATTACKER:
		_expire_red_attacker_lifetime()
	else:
		_expire_avoider_lifetime()


func _shake_camera_avoider_hit() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam == null:
		return
	if rock_type == RockSize.RED_ATTACKER and player_cam.has_method("shake_camera_rock_red_attacker"):
		player_cam.shake_camera_rock_red_attacker()
	elif player_cam.has_method("shake_camera_rock_avoider"):
		player_cam.shake_camera_rock_avoider()
	elif player_cam.has_method("shake_camera_impact"):
		player_cam.shake_camera_impact()


# --- Rock Chaser -------------------------------------------------------------

func _arm_chaser() -> void:
	_chaser_armed = false
	_chaser_lock_progress = 0.0
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	remove_from_group("Target")
	_chaser_saved_gravity = gravity_scale
	_chaser_arm_token += 1
	var token := _chaser_arm_token
	await get_tree().create_timer(chaser_arm_delay_sec, false).timeout
	if token != _chaser_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.CHASER:
		return
	_chaser_armed = true
	ignores_x_out_of_bounds = true
	ballistic_aim_active = false
	gravity_scale = chaser_float_gravity
	linear_damp = 0.8
	# Snap into the play rectangle if launch overshot it.
	_clamp_chaser_to_play_bounds(true)


func _update_chaser(delta: float) -> void:
	if not _chaser_armed:
		return

	# Locked = stop translating, keep spinning in place so it's obvious you can shoot.
	if _chaser_locked:
		linear_velocity = Vector3.ZERO
		global_position = _chaser_lock_pos
		gravity_scale = 0.0
		_update_chaser_lock_progress(delta)
		return

	var bounds := _chaser_play_bounds()
	var aim_xy := _crosshair_world_xy_at_depth(global_position.z)
	var away := Vector2(global_position.x - aim_xy.x, global_position.y - aim_xy.y)
	var desired := Vector2.ZERO
	if away.length_squared() > 0.0001:
		desired = away.normalized() * chaser_max_speed_xy

	# Keep flight inside the column/row rectangle — slide along edges instead of escaping.
	desired = _chaser_steer_inside_bounds(desired, bounds)

	var vel_xy := Vector2(linear_velocity.x, linear_velocity.y)
	var steered := vel_xy.move_toward(desired, chaser_flee_accel * delta)
	linear_velocity.x = steered.x
	linear_velocity.y = steered.y
	linear_velocity.z = move_toward(linear_velocity.z, 0.0, chaser_flee_accel * delta)

	_clamp_chaser_to_play_bounds(false)
	_update_chaser_lock_progress(delta)


func _update_chaser_lock_progress(delta: float) -> void:
	if _avoider_overlaps_crosshair():
		_chaser_lock_progress = minf(_chaser_lock_progress + delta, chaser_lock_time_sec)
		if not _chaser_locked and _chaser_lock_progress >= chaser_lock_time_sec:
			_begin_chaser_lock()
	else:
		_chaser_lock_progress = 0.0
		if _chaser_locked:
			_end_chaser_lock()


func _begin_chaser_lock() -> void:
	_chaser_locked = true
	_chaser_lock_pos = global_position
	linear_velocity = Vector3.ZERO
	gravity_scale = 0.0
	can_sleep = false
	sleeping = false
	if not is_in_group("Target"):
		add_to_group("Target")
	if not _chaser_lock_spin_applied:
		_chaser_lock_spin_applied = true
		var axis := Vector3(randf_range(-0.35, 0.35), 1.0, randf_range(-0.35, 0.35)).normalized()
		apply_torque_impulse(axis * chaser_lock_torque)
		angular_velocity = axis * chaser_lock_torque * 0.65


func _end_chaser_lock() -> void:
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	remove_from_group("Target")
	gravity_scale = chaser_float_gravity
	can_sleep = true



## Playable chase box: columns 1–8 on X, aim rows A–C on Y (at the rock's Z).
func _chaser_play_bounds() -> Rect2:
	var pad := chaser_bounds_padding
	var mgr := _find_rock_manager()
	if mgr:
		var x_right: float = float(mgr.column_to_x(1))
		var x_left: float = float(mgr.column_to_x(8))
		var y_top: float = float(mgr.AIM_LANE_Y[1])
		var y_bot: float = float(mgr.AIM_LANE_Y[3])
		var min_x := minf(x_left, x_right) + pad
		var max_x := maxf(x_left, x_right) - pad
		var min_y := minf(y_bot, y_top) + pad
		var max_y := maxf(y_bot, y_top) - pad
		return Rect2(Vector2(min_x, min_y), Vector2(maxf(max_x - min_x, 0.5), maxf(max_y - min_y, 0.5)))
	# Fallback if manager isn't found.
	return Rect2(Vector2(-7.0 + pad, 0.5 + pad), Vector2(14.0 - pad * 2.0, 6.5 - pad * 2.0))


func _find_rock_manager() -> RockManager:
	var n := get_parent()
	while n:
		if n is RockManager:
			return n as RockManager
		n = n.get_parent()
	return null


func _chaser_steer_inside_bounds(desired: Vector2, bounds: Rect2) -> Vector2:
	var pos := Vector2(global_position.x, global_position.y)
	var edge := maxf(chaser_bounds_padding, 0.2)
	var out := desired
	if pos.x <= bounds.position.x + edge and out.x < 0.0:
		out.x = absf(out.x)
	elif pos.x >= bounds.end.x - edge and out.x > 0.0:
		out.x = -absf(out.x)
	if pos.y <= bounds.position.y + edge and out.y < 0.0:
		out.y = absf(out.y)
	elif pos.y >= bounds.end.y - edge and out.y > 0.0:
		out.y = -absf(out.y)
	# Prefer sliding along the wall when boxed into a corner.
	if out.length_squared() < 0.0001:
		out = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * chaser_max_speed_xy * 0.5
	return out


func _clamp_chaser_to_play_bounds(force_center_if_outside: bool) -> void:
	var bounds := _chaser_play_bounds()
	var pos := global_position
	var was_out := not bounds.has_point(Vector2(pos.x, pos.y))
	pos.x = clampf(pos.x, bounds.position.x, bounds.end.x)
	pos.y = clampf(pos.y, bounds.position.y, bounds.end.y)
	if force_center_if_outside and was_out:
		pos.x = bounds.get_center().x
		pos.y = bounds.get_center().y
	global_position = pos
	# Kill velocity that still pushes out of the box.
	if is_equal_approx(pos.x, bounds.position.x) and linear_velocity.x < 0.0:
		linear_velocity.x = 0.0
	elif is_equal_approx(pos.x, bounds.end.x) and linear_velocity.x > 0.0:
		linear_velocity.x = 0.0
	if is_equal_approx(pos.y, bounds.position.y) and linear_velocity.y < 0.0:
		linear_velocity.y = 0.0
	elif is_equal_approx(pos.y, bounds.end.y) and linear_velocity.y > 0.0:
		linear_velocity.y = 0.0


func _on_rock_body_entered(body: Node) -> void:
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.RED_ATTACKER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return
	if body == null or body == self:
		return

	## Walls / scenery: pop with no strike (same as lifetime expire).
	if body is StaticBody3D:
		_shake_camera_rock_collision()
		_destroy_avoider_from_rock_collision(self)
		return

	## Orange pineapple: explode like a player shot (orange destroy already shakes).
	if _is_orange_target(body):
		_explode_orange_from_avoider(body)
		if avoider_explodes_when_hitting_rock:
			_destroy_avoider_from_rock_collision(self)
		return

	if body is not RockInstance:
		return

	var other: RockInstance = body
	if other.current_state != State.ACTIVE or not other.rock_activated:
		return

	if other.rock_type == RockSize.AVOIDER or other.rock_type == RockSize.RED_ATTACKER:
		if avoider_explodes_when_hitting_avoider:
			_shake_camera_rock_collision()
			_destroy_avoider_from_rock_collision(other)
			_destroy_avoider_from_rock_collision(self)
		return

	# Avoider / red-attacker hit a normal / hazard / other rock — always blow up the other rock.
	# Rock `start_destroyed_process` already plays the rock-destroyed camera shake.
	_destroy_rock_from_avoider_collision(other)
	if avoider_explodes_when_hitting_rock:
		_destroy_avoider_from_rock_collision(self)


func _is_orange_target(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group("pineapple"):
		return true
	return String(body.name).begins_with("Orange")


func _explode_orange_from_avoider(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if "rock_activated" in body and not bool(body.rock_activated):
		return
	if "rock_destroyed" in body and bool(body.rock_destroyed):
		return
	if not body.has_method("hit_by_player"):
		return
	var dmg := 999
	if "health" in body:
		dmg = maxi(int(body.health), 1)
	body.hit_by_player(dmg)


## Same small punch as destroying a rock with a shot (not the heavy avoider-reticle shake).
func _shake_camera_rock_collision() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_rock"):
		player_cam.shake_camera_rock()


func _destroy_rock_from_avoider_collision(other: RockInstance) -> void:
	if other == null or not is_instance_valid(other):
		return
	if other.current_state != State.ACTIVE or not other.rock_activated:
		return
	# Avoiders / red-attackers use the no-strike expire path, not a scored destroy.
	if other.rock_type == RockSize.AVOIDER or other.rock_type == RockSize.RED_ATTACKER:
		_destroy_avoider_from_rock_collision(other)
		return
	other.start_destroyed_process()


## Avoider / red-attacker pop from rock contact — explode with no strike (unlike reticle contact).
func _destroy_avoider_from_rock_collision(avoider: RockInstance) -> void:
	if avoider == null or not is_instance_valid(avoider):
		return
	if avoider.rock_type != RockSize.AVOIDER and avoider.rock_type != RockSize.RED_ATTACKER:
		return
	if avoider.current_state != State.ACTIVE or not avoider.rock_activated:
		return
	if avoider.rock_type == RockSize.RED_ATTACKER:
		avoider._expire_red_attacker_lifetime()
	else:
		avoider._expire_avoider_lifetime()


## Pass-through vs collide for avoider↔avoider, based on `avoider_explodes_when_hitting_avoider`.
func _sync_avoider_collision_exceptions() -> void:
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.RED_ATTACKER:
		return
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self or child is not RockInstance:
			continue
		var other: RockInstance = child
		if other.rock_type != RockSize.AVOIDER and other.rock_type != RockSize.RED_ATTACKER:
			continue
		if avoider_explodes_when_hitting_avoider:
			remove_collision_exception_with(other)
			other.remove_collision_exception_with(self)
		else:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)
