extends Node3D

const SMOKE_QUICK = preload('uid://dldwpcrllmhxj')

@onready var path: Path3D = $'../..'
@onready var follower: PathFollow3D = $'..'
@onready var wall_mesh: Node3D = $Wall_mesh
@onready var bonus_round_starter: CharacterBody3D = $Bonus_round_starter
@onready var omni_light_3d: OmniLight3D = $OmniLight3D

@onready var timer: Timer = $Timer

@export var move_duration := 0.25 #0.2
@export var roll_amount := -45.0
@export var segment_distance := 0.25 # approximate distance per step
@export var pause_between_steps := 0.2
@export var free_ammo_duration := 30.0

@export var trans_type : Tween.TransitionType
@export var trans_ease : Tween.EaseType

@export var on_timer := true

var distance := 0.0
var total_length := 0.0
var waited := false
var stop_moving := false
var free_ammo_mode := false
var last_gun_fired := 2  # Start with 2 so first shot uses gun 1

func _ready() -> void:
	
	#hide()
	#process_mode = Node.PROCESS_MODE_DISABLED
	
	$Ninja_gun.hide()
	$Ninja_gun2.hide()
	
	EventBus.instance.player_shot_weapon.connect(_player_shot_weapon)
	EventBus.instance.game_lost.connect(_stop_moving)
	EventBus.instance.game_won.connect(_stop_moving)
	bonus_round_starter.ninja_target_destroyed.connect(_free_ammo_started)

	if path:
		total_length = path.curve.get_baked_length()
	
	if on_timer:
		hide()
		#var rand_chance_to_appear = randi_range(1,10)
		#if rand_chance_to_appear > 3:
		timer.wait_time = randf_range(20,40)
		timer.start()
			
	else:
		move_along_path()
		
	#move_along_path()

func _player_shot_weapon(target_position: Vector3) -> void:
	if !free_ammo_mode:
		return
	
	# Alternate between guns
	last_gun_fired = 1 if last_gun_fired == 2 else 2
	var gun = $Ninja_gun if last_gun_fired == 1 else $Ninja_gun2

	# === Aim rotation ===
	var gun_pos = gun.global_position
	var dir = (target_position - gun_pos).normalized()
	var up_vector = Vector3.UP

	# Compute target rotation
	var target_basis = Basis().looking_at(dir, up_vector)
	var target_rotation = target_basis.get_euler()

	# Tween gun to look at target smoothly
	var rotate_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	rotate_tween.tween_property(gun, "rotation", target_rotation, 0.1)

	# === Recoil movement in local space ===
	var recoil_distance := -0.3
	var recoil_offset = -gun.transform.basis.z * recoil_distance
	var start_pos = gun.global_position
	var end_pos = start_pos + recoil_offset

	var recoil_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	recoil_tween.tween_property(gun, "global_position", end_pos, 0.1)
	recoil_tween.tween_property(gun, "global_position", start_pos, 0.15)

	CommonCode.spawn_particles(SMOKE_QUICK, 2.0, gun.global_position, true)
	
func _free_ammo_started() -> void:
	if free_ammo_mode:
		return
	
	free_ammo_mode = true
	EventBus.instance.free_ammo_mode_started.emit()

	var get_player_gun := get_tree().get_first_node_in_group("player_gun")
	var orig_pos: Transform3D = get_player_gun.global_transform

	get_player_gun.hide()
	get_player_gun.global_transform = $Ninja_gun.global_transform

	stop_moving = true
	$Ninja_gun.show()
	$Ninja_gun2.show()

	if $Bonus_round_starter:
		$Bonus_round_starter.hide()

	await get_tree().create_timer(free_ammo_duration).timeout

	get_player_gun.global_transform = orig_pos
	stop_moving = false
	free_ammo_mode = false
	EventBus.instance.free_ammo_mode_finished.emit()
	$Smoke_particles.global_position = global_position
	$Smoke_particles.show()
	$Smoke_particles.emitting = true
	
	await get_tree().create_timer(2.0).timeout
	$Ninja_gun.hide()
	$Ninja_gun2.hide()

	move_duration = 0.1
	pause_between_steps = 0.01
	move_along_path()

func move_along_path() -> void:
	if stop_moving:
		return

	if distance >= total_length:
		print("Reached end of path.")
		return

	if follower.progress_ratio >= 0.0755 and !waited:
		waited = true
		var wait_time = randf_range(3, 6)
		var tween_target = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
		tween_target.tween_interval(wait_time / 2)
		tween_target.tween_property(bonus_round_starter, "rotation_degrees:y", 90.0, 0.2)
		tween_target.tween_interval(wait_time / 4)
		tween_target.tween_property(omni_light_3d, "visible", true, 0.2)
		tween_target.parallel().tween_property(omni_light_3d, "omni_range", 0.45, 0.2).set_trans(Tween.TRANS_BACK)
		tween_target.tween_interval(wait_time / 4)
		await tween_target.finished

	var next_distance = min(distance + segment_distance, total_length)
	var next_offset = next_distance / total_length

	var tween = create_tween().set_trans(trans_type).set_ease(trans_ease)
	tween.tween_property(follower, "progress", follower.progress + next_offset, move_duration)
	tween.parallel().tween_property(wall_mesh, "rotation_degrees:x", roll_amount, move_duration).as_relative()
	await tween.finished
	$climb_walls_sfx.play()
	$door_switch.play()

	distance = next_distance
	await get_tree().create_timer(pause_between_steps).timeout
	move_along_path()

func _stop_moving() -> void:
	stop_moving = true

#func move_along_path_old() -> void:
	#if stop_moving:
		#return
#
	#if distance >= total_length:
		#print("Reached end of path.")
		#return
#
	#if follower.progress_ratio >= 0.098 and !waited:
		#waited = true
		#var wait_time = randf_range(3, 10)
		#var tween_target = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
		#tween_target.tween_interval(wait_time)
		#tween_target.tween_property(bonus_round_starter, "rotation_degrees:y", 90.0, 0.2)
		#await tween_target.finished
#
	#var next_distance = min(distance + segment_distance, total_length)
	#var next_offset = next_distance / total_length
#
	#var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(follower, "progress", follower.progress + next_offset, move_duration)
	#tween.parallel().tween_property(wall_mesh, "rotation_degrees:x", roll_amount, move_duration).as_relative()
	#await tween.finished
	#$climb_walls_sfx.play()
	#$door_switch.play()
#
	#distance = next_distance
	#await get_tree().create_timer(pause_between_steps).timeout
	move_along_path()


func _on_timer_timeout() -> void:
	show()
	move_along_path()
