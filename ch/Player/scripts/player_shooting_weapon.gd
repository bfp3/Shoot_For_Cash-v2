extends Node3D


@onready var crosshair: TextureRect = $'../CanvasLayer/Crosshair/Inner_scope/TextureRect'
@onready var crosshair_left: TextureRect = $'../CanvasLayer/Multiscopes/Inner_scope2/TextureRect'

#@onready var crosshair_right = $"../Crosshair/Multiscopes/Inner_scope3/TextureRect"
@onready var current_bullet = BULLET_STAGE_1

const BULLET_VISUAL_1 = preload('uid://0qrt4gvskifx')
const BULLET_STAGE_1 = preload('uid://0qrt4gvskifx')

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
var time_ran_out := false

var can_fire_weapon := true

@onready var player: Player = $'..'
@export var player_gun : Node3D
@export var view_limit := 100.0

var power_target_circle := 60.0
var power_bullet_speed = 30.0
var power_bullet_damage : int = 1
var power_bullet_delay := 0.5

@onready var player_camera := $"../Cam_pivot/Camera3D"

var auto_fire := false
var current_xray_targets : Array = []
var pitch_adjustment := 0.02

var shooting_sky_mine := false
var round_manager : RoundManager


func _ready() -> void:
	await get_tree().process_frame
	
	round_manager = get_tree().get_first_node_in_group('round_manager')
	if round_manager != null:
		#round_manager == RoundManager && 
		print('found the round_manager')

#func _process(delta: float) -> void:
	#if player.current_state != player.State.ACTIVE:
		#return
	
	#if Engine.get_process_frames() % 6 != 0:
		#return
	#update_xray_targets()

func apply_upgrades() -> void:
	power_target_circle = player.power_target_circle
	power_bullet_speed = player.power_bullet_speed
	power_bullet_damage = player.power_bullet_damage
	power_bullet_delay = player.power_bullet_delay
	
	if gl_PlayerState.dataset.power_auto_fire > 0:
		auto_fire = true
	
	current_bullet = BULLET_STAGE_1
	


func get_targets_in_scope() -> Array:
	
	var max_check_distance := view_limit
	var targets_in_scope: Array = []

	var targets = get_tree().get_nodes_in_group("Target")

	for target in targets:

		if !is_instance_valid(target):
			continue
			
		if target.visible == false:
			continue

		if player_camera.is_position_behind(target.global_position):
			continue

		if player_camera.global_position.distance_squared_to(target.global_position) > max_check_distance * max_check_distance:
			continue
			
		if !has_line_of_sight(target):
			%Crosshair.cannot_shoot_obstacle_in_way()
			continue

		var screen_pos = player_camera.unproject_position(target.global_position)

		# Distance from scope center to rock center
		var center_dist = screen_pos.distance_to(crosshair.global_position)

		#var left_dist = screen_pos.distance_to(crosshair.global_position)
		#if crosshair_left.visible:
			#left_dist = screen_pos.distance_to(crosshair_left.global_position)
		#var closest_dist = min(center_dist, left_dist)
		var closest_dist = center_dist

		# Calculate the rock's radius on screen
		var world_scale: Vector3 = target.main_col.global_transform.basis.get_scale()
		var world_radius: float = world_scale.x * 0.5

		var edge_screen_pos = player_camera.unproject_position(
			target.global_position + player_camera.global_basis.x * world_radius
		)

		var screen_radius = screen_pos.distance_to(edge_screen_pos)

		var scope_hit = "center"
		#if left_dist < center_dist:
			#scope_hit = "left"

		# Circle overlap test
		if closest_dist <= power_target_circle + screen_radius:
			targets_in_scope.append({
				"target": target,
				"distance": closest_dist,
				"scope_hit": scope_hit
			})

	targets_in_scope.sort_custom(func(a, b):
		return a.distance < b.distance
	)

	return targets_in_scope

func has_line_of_sight(target: Node3D) -> bool:
	var origin = player_camera.global_position
	var target_pos = target.global_position

	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return true

	var collider = result.collider

	# Hit the target directly
	if collider == target:
		return true

	# Ignore other target objects
	if collider.is_in_group("Target"):
		return true

	# Only StaticBody3D blocks line of sight
	if collider is StaticBody3D:
		if collider.name.contains('Shover'):
			return true
		else:
			return false

	return true

	
