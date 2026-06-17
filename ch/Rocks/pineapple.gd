extends RigidBody3D

const ON_TARGET_SFX = preload('res://sfx/opt_3_fade_shortened.wav')

@export var cash_value := 10
@export var force_multiplier := 1.5
var pitch_adjustment := 0.02

@onready var main_col: CollisionShape3D = $main_col


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
@onready var pineapple_mesh:= $Mesh/small_rock

@onready var current_mesh : MeshInstance3D= pineapple_mesh

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
	EventBus.instance.open_shop.connect(update_disabled)
	await get_tree().create_timer(0.2).timeout
	
	enter_state(State.INACTIVE)



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
	enable_collision()
	reset_stats()
	reset_rock_back_on()
	add_to_group('Target')
	update_gravity(0.04)
	rock_activated = true
	global_position = start_pos
	global_position.x = randi_range(-8,8)
	health = 1

	pineapple_mesh.show()
	rock_activated = true
	pineapple_mesh.scale = Vector3.ONE * 2
	$Mesh.show()
	$Start_falling_timer.start(2.2)

	#var x_variation = randf_range(-1.0, 1.0)
	#const z_variation = 0.0
	#var upward_force = randf_range(9.5, 10.0)
	#var impulse = Vector3(x_variation, upward_force * force_multiplier, z_variation) * pulse_magnitude
	#apply_central_impulse(impulse)

	$explosion_sfx.play()
	$Smoke_quick.emitting = true
	apply_torque_impulse(Vector3.RIGHT * 3000.0)
	
	$Pineapple_launch_sound.play()
	
	#apply_hit_reaction(Vector2.ZERO)
	
func update_hit() -> void:
	update_gravity(1.0)
	$Pineapple_sound_hit.play()
	#disable_collision()
	gl_PlayerState.log_hit('pineapple', 'pineapple', cash_value)
	#gl_PlayerState.add_cash(cash_value)
	$Pineapple_shot_explode.play()
	
	await get_tree().create_timer(0.3).timeout
	$Pineapple_destroyed.play()
	
func update_missed() -> void:
	reset_stats()

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
			print("We are in some other state ", current_state)

func update_disabled() -> void:
	update_gravity(1.0)
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)

func enable_collision() -> void:
	return
	set_collision_layer_value(1, true)


func update_gravity(_gravity_scale : float) -> void:
	gravity_scale = _gravity_scale

func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "Small Rock"
	rock_type_name 		= "rock_type_1"

	var base_health := int(gl_DataSet.get_value("rock_type_1", 1))

	var base_scale  := Vector3.ONE * 0.35

	# Random subtype: 1x / 2x / 3x

	$Mesh.scale = Vector3.ONE
	health = base_health
	#cash_value = base_cash # * size_multiplier
	max_health = health
	pineapple_mesh.visible = true

	current_mesh = pineapple_mesh
	current_mesh.scale = base_scale
	rock_type_gravity_scale = 0.2
			

func reset_stats() -> void:
	$Mesh.scale = Vector3.ONE
	$Mesh.show()
	
	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = pineapple_mesh
	current_rock_type = ""
	rock_type_name = ""
	health = 0

	
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
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished

	

func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func apply_hit_reaction(screen_offset : Vector2) -> void:

	gravity_scale = 0.1
	linear_velocity = Vector3.ZERO
	
	var camera = get_viewport().get_camera_3d()

	if camera == null:
		return

	# Convert screen offset into camera-space directions
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	var force_dir = (right * screen_offset.x) + (up * -screen_offset.y)

	force_dir = force_dir.normalized()
	
	if force_mult_index >= force_mult.size() - 1:
		force_mult_index = 0
	else:
		force_mult_index += 1
	
	apply_central_impulse(force_dir * force_mult[force_mult_index])	

	# spin a bit too
	var torque_dir = Vector3(
		force_dir.z,
		1.0,
		-force_dir.x
	).normalized()
	
	torque_dir = torque_dir * force_mult[force_mult_index]

	apply_torque_impulse(torque_dir * hit_torque_strength)

	smoke_particles_duplicates()

	# Quick squash/stretch feedback
	if current_mesh.scale <= Vector3.ONE * 0.3:
		current_mesh.get_node('damage_mesh').show()
		await get_tree().create_timer(0.08).timeout
		current_mesh.get_node('damage_mesh').hide()
		gravity_scale = rock_type_gravity_scale
		print('true')
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
	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)
		return
	
	start_destroyed_process()
	



func bounce_rocks() -> void:
	update_gravity(0.04)
	global_position = start_pos

func start_destroyed_process() -> void:

	if !rock_activated:
		return
		
	#$Mesh/Yellow_particles.emitting = true
	rock_activated = false
	enter_state(State.HIT)
	
	#if !destroyed_by_marked:
	
	remove_from_group('Target')
	print("reaching")
	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
		
	
	money_label_3d.money_is_money(global_position, cash_value)
	
	set_collision_layer_value(1, false)
	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	print("or not")
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	await tween.finished

	shake_camera()

	print("all the way")
	

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
	
	if current_rock_type == 'Gold':
		gravity_scale = 0.4
		return
		
	

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
	

func play_accurate_sounds() -> void:
	#await get_tree().create_timer(0.05).timeout
	create_shot_instance(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05
	

func create_shot_instance(sound_file : AudioStreamWAV, volume_db : float, pitch_scale : float) -> void:
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
