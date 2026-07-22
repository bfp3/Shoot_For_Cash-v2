extends RigidBody3D
class_name RockInstance

@onready var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')

@export var freeze_mine := false
var sky_mine_blast_radius := 5.0 #15.0

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
var start_exploding := false
var pitch_adjustment := 0.02

var rock_type := 0

var current_particles : GPUParticles3D = null

const ROCK_01 = preload('uid://c2pmyrm3e4ty5')
const ROCK_02 = preload('uid://84ianb3xwjp7')
const ROCK_03 = preload('uid://lxbrgqaovv68')
#const ROCK_04 = preload('uid://g2r7kpvm47k0')


const ROCK_MESHES = [
	ROCK_01,
	ROCK_02,
	ROCK_03,
	#ROCK_04
]

enum RockSize {
	SMALL,
	SMALL_2,
	MEDIUM,
	LARGE,
	HAZARD,
	HUGE,
	HAZARD_SMALL,
	MONEY_ROCK
}

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}

var current_state : State = State.INACTIVE

var rock_has_been_logged := false

@onready var money_label_3d: Label3D = $Money_Label3D
@onready var gold_label_3d: Label3D = $Gold_label3D
@onready var damage_label_3d: Label3D = %Damage_Label3D
@onready var health_remaining_label: Label3D = %Health_remaining_label

@onready var main_col: CollisionShape3D = $main_col
@onready var mesh_container: Node3D = %Mesh

@onready var small_rock: MeshInstance3D = %small_rock
@onready var medium_rock: MeshInstance3D = %medium_rock
@onready var large_rock: MeshInstance3D = %Large_rock
@onready var gold_rock: MeshInstance3D = %Gold_rock
@onready var huge_rock: MeshInstance3D = %Huge_rock
@onready var red_rock: MeshInstance3D = %Red_rock
@onready var hazard_large: MeshInstance3D = %Hazard_large

@onready var current_mesh: MeshInstance3D = small_rock


var hit_torque_strength := 5.0
var max_health : int = 0
var tween_sight_icon : Tween = null 

var cash_value := 0
var current_cash_multiplier := 1
var rock_activated := false

var force_mult : Array = [3,4]
var force_mult_index := 0

var rock_type_gravity_scale := 0.4
var cash_per_hit := 0
var health := 0

var is_deactivated := false
var rock_destroyed := true
var player_has_marked_rock := false
var start_pos : Vector3
var target_x_position : float = 0.0


var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false



func _ready() -> void:
	
	start_pos = global_position
	target_x_position = start_pos.x
	
	await get_tree().create_timer(0.2).timeout
	
	#EventBus.instance.all_rocks_destroyed.connect(hazard_disappear)
	enter_state(State.INACTIVE)


func enter_state(new_state : State) -> void:

	current_state = new_state
	
	
	match new_state:
		State.INACTIVE:
			update_inactive()
			
		State.PREPARE_ROCK:
			update_prepare_rock()
			
		State.ACTIVE:
			update_active()

		State.MISSED:
			update_missed()
		
		State.HIT:
			update_hit()
			
		State.DISABLED:
			update_disabled()

		
			

func update_inactive() -> void:
	hide_all_meshes()
	force_mult.shuffle()
	disable_collision()
	reset_stats()
	# EventBus.instance.rock_created.emit()
	
func update_prepare_rock() -> void:
	reset_stats()
	await get_tree().process_frame
	hide_all_meshes()
	force_mult.shuffle()
	await get_tree().process_frame
	setup_rock_type()
	if rock_type_name != 'hazard_type_1':
		gl_PlayerState.log_rocks(1, rock_type_name)
		
	await get_tree().create_timer(0.2).timeout
	global_position.x = target_x_position
	
func update_active() -> void:
	enable_collision()
	add_to_rocks_round()
	
	%launch_sound.pitch_scale = randf_range(3.0,3.2)
	%launch_sound.play()


func update_hit() -> void:
	update_gravity(1.0)
	linear_velocity = Vector3.ZERO
	gravity_scale = 0.0
	await get_tree().create_timer(1.0).timeout
	disable_collision()
	

func update_missed() -> void:
	disable_collision()
	remove_from_group('Target')
	rock_destroyed = true
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
			
		State.PREPARE_ROCK:
			pass
			
		State.DISABLED:
			pass
			
		_:
			print("We are in some other state rock instance ", current_state)


func update_disabled() -> void:
	update_gravity(1.0)
	await get_tree().create_timer(2.0).timeout
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)
	$Explosion_area.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true

func enable_collision() -> void:
	set_collision_layer_value(1, true)


