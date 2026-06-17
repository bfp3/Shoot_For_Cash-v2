extends StaticBody3D

#const ARROW_AREA_3D = preload("res://ch/weapons/bullet_area3D.tscn")
#
#@export var arrow_speed := 20.0
#
#var spawned_arrows: Array[Area3D] = []
#
#
#
#func add_unique_marker(pos: Vector3) -> void:
	#$Unique_marker.global_position = pos
#
#func spawn_my_arrow() -> void:
	#var new_arrow = ARROW_AREA_3D.instantiate()
	#var player_gun = get_tree().get_first_node_in_group("player_gun")
	#
	#new_arrow.global_position = player_gun.get_barrel_position()
	#get_tree().get_current_scene().add_child(new_arrow)
	#
	#spawned_arrows.append(new_arrow)
	#
	#
#func _physics_process(delta: float) -> void:
	#var target = $Unique_marker.global_position
#
	#for arrow in spawned_arrows.duplicate():
		#if !is_instance_valid(arrow):
			#if spawned_arrows.has(arrow):
				#spawned_arrows.erase(arrow)
			#continue
#
		#var direction = (target - arrow.global_position).normalized()
		#arrow.global_position += direction * arrow_speed * delta
		#arrow.look_at(target, Vector3.UP, true)
#
		#if arrow.global_position.distance_to(target) < 0.4:
			##set_physics_process(false)
			#
			#start_ricochet(arrow)
			#break_off()
			#arrow = null
			#if spawned_arrows.has(arrow):
				#spawned_arrows.erase(arrow)
		#
#func play_sounds() -> void:
	#var pitch = randf_range(0.9, 1.0)
	#$Wood_step.pitch_scale = pitch
	#$Wood_step.play()
#
#
#
#func start_ricochet(arrow: Node3D) -> void:
	##play_sounds()
	## Calculate direction from arrow to target (i.e., original direction of travel)
	#var target = $Unique_marker.global_position
	#var original_dir = (target - arrow.global_position).normalized()
#
	## Compute bounce direction: reflect backwards and slightly upward
	#var bounce_dir = (-original_dir + Vector3.UP * 0.6).normalized()
	#var bounce_distance = 15.0  # Distance to move during ricochet
	#var bounce_target = arrow.global_position + bounce_dir * bounce_distance
#
	## Create a Tween node
	#var tween = create_tween()
#
	#tween.tween_property(arrow, "global_position", bounce_target, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#await tween.finished
	#if is_instance_valid(arrow):
		#arrow.cleanUp()
		#
		#
#func break_off() -> void:
	## Random travel distances
	#var travel_z = randf_range(5.0, 100.0)
	#var travel_x = randf_range(-2.0, 2.0)
	#var travel_y = randf_range(1.0, 3.0)
#
	## Calculate target position
	#var break_direction = Vector3(travel_x, travel_y, travel_z)
	#var target_position = global_position + break_direction
#
	## Rotation intensity scales with travel_z
	#var rotation_intensity = travel_z * 60.0  # degrees, scale as needed
	#var target_rotation = rotation_degrees + Vector3(rotation_intensity, 0, 0)
#
	## Create a tween for motion and rotation
	#var tween = create_tween() #.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.tween_property(self, "global_position", target_position, 0.8)
	#tween.parallel().tween_property(self, "rotation_degrees", target_rotation, 0.8).as_relative()
	#tween.tween_property(self, "global_position:y", -target_position.y * 2, 0.8)
	#tween.parallel().tween_property(self, "rotation_degrees", target_rotation, 0.8).as_relative()
	#await tween.finished
	#self.queue_free() 
