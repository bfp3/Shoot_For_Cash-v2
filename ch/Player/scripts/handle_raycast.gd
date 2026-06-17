extends Node3D

#@onready var crosshair_pos := $"../Crosshair/Inner_scope/TextureRect"
#@onready var camera_3d: Player_Camera = $'../Cam_pivot/Camera3D'
#@onready var crosshair: Player_Crosshair = $'../Crosshair'
#@onready var picking_raycast: Node3D = $Picking_raycast
#
#@export var distance_from_camera := 20.0
#var current_distance_from_camera := 20.0
#
#@export var throw_force := 10.0 #30.0
#var picked_object = null
#@export var pull_power := 10.0
#var toggling_carrying = false
#
#@export var target_check_interval := 0.01
#var time_since_last_check := 0.0
#var is_targeting := false





#func _physics_process(delta: float) -> void:
	#time_since_last_check += delta
	#if time_since_last_check >= target_check_interval:
		#check_for_target()
		#time_since_last_check = 0.0

	#handle_right_click_picking()
	

#func check_for_target() -> void:
	#var screen_pos = crosshair_pos.global_position
	#var origin = camera_3d.project_ray_origin(screen_pos)
	#var direction = camera_3d.project_ray_normal(screen_pos)
	#var end = origin + direction * 500.0
#
	#var space_state = get_world_3d().direct_space_state
	#var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end))
#
	#var was_targeting = is_targeting
	#is_targeting = false
	#$Decal.visible = false
#
	#if result.has("collider"):
		#var collider = result.collider
		#var is_spotter = collider.is_in_group("Spotter")
#
		#is_targeting = true
		#
		#var decal = $Decal
		#decal.visible = true
		#decal.global_position = result.position + result.normal * 0.01
		##decal.look_at(decal.global_position + result.normal, Vector3.UP)
		#decal.rotation_degrees.x += 90.0
		#decal.emission_energy = 100.0 if is_spotter else 25.0
#
#
	#if was_targeting != is_targeting:
		#crosshair.set_targeting_state(is_targeting)

#func mark_target() -> void:
	#var screen_pos = crosshair_pos.global_position
	#var origin = camera_3d.project_ray_origin(screen_pos)
	#var direction = camera_3d.project_ray_normal(screen_pos)
	#var end = origin + direction * 500.0
#
	#var space_state = get_world_3d().direct_space_state
	#var result = space_state.intersect_ray(
		#PhysicsRayQueryParameters3D.create(origin, end)
	#)
#
	## Only allow ONE collider to be marked
	#if result.has("collider"):
		#var collider = result.collider
#
		#if collider.has_method("marking_myself_as_target"):
			#collider.marking_myself_as_target()
			#return

#
#func Xcheck_for_target() -> void:
	#var screen_pos = crosshair_pos.global_position
	#var origin = camera_3d.project_ray_origin(screen_pos)
	#var direction = camera_3d.project_ray_normal(screen_pos)
	#var end = origin + direction * 500.0
#
	#var space_state = get_world_3d().direct_space_state
	#var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end))
#
	#var was_targeting = is_targeting
	#is_targeting = false
	#$Decal.visible = false
#
	#if result.has("collider"):
		#var collider = result.collider
		#var is_spotter = collider.is_in_group("Spotter")
		#var is_cannonball = collider.is_in_group("cannonball")
		#var is_egg = collider.is_in_group("Egg_Cage")
#
		##if is_spotter or is_cannonball or is_egg:
		#is_targeting = true
		#var decal = $Decal
		#decal.visible = true
		#decal.global_position = result.position + result.normal * 0.01
		##decal.look_at(decal.global_position + result.normal, Vector3.UP)
		#decal.rotation_degrees.x += 90.0
		#decal.emission_energy = 100.0 if is_spotter else 25.0

		#if is_spotter and collider.has_method("duck_behind_wall") and not collider.stunned:
		#if is_spotter and not collider.stunned:
			#if collider.has_method('ev_CrosshairOnPopper'):
				#collider.ev_CrosshairOnPopper()


		## Picking up only rigidbodies (e.g., cannonballs)
		#if collider is RigidBody3D: #and is_cannonball:
			#if !toggling_carrying:
				#return
			#if picked_object == null:  # ✅ Only pick up if we're not already holding something
				#pick_object(collider)


	#if was_targeting != is_targeting:
		#crosshair.set_targeting_state(is_targeting)

#func pick_object(collider: RigidBody3D) -> void:
	#picked_object = collider
#
	## Calculate distance from camera ray origin to object
	#var screen_pos = crosshair_pos.global_position
	#var origin = camera_3d.project_ray_origin(screen_pos)
	#var direction = camera_3d.project_ray_normal(screen_pos)
#
	#var obj_pos = picked_object.global_transform.origin
	#var distance_vector = obj_pos - origin
	#current_distance_from_camera = direction.dot(distance_vector)

#func remove_object() -> void:
	#picked_object = null
	
#func _input(event):
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			#distance_from_camera = clamp(distance_from_camera + 1.0, 5.0, 100.0)
			#
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			#distance_from_camera = clamp(distance_from_camera - 1.0, 5.0, 100.0)

	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("speed_up"):
		#toggling_carrying = true
	#else:
		#toggling_carrying = false
		#if picked_object:
			#var screen_pos = crosshair_pos.global_position
			#var origin = camera_3d.project_ray_origin(screen_pos)
			#var direction = camera_3d.project_ray_normal(screen_pos).normalized()
			##picked_object.set_linear_velocity(direction * throw_force)
			#picked_object = null

	
			#
#func handle_right_click_picking() -> void:
	#
	#if picked_object != null:
		#var screen_pos = crosshair_pos.global_position
		#var origin = camera_3d.project_ray_origin(screen_pos)
		#var direction = camera_3d.project_ray_normal(screen_pos)
#
		#var _distance_from_camera := current_distance_from_camera
		#var target_pos = origin + direction * distance_from_camera
		#var current_pos = picked_object.global_transform.origin
#
		#var move_vector = (target_pos - current_pos) * pull_power
		#picked_object.set_linear_velocity(move_vector)
