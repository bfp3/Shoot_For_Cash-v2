class_name RockManager
extends Node3D

enum State {
	INACTIVE,
	PREPARE_ROCKS,
	PULSE_ROCKS,
	ROUND_END,
}

var current_state : State = State.INACTIVE
const pulse_magnitude := 1.1
## When true, waves after wave 1 randomise rock columns (existing behaviour).
@export var randomize_later_waves := true
## Depth launch strength for `rock-pigeon` (into the distance). Raise to send them further back.
const pigeon_depth_impulse := 35.0 #70.0
const rock_pigeon_upward_force := 2.0
## Half-angle of the pigeon fan in degrees. Column 1 = +this, column 8 = -this.
## Matches the editor reference: origin → rotate Y by this → push out.
const pigeon_fan_half_angle_deg := 17.0
## How far from world origin the fan aim reference points sit (meters along each ray).
## Separate from impulse strength — move/tweak via `PigeonAimMarkers` children if present.
const pigeon_aim_reference_depth := 45.0
## Optional: Node3D with 8 Marker3D children named "1"…"8" (or in column order).
## When set, those world positions override the computed 17° fan points.
@export var pigeon_aim_markers: Node3D

var rocks_limit := 0
const ROCK_INSTANCE_SCENE := preload("res://ch/Rocks/Rock_Instance.tscn")
## Extra pool rocks added once when entering the boss layout (batched across frames).
var _boss_extra_rocks_added := false

# --- Rock X-axis placement tuning ---------------------------------------
const X_MAX := 10.0          # left-most bound
const X_MIN := -10.0         # right-most bound
const MIN_ROCK_SPACING := 0.0 # 0.5    # no two rocks closer than this
const CLUSTER_MIN_DIST := 0.0 #0.5    # the clustered pair's minimum gap
const CLUSTER_MAX_DIST := 0.0 #1.5    # the clustered pair's maximum gap
@export var angle_bias := 10.0 # 0.1 # how hard rocks get angled back toward the opposite side

var convergence_x := 0.0
# --------------------------------------------------------------------------


# Columns run left to right along the X-axis: column 1 = 7, column 2 = 5... column 8 = -7
# (step of -2 per column).
var manual_rock_sequence : Array = [4]
## Seconds to wait BEFORE launching each rock (index 0 is usually 0).
var _launch_delays_sec : Array = []
## Balloons that appear after a `wait` — spawned mid-pulse at these absolute times.
## Also holds `pineapple` launches (any time, including t=0).
## Items: { "kind": "balloon"|"pineapple", "entry": Dictionary, "time_sec": float }
var _timed_event_schedule : Array = []
var _timed_event_epoch := 0
## Bumped to cancel in-flight staggered launches (bounce_rocks awaits).
var _launch_epoch := 0

const COLUMN_1_X := 7.0 #18.0 
const COLUMN_STEP := 2.0 #4.0
const COLUMN_COUNT := 8
const SAME_COLUMN_OFFSET := 0.0  # spread applied to duplicate rocks sharing a column
## Extra meters added to the spacing between every neighbouring column.
## 0 = default step 2 → (7, 5, 3, 1, -1, -3, -5, -7).
## 1 = step 3 → (10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5, -10.5).
@export var broaden_columns := 0.0:
	set(value):
		broaden_columns = value
		if is_node_ready():
			sync_telegraph_column_positions()
			sync_debug_visualiser()
@export var DEFAULT_LAUNCH_WAIT_MS := 100
## Telegraph markers — defaults to $Columns2 under Rocks.
@export var telegraph_columns: Node3D
## Aim-grid debug overlays (Column1–8 / RowA–C). Defaults to $DebugVisualiser.
@export var debug_visualiser: Node3D
@export var telegraph_enabled := true
@export var telegraph_blink_color := Color(1.0, 0.92, 0.2, 1.0)
@export_range(0.05, 0.8, 0.01) var telegraph_blink_on_sec := 0.12
@export_range(0.05, 0.8, 0.01) var telegraph_blink_off_sec := 0.1
@export_range(0.0, 1.0, 0.01) var telegraph_gap_between_rocks_sec := 0.06
@export var telegraph_sfx: AudioStream = preload("res://sfx/ninja_flicker.ogg")
@export_range(-40.0, 6.0, 0.5) var telegraph_sfx_volume_db := -12.0
## Pitch rises with column index (1→low, 8→high). 0 = fixed pitch.
@export_range(0.0, 0.2, 0.01) var telegraph_sfx_pitch_step := 0.06
## Ghost spawn→aim path preview before the pulse (non-shootable).
@export var path_telegraph_enabled := true
## Total time budget for the full preview sequence (all rocks).
@export_range(0.5, 5.0, 0.1) var path_telegraph_duration_sec := 2.0
@export var path_telegraph_color := Color(1.0, 0.92, 0.25, 0.75)
@export var path_telegraph_aim_color := Color(0.35, 1.0, 0.55, 0.85)
var _telegraph_sfx_player: AudioStreamPlayer
## Resolved spawn columns for the current wave (launch order). Built in assign_manual_rock_positions.
var _wave_spawn_columns: Array[int] = []
var _telegraph_token := 0
## MeshInstance3D per column index 1..COLUMN_COUNT
var _telegraph_meshes: Array[MeshInstance3D] = []
## Base albedo per mesh instance id — restored after blinks
var _telegraph_base_albedo: Dictionary = {}
## Cached spawn→aim plan so telegraph preview matches the real launch.
## Items: { spawn: Vector3, aim: Vector3, column: int, is_pigeon: bool }
var _wave_telegraph_plan: Array = []
var _path_telegraph_root: Node3D
var _path_ghost_mat: StandardMaterial3D
var _path_aim_mat: StandardMaterial3D
var _path_trail_mat: StandardMaterial3D
var _path_telegraph_tween: Tween
## Aim apex heights — same Y bands balloons use (A/B/C → 1/2/3).
const AIM_LANE_Y := {
	1: 7.0, #6.5
	2: 3.5,
	3: 0.5,
}
## World Z of the aim grid (balloon board is at Z ≈ 22.5; A8 ≈ Vector3(-7, 6.5, 22.5)).
const AIM_PLANE_Z := 23.0
## Multiplier on computed aimed-launch impulse. 1.0 = exact ballistic solve; raise if rocks land short.
@export_range(0.5, 2.0, 0.01) var aim_impulse_scale := 1.08
## Gravity during the aimed arc (higher = faster launch, sharper slowdown at apex). Must match impulse math.
@export_range(0.05, 1.0, 0.01) var aim_launch_gravity_scale := 0.5
## Linear damp applied once the rock passes the apex and starts falling.
@export_range(0.0, 2.0, 0.05) var aim_descent_linear_damp := 0.5
## Extra seconds added to the ascent before passing the aim cell (0 = tight apex; try ~0.5 for old hang).
@export_range(0.0, 2.0, 0.05) var aim_hang_time_sec := 0.0
## When true, unspecified aims converge on the midpoint of this wave's leftmost/rightmost spawns
## (center column ± 1). Explicit aims (e.g. `rock 1 A3`) are unchanged. Pigeons are not affected.
@export var bias_random_aim_toward_center := true
## Chance (0–1) that unspecified aims all meet on the same column. Remainder uses adjacent-lane split.
@export_range(0.0, 1.0, 0.05) var converge_same_lane_chance := 0.5
## World-space jitter around the aim cell. 0 = exact; higher = random point within this radius (X/Y).
@export_range(0.0, 5.0, 0.05) var aim_offset := 0.0
## Shared same-lane aim column for this pulse (-1 if unused).
var _wave_convergence_aim_column := -1
## True = all unspecified rocks share one column; false = left/right adjacent split.
var _wave_aim_converge_same_lane := true
## Midpoint / pool used for split aiming this pulse.
var _wave_aim_mid := 0.0
var _wave_aim_center := -1
var _wave_aim_pool: Array[int] = []
# --------------------------------------------------------------------------

