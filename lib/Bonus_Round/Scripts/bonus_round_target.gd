extends CharacterBody3D
#
#const BOMBS_LANDING_IN_THE_DISTANCE = preload("res://400_sounds/00_sfx/bombs_landing_in_the_distance.tscn")
#const RED_TAKEN_OUT_SFX = preload("res://400_sounds/SFX_pineapple_intro/pineapple_sound_3.wav")
#const SMOKE_LINGERING = preload("res://800_3D_materials/Particles/Smoke_particles/Smoke_lingering.tscn")
#const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")
#
#@export var travel_time: float = 2.0  # How long the arc should last
#@export var arc_strength: float = 0.5 # Controls height of the arc
#@export var arrow_speed := 10.0  # Adjust speed as needed := 0.1
#
#
#var waypoints: Array[Vector3] = [] # List of positions
#var durations: Array[float] = []   # Duration for each movement segment
#var current_index: int = 0         # The index of the current segment
#var elapsed_time: float = 0.0      # Time spent in current segment
#var tween_duration: float = 0.0    # Total duration of current segment
#
#var target_hit := false
#var move_points = []
#var start_time = 0.0
#var travel_times = []
#var travel_directions = []
#var current_speed = 0.0
#
#var target_position: Vector3
#var start_position: Vector3
#var tween_moving_to_marker: Tween = null
#var points: Array = []
#var num_points: int = 50
#
#var moving := true
#
#var slow_travel_time : float = 2.0
#var fast_travel_time : float = 1.0
#
#var spawned_my_own_arrow := false
#var new_arrow : Node3D = null
#
#var was_hit := false
#
#signal target_destroyed
#
#
#func _ready() -> void:
	#return
	#$Timer.wait_time = randi_range(10,30)
	#$Timer.start()
	#hide()
	#tumbling_tween()
	#
	#
#func _input(event: InputEvent) -> void:
	#if Input.is_key_label_pressed(KEY_5):
		#moving_to_marker()
	#
#func moving_to_marker() -> void:
#
	#var dur : float = 10.0
	#
	#var target_pos = find_target_position()
	#global_position = target_pos + Vector3(0, 10, 0)
	#show()
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "global_position", target_pos + Vector3(0, 0.5, 0) , dur)
	#await tween.finished
	#
	#var CMS = get_tree().get_first_node_in_group('CMS')
	#if CMS:
		#CMS.start_bonus_round()
		#
	#was_hit_tween()
	#
##func scale_tween() -> void:
	##scale = Vector3.ONE / 10
	##var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	##tween.tween_property(self, "scale", Vector3.ONE / 2, 0.15)
	##await tween.finished
#
#func _on_timer_timeout() -> void:
	#moving_to_marker()
	#
#func tumbling_tween() -> void:
#
	#var dur : float = 3.0
	##$Mesh.look_at(target_position, Vector3.UP, true)
	#var tween = create_tween().set_loops()
	#tween.tween_property($Mesh, "rotation_degrees:y", 360.0, dur).as_relative()
	#await tween.finished
#
#func spawn_my_arrow() -> void:
#
	#new_arrow = ARROW_AREA_3D.instantiate()
	#get_tree().get_current_scene().add_child(new_arrow)
	#var player_gun = get_tree().get_first_node_in_group('player_gun')
	#
	#new_arrow.global_position = player_gun.get_barrel_position()
	#spawned_my_own_arrow = true
#
#
#func _physics_process(delta: float) -> void:
	#
	#if spawned_my_own_arrow and new_arrow:
		#var direction = ($Unique_marker.global_position - new_arrow.global_position).normalized()
		#new_arrow.global_position += direction * arrow_speed * delta
		#new_arrow.look_at($Unique_marker.global_position, Vector3.UP, true)
		#
	#if not moving:
		#return  # Stop movement if was_hit_tween() was called
#
#
#
#
	#
#func find_target_position() -> Vector3:
	#var marker_node = get_tree().get_first_node_in_group("Parachute_position_marker")
	#if marker_node == null:
		#push_error("No TargetMarkers node found")
		#return global_position
#
	#return marker_node.get_children().pick_random().global_position
#
#func generate_arc_path(start_pos: Vector3, end_pos: Vector3):
	#waypoints.clear()
	#
	#var distance = start_pos.distance_to(end_pos)
	#var h_max = distance * arc_strength  # Arc height scales with distance
	#
	#for i in range(num_points + 1):
		#var t = float(i) / num_points  # Normalized time (0 to 1)
		#
		#var x = lerp(start_pos.x, end_pos.x, t)
		#var z = lerp(start_pos.z, end_pos.z, t)
		#var y = lerp(start_pos.y, end_pos.y, t) + h_max * (1 - (2 * t - 1) ** 2)
		#
		#waypoints.append(Vector3(x, y, z))
