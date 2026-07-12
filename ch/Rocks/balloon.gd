extends StaticBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')

const BALLOON_BLUE_MAT = preload('uid://hn35w2qwra5g')
const BALLOON_WHITE_MAT = preload('uid://bwa2khv4jv2fv')
const BALLOON_ORANGE_MAT = preload('uid://bg5auabbq8fo8')
const BALLOON_RED_MAT = preload('uid://c5lrichw3wfce')
const BALLOON_GREY_MAT = preload('uid://dgrbglmgp2fad')

var pitch_adjustment := 0.02

@onready var balloon_blowing_up: AudioStreamPlayer = $balloon_blowing_up
var player_has_marked_balloon := false

enum PanAxis {
	X_AXIS,
	Y_AXIS
}

var chain_penalty := 2
var being_chained := false

@export_group("Red Balloon Pan")
@export var pan_axis : PanAxis = PanAxis.X_AXIS
@export var pan_distance := 0.5
@export var pan_duration := 3.5
@export var pan_start_delay := 3.0     ## Delay after move_balloon_in_front_of_player() before panning starts.

var pan_tween : Tween



enum BalloonType {
	WHITE,
	BLUE,
	ORANGE,
	RED,
	GREY
}

@export var balloon_type : BalloonType = BalloonType.WHITE
@export var balloon_carrier_penalty := 0
@export var penalty_amount := 0
var original_penalty_amount := 0
var default_balloon_type : BalloonType


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
@export var pulse_magnitude := 0.8
var behind_player := true
var current_state : State



var	force_mult : Array = [3,4]
var force_mult_index := 0

@onready var money_label_3d: Label3D = $Money_Label3D

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
var orig_start_pos : Vector3
var current_rock_type : String = ""
var rock_type_name : String = ""
var falling := false


func _ready() -> void:
	start_pos = global_position
	orig_start_pos = start_pos
	default_balloon_type = balloon_type
	default_hazard_active = hazard_active

	await get_tree().create_timer(0.2).timeout

	enter_state(State.ACTIVE)

	if balloon_type == BalloonType.GREY:
		remove_from_group("Target")
		
	configure_balloon_colour()



func configure_balloon_colour() -> void:
	var balloon_mesh : MeshInstance3D = $Mesh/small_rock2
	match balloon_type:
		BalloonType.WHITE:
			balloon_mesh.material_override = BALLOON_WHITE_MAT
			original_penalty_amount = penalty_amount
			#$Decal_Container.show()
			
		BalloonType.RED:
			balloon_mesh.material_override = BALLOON_RED_MAT
			penalty_amount = -3
			original_penalty_amount = penalty_amount
			#var rand_chan := randi_range(0,3)
			#if rand_chan > 2:
				#pan_duration = 1.0
			
		BalloonType.ORANGE:
			balloon_mesh.material_override = BALLOON_ORANGE_MAT
			penalty_amount = -3
			original_penalty_amount = penalty_amount
			
		BalloonType.BLUE:
			balloon_mesh.material_override = BALLOON_BLUE_MAT
			penalty_amount = 0
			original_penalty_amount = penalty_amount
			
		BalloonType.GREY:
			balloon_mesh.material_override = BALLOON_GREY_MAT
			penalty_amount = 0
			original_penalty_amount = penalty_amount
			
		_:
			push_warning("Unhandled BalloonType: %s" % BalloonType)


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
	if balloon_type != BalloonType.GREY:
		add_to_group('Target')
	rock_activated = true
	#global_position = start_pos
	health = 1
	$Mesh.show()
	
func update_hit() -> void:
	
	if balloon_type == BalloonType.ORANGE || balloon_type == BalloonType.RED:
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
		%balloon_area.monitoring = false

func enable_collision() -> void:
	$main_col.disabled = false
	
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, true)

	if %balloon_area:
		%balloon_area.monitoring = true

func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "Hazard Large"
	rock_type_name 		= "hazard_type_1"

	var base_health := int(gl_DataSet.get_value("hazard_type_1", 1))
	#var base_cash   := int(gl_DataSet.get_value("hazard_type_1", 0))
	var base_cash 	:= int(gl_PlayerState.dataset.cash / 8)
	var base_scale  := Vector3.ONE * 1.0 #0.35

	# Random subtype: 1x / 2x / 3x
	
	#if base_cash >= 0:
	base_cash = penalty_amount
	
	if balloon_type != BalloonType.GREY:
		$Mesh.scale = Vector3.ONE
	health = base_health
	cash_value = base_cash # * size_multiplier
	max_health = health
	
	#main_col.scale = Vector3.ONE * 0.125
	current_mesh = $Mesh/small_rock2
	current_mesh.scale = base_scale


func reset_stats() -> void:
	if balloon_type != BalloonType.GREY:
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
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam:
		player_cam.shake_camera_rock_destroyed()

