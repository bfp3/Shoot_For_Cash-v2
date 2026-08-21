extends Node3D

@onready var crosshair: TextureRect = $'../CanvasLayer/Crosshair/Inner_scope/TextureRect'
@onready var current_bullet = BULLET_STAGE_1

@export var player_camera : Camera3D
@export var stable_camera : Camera3D
#@onready var crosshair_right = $"../Crosshair/Multiscopes/Inner_scope3/TextureRect"

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

var shot_with_right_click := false
var temp_label_pos := Vector3.ZERO

var current_xray_targets : Array = []
var pitch_adjustment := 0.02

var shooting_sky_mine := false
var round_manager : RoundManager
## Active projectile scene (default or alternate weapon).
var active_bullet_scene: PackedScene = BULLET_VISUAL_1


func _ready() -> void:
	await get_tree().process_frame
	
	round_manager = get_tree().get_first_node_in_group('round_manager')


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
	#power_bullet_delay = player.power_bullet_delay
	power_bullet_delay = 0.05


	if active_bullet_scene == null:
		active_bullet_scene = BULLET_STAGE_1
	current_bullet = active_bullet_scene


func set_active_bullet_scene(scene: PackedScene) -> void:
	active_bullet_scene = scene if scene else BULLET_VISUAL_1
	current_bullet = active_bullet_scene
	


