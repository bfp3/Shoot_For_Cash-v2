extends RigidBody3D
class_name RockInstance

@onready var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')

@export var freeze_mine := false
## Alt-gun freeze burst: how far the ice pulse reaches from the rock you shot.
@export var freeze_burst_radius := 4.0
## How long rocks stay frozen after being caught in the burst.
@export var freeze_burst_duration := 1.0
## Visual size of the freeze pulse (Explosion_area scale).
@export var freeze_burst_visual_scale := 3.0
var sky_mine_blast_radius := 5.0 #15.0

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
var start_exploding := false
var pitch_adjustment := 0.02
var _freeze_shot_pending := false

var rock_type := 0

var current_particles : GPUParticles3D = null

const ROCK_01 = preload('uid://c2pmyrm3e4ty5')
const ROCK_02 = preload('uid://84ianb3xwjp7')
const ROCK_03 = preload('uid://lxbrgqaovv68')



const ROCK_MESHES = [
	ROCK_01,
	ROCK_02,
	ROCK_03,

]

enum RockSize {
	SMALL,
	SMALL_2,
	MEDIUM,
	LARGE,
	HAZARD,
	HUGE,
	HAZARD_SMALL,
	RED_ROCK_ERROR,
	SMOKECAN,
	## Homing hazard: steers toward the crosshair; reticle overlap = explode + strike.
	AVOIDER,
	## Flees the crosshair; must stay in scope for `chaser_lock_time_sec` before it can be shot.
	CHASER,
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

@onready var damage_label_3d: Label3D = %Damage_Label3D
@onready var health_remaining_label: Label3D = %Health_remaining_label

@onready var main_col: CollisionShape3D = $main_col
@onready var mesh_container: Node3D = %Mesh

@onready var small_rock: MeshInstance3D = %small_rock
@onready var clay_pigeon: MeshInstance3D = %clay_pigeon

@onready var medium_rock: MeshInstance3D = %medium_rock
@onready var large_rock: MeshInstance3D = %Large_rock
@onready var huge_rock: MeshInstance3D = %Huge_rock
@onready var red_rock: MeshInstance3D = %Red_rock
@onready var blue_rock: MeshInstance3D = %blue_rock
@onready var smokecan: MeshInstance3D = %Smokecan

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
## Aimed rocks: damp-free ascent, then `aim_descent_linear_damp` once past the apex.
var ballistic_aim_active := false
var _ballistic_descent_damp := 0.5
var _ballistic_in_descent := false
## When true, camera out-of-bounds does not count as a miss (e.g. smokecan fly-off).
var ignores_x_out_of_bounds := false
## Set by RockManager once this rock has been inside the camera viewport.
## Off-screen spawns won't miss until they've entered play at least once.
var has_entered_camera_view := false
## Bumps to cancel a pending airborne rock–rock collision schedule.
var _airborne_collision_token := 0

# --- Rock Avoider (rock-avoider) ---------------------------------------------
@export_group("Rock Avoider")
## How hard the avoider steers toward the crosshair (X/Y only).
@export var avoider_seek_accel := 22.0
## Caps horizontal/vertical chase speed so it stays readable.
@export var avoider_max_speed_xy := 16.0
## Delay after launch before seeking / overlap checks (avoids instant spawn kills).
@export var avoider_arm_delay_sec := 0.45
## How long the avoider stays alive before it explodes on its own (no strike).
@export var avoider_lifetime_sec := 4.0
## If true, avoider + rock both explode on contact. If false, only the other rock blows up.
@export var avoider_explodes_when_hitting_rock := false
## If true, two avoiders destroy each other on contact. If false, they pass through each other.
@export var avoider_explodes_when_hitting_avoider := false
var _avoider_armed := false
var _avoider_arm_token := 0
var _avoider_life_token := 0

# --- Rock Chaser (rock-chaser) -----------------------------------------------
@export_group("Rock Chaser")
@export var chaser_flee_accel := 22.0
@export var chaser_max_speed_xy := 16.0
@export var chaser_arm_delay_sec := 0.35
## How long the reticle must stay on the chaser before it becomes shootable.
@export var chaser_lock_time_sec := 2.0
## Padding inside the column 1–8 / row A–C play rectangle.
@export var chaser_bounds_padding := 0.35
## Gravity while dodging (near 0 keeps it in the lane band).
@export var chaser_float_gravity := 0.04
## One-shot spin impulse when the chaser locks (ready to shoot).
@export var chaser_lock_torque := 18.0
var _chaser_armed := false
var _chaser_arm_token := 0
var _chaser_lock_progress := 0.0
var _chaser_locked := false
var _chaser_saved_gravity := 0.12
var _chaser_lock_pos := Vector3.ZERO
var _chaser_lock_spin_applied := false


func _ready() -> void:
	
	start_pos = global_position
	target_x_position = start_pos.x
	# Own a unique physics material so bounce tweaks never leak across pooled rocks.
	if physics_material_override != null:
		physics_material_override = physics_material_override.duplicate()
	else:
		physics_material_override = PhysicsMaterial.new()

	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_rock_body_entered):
		body_entered.connect(_on_rock_body_entered)
	
	await get_tree().create_timer(0.2).timeout
	
	#EventBus.instance.all_rocks_destroyed.connect(hazard_disappear)
	enter_state(State.INACTIVE)


func begin_ballistic_aim_feel(descent_damp: float = 0.5) -> void:
	ballistic_aim_active = true
	_ballistic_descent_damp = descent_damp
	_ballistic_in_descent = false
	linear_damp = 0.0