func update_gravity(_gravity_scale : float) -> void:
	for i in range(3):
		#gravity_scale = _gravity_scale
		gravity_scale = 0.15
		#linear_damp = 0.0
		await get_tree().create_timer(0.1).timeout
	
	if rock_activated:
		await get_tree().create_timer(1.5).timeout
		linear_damp = 0.0

func hide_all_meshes() -> void:
	small_rock.visible			= false
	medium_rock.visible 		= false
	gold_rock.visible			= false
	large_rock.visible 			= false
	huge_rock.visible 			= false
	hazard_large.visible 		= false
	red_rock.visible			= false




func reset_rock_back_on() -> void:
	enter_state(State.MISSED)


func setup_rock_type() -> void:
	current_mesh.scale = Vector3.ONE
	
	match rock_type:
		# 0
		RockSize.SMALL:
			# Base values

			current_rock_type 	= "Small Rock"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.2 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1
			$Mesh.scale = Vector3.ONE
			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			small_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
			
			current_particles = $Mesh/small_rock/GoldParticles
			current_particles.amount += 1
			current_particles.amount -= 1
			current_particles.emitting = true
		
		# 1
		RockSize.SMALL_2:
			current_rock_type 	= "Small Rock"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			var size_multiplier_float : float = 2.4 #randf_range (1.2, 1.35) * 2
			var size_multiplier_int : int = 2
			$Mesh.scale = Vector3.ONE
			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			small_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
		
		# 2
		RockSize.MEDIUM:
			current_rock_type 	= "Coal"
			rock_type_name 		= "rock_type_2"
			#health 				= int(gl_DataSet.get_value("rock_type_2", 1))
			health 				= 2
			cash_value 			= 1 #int(gl_DataSet.get_value("rock_type_2", 0))
			medium_rock.visible = true
			main_col.scale = Vector3.ONE * 0.225
			current_mesh 		= medium_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.625
			max_health = health
			rock_type_gravity_scale = 0.15
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [2,3]
			force_mult_index = 0
			
		# Rock Type 3
		RockSize.LARGE:
			var base_scale  := Vector3.ONE * 0.35
			var size_multiplier_float : float = 1.2
			#var size_multiplier_int : int = 1
			current_rock_type 	= "Gold"
			rock_type_name 		= "rock_type_2"
			health 				= 1
			max_health = health
			cash_value 			= 0
			large_rock.visible 	= true
			main_col.scale = Vector3.ONE * 0.11  * size_multiplier_float
			current_mesh 		= large_rock
			current_mesh.scale = base_scale * size_multiplier_float
			assign_random_mesh(current_mesh)
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			$Mesh.scale = Vector3.ONE
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
	
		
		
		# Rock Type 4
		RockSize.HAZARD:
			var size_multiplier_float : float = 1.0
			var base_scale  := Vector3.ONE * 0.35
			current_rock_type 	= "Game Ender"
			rock_type_name 		= "hazard_type_1"
			health 				= 1#int(gl_DataSet.get_value("rock_type_2", 1))
			cash_value 			= 0 #int(gl_DataSet.get_value("rock_type_2", 0))
			cash_value = 0	#cash_value * 2
		
			hazard_large.visible = true
			current_mesh.scale = base_scale * size_multiplier_float
			main_col.scale = Vector3.ONE * 0.2 #* size_multiplier_float

			current_mesh 		= hazard_large
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.625
			max_health = health
			rock_type_gravity_scale = 0.1
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [4,6,7]
			force_mult_index = 0
		
		
		


#
		#RockSize.LARGE:
			#current_rock_type 	= "Gold"
			#rock_type_name 		= "rock_type_3"
			#health 				= int(gl_DataSet.get_value("rock_type_3", 1))
			#cash_value 			= int(gl_DataSet.get_value("rock_type_3", 0))
			#large_rock.visible 	= true
			#main_col.scale 		= Vector3.ONE * 0.3
			#current_mesh 		= large_rock
			#assign_random_mesh(current_mesh)
			#current_mesh.scale  = Vector3.ONE * 0.7
			#max_health = health
			#rock_type_gravity_scale = 0.4
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [3,4]
			#force_mult_index = 0
			
		RockSize.HUGE:
			current_rock_type 	= "Red Rock"
			rock_type_name 		= "rock_type_4"
			health 				= int(gl_DataSet.get_value("rock_type_4", 1))
			cash_value 			= int(gl_DataSet.get_value("rock_type_4", 0))
			huge_rock.visible 	= true
			main_col.scale 		= Vector3.ONE * 0.3
			current_mesh 		= huge_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.7
			max_health = health
			rock_type_gravity_scale = 0.8
			linear_damp = 0.5
			force_mult = [2,3]
			force_mult_index = 0
			
		RockSize.HAZARD_SMALL:
			current_rock_type 	= "Hazard Large"
			rock_type_name		= "hazard_type_1"
			health 				= int(gl_DataSet.get_value("hazard_type_1", 1))
			#cash_value 			= int(gl_DataSet.get_value("hazard_type_1", 0))
			cash_value 			= int(gl_PlayerState.dataset.cash / 8)
			hazard_large.visible = true
			main_col.scale = Vector3.ONE * 0.75
			current_mesh 		= hazard_large
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 1.5 #* 0.399
			max_health = health
			rock_type_gravity_scale = 0.1
			gl_PlayerState.log_hazard()
			linear_damp = 1.0
			force_mult = [1,2]

