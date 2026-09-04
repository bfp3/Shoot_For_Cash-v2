extends RigidBody3D
## Shootable layout crate. Regular crates knock outward on each hit; cash crates also play VFX.
## SFX live on the shared crates_sfx manager (see Main), not in this scene.

const max_hits := 1
const cash_value := 0
@export var use_hit_vfx := false
@export var use_destroy_sfx := true
@export var destroy_vfx_cue := &""
@export var hit_vfx_cue := &"rock_hit"

@export_group("Hit Knockback")
@export var hit_impulse_power := 8.0
@export var hit_upward_bias := 0.35
@export var hit_torque_strength := 5.0
@export var hit_linear_damp := 1.3
@export var hit_angular_damp := 1.0
@export var force_mult: Array = [3, 4]

@onready var main_col: CollisionShape3D = $CollisionShape3D


var health := 3
var force_mult_index := 0
var _destroyed := false
var _crates_sfx: Node = null


func _ready() -> void:
	health = max_hits
	add_to_group("Target")
	if force_mult.is_empty():
		force_mult = [3, 4]
	force_mult.shuffle()


func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _destroyed:
		return
	health -= maxi(damage, 1)
	play_hit_sfx()
	if health > 0:
		apply_hit_reaction()
		if use_hit_vfx:
			_play_vfx(hit_vfx_cue)
		return
	_start_destroyed()

func start_bullet_to_target() -> void:
	pass

func apply_hit_reaction() -> void:
	axis_lock_linear_x = false
	axis_lock_linear_y = false
	axis_lock_linear_z = false
	axis_lock_angular_x = false
	axis_lock_angular_y = false
	axis_lock_angular_z = false
	linear_damp = hit_linear_damp
	angular_damp = hit_angular_damp
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if force_mult_index >= force_mult.size() - 1:
		force_mult_index = 0
	else:
		force_mult_index += 1
	var mult: float = float(force_mult[force_mult_index])

	var force_dir := _away_from_player_direction()
	apply_central_impulse(force_dir * hit_impulse_power * mult)

	var torque_dir := Vector3(force_dir.z, 1.0, -force_dir.x).normalized()
	apply_torque_impulse(torque_dir * mult * hit_torque_strength)


func _away_from_player_direction() -> Vector3:
	var player := get_tree().get_first_node_in_group("Player")
	var dir := Vector3.FORWARD
	if player and is_instance_valid(player):
		dir = global_position - player.global_position
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir.y = maxf(dir.y, 0.0) + hit_upward_bias
	return dir.normalized()


func _start_destroyed() -> void:
	_destroyed = true
	remove_from_group("Target")
	## Fire destroy SFX before freeing — scheduled on the scene tree so it outlives this node.
	if use_destroy_sfx:
		play_destroy_sfx()
	if destroy_vfx_cue != &"":
		_play_vfx(destroy_vfx_cue)
	if cash_value > 0:
		gl_PlayerState.log_hit("crate", "crate_for_cash", cash_value, global_position)

	freeze = true
	collision_layer = 0
	collision_mask = 0

	if main_col:
		main_col.disabled = true
	await get_tree().create_timer(0.05, false).timeout
	queue_free()


func play_hit_sfx() -> void:
	var vol := randf_range(-25.0, -20.0)
	var pitch := randf_range(0.9, 1.2)
	var mgr := _crates_sfx_manager()
	if mgr == null or not mgr.has_method("play"):
		return
	var tree := get_tree()
	if tree == null:
		mgr.play("crate_hit_sound", 0.01, pitch, vol)
		return
	tree.create_timer(0.05, true, false, true).timeout.connect(
		func () -> void:
			if is_instance_valid(mgr):
				mgr.play("crate_hit_sound", 0.01, pitch, vol),
		CONNECT_ONE_SHOT
	)
	tree.create_timer(0.15, true, false, true).timeout.connect(
		func () -> void:
			if is_instance_valid(mgr):
				mgr.play("crate_hit_sound", 0.02, pitch, vol),
		CONNECT_ONE_SHOT
	)


func play_destroy_sfx() -> void:
	var mgr := _crates_sfx_manager()
	if mgr == null or not mgr.has_method("play"):
		return
	## Immediate destroy sting + layered follow-ups that survive queue_free.
	mgr.play("crate_destroy_sfx")
	var tree := get_tree()
	if tree == null:
		mgr.play("crate_hitSound")
		mgr.play("crate_explosion_sfx")
		return
	tree.create_timer(0.1, true, false, true).timeout.connect(
		func () -> void:
			if is_instance_valid(mgr):
				mgr.play("crate_hitSound"),
		CONNECT_ONE_SHOT
	)
	tree.create_timer(0.2, true, false, true).timeout.connect(
		func () -> void:
			if is_instance_valid(mgr):
				mgr.play("crate_explosion_sfx"),
		CONNECT_ONE_SHOT
	)


func _crates_sfx_manager() -> Node:
	if _crates_sfx != null and is_instance_valid(_crates_sfx):
		return _crates_sfx
	var tree := get_tree()
	if tree:
		_crates_sfx = tree.get_first_node_in_group("crates_sfx")
	return _crates_sfx


func _play_crates_sfx(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	var mgr := _crates_sfx_manager()
	if mgr and mgr.has_method("play"):
		mgr.play(sfx_name, from_position, pitch_scale, volume_db)


func _play_vfx(cue: StringName) -> void:
	if cue == &"":
		return
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("play"):
		pool.play(cue, global_position)