func _physics_process(delta: float) -> void:
	if current_state == State.ACTIVE and rock_activated:
		if rock_type == RockSize.AVOIDER:
			if not _freeze_shot_pending:
				_update_avoider(delta)
		elif rock_type == RockSize.CHASER:
			if not _freeze_shot_pending:
				_update_chaser(delta)

	if not ballistic_aim_active or _ballistic_in_descent:
		return
	if current_state != State.ACTIVE:
		return
	if linear_velocity.y > 0.0:
		return
	_ballistic_in_descent = true
	linear_damp = _ballistic_descent_damp


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
	# Hazards / smokecans / avoiders are obstacles — not required to clear the round.
	if (
		rock_type_name != 'hazard_type_1'
		and rock_type != RockSize.SMOKECAN
		and rock_type != RockSize.AVOIDER
	):
		gl_PlayerState.log_rocks(1, rock_type_name)
		
	await get_tree().create_timer(0.2).timeout
	global_position.x = target_x_position
	
func update_active() -> void:
	if rock_type != RockSize.SMALL_2:
		constant_force.x = 0.01
	
	if  rock_type == RockSize.SMOKECAN:
		constant_force.x = 0.5
	elif rock_type == RockSize.AVOIDER:
		constant_force.x = 0.0
		rotation_degrees = Vector3.ZERO
	elif rock_type == RockSize.CHASER:
		constant_force.x = 0.0
		rotation_degrees = Vector3.ZERO
	else:
		constant_force.x = 0.01
		rotation_degrees = Vector3.ZERO
	
	enable_collision()
	add_to_rocks_round()
	if rock_type == RockSize.AVOIDER:
		_arm_avoider()
		_start_avoider_lifetime()
		_sync_avoider_collision_exceptions()
	elif rock_type == RockSize.CHASER:
		_arm_chaser()
	
	#%rock_launch_sound.pitch_scale = randf_range(3.0,3.2)
	%rock_launch_sound.play()
	



func update_hit() -> void:
	update_gravity(1.0)
	#linear_velocity = Vector3.ZERO
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
			# Black hazards / smokecans / avoiders should keep falling or orange-drift motion
			# across wave clears; only normal rocks get parked as DISABLED.
			if (
				rock_type == RockSize.HAZARD
				or rock_type == RockSize.HAZARD_SMALL
				or rock_type == RockSize.SMOKECAN
				or rock_type == RockSize.AVOIDER
			):
				pass
			else:
				enter_state(State.DISABLED)
			
		State.PREPARE_ROCK:
			pass
			
		State.DISABLED:
			pass
			
		_:
			print("We are in some other state rock instance ", current_state)


func update_disabled() -> void:
	update_gravity(1.0)
	# Keep layer 1 for remaining interactions, but stop rock–rock bounce while parked.
	_cancel_airborne_rock_collisions()
	#await get_tree().create_timer(2.0).timeout
	#disable_collision()
	#remove_from_group('Target')



func disable_collision() -> void:
	_cancel_airborne_rock_collisions()
	set_collision_layer_value(1, false)
	$Explosion_area.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true

func enable_collision() -> void:
	# Layer 1 only — rock–rock mask stays off until schedule_airborne_rock_collisions().
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, false)


## After launch settles: allow this rock to collide / bounce with other airborne rocks.
## Safe to call during pulse — delay keeps dormant launch stacking from shoving neighbors.
func schedule_airborne_rock_collisions(delay_sec: float, bounce: float) -> void:
	_airborne_collision_token += 1
	var token := _airborne_collision_token
	set_collision_mask_value(1, false)

	if delay_sec <= 0.0:
		if current_state == State.ACTIVE and rock_activated:
			_enable_airborne_rock_collisions(bounce)
		return

	get_tree().create_timer(delay_sec).timeout.connect(
		func () -> void:
			if token != _airborne_collision_token:
				return
			if current_state != State.ACTIVE or not rock_activated:
				return
			_enable_airborne_rock_collisions(bounce),
		CONNECT_ONE_SHOT
	)


func _enable_airborne_rock_collisions(bounce: float) -> void:
	set_collision_mask_value(1, true)
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = clampf(bounce, 0.0, 1.0)
	if rock_type == RockSize.AVOIDER:
		_sync_avoider_collision_exceptions()


func _cancel_airborne_rock_collisions() -> void:
	_airborne_collision_token += 1
	set_collision_mask_value(1, false)
	if physics_material_override != null:
		physics_material_override.bounce = 0.0


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
	clay_pigeon.visible			= false
	medium_rock.visible 		= false
	large_rock.visible 			= false
	huge_rock.visible 			= false
	hazard_large.visible 		= false
	red_rock.visible			= false
	if blue_rock:
		blue_rock.visible		= false
	smokecan.visible			= false




func reset_rock_back_on() -> void:
	enter_state(State.MISSED)


func setup_rock_type() -> void:
	current_mesh.scale = Vector3.ONE
	
	angular_damp = 1.0
	
	match rock_type:
		# 0
		RockSize.SMALL:
			# Base values

			current_rock_type 	= "Small Rock"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_1", 0))
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
			#%TrailParticles.emitting = true
		
		
		RockSize.SMALL_2:
			current_rock_type 	= "Pigeon"
			rock_type_name 		= "rock_type_1"
			gl_PlayerState.log_white_rock()
			#var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			var base_scale  := Vector3.ONE * 0.35

			var size_multiplier_float : float = 1.4 #randf_range (1.2, 1.35) * 2
			#var size_multiplier_int : int = 2
			$Mesh.scale = Vector3.ONE
			health = 1 #base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			clay_pigeon.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = clay_pigeon
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			linear_damp = 0.5
			force_mult.clear()
			force_mult = [3,4]
			force_mult_index = 0
		
			current_particles = $Mesh/clay_pigeon/GoldParticles
			current_particles.amount += 1
			current_particles.amount -= 1
			current_particles.emitting = true
			#%TrailParticles.emitting = true
		
		
		
		# 1
		#RockSize.SMALL_2:
			#current_rock_type 	= "Pigeon"
			#rock_type_name 		= "rock_type_1"
			#ignores_x_out_of_bounds = true
			#gl_PlayerState.log_white_rock()
			#var base_health := int(gl_DataSet.get_value("rock_type_1", 1))
			#var base_cash   := 0 #int(gl_DataSet.get_value("rock_type_1", 0))
			#var base_scale  := Vector3.ONE * 0.35 * 2