func destroyed_by_shratnel() -> void:
	if !visible:
		return
	
	hazard_active = false
	$pop_balloon_soft.play()
	start_destroyed_process()
	
		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	if !visible && $Mesh.visible == false:
		return
	
	health -= damage
	
	if balloon_type == BalloonType.RED and player_has_marked_balloon:
		apply_marked_ability()
		return
	

	match balloon_type:
		BalloonType.BLUE:
			#get_tree().get_first_node_in_group('Player').game_lost = true
			#await get_tree().process_frame
			temp_slow_down()
			rock_pop_balloon()
			play_destroy_sfx()
			smoke_particles()
			$pop_balloon_soft.play()
			#global_position = start_pos
			#$Mesh.hide()
			disable_collision()
			
		BalloonType.WHITE:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, 0)
			start_destroyed_process()

		BalloonType.RED:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, penalty_amount)
			start_destroyed_process()
			
		BalloonType.ORANGE:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, penalty_amount)
			start_destroyed_process()
			
		BalloonType.GREY:
			play_destroy_sfx()
			smoke_particles()
			$pop_balloon_soft.play()
			#global_position = start_pos
			get_parent().get_parent().carrier_balloon_popped()
			$Mesh.hide()
			disable_collision()


	

func start_destroyed_process() -> void:

	if !rock_activated:
		return
	
	if player_has_marked_balloon:
		return
	
	rock_activated = false
	enter_state(State.HIT)
	stop_gentle_pan()
	blast_radius()
	#if !destroyed_by_marked:
	disable_collision()

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	if balloon_type == BalloonType.GREY:
		cash_value = balloon_carrier_penalty
		
	#if balloon_type == BalloonType.WHITE and hazard_active:
	
	
	
	if balloon_type == BalloonType.RED:
		money_label_3d.money_is_money(global_position, penalty_amount)
		
	#else:
		#money_label_3d.print_text(global_position, 'BLUE DOWN')
		
	set_collision_layer_value(1, false)
	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	was_hit_tween()
	

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.0, 0.33)
	await tween.finished
	#scale = clamp(scale, Vector3.ONE, Vector3.ONE * 2.5)
	

	#shake_camera()
	

	if balloon_type == BalloonType.RED:
		get_parent().add_white_balloon_back_into_list(self)
		return
		var current_pos := global_position
		
		global_position.y -= 20.0
		show()
		#current_mesh.scale = Vector3.ONE * 0.5
		if balloon_type != BalloonType.GREY:
			$Mesh.scale = Vector3.ONE
		
		var tween_balloon = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_balloon.tween_property(self, "global_position", current_pos, 2.5)
		#await tween_balloon.finished
		rock_activated = true
		enable_collision()
		is_deactivated = false
		
		
		add_to_group('Target')
		
	elif balloon_type == BalloonType.WHITE:
		get_parent().add_white_balloon_back_into_list(self)
		#var player_balloon_container = get_tree().get_first_node_in_group('player_balloon_container')
		#if player_balloon_container:
			#player_balloon_container.white_reward()
		
	#elif balloon_type == BalloonType.RED:
		#var player_balloon_container = get_tree().get_first_node_in_group('player_balloon_container')
		#if player_balloon_container:
			#player_balloon_container.red_penalty()
			#player_balloon_container.player_balloon_was_popped()

		
	
	
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
	#$hitSound.play()f
	#await get_tree().create_timer(0.1).timeout
	#$explosion_sfx.play()

func move_balloon_in_front_of_player() -> void:
	start_gentle_pan()
	$Mesh.scale = Vector3.ONE
	rock_activated = true
	rock_destroyed = false
	add_to_group('Target')
	%Marked.hide()
	$AnimationPlayer.play('idle')
	player_has_marked_balloon = false
	chain_penalty = 2
	being_chained = false
	penalty_amount = original_penalty_amount

	if balloon_type != BalloonType.BLUE:
		start_pos = orig_start_pos
		behind_player = false
		show()
		await get_tree().create_timer(1.5).timeout
		$balloon_blowing_up.play()
		await get_tree().create_timer(1.5).timeout
		$move_balloon.play()
	
	else:
		behind_player = false
		show()
		#await get_tree().create_timer(1.0).timeout
		$move_balloon.play()
		$balloon_blowing_up.play()
		
		
func start_gentle_pan() -> void:
	if balloon_type != BalloonType.RED:
		return

	stop_gentle_pan()

	await get_tree().create_timer(pan_start_delay).timeout

	# Bail if the balloon got hit, hidden, or changed type during the wait.
	if balloon_type != BalloonType.RED or !visible:
		return

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
	if balloon_type == BalloonType.RED:
		if gl_PlayerState.dataset.power_balloon_buster > 0:
			player_has_marked_balloon = true
		
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
	if balloon_type == BalloonType.BLUE:# ||balloon_type == BalloonType.RED:
		get_parent().player_balloon_was_popped()

		var crt = get_tree().get_first_node_in_group('TV_CRT_Filter')
		if crt:
			crt.taking_damage_tween()
	
	rock_activated = false
	enter_state(State.HIT)
	$pop_balloon.play()
	disable_collision()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	#if balloon_type == BalloonType.GREY:
		#cash_value = balloon_carrier_penalty
	
	#if balloon_type != BalloonType.GREY:
		#money_label_3d.money_is_money(global_position, cash_value)
	is_deactivated = true
	
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.5, 0.33)
	await tween.finished

	shake_camera()
	
		
	await get_tree().create_timer(0.1).timeout
	print('at some point this was called')
	#queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name.contains('Rock'):
		if balloon_type == BalloonType.BLUE:
			rock_pop_balloon()
		else:
			start_destroyed_process()