func get_targets_in_scope() -> Array:
	
	var max_check_distance := view_limit
	var targets_in_scope: Array = []

	var targets = get_tree().get_nodes_in_group("Target")

	for target in targets:

		if !is_instance_valid(target):
			continue
			
		if target.visible == false:
			continue

		if stable_camera.is_position_behind(target.global_position):
			continue

		if stable_camera.global_position.distance_squared_to(target.global_position) > max_check_distance * max_check_distance:
			continue
			
		if !has_line_of_sight(target):
			%Crosshair.cannot_shoot_obstacle_in_way()
			continue

		var screen_pos = stable_camera.unproject_position(target.global_position)

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

		var edge_screen_pos = stable_camera.unproject_position(
			target.global_position + stable_camera.global_basis.x * world_radius
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
	var origin = stable_camera.global_position
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
	var origin = stable_camera.project_ray_origin(screen_pos)
	var direction = stable_camera.project_ray_normal(screen_pos)
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
	await get_tree().create_timer(power_bullet_speed, false).timeout
	if is_instance_valid(target):
		var freeze_shot := false
		if player and player.get("using_alt_weapon") == true:
			freeze_shot = true
			
		if target is RockInstance:
			if target.has_method("hit_by_player"):
				target.hit_by_player(
					damage,
					screen_offset,
					freeze_shot
				)
		else:
			if target.has_method("hit_by_player"):
				target.hit_by_player(
					damage,
					screen_offset
				)
			



func shoot_target() -> void:

	if !can_fire_weapon:
		return

	#if shooting_sky_mine:
		#return
	
	round_manager.bullet_active = true

	
	_reset_pitch_adjustment()

	var double_power: bool = get_parent()._scope_at_min
	var targets = get_targets_in_scope()

	# If a special mid-round target is the closest aim, only shoot that — don't multi-hit rocks.
	if not targets.is_empty() and _is_special_midround_target(targets[0].target):
		targets = [targets[0]]

	var rock_count := 0
	var rocks_to_destroy := []

	for target_data in targets:
		var target = target_data.target
		# Balloons / oranges / ammo / balloon-check do not count toward multi-shot.
		if not _counts_for_multishot(target):
			continue
		rock_count += 1
		rocks_to_destroy.append(target)

	#if gl_PlayerState.dataset.power_sky_mine > 0 && !shot_with_right_click:
		#shooting_sky_mine = true

		#if !targets.is_empty():
			#targets = [targets[0]] # Only the closest target

	if targets.is_empty():
		var shootable_hit = get_shootable_hit()

		if !shootable_hit.is_empty():
			shoot_shootable_object(shootable_hit)
		else:
			shoot_bullet_without_target()
			if player and player.has_method("register_accuracy_miss"):
				player.register_accuracy_miss()
		
		shooting_sky_mine = false
		return

	$"../SFX/Flicker_sound".play()
	get_parent().player_did_not_miss()
	if player and player.has_method("register_accurate_shot"):
		player.register_accurate_shot()

	for target_data in targets:

		var target = target_data.target

		if !is_instance_valid(target):
			continue

		if player.shot_count <= 0:
			break

		var damage := power_bullet_damage

		if double_power:
			damage += 1
			power_bullet_speed /= 4

		%Crosshair.crosshair_shake()
		player_gun.get_barrel_position(target.global_position.x)
		player_camera.shake_camera_shooting()

		if gl_PlayerState.dataset.power_balloon_buster > 0:
			if target.has_method("apply_marked_ability") && target is not RockInstance:
				target.apply_marked_ability()
		
		if shooting_sky_mine:
			if target is RockInstance:
				target.player_has_marked_rock = true
				#shooting_sky_mine = false
				
				
		target.start_bullet_to_target()

		if shot_with_right_click:
			damage = 0
			power_bullet_speed /= 4

		if not spawn_projectile(target, power_bullet_speed):
			break

		var rock_screen_pos = stable_camera.unproject_position(target.global_position)
		var screen_offset = rock_screen_pos - crosshair.global_position

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

		await get_tree().create_timer(delay, false).timeout
		if shooting_sky_mine:
			shooting_sky_mine = false
			break
		
		shooting_sky_mine = false

	if rocks_to_destroy.size() >= 2 && !shot_with_right_click:
		## Glory: fail as soon as a double is scored (don't wait for clear / wave end).
		if rock_count >= 2 and round_manager and round_manager.has_method("has_active_special_challenge") \
			and bool(round_manager.has_active_special_challenge("no_doubles")):
			if round_manager.has_method("on_special_challenge_double"):
				round_manager.on_special_challenge_double()
			return
		# Midpoint of the rocks at the moment of the multi (before destroy VFX moves them).
		var hit_sum := Vector3.ZERO
		var hit_count := 0
		for rock in rocks_to_destroy:
			if is_instance_valid(rock):
				hit_sum += rock.global_position
				hit_count += 1
		if hit_count > 0:
			temp_label_pos = hit_sum / float(hit_count)
		await wait_for_all_rocks_destroyed(rocks_to_destroy)
		if gl_PlayerState.dataset.total_hazards > 0:
			return
		activate_multishot_bonus(rock_count)
		
	
func can_shoot(_can_shoot : bool) -> void:
	can_fire_weapon = _can_shoot


## Out-of-ammo path: fire only if early-exit or ammo-reload is in the reticle.
func shoot_early_exit_if_aimed() -> bool:
	return shoot_special_midround_target_if_aimed()


func _is_special_midround_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target.is_in_group("early_exit_target") or target.is_in_group("ammo_reload_target") or target.is_in_group("ammo_balloon") or target.is_in_group("checkpoint")


func _counts_for_multishot(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if _is_special_midround_target(target):
		return false
	if target is RockInstance:
		return true
	return false


func shoot_special_midround_target_if_aimed() -> bool:
	if !can_fire_weapon:
		return false

	var targets := get_targets_in_scope()
	var special_target: Node3D = null
	for target_data in targets:
		var target = target_data.target
		if _is_special_midround_target(target):
			special_target = target
			break

	if special_target == null:
		return false

	round_manager.bullet_active = true
	_reset_pitch_adjustment()

	$"../SFX/Flicker_sound".play()
	%Crosshair.crosshair_shake()
	player_gun.get_barrel_position(special_target.global_position.x)
	player_camera.shake_camera_shooting()

	if special_target.has_method("start_bullet_to_target"):
		special_target.start_bullet_to_target()

	if not spawn_projectile(special_target, power_bullet_speed, Vector3.ZERO, true):
		round_manager.bullet_active = false
		return false

	var rock_screen_pos = stable_camera.unproject_position(special_target.global_position)
	var screen_offset = rock_screen_pos - crosshair.global_position
	process_target_hit.call_deferred(special_target, power_bullet_damage, screen_offset)
	if player and player.has_method("register_accurate_shot"):
		player.register_accurate_shot()
	return true
	
	
func spawn_projectile(_target : Node3D, _power_bullet_speed : float, result_pos : Vector3 = Vector3.ZERO, free_shot := false) -> bool:

	if not free_shot and not player.consume_ammo(1):
		return false

	var bullet_scene: PackedScene = active_bullet_scene if active_bullet_scene else BULLET_VISUAL_1
	var new_bullet = bullet_scene.instantiate()

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

	return true



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
	
	#%cannot_shoot_sfx.play(0.91)
	#$"../SFX/Flicker_sound".play()
	play_missed_sounds()
	await get_tree().create_timer(0.1, false).timeout
	create_shot_instance(ON_TARGET_SFX, -35.0, 0.65 + pitch_adjustment)
	%Crosshair.crosshair_shake()
	player_camera.shake_camera_shooting()
	round_manager.bullet_active = false


	# Raycast from the crosshair center out into the world to find
	# where the "missed" bullet should fly toward.
	var screen_pos = crosshair.global_position
	var origin = stable_camera.project_ray_origin(screen_pos)
	var direction = stable_camera.project_ray_normal(screen_pos)
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
	var origin = stable_camera.project_ray_origin(screen_pos)
	var direction = stable_camera.project_ray_normal(screen_pos)
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

	#player_camera.shake_camera_shooting()
	%Crosshair.crosshair_shake()

	spawn_projectile(null, power_bullet_speed, hit_position)

	process_shootable_hit.call_deferred(hit_position, hit_normal)

func process_shootable_hit(hit_position: Vector3, hit_normal: Vector3) -> void:
	await get_tree().create_timer(power_bullet_speed, false).timeout
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
	player_camera.shake_camera_shooting()
	
func wait_for_all_rocks_destroyed(rocks: Array) -> void:
	while true:
		var remaining := 0

		for rock in rocks:
			if not is_instance_valid(rock):
				continue
			if rock.rock_activated:
				remaining += 1

		if remaining == 0:
			return

		await get_tree().process_frame
	
func activate_multishot_bonus(rock_count: int) -> void:
	
	print('called a Multi')
	if gl_PlayerState.dataset.total_hazards > 0:
		return

	## Glory special challenge: any double / multi fails the round.
	if rock_count >= 2 and round_manager and round_manager.has_method("on_special_challenge_double"):
		if round_manager.has_method("has_active_special_challenge") \
			and bool(round_manager.has_active_special_challenge("no_doubles")):
			round_manager.on_special_challenge_double()
			return
	
	var multi_shot := get_tree().get_first_node_in_group('multi_shot')
	multi_shot.multi_shot(rock_count, temp_label_pos)
	
	#%ComboMode.start()
	
	
