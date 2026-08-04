class_name RockManager
extends Node3D

enum State {
	INACTIVE,
	PREPARE_ROCKS,
	PULSE_ROCKS,
	ROUND_END,
}

var current_state : State = State.INACTIVE
@export var pulse_magnitude := 1.1
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

const COLUMN_1_X := 7.0
const COLUMN_STEP := 2.0
const COLUMN_COUNT := 8
const SAME_COLUMN_OFFSET := 0.0  # spread applied to duplicate rocks sharing a column
const DEFAULT_LAUNCH_WAIT_MS := 100
## Aim apex heights — same Y bands balloons use (A/B/C → 1/2/3).
const AIM_LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}
## Row A is the reference / max pulse. B and C scale down from that.
const AIM_PULSE_SCALE := {
	1: 1.0,   # A
	2: 0.85,  # B
	3: 0.70,  # C
}
# --------------------------------------------------------------------------

# --- Out-of-bounds monitoring (during PULSE_ROCKS only) -------------------
@onready var splash_zone: Area3D = %Splash_zone
const OUT_OF_BOUNDS_X := 17.0       # abs(x) beyond this is considered out of bounds
const BOUNDS_CHECK_INTERVAL := 0.1  # how often (seconds) to scan active rocks
var _bounds_check_active := false
var _bounds_check_accum := 0.0
# --------------------------------------------------------------------------


func _ready() -> void:
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
	rocks_limit = temp_rock_array.size()

	var active_bodies : Array = []

	var container_children := $Container_1.get_children()
	if rocks_limit > container_children.size():
		printt("Exceeding the number of rocks in the scene." % [rocks_limit, container_children.size()])
		rocks_limit = container_children.size()

	var counter := 0
	for i in container_children:
		if i.current_state == i.State.DISABLED:
			continue
		if counter < rocks_limit:
			active_bodies.append(i)
		else:
			i.enter_state(i.State.INACTIVE)
		counter += 1

	assign_manual_rock_positions(active_bodies)

	var pointer : int = 0
	
	var c := 0
	for entry in temp_rock_array:
		#if active_bodies[pointer].current_state == active_bodies[pointer].State.DISABLED:
			#continue
		if c >= rocks_limit:
			break
		active_bodies[pointer].rock_type = _spawn_entry_to_rock_type(entry)
		active_bodies[pointer].enter_state(active_bodies[pointer].State.PREPARE_ROCK)
		pointer += 1
		c += 1


func _spawn_entry_to_rock_type(entry) -> int:
	if entry is Dictionary:
		match String(entry.get('cmd', '')).to_lower():
			'rock-black':
				return RockInstance.RockSize.HAZARD
			'rock-pigeon':
				return RockInstance.RockSize.SMALL_2
			'red_rock_error':
				return RockInstance.RockSize.RED_ROCK_ERROR
			'smokebomb':
				return RockInstance.RockSize.SMOKEBOMB
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
		or cmd == 'smokebomb'
	)


func update_pulse_rocks() -> void:
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
	for body in $Container_1.get_children():
		if !(body is RockInstance):
			continue
		# Same eligibility as splash_zone: only live round rocks can miss.
		if body.current_state != body.State.ACTIVE:
			continue
		if body.rock_activated == false:
			continue
		# Depth/fan rocks (pigeons) may leave the side rails — only splash/water misses them.
		if body.ignores_x_out_of_bounds:
			continue
		if absf(body.global_position.x) > OUT_OF_BOUNDS_X:
			deactivate_out_of_bounds_rock(body)


func deactivate_out_of_bounds_rock(body: RockInstance) -> void:
	if body.current_state != RockInstance.State.ACTIVE:
		return
	if body.rock_activated == false:
		return

	# Capture before MISSED → reset_stats() clears rock_type_name.
	var missed_rock_type_name: String = body.rock_type_name
	body.rock_activated = false
	body.enter_state(body.State.MISSED)
	gl_PlayerState.log_rock_missed(missed_rock_type_name)


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
	# Column 1 -> 7, column 2 -> 5, ... column 8 -> -7.
	column = column % 10
	
	var clamped_column := clampi(column, 1, COLUMN_COUNT)
	if clamped_column != column:
		push_warning("RockManager: column %d out of range [1, %d], clamped to %d." % [column, COLUMN_COUNT, clamped_column])
	return COLUMN_1_X - float(clamped_column - 1) * COLUMN_STEP


func assign_manual_rock_positions(bodies: Array) -> void:
	if bodies.is_empty():
		return
	
	var column_counts := {}
	var positions : Array[float] = []
	
	for entry in manual_rock_sequence:
		var column := _resolve_spawn_column(entry)
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
	$pitch_shift_rock_sound.pitch_scale = 0.85
	#$pitch_shift_rock_sound.volume_db = -9.0
	update_gravity(1.0)
	for body in $Container_1.get_children():
		body.round_end_check_rock_status()
		
	


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
	
	var probability = randi_range(1,10)
	if probability > 0:
		return 0.0
	
	return 10.0
	
