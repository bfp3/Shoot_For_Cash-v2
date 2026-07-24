extends RigidBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')

var cash_value := 0
var original_cash_value := 0

@export var force_multiplier := 1.5
var pitch_adjustment := 0.02
var taken_hit = false
@onready var main_col: CollisionShape3D = $main_col

enum ExitSide {
	LEFT,
	RIGHT,
	TOP
}

var exit_side : ExitSide

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}
@export var pulse_magnitude := 0.8

var current_state : State


var	force_mult : Array = [3,4]
var force_mult_index := 0

var rock_type_gravity_scale := 0.4

@onready var money_label_3d: Label3D = $Money_Label3D
@onready var gold_label_3d: Label3D = $Gold_label3D
@onready var orange_mesh := $Mesh/small_rock

@onready var current_mesh : MeshInstance3D= orange_mesh

var max_health : int = 0


@export var hit_torque_strength := 5.0
@export var hit_upward_force := 2.0


var rock_activated := false
var rock_destroyed := true
var is_deactivated := false
var health := 0
var start_pos : Vector3

var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false



func _ready() -> void:
	
	start_pos = global_position
	
	EventBus.instance.oranges_start_falling.connect(start_falling)
	EventBus.instance.open_shop.connect(update_disabled)
	await get_tree().create_timer(0.2).timeout
	
	enter_state(State.INACTIVE)

	
	cash_value = int(gl_DataSet.get_value('orange', 0))
	original_cash_value = cash_value

func start_falling() -> void:
	apply_hit_reaction(Vector2.UP)
	disable_collision()
	await get_tree().create_timer(0.15).timeout
	update_gravity(5.0)
	linear_damp = 0.0
	
	
func enter_state(new_state : State) -> void:

	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()
			
		State.ACTIVE:
			update_active()

		State.MISSED:
			update_missed()
		
		State.HIT:
			update_hit()
			
		State.DISABLED:
			update_disabled()

		
			
func update_inactive() -> void:
	force_mult.shuffle()
	disable_collision()
	reset_stats()
	# EventBus.instance.rock_created.emit()
	
func update_prepare_rock() -> void:
	reset_stats()
	await get_tree().process_frame
	force_mult.shuffle()
	await get_tree().process_frame
	
func update_active() -> void:
	disable_collision()
	enable_collision()
	%GoldParticles.emitting = true
	reset_stats()
	reset_rock_back_on()
	add_to_group('Target')
	#update_gravity(0.0)
	update_gravity(0.01)
	global_position = start_pos
	global_position.x = randi_range(-8,8)
	health = 1
	linear_damp = 5.0
	orange_mesh.show()
	rock_activated = true

	$Mesh.show()
	$Start_falling_timer.start(2.2)
	
	$explosion_sfx.play()
	$Smoke_quick.emitting = true
	
	#apply_torque_impulse(Vector3.RIGHT * 1000.0)
	apply_torque_impulse(Vector3.UP * 1000.0)
	
	$Pineapple_launch_sound.play()
	
	#apply_hit_reaction(Vector2.ZERO)
	
func update_hit() -> void:
	update_gravity(1.0)
	%GoldParticles.emitting = false
	$Pineapple_sound_hit.play()
	disable_collision()
	gl_PlayerState.log_hit('orange', 'orange', cash_value)
	$Pineapple_shot_explode.play()
	
	await get_tree().create_timer(0.3).timeout
	$Pineapple_destroyed.play()
	
func update_missed() -> void:
	reset_stats()
	disable_collision()

func round_end_check_rock_status() -> void:
	
	match current_state:
		State.HIT:
			pass
			
		State.MISSED:
			pass
			
		
		State.INACTIVE:
			pass
			
		State.ACTIVE:
			enter_state(State.DISABLED)
			
		_:
			print("We are in some other state pineapple", current_state)

func update_disabled() -> void:
	update_gravity(1.0)
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(8, false)
	
	set_collision_mask_value(8, false)
	set_collision_mask_value(1, false)
	
func enable_collision() -> void:
	set_collision_layer_value(8, true)
	#return
	
	
	
	set_collision_layer_value(8, true)
	set_collision_mask_value(8, true)
	set_collision_mask_value(1, true)
	set_collision_layer_value(1, true)


func update_gravity(_gravity_scale : float) -> void:
	gravity_scale = _gravity_scale
	pass

