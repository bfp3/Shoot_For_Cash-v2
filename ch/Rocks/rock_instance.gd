extends RigidBody3D
class_name RockInstance

const ON_TARGET_SFX = preload('res://sfx/opt_3_fade_shortened.wav')
var pitch_adjustment := 0.02

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
	MEDIUM,
	MEDIUM_REDD,
	LARGE,
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

var current_state : State

@onready var money_label_3d: Label3D = $Money_Label3D
@onready var gold_label_3d: Label3D = $Gold_label3D
@onready var damage_label_3d: Label3D = %Damage_Label3D
@onready var health_remaining_label: Label3D = %Health_remaining_label

@export_group('Health Display')
@onready var icon: Sprite3D = %'2d_3d_icon'
var health_green : Color = Color("d3d6cf")
var health_orange : Color = Color(1.0, 0.6, 0.0)
var health_red : Color = Color('870000')

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

var rock_activated := false

var force_mult : Array = [3,4]
var force_mult_index := 0

var rock_type_gravity_scale := 0.4
var cash_per_hit := 0
var health := 0

var has_been_marked := false
var is_deactivated := false
var rock_destroyed := true
var player_has_marked_rock := false
var start_pos : Vector3


var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false


func _ready() -> void:
	
	start_pos = global_position
	
	await get_tree().create_timer(0.2).timeout
	
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
	
func update_active() -> void:
	enable_collision()
	add_to_rocks_round()

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
			
		_:
			print("We are in some other state ", current_state)

func update_disabled() -> void:
	update_gravity(1.0)
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)
	$Explosion_area.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true

func enable_collision() -> void:
	set_collision_layer_value(1, true)


func update_gravity(_gravity_scale : float) -> void:
	gravity_scale = _gravity_scale


func hide_all_meshes() -> void:
	small_rock.visible			= false
	medium_rock.visible 		= false
	gold_rock.visible			= false
	large_rock.visible 			= false
	huge_rock.visible 			= false
	hazard_large.visible 		= false
	red_rock.visible			= false


func choose_rock_type() -> int:
	var area_name: String = gl_PlayerState.dataset.stage_name
	var current_rock_limit: int = gl_PlayerState.dataset.rock_limit
	var allowed_rocks: Array[int] = []

	match area_name:
		"moss":
	
			if current_rock_limit >= 10:
				allowed_rocks.append(RockSize.MEDIUM)

			else:
				allowed_rocks.append(RockSize.SMALL)

				if current_rock_limit > 7:
					var rand_chance := randi_range(0, 3)

					if rand_chance > 1:
						allowed_rocks.append(RockSize.MEDIUM)
						
					
					

		"redd":
			if current_rock_limit >= 10:
				allowed_rocks.append(RockSize.HUGE)

			else:
				allowed_rocks.append(RockSize.MEDIUM_REDD)
				#if current_rock_limit > 5:
					#var rand_chance := randi_range(0, 3)
					#if rand_chance > 2:
						#allowed_rocks.append(RockSize.HAZARD_SMALL)

				if current_rock_limit > 3:
					var rand_chance := randi_range(0, 1)

					if rand_chance > 0:
						allowed_rocks.append(RockSize.LARGE)

		"glory":
			allowed_rocks.append(RockSize.LARGE)

			if current_rock_limit > 5:
				allowed_rocks.append(RockSize.HUGE)

	if allowed_rocks.is_empty():
		return RockSize.SMALL

	return allowed_rocks.pick_random()




func reset_rock_back_on() -> void:
	enter_state(State.MISSED)

