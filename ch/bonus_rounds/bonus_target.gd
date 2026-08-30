extends StaticBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
var pitch_adjustment := 0.02

@onready var balloon_blowing_up: AudioStreamPlayer = $balloon_blowing_up
var player_has_marked_balloon := false

enum PanAxis {
	X_AXIS,
	Y_AXIS
}


var protect_mode := false


@export var pan_axis : PanAxis = PanAxis.Y_AXIS
@export var pan_distance := 0.5
@export var pan_duration := 3.5
@export var pan_start_delay := 3.0     ## Delay after move_balloon_in_front_of_player() before panning starts.

var pan_tween : Tween


var hazard_active := true
var default_hazard_active := true

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}
var behind_player := true
var current_state : State



var	force_mult : Array = [3,4]
var force_mult_index := 0

@onready var money_label_3d: Label3D = $Money_Label3D

@onready var main_col: CollisionShape3D = $main_col
@onready var current_mesh : MeshInstance3D=  $Mesh/centerPiece

var max_health : int = 0
var cash_value := 0




var rock_activated := false
var rock_destroyed := true
var is_deactivated := false
var health := 0
var start_pos : Vector3
var orig_start_pos : Vector3
var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false


func _ready() -> void:
	start_pos = global_position
	orig_start_pos = start_pos

	default_hazard_active = hazard_active

	await get_tree().create_timer(0.2).timeout

	enter_state(State.ACTIVE)


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
	#global_position = start_pos
	health = 1
	$Mesh.show()
	
func update_hit() -> void:
	if !hazard_active:
		return
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
			print("We are in some other state balloon ", current_state)

func update_disabled() -> void:
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	$main_col.disabled = true
	if %balloon_area:
		%balloon_area.set_deferred("monitoring", false)

func enable_collision() -> void:
	$main_col.disabled = false
	
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, true)

	if %balloon_area:
		%balloon_area.set_deferred("monitoring", true)

func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "hazard"
	#rock_type_name 	= "hazard_type_1"
	rock_type_name 		= ""

	var base_health 	:= int(gl_DataSet.get_value("hazard_type_1", 1))
	var base_cash 		:= int(gl_DataSet.get_value("balloon_orange", 1))

	$Mesh.scale = Vector3.ONE
	health = base_health
	cash_value = base_cash # * size_multiplier
	max_health = health
	
	#main_col.scale = Vector3.ONE * 0.125
	current_mesh = $Mesh/centerPiece



func reset_stats() -> void:
	$Mesh.scale = Vector3.ONE

	$Mesh.show()
	
	pitch_adjustment = 0.02
	
	rock_activated = false
	current_mesh = $Mesh/centerPiece
	current_rock_type = "hazard"
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
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_bonus_target"):
		player_cam.shake_camera_bonus_target()

func destroyed_by_shratnel() -> void:
	if !visible:
		return
	
	hazard_active = false
	$pop_balloon_soft.play()
	start_destroyed_process()
	
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	#if balloon_type == BalloonType.BLUE:
		#return
	
	if !visible && $Mesh.visible == false:
		return
	
	health -= damage
		
	rock_pop_balloon()
	play_destroy_sfx()
	smoke_particles()
	$pop_balloon_soft.play()
	disable_collision()
			



	

func start_destroyed_process() -> void:

	if !rock_activated:
		return
	
	if player_has_marked_balloon:
		return

	_notify_bonus_manager_destroyed()
	
	rock_activated = false
	enter_state(State.HIT)
	stop_gentle_pan()

	disable_collision()

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
		
	set_collision_layer_value(1, false)
	is_deactivated = true

	
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.0, 0.33)
	await tween.finished


	
func play_hit_sfx() -> void:
	$take_damage_sfx.volume_db = randf_range(-25.0, -20.0)
	$take_damage_sfx.pitch_scale = randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05).timeout
	$take_damage_sfx.play(0.01)
	await get_tree().create_timer(0.1).timeout
	$take_damage_sfx.play(0.02)


