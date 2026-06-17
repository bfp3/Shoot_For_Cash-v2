extends Node3D

const ON_TARGET_SFX = preload('res://400_sounds/gun_sfx/opt_3_fade_shortened.wav')

const ARROW = preload("res://300_assets/Arrows/Arrow.tscn")
const BULLET_RIGID = preload("res://200_characters/weapons/bullet_rigid.tscn")
const BULLET = preload("res://200_characters/weapons/bullet_area3D.tscn")

@onready var camera_system: Camera3D = $"../Cam_pivot/Camera3D"

@export var await_time := 0.19

@onready var hand_marker: Marker3D = $"../Cam_pivot/Hand/Marker3D"
@onready var camera_3d: Camera3D = $"../Cam_pivot/Camera3D"
@export var view_limit := 300.0 #10.0

var firing_weapon := false
var bullet_speed := 0.0

var pitch_adjustment := 0.02

func _ready() -> void:
	EventBus.instance.game_lost.connect(_cannot_shoot)
	EventBus.instance.finished_standard_reload.connect(_reset_pitch_adjustment)
	
func _reset_pitch_adjustment() -> void:
	pitch_adjustment = 0.02
	
func _cannot_shoot() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func shoot_target() -> void:
	var space_state = get_world_3d().direct_space_state
	var start: Vector3
	var direction: Vector3

	# Calculate the direction from the crosshair position in the screen space
	var viewport = get_viewport()
	var screen_pos = $"../Crosshair/Inner_scope/TextureRect".global_position # crosshair.position
	var mouse_ray = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)
	#$"../Crosshair/aim_texture".position = screen_pos + Vector2(-14.0, -11.0)
	start = mouse_ray #$Crosshair2/Rail_position.global_position
	direction = ray_dir * view_limit  # You can adjust this distance as needed
	
	#print(direction, " DIRECTION")
	var end = start + direction
	var query = PhysicsRayQueryParameters3D.create(start, end)
	var result = space_state.intersect_ray(query)
	
	
	if result:
		
		if result.collider.is_in_group('Target'): # && !result.collider.target_hit:
			var target = result.collider
			
			var future_target_position
			
			
			if target.has_method('add_unique_marker'):
				target.add_unique_marker(result.position)
			
			
			if target.has_method('spawn_my_arrow'):
				camera_system.camera_shake_on_target()
				
				EventBus.instance.player_shot_weapon.emit(result.position)
				
				if target.is_in_group('Spotter'):
					target.spawn_my_arrow()
					play_accurate_sounds()
				#else:
				
					#spawn_projectile(result.collider)
				
				if target.is_in_group('backing_wall'):
					#spawn_missed_shot()
					#spawn_projectile(result.collider)
					target.spawn_my_arrow()
					play_missed_sounds()
				else:
					spawn_tracking_bullet()
					
				#var player_gun = get_tree().get_nodes_in_group('player_gun')[0]
				#if player_gun:
					#player_gun.spawn_second_missile(target)
				

				
		elif result.collider.is_in_group('Ammo_crate'):
			spawn_bullet(result.position)
		
		else:
			direction = result.position
			#spawn_bullet(direction)
			shoot_second_weapon(direction)
		
	else:
		return
		spawn_bullet(direction)


func spawn_projectile(_target : Node3D) -> void:
	var SPOTTER_PROJECTILE = preload('res://200_characters/weapons/Simple_Bullet.tscn')
	for i in range(2):
		
		var new_bullet = SPOTTER_PROJECTILE.instantiate()
		new_bullet.target_node = _target
		get_tree().get_current_scene().add_child(new_bullet)
		var player_gun = get_tree().get_nodes_in_group('player_gun')[0]
		if player_gun:
			new_bullet.global_position = player_gun.get_barrel_position()
		else:
			new_bullet.global_position = $'..'.global_position
			
		await get_tree().create_timer(0.15).timeout
		

func play_missed_sounds() -> void:
	#for i in range(2):
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db - 5.0)
	#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db)
	await get_tree().create_timer(await_time).timeout
	CommonCode.play_sound_duplicate_instance(%gunsfx_second, 0.0, %gunsfx_second.volume_db)
	#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db - 7.0)
	#await get_tree().create_timer(0.15).timeout

func play_accurate_sounds() -> void:
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db - 5.0)
	CommonCode.play_sound_instance_pitch_adjusted(ON_TARGET_SFX, -25.0 + pitch_adjustment, 0.7 + pitch_adjustment)
	#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db)
	await get_tree().create_timer(await_time).timeout
	CommonCode.play_sound_duplicate_instance(%gunsfx_second, 0.0, %gunsfx_second.volume_db)
	pitch_adjustment += 0.05
	#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db - 7.0)
	#await get_tree().create_timer(0.15).timeout
	
	
	#for i in range(2):
		#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db)
		##CommonCode.play_sound_duplicate_instance($'../gun/on_target_sfx', 0.0, $'../gun/on_target_sfx'.volume_db)
		#
		#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db - 15.0)
		#pitch_adjustment += 0.05
		#await get_tree().create_timer(0.15).timeout
		

