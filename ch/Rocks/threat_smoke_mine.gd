extends RigidBody3D
## Invincible patrol smoke mine. Scripted via `threat …` / removed via `clear threat`.

class_name ThreatSmokeMine

const MINE_COLLISION_LAYER := 16 ## Bit 5 — mines only collide with other mines (rocks stay on layer 2).
const THREAT_SMOKE_VFX_LIFETIME := 10.0

@export_group("Patrol")
@export_range(4.0, 80.0, 0.5) var speed_slow := 4.0
@export_range(4.0, 80.0, 0.5) var speed_fast := 22.0
@export_range(4.0, 120.0, 0.5) var speed_fastest := 36.0
@export_range(0.0, 3.0, 0.05) var path_hold_sec := 0.35
## Brief hold after activate SFX before patrol starts.
@export_range(0.0, 5.0, 0.05) var dormant_arm_sec := 0.2
## Ease of position along each leg (0→1). Edit the Curve inside this texture.
@export var travel_curve: CurveTexture
## Multiplies travel speed over the leg (0→1). Edit the Curve inside this texture.
@export var travel_speed_curve: CurveTexture

@export_group("Arrival")
## Rise from below into the first path cell (no spin / dim lights).
@export_range(0.15, 4.0, 0.05) var arrive_duration_sec := 1.1
## How far below the home cell the mine starts (world Y).
@export_range(2.0, 28.0, 0.5) var arrive_from_below_y := 14.0
## Optional random stagger so packs don't land in lockstep.
@export_range(0.0, 1.5, 0.05) var arrive_stagger_max_sec := 0.35
@export_range(0.0, 8.0, 0.05) var arrive_light_energy := 1.5
@export_range(1.0, 64.0, 0.5) var active_light_energy := 48.0
@export_range(0.05, 1.5, 0.05) var light_fade_sec := 0.35

@export_group("Spin")
## Idle spin (degrees / sec) while active.
@export var spin_deg_per_sec := Vector3(90.0, 140.0, 40.0)
## Extra spin while alarm is winding up (degrees / sec).
@export var alarm_spin_deg_per_sec := Vector3(420.0, 720.0, 180.0)

@export_group("Bob")
@export var bob_enabled := true
@export_range(0.0, 1.0, 0.01) var bob_amplitude := 0.12
@export_range(0.1, 8.0, 0.05) var bob_speed := 1.6

@export_group("Idle Beep")
@export var beep_enabled := true
@export_range(0.5, 10.0, 0.1) var beep_interval_min_sec := 2.0
@export_range(0.5, 10.0, 0.1) var beep_interval_max_sec := 3.0
@export_range(-40.0, 6.0, 0.5) var beep_volume_db := -18.0
## Optional random delay before each beep (makes a pack feel less synced).
@export_range(0.0, 1.0, 0.05) var beep_jitter_sec := 0.25

@export_group("Alarm")
## Hold after alarm SFX before smoke (mine stays frozen / upright).
@export_range(0.0, 3.0, 0.05) var alarm_spin_delay_sec := 0.5
## Extra hold after the freeze delay before releasing AOE smoke.
@export_range(0.0, 3.0, 0.05) var smoke_release_delay_sec := 0.5
@export_range(0.05, 1.0, 0.01) var alarm_rotation_snap_sec := 0.18
@export_range(0.2, 8.0, 0.05) var smoke_cooldown_sec := 1.5
## After smoke pops: stay dormant (no move / no crosshair) for this long.
@export_range(0.0, 12.0, 0.1) var post_smoke_dormant_sec := 4.0
@export var threat_smoke_vfx_cue := &"threat_smoke"
@export_range(2.0, 12.0, 0.1) var threat_smoke_vfx_lifetime := THREAT_SMOKE_VFX_LIFETIME

@export_group("Core Reveal")
## Soft x-ray peek of HiddenMesh/Red_rock_attack while the reticle overlaps.
@export_range(0.2, 1.5, 0.05) var core_reveal_radius_scale := 0.9
@export_range(0.0, 48.0, 1.0) var core_reveal_softness_px := 14.0
@export_range(0.0, 4.0, 0.05) var core_reveal_emission := 1.15
@export var core_reveal_tint := Color(1.0, 0.02, 0.04, 1.0)

