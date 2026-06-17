extends Node3D

const BONUS_CANNONBALL = preload("res://lib/Bonus_Round/Bonus_round_cannonball.tscn")

@export var launch_speed: float = 5.0
@export var arc_strength: float = 0.22
@export var is_active := false

@onready var mesh: Node3D = $Mesh
@onready var smoke_particles: GPUParticles3D = $Smoke_quick
@onready var marker_3d: Marker3D = $Mesh/Marker3D

# New Variables
var prepared_cannonballs: Array = []
var prepared_shot_types: Array = []
var game_won := false

var counter := 0
@export var total_amount_of_bonus_shots := 20

var firing_in_progress: bool = false

func _ready() -> void:
	hide()


func prepare_shot_queue() -> void:
	var bonus_cannonball = BONUS_CANNONBALL.instantiate()

	# Set cannonball parameters
	bonus_cannonball.slow_travel_time = launch_speed * 2
	bonus_cannonball.fast_travel_time = launch_speed * 2 #0.25
	bonus_cannonball.travel_time = launch_speed
	bonus_cannonball.arc_strength = 0.15 # arc_strength

	# Position cannonball ready at marker
	get_parent().add_child(bonus_cannonball)
	bonus_cannonball.scale = Vector3.ONE / 10
	bonus_cannonball.global_position = marker_3d.global_position
	
	bonus_cannonball.particles.amount = 50
	bonus_cannonball.show()
	bonus_cannonball.target_launcher_fire("bonus")

	firing_sequence()
	visual_fire()
	launching_tween()
	counter += 1

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
	var new_particles = smoke_particles.duplicate()
	new_particles.add_to_group('smoke_particles')
	new_particles.duplicate_particles = true
	get_tree().get_current_scene().add_child(new_particles)
	new_particles.show()
	new_particles.global_position = marker_3d.global_position + Vector3(0, 0.5, 0)
	new_particles.emitting = true

# (Optional) Smoke destruction animation for win sequence
func smoke_up() -> void:
	if $launch_sound:
		var launch_sound_dup = preload("res://sfx/Arrow_release.wav")
		var pitch_fluc = randf_range(0.05, 0.15)
		var vol_fluc = randf_range(10.0, 15.0)
		CommonCode.play_sound_instance_pitch_adjusted(launch_sound_dup, $launch_sound.volume_db - vol_fluc, pitch_fluc)
		smoke_particles_destruction()

func smoke_particles_destruction() -> void:
	var new_particles = $Smoke_quick4.duplicate()
	new_particles.add_to_group('smoke_particles')
	new_particles.duplicate_particles = true
	get_tree().get_current_scene().add_child(new_particles)
	new_particles.global_position = marker_3d.global_position + Vector3(0, 0.5, 0)
	new_particles.emitting = true


func _on_timer_timeout() -> void:
	if game_won:
		return
		
	if counter >= total_amount_of_bonus_shots:
		$Timer.stop()
		hide()
		return
	show()
	prepare_shot_queue()

func _on_game_won_lost() -> void:
	game_won = true
	$Timer.stop()