func bounce_rocks() -> void:
	
	var bodies = $Container_1.get_children()
	
	angle_bias = get_angle_bias()
	
	var counter := 0
	
	for body in bodies:
		if body.current_state == body.State.DISABLED:
			continue
		
		if counter >= bodies.size():
			break

		# Delay before this rock (from `wait` markers; default 100ms between rocks).
		if counter < _launch_delays_sec.size():
			var delay_sec: float = float(_launch_delays_sec[counter])
			if delay_sec > 0.0:
				await get_tree().create_timer(delay_sec).timeout

		body.enter_state(body.State.ACTIVE)
		body.bounce_rocks()

		var upward_force = 10.0
		var impulse: Vector3
		if body.rock_type == RockInstance.RockSize.SMALL_2:
			upward_force = upward_force * rock_pigeon_upward_force
			impulse = _pigeon_launch_impulse(body, counter, upward_force)
		else:
			impulse = _build_launch_impulse(body, counter, upward_force, 0.0)
		body.apply_central_impulse(impulse)

		counter += 1
		
		if counter >= rocks_limit:
			break

	#spin_rocks()


## Pigeons fly into the distance along the column fan (17° half-angle from world origin).
## `rock-pigeon 1` → spawn col 1, aim along col 1's distant ray.
## `rock-pigeon 1 A8` → spawn col 1, aim at col 8's distant point (row A height).
func _pigeon_launch_impulse(body, rock_index: int, upward_force: float) -> Vector3:
	var aim_row := 0
	var aim_column := 0
	var spawn_column := -1

	var entry = null
	if rock_index >= 0 and rock_index < manual_rock_sequence.size():
		entry = manual_rock_sequence[rock_index]
	if entry is Dictionary:
		aim_row = int(entry.get('aim_row', 0))
		aim_column = int(entry.get('aim_column', 0))
		spawn_column = int(entry.get('column', -1))

	# No aim cell → stay on this lane's own fan ray (into the distance).
	if aim_column < 1:
		if spawn_column < 1:
			spawn_column = _x_to_nearest_column(body.global_position.x)
		aim_column = spawn_column

	var y_force: float = upward_force
	if aim_row > 0:
		y_force = upward_force * float(AIM_PULSE_SCALE.get(aim_row, 1.0))

	var aim_point := _pigeon_aim_world_point(aim_column, aim_row, body.global_position.y)
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


## Same pulse power (upward_force * pulse_magnitude). Aimed rocks steer toward A/B/C cells.
func _build_launch_impulse(body, rock_index: int, upward_force: float, z_variation: float) -> Vector3:
	var entry = null
	if rock_index >= 0 and rock_index < manual_rock_sequence.size():
		entry = manual_rock_sequence[rock_index]

	if entry is Dictionary:
		var aim_row: int = int(entry.get('aim_row', 0))
		var aim_column: int = int(entry.get('aim_column', 0))
		if aim_row > 0 and aim_column > 0:
			return _aimed_launch_impulse(body, aim_row, aim_column, upward_force, z_variation)

	# No aim — original angle_bias / convergence behaviour.
	var x_variation := 0.0
	x_variation += _get_position_angle_bias(body.global_position.x)
	return Vector3(x_variation, upward_force, z_variation) * pulse_magnitude


## Aimed rocks steer toward A/B/C cells. Row A uses full pulse; B/C scale down from that.
func _aimed_launch_impulse(body, aim_row: int, aim_column: int, upward_force: float, z_variation: float) -> Vector3:
	var pulse_scale: float = float(AIM_PULSE_SCALE.get(aim_row, 1.0))
	var scaled_upward: float = upward_force * pulse_scale

	var aim_x := column_to_x(aim_column)
	var aim_y := float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1]))
	var dx: float = aim_x - body.global_position.x
	var dy: float = aim_y - body.global_position.y

	var x_variation := 0.0
	if dy > 0.001:
		# Scale so Y stays at scaled_upward (A = full power; B/C reduced).
		x_variation = dx * (scaled_upward / dy)
	elif absf(dx) > 0.001:
		# Aim is at/below spawn height — still pulse upward, steer sideways toward the column.
		x_variation = dx * pulse_scale

	return Vector3(x_variation, scaled_upward, z_variation) * pulse_magnitude


func spin_rocks() -> void:
	
	var bodies = $Container_1.get_children()
	var counter := 0
	for body in bodies:
		if counter >= bodies.size():
			break

		body.apply_torque_impulse(Vector3.LEFT * 3000.0)
		counter += 1
		
		if counter >= rocks_limit:
			break
		
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