func reset_stats() -> void:
	$Mesh.scale = Vector3.ONE
	$Marked.hide()
	$Freeze.hide()
	$Mesh.hide()
	start_exploding = false
	
	await get_tree().process_frame
	

	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = small_rock
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = 0
	linear_damp = 0.5
	rock_has_been_logged = false
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	falling = false
	rock_destroyed = false
	player_has_marked_rock = false
	is_deactivated = false
	global_position = start_pos
	await get_tree().process_frame
	
	$Mesh.show()


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished

	
func detonate_rock() -> void:
	start_destroyed_process()
	expand_blast_radius()

	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_sky_mines()

func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func apply_marked_ability() -> void:
	#if player_has_marked_rock:
		#return
	
	player_has_marked_rock = true
	freeze = true
	
	if freeze_mine:
		$Freeze.show()
		$freeze_embers.emitting = true
	
	else:
		$Marked.show()
		$marked_embers.emitting = true
	
	
	
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.remove_sky_mine()

	
	
	await get_tree().create_timer(0.15).timeout
	$marked_sfx.play()
	
	
	await get_tree().create_timer(0.5).timeout
	detonate_rock()
	
func apply_hit_reaction(screen_offset: Vector2, accurate_direction := true) -> void:
	
	gravity_scale = 0.1
	linear_damp = 0.3
	linear_velocity = Vector3.ZERO
	
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var force_dir := get_hit_force_direction(
		camera,
		screen_offset,
		accurate_direction
	)

	if force_mult_index >= force_mult.size() - 1:
		force_mult_index = 0
	else:
		force_mult_index += 1

	apply_central_impulse(force_dir * force_mult[force_mult_index])

	# Spin the rock
	var torque_dir := Vector3(
		force_dir.z,
		1.0,
		-force_dir.x
	).normalized()

	apply_torque_impulse(
		torque_dir * force_mult[force_mult_index] * hit_torque_strength
	)

	smoke_particles_duplicates()


func get_hit_force_direction(
	camera: Camera3D,
	screen_offset: Vector2,
	accurate_direction: bool
) -> Vector3:

	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y

	var force_dir := right * screen_offset.x
	force_dir += up * -screen_offset.y

	if !accurate_direction:
		# Remove downward movement while still allowing upward movement.
		var vertical := force_dir.dot(up)

		if vertical < 0.0:
			force_dir -= up * vertical

	return force_dir.normalized()

func shrink_current_mesh() -> void:
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

		#tween.tween_property(
			#current_mesh,
			#"scale",
			#original_scale,
			#0.12
		#)
		
		await tween.finished
		current_mesh.get_node('damage_mesh').hide()
	
	gravity_scale = rock_type_gravity_scale
	
func display_damage_counter(_damage_output : int) -> void:
	%Damage_Label3D.damage_is_damage(global_position, _damage_output)
	pass

func display_health_counter() -> void:
	pass
	#%Health_remaining_label.health_is_health(global_position, health)
	