func mark_target() -> void:
	var screen_pos = crosshair.global_position #+ (crosshair.size * 0.5)
	var origin = player_camera.project_ray_origin(screen_pos)
	var direction = player_camera.project_ray_normal(screen_pos)
	var end = origin + direction * view_limit

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(origin, end)
	)

	# Only allow ONE collider to be marked
	if result.has("collider"):
		var collider = result.collider

		if collider.has_method("marking_myself_as_target"):
			collider.marking_myself_as_target()
			return




func update_xray_targets() -> void:

	var new_targets = get_targets_in_scope()

	# Disable only targets that left scope
	for target in current_xray_targets:
		if !new_targets.has(target):
			if is_instance_valid(target):
				target.set_xray_visible(false)

	# Enable only newly entered targets
	for target in new_targets:
		if !current_xray_targets.has(target):
			if is_instance_valid(target):
				target.set_xray_visible(true)

	current_xray_targets = new_targets




func XXupdate_xray_targets() -> void:

	var targets_in_scope = get_targets_in_scope()

	var all_targets = get_tree().get_nodes_in_group("Target")

	# First disable all
	for target in all_targets:

		if !is_instance_valid(target):
			continue

		if target.has_method("set_xray_visible"):
			target.set_xray_visible(false)

	# Then enable only scanned targets
	for target in targets_in_scope:

		if !is_instance_valid(target):
			continue

		if target.has_method("set_xray_visible"):
			target.set_xray_visible(true)


func _reset_pitch_adjustment() -> void:
	pitch_adjustment = 0.02
	
	
func _cannot_shoot() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	
func process_target_hit(target, damage, screen_offset) -> void:
	await get_tree().create_timer(power_bullet_speed).timeout
	if is_instance_valid(target):
		target.hit_by_player(
			damage,
			screen_offset
		)
		
		
		
func shoot_target() -> void:
	
	if !can_fire_weapon:
		return
	
	if shooting_sky_mine:
		return
	
	round_manager.bullet_active = true
	
	_reset_pitch_adjustment()

	var targets = get_targets_in_scope()


	if gl_PlayerState.dataset.power_sky_mine > 0:
		shooting_sky_mine = true

		if !targets.is_empty():
			targets = [targets[0]] # Only the closest target

	if targets.is_empty():
		var shootable_hit = get_shootable_hit()

		if !shootable_hit.is_empty():
			shoot_shootable_object(shootable_hit)
		else:
			shoot_bullet_without_target()

		shooting_sky_mine = false
		return

	$"../SFX/Flicker_sound".play()
	get_parent().player_did_not_miss()

	for target_data in targets:

		var target = target_data.target

		if !is_instance_valid(target):
			continue

		var damage := power_bullet_damage

		#if target_data.scope_hit == "left":
			#damage *= 2

		#if target.has_method("marking_myself_as_target"):
			#target.marking_myself_as_target()

		%Crosshair.crosshair_shake()
		player_gun.get_barrel_position(target.global_position.x)
		player_camera.shake_camera_shooting()

		target.play_accurate_sounds()

		spawn_projectile(target, power_bullet_speed)

		var rock_screen_pos = player_camera.unproject_position(target.global_position)
		var screen_offset = rock_screen_pos - crosshair.global_position

		# Start the hit timer independently
		process_target_hit.call_deferred(
			target,
			damage,
			screen_offset
		)

		if time_ran_out:
			break

		var delay := power_bullet_delay

		if shooting_sky_mine:
			delay += 0.5

		await get_tree().create_timer(delay).timeout
		
		shooting_sky_mine = false
	
func can_shoot(_can_shoot : bool) -> void:
	can_fire_weapon = _can_shoot
	
	
func spawn_projectile(_target : Node3D, _power_bullet_speed : float, result_pos : Vector3 = Vector3.ZERO) -> void:

	var new_bullet = BULLET_VISUAL_1.instantiate()

	if _target != null:
		new_bullet.target_node = _target
	else:
		new_bullet.target_node = null

	new_bullet.power_bullet_speed = power_bullet_speed

	get_tree().get_current_scene().add_child(new_bullet)

	new_bullet.global_transform = player_gun.get_barrel_position()

	if _target != null:
		new_bullet.bullet_setup(_target, _power_bullet_speed)
	else:
		# No target — fly toward the raycast hit point / horizon instead
		new_bullet.bullet_setup_no_target(result_pos, _power_bullet_speed)