@export_group("Mine Collision")
@export_range(0.1, 3.0, 0.05) var stun_duration_sec := 0.55
@export_range(0.5, 20.0, 0.1) var knockback_speed := 7.0
@export_range(0.05, 2.0, 0.05) var return_home_sec := 0.35
@export_range(0.0, 25.0, 0.5) var wobble_deg := 14.0

const CORE_XRAY_SHADER := preload("res://ch/Rocks/fake_rock_xray.gdshader")

@onready var _mesh_root: Node3D = $Mesh
@onready var _mesh: MeshInstance3D = $Mesh/Threat_smoke
@onready var _blink_player: AnimationPlayer = $Mesh/Threat_smoke/AnimationPlayer
@onready var _alarm_player: AnimationPlayer = $Mesh/Threat_smoke/AnimationPlayer2
@onready var _beep_sfx: AudioStreamPlayer3D = $SFX/beep_sfx
@onready var _alarm_sfx: AudioStreamPlayer3D = $SFX/alarm_sfx
@onready var _stun_sfx: AudioStreamPlayer3D = $SFX/stun_sfx
@onready var _release_smoke_sfx: AudioStreamPlayer3D = get_node_or_null("SFX/release_smoke_sfx") as AudioStreamPlayer3D
@onready var _activate_sfx: AudioStreamPlayer3D = get_node_or_null("SFX/beep_sfx") as AudioStreamPlayer3D
@onready var _marked_embers: GPUParticles3D = get_node_or_null("marked_embers") as GPUParticles3D
@onready var _lights: ThreatLightsContainer = (
	get_node_or_null("Mesh/Threat_smoke/LightsContainer") as ThreatLightsContainer
)
@onready var _core_mesh: MeshInstance3D = (
	get_node_or_null("Mesh/HiddenMesh/Red_rock_attack") as MeshInstance3D
)
@onready var _core_glow: OmniLight3D = (
	get_node_or_null("Mesh/HiddenMesh/Red_rock_attack/Fire/Glow") as OmniLight3D
)
@onready var _core_fire: GPUParticles3D = (
	get_node_or_null("Mesh/HiddenMesh/Red_rock_attack/Fire") as GPUParticles3D
)
@onready var _core_embers: GPUParticles3D = (
	get_node_or_null("Mesh/HiddenMesh/Red_rock_attack/RedParticles") as GPUParticles3D
)

var _active := false
var _dormant := true
var _arriving := false
var _exiting := false
var _stunned := false
var _alarming := false
var _alarm_fast_spin := false
var _spin_enabled := false
## True when spawned from range preamble (`threat` before `round`).
var is_range_default := false
var _path: Array[Vector3] = []
var _path_index := 0
var _drive_token := 0
## Bumped on round reset so post-smoke awaits cancel cleanly.
var _life_token := 0
var _cruise_speed := 4.0
var _smoke_ready_at := 0.0
var _splash_exit_pos := Vector3.ZERO
var _plane_z := 23.0
var _home_pos := Vector3.ZERO
var _resume_path_index := 0
var _mesh_base_pos := Vector3.ZERO
var _bob_t := 0.0
var _beep_left := 0.0
var _spin_mul := 1.0
var _light_mats: Array[StandardMaterial3D] = []
var _arrive_tween: Tween
var _alarm_pose_tween: Tween
var _core_xray_mat: ShaderMaterial = null
var _core_glow_rest_energy := 5.0


func _ready() -> void:
	add_to_group("threat_smoke_mine")
	gravity_scale = 0.0
	linear_damp = 2.0
	angular_damp = 8.0
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	collision_layer = 0
	collision_mask = 0
	freeze = true
	sleeping = true
	if _mesh:
		_mesh.visible = true
	if _mesh_root:
		_mesh_base_pos = _mesh_root.position
	_cache_light_materials()
	_setup_core_xray()
	if travel_curve == null:
		travel_curve = load("res://ch/Rocks/threat_travel_curve.tres") as CurveTexture
	if travel_speed_curve == null:
		travel_speed_curve = load("res://ch/Rocks/threat_travel_speed_curve.tres") as CurveTexture
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if _marked_embers:
		_marked_embers.emitting = false
	hide()


