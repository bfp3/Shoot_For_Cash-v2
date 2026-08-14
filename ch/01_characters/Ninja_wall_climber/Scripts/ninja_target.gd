extends CharacterBody3D

#const BOMBS_LANDING_IN_THE_DISTANCE = preload('uid://disfcwr18xhfw')
#const SMOKE_LINGERING = preload("res://res/Particles/Smoke_particles/Smoke_lingering.tscn")
#const ARROW_AREA_3D = preload("res://ch/weapons/bullet_area3D.tscn")
#
#@export var arrow_speed := 20.0  # Adjust speed as needed := 0.1
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
#signal ninja_target_destroyed
#
#
#func _ready() -> void:
	#pass
	#
	#
#func free_ammo_started() -> void:
	#var cms : CMS = get_tree().get_first_node_in_group('CMS')
	#if cms:
		#cms.start_bonus_round()
		#
	#was_hit_tween()
	#
#
#
#func spawn_my_arrow() -> void:
	#if target_hit:
		#return
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
#func where(time: float) -> Vector3:
	#return Vector3.ZERO
#
#func smoke_particles() -> void:
	#var new_particles = $Smoke_particles #.duplicate()
	#new_particles.emitting = true
	#new_particles.duplicate_particles = true
	#new_particles.show()
	#new_particles.reparent(get_tree().get_current_scene(), true)
	##get_tree().get_current_scene().add_child(new_particles)
	#new_particles.global_position = global_position
	#new_particles.add_to_group("smoke_particles")
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
	#ninja_target_destroyed.emit()
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
#
#
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