#func _on_area_3d_area_entered(area: Area3D) -> void:
	#if !self.is_in_group('Target'):
		#return
	#
	#if area.is_in_group("bullet") and !target_hit:
		##if !has_been_marked:
			##return		
		#hit_by_player(area.power_bullet_damage)
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:	
	
	#freeze_mine = true
	
	if rock_type_name.contains("hazard_type"):
		health -= 1
		
	else:
		health -= damage
		#if damage == 0:
			#cash_value += 10
			#health += 10
			#var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			#tween.tween_property(
				#current_mesh, "scale", current_mesh.scale * 1.1, 0.08)
		
	display_health_counter()
	display_damage_counter(damage)
	
	
	
	#Rock Takes Damage But Is Not Destroyed Process
	#if gl_PlayerState.dataset.power_sky_mine > 0:
	if player_has_marked_rock:
		if gl_PlayerState.dataset.total_hazards > 0:
			gl_PlayerState.dataset.total_hazards = 0
			rock_type_name = 'rock_type_4'
		apply_marked_ability()
		play_hit_sfx()
		return
	
	
		
	if rock_type_name == 'rock_type_3':
		health -= 1
		if health <= 0:
			start_destroyed_process()
		else:
			money_label_3d.money_is_money(global_position, 1)
			%gold_sfx.play()
			play_hit_sfx()
			apply_hit_reaction(screen_offset)
			if damage > 0:
				shrink_current_mesh()
			
			gl_PlayerState.add_cash(1)
		return
	

	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)

		#%explosion_radius_mesh.hide()
		return
	
	
	#Rock Destroyed Process
	start_destroyed_process()
	
	
func add_to_rocks_round() -> void:
	play_piano_note()
	add_to_group('Target')
	%explosion_radius_mesh.hide()

	# Hazards can never be gold

	rock_activated = true

	$Start_falling_timer.start(2.2)


func bounce_rocks() -> void:
	linear_damp = 0.5
	update_gravity(0.04)
	#apply_torque_impulse(Vector3.LEFT * 3000.0)



func start_destroyed_process() -> void:

	if !rock_activated:
		return
	if rock_destroyed:
		return
		
	get_parent().get_parent().get_node('pitch_shift_rock_sound').pitch_scale += 0.05
	get_parent().get_parent().get_node('pitch_shift_rock_sound').volume_db += 1.0
	get_parent().get_parent().get_node('pitch_shift_rock_sound').play()

	
	rock_activated = false
	
	if current_particles != null:
		current_particles.emitting = false
	
	#if player_has_marked_rock == false:
	expand_blast_radius()
	enter_state(State.HIT)
	
	if rock_type == RockSize.SMALL:
		%progress_rock_sound.play()
	
	#if rock_type_name.contains('hazard'):
		#var tweeny = create_tween().set_ease(Tween.EASE_IN)
		#tweeny.tween_property(Engine, "time_scale", 0.01, 0.01)
		#tweeny.tween_interval(0.02)
		#tweeny.tween_property(Engine, "time_scale", 1.0, 0.5)
		#await tweeny.finished
	
	if rock_type_name != 'hazard_type_1':
		var bonus_cash_reward := 0
		var bonus_zones := get_tree().get_first_node_in_group('multi_shot')
		if bonus_zones:
			bonus_cash_reward = bonus_zones.check_if_within_zone(global_position.y)
			
		cash_value += bonus_cash_reward
		
	
	if rock_type_name.contains('hazard'):
		%hazard_hit_sound.play()
		cash_value = -10
	
	
	if !rock_has_been_logged:
		rock_has_been_logged = true

		gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value)
		
	#if !destroyed_by_marked:


	
	
	
	remove_from_group('Target')
	
	play_destroy_sfx()
	$Marked.hide()

	if cash_value > abs(0):
		money_label_3d.money_is_money(global_position, cash_value)
		
	if cash_value < 0:
		money_label_3d.money_is_money(global_position, cash_value)
			
	set_collision_layer_value(1, false)

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	

	#var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	#await tween.finished
	
	if !player_has_marked_rock:
		shake_camera()
	
	

	round_manager.bullet_active = false
	

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
	
	#if current_rock_type == 'Gold':
		#gravity_scale = 0.4
		#return


func assign_random_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	
	var rand_selection = ROCK_MESHES.pick_random()
	mesh_instance.mesh = rand_selection
	mesh_instance.get_child(0).mesh = rand_selection


func _on_explosion_area_body_entered(body: Node3D) -> void:
	#if rock_destroyed:
		#return
	
	# PUSH ROCKS AWAY IN BLAST
	#if player_has_marked_rock == false:
		#if body is RigidBody3D:
			#var force_dir = (body.global_position - global_position)
			#force_dir = force_dir.normalized()	
			#body.apply_central_impulse(force_dir * 2)
			#body.apply_torque_impulse(force_dir * 500.0)
			#return
	
	if body.name.contains('Rock_Instance'):
		if body.current_state != body.State.ACTIVE:
			return
		
		if body.current_rock_type.contains("Ender"):
			body.rock_type_name = 'rock_type_4'
			body.current_rock_type = 'neutralised'
			
		if freeze_mine:
			body.hit_by_player(0, Vector2.ZERO)
			body.get_node('Freeze').show()
			await get_tree().create_timer(0.25).timeout
			body.freeze = true
			await get_tree().create_timer(3.5).timeout
			if body != null:
				body.freeze = false
				body.get_node('Freeze').hide()
				
		else:
			body.start_destroyed_process()
			body.hit_by_player(1, Vector2.ZERO)
	
	if body.name.contains('Balloon'):
		#return
		#if freeze_mine:
			#return
		#if player_has_marked_rock == false:
			#return
		body.destroyed_by_shratnel()