func _physics_process(delta: float) -> void:
	if not visible:
		_apply_core_xray(Vector2.ZERO, 0.0, false)
		return
	_update_core_reveal()
	_update_bob(delta)

	var trail := get_node_or_null("GPUParticles3D") as Node3D
	if trail:
		trail.rotate_y(-2.0 * delta)
	if _dormant or _arriving or _exiting or _alarming:
		linear_velocity = Vector3.ZERO
		return
	if not _active:
		return
	if _stunned:
		linear_velocity = linear_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
		_lock_plane_z()
		return
	_check_crosshair_alarm()
	_tick_beep(delta)
	_lock_plane_z()


func _process(delta: float) -> void:
	if not visible:
		return
	_update_spin(delta)


## Manager entry: rise into place dormant, activate, then patrol.
func activate_from_script(
	path_world: Array,
	splash_pos: Vector3 = Vector3.ZERO,
	pace: String = "",
	plane_z: float = 23.0
) -> void:
	configure_pace(pace)
	_plane_z = plane_z
	_splash_exit_pos = splash_pos
	_path.clear()
	for p in path_world:
		var pt := Vector3(p)
		pt.z = _plane_z
		_path.append(pt)
	if _path.is_empty():
		push_warning("ThreatSmokeMine: activate with empty path")
		queue_free()
		return

	_exiting = false
	_stunned = false
	_alarming = false
	_alarm_fast_spin = false
	_arriving = true
	_smoke_ready_at = 0.0
	_path_index = 0
	_home_pos = _path[0]
	_resume_path_index = 0
	_bob_t = randf() * TAU
	_beep_left = _next_beep_wait()
	_spin_mul = 1.0
	_spin_enabled = false

	show()
	if _mesh:
		_mesh.visible = true
	if _mesh_root:
		_mesh_root.show()
		_mesh_root.position = _mesh_base_pos
	_enable_mine_collision(false)
	freeze = true
	_dormant = true
	_active = false
	_set_dormant_look(true, 0.0)
	_set_lights_state(ThreatLightsContainer.State.DORMANT, true)

	var spawn := _arrival_spawn_pos(_home_pos)
	global_position = spawn
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var stagger := maxf(arrive_stagger_max_sec, 0.0)
	if stagger > 0.0:
		await get_tree().create_timer(randf_range(0.0, stagger), false).timeout
		if not is_instance_valid(self) or _exiting:
			return

	await _tween_arrive_to(_home_pos)
	if not is_instance_valid(self) or _exiting:
		return

	_arriving = false
	_set_lights_state(ThreatLightsContainer.State.DORMANT, true)
	## Ambient preamble mines park dormant until PLAY; script mines arm immediately.
	if is_range_default:
		_dormant = true
		_active = false
		_spin_enabled = false
		freeze = true
		_enable_mine_collision(false)
		_set_dormant_look(true, 0.0)
		_play_local_sfx(_activate_sfx)
		return

	_play_local_sfx(_activate_sfx)
	_set_dormant_look(false, light_fade_sec)
	_spin_enabled = true
	var arm := maxf(dormant_arm_sec, 0.0)
	if arm > 0.0:
		await get_tree().create_timer(arm, false).timeout
		if not is_instance_valid(self) or _exiting:
			return
	start_patrol()


func start_patrol() -> void:
	if _exiting or _path.is_empty() or _arriving:
		return
	_dormant = false
	_active = true
	_stunned = false
	_alarming = false
	_alarm_fast_spin = false
	_spin_enabled = true
	freeze = false
	sleeping = false
	_enable_mine_collision(true)
	_set_dormant_look(false, 0.0)
	_set_lights_state(ThreatLightsContainer.State.DORMANT, false)
	_drive_token += 1
	_drive_path(_drive_token)


## Round stop / reset / end — freeze ambient mines in dormant look until next PLAY.
func enter_round_dormant(instant_lights: bool = false) -> void:
	if _exiting:
		return
	_life_token += 1
	_kill_arrive_tween()
	if _alarm_pose_tween != null and is_instance_valid(_alarm_pose_tween):
		_alarm_pose_tween.kill()
		_alarm_pose_tween = null
	## Finish arrival snap if still rising when the round ends.
	if _arriving and not _path.is_empty():
		global_position = _home_pos
	_arriving = false
	_drive_token += 1
	_active = false
	_dormant = true
	_stunned = false
	_alarming = false
	_alarm_fast_spin = false
	_spin_mul = 1.0
	_spin_enabled = false
	_smoke_ready_at = 0.0
	_stop_path_motion()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_enable_mine_collision(false)
	_set_dormant_look(true, 0.0 if instant_lights else light_fade_sec)
	_set_lights_state(ThreatLightsContainer.State.DORMANT, instant_lights)
	_apply_core_xray(Vector2.ZERO, 0.0, false)
	if _marked_embers:
		_marked_embers.emitting = false