func spawn_missed_shot() -> void:

	if firing_weapon:
		return
		
	firing_weapon = true

	play_missed_sounds()
	await get_tree().create_timer(0.05).timeout
	
	firing_weapon = false
	$"../Crosshair_3D".shake_gun()
	$"../Crosshair".crosshair_shake()

		

func shoot_target_rigid() -> void:

	
	var space_state = get_world_3d().direct_space_state
	var start: Vector3
	var direction: Vector3

	var viewport = get_viewport()
	var screen_pos = $"../Crosshair/Inner_scope/TextureRect".global_position # crosshair.position
	var mouse_ray = camera_3d.project_ray_origin(screen_pos)
	var ray_dir = camera_3d.project_ray_normal(screen_pos)
	$"../Crosshair/aim_texture".position = screen_pos + Vector2(-14.0, -11.0)
	start = mouse_ray #$Crosshair2/Rail_position.global_position
	direction = ray_dir * 1 #view_limit  # You can adjust this distance as needed
	
	#print(direction, " DIRECTION")
	var end = start + direction
	var query = PhysicsRayQueryParameters3D.create(start, end)
	var result = space_state.intersect_ray(query)
	
	if result:
		shoot_second_weapon(direction)
	else:
		shoot_second_weapon(direction)

func prepare_arrow(target_pos: Vector3):
	var new_arrow = ARROW.instantiate()
	get_tree().get_current_scene().add_child(new_arrow)
	new_arrow.set_direction(target_pos)
	new_arrow.global_position = hand_marker.global_position
	
func spawn_tracking_bullet() -> void:

	if firing_weapon:
		return
	
	var HUD_lamp_mini = get_tree().get_nodes_in_group('HUD_lamp_mini')[0]
	if HUD_lamp_mini:
		HUD_lamp_mini.shot_hit_blinking()
		$'../Ammo_panel_3D/Small_light/flashing_light'.shot_hit_blinking()

	firing_weapon = true
	play_accurate_sounds()
	
	#for i in range(2):
		#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db)
		##CommonCode.play_sound_duplicate_instance($'../gun/on_target_sfx', 0.0, $'../gun/on_target_sfx'.volume_db)
		#CommonCode.play_sound_instance_pitch_adjusted(ON_TARGET_SFX, -25.0 + pitch_adjustment, 0.7 + pitch_adjustment)
		#CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db)
		#pitch_adjustment += 0.05
		#await get_tree().create_timer(0.15).timeout
	#await get_tree().create_timer(0.05).timeout
	
	
	firing_weapon = false
	camera_3d.shake_camera()
	$"../Crosshair_3D".shake_gun()
	$"../Crosshair".crosshair_shake()

	
func spawn_bullet(target_pos: Vector3) -> void:
	

	
	if firing_weapon:
		return
		
	firing_weapon = true
	
	#var bullet = $bullet
	var bullet = BULLET.instantiate()
	get_tree().get_current_scene().add_child(bullet)
	
	bullet.hit_something = false
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db)
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db)

	var player_gun = get_tree().get_first_node_in_group('player_gun')
	bullet.global_position = player_gun.get_barrel_position()
	
	#bullet.global_position = $"../Crosshair_3D/Rail_position".global_position
	await get_tree().create_timer(0.02).timeout
	#bullet.shoot(target_pos, bullet_speed) #RIGID BODY
	bullet.shoot(target_pos)
	
	await get_tree().create_timer(0.05).timeout
	
	firing_weapon = false
	camera_3d.shake_camera()
	$"../Crosshair_3D".shake_gun()
	$"../Crosshair".crosshair_shake()

	bullet_speed = 0.0
	
	

func shoot_second_weapon(target_pos : Vector3) -> void:
	
	if firing_weapon:
		return
		
	firing_weapon = true
	
	#var bullet = $bullet
	var bullet = BULLET_RIGID.instantiate()
	get_tree().get_current_scene().add_child(bullet)
	
	bullet.hit_something = false
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx", 0.0, $"../gun/gunsfx".volume_db)
	CommonCode.play_sound_duplicate_instance($"../gun/gunsfx_old", 0.2, $"../gun/gunsfx_old".volume_db)

	var player_gun = get_tree().get_first_node_in_group('player_gun')
	bullet.global_position = player_gun.get_barrel_position()
	#bullet.global_position = $"../Crosshair_3D/Rail_position".global_position
	await get_tree().create_timer(0.02).timeout
	bullet.shoot(target_pos) #RIGID BODY
	
	
	await get_tree().create_timer(0.05).timeout
	
	firing_weapon = false
	camera_3d.shake_camera()
	$"../Crosshair".crosshair_shake()
	bullet_speed = 0.0
	firing_weapon = false