func expand_blast_radius() -> void:
	if !player_has_marked_rock && !start_exploding:
		#gl_PlayerState.dataset.power_sky_mine = clamp(gl_PlayerState.dataset.power_sky_mine -1,0,3)
		standard_blast()
		return
	start_exploding = true
	var _blast_radius := 7.5
	#if gl_PlayerState.dataset.power_sky_mine == 2:
		#blast_radius = 15.0
		#
	#if gl_PlayerState.dataset.power_sky_mine >= 3:
		#blast_radius = 25.0
	if current_rock_type.contains("Ender"):
		_blast_radius = 15.0
		print("WHY NOT")
	print("WHY NOT 2 blast radius ", _blast_radius)
	player_has_marked_rock = false
	gl_PlayerState.dataset.power_sky_mine = clamp(gl_PlayerState.dataset.power_sky_mine - 1,0,3)
	#gl_PlayerState.dataset.power_sky_mine = 0
	
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.0

	var blast_node : Area3D = $Explosion_area
	blast_node.scale = Vector3.ONE
	blast_node.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 27.5, 0.4)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.45)
	#tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	%explosion_radius_mesh.transparency = 0.4
	blast_node.hide()
	blast_node.monitoring = false
	
func standard_blast() -> void:
	var blast_node : Area3D = $Explosion_area
	blast_node.show()
	%explosion_radius_mesh.show()
	blast_node.monitoring = true
	#$Explosion_area/CollisionShape3D.disabled = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 4.0, 0.35) #0.25
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.25)
	tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	%explosion_radius_mesh.transparency = 0.0
	%explosion_radius_mesh.hide()
	blast_node.hide()
	blast_node.monitoring = false
	

func smoke_particles() -> void:
	if rock_type_name.contains('hazard'):
		$Hazard_AoE2.global_position = global_position
		$Hazard_AoE2.play_particles = true
		
	else:
		$AoE.global_position = global_position
		$AoE.play_particles = true


func hazard_smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick.duplicate()

	if !_new_particles:
		return
		
	_new_particles.emitting = true
	_new_particles.duplicate_particles = true
	_new_particles.show()
	get_tree().get_current_scene().add_child(_new_particles)
	_new_particles.global_position = global_position


func smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick #.duplicate()

	if !_new_particles:
		return
		
	#_new_particles.add_to_group("smoke_particles")
	_new_particles.emitting = true
	#_new_particles.duplicate_particles = true
	_new_particles.show()
	#add_child(_new_particles)
	#get_tree().get_current_scene().add_child(_new_particles)
	_new_particles.global_position = global_position
	
	var _new_sparks : GPUParticles3D = $Sparks01 #.duplicate()
	if !_new_sparks:
		return
	_new_sparks.show()
	#_new_sparks.finished.connect(_new_sparks.queue_free)
	#get_tree().get_current_scene().add_child(_new_sparks)
	_new_sparks.global_position = global_position
	_new_sparks.emitting = true
	
	#var _new_sparks : GPUParticles3D = $Sparks01 #.duplicate()
#
	#if !_new_sparks:
		#return
		#
	#_new_sparks.show()
	#_new_sparks.global_position = global_position
	#_new_sparks.emitting = true

func start_bullet_to_target() -> void:
	play_accurate_sounds()
	if rock_type_name.contains('hazard'):
		gl_PlayerState.dataset.total_hazards += 1
		
func play_accurate_sounds() -> void:
	#await get_tree().create_timer(0.05).timeout
	create_shot_instance(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05
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

func play_piano_note() -> void:
	match global_position.x:
		-7.0:
			$"PianoNotes/1".play()
			
		-5.0:
			$"PianoNotes/2".play()
			
		-3.0:
			$"PianoNotes/3".play()
			
		-1.0:
			$"PianoNotes/4".play()
		
		1.0:
			$"PianoNotes/5".play()
			
		3.0:
			$"PianoNotes/6".play()
			
		5.0:
			$"PianoNotes/7".play()
			
		7.0:
			$"PianoNotes/8".play()
		

		

		
		