#
			#var size_multiplier_float : float = 2.4 #randf_range (1.2, 1.35) * 2
			#var size_multiplier_int : int = 2
			#$Mesh.scale = Vector3.ONE
			#health = 1 #base_health * size_multiplier_int
			#cash_value = base_cash # * size_multiplier
			#max_health = health
			#small_rock.visible = true
			#main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			#current_mesh = small_rock
			#assign_random_mesh(current_mesh)
			#current_mesh.scale = base_scale * size_multiplier_float
			#rock_type_gravity_scale = 0.1 # + (size_multiplier / 10)
			#linear_damp = 0.5
			#force_mult.clear()
			#force_mult = [3,4]
			#force_mult_index = 0
		
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
			health 				= int(gl_DataSet.get_value("hazard_type_1", 1))
			cash_value 			= int(gl_DataSet.get_value("hazard_type_1", 0))
		
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
			
			
			
		RockSize.RED_ROCK_ERROR:
			# Base values
			current_rock_type 	= "Red Rock"
			rock_type_name 		= "rock_type_9"
			gl_PlayerState.log_white_rock()
			var base_health :=  int(gl_DataSet.get_value("rock_type_9", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_9", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.2 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1
			$Mesh.scale = Vector3.ONE
			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			red_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 2.5 # + (size_multiplier / 10)
			linear_damp = 1.5
			force_mult.clear()
			force_mult = [0, 1]
			force_mult_index = 0
			
		
		RockSize.SMOKECAN:
			# Base values — obstacle only; does not count toward round progress (like HAZARD).
			current_rock_type 	= "Smokecan"
			rock_type_name 		= "rock_type_8"
			var base_health := int(gl_DataSet.get_value("rock_type_8", 1))
			var base_cash   := int(gl_DataSet.get_value("rock_type_8", 0))
			var base_scale  := Vector3.ONE * 0.35

			# Random subtype: 1x / 2x / 3x
			#var size_multiplier : int = [1, 2].pick_random() #, 3].pick_random()
			var size_multiplier_float : float = 1.5 #randf_range (1.2, 1.35)
			var size_multiplier_int : int = 1
			$Mesh.scale = Vector3.ONE
			health = base_health * size_multiplier_int
			cash_value = base_cash # * size_multiplier
			max_health = health
			smokecan.visible = true
			main_col.scale = Vector3.ONE * 0.125  * size_multiplier_float
			current_mesh = smokecan
			#assign_random_mesh(current_mesh)
			current_mesh.scale = base_scale * size_multiplier_float
			rock_type_gravity_scale = 2.5 # + (size_multiplier / 10)
			linear_damp = 1.5
			force_mult.clear()
			force_mult = [0, 1]
			force_mult_index = 0

		RockSize.AVOIDER:
			# Homing hazard — chase the reticle; contact = strike. Not a clearable rock.
			current_rock_type = "Rock Avoider"
			rock_type_name = "rock_type_avoider"
			var avoider_scale := Vector3.ONE * 0.35
			var avoider_size := 1.35
			$Mesh.scale = Vector3.ONE
			health = 1
			cash_value = 0
			max_health = health
			red_rock.visible = true
			main_col.scale = Vector3.ONE * 0.125 * avoider_size * 1.5
			current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = avoider_scale * avoider_size
			rock_type_gravity_scale = 0.12
			linear_damp = 0.35
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			current_particles = $Mesh/Red_rock/GoldParticles if $Mesh/Red_rock.has_node("GoldParticles") else null
			if current_particles:
				current_particles.emitting = true
			_avoider_armed = false

		RockSize.CHASER:
			current_rock_type = "Rock Chaser"
			rock_type_name = "rock_type_chaser"
			gl_PlayerState.log_white_rock()
			var chaser_scale := Vector3.ONE * 0.35
			var chaser_size := 1.35
			$Mesh.scale = Vector3.ONE
			health = 1
			cash_value = 0
			max_health = health
			if blue_rock:
				blue_rock.visible = true
				current_mesh = blue_rock
			else:
				red_rock.visible = true
				current_mesh = red_rock
			assign_random_mesh(current_mesh)
			current_mesh.scale = chaser_scale * chaser_size
			main_col.scale = Vector3.ONE * 0.125 * chaser_size
			rock_type_gravity_scale = 0.12
			linear_damp = 0.35
			force_mult.clear()
			force_mult = [3, 4]
			force_mult_index = 0
			_chaser_armed = false
			_chaser_lock_progress = 0.0
			_chaser_locked = false
			if blue_rock and blue_rock.has_node("RedParticles"):
				current_particles = blue_rock.get_node("RedParticles")
				current_particles.emitting = true

func reset_stats() -> void:
	ignores_x_out_of_bounds = false
	has_entered_camera_view = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1
	_chaser_armed = false
	_chaser_arm_token += 1
	_chaser_lock_progress = 0.0
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	can_sleep = true
	$Mesh.scale = Vector3.ONE
	$Mesh.position = Vector3.ZERO
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
	ballistic_aim_active = false
	_ballistic_in_descent = false
	_freeze_shot_pending = false
	_cancel_airborne_rock_collisions()
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


## Alt-gun hit: pulse a small freeze radius; every rock inside gets iced.
func apply_freeze_shot_effect(damage: int = 1, screen_offset: Vector2 = Vector2.ZERO) -> void:
	if rock_destroyed or not rock_activated:
		return

	if rock_type_name.contains("hazard_type"):
		health -= 1
	else:
		health -= damage
	display_health_counter()
	display_damage_counter(maxi(damage, 1))
	play_hit_sfx()
	apply_hit_reaction(screen_offset)

	var should_destroy := health <= 0
	release_freeze_burst()

	if should_destroy:
		await get_tree().create_timer(freeze_burst_duration, false).timeout
		if is_instance_valid(self) and not rock_destroyed and rock_activated:
			start_destroyed_process()


## Small AOE ice pulse from this rock. Caught rocks (including avoiders) call apply_aoe_freeze().
func release_freeze_burst() -> void:
	_play_freeze_burst_visual()
	if has_node("%Freeze_sfx"):
		%Freeze_sfx.play()
	elif has_node("%Freeze_sfx2"):
		%Freeze_sfx2.play()

	var origin := global_position
	var radius_sq := freeze_burst_radius * freeze_burst_radius
	# Prefer Target group, but also sweep RockInstance siblings so avoiders always count.
	var candidates: Array = get_tree().get_nodes_in_group("Target")
	var parent_rocks := get_parent()
	if parent_rocks:
		for child in parent_rocks.get_children():
			if child is RockInstance and child not in candidates:
				candidates.append(child)

	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is RockInstance):
			continue
		var rock := node as RockInstance
		if rock.global_position.distance_squared_to(origin) > radius_sq:
			continue
		rock.apply_aoe_freeze(freeze_burst_duration)


## Freeze this rock in place for duration, then thaw.
## Avoiders / chasers also stop seeking while iced.
func apply_aoe_freeze(duration: float = 1.0) -> void:
	if _freeze_shot_pending or rock_destroyed or not rock_activated:
		return
	if current_state != State.ACTIVE:
		return

	_freeze_shot_pending = true
	if has_node("Freeze"):
		$Freeze.show()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = true

	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Pause avoider lifetime so it can't expire mid-freeze.
	if rock_type == RockSize.AVOIDER:
		_avoider_life_token += 1

	await get_tree().create_timer(duration, false).timeout

	if not is_instance_valid(self):
		return
	_freeze_shot_pending = false
	freeze = false
	if has_node("Freeze"):
		$Freeze.hide()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = false

	# Resume avoider lifetime after thaw.
	if rock_type == RockSize.AVOIDER and rock_activated and current_state == State.ACTIVE:
		_start_avoider_lifetime()


func _play_freeze_burst_visual() -> void:
	if not has_node("Explosion_area"):
		return
	var blast_node: Area3D = $Explosion_area
	# Visual only — freeze is applied via distance check, not body_entered.
	blast_node.monitoring = false
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE
	blast_node.show()
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(blast_node, "scale", Vector3.ONE * freeze_burst_visual_scale, 0.28)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.28)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		blast_node.scale = Vector3.ONE
		blast_node.hide()
		%explosion_radius_mesh.transparency = 0.0
		%explosion_radius_mesh.hide()
	)


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func apply_marked_ability() -> void:
	#if player_has_marked_rock:
		#return
	
	player_has_marked_rock = true
	#freeze = true
	apply_slow_linear_damp()
	
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
	%rock_marked_sfx.play()
	
	
	await get_tree().create_timer(1.0).timeout
	detonate_rock()
	
	
