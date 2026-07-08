extends StaticBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
const BALLOON_MAT_GREY = preload('uid://dgrbglmgp2fad')

var pitch_adjustment := 0.02

@export var hazard_mode := true

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}
@export var pulse_magnitude := 0.8
var behind_player := true
var current_state : State

@export var balloon_carrier := false
@export var balloon_carrier_penalty := 0

var	force_mult : Array = [3,4]
var force_mult_index := 0

@onready var money_label_3d: Label3D = $Money_Label3D

#@onready var pineapple_mesh:= $Mesh/small_rock
@onready var main_col: CollisionShape3D = $main_col
@onready var current_mesh : MeshInstance3D=  $Mesh/small_rock2

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
@export var player_balloon := false


func _ready() -> void:
	
	start_pos = global_position
	
	await get_tree().create_timer(0.2).timeout

	enter_state(State.ACTIVE)
	
	if balloon_carrier:
		remove_from_group('Target')
	#EventBus.instance.egg_pulsed.connect(enter_state.bind(State.ACTIVE))


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
	if !balloon_carrier:
		add_to_group('Target')
	rock_activated = true
	#global_position = start_pos
	health = 1
	$Mesh.show()
	
func update_hit() -> void:
	
	
	if hazard_mode:
		$pop_balloon.pitch_scale = randf_range(0.95,1.1)
		$pop_balloon.play()
		
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
	var base_scale  := Vector3.ONE * 1.0 #0.35

	# Random subtype: 1x / 2x / 3x
	
	if base_cash >= 0:
		base_cash = -3
	
	if !balloon_carrier:
		$Mesh.scale = Vector3.ONE
	health = base_health
	cash_value = base_cash # * size_multiplier
	max_health = health
	
	#main_col.scale = Vector3.ONE * 0.125
	current_mesh = $Mesh/small_rock2
	current_mesh.scale = base_scale


func reset_stats() -> void:
	if !balloon_carrier:
		$Mesh.scale = Vector3.ONE

	$Mesh.show()
	
	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = $Mesh/small_rock2
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = 0
	
	falling = false
	rock_destroyed = false
	is_deactivated = false
	#global_position = start_pos


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func destroyed_by_shratnel() -> void:

	if !visible:
		return
	
	hazard_mode = false
	$pop_balloon_soft.play()
	start_destroyed_process()
	return
	print('destroyed by shratnel')
	$Mesh.hide()
	gl_PlayerState.log_hit(rock_type_name, current_rock_type, 3)
	smoke_particles()
	await get_tree().create_timer(2.0).timeout
	queue_free()
	#hide()
	#global_position = start_pos
	
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	if !visible && $Mesh.visible == false:
		return
	
	health -= damage
	
	#if health > 0:
		#play_hit_sfx()
		#smoke_particles_duplicates()
		#current_mesh.get_node('damage_mesh').show()
		#await get_tree().create_timer(0.08).timeout
		#current_mesh.get_node('damage_mesh').hide()
		#return
		#return
	#else:
	
	if player_balloon:
		rock_pop_balloon()
		play_destroy_sfx()
		$AoE.play_particles = true
		return
	
	if !hazard_mode:
		$pop_balloon_soft.play()
		#global_position = start_pos
		$AoE.play_particles = true
		get_parent().get_parent().carrier_balloon_popped()
		hide()
		disable_collision()
		
	else:
		
		if !balloon_carrier && !player_balloon:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, cash_value)
		start_destroyed_process()
	

func start_destroyed_process() -> void:

	if !rock_activated:
		return
		
	rock_activated = false
	enter_state(State.HIT)
	
	
	#if !destroyed_by_marked:
	disable_collision()

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	if balloon_carrier:
		cash_value = balloon_carrier_penalty
		
	
	if !balloon_carrier && hazard_mode:
		money_label_3d.money_is_money(global_position, cash_value)
	
	set_collision_layer_value(1, false)
	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.0, 0.33)
	await tween.finished
	#scale = clamp(scale, Vector3.ONE, Vector3.ONE * 2.5)
	shake_camera()
	
	var current_pos := global_position
	
	global_position.y -= 20.0
	
	show()
	#current_mesh.scale = Vector3.ONE * 0.5
	if !balloon_carrier:
		$Mesh.scale = Vector3.ONE
	
	var tween_balloon = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_balloon.tween_property(self, "global_position", current_pos, 2.5)
	#await tween_balloon.finished
	rock_activated = true
	enable_collision()
	is_deactivated = false
	
	if !balloon_carrier:
		add_to_group('Target')

	
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

func move_balloon_in_front_of_player() -> void:
	if !player_balloon:
		behind_player = false
		show()
		await get_tree().create_timer(3.0).timeout
		$move_balloon.play()
	
	else:
		behind_player = false
		show()
		await get_tree().create_timer(1.0).timeout
		$move_balloon.play()	

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


func rock_pop_balloon() -> void:
	if !rock_activated:
		return
	
	if player_balloon:
		get_parent().current_balloon = null
		play_destroy_sfx()
		var crt = get_tree().get_first_node_in_group('TV_CRT_Filter')
		if crt:
			crt.taking_damage_tween()
	
	rock_activated = false
	enter_state(State.HIT)
	
	disable_collision()

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	#if balloon_carrier:
		#cash_value = balloon_carrier_penalty
	
	#if !balloon_carrier:
		#money_label_3d.money_is_money(global_position, cash_value)
	is_deactivated = true
	
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.5, 0.33)
	await tween.finished

	shake_camera()
	
		
	await get_tree().create_timer(0.1).timeout
	
	queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name.contains('Rock'):
		if player_balloon:
			rock_pop_balloon()
		else:
			start_destroyed_process()