# --- Out-of-bounds monitoring (during PULSE_ROCKS only) -------------------
# Misses when an activated rock leaves the camera view on the left, right, or
# bottom (top is allowed — rocks arc above and fall back). Margins are in
# screen pixels beyond the viewport edge. Rocks that spawn off-screen only
# count after they have entered the viewport at least once.
@onready var splash_zone: Area3D = %Splash_zone
const BOUNDS_CHECK_INTERVAL := 0.1  # how often (seconds) to scan active rocks
@export var oob_margin_left_px := 64.0
@export var oob_margin_right_px := 64.0
@export var oob_margin_bottom_px := 64.0
## Optional override; if unset, uses the active Camera3D / `player_cam`.
@export var bounds_camera: Camera3D
## Particle burst + side-biased camera shake when a rock escapes the screen (strike miss).
## Toggle on the Rocks / RockManager node in Main.tscn.
@export var oob_miss_feedback_enabled := true
@export_range(0.0, 0.5, 0.005) var oob_miss_shake_amount := 0.16
@export_range(0.02, 0.5, 0.01) var oob_miss_shake_duration := 0.1
## After launch delay, airborne rocks collide and bounce off each other.
## Off while dormant / preparing / during the pulse itself (see delay below).
## Toggle on the Rocks / RockManager node in Main.tscn.
@export var rock_rock_collisions_enabled := true
## PhysicsMaterial bounce (0 = dead stop on contact, 1 = max restitution) once airborne.
@export_range(0.0, 1.0, 0.05) var rock_rock_bounce := 0.35
## Seconds after each rock's launch impulse before rock–rock collision turns on.
## Keeps stacked / nearby launches from shoving each other during the pulse.
@export_range(0.0, 2.0, 0.05) var rock_rock_collision_delay_sec := 0.4
var _bounds_check_active := false
var _bounds_check_accum := 0.0

enum OobSide { NONE, LEFT, RIGHT, BOTTOM, BEHIND }

const _OOB_MISS_SMOKE := preload("res://res/Particles/Smoke_particles/SmokeQuick.tscn")
const _OOB_MISS_SPARKS = preload("uid://fsbgvpv0703x")
# --------------------------------------------------------------------------

func _ready() -> void:
	if telegraph_columns == null:
		if has_node("Columns2"):
			telegraph_columns = $Columns2
		elif has_node("Columns"):
			telegraph_columns = $Columns
	if debug_visualiser == null and has_node("DebugVisualiser"):
		debug_visualiser = $DebugVisualiser
	_ensure_telegraph_sfx_player()
	_cache_telegraph_meshes()
	# Defer until a Camera3D is current so perspective sync can run.
	call_deferred("sync_telegraph_column_positions")
	call_deferred("sync_debug_visualiser")
	EventBus.instance.egg_pulsed.connect(enter_state.bind(State.PULSE_ROCKS))
	#EventBus.instance.all_rocks_destroyed.connect(all_rocks_destroyed)
	EventBus.instance.detonate_sky_mines.connect(detonate_sky_mines)
	enter_state(current_state)

func _process(delta: float) -> void:
	if not _bounds_check_active:
		return
	
	_bounds_check_accum += delta
	if _bounds_check_accum < BOUNDS_CHECK_INTERVAL:
		return
	_bounds_check_accum = 0.0
	
	check_rocks_out_of_bounds()

func enter_state(new_state : State) -> void:
	current_state = new_state
	
	match current_state:
		State.INACTIVE:
			update_inactive()
			
		State.PREPARE_ROCKS:
			update_prepare_rocks()
			
		State.PULSE_ROCKS:
			update_pulse_rocks()
			
		State.ROUND_END:
			update_round_end()
			
func update_inactive() -> void:
	_bounds_check_active = false
	_cancel_wave_telegraph()
	_cancel_pending_launches()
	_wave_telegraph_plan.clear()
	for i in $Container_1.get_children():
		i.enter_state(i.State.INACTIVE)
	

# This is the start of arranging the rocks.
func start_manual_rock_round(sequence: Array) -> void:
	var rocks: Array = []
	var delays_sec: Array = []
	var pending_wait_ms = null
	var is_first_rock := true

	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait':
				pending_wait_ms = int(entry.get('ms', DEFAULT_LAUNCH_WAIT_MS))
				continue
			if not _is_launchable_spawn_cmd(cmd):
				continue

			if is_first_rock:
				delays_sec.append(0.0)
				is_first_rock = false
			else:
				var wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				delays_sec.append(float(wait_ms) / 1000.0)
			pending_wait_ms = null
			rocks.append(entry)
			continue

		# Legacy integer format support while migrating.
		if typeof(entry) == TYPE_INT:
			if entry >= 300:
				continue
			if is_first_rock:
				delays_sec.append(0.0)
				is_first_rock = false
			else:
				var legacy_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				delays_sec.append(float(legacy_wait_ms) / 1000.0)
			pending_wait_ms = null
			rocks.append(entry)

	manual_rock_sequence = rocks
	_launch_delays_sec = delays_sec
	_timed_event_schedule = _build_timed_event_schedule(sequence)
	enter_state(State.PREPARE_ROCKS)


## Mid-round balloons (after a `wait`) and pineapples share the rock absolute timeline.
## Pending waits are NOT consumed by balloons/pineapples (rock stagger stays unchanged).
func _build_timed_event_schedule(sequence: Array) -> Array:
	var schedule: Array = []
	var abs_t := 0.0
	var pending_wait_ms = null
	var is_first_rock := true
	var seen_wait := false

	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait':
				seen_wait = true
				pending_wait_ms = int(entry.get('ms', DEFAULT_LAUNCH_WAIT_MS))
				continue

			if cmd == 'balloon':
				if seen_wait:
					var balloon_extra := 0.0
					if pending_wait_ms != null:
						balloon_extra = float(pending_wait_ms) / 1000.0
					schedule.append({
						'kind': 'balloon',
						'entry': entry,
						'time_sec': abs_t + balloon_extra,
					})
				continue

			if cmd == 'pineapple':
				var pineapple_extra := 0.0
				if pending_wait_ms != null:
					pineapple_extra = float(pending_wait_ms) / 1000.0
				schedule.append({
					'kind': 'pineapple',
					'entry': entry,
					'time_sec': abs_t + pineapple_extra,
				})
				continue

			if not _is_launchable_spawn_cmd(cmd):
				continue

			if is_first_rock:
				is_first_rock = false
			else:
				var wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				abs_t += float(wait_ms) / 1000.0
			pending_wait_ms = null
			continue

		if typeof(entry) == TYPE_INT:
			var code: int = entry
			# Legacy balloon codes after a wait → mid-round.
			if code == 399 or (code > 300 and code <= 400):
				if seen_wait:
					var legacy_extra := 0.0
					if pending_wait_ms != null:
						legacy_extra = float(pending_wait_ms) / 1000.0
					var legacy_entry: Dictionary
					if code == 399:
						legacy_entry = {'cmd': 'balloon', 'all': true}
					else:
						legacy_entry = {
							'cmd': 'balloon',
							'row': int((code - 300) / 10),
							'column': (code - 300) % 10,
						}
					schedule.append({
						'kind': 'balloon',
						'entry': legacy_entry,
						'time_sec': abs_t + legacy_extra,
					})
				continue
			if code >= 300:
				continue
			if is_first_rock:
				is_first_rock = false
			else:
				var legacy_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				abs_t += float(legacy_wait_ms) / 1000.0
			pending_wait_ms = null

	return schedule
	
func update_prepare_rocks() -> void:
	var temp_rock_array : Array = manual_rock_sequence
	splash_zone.reset_detected_bodies()

	var container_children := $Container_1.get_children()
	var available_bodies : Array = []

	# Leave in-flight rocks alone (ACTIVE / DISABLED) so black hazards can keep
	# falling or drifting from orange hits while the next wave prepares.
	for i in container_children:
		if _rock_slot_busy(i):
			continue
		available_bodies.append(i)

	rocks_limit = mini(temp_rock_array.size(), available_bodies.size())
	if temp_rock_array.size() > available_bodies.size():
		push_warning(
			"Rock sequence needs %d rocks but only %d free slots (others still in flight)."
			% [temp_rock_array.size(), available_bodies.size()]
		)

	var active_bodies : Array = []
	for i in available_bodies.size():
		var body = available_bodies[i]
		if i < rocks_limit:
			active_bodies.append(body)
		else:
			body.enter_state(body.State.INACTIVE)

	assign_manual_rock_positions(active_bodies)

	for pointer in rocks_limit:
		if pointer >= active_bodies.size():
			break
		active_bodies[pointer].rock_type = _spawn_entry_to_rock_type(temp_rock_array[pointer])
		active_bodies[pointer].enter_state(active_bodies[pointer].State.PREPARE_ROCK)

	_build_wave_telegraph_plan(active_bodies)
	start_wave_telegraph()