func apply_slow_linear_damp() -> void:
	var torque_dir := Vector3(
		500.0,
		1.0,
		-500.0
	).normalized()

	apply_torque_impulse(
		torque_dir * force_mult[force_mult_index] * hit_torque_strength
	)
	
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_interval(0.2)
	tween.tween_property(self, "linear_damp", 18.0, 0.15).as_relative()
	tween.parallel().tween_property(self, "angular_damp", 18.0, 0.15).as_relative()
	
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
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO, freeze_shot := false) -> void:	
	
	#freeze_mine = true

	# Avoiders: reticle/shot normally strikes — unless frozen, then you can shoot them out cleanly.
	if rock_type == RockSize.AVOIDER:
		if _freeze_shot_pending:
			_destroy_frozen_avoider()
			return
		_trigger_avoider_crosshair_contact()
		return

	# Chaser must be locked (held in scope) before shots count.
	if rock_type == RockSize.CHASER and not _chaser_locked:
		return

	## Alt weapon: release a freeze burst — nearby rocks ice up.
	if freeze_shot:
		await apply_freeze_shot_effect(damage, screen_offset)
		return
	
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

	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)

		#%explosion_radius_mesh.hide()
		return
	
	
	if rock_type == RockSize.SMOKECAN:
		apply_torque_impulse(Vector3.BACK * 100.0)
		play_hit_sfx()
		#%rock_launch_sound.play()
		%rock_flicker_sfx.play()
		%launched_into_distance_3d.play(0.25)
		fly_off_into_distance()
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property($Mesh, "position:y", 0.5, 0.5)
		return
		
	#Rock Destroyed Process
	
	if rock_type == RockSize.HAZARD:
		$Marked.show()
		#$marked_embers.emitting = true
		%rock_marked_sfx.play()
		apply_slow_linear_damp()
		await get_tree().create_timer(1.5, false).timeout
	
	
	start_destroyed_process()
	
	
	
