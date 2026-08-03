extends Node3D

@export var left_marker: Marker3D
@export var right_marker: Marker3D
@export var round_manager: RoundManager

@export var blue_balloon : Node3D

@export var pineapples_from_any_direction := false
@export var pineapple_spawn_radius := 12.0

@export var pineapple_aim_offset := 3.0
@export var pineapple_hit_chance := 0.3 # 30% hit directly, 70% miss

# How often (seconds) to poll the destroyed-count while waiting for the round to end.
const POLL_INTERVAL := 0.25

var pineapples: Array[RigidBody3D] = []
var _total_launched: int = 0

@export var oranges := false
var done_once_in_round := false

func _ready() -> void:
	_collect_pineapples()
	#if oranges:
		#EventBus.instance.bonus_oranges.connect(start_bonus_oranges)
		#EventBus.instance.egg_pulsed.connect(reset_oranges)
		

func reset_oranges() -> void:
	done_once_in_round = false

func start_bonus_oranges() -> void:
	await get_tree().create_timer(1.0, false).timeout

	var active_oranges: Array = []
	var active_counter := 0
	for body in get_children():

		if active_counter >= 3:
			active_counter = 0
			break

		launch_pineapple(body)
		active_counter += 1
		active_oranges.append(body)
		await get_tree().create_timer(0.02).timeout

	# Wait until every launched orange has been destroyed.
	while active_oranges.size() > 0:
		print("STILL ",  active_oranges.size())
		for i in range(active_oranges.size() - 1, -1, -1):
			if active_oranges[i].rock_destroyed:
				active_oranges.remove_at(i)
		
		await get_tree().process_frame

	await get_tree().create_timer(1.0).timeout
	print('MOVING ON FROM BONUS ORANGE')
	
	round_manager.bonus_oranges_ready = false

func _collect_pineapples() -> void:
	pineapples.clear()
	for child in get_children():
		if child is RigidBody3D:
			pineapples.append(child)


func start_bonus_round() -> void:
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	_total_launched = 0

	%PerfectParticles.emitting = true
	%PerfectParticles2.emitting = true

	await get_tree().create_timer(1.0, false).timeout
	await get_tree().create_timer(1.0, false).timeout

	# Launch every pineapple from the left or right.
	for body in pineapples:
		launch_pineapple(body)
		_total_launched += 1
		#await get_tree().create_timer(randf_range(0.1,0.33)).timeout
		await get_tree().create_timer(0.5, false).timeout
			
	# Wait until every launched pineapple has been destroyed, then wrap up.
	await _wait_for_all_destroyed()
	stop_pineapples()


func _wait_for_all_destroyed() -> void:
	while gl_PlayerState.dataset.power_bonus_round_pineapples < _total_launched:
		await get_tree().create_timer(POLL_INTERVAL).timeout


func stop_pineapples() -> void:
	await get_tree().create_timer(2.0, false).timeout
	for body in pineapples:
		body.reset_stats()

	#if round_manager:
		#round_manager.on_bonus_round_finished()


func launch_pineapple(body: RigidBody3D) -> void:
		
	if blue_balloon == null:
		return
		
	body.update_active()

	var force = (
		#randf_range(9.5, 10.0)
		6.0
		* body.force_multiplier
		* 1.5
		* body.pulse_magnitude
	)

	# New behaviour for bonus pineapples.
	if pineapples_from_any_direction:
		var angle := randf() * TAU

		var spawn_pos := blue_balloon.global_position + Vector3(
			cos(angle) * pineapple_spawn_radius,
			sin(angle) * pineapple_spawn_radius,
			0.0
		)

		body.global_position = spawn_pos

		# Optional: keep exit_side sensible.
		body.exit_side = (
			body.ExitSide.RIGHT
			if spawn_pos.x < blue_balloon.global_position.x
			else body.ExitSide.LEFT
		)

		var target := blue_balloon.global_position

		# Most pineapples miss the balloon.
		if randf() > pineapple_hit_chance:
			var offset := Vector3(
				randf_range(-pineapple_aim_offset, pineapple_aim_offset),
				randf_range(-pineapple_aim_offset, pineapple_aim_offset),
				0.0
			)
			target += offset

		var direction := (target - spawn_pos).normalized()
		
		body.apply_central_impulse(direction * force)
		var torque_axis := Vector3.FORWARD.cross(direction).normalized()
		body.apply_torque_impulse(torque_axis * 3000.0)
		
	else:
		# Original left/right launch.
		var shoot_from_left := randf() < 0.5

		if shoot_from_left:
			body.exit_side = body.ExitSide.RIGHT
			body.global_position = left_marker.global_position
			body.global_position.y = randi_range(1, 7)
			body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
		else:
			body.exit_side = body.ExitSide.LEFT
			body.global_position = right_marker.global_position
			body.global_position.y = randi_range(1, 7)
			body.apply_central_impulse(Vector3(force, 0.0, 0.0))

	body.start_timer()

func Xlaunch_pineapple(body: RigidBody3D) -> void:
	body.update_active()

	# 50/50 chance of launching left->right or right->left.
	var shoot_from_left := randf() < 0.5

	var force = (
		randf_range(9.5, 10.0)
		* body.force_multiplier
		* 1.5
		* body.pulse_magnitude
	)

	if shoot_from_left:
		body.exit_side = body.ExitSide.RIGHT
		body.global_position = left_marker.global_position
		body.global_position.y = randi_range(1,7)
		body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
	else:
		body.exit_side = body.ExitSide.LEFT
		body.global_position = right_marker.global_position 
		body.global_position.y = randi_range(1,7)
		body.apply_central_impulse(Vector3(force, 0.0, 0.0))

	body.start_timer()
	
	
#func _input(event: InputEvent) -> void:
	#if Input.is_action_just_pressed('left'):
		#start_bonus_round()
	#
	#if Input.is_action_just_pressed('right'):
		#stop_pineapples()