## After shop / round start — wake ambient mines that were parked dormant.
func arm_from_dormant() -> void:
	if _exiting or _arriving or _path.is_empty():
		return
	if _active and not _dormant:
		return
	_life_token += 1
	_play_local_sfx(_activate_sfx)
	_set_dormant_look(false, light_fade_sec)
	_set_lights_state(ThreatLightsContainer.State.DORMANT, false)
	_spin_enabled = true
	start_patrol()


## Round / level end — stop patrol, stay put, keep collision off.
func stop_patrol() -> void:
	enter_round_dormant(false)


func configure_pace(pace: String) -> void:
	match String(pace).strip_edges().to_lower():
		"slow":
			_cruise_speed = speed_slow
		"fast":
			_cruise_speed = speed_fast
		"fastest":
			_cruise_speed = speed_fastest
		_:
			_cruise_speed = speed_slow


func begin_threat_splash_exit() -> void:
	if _exiting:
		return
	_exiting = true
	_kill_arrive_tween()
	_arriving = false
	_active = false
	_dormant = false
	_spin_enabled = false
	_drive_token += 1
	_stunned = false
	_alarming = false
	_alarm_fast_spin = false
	_stop_path_motion()
	freeze = false
	sleeping = false
	_enable_mine_collision(false)
	if _marked_embers:
		_marked_embers.emitting = false
	var splash := _splash_exit_pos
	if splash == Vector3.ZERO:
		splash = Vector3(global_position.x, global_position.y - 14.0, global_position.z)
	if splash.y >= global_position.y - 0.5:
		splash.y = global_position.y - 14.0
	var cruise := maxf(_cruise_speed * 1.15, 1.0)
	var dir := splash - global_position
	if dir.length() < 0.001:
		dir = Vector3.DOWN
	else:
		dir = dir.normalized()
	linear_velocity = dir * cruise
	_plunge_then_free(splash, cruise)


func _plunge_then_free(splash: Vector3, cruise: float) -> void:
	var token := _drive_token
	var elapsed := 0.0
	while token == _drive_token and is_instance_valid(self) and elapsed < 4.0:
		var to_target := splash - global_position
		if to_target.length() > 0.5:
			linear_velocity = to_target.normalized() * cruise
		else:
			linear_velocity = Vector3.DOWN * cruise
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	if is_instance_valid(self):
		queue_free()


func _drive_path(token: int) -> void:
	while token == _drive_token and _active and not _exiting and not _dormant:
		if _path.size() < 2:
			_path_index = 0
			await _move_to_point(_path[0], token)
			return
		for i in _path.size():
			if token != _drive_token or not _active or _exiting or _dormant:
				return
			while _stunned or _alarming:
				if token != _drive_token or not _active or _exiting or _dormant:
					return
				await get_tree().physics_frame
			_path_index = i
			_home_pos = _path[i]
			_resume_path_index = i
			await _move_to_point(_path[i], token)
			if token != _drive_token or not _active or _exiting or _dormant:
				return
			var hold := maxf(path_hold_sec, 0.0)
			if hold > 0.0:
				var held := 0.0
				while held < hold:
					if token != _drive_token or not _active or _exiting or _dormant:
						return
					if _stunned or _alarming:
						await get_tree().physics_frame
						continue
					await get_tree().physics_frame
					held += get_physics_process_delta_time()