func setup_rock_type() -> void:
	current_mesh.scale = Vector3.ONE
	if gl_PlayerState.dataset.rock_limit == 1 && gl_PlayerState.dataset.stage_name == 'moss':
		first_rock()
		return
		
	var rock_size = choose_rock_type()
	
	match rock_size:
		RockSize.SMALL:
			# Base values

			current_rock_type 	= "Small Rock"
			rock_type_name 		= "rock_type_1"

			var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			var size_multiplier : int = [1, 2, 3].pick_random()
			$Mesh.scale = Vector3.ONE
			health = base_health * size_multiplier
			cash_value = base_cash # * size_multiplier
			max_health = health
			update_health_icon()
			small_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125 * size_multiplier
			current_mesh = small_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
		
		RockSize.MEDIUM:
			current_rock_type 	= "Coal"
			rock_type_name 		= "rock_type_2"
			health 				= int(gl_DataSet.get_value("rock_type_2", 1))
			cash_value 			= int(gl_DataSet.get_value("rock_type_2", 0))
			medium_rock.visible = true
			main_col.scale = Vector3.ONE * 0.225
			current_mesh 		= medium_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.625
			max_health = health
			rock_type_gravity_scale = 0.3
			update_health_icon()
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [2,3]
			force_mult_index = 0
			
		RockSize.MEDIUM_REDD:
			current_rock_type 	= "Coal"
			rock_type_name 		= "rock_type_2"
			health 				= int(gl_DataSet.get_value("rock_type_2", 1))
			cash_value 			= int(gl_DataSet.get_value("rock_type_2", 0))
			cash_value = cash_value * 2
			huge_rock.visible = true
			main_col.scale = Vector3.ONE * 0.225
			main_col.scale *= 1.5
			current_mesh 		= huge_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.625
			max_health = health
			rock_type_gravity_scale = 0.3
			update_health_icon()
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [4,6,7]
			force_mult_index = 0

		RockSize.LARGE:
			current_rock_type 	= "Gold"
			rock_type_name 		= "rock_type_3"
			health 				= int(gl_DataSet.get_value("rock_type_3", 1))
			cash_value 			= int(gl_DataSet.get_value("rock_type_3", 0))
			large_rock.visible 	= true
			main_col.scale 		= Vector3.ONE * 0.3
			current_mesh 		= large_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale  = Vector3.ONE * 0.7
			max_health = health
			rock_type_gravity_scale = 0.4
			update_health_icon()
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
			
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
			update_health_icon()
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
			update_health_icon()
			gl_PlayerState.log_hazard()
			linear_damp = 1.0
			force_mult = [1,2]
			

func reset_stats() -> void:
	$Mesh.scale = Vector3.ONE
	$Marked.hide()
	$Mesh.show()
	
	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = small_rock
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = 0
	
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	falling = false
	rock_destroyed = false
	has_been_marked = false
	player_has_marked_rock = false
	is_deactivated = false
	global_position = start_pos

	icon.modulate.a = 0.0



func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
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
	if player_has_marked_rock:
		return
	
	
	player_has_marked_rock = true
	freeze = true
	$Marked.show()
	$marked_embers.emitting = true
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.remove_sky_mine()

	
	
	await get_tree().create_timer(0.15).timeout
	$marked_sfx.play()
	
	
	await get_tree().create_timer(0.5).timeout
	detonate_rock()
	
func apply_hit_reaction(screen_offset : Vector2) -> void:
	#if gravity_scale >= 1.0:
	gravity_scale = 0.1
	linear_damp = 0.3
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
	
	if rock_type_name.contains("hazard_type"):
		health -= 1
		
	else:
		health -= damage
		
	display_health_counter()
	update_health_icon() 
	display_damage_counter(damage)
	
	%explosion_radius_mesh.hide()
	
	#Rock Takes Damage But Is Not Destroyed Process
	if gl_PlayerState.dataset.power_sky_mine > 0:
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
		
			gl_PlayerState.add_cash(1)
		return
	

	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)
		has_been_marked = false

		return
	
	
	#Rock Destroyed Process
	start_destroyed_process()
	
