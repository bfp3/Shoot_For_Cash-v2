extends StaticBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')

const BALLOON_BLUE_MAT = preload('uid://hn35w2qwra5g')
const BALLOON_WHITE_MAT = preload('uid://bwa2khv4jv2fv')
const BALLOON_ORANGE_MAT = preload('uid://bg5auabbq8fo8')
const BALLOON_RED_MAT = preload('uid://c5lrichw3wfce')
const BALLOON_GREY_MAT = preload('uid://dgrbglmgp2fad')
#const BALLOON_YELLOW_MAT = preload('uid://bcrtdxo7t4poh')
const BALLOON_MAT_BANK_BALLOON = preload('res://res/BALLOON_MAT_BANK_BALLOON.tres')
const BALLOON_MAT_MULTIPLIER_BALLOON = preload('res://res/BALLOON_MAT_MULTIPLIER_BALLOON.tres')
const CAMO_MATERIAL = preload('uid://cte0j125svd7e')
var pitch_adjustment := 0.02
const BALLOON_YELLOW_MAT = preload("uid://dfug3isuomnqg")

@onready var balloon_blowing_up: AudioStreamPlayer = $balloon_blowing_up
var player_has_marked_balloon := false

enum PanAxis {
	X_AXIS,
	Y_AXIS
}

var chain_penalty := 2
var being_chained := false

@export_group("Red Balloon Pan")
@export var pan_axis : PanAxis = PanAxis.Y_AXIS
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

@export_group("Pop On Crosshair Overlap")
## Local fallback only. The Player scene "Crosshair Destroy On Overlap / Balloons" flag is the live toggle.
@export var pop_on_crosshair_overlap := false
## Delay after becoming active before overlap can pop (avoids instant pops on spawn).
@export_range(0.0, 3.0, 0.05) var pop_on_crosshair_arm_delay_sec := 0.15

var _pop_on_crosshair_armed := false
var _pop_on_crosshair_arm_token := 0

## When true (bonus-protect), rocks/pineapples popping this BLUE balloon fail the bonus.
var protect_mode := false

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
var occupy_row := -1
var occupy_column := -1
var slot_tween: Tween
## True while flying in or out — ignore extra spawn/clear requests.
var transition_locked := false
var current_state : State



var	force_mult : Array = [3,4]
var force_mult_index := 0

#@onready var money_label_3d: Label3D = $Money_Label3D

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
			#balloon_mesh.material_override = BALLOON_WHITE_MAT
			balloon_mesh.material_override = BALLOON_YELLOW_MAT
			original_penalty_amount = penalty_amount
			#$Decal_Container.show()
			
		BalloonType.RED:
			#balloon_mesh.material_override = BALLOON_RED_MAT
			balloon_mesh.material_override = BALLOON_ORANGE_MAT
			penalty_amount = -10
			#penalty_amount = 0
			original_penalty_amount = penalty_amount
			#var rand_chan := randi_range(0,3)
			#if rand_chan > 2:
				#pan_duration = 1.0
			
		BalloonType.ORANGE:
			balloon_mesh.material_override = BALLOON_ORANGE_MAT
			penalty_amount = -3
			original_penalty_amount = penalty_amount
			
		BalloonType.BLUE:
			balloon_mesh.material_override = BALLOON_YELLOW_MAT
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
	scale = Vector3.ONE * 1.7
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
	if _wants_pop_on_crosshair_overlap():
		_arm_pop_on_crosshair()


func _wants_pop_on_crosshair_overlap() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("wants_crosshair_destroy_on_overlap"):
		return bool(player.wants_crosshair_destroy_on_overlap("balloons"))
	return pop_on_crosshair_overlap


func _process(_delta: float) -> void:
	if not _wants_pop_on_crosshair_overlap():
		return
	if not _pop_on_crosshair_armed:
		return
	if not rock_activated or rock_destroyed or is_deactivated:
		return
	if current_state != State.ACTIVE:
		return
	if transition_locked:
		return
	if not visible or not $Mesh.visible:
		return
	if not _balloon_overlaps_crosshair():
		return
	_pop_on_crosshair_armed = false
	_pop_on_crosshair_arm_token += 1
	# Same outcome as a normal shot for this balloon type.
	hit_by_player(1)