## Slots still mid-flight must not be reclaimed for the next wave's sequence.
func _rock_slot_busy(body) -> bool:
	return body.current_state == body.State.ACTIVE or body.current_state == body.State.DISABLED


func _spawn_entry_to_rock_type(entry) -> int:
	if entry is Dictionary:
		match String(entry.get('cmd', '')).to_lower():
			'rock-black':
				return RockInstance.RockSize.HAZARD
			'rock-pigeon':
				return RockInstance.RockSize.SMALL_2
			'red_rock_error':
				return RockInstance.RockSize.RED_ROCK_ERROR
			'smokecan':
				return RockInstance.RockSize.SMOKECAN
			'rock-avoider':
				return RockInstance.RockSize.AVOIDER
			'rock-chaser':
				return RockInstance.RockSize.CHASER
			_:
				return RockInstance.RockSize.SMALL

	# Legacy integer encoding: type = value / 10 (1-8 → SMALL, 41-48 → HAZARD)
	if typeof(entry) == TYPE_INT:
		return int(entry / 10)

	return RockInstance.RockSize.SMALL


func _is_launchable_spawn_cmd(cmd: String) -> bool:
	return (
		cmd == 'rock'
		or cmd == 'rock-black'
		or cmd == 'rock-pigeon'
		or cmd == 'red_rock_error'
		or cmd == 'smokecan'
		or cmd == 'rock-avoider'
		or cmd == 'rock-chaser'
	)


func update_pulse_rocks() -> void:
	_cancel_wave_telegraph()
	splash_zone.activate_splash_zone()

	pick_convergence_point()

	_bounds_check_accum = 0.0
	_bounds_check_active = true
	
	_run_timed_event_spawns()
	bounce_rocks()


func _run_timed_event_spawns() -> void:
	if _timed_event_schedule.is_empty():
		return

	var balloon_container := get_tree().get_first_node_in_group('balloon_container')
	var pineapple_launcher: Node = null
	for node in get_tree().get_nodes_in_group('pineapple_container'):
		if node.has_method('launch_from_spawn_entry'):
			pineapple_launcher = node
			break

	_timed_event_epoch += 1
	var epoch := _timed_event_epoch
	var schedule: Array = _timed_event_schedule.duplicate(true)
	var elapsed := 0.0

	for item in schedule:
		if epoch != _timed_event_epoch:
			return
		if current_state != State.PULSE_ROCKS:
			return

		var time_sec: float = float(item.get('time_sec', 0.0))
		var wait_for: float = time_sec - elapsed
		if wait_for > 0.0:
			await get_tree().create_timer(wait_for, false).timeout
			elapsed += wait_for

		if epoch != _timed_event_epoch:
			return
		if current_state != State.PULSE_ROCKS:
			return

		var kind: String = String(item.get('kind', ''))
		var entry = item.get('entry', {})
		if not (entry is Dictionary):
			continue

		match kind:
			'balloon':
				if balloon_container and balloon_container.has_method('spawn_balloon_entry'):
					await balloon_container.spawn_balloon_entry(entry)
			'pineapple':
				if pineapple_launcher and pineapple_launcher.has_method('launch_from_spawn_entry'):
					pineapple_launcher.launch_from_spawn_entry(entry)


func check_rocks_out_of_bounds() -> void:
	var camera := _get_bounds_camera()
	if camera == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	for body in $Container_1.get_children():
		if !(body is RockInstance):
			continue
		# Same eligibility as splash_zone: only live round rocks can miss.
		if body.current_state != body.State.ACTIVE:
			continue
		if body.rock_activated == false:
			continue
		# Explicit opt-out (e.g. smokecan fly-off) — not a camera miss.
		if body.ignores_x_out_of_bounds:
			continue
		if body.rock_type == RockInstance.RockSize.AVOIDER and not body.avoider_destroys_on_out_of_bounds:
			continue

		var world_pos : Vector3 = body.global_position
		if _is_inside_camera_viewport(camera, world_pos, viewport_size):
			body.has_entered_camera_view = true
			continue

		# Spawned off-screen and still entering play — wait until they've been seen.
		if not body.has_entered_camera_view:
			continue

		if _is_outside_camera_miss_bounds(camera, world_pos, viewport_size):
			var side := _get_camera_miss_side(camera, world_pos, viewport_size)
			deactivate_out_of_bounds_rock(body, side)


func _get_bounds_camera() -> Camera3D:
	if bounds_camera != null and is_instance_valid(bounds_camera):
		return bounds_camera
	var active := get_viewport().get_camera_3d()
	if active != null:
		return active
	return get_tree().get_first_node_in_group('player_cam') as Camera3D