func fly_off_into_distance() -> void:
	ignores_x_out_of_bounds = true
	
	var strength : float = 4.0 # [4.0].pick_random()
	var x_direction := 0.0
	var player := get_tree().get_first_node_in_group('Player')
	
	if !player:
		apply_central_impulse(Vector3(x_direction,-0.0,35) * strength)

	else:
		#strength = 4.0
		var dir : Vector3= self.global_position - player.global_position.normalized()
		dir.y /= 3
		apply_central_impulse(dir * strength)
	
	
	
func add_to_rocks_round() -> void:
	play_piano_note()
	# Avoiders punish reticle overlap — keep them out of the shootable Target group.
	# Chasers join Target only after the lock timer completes.
	if rock_type != RockSize.AVOIDER and rock_type != RockSize.CHASER:
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

	%RedParticles.emitting = false
	rock_activated = false
	
	if current_particles != null:
		current_particles.emitting = false
	
	if %TrailParticles != null:
		%TrailParticles.emitting = false
	
	#if player_has_marked_rock == false:
	expand_blast_radius()
	enter_state(State.HIT)
	
	if rock_type == RockSize.SMALL:
		%rock_flicker_sfx.play()
		#await get_tree().create_timer(0.1).timeout
		get_parent().get_parent().get_node('pitch_shift_rock_sound').pitch_scale += 0.1
		get_parent().get_parent().get_node('pitch_shift_rock_sound').play()

	
	# This is to score bonus cash for shooting rocks beneath the Cash Zones / ZoneA, ZoneB
	#if rock_type != RockSize.HAZARD:
		#var bonus_cash_reward := 0
		#var bonus_zones := get_tree().get_first_node_in_group('multi_shot')
		#if bonus_zones:
			#bonus_cash_reward = bonus_zones.check_if_within_zone(global_position.y)
			
		#cash_value += bonus_cash_reward
		

	
	
	if !rock_has_been_logged:
		rock_has_been_logged = true

		gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value)
			
	
	remove_from_group('Target')
	
	play_destroy_sfx()
	$Marked.hide()
	if has_node("Freeze"):
		$Freeze.hide()

	if cash_value > 0:
		money_label_3d.money_is_money(global_position, cash_value)
		
	
			
	set_collision_layer_value(1, false)

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
		
			
	if rock_type == RockSize.HAZARD:
		#$Marked.show()
		##$marked_embers.emitting = true
		#%rock_marked_sfx.play()
		#apply_slow_linear_damp()
		#await get_tree().create_timer(1.0).timeout
		#
		#await get_tree().create_timer(0.5).timeout
		
		if cash_value < 0:
			money_label_3d.money_is_money(global_position, cash_value)
		
		%hazard_hit_sound.play()
		play_destroy_sfx()
		EventBus.instance.hazard_hit.emit()
	
	
	if cash_value == 2:
		hazard_aoe_delayed()
	
	if rock_type == RockSize.SMOKECAN:
		%hazard_hit_sound.play()
		
	was_hit_tween()
	

	#var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	#await tween.finished
	
	if !player_has_marked_rock:
		shake_camera()
	
	

	round_manager.bullet_active = false
	$Mesh.position = Vector3.ZERO

func play_hit_sfx() -> void:
	%rock_hit_sound.volume_db = randf_range(-25.0, -20.0)
	%rock_hit_sound.pitch_scale = randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05).timeout
	%rock_hit_sound.play(0.01)
	await get_tree().create_timer(0.1).timeout
	%rock_hit_sound.play(0.02)


func play_destroy_sfx() -> void:
	%rock_hit_sound.play(0.02)
	await get_tree().create_timer(0.1).timeout
	%rock_hitSound.play()
	await get_tree().create_timer(0.1).timeout
	%rock_explosion_sfx.play()



		

func _on_start_falling_timer_timeout() -> void:
	falling = true
	# Rock–rock collision is scheduled after launch via schedule_airborne_rock_collisions().
	
	if rock_type == RockSize.SMOKECAN:
		var damage_mesh = current_mesh.get_child(0) 
		for i in range(3):
			damage_mesh.show()
			await get_tree().create_timer(0.1, false).timeout
			damage_mesh.hide()
			await get_tree().create_timer(0.1, false).timeout
			
		damage_mesh.show()
		await get_tree().create_timer(0.1, false).timeout
		damage_mesh.hide()
		start_destroyed_process()
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
	if player_has_marked_rock == false:
		if body is RigidBody3D:

			var force_dir = (body.global_position - global_position)
			force_dir = force_dir.normalized()	
			#body.apply_central_impulse(force_dir * 2)
			#body.apply_central_impulse(force_dir / 2)
			body.apply_torque_impulse(force_dir * 500.0)
			return
	
	if body.name.contains('Rock_Instance'):
		if body.current_state != body.State.ACTIVE:
			return
		
		if body.current_rock_type.contains("Ender"):
			body.rock_type_name = 'rock_type_4'
			body.current_rock_type = 'neutralised'
			
		if freeze_mine:
			# Prefer the shared freeze helper so avoiders ice instead of striking.
			if body.has_method("apply_aoe_freeze"):
				body.apply_aoe_freeze(3.5)
			else:
				body.hit_by_player(0, Vector2.ZERO)
				if body.has_node("Freeze"):
					body.get_node("Freeze").show()
				await get_tree().create_timer(0.25).timeout
				body.freeze = true
				await get_tree().create_timer(3.5).timeout
				if is_instance_valid(body):
					body.freeze = false
					if body.has_node("Freeze"):
						body.get_node("Freeze").hide()
				
		else:
			body.start_destroyed_process()
			body.hit_by_player(1, Vector2.ZERO)
	
	#if body.name.contains('Balloon'):
		#return
		#if freeze_mine:
			#return
		#if player_has_marked_rock == false:
			#return
		#body.destroyed_by_shratnel()



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

	# #endregion
	blast_node.show()
	%explosion_radius_mesh.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
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