func _arm_pop_on_crosshair() -> void:
	_pop_on_crosshair_armed = false
	_pop_on_crosshair_arm_token += 1
	var token := _pop_on_crosshair_arm_token
	var delay := maxf(pop_on_crosshair_arm_delay_sec, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if token != _pop_on_crosshair_arm_token:
		return
	if not rock_activated or current_state != State.ACTIVE:
		return
	if not _wants_pop_on_crosshair_overlap():
		return
	_pop_on_crosshair_armed = true


func _balloon_overlaps_crosshair() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	else:
		cam = get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return false

	var balloon_screen := cam.unproject_position(get_aim_global_position())
	var crosshair_screen := _player_crosshair_screen_pos(player)

	var world_radius := get_aim_world_radius()

	var edge_screen := cam.unproject_position(
		get_aim_global_position() + cam.global_basis.x * world_radius
	)
	var screen_radius := balloon_screen.distance_to(edge_screen)
	var hit_radius := _player_live_crosshair_hit_radius(player)
	return balloon_screen.distance_to(crosshair_screen) <= hit_radius + screen_radius


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		var rect: Control = weapon.crosshair
		return rect.global_position + Vector2(20.0, 20.0)
	var crosshair: Control = player.get_node_or_null("%Crosshair") as Control
	if crosshair:
		return crosshair.global_position + (crosshair.size * 0.5)
	return get_viewport().get_visible_rect().size * 0.5


func _player_live_crosshair_hit_radius(player: Node) -> float:
	if player == null:
		return 40.0
	if player.has_method("get_current_crosshair_hit_radius"):
		return float(player.get_current_crosshair_hit_radius())
	var weapon = player.get("weapon_shooting")
	if weapon and "power_target_circle" in weapon and float(weapon.power_target_circle) > 0.0:
		return float(weapon.power_target_circle)
	if "power_target_circle" in player and float(player.power_target_circle) > 0.0:
		return float(player.power_target_circle)
	return 40.0

	
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
	set_collision_layer_value(19, false)
	set_collision_layer_value(20, false)
	$main_col.disabled = true
	if %balloon_area:
		%balloon_area.set_deferred("monitoring", false)

func enable_collision() -> void:
	$main_col.disabled = false
	
	set_collision_layer_value(19, true)
	set_collision_layer_value(20, true)

	if %balloon_area:
		%balloon_area.set_deferred("monitoring", true)


## Screen / LOS aim point — prefer the collider (ammo/checkpoint meshes sit above the root).
func get_aim_global_position() -> Vector3:
	if main_col != null and is_instance_valid(main_col):
		return main_col.global_position
	return global_position


## World-space radius used for reticle circle overlap.
func get_aim_world_radius() -> float:
	if main_col == null or not is_instance_valid(main_col) or main_col.shape == null:
		return 0.5
	var gscale := main_col.global_transform.basis.get_scale()
	var sx := absf(gscale.x)
	var sy := absf(gscale.y)
	var sz := absf(gscale.z)
	var shape := main_col.shape
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * maxf(sx, maxf(sy, sz))
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		## Cover the visible balloon silhouette, not just the thin X scale heuristic.
		return maxf(half.x * sx, maxf(half.z * sz, half.y * sy * 0.65))
	return maxf(sx, 0.25) * 0.5


func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "hazard"
	#rock_type_name 	= "hazard_type_1"
	rock_type_name 		= ""

	var base_health 	:= int(gl_DataSet.get_value("hazard_type_1", 1))
	var base_cash 		:= int(gl_DataSet.get_value("balloon_orange", 1))
	var base_scale  	:= Vector3.ONE * 1.0 #0.35

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
	current_rock_type = "hazard"
	rock_type_name = ""
	health = 0
	cash_value = 0
	
	falling = false
	rock_destroyed = false
	is_deactivated = false
	_pop_on_crosshair_armed = false
	_pop_on_crosshair_arm_token += 1
	#global_position = start_pos


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_balloon"):
		player_cam.shake_camera_balloon()

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
	
	if balloon_type == BalloonType.RED and player_has_marked_balloon:
		apply_marked_ability()
		return
	

	match balloon_type:
		BalloonType.BLUE:
			#get_tree().get_first_node_in_group('Player').game_lost = true
			#await get_tree().process_frame
			rock_pop_balloon()
			play_destroy_sfx()
			$pop_balloon_soft.play()
			#global_position = start_pos
			#$Mesh.hide()
			disable_collision()
			
		BalloonType.WHITE:
			_apply_script_balloon_shot()
			start_destroyed_process()

		BalloonType.RED:
			_apply_script_balloon_shot()
			#EventBus.instance.hazard_hit.emit()
			start_destroyed_process()
			
		BalloonType.ORANGE:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, penalty_amount)
			start_destroyed_process()
			
		BalloonType.GREY:
			play_destroy_sfx()
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

	disable_collision()

	play_destroy_sfx()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	if balloon_type == BalloonType.GREY:
		cash_value = balloon_carrier_penalty

	
	if balloon_type == BalloonType.RED and not _script_balloon_uses_container_rules():
		cash_value = int(gl_DataSet.get_value('balloon_orange', 0))
		print("balloon value is ", cash_value)
		#money_label_3d.money_is_money(global_position, cash_value)

		
	set_collision_layer_value(19, false)
	is_deactivated = true
	occupy_row = -1
	occupy_column = -1
	transition_locked = false

	_leave_play_and_notify_sequence()

	smoke_particles()
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.0, 0.33)
	await tween.finished

	#shake_camera()
	

	if balloon_type == BalloonType.RED:
		get_parent().add_balloon_back_into_list(self)