func Xspawn_projectile(_target : Node3D, _power_bullet_speed : float, result_pos : Vector3 = Vector3.ZERO) -> void:

			
	#var new_bullet = current_bullet.instantiate()
	var new_bullet = BULLET_VISUAL_1.instantiate()
	if _target != null:
		new_bullet.target_node = _target
	else:
		new_bullet.target_node = null
		_target = null
	
	new_bullet.power_bullet_speed = power_bullet_speed
	#new_bullet.power_bullet_damage = power_bullet_damage
	
	get_tree().get_current_scene().add_child(new_bullet)
	
	#var player_gun = get_tree().get_nodes_in_group('player_gun')[0]
	#
	new_bullet.global_transform = player_gun.get_barrel_position()

	
	#player_camera.shake_camera_shooting()
	#new_bullet.bullet_setup(_target, result_pos, 0.0)
	new_bullet.bullet_setup(_target, _power_bullet_speed)
	
	#await get_tree().create_timer(await_time).timeout
	


func play_accurate_sounds() -> void:
	return
	#await get_tree().create_timer(0.05).timeout
	#create_shot_instance(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	#pitch_adjustment += 0.05
	

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


func play_missed_sounds() -> void:	
	pitch_adjustment = 0.02
	%Crosshair.crosshair_nothing_to_shoot()
	%cannot_shoot_sfx.play(0.91)

func shoot_bullet_without_target() -> void:
	if auto_fire:
		return

	#%cannot_shoot_sfx.play(0.91)
	#$"../SFX/Flicker_sound".play()
	play_missed_sounds()
	await get_tree().create_timer(0.1).timeout
	create_shot_instance(ON_TARGET_SFX, -35.0, 0.65 + pitch_adjustment)
	%Crosshair.crosshair_shake()
	player_camera.shake_camera_shooting()
	round_manager.bullet_active = false


	# Raycast from the crosshair center out into the world to find
	# where the "missed" bullet should fly toward.
	var screen_pos = crosshair.global_position
	var origin = player_camera.project_ray_origin(screen_pos)
	var direction = player_camera.project_ray_normal(screen_pos)
	var end = origin + direction * view_limit

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(origin, end)
	)

	var aim_point : Vector3
	if result.has("position"):
		aim_point = result.position
	else:
		aim_point = end

	if player_gun:
		player_gun.get_barrel_position(aim_point.x)

	spawn_projectile(null, power_bullet_speed, aim_point)

	
func get_shootable_hit() -> Dictionary:
	
	var screen_pos = crosshair.global_position
	var origin = player_camera.project_ray_origin(screen_pos)
	var direction = player_camera.project_ray_normal(screen_pos)
	var end = origin + direction * view_limit

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(origin, end)
	)

	if result.is_empty():
		return {}

	var collider = result.collider

	if collider is StaticBody3D and !collider.is_in_group('Target') || collider is StaticBody3D && !collider.is_in_group('bonus_time_item'):
		return result

	return {}
	


func shoot_shootable_object(hit: Dictionary) -> void:
	var hit_position: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal
	
	$"../SFX/Flicker_sound".play()

	if player_gun:
		player_gun.get_barrel_position(hit_position.x)

	player_camera.shake_camera_shooting()
	%Crosshair.crosshair_shake()

	spawn_projectile(null, power_bullet_speed, hit_position)

	process_shootable_hit.call_deferred(hit_position, hit_normal)


func process_shootable_hit(hit_position: Vector3, hit_normal: Vector3) -> void:
	await get_tree().create_timer(power_bullet_speed).timeout
	explode_at_point(hit_position, hit_normal)


func explode_at_point(explosion_position: Vector3, normal: Vector3) -> void:
	var explosion = %ShootWallVFX #.duplicate()
	#get_tree().get_current_scene().add_child(explosion)
	explosion.global_position = explosion_position

	#if explosion.has_method("orient_to_normal"):
		#explosion.orient_to_normal(normal)

	round_manager.bullet_active = false
	explosion.play_particles = true
	%take_damage_sfx.play()
	
