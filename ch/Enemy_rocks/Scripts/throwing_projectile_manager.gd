extends Node

@onready var player: Player = get_tree().get_first_node_in_group('Player')
@onready var egg: Egg_Cage = get_tree().get_first_node_in_group('main_egg')

@export var on_target_speed := 1.0
@export var on_target_arc := 1.0

@onready var throw_rock: Node = $Throw_rock
@onready var throw_smoke: Node = $Throw_smoke


enum ThrowPattern {SINGLE, DOUBLE, TRIPLE, DOUBLE_CONSECUTIVE, TRIPLE_CONSECUTIVE, DISTRACTION}

@export var controlled_pattern := 0

var batches_to_throw := 2
var amount_of_rocks := 1
var time_between_each_rock := 0.5
var time_between_batches := 0.5

var first_throw := true
var currently_throwing := false
var red_count := 0
var throw_pattern_type := ThrowPattern.SINGLE 
var distracting_throw := false
var first_rock_thrown := false
var throwing_interrupted := false



func stop_throwing() -> void:
	throwing_interrupted = true
	currently_throwing = false


func prepare_smokebomb(rock_spawn_pos : Vector3) -> void:
	$Throw_smoke.start(rock_spawn_pos)
	
	#$Throw_smokerock.start(rock_spawn_pos)

func prepare_rock(rock_spawn_pos : Vector3, projectile_type : String) -> void:

	#if projectile_throw_cancelled || currently_throwing:
		#return

	if controlled_pattern > ThrowPattern.size():
		throw_pattern_type = randi_range(0, 4)
		
	elif first_throw:
		throw_pattern_type = 0
		first_throw = false
		
	else:
		throw_pattern_type = controlled_pattern
	
	match throw_pattern_type:
		ThrowPattern.SINGLE:
			batches_to_throw = 1
			amount_of_rocks = 1
			time_between_each_rock = 1.5
			time_between_batches = 1.5
			throw_projectile(rock_spawn_pos, projectile_type)

		ThrowPattern.DOUBLE:
			batches_to_throw = 1 #randi_range(1, 3)
			amount_of_rocks = 2
			time_between_each_rock = 0 # 0.05 #randf_range(0.3, 0.5)
			time_between_batches = 0.5
			throw_projectile(rock_spawn_pos, projectile_type)

		ThrowPattern.DOUBLE_CONSECUTIVE:
			batches_to_throw = 1 #randi_range(1, 2)
			amount_of_rocks = 2 #6
			time_between_each_rock = 0.0
			time_between_batches = 1.5
			throw_projectile(rock_spawn_pos, projectile_type)
			
			
		ThrowPattern.TRIPLE_CONSECUTIVE:
			batches_to_throw = 10 #randi_range(1, 2)
			amount_of_rocks = 1
			time_between_each_rock =  0.0 #0.25 # 0.3
			time_between_batches = 1.5 # 2.5
			throw_projectile(rock_spawn_pos, projectile_type)
			
		
		ThrowPattern.DISTRACTION:
			batches_to_throw = 1 #randi_range(1, 2)
			amount_of_rocks = randi_range(3,4)
			time_between_each_rock =  0.0 #0.25 # 0.3
			time_between_batches = 1.5 # 2.5
			throw_projectile(rock_spawn_pos, projectile_type)
			
		#ThrowPattern.ROW_THEN_GROUP:
			#batches_to_throw = 2
			#amount_of_rocks = 6 # first batch only, second will be hardcoded
			#time_between_each_rock = 0.3
			#time_between_batches = 0.6
			#throw_pattern()

			
			
func throw_projectile(rock_spawn_pos : Vector3, projectile_type : String) -> void:
	currently_throwing = true
	throwing_interrupted = false
	first_rock_thrown = false
	if !distracting_throw:
		red_count = 0

	for batch in range(batches_to_throw):
		if throwing_interrupted:
			return

		#if throw_pattern_type == ThrowPattern.ROW_THEN_GROUP and batch == 1:
			#for i in range(6):
				#if throwing_interrupted:
					#return
				#spawn_projectile(batch, i, rock_spawn_pos)
			#await get_tree().create_timer(time_between_batches).timeout
			#continue

		for i in range(amount_of_rocks):
			if throwing_interrupted:
				return
			if projectile_type == 'rock':
				spawn_projectile(batch, i, rock_spawn_pos)
				
			if projectile_type == 'smokebomb':
				spawn_smokebomb_projectile(batch, i, rock_spawn_pos)

			if time_between_each_rock > 0.0:
				await get_tree().create_timer(time_between_each_rock).timeout
				if throwing_interrupted:
					return

		await get_tree().create_timer(time_between_batches).timeout
		if throwing_interrupted:
			return
	
	#parent.throwing_finished()
	currently_throwing = false
	distracting_throw = false


