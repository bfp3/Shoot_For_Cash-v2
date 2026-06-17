extends Node

@onready var player: Player = get_tree().get_first_node_in_group('Player')
@onready var egg: Egg_Cage = get_tree().get_first_node_in_group('main_egg')

@onready var parent: StaticBody3D = $'../..'

@export var on_target_speed := 1.0
@export var on_target_arc := 1.0

enum ThrowPattern {GENTLE, MEDIUM, HEAVY_AT_ONCE, HEAVY_ONE_AFTER_ANOTHER, ROW_THEN_GROUP}

@export var controlled_pattern := 0

const SPOTTER_PROJECTILE = preload('res://500_sequences/Cannonball_System/Cannonballs/Spotter_projectiles.tscn')
const SMOKESCREEN_ROUND = preload("res://200_characters/Enemy_rocks/smoke_bomb_rigidbody.tscn")

var batches_to_throw := 2
var amount_of_rocks := 1
var time_between_each_rock := 0.5
var time_between_batches := 0.5

var first_throw := true
var currently_throwing := false
var red_count := 0
var throw_pattern_type := ThrowPattern.GENTLE  # Set during pick_throwing_pattern()
var distracting_throw := false
var first_rock_thrown := false
var throwing_interrupted := false


func stop_throwing() -> void:
	throwing_interrupted = true
	currently_throwing = false



func pick_throwing_pattern() -> void:

	#if parent.projectile_throw_cancelled || currently_throwing:
		#return

	if controlled_pattern > ThrowPattern.size():
		throw_pattern_type = randi_range(0, 4)
		
	elif first_throw:
		throw_pattern_type = 0
		first_throw = false
		
	else:
		throw_pattern_type = controlled_pattern
	
	match throw_pattern_type:
		ThrowPattern.GENTLE:
			batches_to_throw = 1
			amount_of_rocks = 1
			time_between_each_rock = 1.5
			time_between_batches = 1.5
			throw_pattern()

		ThrowPattern.MEDIUM:
			batches_to_throw = 1 #randi_range(1, 3)
			amount_of_rocks = 3
			time_between_each_rock = 0 # 0.05 #randf_range(0.3, 0.5)
			time_between_batches = 0.5
			throw_pattern()

		ThrowPattern.HEAVY_AT_ONCE:
			batches_to_throw = 1 #randi_range(1, 2)
			amount_of_rocks = 2 #6
			time_between_each_rock = 0.0
			time_between_batches = 1.5
			throw_pattern()
			
			
		ThrowPattern.HEAVY_ONE_AFTER_ANOTHER:
			batches_to_throw = 10 #randi_range(1, 2)
			amount_of_rocks = 1
			time_between_each_rock =  0.0 #0.25 # 0.3
			time_between_batches = 1.5 # 2.5
			throw_pattern()
			
		ThrowPattern.ROW_THEN_GROUP:
			batches_to_throw = 2
			amount_of_rocks = 6 # first batch only, second will be hardcoded
			time_between_each_rock = 0.3
			time_between_batches = 0.6
			throw_pattern()

			
			
func throw_pattern() -> void:
	currently_throwing = true
	throwing_interrupted = false
	first_rock_thrown = false
	if !distracting_throw:
		red_count = 0

	for batch in range(batches_to_throw):
		if throwing_interrupted:
			return

		if throw_pattern_type == ThrowPattern.ROW_THEN_GROUP and batch == 1:
			for i in range(6):
				if throwing_interrupted:
					return
				spawn_projectile(batch, i)
			await get_tree().create_timer(time_between_batches).timeout
			continue

		for i in range(amount_of_rocks):
			if throwing_interrupted:
				return
			spawn_projectile(batch, i)

			if time_between_each_rock > 0.0:
				await get_tree().create_timer(time_between_each_rock).timeout
				if throwing_interrupted:
					return

		await get_tree().create_timer(time_between_batches).timeout
		if throwing_interrupted:
			return
	
	parent.throwing_finished()
	currently_throwing = false
	distracting_throw = false


func throw_distraction_rocks() -> void:
	if currently_throwing:
		return
	distracting_throw = true
	ThrowPattern.HEAVY_AT_ONCE
	batches_to_throw = 1 #randi_range(1, 2)
	amount_of_rocks = 3 #randf_range(3, 4)
	time_between_each_rock = 0.0
	time_between_batches = 1.5
	fake_mesh_tween()
	

func throw_single() -> void:
	if currently_throwing:
		return
	distracting_throw = true
	ThrowPattern.MEDIUM
	batches_to_throw = 1  #randi_range(1, 2)
	amount_of_rocks = 1
	time_between_each_rock = 0.0
	time_between_batches = 1.0
	throw_pattern()