## True when the rock is currently inside the visible viewport rectangle (no margin).
func _is_inside_camera_viewport(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> bool:
	if camera.is_position_behind(world_pos):
		return false
	var screen := camera.unproject_position(world_pos)
	return (
		screen.x >= 0.0
		and screen.x <= viewport_size.x
		and screen.y >= 0.0
		and screen.y <= viewport_size.y
	)


## Left / right / bottom past the viewport + margin. Top is never a miss.
## Behind the camera counts as out once the rock has already been on-screen.
func _is_outside_camera_miss_bounds(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> bool:
	return _get_camera_miss_side(camera, world_pos, viewport_size) != OobSide.NONE


func _get_camera_miss_side(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> OobSide:
	if camera.is_position_behind(world_pos):
		return OobSide.BEHIND

	var screen := camera.unproject_position(world_pos)
	if screen.x < -oob_margin_left_px:
		return OobSide.LEFT
	if screen.x > viewport_size.x + oob_margin_right_px:
		return OobSide.RIGHT
	if screen.y > viewport_size.y + oob_margin_bottom_px:
		return OobSide.BOTTOM
	# screen.y < 0 (above the camera) is allowed
	return OobSide.NONE


func deactivate_out_of_bounds_rock(body: RockInstance, side: OobSide = OobSide.NONE) -> void:
	if body.current_state != RockInstance.State.ACTIVE:
		return
	if body.rock_activated == false:
		return

	# Capture before MISSED → reset_stats() clears rock_type_name.
	var missed_rock_type_name: String = body.rock_type_name
	var miss_pos: Vector3 = body.global_position
	body.rock_activated = false
	if body.has_method('out_of_bounds'):
		body.out_of_bounds()
	body.enter_state(body.State.MISSED)
	gl_PlayerState.log_rock_missed(missed_rock_type_name)

	# Strike / miss feedback (skip hazards & smokecans — they don't count as OOB strikes).
	if oob_miss_feedback_enabled and _oob_miss_should_show_feedback(missed_rock_type_name):
		_play_oob_miss_feedback(miss_pos, side)


func _oob_miss_should_show_feedback(rock_type_name: String) -> bool:
	if rock_type_name.contains("hazard"):
		return false
	if rock_type_name.contains("rock_type_8") or rock_type_name.contains("smokecan"):
		return false
	if rock_type_name.contains("rock_type_avoider") or rock_type_name.contains("avoider"):
		return false
	return true


func _play_oob_miss_feedback(world_pos: Vector3, side: OobSide) -> void:
	_spawn_oob_miss_particles(world_pos)
	var side_sign := _oob_side_to_camera_x_sign(side, world_pos)
	var cam := get_tree().get_first_node_in_group("player_cam")
	if cam and cam.has_method("shake_camera_oob_miss"):
		cam.shake_camera_oob_miss(side_sign, oob_miss_shake_amount, oob_miss_shake_duration)


## -1 = punch camera left, +1 = punch camera right (camera local X).
func _oob_side_to_camera_x_sign(side: OobSide, world_pos: Vector3) -> float:
	match side:
		OobSide.LEFT:
			return -1.0
		OobSide.RIGHT:
			return 1.0
		_:
			# Bottom / behind — bias by which half of the screen the rock was on.
			var cam := _get_bounds_camera()
			if cam == null:
				return signf(world_pos.x) if not is_zero_approx(world_pos.x) else 1.0
			if cam.is_position_behind(world_pos):
				return signf(world_pos.x) if not is_zero_approx(world_pos.x) else 1.0
			var screen := cam.unproject_position(world_pos)
			var mid := get_viewport().get_visible_rect().size.x * 0.5
			return -1.0 if screen.x < mid else 1.0


func _spawn_oob_miss_particles(world_pos: Vector3) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = self

	var smoke: Node = _OOB_MISS_SMOKE.instantiate()
	host.add_child(smoke)
	if smoke is Node3D:
		(smoke as Node3D).global_position = world_pos
	if smoke is GPUParticles3D:
		var gp := smoke as GPUParticles3D
		gp.one_shot = true
		gp.emitting = true
		gp.finished.connect(smoke.queue_free, CONNECT_ONE_SHOT)
	else:
		smoke.queue_free.call_deferred()

	var sparks: Node = _OOB_MISS_SPARKS.instantiate()
	host.add_child(sparks)
	if sparks is Node3D:
		(sparks as Node3D).global_position = world_pos
	if sparks is GPUParticles3D:
		var sp := sparks as GPUParticles3D
		sp.one_shot = true
		sp.emitting = true
		sp.finished.connect(sparks.queue_free, CONNECT_ONE_SHOT)
	else:
		# Fallback free if scene root isn't a GPUParticles3D.
		get_tree().create_timer(1.2).timeout.connect(sparks.queue_free, CONNECT_ONE_SHOT)


func assign_rock_positions(bodies: Array) -> void:

	if bodies.is_empty():
		return
	
	var positions : Array[float] = []
	
	# 1. Pick the cluster anchor + partner first so there's always room for them.
	var cluster_anchor := randf_range(X_MIN, X_MAX)
	var cluster_offset := randf_range(CLUSTER_MIN_DIST, CLUSTER_MAX_DIST)
	if randf() < 0.5:
		cluster_offset = -cluster_offset
	
	var cluster_partner := cluster_anchor + cluster_offset
	if cluster_partner > X_MAX or cluster_partner < X_MIN:
		# Went off the edge — try the opposite direction instead.
		cluster_partner = cluster_anchor - cluster_offset
	cluster_partner = clamp(cluster_partner, X_MIN, X_MAX)
	
	positions.append(cluster_anchor)
	if bodies.size() > 1:
		positions.append(cluster_partner)
	
	# 2. Fill remaining rocks via rejection sampling, keeping MIN_ROCK_SPACING
	#    away from every position already chosen.
	var max_attempts := 50
	for i in range(positions.size(), bodies.size()):
		var placed := false
		for attempt in range(max_attempts):
			var candidate := randf_range(X_MIN, X_MAX)
			if _is_far_enough(candidate, positions):
				positions.append(candidate)
				placed = true
				break
		if not placed:
			# Range is crowded — fall back to whatever spot has the largest
			# gap to its nearest neighbor, so we never leave a rock unplaced.
			positions.append(_best_effort_position(positions))
	
	# 3. Shuffle so the "cluster pair" isn't always assigned to the first two
	#    rocks in the container (keeps which physical rocks cluster random too).
	positions.shuffle()
	
	for idx in range(bodies.size()):
		var body = bodies[idx]
		body.target_x_position = positions[idx]


func column_to_x(column: int) -> float:
	# Column 1 is rightmost (+), column 8 leftmost (-). Spacing is equal across all columns.
	# broaden_columns adds to COLUMN_STEP so the whole fan widens uniformly from center.
	column = column % 10

	var clamped_column := clampi(column, 1, COLUMN_COUNT)
	if clamped_column != column:
		push_warning("RockManager: column %d out of range [1, %d], clamped to %d." % [column, COLUMN_COUNT, clamped_column])
	var step := COLUMN_STEP + broaden_columns
	var half_span := float(COLUMN_COUNT - 1) * 0.5 * step
	return half_span - float(clamped_column - 1) * step


# --- Column telegraph -------------------------------------------------------

func _cache_telegraph_meshes() -> void:
	_telegraph_meshes.clear()
	_telegraph_meshes.resize(COLUMN_COUNT + 1)
	_telegraph_base_albedo.clear()
	if telegraph_columns == null:
		return

	# Prefer Column1…Column8 (root Columns / clean naming).
	var numbered := 0
	for col in range(1, COLUMN_COUNT + 1):
		var node := telegraph_columns.get_node_or_null("Column%d" % col)
		if node is MeshInstance3D:
			_telegraph_meshes[col] = node
			numbered += 1

	# Legacy Rocks/$Columns naming: Column (=1), Column1 (=2), … Column7 (=8).
	if numbered < COLUMN_COUNT:
		for col in range(1, COLUMN_COUNT + 1):
			if _telegraph_meshes[col] != null:
				continue
			var legacy_name := "Column" if col == 1 else ("Column%d" % (col - 1))
			var legacy := telegraph_columns.get_node_or_null(legacy_name)
			if legacy is MeshInstance3D:
				_telegraph_meshes[col] = legacy

	# Last resort: MeshInstance3D children in tree order.
	if numbered < COLUMN_COUNT:
		var idx := 1
		for child in telegraph_columns.get_children():
			if idx > COLUMN_COUNT:
				break
			if child is MeshInstance3D:
				if _telegraph_meshes[idx] == null:
					_telegraph_meshes[idx] = child
				idx += 1

	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _telegraph_meshes[col]
		if mesh == null:
			continue
		_ensure_telegraph_material(mesh)


func _ensure_telegraph_material(mesh: MeshInstance3D) -> void:
	var mat: Material = mesh.material_override
	if mat == null:
		var active := mesh.get_active_material(0)
		if active != null:
			mat = active.duplicate()
		else:
			var std := StandardMaterial3D.new()
			std.albedo_color = Color(0.55, 0.55, 0.55, 1.0)
			mat = std
	else:
		mat = mat.duplicate()
	mesh.material_override = mat
	if mat is BaseMaterial3D:
		_telegraph_base_albedo[mesh.get_instance_id()] = (mat as BaseMaterial3D).albedo_color


func _resolve_telegraph_columns_node() -> Node3D:
	if telegraph_columns != null and is_instance_valid(telegraph_columns):
		return telegraph_columns
	if has_node("Columns2"):
		telegraph_columns = $Columns2
		return telegraph_columns
	if has_node("Columns"):
		telegraph_columns = $Columns
		return telegraph_columns
	return null


func _ensure_telegraph_sfx_player() -> void:
	if _telegraph_sfx_player != null and is_instance_valid(_telegraph_sfx_player):
		return
	var existing := get_node_or_null("TelegraphSFX")
	if existing is AudioStreamPlayer:
		_telegraph_sfx_player = existing
	else:
		_telegraph_sfx_player = AudioStreamPlayer.new()
		_telegraph_sfx_player.name = "TelegraphSFX"
		_telegraph_sfx_player.max_polyphony = 4
		add_child(_telegraph_sfx_player)
	if telegraph_sfx != null:
		_telegraph_sfx_player.stream = telegraph_sfx
	_telegraph_sfx_player.volume_db = telegraph_sfx_volume_db


func _play_telegraph_sfx(column: int) -> void:
	_ensure_telegraph_sfx_player()
	if _telegraph_sfx_player == null or telegraph_sfx == null:
		return
	if _telegraph_sfx_player.stream != telegraph_sfx:
		_telegraph_sfx_player.stream = telegraph_sfx
	_telegraph_sfx_player.volume_db = telegraph_sfx_volume_db
	var base_pitch := 0.82
	_telegraph_sfx_player.pitch_scale = base_pitch + float(clampi(column, 1, COLUMN_COUNT) - 1) * telegraph_sfx_pitch_step
	_telegraph_sfx_player.play()


## Keep telegraph markers visually aligned with rock columns from the camera.
## Markers sit closer on Z than the spawn plane (~AIM_PLANE_Z), so matching world X
## looks wrong on the sides. We match each rock column's screen-X onto the marker's
## existing Y/Z (your perspective layout), and still follow broaden_columns / column_to_x.
func sync_telegraph_column_positions() -> void:
	if _resolve_telegraph_columns_node() == null:
		return
	if _telegraph_meshes.size() <= 1 or _telegraph_meshes[1] == null:
		_cache_telegraph_meshes()

	var camera := _get_bounds_camera()
	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _get_telegraph_mesh(col)
		if mesh == null:
			continue
		var pos := mesh.global_position
		var rock_x := column_to_x(col)
		if camera != null:
			var rock_world := Vector3(rock_x, global_position.y, AIM_PLANE_Z)
			pos.x = _perspective_match_screen_x(camera, rock_world, pos, rock_x)
		# If no camera yet, leave the hand-tuned X alone.
		mesh.global_position = pos


## Find marker X so it shares the rock's screen-X while keeping marker Y/Z.
func _perspective_match_screen_x(
	camera: Camera3D,
	rock_world: Vector3,
	marker_pos: Vector3,
	fallback_x: float
) -> float:
	if camera.is_position_behind(rock_world):
		return fallback_x
	var rock_screen := camera.unproject_position(rock_world)
	var marker_screen := camera.unproject_position(marker_pos)
	# Same horizontal as the rock column, same vertical as the existing marker.
	var screen := Vector2(rock_screen.x, marker_screen.y)
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.z) < 0.00001:
		return fallback_x
	var t := (marker_pos.z - origin.z) / dir.z
	if t < 0.0:
		return fallback_x
	return origin.x + dir.x * t


## Keep $DebugVisualiser columns/rows aligned with column_to_x() and AIM_LANE_Y.
## This overlay sits on the aim plane (Z≈23), so world X/Y match is correct (no perspective remap).
func sync_debug_visualiser() -> void:
	if debug_visualiser == null or not is_instance_valid(debug_visualiser):
		if has_node("DebugVisualiser"):
			debug_visualiser = $DebugVisualiser
		else:
			return

	for col in range(1, COLUMN_COUNT + 1):
		var col_node := debug_visualiser.get_node_or_null("Column%d" % col)
		if col_node is Node3D:
			var pos := (col_node as Node3D).global_position
			pos.x = column_to_x(col)
			(col_node as Node3D).global_position = pos

	# RowA / RowA2 / RowA3 → aim rows 1/2/3 (A/B/C). Also accept RowB / RowC aliases.
	var row_node_names := {
		1: ["RowA", "Row1", "RowB1"],
		2: ["RowA2", "RowB", "Row2"],
		3: ["RowA3", "RowC", "Row3"],
	}
	for row in AIM_LANE_Y.keys():
		var names: Array = row_node_names.get(int(row), [])
		var lane_y: float = float(AIM_LANE_Y[row])
		for node_name in names:
			var row_node := debug_visualiser.get_node_or_null(str(node_name))
			if row_node is Node3D:
				var pos := (row_node as Node3D).global_position
				pos.y = lane_y
				(row_node as Node3D).global_position = pos
				break


func start_wave_telegraph() -> void:
	_cancel_wave_telegraph()
	if not telegraph_enabled and not path_telegraph_enabled:
		return
	if _resolve_telegraph_columns_node() != null:
		sync_telegraph_column_positions()
		telegraph_columns.visible = true

	_telegraph_token += 1
	var token := _telegraph_token
	if path_telegraph_enabled:
		_run_path_telegraph(token)
	elif telegraph_enabled:
		_run_column_telegraph(token)


func start_column_telegraph() -> void:
	# Back-compat alias.
	start_wave_telegraph()


func _cancel_wave_telegraph() -> void:
	_telegraph_token += 1
	if _path_telegraph_tween != null:
		_path_telegraph_tween.kill()
		_path_telegraph_tween = null
	_restore_all_telegraph_colors()
	_clear_path_telegraph_visuals()


func _cancel_column_telegraph() -> void:
	_cancel_wave_telegraph()


func _build_wave_telegraph_plan(bodies: Array) -> void:
	_wave_telegraph_plan.clear()
	if bodies.is_empty() or rocks_limit <= 0:
		return

	_rebuild_wave_convergence_aim_columns(bodies)

	for i in mini(rocks_limit, bodies.size()):
		var body = bodies[i]
		var entry = null
		if i < manual_rock_sequence.size():
			entry = manual_rock_sequence[i]

		var spawn_column := 1
		if i < _wave_spawn_columns.size():
			spawn_column = _wave_spawn_columns[i]
		else:
			spawn_column = _x_to_nearest_column(body.target_x_position)

		var spawn := Vector3(
			body.target_x_position,
			body.global_position.y,
			body.global_position.z
		)

		var is_pigeon = body.rock_type == RockInstance.RockSize.SMALL_2
		var aim_world: Vector3
		if is_pigeon:
			var aim := _resolve_aim_cell(entry)
			aim_world = _pigeon_aim_world_point(aim.y, aim.x, spawn.y)
		else:
			var aim := _resolve_aim_cell(entry, true, spawn_column)
			# Bake jitter once so preview and launch share the same target.
			aim_world = _aim_cell_world_position(aim.x, aim.y, true)

		_wave_telegraph_plan.append({
			'spawn': spawn,
			'aim': aim_world,
			'column': spawn_column,
			'is_pigeon': is_pigeon,
		})


func _ensure_path_telegraph_root() -> Node3D:
	if _path_telegraph_root != null and is_instance_valid(_path_telegraph_root):
		return _path_telegraph_root
	_path_telegraph_root = Node3D.new()
	_path_telegraph_root.name = "PathTelegraph"
	add_child(_path_telegraph_root)
	return _path_telegraph_root


func _ensure_path_telegraph_materials() -> void:
	if _path_ghost_mat == null:
		_path_ghost_mat = _make_path_preview_material(path_telegraph_color, 2.5)
	else:
		_path_ghost_mat.albedo_color = path_telegraph_color
		_path_ghost_mat.emission = path_telegraph_color
	if _path_aim_mat == null:
		_path_aim_mat = _make_path_preview_material(path_telegraph_aim_color, 3.5)
	else:
		_path_aim_mat.albedo_color = path_telegraph_aim_color
		_path_aim_mat.emission = path_telegraph_aim_color
	if _path_trail_mat == null:
		var trail_col := path_telegraph_color
		trail_col.a = 0.35
		_path_trail_mat = _make_path_preview_material(trail_col, 1.2)


func _make_path_preview_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = emission_energy
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	return mat


func _clear_path_telegraph_visuals() -> void:
	if _path_telegraph_root == null or not is_instance_valid(_path_telegraph_root):
		return
	for child in _path_telegraph_root.get_children():
		child.queue_free()


func _make_path_sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Visual only — never shootable / never a physics target.
	return mesh_inst


func _run_path_telegraph(token: int) -> void:
	if _wave_telegraph_plan.is_empty():
		if telegraph_enabled:
			await _run_column_telegraph(token)
		return

	_ensure_path_telegraph_materials()
	var root := _ensure_path_telegraph_root()
	_clear_path_telegraph_visuals()

	var count := _wave_telegraph_plan.size()
	var budget := maxf(path_telegraph_duration_sec, 0.2)
	var per_rock := budget / float(count)
	# Leave a little gap between rocks so order is readable.
	var move_sec := clampf(per_rock * 0.72, 0.08, 0.55)
	var hold_sec := clampf(per_rock * 0.18, 0.04, 0.2)
	var gap_sec := maxf(0.0, per_rock - move_sec - hold_sec)

	for i in count:
		if token != _telegraph_token:
			return
		_clear_path_telegraph_visuals()

		var item: Dictionary = _wave_telegraph_plan[i]
		var spawn: Vector3 = item.spawn
		var aim: Vector3 = item.aim
		var column: int = int(item.column)
		var is_pigeon: bool = bool(item.is_pigeon)

		if telegraph_enabled:
			_blink_column_once_fire_and_forget(column, token)
		_play_telegraph_sfx(column)

		var ghost := _make_path_sphere(0.28, _path_ghost_mat)
		root.add_child(ghost)
		ghost.global_position = spawn

		var aim_marker := _make_path_sphere(0.22, _path_aim_mat)
		root.add_child(aim_marker)
		aim_marker.global_position = aim
		aim_marker.visible = true

		var path_pts := _sample_telegraph_path(spawn, aim, is_pigeon, 10)
		_spawn_path_trail_dots(root, path_pts)

		if _path_telegraph_tween != null:
			_path_telegraph_tween.kill()
		_path_telegraph_tween = create_tween()
		var tween := _path_telegraph_tween
		tween.set_parallel(false)
		for p in range(1, path_pts.size()):
			var seg_t := move_sec / float(maxi(path_pts.size() - 1, 1))
			tween.tween_property(ghost, "global_position", path_pts[p], seg_t)
		tween.tween_interval(hold_sec)
		await tween.finished
		if _path_telegraph_tween == tween:
			_path_telegraph_tween = null

		if token != _telegraph_token:
			return
		if gap_sec > 0.0:
			await get_tree().create_timer(gap_sec).timeout

	if token == _telegraph_token:
		_clear_path_telegraph_visuals()


func _blink_column_once_fire_and_forget(column: int, token: int) -> void:
	var mesh := _get_telegraph_mesh(column)
	if mesh == null:
		return
	var mat := mesh.material_override as BaseMaterial3D
	if mat == null:
		_ensure_telegraph_material(mesh)
		mat = mesh.material_override as BaseMaterial3D
	if mat == null:
		return
	var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
	mat.albedo_color = telegraph_blink_color
	get_tree().create_timer(telegraph_blink_on_sec).timeout.connect(
		func () -> void:
			if token != _telegraph_token:
				return
			if is_instance_valid(mesh) and mat:
				mat.albedo_color = base,
		CONNECT_ONE_SHOT
	)


func _sample_telegraph_path(from: Vector3, to: Vector3, is_pigeon: bool, samples: int) -> PackedVector3Array:
	samples = maxi(samples, 2)
	var pts := PackedVector3Array()
	if is_pigeon:
		for i in samples:
			var u := float(i) / float(samples - 1)
			pts.append(from.lerp(to, u))
		return pts

	var vel := BallisticAim.velocity_to_point(
		from, to, -1.0, aim_launch_gravity_scale, aim_hang_time_sec
	)
	var g := BallisticAim.gravity_accel(aim_launch_gravity_scale)
	var dy := to.y - from.y
	var hang := maxf(aim_hang_time_sec, 0.0)
	var flight_t: float
	if dy > 0.01:
		flight_t = sqrt(2.0 * dy / g) + hang
	else:
		var dist := from.distance_to(to)
		flight_t = maxf(0.35, dist / 15.0) + hang
	flight_t = maxf(flight_t, 0.001)

	for i in samples:
		var u := float(i) / float(samples - 1)
		var ti := flight_t * u
		pts.append(from + vel * ti + Vector3(0.0, -0.5 * g * ti * ti, 0.0))
	# Snap end to exact aim so the ghost lands cleanly.
	if pts.size() > 0:
		pts[pts.size() - 1] = to
	return pts


func _spawn_path_trail_dots(root: Node3D, path_pts: PackedVector3Array) -> void:
	# Skip first/last — ghost + aim marker cover those.
	for i in range(1, path_pts.size() - 1):
		var dot := _make_path_sphere(0.08, _path_trail_mat)
		root.add_child(dot)
		dot.global_position = path_pts[i]


func _run_column_telegraph(token: int) -> void:
	var order: Array[int] = []
	var limit := mini(rocks_limit, _wave_spawn_columns.size())
	for i in limit:
		order.append(_wave_spawn_columns[i])

	for column in order:
		if token != _telegraph_token:
			return
		await _blink_column_twice(column, token)
		if token != _telegraph_token:
			return
		if telegraph_gap_between_rocks_sec > 0.0:
			await get_tree().create_timer(telegraph_gap_between_rocks_sec).timeout


func _blink_column_twice(column: int, token: int) -> void:
	var mesh := _get_telegraph_mesh(column)
	if mesh == null:
		return
	var mat := mesh.material_override as BaseMaterial3D
	if mat == null:
		_ensure_telegraph_material(mesh)
		mat = mesh.material_override as BaseMaterial3D
	if mat == null:
		return

	var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
	for _i in 1:
		if token != _telegraph_token:
			mat.albedo_color = base
			return
		mat.albedo_color = telegraph_blink_color
		_play_telegraph_sfx(column)
		await get_tree().create_timer(telegraph_blink_on_sec).timeout
		if token != _telegraph_token:
			mat.albedo_color = base
			return
		mat.albedo_color = base
		await get_tree().create_timer(telegraph_blink_off_sec).timeout


func _get_telegraph_mesh(column: int) -> MeshInstance3D:
	if column < 1 or column >= _telegraph_meshes.size():
		return null
	var mesh := _telegraph_meshes[column]
	if mesh == null or not is_instance_valid(mesh):
		return null
	return mesh


func _restore_all_telegraph_colors() -> void:
	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _get_telegraph_mesh(col)
		if mesh == null:
			continue
		var mat := mesh.material_override as BaseMaterial3D
		if mat == null:
			continue
		var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
		mat.albedo_color = base


func assign_manual_rock_positions(bodies: Array) -> void:
	if bodies.is_empty():
		return
	
	var column_counts := {}
	var positions : Array[float] = []
	_wave_spawn_columns.clear()
	
	for entry in manual_rock_sequence:
		var column := _resolve_spawn_column(entry)
		_wave_spawn_columns.append(column)
		var base_x := column_to_x(column)
		var occurrence : int = column_counts.get(column, 0)
		column_counts[column] = occurrence + 1
		
		var offset := 0.0
		if occurrence > 0:
			var direction := 1.0 if occurrence % 2 == 1 else -1.0
			var step := ceili(occurrence / 2.0)
			offset = direction * step * SAME_COLUMN_OFFSET

		
		positions.append(base_x + offset)
	
	for idx in range(bodies.size()):
		var body = bodies[idx]
		body.target_x_position = positions[idx]


## Resolves a spawn entry to column 1-8. Missing/negative column → random (same as waves 2/3).
func _resolve_spawn_column(entry) -> int:
	if entry is Dictionary:
		var column: int = int(entry.get('column', -1))
		if column < 1:
			return randi_range(1, COLUMN_COUNT)
		return column

	if typeof(entry) == TYPE_INT:
		var value: int = entry
		if value < 10:
			return clampi(value, 1, COLUMN_COUNT)
		return clampi(value % 10, 1, COLUMN_COUNT)

	return randi_range(1, COLUMN_COUNT)


## Resolves aim cell. Missing row → row A (1). Missing column → wave converge / split pool.
## Pass apply_center_bias + spawn_column for rocks / rock-black / smokecan random aims.
func _resolve_aim_cell(entry, apply_center_bias: bool = false, spawn_column: int = -1) -> Vector2i:
	var aim_row := 0
	var aim_column := 0
	if entry is Dictionary:
		aim_row = int(entry.get('aim_row', -1))
		aim_column = int(entry.get('aim_column', -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 1:
		if apply_center_bias and bias_random_aim_toward_center and not _wave_aim_pool.is_empty():
			aim_column = _pick_wave_aim_column(spawn_column)
		else:
			aim_column = randi_range(1, COLUMN_COUNT)
	return Vector2i(aim_row, aim_column)


## Same-lane: shared column. Split: left spawn → center/right of pool; right spawn → left/center.
func _pick_wave_aim_column(spawn_column: int) -> int:
	if _wave_aim_converge_same_lane and _wave_convergence_aim_column >= 1:
		return _wave_convergence_aim_column

	var side_pool: Array[int] = []
	if spawn_column < 1 or _wave_aim_center < 1:
		side_pool = _wave_aim_pool.duplicate()
	elif float(spawn_column) < _wave_aim_mid:
		# Left side → aim center or one lane toward the right (e.g. A4 / A5).
		for col in _wave_aim_pool:
			if col >= _wave_aim_center:
				side_pool.append(col)
	elif float(spawn_column) > _wave_aim_mid:
		# Right side → aim center or one lane toward the left (e.g. A3 / A4).
		for col in _wave_aim_pool:
			if col <= _wave_aim_center:
				side_pool.append(col)
	else:
		side_pool = _wave_aim_pool.duplicate()

	if side_pool.is_empty():
		side_pool = _wave_aim_pool.duplicate()
	if side_pool.is_empty():
		return randi_range(1, COLUMN_COUNT)
	return side_pool[randi() % side_pool.size()]


## Midpoint of furthest-left / furthest-right spawn columns, then center ± 1 (clamped to 1–8).
## e.g. spawns 1+8 → A3/A4/A5; spawns 1+2 → A1/A2/A3; spawns 2+4 → A2/A3/A4.
func _convergence_aim_columns_from_spawns(spawn_columns: Array[int]) -> Dictionary:
	var empty := {'pool': [] as Array[int], 'mid': 0.0, 'center': -1}
	if spawn_columns.is_empty():
		return empty

	var leftmost := spawn_columns[0]
	var rightmost := spawn_columns[0]
	for col in spawn_columns:
		leftmost = mini(leftmost, col)
		rightmost = maxi(rightmost, col)

	var mid := (float(leftmost) + float(rightmost)) * 0.5
	var center := clampi(roundi(mid), 1, COLUMN_COUNT)
	var pool: Array[int] = []
	for col in range(center - 1, center + 2):
		if col >= 1 and col <= COLUMN_COUNT:
			pool.append(col)
	return {'pool': pool, 'mid': mid, 'center': center}


## Collect non-pigeon spawn columns, build aim pool, then roll same-lane vs adjacent-split.
func _rebuild_wave_convergence_aim_columns(bodies: Array) -> void:
	_wave_convergence_aim_column = -1
	_wave_aim_converge_same_lane = true
	_wave_aim_mid = 0.0
	_wave_aim_center = -1
	_wave_aim_pool.clear()

	var spawn_cols: Array[int] = []
	var counter := 0
	for body in bodies:
		if body.current_state != body.State.PREPARE_ROCK and body.current_state != body.State.ACTIVE:
			continue
		if counter >= rocks_limit:
			break
		if body.rock_type != RockInstance.RockSize.SMALL_2:
			spawn_cols.append(_x_to_nearest_column(body.target_x_position))
		counter += 1

	var info := _convergence_aim_columns_from_spawns(spawn_cols)
	_wave_aim_pool = info.pool
	_wave_aim_mid = float(info.mid)
	_wave_aim_center = int(info.center)
	if _wave_aim_pool.is_empty():
		return

	_wave_aim_converge_same_lane = randf() < converge_same_lane_chance
	if _wave_aim_converge_same_lane:
		_wave_convergence_aim_column = _wave_aim_pool[randi() % _wave_aim_pool.size()]
	else:
		_wave_convergence_aim_column = -1


func _is_far_enough(candidate: float, positions: Array[float]) -> bool:
	for p in positions:
		if abs(candidate - p) < MIN_ROCK_SPACING:
			return false
	return true


func _best_effort_position(positions: Array[float]) -> float:
	var best_x := X_MIN
	var best_gap := -1.0
	var x := X_MIN
	
	while x <= X_MAX:
		var nearest_gap := INF
		for p in positions:
			nearest_gap = min(nearest_gap, abs(x - p))
		if nearest_gap > best_gap:
			best_gap = nearest_gap
			best_x = x
		x += 0.25

	return best_x


func _get_position_angle_bias(x_position: float) -> float:
	# Rocks get angled toward convergence_x instead of the exact center.
	
	
	var half_range := (X_MAX - X_MIN) * 0.5
	var normalized = clamp((x_position - convergence_x) / half_range, -1.0, 1.0)
	
	
	return -normalized * angle_bias


func pick_convergence_point() -> void:
	var column := randi_range(1, COLUMN_COUNT - 2)
	convergence_x = column_to_x(column)

func update_round_end() -> void:
	_bounds_check_active = false
	_timed_event_epoch += 1
	_cancel_pending_launches()
	$pitch_shift_rock_sound.pitch_scale = 0.85
	#$pitch_shift_rock_sound.volume_db = -9.0
	update_gravity(1.0)
	for body in $Container_1.get_children():
		body.round_end_check_rock_status()


## Stop staggered `wait` launches mid-sequence (lose / abort / round end).
func _cancel_pending_launches() -> void:
	_launch_epoch += 1


func detonate_sky_mines() -> void:
	var bodies = $Container_1.get_children()
	var counter := 0
	for body in bodies:
		if counter >= bodies.size():
			break
		if body.player_has_marked_rock == true && body.rock_activated:
			body.detonate_rock()
			
func get_rock_limit() -> int:
	var rocks_cap = gl_PlayerState.dataset.rock_limit
	rocks_cap = clamp(rocks_cap, 0, $Container_1.get_children().size())
	gl_PlayerState.dataset.rock_limit = rocks_cap
	return rocks_cap


func get_angle_bias() -> float:
	
	if !randomize_later_waves:
		return 0.0
	
	var probability = randi_range(1,10)
	if probability > 8:
		return 0.0
	
	return 10.0
	
func bounce_rocks() -> void:
	var bodies = $Container_1.get_children()
	# Only launch rocks prepared for this wave — leave lingering ACTIVE hazards alone.
	var to_launch: Array = []
	for body in bodies:
		if body.current_state == body.State.PREPARE_ROCK:
			to_launch.append(body)

	angle_bias = get_angle_bias()
	# Prefer the prepare-time plan so launch matches the telegraph preview.
	if _wave_telegraph_plan.is_empty():
		_rebuild_wave_convergence_aim_columns(to_launch)

	_launch_epoch += 1
	var epoch := _launch_epoch
	var counter := 0

	for body in to_launch:
		if epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
			return
		if counter >= rocks_limit:
			break

		# Delay before this rock (from `wait` markers; default 100ms between rocks).
		if counter < _launch_delays_sec.size():
			var delay_sec: float = float(_launch_delays_sec[counter])
			if delay_sec > 0.0:
				await get_tree().create_timer(delay_sec).timeout
				if epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
					return

		if body == null or not is_instance_valid(body):
			counter += 1
			continue
		if body.current_state != body.State.PREPARE_ROCK:
			counter += 1
			continue

		body.enter_state(body.State.ACTIVE)

		var upward_force = 10.0
		var impulse: Vector3
		if body.rock_type == RockInstance.RockSize.SMALL_2:
			body.bounce_rocks()
			upward_force = upward_force * rock_pigeon_upward_force
			impulse = _pigeon_launch_impulse(body, counter, upward_force)
		else:
			BallisticAim.configure_body_for_ballistic_launch(body, aim_launch_gravity_scale)
			body.begin_ballistic_aim_feel(aim_descent_linear_damp)
			impulse = _build_launch_impulse(body, counter, upward_force, 0.0)
		body.apply_central_impulse(impulse)

		# Rock–rock only after the pulse impulse has cleared — not dormant, not mid-launch.
		if rock_rock_collisions_enabled:
			body.schedule_airborne_rock_collisions(rock_rock_collision_delay_sec, rock_rock_bounce)

		counter += 1

	if epoch == _launch_epoch and current_state == State.PULSE_ROCKS:
		spin_rocks(to_launch)


## Pigeons fly into the distance along the column fan (17° half-angle from world origin).
## `rock-pigeon 1` → spawn col 1, random aim cell on the fan.
## `rock-pigeon 1 A8` → spawn col 1, aim at col 8's distant point (row A height).
func _pigeon_launch_impulse(body, rock_index: int, upward_force: float) -> Vector3:
	var aim_point: Vector3
	if rock_index >= 0 and rock_index < _wave_telegraph_plan.size():
		aim_point = _wave_telegraph_plan[rock_index].aim
	else:
		var entry = null
		if rock_index >= 0 and rock_index < manual_rock_sequence.size():
			entry = manual_rock_sequence[rock_index]
		var aim := _resolve_aim_cell(entry)
		aim_point = _pigeon_aim_world_point(aim.y, aim.x, body.global_position.y)

	var y_force: float = upward_force
	var dx: float = aim_point.x - body.global_position.x
	var dz: float = aim_point.z - body.global_position.z

	var x_impulse := 0.0
	if absf(dz) > 0.001:
		# Keep depth impulse fixed; steer X so the path lines up with the aim point.
		x_impulse = pigeon_depth_impulse * (dx / dz)
	elif absf(dx) > 0.001:
		x_impulse = dx

	return Vector3(x_impulse, y_force, pigeon_depth_impulse) * pulse_magnitude


## Distant aim point for a column on the pigeon fan (optionally at an A/B/C height).
func _pigeon_aim_world_point(column: int, aim_row: int, fallback_y: float) -> Vector3:
	var clamped := clampi(column, 1, COLUMN_COUNT)
	var y: float = fallback_y
	if aim_row > 0:
		y = float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1]))

	var marker := _get_pigeon_aim_marker(clamped)
	if marker:
		return Vector3(marker.global_position.x, y, marker.global_position.z)

	# Reference construction: Vector3.ZERO → rotate Y by fan angle → push out.
	var angle := _pigeon_column_fan_angle(clamped)
	var offset := Vector3(sin(angle), 0.0, cos(angle)) * pigeon_aim_reference_depth
	return Vector3(offset.x, y, offset.z)


## Column 1 → +17°, column 8 → -17°, linear in between.
func _pigeon_column_fan_angle(column: int) -> float:
	var clamped := clampi(column, 1, COLUMN_COUNT)
	var t := float(clamped - 1) / float(COLUMN_COUNT - 1)
	return deg_to_rad(lerpf(pigeon_fan_half_angle_deg, -pigeon_fan_half_angle_deg, t))


func _get_pigeon_aim_marker(column: int) -> Marker3D:
	if pigeon_aim_markers == null:
		pigeon_aim_markers = get_node_or_null('../PigeonAimMarkers') as Node3D
	if pigeon_aim_markers == null:
		return null

	var by_name: Node = pigeon_aim_markers.get_node_or_null(str(column))
	if by_name is Marker3D:
		return by_name

	var markers: Array[Marker3D] = []
	for child in pigeon_aim_markers.get_children():
		if child is Marker3D:
			markers.append(child)
	if column >= 1 and column <= markers.size():
		return markers[column - 1]
	return null


func _x_to_nearest_column(x: float) -> int:
	var best := 1
	var best_dist := absf(x - column_to_x(1))
	for col in range(2, COLUMN_COUNT + 1):
		var dist := absf(x - column_to_x(col))
		if dist < best_dist:
			best_dist = dist
			best = col
	return best


## Ballistic launch through the aim cell world point (e.g. A8 = (-7, 6.5, 23)).
func _build_launch_impulse(body, rock_index: int, _upward_force: float, _z_variation: float) -> Vector3:
	var aim_pos: Vector3
	if rock_index >= 0 and rock_index < _wave_telegraph_plan.size():
		aim_pos = _wave_telegraph_plan[rock_index].aim
	else:
		var entry = null
		if rock_index >= 0 and rock_index < manual_rock_sequence.size():
			entry = manual_rock_sequence[rock_index]
		var spawn_column := _x_to_nearest_column(body.target_x_position)
		var aim := _resolve_aim_cell(entry, true, spawn_column)
		aim_pos = _aim_cell_world_position(aim.x, aim.y, true)
	return _aimed_launch_impulse_to_world(body, aim_pos)


func _aim_cell_world_position(aim_row: int, aim_column: int, apply_jitter: bool = true) -> Vector3:
	var pos := Vector3(
		column_to_x(aim_column),
		float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1])),
		AIM_PLANE_Z
	)
	if apply_jitter and aim_offset > 0.0:
		# Uniform disk in the aim plane (X/Y); Z stays on the board depth.
		var angle := randf() * TAU
		var radius := aim_offset * sqrt(randf())
		pos.x += cos(angle) * radius
		pos.y += sin(angle) * radius
	return pos


