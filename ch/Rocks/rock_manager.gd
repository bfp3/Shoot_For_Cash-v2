class_name RockManager
extends Node3D

# I would like you to check which place we are in, and then that will determine the rock limit
# Can you help me?	


enum State {
	INACTIVE,
	PREPARE_ROCKS,
	PULSE_ROCKS,
	ROUND_END,
}

var current_state : State = State.INACTIVE
@export var pulse_magnitude := 0.9
var rocks_limit := 3

@onready var splash_zone: Area3D = %Splash_zone




func _ready() -> void:
	EventBus.instance.egg_pulsed.connect(enter_state.bind(State.PULSE_ROCKS))
	EventBus.instance.all_rocks_destroyed.connect(all_rocks_destroyed)
	EventBus.instance.detonate_sky_mines.connect(detonate_sky_mines)
	enter_state(current_state)

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
	for i in $Container_1.get_children():
		i.enter_state(i.State.INACTIVE)
	
func update_prepare_rocks() -> void:
	splash_zone.reset_detected_bodies()
	rocks_limit = get_rock_limit()
	#rocks_limit = 10
	gl_PlayerState.log_rocks(rocks_limit)
	
	var counter := 0
	for i in $Container_1.get_children():
		i.enter_state(i.State.PREPARE_ROCK)
		counter += 1
		if counter >= rocks_limit:
			break
	
func update_pulse_rocks() -> void:
	splash_zone.activate_splash_zone()
	#if gl_PlayerState.dataset.round <= 1:
		#start_first_round_rock_sequence()
	#
	#else:
	bounce_rocks()
	#tween_rocks()
	
func tween_rocks() -> void:
	var bodies = $Container_1.get_children()
	var counter := 0
	
	for body in bodies:
		if counter >= bodies.size():
			break
		body.enter_state(body.State.ACTIVE)
	
	counter = 0
	
	for body in bodies:
		if counter >= bodies.size():
			break
		
		body.tween_rocks()

		counter += 1
		await get_tree().create_timer(0.1).timeout
		
		if counter >= rocks_limit:
			break

func update_round_end() -> void:
	update_gravity(1.0)
	for body in $Container_1.get_children():
		body.round_end_check_rock_status()


func all_rocks_destroyed() -> void:
	#if gl_PlayerState.dataset.total_rocks_missed == 0:
	$Gold_sfx.play()
	
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



func bounce_rocks() -> void:
	
	var bodies = $Container_1.get_children()

	var counter := 0
	
	for body in bodies:
		if counter >= bodies.size():
			break
		
		body.enter_state(body.State.ACTIVE)
	
	counter = 0
	
	for body in bodies:
		if counter >= bodies.size():
			break
		
		body.bounce_rocks()
		
		#$AnimationPlayer.play('push_up')
		
		var x_variation = randf_range(-2.0, 2.0)
		const z_variation = 0.0
		#var upward_force = randf_range(9.5, 10.0)
		var upward_force = randf_range(9.5, 10.0)
		
		var impulse = Vector3(x_variation, upward_force, z_variation) * pulse_magnitude
		
		body.apply_central_impulse(impulse)

		counter += 1
		
		await get_tree().create_timer(0.1).timeout
		await get_tree().create_timer(0.2).timeout
		
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



func start_first_round_rock_sequence() -> void:
	rocks_limit = 1
	var first_rock = $Container_1/Shootable_object
	first_rock.first_rock()

	var x_variation = randf_range(-2.0, 2.0)
	var z_variation = 0.0
	var upward_force = randf_range(9.5, 10.0)
	var impulse = Vector3(x_variation, upward_force, z_variation) * pulse_magnitude
	first_rock.apply_central_impulse(impulse)

	spin_rocks()