func hazard_aoe_delayed() -> void:

	$Hazard_AoE2.global_position = global_position
	$Hazard_AoE2.play_particles = true


func smoke_particles() -> void:
	
	if rock_type == RockSize.SMOKECAN:
		%Smokecan_AoE.global_position = global_position
		%Smokecan_AoE.play_particles = true
		
	if rock_type_name.contains('hazard'):
		$Hazard_AoE2.global_position = global_position
		$Hazard_AoE2.play_particles = true
		
	else:
		var _phys := global_position
		var _interp := get_global_transform_interpolated().origin
		var _expl_interp = $Explosion_area.get_global_transform_interpolated().origin
		# #endregion
		$AoE.global_position = global_position
		$AoE.play_particles = true




func smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick

	if !_new_particles:
		return
		
	_new_particles.emitting = true
	_new_particles.show()
	_new_particles.global_position = global_position

	var _new_sparks : GPUParticles3D = $Sparks01
	if !_new_sparks:
		return
	_new_sparks.show()
	_new_sparks.global_position = global_position
	_new_sparks.emitting = true


func hazard_smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick.duplicate()

	if !_new_particles:
		return
		
	_new_particles.emitting = true
	_new_particles.duplicate_particles = true
	_new_particles.show()
	get_tree().get_current_scene().add_child(_new_particles)
	_new_particles.global_position = global_position


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
		

		

func out_of_bounds() -> void:
	%rock_hitSound.play()
	%rock_hit_sound.play()


# --- Rock Avoider ------------------------------------------------------------

func _arm_avoider() -> void:
	_avoider_armed = false
	_avoider_arm_token += 1
	%RedParticles.emitting = true
	var token := _avoider_arm_token
	await get_tree().create_timer(avoider_arm_delay_sec).timeout
	if token != _avoider_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.AVOIDER:
		return
	_avoider_armed = true
	# Detect rock contacts for destroy-on-hit (independent of bounce toggle timing).
	set_collision_mask_value(1, true)
	_sync_avoider_collision_exceptions()


func _start_avoider_lifetime() -> void:
	_avoider_life_token += 1
	var token := _avoider_life_token
	var lifetime := maxf(avoider_lifetime_sec, 0.1)
	await get_tree().create_timer(lifetime).timeout
	if token != _avoider_life_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.AVOIDER:
		return
	if not rock_activated:
		return
	_expire_avoider_lifetime()


## Timed out without touching the reticle — pop with no strike.
func _expire_avoider_lifetime() -> void:
	if rock_type != RockSize.AVOIDER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	rock_activated = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1

	remove_from_group("Target")
	disable_collision()

	if current_particles != null:
		current_particles.emitting = false
	if %TrailParticles != null:
		%TrailParticles.emitting = false
	var red := get_node_or_null("%RedParticles") as GPUParticles3D
	if red:
		red.emitting = false

	expand_blast_radius()
	play_destroy_sfx()
	await was_hit_tween()
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


func _update_avoider(delta: float) -> void:
	if not _avoider_armed:
		return
	if _freeze_shot_pending:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	var aim_xy := _crosshair_world_xy_at_depth(global_position.z)
	var to_aim := Vector2(aim_xy.x - global_position.x, aim_xy.y - global_position.y)
	if to_aim.length_squared() > 0.0001:
		var desired := to_aim.normalized() * avoider_max_speed_xy
		var vel_xy := Vector2(linear_velocity.x, linear_velocity.y)
		var steered := vel_xy.move_toward(desired, avoider_seek_accel * delta)
		linear_velocity.x = steered.x
		linear_velocity.y = steered.y
		# Keep Z motion from the launch arc; do not steer on Z.

	if _avoider_overlaps_crosshair():
		_trigger_avoider_crosshair_contact()


## Project the player's crosshair onto the rock's depth plane; return world X/Y only.
func _crosshair_world_xy_at_depth(depth_z: float) -> Vector2:
	var fallback := Vector2(global_position.x, global_position.y)
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return fallback

	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return fallback

	var screen_pos := _player_crosshair_screen_pos(player)
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.z) < 0.00001:
		return fallback
	var t := (depth_z - origin.z) / dir.z
	if t < 0.0:
		return fallback
	return Vector2(origin.x + dir.x * t, origin.y + dir.y * t)


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	# Prefer the same TextureRect the gun uses for hit tests.
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		var rect: Control = weapon.crosshair
		return rect.global_position

	var crosshair: Control = player.get_node_or_null("%Crosshair") as Control
	if crosshair:
		return crosshair.global_position + (crosshair.size * 0.5)
	return get_viewport().get_visible_rect().size * 0.5


func _avoider_overlaps_crosshair() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return false

	var rock_screen := cam.unproject_position(global_position)
	var crosshair_screen := _player_crosshair_screen_pos(player)

	var world_radius := 0.5
	if main_col and main_col.shape is SphereShape3D:
		world_radius = (main_col.shape as SphereShape3D).radius * main_col.scale.x
	elif current_mesh:
		world_radius = maxf(current_mesh.scale.x, 0.2) * 0.5

	var edge_screen := cam.unproject_position(
		global_position + cam.global_basis.x * world_radius
	)
	var screen_radius := rock_screen.distance_to(edge_screen)

	# Use the live shrink/expand hit radius (weapon), not the resting upgrade value.
	var hit_radius := _player_live_crosshair_hit_radius(player)

	return rock_screen.distance_to(crosshair_screen) <= hit_radius + screen_radius