func _move_to_point(dest: Vector3, token: int) -> void:
	dest.z = _plane_z
	var from := global_position
	from.z = _plane_z
	var dist := from.distance_to(dest)
	if dist < 0.02:
		global_position = dest
		linear_velocity = Vector3.ZERO
		return
	var base_speed := maxf(_cruise_speed, 1.0)
	var duration := clampf(dist / base_speed, 0.08, 6.0)
	var elapsed := 0.0
	while elapsed < duration:
		if token != _drive_token or not _active or _exiting or _dormant:
			return
		if _stunned or _alarming:
			await get_tree().physics_frame
			## Do not advance elapsed while interrupted — resume this leg afterward.
			from = global_position
			from.z = _plane_z
			dist = from.distance_to(dest)
			duration = clampf(dist / base_speed, 0.08, 6.0)
			elapsed = 0.0
			continue
		var u := clampf(elapsed / duration, 0.0, 1.0)
		var eased := _sample_travel_curve(u)
		var speed_mul := _sample_speed_curve(u)
		var desired := from.lerp(dest, eased)
		desired.z = _plane_z
		## Velocity chase so RigidBody contacts can push mines apart.
		var to_desired := desired - global_position
		var chase := clampf(12.0 * speed_mul, 4.0, 28.0)
		linear_velocity = to_desired * chase
		## Snap when very close to avoid endless micro-chase.
		if to_desired.length() < 0.04 and u > 0.92:
			global_position = dest
			linear_velocity = Vector3.ZERO
			return
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time() * maxf(speed_mul, 0.15)
	if token != _drive_token:
		return
	global_position = dest
	linear_velocity = Vector3.ZERO


func _sample_travel_curve(u: float) -> float:
	var c := _curve_from_texture(travel_curve)
	if c:
		return clampf(c.sample(u), 0.0, 1.0)
	## Smoothstep fallback.
	return u * u * (3.0 - 2.0 * u)


func _sample_speed_curve(u: float) -> float:
	var c := _curve_from_texture(travel_speed_curve)
	if c:
		return maxf(c.sample(u), 0.05)
	return 1.0


func _curve_from_texture(tex: CurveTexture) -> Curve:
	if tex == null:
		return null
	return tex.curve


func _stop_path_motion() -> void:
	linear_velocity = Vector3.ZERO


func _enable_mine_collision(on: bool) -> void:
	if on:
		collision_layer = MINE_COLLISION_LAYER
		collision_mask = MINE_COLLISION_LAYER
	else:
		collision_layer = 0
		collision_mask = 0


func _lock_plane_z() -> void:
	if absf(global_position.z - _plane_z) > 0.001:
		global_position.z = _plane_z
	linear_velocity.z = 0.0


func _on_body_entered(body: Node) -> void:
	if not _active or _dormant or _arriving or _exiting or _stunned:
		return
	if body == null or body == self:
		return
	if not (body is ThreatSmokeMine):
		return
	_begin_collision_stun(body as ThreatSmokeMine)


func _begin_collision_stun(other: ThreatSmokeMine) -> void:
	if _stunned or other == null:
		return
	_stunned = true
	_alarming = false
	_spin_mul = 1.0
	var resume := _path[_resume_path_index] if _resume_path_index >= 0 and _resume_path_index < _path.size() else global_position
	resume.z = _plane_z
	_home_pos = resume

	var away := global_position - other.global_position
	away.z = 0.0
	if away.length() < 0.001:
		away = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0)
	away = away.normalized()
	linear_velocity = away * knockback_speed

	_play_local_sfx(_stun_sfx)
	_wobble_mesh()

	var token := _drive_token
	await get_tree().create_timer(maxf(stun_duration_sec, 0.1), false).timeout
	if not is_instance_valid(self) or token != _drive_token or _exiting or _dormant:
		_stunned = false
		return

	## Return toward the path cell we were claiming.
	var back_t := 0.0
	var back_dur := maxf(return_home_sec, 0.05)
	var back_from := global_position
	while back_t < back_dur:
		if not is_instance_valid(self) or token != _drive_token or _exiting or _dormant:
			_stunned = false
			return
		var u := clampf(back_t / back_dur, 0.0, 1.0)
		var eased := u * u * (3.0 - 2.0 * u)
		var desired := back_from.lerp(_home_pos, eased)
		desired.z = _plane_z
		linear_velocity = (desired - global_position) * 16.0
		await get_tree().physics_frame
		back_t += get_physics_process_delta_time()
	if is_instance_valid(self):
		global_position = _home_pos
		linear_velocity = Vector3.ZERO
		_stunned = false


func _wobble_mesh() -> void:
	if _mesh_root == null:
		return
	var base_rot := _mesh_root.rotation_degrees
	var amp := wobble_deg
	var tw := create_tween()
	tw.tween_property(_mesh_root, "rotation_degrees", base_rot + Vector3(amp, -amp, amp * 0.5), 0.08)
	tw.tween_property(_mesh_root, "rotation_degrees", base_rot + Vector3(-amp, amp, -amp * 0.5), 0.08)
	tw.tween_property(_mesh_root, "rotation_degrees", base_rot, 0.1)


