extends RigidBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')

@onready var current_mesh: MeshInstance3D = $MeshInstance3D
@onready var main_col: CollisionShape3D = $main_col
var activated := true
@export var additional_time := 5.0

func _ready() -> void:
	self.queue_free()
	#return
	#EventBus.instance.egg_pulsed.connect(start_round)
	#time_ran_out()


func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:	
	play_hit_sfx()
	apply_hit_reaction()
	start_destroyed_process()
	
	apply_bonus_time()
	
func apply_bonus_time() -> void:
	var round_timer = get_tree().get_first_node_in_group("round_timer")
	if round_timer:
		round_timer._add_additional_time(additional_time)
	
func start_destroyed_process() -> void:
	print('is this called')
	if !activated:
		return
		
	activated = false
		
	if is_in_group('Target'):
		remove_from_group('Target')
		
	#money_label_3d.money_is_money(global_position, cash_value)

	was_hit_tween()
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	await tween.finished
	
	shake_camera()
	
func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_bonus_time"):
		player_cam.shake_camera_bonus_time()

func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	#tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	tween.tween_property(self, "rotation_degrees:x", 105.0, 0.3)
	await tween.finished

func apply_hit_reaction() -> void:
	if current_mesh.scale <= Vector3.ONE * 0.3:
		get_node('damage_mesh').show()
		await get_tree().create_timer(0.08).timeout
		get_node('damage_mesh').hide()

		return
		
	if current_mesh:
		var original_scale := current_mesh.scale
		get_node('damage_mesh').show()
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			current_mesh,
			"scale",
			original_scale * 0.85,
			0.08
		)
		
		await tween.finished
		get_node('damage_mesh').hide()
		
		
func play_hit_sfx() -> void:
	$take_damage_sfx.volume_db = randf_range(-25.0, -20.0)
	$take_damage_sfx.pitch_scale = randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05).timeout
	$take_damage_sfx.play(0.01)
	await get_tree().create_timer(0.1).timeout
	$take_damage_sfx.play(0.02)

func play_accurate_sounds() -> void:
	#await get_tree().create_timer(0.05).timeout
	create_shot_instance(ON_TARGET_SFX, -30.0, 0.7)

func smoke_particles() -> void:
	$AoE.global_position = current_mesh.global_position
	$AoE.play_particles = true
	
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

func start_round() -> void:
	#activated = true
	add_to_group('Target')
	#smoke_particles()
	await get_tree().process_frame
	current_mesh.show()

func time_ran_out() -> void:
	activated = false
	smoke_particles()
	add_to_group('Target')
	await get_tree().process_frame
	current_mesh.hide()