## Matches what shooting uses: Weapon_shooting.power_target_circle updates while holding shrink/expand.
func _player_live_crosshair_hit_radius(player: Node) -> float:
	if player == null:
		return 40.0
	if player.has_method("get_current_crosshair_hit_radius"):
		return float(player.get_current_crosshair_hit_radius())
	var weapon = player.get("weapon_shooting")
	if weapon and "power_target_circle" in weapon and float(weapon.power_target_circle) > 0.0:
		return float(weapon.power_target_circle)
	if "power_target_circle" in player and float(player.power_target_circle) > 0.0:
		return float(player.power_target_circle)
	return 40.0


func _trigger_avoider_crosshair_contact() -> void:
	if rock_type != RockSize.AVOIDER:
		return
	# Frozen avoiders are inert — no strike from reticle touch.
	if _freeze_shot_pending:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	rock_activated = false
	_avoider_armed = false
	_avoider_arm_token += 1
	_avoider_life_token += 1

	remove_from_group("Target")
	disable_collision()

	if current_particles != null:
		current_particles.emitting = false
	if %TrailParticles != null:
		%TrailParticles.emitting = false
	var red := get_node_or_null("%RedParticles") as GPUParticles3D
	if red:
		red.emitting = false

	expand_blast_radius()
	play_destroy_sfx()
	_shake_camera_avoider_hit()
	gl_PlayerState.add_strike()
	await was_hit_tween()
	if current_state == State.ACTIVE:
		enter_state(State.MISSED)


## Shoot a frozen avoider to destroy it with no strike (freeze disables the hazard).
func _destroy_frozen_avoider() -> void:
	if rock_type != RockSize.AVOIDER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return

	_freeze_shot_pending = false
	freeze = false
	if has_node("Freeze"):
		$Freeze.hide()
	if has_node("freeze_embers"):
		$freeze_embers.emitting = false

	play_hit_sfx()
	_expire_avoider_lifetime()


func _shake_camera_avoider_hit() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_avoider_hit"):
		player_cam.shake_camera_avoider_hit()
	elif player_cam and player_cam.has_method("shake_camera_impact"):
		player_cam.shake_camera_impact()


# --- Rock Chaser -------------------------------------------------------------

func _arm_chaser() -> void:
	_chaser_armed = false
	_chaser_lock_progress = 0.0
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	remove_from_group("Target")
	_chaser_saved_gravity = gravity_scale
	_chaser_arm_token += 1
	var token := _chaser_arm_token
	await get_tree().create_timer(chaser_arm_delay_sec).timeout
	if token != _chaser_arm_token:
		return
	if current_state != State.ACTIVE or rock_type != RockSize.CHASER:
		return
	_chaser_armed = true
	ignores_x_out_of_bounds = true
	ballistic_aim_active = false
	gravity_scale = chaser_float_gravity
	linear_damp = 0.8
	# Snap into the play rectangle if launch overshot it.
	_clamp_chaser_to_play_bounds(true)


func _update_chaser(delta: float) -> void:
	if not _chaser_armed:
		return

	# Locked = stop translating, keep spinning in place so it's obvious you can shoot.
	if _chaser_locked:
		linear_velocity = Vector3.ZERO
		global_position = _chaser_lock_pos
		gravity_scale = 0.0
		_update_chaser_lock_progress(delta)
		return

	var bounds := _chaser_play_bounds()
	var aim_xy := _crosshair_world_xy_at_depth(global_position.z)
	var away := Vector2(global_position.x - aim_xy.x, global_position.y - aim_xy.y)
	var desired := Vector2.ZERO
	if away.length_squared() > 0.0001:
		desired = away.normalized() * chaser_max_speed_xy

	# Keep flight inside the column/row rectangle — slide along edges instead of escaping.
	desired = _chaser_steer_inside_bounds(desired, bounds)

	var vel_xy := Vector2(linear_velocity.x, linear_velocity.y)
	var steered := vel_xy.move_toward(desired, chaser_flee_accel * delta)
	linear_velocity.x = steered.x
	linear_velocity.y = steered.y
	linear_velocity.z = move_toward(linear_velocity.z, 0.0, chaser_flee_accel * delta)

	_clamp_chaser_to_play_bounds(false)
	_update_chaser_lock_progress(delta)


func _update_chaser_lock_progress(delta: float) -> void:
	if _avoider_overlaps_crosshair():
		_chaser_lock_progress = minf(_chaser_lock_progress + delta, chaser_lock_time_sec)
		if not _chaser_locked and _chaser_lock_progress >= chaser_lock_time_sec:
			_begin_chaser_lock()
	else:
		_chaser_lock_progress = 0.0
		if _chaser_locked:
			_end_chaser_lock()


func _begin_chaser_lock() -> void:
	_chaser_locked = true
	_chaser_lock_pos = global_position
	linear_velocity = Vector3.ZERO
	gravity_scale = 0.0
	can_sleep = false
	sleeping = false
	if not is_in_group("Target"):
		add_to_group("Target")
	if not _chaser_lock_spin_applied:
		_chaser_lock_spin_applied = true
		var axis := Vector3(randf_range(-0.35, 0.35), 1.0, randf_range(-0.35, 0.35)).normalized()
		apply_torque_impulse(axis * chaser_lock_torque)
		angular_velocity = axis * chaser_lock_torque * 0.65