func _leave_play_and_notify_sequence() -> void:
	kill_slot_tween()
	var parent := get_parent()
	if parent and parent.has_method("note_balloon_left_play"):
		parent.note_balloon_left_play()
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return
	var rocks = round_manager.get("rocks_container")
	if rocks and rocks.has_method("notify_clearable_destroyed"):
		rocks.notify_clearable_destroyed()

	
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

	$balloon_blowing_up.play()
	$move_balloon.play()
	
	start_gentle_pan()
	$Mesh.scale = Vector3.ONE
	rock_activated = true
	rock_destroyed = false
	add_to_group('Target')

	$AnimationPlayer.play('idle')
	player_has_marked_balloon = false
	chain_penalty = 2
	being_chained = false
	penalty_amount = original_penalty_amount

	if balloon_type != BalloonType.BLUE:
		start_pos = orig_start_pos
		behind_player = false
		show()
		#await get_tree().create_timer(1.5).timeout
		#$balloon_blowing_up.play()
		#await get_tree().create_timer(1.5).timeout
		#$move_balloon.play()
	
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
	_play_vfx(&"balloon_destroy")

func smoke_particles_duplicates() -> void:
	_play_vfx(&"balloon_destroy")


func _play_vfx(cue: StringName) -> void:
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("play"):
		pool.play(cue, global_position)


func start_bullet_to_target() -> void:
	if balloon_type == BalloonType.BLUE:
		return
		
		
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
		#get_parent().player_balloon_was_popped()

		var crt = get_tree().get_first_node_in_group('TV_CRT_Filter')
		if crt:
			crt.taking_damage_tween()

		if protect_mode:
			_notify_protect_container_popped()
	
	rock_activated = false
	enter_state(State.HIT)
	$pop_balloon.play()
	disable_collision()
	
	if is_in_group('Target'):
		remove_from_group('Target')
	
	is_deactivated = true
	_leave_play_and_notify_sequence()
	
	was_hit_tween()
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale * 1.5, 0.33)
	await tween.finished

	shake_camera()
	
		
	await get_tree().create_timer(0.1).timeout
	print('at some point this was called')
	#queue_free()


func _notify_protect_container_popped() -> void:
	var container := get_parent()
	if container and container.has_method('notify_protect_balloon_popped'):
		container.notify_protect_balloon_popped()