func Xshoot_bullet_without_target() -> void:
	if auto_fire:
		return
	%cannot_shoot_sfx.play(0.91)
	
	return
	#play_accurate_sounds()
#
	#EventBus.instance.player_shot_weapon.emit(global_position)
	#get_parent().player_did_not_miss()
#
	#var new_bullet = current_bullet.instantiate()
#
	#new_bullet.target_node = null
	#new_bullet.power_bullet_speed = power_bullet_speed
	#new_bullet.power_bullet_damage = power_bullet_damage
#
	#var player_gun = get_tree().get_nodes_in_group("player_gun")[0]
#
	#get_tree().get_current_scene().add_child(new_bullet)
#
	#var barrel_pos = player_gun.get_barrel_position()
	#new_bullet.global_position = barrel_pos
#
	## TRUE crosshair center
	#var crosshair = $"../Crosshair/Inner_scope/TextureRect"
	##var screen_pos = crosshair.global_position + crosshair.size * 0.5
	#var screen_pos = crosshair.global_position #+ crosshair_offset
	#var ray_origin = player_camera.project_ray_origin(screen_pos)
	#var ray_direction = player_camera.project_ray_normal(screen_pos)
#
	#var aim_point = ray_origin + ray_direction * 500.0
#
	#new_bullet.move_direction =	(aim_point - barrel_pos).normalized()
#
	#player_camera.shake_camera_shooting()
#
	#await get_tree().create_timer(await_time).timeout
	
	

#func activate_pinch():
#
	#var targets = get_targets_in_scope()
#
	#if targets.is_empty():
		#return
#
	#var screen_pos = crosshair.global_position
	#var origin = player_camera.project_ray_origin(screen_pos)
	#var direction = player_camera.project_ray_normal(screen_pos)
#
	#var pinch_center = origin + direction #* view_limit
#
	#for target in targets:
#
		#if !(target is RigidBody3D):
			#continue
#
		#var body := target as RigidBody3D
		#pinch_center = origin + direction * body.global_position.z
		#var radius = 0.5 # get_body_radius(body)
		#body.gravity_scale = 0.0
		#body.linear_velocity = Vector3.ZERO
		## spread bodies around center
		#var random_offset =	Vector3(
				#randf_range(-radius, radius),
				#randf_range(-radius, radius),
				#0
			#)
		#var destination = Vector3(pinch_center.x, pinch_center.y, body.global_position.z) + random_offset
		#destination.z = body.global_position.z

		#var tween = create_tween()
#
		#tween.tween_property(
			#body, "global_position", destination, 0.2)


#func Xshoot_target() -> void:
	#_reset_pitch_adjustment()
	#
	#var targets = get_targets_in_scope()
#
	#if targets.is_empty():
		#shoot_bullet_without_target()
		#play_missed_sounds()
		#return
	#else:
		#$"../SFX/Flicker_sound".play()
		#get_parent().player_did_not_miss()
#
	#for target_data in targets:
#
		#var target = target_data.target
#
		#if !is_instance_valid(target):
			#continue
#
		#var damage = power_bullet_damage
#
		#if target_data.scope_hit == "left":
			#damage *= 2
#
		#if target.has_m4ethod("marking_myself_as_target"):
			#target.marking_myself_as_target()
#
		#%Crosshair.crosshair_shake()
		#player_gun.get_barrel_position(target.global_position.x)
		#$'../Cam_pivot/Camera3D'.shake_camera_shooting()
#
		##play_accurate_sounds()
		#target.play_accurate_sounds()
#
		#spawn_projectile(target, power_bullet_speed)
#
		#var rock_screen_pos = player_camera.unproject_position(target.global_position)
		#var screen_offset = rock_screen_pos - crosshair.global_position
#
		#await get_tree().create_timer(power_bullet_speed).timeout
#
		#target.hit_by_player(
			#damage,
			#screen_offset
		#)
#
		#await get_tree().create_timer(power_bullet_delay).timeout
#
		#if time_ran_out:
			#break
			
