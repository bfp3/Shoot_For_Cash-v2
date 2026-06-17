extends Node3D

@export var launch_speed: float = 5.0
@export var arc_strength: float = 0.22
@export var is_active := false

@onready var mesh: Node3D = $Mesh
@onready var smoke_particles: GPUParticles3D = $Smoke_quick2
@onready var marker_3d: Marker3D = %Marker3D

var prepared_cannonballs: Array = []
var prepared_shot_types: Array = []

var firing_in_progress: bool = false

@onready var STANDARD_CANNONBALL = get_parent().STANDARD_CANNONBALL


func prepare_shot_queue(shots: Array, cannonball_container: Node) -> void:
	# Prepare cannonballs but do not fire yet
	for shot_data in shots:
		#var STANDARD_CANNONBALL_CORKSCREW = preload('res://500_sequences/Cannonball_System/Cannonballs/Standard_cannonball_corkscrew.tscn')
		#var cannonball = STANDARD_CANNONBALL_CORKSCREW.instantiate()
		var cannonball = STANDARD_CANNONBALL.instantiate()
		
		if GameManager.in_retry_world:
			cannonball.slow_travel_time = launch_speed * 2
			cannonball.fast_travel_time = launch_speed * 0.25
			#cannonball.travel_time = launch_speed
			cannonball.arc_strength = arc_strength / 2.5
			#cannonball.base_flight_time = cannonball.base_flight_time / 2
			
		else:
			# Set cannonball parameters
			cannonball.slow_travel_time = launch_speed * 2
			cannonball.fast_travel_time = launch_speed * 0.25
			#cannonball.travel_time = launch_speed
			cannonball.arc_strength = clamp(cannonball.arc_strength, 0.05, arc_strength)

		# Position cannonball ready at marker
		cannonball_container.add_child(cannonball)
		cannonball.scale = Vector3.ONE / 10
		cannonball.global_position = marker_3d.global_position
		
		cannonball.particles.amount = 50
		cannonball.bomb_mesh.show()

		# Store for later firing
		prepared_cannonballs.append(cannonball)
		prepared_shot_types.append(shot_data["type"])


func fire_prepared_shots() -> void:
	if firing_in_progress or prepared_cannonballs.is_empty():
		return

	firing_in_progress = true
	fire_next_shot()

func fire_next_shot() -> void:
	if prepared_cannonballs.is_empty():
		firing_in_progress = false
		return
	
	var cannonball = prepared_cannonballs.pop_front()
	var shot_type = prepared_shot_types.pop_front()

	# Visual launcher animation
	visual_fire()

	# Launch cannonball
	await launching_tween()
	
	if cannonball != null:
		cannonball.target_launcher_fire(shot_type)

	# Play firing sound
	firing_sequence()

	# Short delay between firing shots
	await get_tree().create_timer(0.5).timeout

	fire_next_shot()

func visual_fire() -> void:
	mesh_launcher_tween()

func launching_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_smoke_particles)
	tween.tween_callback(_smoke_particles_2)
	await tween.finished

func mesh_launcher_tween() -> void:
	var launcher_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	launcher_tween.tween_property(mesh, "global_position:y", -0.05, 0.75).as_relative().set_ease(Tween.EASE_IN)
	launcher_tween.tween_interval(0.15)
	launcher_tween.tween_property(mesh, "global_position:y", 0.05, 1.5).as_relative().set_ease(Tween.EASE_OUT)
	await launcher_tween.finished

func firing_sequence() -> void:
	if $launch_sound:
		CommonCode.play_sound_duplicate_instance($launch_sound, 0.15, $launch_sound.volume_db)

func _smoke_particles() -> void:
	var new_particles = $Smoke_quick2.duplicate()
	new_particles.add_to_group('smoke_particles')
	new_particles.duplicate_particles = true
	get_tree().get_current_scene().add_child(new_particles)
	
	new_particles.show()
	new_particles.global_position = marker_3d.global_position + Vector3(0, 0.5, 0)
	new_particles.emitting = true
	

func _smoke_particles_2() -> void:
	var new_particles_2 = $Smoke_quick3.duplicate()
	new_particles_2.duplicate_particles = true
	new_particles_2.add_to_group('smoke_particles')
	get_tree().get_current_scene().add_child(new_particles_2)
	new_particles_2.show()
	
	new_particles_2.global_position = marker_3d.global_position + Vector3(0, 0.5, 0)
	new_particles_2.emitting = true

func smoke_up() -> void:
	if $launch_sound:
		var launch_sound_dup = preload("res://sfx/Arrow_release.wav")
		var pitch_fluc = randf_range(0.05, 0.15)
		var vol_fluc = randf_range(10.0, 15.0)
		CommonCode.play_sound_instance_pitch_adjusted(launch_sound_dup, $launch_sound.volume_db - vol_fluc, pitch_fluc)
		smoke_particles_destruction()

func smoke_particles_destruction() -> void:
	var new_particles = $Smoke_quick4.duplicate()
	new_particles.duplicate_particles = true
	new_particles.add_to_group('smoke_particles')
	get_tree().get_current_scene().add_child(new_particles)
	new_particles.global_position = marker_3d.global_position + Vector3(0, 0.5, 0)
	new_particles.emitting = true