func _end_chaser_lock() -> void:
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	remove_from_group("Target")
	gravity_scale = chaser_float_gravity
	can_sleep = true



## Playable chase box: columns 1–8 on X, aim rows A–C on Y (at the rock's Z).
func _chaser_play_bounds() -> Rect2:
	var pad := chaser_bounds_padding
	var mgr := _find_rock_manager()
	if mgr:
		var x_right: float = float(mgr.column_to_x(1))
		var x_left: float = float(mgr.column_to_x(8))
		var y_top: float = float(mgr.AIM_LANE_Y[1])
		var y_bot: float = float(mgr.AIM_LANE_Y[3])
		var min_x := minf(x_left, x_right) + pad
		var max_x := maxf(x_left, x_right) - pad
		var min_y := minf(y_bot, y_top) + pad
		var max_y := maxf(y_bot, y_top) - pad
		return Rect2(Vector2(min_x, min_y), Vector2(maxf(max_x - min_x, 0.5), maxf(max_y - min_y, 0.5)))
	# Fallback if manager isn't found.
	return Rect2(Vector2(-7.0 + pad, 0.5 + pad), Vector2(14.0 - pad * 2.0, 6.5 - pad * 2.0))


func _find_rock_manager() -> RockManager:
	var n := get_parent()
	while n:
		if n is RockManager:
			return n as RockManager
		n = n.get_parent()
	return null


func _chaser_steer_inside_bounds(desired: Vector2, bounds: Rect2) -> Vector2:
	var pos := Vector2(global_position.x, global_position.y)
	var edge := maxf(chaser_bounds_padding, 0.2)
	var out := desired
	if pos.x <= bounds.position.x + edge and out.x < 0.0:
		out.x = absf(out.x)
	elif pos.x >= bounds.end.x - edge and out.x > 0.0:
		out.x = -absf(out.x)
	if pos.y <= bounds.position.y + edge and out.y < 0.0:
		out.y = absf(out.y)
	elif pos.y >= bounds.end.y - edge and out.y > 0.0:
		out.y = -absf(out.y)
	# Prefer sliding along the wall when boxed into a corner.
	if out.length_squared() < 0.0001:
		out = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * chaser_max_speed_xy * 0.5
	return out


func _clamp_chaser_to_play_bounds(force_center_if_outside: bool) -> void:
	var bounds := _chaser_play_bounds()
	var pos := global_position
	var was_out := not bounds.has_point(Vector2(pos.x, pos.y))
	pos.x = clampf(pos.x, bounds.position.x, bounds.end.x)
	pos.y = clampf(pos.y, bounds.position.y, bounds.end.y)
	if force_center_if_outside and was_out:
		pos.x = bounds.get_center().x
		pos.y = bounds.get_center().y
	global_position = pos
	# Kill velocity that still pushes out of the box.
	if is_equal_approx(pos.x, bounds.position.x) and linear_velocity.x < 0.0:
		linear_velocity.x = 0.0
	elif is_equal_approx(pos.x, bounds.end.x) and linear_velocity.x > 0.0:
		linear_velocity.x = 0.0
	if is_equal_approx(pos.y, bounds.position.y) and linear_velocity.y < 0.0:
		linear_velocity.y = 0.0
	elif is_equal_approx(pos.y, bounds.end.y) and linear_velocity.y > 0.0:
		linear_velocity.y = 0.0


func _on_rock_body_entered(body: Node) -> void:
	if rock_type != RockSize.AVOIDER:
		return
	if current_state != State.ACTIVE or not rock_activated:
		return
	if body == self or body is not RockInstance:
		return

	var other: RockInstance = body
	if other.current_state != State.ACTIVE or not other.rock_activated:
		return

	if other.rock_type == RockSize.AVOIDER:
		if avoider_explodes_when_hitting_avoider:
			_destroy_avoider_from_rock_collision(other)
			_destroy_avoider_from_rock_collision(self)
		return

	# Avoider hit a normal / hazard / other rock — always blow up the other rock.
	_destroy_rock_from_avoider_collision(other)
	if avoider_explodes_when_hitting_rock:
		_destroy_avoider_from_rock_collision(self)


func _destroy_rock_from_avoider_collision(other: RockInstance) -> void:
	if other == null or not is_instance_valid(other):
		return
	if other.current_state != State.ACTIVE or not other.rock_activated:
		return
	# Avoiders use the no-strike expire path, not a scored destroy.
	if other.rock_type == RockSize.AVOIDER:
		_destroy_avoider_from_rock_collision(other)
		return
	other.start_destroyed_process()


## Avoider pop from rock/avoider contact — explode with no strike (unlike reticle contact).
func _destroy_avoider_from_rock_collision(avoider: RockInstance) -> void:
	if avoider == null or not is_instance_valid(avoider):
		return
	if avoider.rock_type != RockSize.AVOIDER:
		return
	if avoider.current_state != State.ACTIVE or not avoider.rock_activated:
		return
	avoider._expire_avoider_lifetime()


## Pass-through vs collide for avoider↔avoider, based on `avoider_explodes_when_hitting_avoider`.
func _sync_avoider_collision_exceptions() -> void:
	if rock_type != RockSize.AVOIDER:
		return
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self or child is not RockInstance:
			continue
		var other: RockInstance = child
		if other.rock_type != RockSize.AVOIDER:
			continue
		if avoider_explodes_when_hitting_avoider:
			remove_collision_exception_with(other)
			other.remove_collision_exception_with(self)
		else:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)
