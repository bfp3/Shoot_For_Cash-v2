extends Node3D

@export var left_marker: Marker3D
@export var right_marker: Marker3D
@export var round_manager: RoundManager

# How often (seconds) to poll the destroyed-count while waiting for the round to end.
const POLL_INTERVAL := 0.25

var pineapples: Array[RigidBody3D] = []
var _total_launched: int = 0

@export var oranges := false
var done_once_in_round := false

func _ready() -> void:
	_collect_pineapples()
	if oranges:
		EventBus.instance.bonus_oranges.connect(start_bonus_oranges)
		EventBus.instance.egg_pulsed.connect(reset_oranges)
		

func reset_oranges() -> void:
	done_once_in_round = false

func start_bonus_oranges() -> void:
	
	if done_once_in_round:
		return
	done_once_in_round = true
	
	for body in self.get_children():
		if _total_launched >= 3:
			_total_launched = 0
			break
		launch_pineapple(body)
		_total_launched += 1
		await get_tree().create_timer(0.02).timeout



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

	await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(1.0).timeout

	# Launch every pineapple from the left or right.
	for body in pineapples:
		launch_pineapple(body)
		_total_launched += 1
		await get_tree().create_timer(randf_range(0.1,0.33)).timeout

	# Wait until every launched pineapple has been destroyed, then wrap up.
	await _wait_for_all_destroyed()
	stop_pineapples()


func _wait_for_all_destroyed() -> void:
	while gl_PlayerState.dataset.power_bonus_round_pineapples < _total_launched:
		await get_tree().create_timer(POLL_INTERVAL).timeout


func stop_pineapples() -> void:
	await get_tree().create_timer(2.0).timeout
	for body in pineapples:
		body.reset_stats()

	#if round_manager:
		#round_manager.on_bonus_round_finished()


func launch_pineapple(body: RigidBody3D) -> void:
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
	
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('left'):
		start_bonus_round()
	
	if Input.is_action_just_pressed('right'):
		stop_pineapples()