func fake_mesh_tween() -> void:
	var orig_pos : Vector3 = %Copy_mesh.global_position
	var orig_rot : Vector3 = %Copy_mesh.rotation_degrees
	%Copy_mesh.look_at(parent.egg.global_position, Vector3.UP, false)
	%Copy_mesh.show()
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(%Copy_mesh, "global_position:y", 0.75, 0.25).as_relative()
	tween.parallel().tween_callback(throw_pattern).set_delay(0.1)
	tween.tween_property(%Copy_mesh, "global_position", orig_pos, 0.25)
	await tween.finished
	%Copy_mesh.rotation_degrees = orig_rot
	%Copy_mesh.hide()


func spawn_projectile(batch: int, index: int) -> void:
	
	var rand_chance : int = randi_range(0,6)
	if rand_chance < 1:
		%EnemyPopperThrowRock.pitch_scale = randf_range(0.95,1.05)
		%EnemyPopperThrowRock.play()
		spawn_rigid_body_projectile()
		return
		
	if rand_chance >= 4:
		%EnemyPopperThrowRock.pitch_scale = randf_range(0.95,1.05)
		%EnemyPopperThrowRock.play()
		throw_smokescreen()
		return
	
	%EnemyPopperThrowRock.pitch_scale = randf_range(0.95,1.05)
	%EnemyPopperThrowRock.play()
	
	var new_projectile : Standard_Cannonball = SPOTTER_PROJECTILE.instantiate()
	
	#new_projectile.arc_strength = randf_range(0.25, 0.30)
	new_projectile.arc_strength = randf_range(0.12, 0.15) # overridden
	
	new_projectile.probability_of_special_bomb = 1.0
	#new_projectile.travel_speed = randf_range(5.0, 15.0)
	new_projectile.travel_speed = 1.0
	#new_projectile.scale_multiplier = randf_range(0.5, 2.0)
	

	var targ_colour := get_throw_target_colour(batch, index)

	if targ_colour == "RED":
		new_projectile.travel_speed = on_target_speed # 1.0
		new_projectile.arc_strength = on_target_arc
	
	else:
		new_projectile.travel_speed = on_target_speed
		new_projectile.arc_strength = on_target_arc
		
		#new_projectile.travel_speed = randi_range(4.0, 15.0)
		#new_projectile.arc_strength = randf_range(0.05, 0.20)
		
	get_tree().get_current_scene().add_child(new_projectile)
	new_projectile.global_position = %spawn_projectile_marker.global_position
	new_projectile.target_launcher_fire(targ_colour)



func spawn_rigid_body_projectile() -> void:
	var rotation_torque := -0.01
	var throw_speed_x:= 0.0
	var throw_speed_y := 5.0
	var throw_speed_z := -15.0
	var magnitude := 15.0 #10.0
	var aim_at_player := false
	
	var ROCK_PROJECTILE_RIGIDBODY = preload('res://200_characters/Enemy_rocks/rock_projectile_rigidbody.tscn')
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
	var rotation_torque := -0.01
	var throw_speed_x:= 0.0
	var throw_speed_y := 8.5
	var throw_speed_z := -15.0
	var magnitude := 19.0 #10.0
	var aim_at_player := true
	
	var new_rock: RigidBody3D = SMOKESCREEN_ROUND.instantiate()
	get_tree().get_current_scene().add_child(new_rock)
	new_rock.global_position = %spawn_projectile_marker.global_position # + Vector3(0,1,-3)

	var target_position = player.global_transform.origin #  if aim_at_player else egg.global_transform.origin

	var direction = (target_position - %spawn_projectile_marker.global_position).normalized()
	var impulse = direction.normalized() * magnitude
	new_rock.look_at(target_position, Vector3.UP, true)
	new_rock.linear_velocity = Vector3.UP * throw_speed_y
	new_rock.apply_central_impulse(impulse)
	new_rock.apply_torque_impulse(Vector3(rotation_torque, 0.0, 0.0) * magnitude)



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
		ThrowPattern.GENTLE:
			return "RED"
		
		ThrowPattern.MEDIUM:
			return "RED" if randf() < 0.4 else "GREY"
		
		ThrowPattern.HEAVY_AT_ONCE, ThrowPattern.HEAVY_ONE_AFTER_ANOTHER:
			if red_count < 3:
				var red_chance := 1.0 if red_count == 0 else 0.1
				if randf() < red_chance:
					red_count += 1
					return "RED"
			return "GREY"

	return "GREY"