func _check_crosshair_alarm() -> void:
	## Dormant / arriving / post-smoke cooldown: crosshair does nothing.
	if _alarming or _stunned or _dormant or _arriving or not _active or _exiting:
		return
	if not _overlaps_crosshair():
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _smoke_ready_at:
		return
	_smoke_ready_at = (
		now
		+ maxf(smoke_cooldown_sec, 0.2)
		+ maxf(alarm_spin_delay_sec, 0.0)
		+ maxf(smoke_release_delay_sec, 0.0)
		+ maxf(post_smoke_dormant_sec, 0.0)
	)
	_run_alarm_sequence()


func _run_alarm_sequence() -> void:
	_alarming = true
	_alarm_fast_spin = false
	_spin_mul = 1.0
	_spin_enabled = false
	_set_lights_state(ThreatLightsContainer.State.ALARM, false)
	_snap_mesh_upright()
	_trigger_alarm_camera_shake()
	
	start_steam_particles(true)
	if _stun_sfx:
		_stun_sfx.play()
	if _marked_embers:
		_marked_embers.emitting = true
	if _alarm_player:
		_alarm_player.play(&"alarm_smoke")
	_play_local_sfx(_alarm_sfx)

	## Hold upright while alarm winds up, then release smoke.
	var spin_delay := maxf(alarm_spin_delay_sec, 0.0)
	if spin_delay > 0.0:
		await get_tree().create_timer(spin_delay, false).timeout
	if not is_instance_valid(self) or _exiting or _dormant or _arriving:
		_cancel_alarm_visuals()
		return

	var delay := maxf(smoke_release_delay_sec, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(self) or _exiting or _dormant or _arriving:
		_cancel_alarm_visuals()
		return

	_spin_mul = 1.0
	_alarming = false
	_alarm_fast_spin = false
	_play_local_sfx(_release_smoke_sfx)
	await get_tree().create_timer(0.1, false).timeout
	if not is_instance_valid(self) or _exiting:
		return
	_play_threat_smoke()
	start_steam_particles(false)
	_trigger_alarm_camera_shake()
	await _enter_post_smoke_dormant()

func _cancel_alarm_visuals() -> void:
	_alarming = false
	_alarm_fast_spin = false
	_spin_mul = 1.0
	if _marked_embers:
		_marked_embers.emitting = false
	_set_lights_state(ThreatLightsContainer.State.DORMANT, false)


func _snap_mesh_upright() -> void:
	if _mesh_root == null:
		return
	if _mesh_root:
		_mesh_root.position = _mesh_base_pos
	if _alarm_pose_tween != null and is_instance_valid(_alarm_pose_tween):
		_alarm_pose_tween.kill()
	_alarm_pose_tween = create_tween()
	_alarm_pose_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_alarm_pose_tween.tween_property(
		_mesh_root,
		"rotation_degrees",
		Vector3.ZERO,
		maxf(alarm_rotation_snap_sec, 0.05)
	)


func _trigger_alarm_camera_shake() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake_camera_threat_smoke_mine"):
		cam.shake_camera_threat_smoke_mine()


func _enter_post_smoke_dormant() -> void:
	## Freeze in place — no patrol, no crosshair, shrunk lights / no spin.
	var token := _life_token
	_drive_token += 1
	_active = false
	_dormant = true
	_stunned = false
	_alarming = false
	_alarm_fast_spin = false
	_spin_mul = 1.0
	_spin_enabled = false
	_stop_path_motion()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_enable_mine_collision(false)
	_set_dormant_look(true, light_fade_sec)
	_set_lights_state(ThreatLightsContainer.State.DEACTIVATED, false)
	if _marked_embers:
		_marked_embers.emitting = false

	var wait := maxf(post_smoke_dormant_sec, 0.0)
	if wait > 0.0:
		await get_tree().create_timer(wait, false).timeout
	if not is_instance_valid(self) or _exiting or token != _life_token:
		return

	_play_local_sfx(_activate_sfx)
	_set_dormant_look(false, light_fade_sec)
	_set_lights_state(ThreatLightsContainer.State.DORMANT, false)
	_spin_enabled = true
	start_patrol()


func _play_threat_smoke() -> void:
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool == null:
		return
	var lifetime := maxf(threat_smoke_vfx_lifetime, THREAT_SMOKE_VFX_LIFETIME)
	if pool.has_method("play"):
		## Always cue `threat_smoke` → aoe_threat_smoke.tscn in Main's VfxPool.
		pool.play(threat_smoke_vfx_cue, global_position, lifetime)
	elif pool.has_method("play_threat_smoke"):
		pool.play_threat_smoke(global_position)

	%rock_hitSound.play()



func _arrival_spawn_pos(home: Vector3) -> Vector3:
	var spawn := home
	if _splash_exit_pos != Vector3.ZERO:
		spawn = Vector3(home.x, _splash_exit_pos.y, home.z)
	else:
		spawn = Vector3(home.x, home.y - arrive_from_below_y, home.z)
	if spawn.y > home.y - 2.0:
		spawn.y = home.y - arrive_from_below_y
	spawn.z = _plane_z
	return spawn


func _tween_arrive_to(dest: Vector3) -> void:
	_kill_arrive_tween()
	dest.z = _plane_z
	var dur := maxf(arrive_duration_sec, 0.05)
	_arrive_tween = create_tween()
	_arrive_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_arrive_tween.tween_property(self, "global_position", dest, dur)
	await _arrive_tween.finished
	_arrive_tween = null
	if is_instance_valid(self):
		global_position = dest
		linear_velocity = Vector3.ZERO


func _kill_arrive_tween() -> void:
	if _arrive_tween != null and is_instance_valid(_arrive_tween):
		_arrive_tween.kill()
	_arrive_tween = null


func _cache_light_materials() -> void:
	_light_mats.clear()
	var host: Node = _lights if _lights else _mesh
	if host == null:
		return
	for child in host.get_children():
		if not (child is MeshInstance3D):
			continue
		if not String(child.name).begins_with("redlights"):
			continue
		var mi := child as MeshInstance3D
		var base := mi.material_override
		if base == null:
			base = mi.get_active_material(0)
		if not (base is StandardMaterial3D):
			continue
		var dup := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.material_override = dup
		_light_mats.append(dup)


func _set_lights_energy(energy: float, fade_sec: float = 0.0) -> void:
	if _light_mats.is_empty():
		return
	var target := maxf(energy, 0.0)
	if fade_sec <= 0.02:
		for mat in _light_mats:
			mat.emission_energy_multiplier = target
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for mat in _light_mats:
		tw.tween_property(mat, "emission_energy_multiplier", target, fade_sec)


func _set_lights_state(state: ThreatLightsContainer.State, instant: bool = false) -> void:
	if _lights == null:
		return
	_lights.enter_state(state, instant)


func _set_dormant_look(dormant: bool, fade_sec: float = 0.0) -> void:
	if dormant:
		_spin_enabled = false
		if _blink_player and _blink_player.is_playing():
			_blink_player.stop()
		_set_lights_energy(arrive_light_energy, fade_sec)
	else:
		_set_lights_energy(active_light_energy, fade_sec)
		if _blink_player:
			_blink_player.play(&"blinkinganim")


func _play_local_sfx(player: AudioStreamPlayer3D, volume_db: float = INF) -> void:
	if player == null or player.stream == null:
		return
	if volume_db < 1000.0:
		player.volume_db = volume_db
	player.play()


func _play_beep() -> void:
	if _beep_sfx == null:
		return
	var jitter := maxf(beep_jitter_sec, 0.0)
	if jitter > 0.0:
		await get_tree().create_timer(randf_range(0.0, jitter), false).timeout
		if not is_instance_valid(self) or not _active or _dormant or _arriving or _exiting:
			return
	_play_local_sfx(_beep_sfx, beep_volume_db)


func _update_spin(delta: float) -> void:
	if _mesh_root == null or not _spin_enabled or _dormant or _arriving or _alarming:
		return
	var rates := spin_deg_per_sec
	if _alarm_fast_spin:
		rates = alarm_spin_deg_per_sec
	rates *= _spin_mul
	_mesh_root.rotate_x(deg_to_rad(rates.x * 0.25) * delta)
	_mesh_root.rotate_y(deg_to_rad(rates.y / 2.0) * delta)


func _update_bob(delta: float) -> void:
	if not bob_enabled or _mesh_root == null:
		return
	if _dormant or _arriving or _alarming or not _active:
		_mesh_root.position = _mesh_base_pos
		return
	_bob_t += delta * bob_speed
	var y := sin(_bob_t) * bob_amplitude
	_mesh_root.position = _mesh_base_pos + Vector3(0.0, y, 0.0)


func _tick_beep(delta: float) -> void:
	if not beep_enabled or _dormant or _arriving or not _active or _exiting:
		return
	_beep_left -= delta
	if _beep_left > 0.0:
		return
	_beep_left = _next_beep_wait()
	_play_beep()


func _next_beep_wait() -> float:
	var a := minf(beep_interval_min_sec, beep_interval_max_sec)
	var b := maxf(beep_interval_min_sec, beep_interval_max_sec)
	return randf_range(a, b)


func _setup_core_xray() -> void:
	if _core_mesh == null:
		return
	_core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_xray_mat = ShaderMaterial.new()
	_core_xray_mat.shader = CORE_XRAY_SHADER
	_core_xray_mat.render_priority = 2
	_core_xray_mat.set_shader_parameter("use_albedo_tex", 0.0)
	_core_xray_mat.set_shader_parameter("albedo_tint", core_reveal_tint)
	_core_xray_mat.set_shader_parameter("emission_color", core_reveal_tint)
	_core_xray_mat.set_shader_parameter("emission_mul", 0.0)
	_core_mesh.material_override = _core_xray_mat
	if _core_glow:
		_core_glow_rest_energy = maxf(_core_glow.light_energy, 5.0)
		_core_glow.light_energy = 0.0
	_apply_core_xray(Vector2.ZERO, 0.0, false)


func _update_core_reveal() -> void:
	if _core_xray_mat == null:
		return
	## Peek while the mine is live / alarming; hide while dormant / arriving / exiting.
	if _dormant or _arriving or _exiting or (not _active and not _alarming):
		_apply_core_xray(Vector2.ZERO, 0.0, false)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		_apply_core_xray(Vector2.ZERO, 0.0, false)
		return
	var player := get_tree().get_first_node_in_group("Player")
	var aim := _player_crosshair_screen_pos(player)
	var radius := _player_live_crosshair_hit_radius(player) * core_reveal_radius_scale
	var overlapping := _overlaps_crosshair()
	_apply_core_xray(aim, radius if overlapping else 0.0, overlapping)


func _apply_core_xray(center_px: Vector2, radius_px: float, overlapping: bool) -> void:
	if _core_xray_mat == null:
		return
	var softness := maxf(core_reveal_softness_px, radius_px * 0.12)
	_core_xray_mat.set_shader_parameter("xray_center_px", center_px)
	_core_xray_mat.set_shader_parameter("xray_radius_px", radius_px if overlapping else 0.0)
	_core_xray_mat.set_shader_parameter("xray_softness_px", softness)
	_core_xray_mat.set_shader_parameter("emission_mul", core_reveal_emission if overlapping else 0.0)
	_core_xray_mat.set_shader_parameter("albedo_tint", core_reveal_tint)
	_core_xray_mat.set_shader_parameter("emission_color", core_reveal_tint)
	if _core_glow:
		_core_glow.light_energy = _core_glow_rest_energy if overlapping else 0.0
	if _core_fire:
		_core_fire.emitting = overlapping
	if _core_embers:
		_core_embers.emitting = overlapping


func _overlaps_crosshair() -> bool:
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
	var world_radius := 0.55
	var col := get_node_or_null("main_col") as CollisionShape3D
	if col and col.shape is SphereShape3D:
		world_radius = (col.shape as SphereShape3D).radius * maxf(col.scale.x, 1.0)
	var edge_screen := cam.unproject_position(global_position + cam.global_basis.x * world_radius)
	var screen_radius := rock_screen.distance_to(edge_screen)
	var hit_radius := _player_live_crosshair_hit_radius(player)
	return rock_screen.distance_to(crosshair_screen) <= hit_radius + screen_radius


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		var rect: Control = weapon.crosshair
		return rect.global_position
	var crosshair: Control = player.get_node_or_null("%Crosshair") as Control
	if crosshair:
		return crosshair.global_position + (crosshair.size * 0.5)
	return get_viewport().get_visible_rect().size * 0.5


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

func start_steam_particles(turn_off : bool = false) -> void:
	for i in $SteamParticles.get_children():
		if i is GPUParticles3D:
			i.emitting = turn_off