func play_destroy_sfx() -> void:
	$take_damage_sfx.play(0.02)

func move_balloon_in_front_of_player() -> void:
	start_gentle_pan()
	$Mesh.scale = Vector3.ONE
	rock_activated = true
	rock_destroyed = false
	add_to_group('Target')
	%Marked.hide()
	$AnimationPlayer.play('idle')
	player_has_marked_balloon = false

	behind_player = false
	show()
	$move_balloon.play()
	$balloon_blowing_up.play()
		
		
func start_gentle_pan() -> void:

	stop_gentle_pan()

	await get_tree().create_timer(pan_start_delay).timeout


	var axis_prop := "global_position:x" if pan_axis == PanAxis.X_AXIS else "global_position:y"

	pan_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_loops()
	pan_tween.tween_property(self, axis_prop, -pan_distance, pan_duration).as_relative()
	pan_tween.tween_property(self, axis_prop, pan_distance, pan_duration).as_relative()


func stop_gentle_pan() -> void:
	if pan_tween and pan_tween.is_valid():
		pan_tween.kill()

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


func start_bullet_to_target() -> void:
	play_accurate_sounds()
		
func play_accurate_sounds() -> void:
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
	
	
	stop_gentle_pan()
	
	var crt = get_tree().get_first_node_in_group('TV_CRT_Filter')
	if crt:
		crt.taking_damage_tween()

	#_notify_bonus_manager_destroyed()
	
	rock_activated = false
	enter_state(State.HIT)
	$pop_balloon.play()
	disable_collision()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	is_deactivated = true
	
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.5, 0.33)
	await tween.finished

	shake_camera()
	
		
	await get_tree().create_timer(0.1).timeout
	print('at some point this was called')
	#queue_free()


func _notify_bonus_manager_destroyed() -> void:
	var container := get_parent()
	if container and container.has_method('notify_bonus_target_destroyed'):
		container.notify_bonus_target_destroyed()



func _on_area_3d_body_entered(body: Node3D) -> void:


	var is_pineapple := body.name.contains('Pineapple')
	var is_rock := body is RockInstance or body.name.contains('Rock')
	if not is_pineapple and not is_rock:
		return

	if is_rock and body is RockInstance and body.current_state != body.State.ACTIVE:
		return


	rock_pop_balloon()

	if is_pineapple or is_rock:
		start_destroyed_process()


func restart() -> void:

	hazard_active = default_hazard_active

	behind_player = true
	player_has_marked_balloon = false
	reset_stats()
	reset_rock_back_on()

	add_to_group("Target")

	enter_state(State.ACTIVE)
	
	await get_tree().create_timer(2.0).timeout
	scale = Vector3.ONE

	show()
	$Mesh.show()
	$Mesh.scale = Vector3.ONE

		



func _push_rock_after_delay(target: RockInstance, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	if !is_instance_valid(target):
		return

	var force_dir := target.global_position - global_position
	force_dir.z = 0.0
	force_dir = force_dir.normalized()

	target.apply_central_impulse(force_dir * 20)
	target.apply_torque_impulse(force_dir * 500.0)
	


func end_of_the_round_pop_balloon(_added_cash : int) -> void:

	rock_activated = false
	stop_gentle_pan()
	disable_collision()

	if is_in_group('Target'):
		remove_from_group('Target')

	set_collision_layer_value(1, false)
	is_deactivated = true

	# Reward instead of penalize: always +$1 regardless of balloon_type/penalty_amount.
	cash_value = _added_cash
	cash_value = 0
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:z", 4.0, 3.0).as_relative()
	tween.parallel().tween_property(self, "global_position:y", 15.0, 3.5) #.as_relative()
	tween.parallel().tween_property(self, "global_position:x", -6.0, 3.5).as_relative()
	await tween.finished
	
	#get_parent().add_balloon_back_into_list(self)