func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "Small Rock"
	rock_type_name 		= "rock_type_1"

	var base_health := int(gl_DataSet.get_value("rock_type_1", 1))

	#var base_scale  := Vector3.ONE * 2 #* 0.35

	# Random subtype: 1x / 2x / 3x
	$hit_wall_timer.stop()
	$Mesh.scale = Vector3.ONE
	health = base_health
	#cash_value = base_cash # * size_multiplier
	max_health = health
	orange_mesh.visible = true
	main_col.scale = Vector3.ONE #base_scale
	current_mesh = orange_mesh
	current_mesh.scale = Vector3.ONE * 2#base_scale
	#current_mesh.scale.x = base_scale.x
	#current_mesh.scale.y = 1.471
	#current_mesh.scale.z = base_scale.z
	
	rock_type_gravity_scale = 0.2
	show()

func reset_stats() -> void:
	hide()
	$Mesh.scale = Vector3.ONE
	$Mesh.show()
	$hit_wall_timer.stop()
	pitch_adjustment = 0.02
	taken_hit = false
	rock_activated = false
	current_mesh = orange_mesh
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = original_cash_value
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	falling = false
	rock_destroyed = false
	is_deactivated = false
	global_position = start_pos


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished

	

func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func apply_hit_reaction(screen_offset : Vector2) -> void:

	gravity_scale = 0.1
	linear_velocity = Vector3.ZERO
	
	
	
	var camera = get_viewport().get_camera_3d()

	#screen_offset = Vector2.UP

	if camera == null:
		return

	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	var force_dir = (right * screen_offset.x) + (up * -screen_offset.y)
	var vertical_amount = force_dir.dot(up)

	if vertical_amount < 0.0:
		force_dir -= up * vertical_amount
		force_dir += up * 0.15

	force_dir = force_dir.normalized()
	apply_central_impulse(force_dir * force_mult[force_mult_index])

	# spin a bit too
	var torque_dir = Vector3(
		force_dir.z,
		1.0,
		-force_dir.x
	).normalized()
	
	torque_dir = torque_dir * force_mult[force_mult_index]
	apply_torque_impulse(torque_dir * hit_torque_strength)

	

	# Quick squash/stretch feedback
	if current_mesh.scale <= Vector3.ONE * 0.3:
		current_mesh.get_node('damage_mesh').show()
		await get_tree().create_timer(0.08).timeout
		current_mesh.get_node('damage_mesh').hide()
		gravity_scale = rock_type_gravity_scale

		return
		
	if current_mesh:
		var original_scale := current_mesh.scale
		current_mesh.get_node('damage_mesh').show()
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			current_mesh,
			"scale",
			original_scale * 0.85,
			0.08
		)

		tween.tween_property(
			current_mesh,
			"scale",
			original_scale,
			0.12
		)
		
		await tween.finished
		current_mesh.get_node('damage_mesh').hide()
	
	gravity_scale = rock_type_gravity_scale
	

		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	health -= damage
	taken_hit = true
	smoke_particles_duplicates()
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)
		return
	
	rock_destroyed = true
	start_destroyed_process()
	



func bounce_rocks() -> void:
	update_gravity(0.04)
	#update_gravity(0.0)
	global_position = start_pos

func start_destroyed_process() -> void:

	if !rock_activated:
		return
		
	
	expand_blast_radius()
	
	#$Mesh/Yellow_particles.emitting = true
	rock_activated = false
	#rock_destroyed = true
	freeze = true
	enter_state(State.HIT)
	
	#if !destroyed_by_marked:
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager:
		round_manager.orange_active -= 1
	
	remove_from_group('Target')

	play_destroy_sfx()
		
	gl_PlayerState.add_bonus(cash_value)
	money_label_3d.money_is_money(global_position, cash_value)
	

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	
#
	#var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	#await tween.finished

	shake_camera()
	

func play_hit_sfx() -> void:
	$take_damage_sfx.volume_db = randf_range(-25.0, -20.0)
	$take_damage_sfx.pitch_scale = randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05).timeout
	$take_damage_sfx.play(0.01)
	await get_tree().create_timer(0.1).timeout
	$take_damage_sfx.play(0.02)


func play_destroy_sfx() -> void:
	$take_damage_sfx.play(0.02)
	await get_tree().create_timer(0.1).timeout
	$hitSound.play()
	await get_tree().create_timer(0.1).timeout
	$explosion_sfx.play()
	

func _on_start_falling_timer_timeout() -> void:
	falling = true
	linear_damp = 0.0

func smoke_particles() -> void:
	$AoE.global_position = global_position
	$AoE.play_particles = true


func smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick.duplicate()

	if !_new_particles:
		return
		
	_new_particles.add_to_group("smoke_particles")
	_new_particles.emitting = true
	_new_particles.duplicate_particles = true
	_new_particles.show()
	add_child(_new_particles)
	#get_tree().get_current_scene().add_child(_new_particles)
	_new_particles.global_position = global_position
	
	var _new_sparks : GPUParticles3D = $Sparks01.duplicate()
	if !_new_sparks:
		return
	_new_sparks.show()
	_new_sparks.finished.connect(_new_sparks.queue_free)
	get_tree().get_current_scene().add_child(_new_sparks)
	_new_sparks.global_position = global_position
	_new_sparks.emitting = true
	

func start_bullet_to_target() -> void:
	play_accurate_sounds()
	
	
func play_accurate_sounds() -> void:
	#await get_tree().create_timer(0.05).timeout
	create_shot_instance(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05
	

func create_shot_instance(sound_file : AudioStream, volume_db : float, pitch_scale : float = 0.02) -> void:
	var sound_instance = AudioStreamPlayer.new()
	sound_instance.name = str(sound_file)
	add_child(sound_instance)
	sound_instance.stream = sound_file
	sound_instance.volume_db = clamp(volume_db, -80.0,-10.0)
	sound_instance.pitch_scale = pitch_scale
	sound_instance.play()
	await sound_instance.finished
	
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()
		
func hit_out_of_bounds() -> void:
	if !rock_activated:
		return
	rock_activated = false
	rock_destroyed = true
	set_collision_layer_value(1, false)
	set_collision_layer_value(8, false)
	#current_mesh.get_node('damage_mesh').show()
	#await get_tree().create_timer(0.28).timeout
	#current_mesh.get_node('damage_mesh').hide()
	
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager:
		round_manager.orange_active -= 1
	
	freeze = true

	remove_from_group('Target')

	# Same explosion feedback as a normal destroy

	#play_destroy_sfx()
	#$Pineapple_sound_hit.play()


	# Penalize instead of reward
	gl_PlayerState.log_hit('orange', 'orange', 0)
	money_label_3d.money_is_money(global_position, 0)


	is_deactivated = true


	hit_wall_effects()
	$Mesh.hide()
	#var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	#await tween.finished

	

	#await get_tree().create_timer(0.3).timeout
	#$Pineapple_destroyed.play()

	enter_state(State.MISSED)

func hit_wall_effects() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property($AoE2Fail, "play_particles", true, 0.10)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished

func check_position_for_wall() -> void:
	var bottom_y := -3.0
	match exit_side:
		ExitSide.LEFT:
			
			if global_position.x > 15.5 || global_position.y <= bottom_y:
				hit_out_of_bounds()
			#if global_position.x > -18.5:
				#hit_out_of_bounds()

		ExitSide.RIGHT:
			if global_position.x < -15.5 || global_position.y <= bottom_y:
				hit_out_of_bounds()
			#if global_position.x > 15.5:
				#hit_out_of_bounds()

		ExitSide.TOP:
			if global_position.y > 9.0 || global_position.y <= bottom_y:
				hit_out_of_bounds()
				
		

func start_timer() -> void:
	$hit_wall_timer.start()

func _on_hit_wall_timer_timeout() -> void:
	check_position_for_wall()
	if is_deactivated:
		$hit_wall_timer.stop()
		return
		
	else:
		$hit_wall_timer.start()


func _on_explosion_area_body_entered(body: Node3D) -> void:

	#if body.name.contains('Balloon'):
		#if body.balloon_type == body.BalloonType.BLUE:
			#return
		#body.destroyed_by_shratnel()
	
	#if body.name.contains('range') || body.name.contains('apple'):
	if body.name.contains('apple'):
		body.start_destroyed_process()

	
	if body is RockInstance:
		if body.rock_type == body.RockSize.HAZARD:
			var strength : float = [2.0,3.0].pick_random()
			body.apply_central_impulse(body.global_position - global_position * strength)
			return

		body.hit_by_player(100, Vector2.ZERO)
	
func expand_blast_radius() -> void:
	#return
	const domain_expansion : float = 14.0
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.2
	#%explosion_radius_mesh.transparency = 1.0
	var blast_node : Area3D = %Explosion_area
	blast_node.scale = Vector3.ONE
	blast_node.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * domain_expansion, 0.25)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.45)
	#tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE

	blast_node.hide()
	blast_node.monitoring = false