## Launch position: column X is assigned in prepare; Y/Z come from the rock instance.
func _launch_world_position(body) -> Vector3:
	return Vector3(body.target_x_position, body.global_position.y, body.global_position.z)


## Reverse-engineered impulse so every lane passes through the same aim world point.
func _aimed_launch_impulse(body, aim_row: int, aim_column: int) -> Vector3:
	return _aimed_launch_impulse_to_world(body, _aim_cell_world_position(aim_row, aim_column, true))


func _aimed_launch_impulse_to_world(body, aim_pos: Vector3) -> Vector3:
	var start_pos := _launch_world_position(body)
	return BallisticAim.impulse_to_point(
		body, start_pos, aim_pos, -1.0, aim_launch_gravity_scale, aim_impulse_scale, aim_hang_time_sec
	)


func spin_rocks(bodies: Array = []) -> void:
	if bodies.is_empty():
		bodies = $Container_1.get_children()

	var counter := 0
	for body in bodies:
		if counter >= rocks_limit:
			break

		body.apply_torque_impulse(Vector3.LEFT * 3000.0)
		counter += 1
		
func update_gravity(_gravity_scale : float) -> void:
	#var counter := 0
	var bodies = $Container_1.get_children()
	for body in bodies:
		body.update_gravity(_gravity_scale)
		#counter += 1

		#await get_tree().create_timer(0.01).timeout