func restart() -> void:
	# Restore exported flags to their original values.
	balloon_type = default_balloon_type
	hazard_active = default_hazard_active

	behind_player = true
	player_has_marked_balloon = false
	reset_stats()
	reset_rock_back_on()

	if balloon_type == BalloonType.GREY:
		remove_from_group("Target")
	else:
		add_to_group("Target")

	enter_state(State.ACTIVE)
	
	await get_tree().create_timer(2.0).timeout
	scale = Vector3.ONE

	show()
	$Mesh.show()
	$Mesh.scale = Vector3.ONE
	if balloon_type == BalloonType.GREY:
		$Mesh.scale = Vector3.ONE / 2
		
func temp_slow_down() -> void:
	#if has_meta("slowmo_tween"):
		#var old_tween: Tween = get_meta("slowmo_tween")
		#if is_instance_valid(old_tween):
			#old_tween.kill()
#
	var tween := create_tween()
	#set_meta("slowmo_tween", tween)

	# Instantly slow the game down.
	Engine.time_scale = 0.2
	
	# Hold the slow motion briefly.
	tween.tween_interval(0.2)

	# Smoothly return to normal speed.
	tween.tween_property(Engine, "time_scale", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	await tween.finished
	Engine.time_scale = 1.0
	
	
func blast_radius() -> void:
	await get_tree().create_timer(0.1).timeout

	const BLAST_RADIUS := 5.0
	const MAX_DELAY := 0.2

	for target in get_tree().get_nodes_in_group("Target"):
		if target is RockInstance:
			var distance := Vector2(global_position.x, global_position.y).distance_to(
				Vector2(target.global_position.x, target.global_position.y)
			)

			if distance <= BLAST_RADIUS:
				_push_rock_after_delay(target, distance / BLAST_RADIUS * MAX_DELAY)


func _push_rock_after_delay(target: RockInstance, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	if !is_instance_valid(target):
		return

	var force_dir := target.global_position - global_position
	force_dir.z = 0.0
	force_dir = force_dir.normalized()

	target.apply_central_impulse(force_dir * 2)
	target.apply_torque_impulse(force_dir * 500.0)
	
func apply_marked_ability() -> void:
	if balloon_type != BalloonType.RED:
		return

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.remove_sky_mine()

	play_hit_sfx()
	sky_mine_blast()


func sky_mine_blast() -> void:
	if !rock_activated:
		return
		
	%Marked.show()
	$marked_embers.emitting = true
	
	if pan_tween:
		pan_tween.stop()
		pan_tween.kill()
		
	$AnimationPlayer.stop()
	
	
	if being_chained:
		await get_tree().create_timer(0.02).timeout
	
	else:
		#await get_tree().create_timer(1.0).timeout
		penalty_amount = 0
		
	
	%AoE2.play_particles = true
	#var player_cam = get_tree().get_first_node_in_group("player_cam")
	#if player_cam:
		#player_cam.shake_camera_sky_mines()
		#
	player_has_marked_balloon = false
	start_destroyed_process()
	
	var _blast_radius := 5.0

	gl_PlayerState.dataset.power_balloon_buster = 0
	
	return

	for target in get_tree().get_nodes_in_group("Target"):
		if target == self:
			continue

		if !is_instance_valid(target):
			continue

		var distance := Vector2(global_position.x, global_position.y).distance_to(
			Vector2(target.global_position.x, target.global_position.y)
		)

		if distance <= _blast_radius:
			await get_tree().create_timer(0.075).timeout

			var penalty := 2
			if target.name.contains("Balloon") and target.balloon_type == target.BalloonType.RED:
				penalty = chain_penalty
				chain_penalty += 2

			_sky_mine_hit_after_delay(
				target,
				(distance / _blast_radius) * 0.2,
				penalty
		)
		break
		

		
	
func _sky_mine_hit_after_delay(target: Node, delay: float, chain_penalty: int) -> void:
	await get_tree().create_timer(delay).timeout

	if !is_instance_valid(target):
		return

	#if target is RockInstance:
		#if target.current_state == target.State.ACTIVE:
			#target.start_destroyed_process()
			#return

	elif target.name.contains("Balloon"):
		if target.balloon_type != target.BalloonType.RED:
			return
	
		if target.player_has_marked_balloon:
			return
	
		if target.has_method("start_destroyed_process"):
			target.penalty_amount = chain_penalty
			target.being_chained = true
			#target.start_destroyed_process()
			target.sky_mine_blast()
