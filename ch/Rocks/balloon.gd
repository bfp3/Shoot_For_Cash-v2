extends StaticBody3D

const ON_TARGET_SFX = preload('res://sfx/opt_3_fade_shortened.wav')


var pitch_adjustment := 0.02

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}
@export var pulse_magnitude := 0.8

var current_state : State


var	force_mult : Array = [3,4]
var force_mult_index := 0

@onready var money_label_3d: Label3D = $Money_Label3D
@onready var gold_label_3d: Label3D = $Gold_label3D
@onready var pineapple_mesh:= $Mesh/small_rock
@onready var main_col: CollisionShape3D = $main_col
@onready var current_mesh : MeshInstance3D= pineapple_mesh

var max_health : int = 0
var cash_value := 0


@export var hit_torque_strength := 5.0
@export var hit_upward_force := 2.0


var rock_activated := false
var rock_destroyed := true
var is_deactivated := false
var health := 0
var start_pos : Vector3

var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false


func _ready() -> void:
	
	start_pos = global_position
	
	await get_tree().create_timer(0.2).timeout
	
	enter_state(State.INACTIVE)
	EventBus.instance.egg_pulsed.connect(enter_state.bind(State.ACTIVE))


func enter_state(new_state : State) -> void:

	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()
			
		State.ACTIVE:
			update_active()

		State.MISSED:
			update_missed()
		
		State.HIT:
			update_hit()
			
		State.DISABLED:
			update_disabled()

		
			
func update_inactive() -> void:
	force_mult.shuffle()
	disable_collision()
	reset_stats()
	
	# EventBus.instance.rock_created.emit()


func quick_pan() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_loops()
	tween.tween_property(self, 'global_position:x', -2, 1.0).as_relative()
	tween.tween_property(self, 'global_position:x', 2, 1.0).as_relative()
	tween.tween_interval(2.0)

func update_prepare_rock() -> void:
	reset_stats()

	await get_tree().process_frame
	force_mult.shuffle()
	await get_tree().process_frame
	
func update_active() -> void:
	enable_collision()
	reset_stats()
	#quick_pan()
	reset_rock_back_on()
	add_to_group('Target')
	rock_activated = true
	global_position = start_pos
	health = 1
	
	rock_activated = true
	$Mesh.show()
	
func update_hit() -> void:
	$pop_balloon.pitch_scale = randf_range(0.95,1.1)
	$pop_balloon.play()
	gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value)
	
	
func update_missed() -> void:
	reset_stats()

func round_end_check_rock_status() -> void:
	
	match current_state:
		State.HIT:
			pass
			
		State.MISSED:
			pass
			
		
		State.INACTIVE:
			pass
			
		State.ACTIVE:
			enter_state(State.DISABLED)
			
		_:
			print("We are in some other state ", current_state)

func update_disabled() -> void:
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	$main_col.disabled = true

func enable_collision() -> void:
	$main_col.disabled = false
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, true)



func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "Hazard Large"
	rock_type_name 		= "hazard_type_1"

	var base_health := int(gl_DataSet.get_value("hazard_type_1", 1))
	#var base_cash   := int(gl_DataSet.get_value("hazard_type_1", 0))
	var base_cash 	:= int(gl_PlayerState.dataset.cash / 8)
	var base_scale  := Vector3.ONE * 0.35

	# Random subtype: 1x / 2x / 3x
	
	if base_cash >= 0:
		base_cash = -3
	
	$Mesh.scale = Vector3.ONE
	health = base_health
	cash_value = base_cash # * size_multiplier
	max_health = health
	pineapple_mesh.visible = true
	#main_col.scale = Vector3.ONE * 0.125
	current_mesh = pineapple_mesh
	current_mesh.scale = base_scale


func reset_stats() -> void:
	$Mesh.scale = Vector3.ONE
	$Mesh.show()
	
	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = pineapple_mesh
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = 0

	
	falling = false
	rock_destroyed = false
	is_deactivated = false
	global_position = start_pos


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func apply_hit_reaction(screen_offset : Vector2) -> void:

	smoke_particles_duplicates()
	
	current_mesh.get_node('damage_mesh').show()
	await get_tree().create_timer(0.08).timeout
	current_mesh.get_node('damage_mesh').hide()
	
	

		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	health -= damage
	
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)
		return
	
	start_destroyed_process()
	

func start_destroyed_process() -> void:

	if !rock_activated:
		return
		
	rock_activated = false
	enter_state(State.HIT)
	
	#if !destroyed_by_marked:
	disable_collision()
	remove_from_group('Target')

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
		
	
	money_label_3d.money_is_money(global_position, cash_value)
	
	set_collision_layer_value(1, false)
	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	await tween.finished

	shake_camera()

	

func play_hit_sfx() -> void:
	$take_damage_sfx.volume_db = randf_range(-25.0, -20.0)
	$take_damage_sfx.pitch_scale = randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05).timeout
	$take_damage_sfx.play(0.01)
	await get_tree().create_timer(0.1).timeout
	$take_damage_sfx.play(0.02)


func play_destroy_sfx() -> void:
	$take_damage_sfx.play(0.02)
	#await get_tree().create_timer(0.1).timeout
	#$hitSound.play()
	#await get_tree().create_timer(0.1).timeout
	#$explosion_sfx.play()
	
	
func smoke_particles() -> void:
	
	$AoE.global_position = global_position
	$AoE.play_particles = true

func smoke_particles_duplicates() -> void:
	var _new_particles : GPUParticles3D = $Smoke_quick.duplicate()

	if !_new_particles:
		return
		
	_new_particles.add_to_group("smoke_particles")
	_new_particles.emitting = true
	_new_particles.duplicate_particles = true
	_new_particles.show()
	add_child(_new_particles)
	#get_tree().get_current_scene().add_child(_new_particles)
	_new_particles.global_position = global_position
	
	var _new_sparks : GPUParticles3D = $Sparks01.duplicate()
	if !_new_sparks:
		return
	_new_sparks.show()
	_new_sparks.finished.connect(_new_sparks.queue_free)
	get_tree().get_current_scene().add_child(_new_sparks)
	_new_sparks.global_position = global_position
	_new_sparks.emitting = true
	

func play_accurate_sounds() -> void:
	#await get_tree().create_timer(0.05).timeout
	create_shot_instance(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05
	

func create_shot_instance(sound_file : AudioStreamWAV, volume_db : float, pitch_scale : float) -> void:
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