func reset_all_rocks() -> void:
	var bodies = $Container_1.get_children()

	for body in bodies:
		body.enter_state(body.State.INACTIVE)


## Instantiates extra inactive rocks into Container_1 across frames to avoid hitching.
func ensure_extra_rocks(count: int = 80, per_frame: int = 4) -> void:
	if count <= 0:
		return
	if _boss_extra_rocks_added:
		return
	_boss_extra_rocks_added = true

	var container: Node3D = $Container_1
	var remaining := count
	while remaining > 0:
		var batch := mini(per_frame, remaining)
		for _i in batch:
			var rock: Node = ROCK_INSTANCE_SCENE.instantiate()
			container.add_child(rock)
			if rock.has_method("enter_state"):
				rock.enter_state(rock.State.INACTIVE)
			if rock is Node3D:
				(rock as Node3D).global_position = Vector3(0.0, -100.0, 0.0)
		remaining -= batch
		await get_tree().process_frame

		
func end_of_round() -> void:
	enter_state(State.ROUND_END)
			
func reset_rock_back_on() -> void:
	var bodies = $Container_1.get_children()
	var counter := 0

	for body in bodies:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.enter_state(body.State.INACTIVE)
		counter += 1
		if counter >= rocks_limit:
			break
		await get_tree().create_timer(0.2).timeout
	
	await get_tree().create_timer(0.2).timeout
	splash_zone.reset_detected_bodies()
	

func shuffle_current_sequence(_sequence: Array) -> void:
	if not randomize_later_waves:
		start_manual_rock_round(_sequence)
		return

	for idx in range(_sequence.size() - 1, -1, -1):
		var entry = _sequence[idx]

		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			# Keep wait markers in place so launch stagger survives wave shuffles.
			if cmd == 'wait':
				continue
			if not _is_launchable_spawn_cmd(cmd):
				_sequence.remove_at(idx)
				continue
			# Waves 2+: randomise column exactly like the old int shuffle.
			entry.column = randi_range(1, COLUMN_COUNT)
			_sequence[idx] = entry
			continue

		if typeof(entry) != TYPE_INT:
			_sequence.remove_at(idx)
			continue

		var value: int = entry
		if value >= 300:
			_sequence.remove_at(idx)
			continue

		if value < 10:
			_sequence[idx] = randi_range(1, 8)
		else:
			_sequence[idx] = (value / 10) * 10 + randi_range(1, 8)

	manual_rock_sequence = _sequence
	start_manual_rock_round(_sequence)