#
#func start_arc_movement():
	#if waypoints.is_empty() or not moving:
		#return
#
	## You can decide how many iterations are fast
	#var fast_iterations = 20
	#var step_time : float
	#var current_travel_time : float
	#
	#tween_moving_to_marker = create_tween()
	#tween_moving_to_marker.set_trans(Tween.TRANS_LINEAR)
	#tween_moving_to_marker.set_ease(Tween.EASE_IN_OUT)
	#
	#durations.clear()  # Ensure no old values remain
#
	#for i in range(waypoints.size() - 1):
		#step_time = (fast_travel_time if i < fast_iterations else slow_travel_time) / num_points
		#durations.append(step_time)  # Store step duration
#
	#for i in range(waypoints.size()):
		#if i < fast_iterations:
			#current_travel_time = fast_travel_time
		## After fast_iterations, set the travel time to slow_travel_time
		#else:
			#current_travel_time = slow_travel_time
		#
		## Calculate step time based on the current travel time
		#step_time = current_travel_time / num_points
		#
		## Move the target to the next point
		#tween_moving_to_marker.tween_property(self, "global_position", waypoints[i], step_time)
#
	#await tween_moving_to_marker.finished
	#global_position = target_position
	#hit_the_ground_tween()
	#
	#
#func where(time: float) -> Vector3:
	#return Vector3.ZERO
#
	#if waypoints.is_empty():
		#push_error("waypoints array is empty!")
		#return Vector3.ZERO
	#
	#if waypoints.size() == 1:
		#push_error("waypoints array is empty_3!")
		#return waypoints[0]  # If only one point, return it
#
	#var future_time = elapsed_time + time
	#var temp_index = current_index
	#var temp_elapsed = elapsed_time
	#
	#
	#while temp_index < waypoints.size() - 1:
		#var segment_duration = durations[temp_index]
		#
#
		#if future_time <= segment_duration:
			## Interpolate within this segment
			#var t = future_time / segment_duration
			#var interpolated_pos = waypoints[temp_index].lerp(waypoints[temp_index + 1], t)
			#return interpolated_pos
		#
		## Move to the next segment
		#future_time -= segment_duration
		#temp_index += 1
		#temp_elapsed = 0.0
	#
	#return waypoints[waypoints.size() - 1]
#
#func smoke_particles() -> void:
	#var new_particles = $Smoke_particles #.duplicate()
	#new_particles.emitting = true
	#new_particles.duplicate_particles = true
	#new_particles.show()
	#new_particles.reparent(get_tree().get_current_scene(), true)
	##get_tree().get_current_scene().add_child(new_particles)
	#new_particles.global_position = global_position
#
#func hit_the_ground_tween() -> void:
	#was_hit_tween()
#
#func was_hit_tween() -> void:
	#
	#if tween_moving_to_marker:
		#tween_moving_to_marker.stop()
#
	#moving = false
#
	#smoke_particles()
	#$hitSound.play_sound()
#
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property($Mesh, "scale", Vector3.ONE * 0.27, 0.1)
	#tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.15)
	#await tween.finished
#
	#destroy_self()
#
#
#
#func play_red_hit_sfx() -> void:
	#await get_tree().create_timer(0.5).timeout
	#CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 0.75)
	#await get_tree().create_timer(0.1).timeout
	#CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 1.75)
	#CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 1.0)
#
#func _on_area_3d_area_entered(area: Area3D) -> void:
	#
	#if area.is_in_group('bullet') && !target_hit:
		#area.queue_free()
		#target_hit = true
#
		#if area.has_method('cleanUp'):
			#area.cleanUp()
		#
		#was_hit_tween()
		#instance_hud_feedback()
		#return
		#
#func add_unique_marker(pos : Vector3) -> void:
	#$Unique_marker.show()
	#$Unique_marker.global_position = pos
#
#func instance_hud_feedback() -> void:
	#var new_feedback = get_tree().get_first_node_in_group("HUD_feedback_corner")
	#if new_feedback:
		#if new_feedback.has_method('bonus_round_feedback'):
			#new_feedback.bonus_round_feedback()
#
#func destroy_self() -> void:
	#target_destroyed.emit()
	#
	#shake_camera_on_impact()
	#var crash_sound = BOMBS_LANDING_IN_THE_DISTANCE.instantiate()
	#get_tree().get_current_scene().add_child(crash_sound)
	#crash_sound.play_sound()
	#self.queue_free()
#
#func shake_camera_on_impact() -> void:
	#var player_cam = get_tree().get_first_node_in_group('player_cam')
	#var distance_from_player = global_position.distance_to(player_cam.global_position)
	#player_cam.shake_camera_based_on_position(distance_from_player)