func first_rock() -> void:
	# Base values
	#hide_all_meshes()
	current_rock_type 	= "Small Rock"
	rock_type_name 		= "rock_type_1"

	var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
	var base_cash   := int(gl_DataSet.get_value("rock_type_1", 0))
	var base_scale  := Vector3.ONE * 0.3

	# Random subtype: 1x / 2x / 3x
	var size_multiplier : int = 2

	health = base_health * size_multiplier
	cash_value = base_cash
	max_health = health
	#update_health_icon()
	small_rock.visible = true
	main_col.scale = Vector3.ONE * 0.125 * size_multiplier
	current_mesh = small_rock
	assign_random_mesh(current_mesh)
	current_mesh.scale = base_scale * size_multiplier
	
	rock_type_gravity_scale = 0.05 # + (size_multiplier / 10)
	linear_damp = 0.5
	force_mult.clear()
	force_mult = [1,2]
	force_mult_index = 0
	
	add_to_group('Target')
	force_mult.shuffle()
	icon.show()
	icon.modulate.a = 0.0

	$Start_falling_timer.start(2.2)
	current_state = State.ACTIVE
	enable_collision()

func add_to_rocks_round() -> void:
	
	add_to_group('Target')
	%explosion_radius_mesh.hide()
	icon.show()
	icon.modulate.a = 0.0
	# Hazards can never be gold

	rock_activated = true

	$Start_falling_timer.start(2.2)


func bounce_rocks() -> void:
	update_gravity(0.04)
	global_position = start_pos

func start_destroyed_process() -> void:

	if !rock_activated:
		return
		
	rock_activated = false
	
	if player_has_marked_rock == false:
		expand_blast_radius()
	
	enter_state(State.HIT)
	gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value)
	#if !destroyed_by_marked:
	
	if rock_type_name.contains('Hazard'):
		$Hazard_sfx.play()
	
	remove_from_group('Target')
	
	play_destroy_sfx()
	$Marked.hide()
	icon.hide()

	
	if is_in_group('Target'):
		remove_from_group('Target')
		

	money_label_3d.money_is_money(global_position, cash_value)
	
	set_collision_layer_value(1, false)

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	await tween.finished
	
	if !player_has_marked_rock:
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
	if player_has_marked_rock == false:
		if body is RigidBody3D:
			print('push rock away from blast radius')
			var force_dir = (body.global_position - global_position)
			force_dir = force_dir.normalized()	
			body.apply_central_impulse(force_dir * 3)
			return
	
	if body.name.contains('Rock_Instance'):
		body.start_destroyed_process()
		
	if body.name.contains('Balloon'):
		if player_has_marked_rock == false:
			return
		body.start_destroyed_process()


func expand_blast_radius() -> void:
	if !player_has_marked_rock:
		standard_blast()
		return
	
	%explosion_radius_mesh.show()
	
	var blast_node : Area3D = $Explosion_area
	blast_node.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 15.0, 0.3)
	tween.tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.25)
	
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	%explosion_radius_mesh.transparency = 0.2
	blast_node.hide()
	blast_node.monitoring = false
	
func standard_blast() -> void:

	var blast_node : Area3D = $Explosion_area
	blast_node.show()
	%explosion_radius_mesh.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * 5.0, 0.25)
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
	
	#var _new_sparks : GPUParticles3D = $Sparks01 #.duplicate()
#
	#if !_new_sparks:
		#return
		#
	#_new_sparks.show()
	#_new_sparks.global_position = global_position
	#_new_sparks.emitting = true

		
		
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


#func set_xray_visible(value : bool) -> void:
	#tween_2d_icon(value)

#func tween_2d_icon(value : bool) -> void:
#
	#if value:
		#if tween_sight_icon:
			#tween_sight_icon.kill()
		#$'2d_3d_icon/AnimationPlayer'.play('2d_3d_icon')
		#tween_sight_icon = create_tween()
		#tween_sight_icon.tween_property(%'2d_3d_icon', 'modulate:a', 1.0, 0.1)
	#
	#else:
#
		#$'2d_3d_icon/AnimationPlayer'.pause()
		
		
func update_health_icon() -> void:
	return
	#if max_health <= 0:
		#return
#
	#var health_percent : float = float(health) / float(max_health)
	#
	#
	#if health_percent > 0.80:
		#icon.modulate = health_green
		#icon.scale = Vector3.ONE * 0.52
	#elif health_percent > 0.50:
		#icon.modulate = health_orange
		#icon.scale = Vector3.ONE * 0.4
	#else:
		#icon.modulate = health_red
		#icon.scale = Vector3.ONE * 0.35