func _input(event: InputEvent) -> void:
	
	if Input.is_action_just_pressed('left'):
		if balloon_type == BalloonType.BLUE:
			restart()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if balloon_type != BalloonType.BLUE:
		return

	#if protect_mode:
		#var is_rock := body is RockInstance or body.name.contains('Rock')
		#var is_pineapple := body.name.contains('Pineapple')
		#if is_rock or is_pineapple:
			#rock_pop_balloon()
		#return

	if body.name.contains('Pineapple'):
		start_destroyed_process()
	
	if body is RockInstance or body.name.contains('Rock'):
		if body.current_state != body.State.ACTIVE:
			print("not active")
			return
			
		print("active")
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
	scale = Vector3.ONE * 1.7

	show()
	$Mesh.show()
	$Mesh.scale = Vector3.ONE
	if balloon_type == BalloonType.GREY:
		$Mesh.scale = Vector3.ONE / 2
		



func _push_rock_after_delay(target: RockInstance, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	if !is_instance_valid(target):
		return

	var force_dir := target.global_position - global_position
	force_dir.z = 0.0
	force_dir = force_dir.normalized()

	target.apply_central_impulse(force_dir * 20)
	target.apply_torque_impulse(force_dir * 500.0)
	
func apply_marked_ability() -> void:
	if balloon_type != BalloonType.RED:
		return

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.remove_sky_mine()

	play_hit_sfx()



	
func _sky_mine_hit_after_delay(target: Node, delay: float, _chain_penalty: int) -> void:
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
			target.penalty_amount = _chain_penalty
			target.being_chained = true
			#target.start_destroyed_process()
			target.sky_mine_blast()


func _script_balloon_uses_container_rules() -> bool:
	var host := get_parent()
	return host != null and ("shooting_balloon_gives_strike" in host)


func _apply_script_balloon_shot() -> void:
	if not _script_balloon_uses_container_rules():
		if balloon_type == BalloonType.RED:
			gl_PlayerState.log_hit('hazard_type_1', 'balloon', -30)
		else:
			gl_PlayerState.log_hit(rock_type_name, current_rock_type, 0)
		return
	var as_strike := bool(get_parent().shooting_balloon_gives_strike)
	if as_strike:
		var rocks = null
		var round_manager = get_tree().get_first_node_in_group("round_manager")
		if round_manager:
			rocks = round_manager.get("rocks_container")
		if rocks and rocks.has_method("suppress_next_strike_feedback"):
			rocks.suppress_next_strike_feedback()
		gl_PlayerState.add_strike()
	else:
		gl_PlayerState.log_hit(rock_type_name, current_rock_type, -10)


func kill_slot_tween() -> void:
	if slot_tween and slot_tween.is_valid():
		slot_tween.kill()
	slot_tween = null


func drift_away_for_checkpoint() -> void:
	if transition_locked or not rock_activated:
		return
	transition_locked = true
	kill_slot_tween()
	rock_activated = false
	stop_gentle_pan()
	disable_collision()
	if is_in_group('Target'):
		remove_from_group('Target')
	set_collision_layer_value(19, false)
	is_deactivated = true
	_leave_play_and_notify_sequence()
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:z", 4.0, 3.0).as_relative()
	tween.parallel().tween_property(self, "global_position:y", 15.0, 3.5)
	tween.parallel().tween_property(self, "global_position:x", -6.0, 3.5).as_relative()
	await tween.finished
	occupy_row = -1
	occupy_column = -1
	transition_locked = false
	var host := get_parent()
	if host and host.has_method("add_balloon_back_into_list"):
		host.add_balloon_back_into_list(self)


func end_of_the_round_pop_balloon(_added_cash : int) -> void:
	if behind_player:
		return
	if not rock_activated and transition_locked:
		return
	transition_locked = true
	kill_slot_tween()
	rock_activated = false
	stop_gentle_pan()
	disable_collision()

	if is_in_group('Target'):
		remove_from_group('Target')

	set_collision_layer_value(19, false)
	is_deactivated = true

	# Reward instead of penalize: always +$1 regardless of balloon_type/penalty_amount.
	cash_value = _added_cash
	cash_value = 0
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:z", 4.0, 3.0).as_relative()
	tween.parallel().tween_property(self, "global_position:y", 15.0, 3.5) #.as_relative()
	tween.parallel().tween_property(self, "global_position:x", -6.0, 3.5).as_relative()
	await tween.finished
	occupy_row = -1
	occupy_column = -1
	transition_locked = false

	if balloon_type == BalloonType.RED:
		get_parent().add_balloon_back_into_list(self)
	else:
		get_parent().add_balloon_back_into_list(self)