func throw_distraction_rocks() -> void:
	if currently_throwing:
		return
	distracting_throw = true
	ThrowPattern.DISTRACTION
	batches_to_throw = 1 #randi_range(1, 2)
	amount_of_rocks = 3 #randf_range(3, 4)
	time_between_each_rock = 0.0
	time_between_batches = 1.5
	#fake_mesh_tween()
	

#func throw_single() -> void:
	#if currently_throwing:
		#return
	#distracting_throw = true
	#ThrowPattern.SINGLE
	#batches_to_throw = 1  #randi_range(1, 2)
	#amount_of_rocks = 1
	#time_between_each_rock = 0.0
	#time_between_batches = 1.0
	#throw_projectile(rock_spawn_pos)


func spawn_projectile(batch: int, index: int, rock_spawn_pos : Vector3) -> void:
	throw_rock.start(batch, index, rock_spawn_pos)
	return
	
func spawn_smokebomb_projectile(batch: int, index: int, rock_spawn_pos : Vector3) -> void:
	$Throw_smokerock.start(batch, index, rock_spawn_pos)
	return
	
	var rand_chance : int = randi_range(0,6)
	#if rand_chance < 1:
		#throw_rock.
		#
		#spawn_rigid_body_projectile()
		#return
		
	if rand_chance >= 4:
		%EnemyPopperThrowRock.pitch_scale = randf_range(0.95,1.05)
		%EnemyPopperThrowRock.play()
		throw_smokescreen()
		return
	
	else:
		throw_rock.start(batch, index, rock_spawn_pos)

	
		



func spawn_rigid_body_projectile() -> void:
	var rotation_torque := -0.01
	var throw_speed_x:= 0.0
	var throw_speed_y := 5.0
	var throw_speed_z := -15.0
	var magnitude := 15.0 #10.0
	var aim_at_player := false
	
	var ROCK_PROJECTILE_RIGIDBODY = preload('res://ch/Enemy_rocks/rock_projectile_rigidbody.tscn')
	
	var new_rock: RigidBody3D = ROCK_PROJECTILE_RIGIDBODY.instantiate()
	get_tree().get_current_scene().add_child(new_rock)
	new_rock.global_position = %spawn_projectile_marker.global_position

	var target_position = player.global_transform.origin  if aim_at_player else egg.global_transform.origin

	var direction = (target_position - %spawn_projectile_marker.global_position).normalized()
	var impulse = direction.normalized() * magnitude
	new_rock.look_at(target_position, Vector3.UP, true)
	new_rock.linear_velocity = Vector3.UP * throw_speed_y
	new_rock.apply_central_impulse(impulse)
	new_rock.apply_torque_impulse(Vector3(rotation_torque, 0.0, 0.0) * magnitude)


func throw_smokescreen() -> void:
	pass
	#var rotation_torque := -0.01
	#var throw_speed_x:= 0.0
	#var throw_speed_y := 8.5
	#var throw_speed_z := -15.0
	#var magnitude := 19.0 #10.0
	#var aim_at_player := true
	#
	#var new_rock: RigidBody3D = SMOKESCREEN_ROUND.instantiate()
	#get_tree().get_current_scene().add_child(new_rock)
	#new_rock.global_position = %spawn_projectile_marker.global_position # + Vector3(0,1,-3)
#
	#var target_position = player.global_transform.origin #  if aim_at_player else egg.global_transform.origin
#
	#var direction = (target_position - %spawn_projectile_marker.global_position).normalized()
	#var impulse = direction.normalized() * magnitude
	#new_rock.look_at(target_position, Vector3.UP, true)
	#new_rock.linear_velocity = Vector3.UP * throw_speed_y
	#new_rock.apply_central_impulse(impulse)
	#new_rock.apply_torque_impulse(Vector3(rotation_torque, 0.0, 0.0) * magnitude)



func get_throw_target_colour(batch_index: int, rock_index: int) -> String:
	if distracting_throw:
		if red_count < 1:
			red_count += 1
			return "RED"
			
		return "GREY"


	if !first_rock_thrown:
		first_rock_thrown = true
		red_count += 1
		return "RED"

	match throw_pattern_type:
		ThrowPattern.SINGLE:
			return "RED"
		
		ThrowPattern.DOUBLE:
			return "RED" if randf() < 0.4 else "GREY"
		
		ThrowPattern.TRIPLE, ThrowPattern.TRIPLE_CONSECUTIVE:
			if red_count < 3:
				var red_chance := 1.0 if red_count == 0 else 0.1
				if randf() < red_chance:
					red_count += 1
					return "RED"
			return "GREY"

	return "GREY"
