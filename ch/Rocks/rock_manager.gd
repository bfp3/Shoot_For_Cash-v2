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

const COLUMN_1_X := 7.0
const COLUMN_STEP := 2.0
const COLUMN_COUNT := 8
const SAME_COLUMN_OFFSET := 0.0  # spread applied to duplicate rocks sharing a column
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
	# Drop anything that isn't a rock/black spawn dict (legacy ints / balloons).
	for idx in range(sequence.size() - 1, -1, -1):
		var entry = sequence[idx]
		if entry is Dictionary:
			var cmd: String = entry.get('cmd', '')
			if cmd != 'rock' and cmd != 'black':
				sequence.remove_at(idx)
			continue
		# Legacy integer format support while migrating.
		if typeof(entry) == TYPE_INT:
			if entry >= 300:
				sequence.remove_at(idx)
			continue
		sequence.remove_at(idx)

	manual_rock_sequence = sequence
	enter_state(State.PREPARE_ROCKS)
	
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
		match String(entry.get('cmd', '')):
			'black':
				return RockInstance.RockSize.HAZARD
			_:
				return RockInstance.RockSize.SMALL

	# Legacy integer encoding: type = value / 10 (1-8 → SMALL, 41-48 → HAZARD)
	if typeof(entry) == TYPE_INT:
		return int(entry / 10)

	return RockInstance.RockSize.SMALL


func update_pulse_rocks() -> void:
	splash_zone.activate_splash_zone()

	pick_convergence_point()

	_bounds_check_accum = 0.0
	_bounds_check_active = true
	
	bounce_rocks()


func check_rocks_out_of_bounds() -> void:
	for body in $Container_1.get_children():
		if body.current_state != body.State.DISABLED:
			continue
			
		if !body.name.contains('Rock_Instance'):
			continue
		if absf(body.global_position.x) > OUT_OF_BOUNDS_X:
			deactivate_out_of_bounds_rock(body)


func deactivate_out_of_bounds_rock(body) -> void:
	if body.current_state == RockInstance.State.ACTIVE:
		body.enter_state(body.State.MISSED)
		print('OUT OF BOUNDS ', body.name)
		gl_PlayerState.log_rock_missed()
		#body.enter_state(RockInstance.State.MISSED)


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
		body.enter_state(body.State.ACTIVE)
		body.bounce_rocks()

		#$AnimationPlayer.play('push_up')
		
		#var x_variation = randf_range(-2.0, 2.0)
		var x_variation = 0.0
		const z_variation = 0.0
		#var upward_force = randf_range(9.5, 10.0)
		var upward_force = 10.0
		
		# Angle the impulse back toward the opposite side based on where
		# this rock currently sits along the X axis.
		x_variation += _get_position_angle_bias(body.global_position.x)
		
		var impulse = Vector3(x_variation, upward_force, z_variation) * pulse_magnitude
		
		body.apply_central_impulse(impulse)

		counter += 1
		
		await get_tree().create_timer(0.1).timeout
		#var rand_dur = [0.01,0.1,0.2,0.3].pick_random()
		#await get_tree().create_timer(rand_dur).timeout
		#await get_tree().create_timer(0.1).timeout
		#spin_rocks()
		#await get_tree().create_timer(0.2).timeout
		
		if counter >= rocks_limit:
			break

	#spin_rocks()
	


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
	for idx in range(_sequence.size() - 1, -1, -1):
		var entry = _sequence[idx]

		if entry is Dictionary:
			var cmd: String = entry.get('cmd', '')
			if cmd != 'rock' and cmd != 'black':
				_sequence.remove_at(idx)
				continue
			# Waves 2/3: randomise column exactly like the old int shuffle.
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
