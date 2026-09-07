extends RigidBody3D
## Energy shard released by `rock-cardinal`. Crosshair overlap or a shot = strike + destroy.
## Not a pooled RockInstance — does not block wait / wait-until-clear.

const TRAIL_SCENE := preload("res://vfx/Trails_scene.tscn")

@export var arm_delay_sec := 0.28
@export var oob_distance := 18.0

@onready var main_col: CollisionShape3D = $CollisionShape3D
@onready var core_mesh: MeshInstance3D = $Core
@onready var glow_mesh: MeshInstance3D = $Glow

var _armed := false
var _dead := false
var _dir := Vector3.RIGHT
var _speed := 16.0
var _size := 0.625
var _lifetime := 2.75
var _spin := 8.0
var _shake_amp := 0.0
var _plane_z := 0.0
var _origin := Vector3.ZERO
var _arm_token := 0
var _life_token := 0
var _rocks_sfx: Node = null


func _ready() -> void:
	add_to_group("cardinal_burst")
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.12
	can_sleep = false
	continuous_cd = true
	axis_lock_linear_z = true
	contact_monitor = true
	max_contacts_reported = 4
	_build_energy_vfx()


func launch(origin: Vector3, dir: Vector3, speed: float, size: float, lifetime: float, spin: float = 8.0, shake: float = 0.0) -> void:
	_origin = origin
	_plane_z = origin.z
	_dir = dir
	_dir.z = 0.0
	if _dir.length_squared() < 0.0001:
		_dir = Vector3.RIGHT
	_dir = _dir.normalized()
	_speed = maxf(speed, 0.1)
	_size = maxf(size, 0.05)
	_lifetime = maxf(lifetime, 0.15)
	_spin = maxf(spin, 0.0)
	_shake_amp = maxf(shake, 0.0)
	global_position = origin + _dir * (_size * 0.45)
	global_position.z = _plane_z
	_apply_size()
	linear_velocity = _dir * _speed
	var spin_axis := Vector3(_dir.y, _dir.x, 0.4)
	if spin_axis.length_squared() > 0.0001 and _spin > 0.0:
		## Parent hang torque is ~1200; shards use a smaller fraction so they tumble, not blur.
		apply_torque_impulse(spin_axis.normalized() * (_spin * 0.01))
	add_to_group("Target")
	_start_lifetime()
	_arm_overlap()


## RockManager reset / round-end calls this so leftover shards vanish.
func dismiss() -> void:
	_die(false)


func enter_state(_state) -> void:
	dismiss()


func update_gravity(_gravity_scale: float) -> void:
	gravity_scale = 0.0


func round_end_check_rock_status() -> void:
	dismiss()


func hit_by_player(_damage: int, _screen_offset: Vector2 = Vector2.ZERO, _freeze_shot := false) -> void:
	_strike_and_die()


func start_bullet_to_target() -> void:
	pass


func _physics_process(_delta: float) -> void:
	if _dead:
		return
	if freeze:
		return
	linear_velocity = _dir * _speed
	var pos := global_position
	pos.z = _plane_z
	global_position = pos
	_apply_flight_shake()
	if _armed and global_position.distance_to(_origin) >= maxf(_size * 1.25, 0.7) and _overlaps_crosshair():
		_strike_and_die()
		return
	if global_position.distance_to(_origin) > oob_distance:
		dismiss()


func _apply_size() -> void:
	if core_mesh:
		core_mesh.scale = Vector3.ONE * _size
	if glow_mesh:
		glow_mesh.scale = Vector3.ONE * _size * 1.35
	if main_col:
		## Match rock-stay-black: mesh 0.625 → collision scale 0.2.
		main_col.scale = Vector3.ONE * (0.2 * (_size / 0.625))


func _apply_flight_shake() -> void:
	if _shake_amp <= 0.0 or core_mesh == null:
		return
	var amp := _shake_amp * 0.35
	var jitter := Vector3(
		randf_range(-amp, amp),
		randf_range(-amp, amp),
		randf_range(-amp * 0.35, amp * 0.35)
	)
	core_mesh.position = jitter
	if glow_mesh:
		glow_mesh.position = jitter


func _build_energy_vfx() -> void:
	if core_mesh and core_mesh.material_override == null:
		var core_mat := StandardMaterial3D.new()
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core_mat.albedo_color = Color(1.0, 0.82, 0.28, 1.0)
		core_mat.emission_enabled = true
		core_mat.emission = Color(1.0, 0.55, 0.12)
		core_mat.emission_energy_multiplier = 6.5
		core_mesh.material_override = core_mat
	if glow_mesh and glow_mesh.material_override == null:
		var glow_mat := StandardMaterial3D.new()
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.albedo_color = Color(1.0, 0.45, 0.08, 0.28)
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(1.0, 0.35, 0.05)
		glow_mat.emission_energy_multiplier = 3.5
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow_mesh.material_override = glow_mat

	if get_node_or_null("Sparks") == null:
		add_child(_make_sparks())
	if get_node_or_null("Wisps") == null:
		add_child(_make_wisps())
	if get_node_or_null("Trail") == null:
		var trail := TRAIL_SCENE.instantiate()
		trail.name = "Trail"
		trail.set("_fromWidth", 0.18)
		trail.set("_toWidth", 0.0)
		trail.set("_lifespan", 0.28)
		trail.set("_startColor", Color(1.0, 0.75, 0.2, 0.85))
		trail.set("_endColor", Color(1.0, 0.2, 0.0, 0.0))
		add_child(trail)


func _make_sparks() -> GPUParticles3D:
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 28
	sparks.lifetime = 0.32
	sparks.emitting = true
	sparks.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 4.5
	pm.scale_min = 0.04
	pm.scale_max = 0.11
	pm.color = Color(4.2, 2.1, 0.25, 1.0)
	sparks.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.albedo_color = Color(1.0, 0.72, 0.18, 0.95)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.5, 0.08)
	spark_mat.emission_energy_multiplier = 5.0
	quad.material = spark_mat
	sparks.draw_pass_1 = quad
	return sparks


func _make_wisps() -> GPUParticles3D:
	var wisps := GPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.amount = 14
	wisps.lifetime = 0.45
	wisps.emitting = true
	wisps.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.spread = 40.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.6
	pm.scale_min = 0.08
	pm.scale_max = 0.2
	pm.color = Color(0.35, 2.4, 3.8, 1.0)
	wisps.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.35, 0.85, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 3.5
	quad.material = mat
	wisps.draw_pass_1 = quad
	return wisps


func _arm_overlap() -> void:
	_armed = false
	_arm_token += 1
	var token := _arm_token
	var delay := maxf(arm_delay_sec, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if token != _arm_token or _dead:
		return
	_armed = true


func _start_lifetime() -> void:
	_life_token += 1
	var token := _life_token
	await get_tree().create_timer(_lifetime, false).timeout
	if token != _life_token or _dead:
		return
	dismiss()


func _strike_and_die() -> void:
	if _dead:
		return
	_play_rocks_sfx("hazard_hit_sound")
	EventBus.instance.hazard_hit.emit()
	_set_strike_feedback_origin_here()
	gl_PlayerState.add_strike()
	_shake_hazard()
	_play_vfx(&"hazard_destroy")
	_die(true)


func _die(from_hit: bool) -> void:
	if _dead:
		return
	_dead = true
	_armed = false
	_arm_token += 1
	_life_token += 1
	remove_from_group("Target")
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	if not from_hit:
		_play_vfx(&"rock_destroy")
	if core_mesh:
		core_mesh.visible = false
	if glow_mesh:
		glow_mesh.visible = false
	var sparks := get_node_or_null("Sparks") as GPUParticles3D
	if sparks:
		sparks.emitting = false
	var wisps := get_node_or_null("Wisps") as GPUParticles3D
	if wisps:
		wisps.emitting = false
	queue_free()


func _overlaps_crosshair() -> bool:
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

	var rock_screen := cam.unproject_position(global_position)
	var crosshair_screen := _player_crosshair_screen_pos(player)

	var world_radius := 0.5
	if main_col and main_col.shape is SphereShape3D:
		world_radius = (main_col.shape as SphereShape3D).radius * main_col.scale.x
	elif core_mesh:
		world_radius = maxf(core_mesh.scale.x, 0.2) * 0.5

	var edge_screen := cam.unproject_position(
		global_position + cam.global_basis.x * world_radius
	)
	var screen_radius := rock_screen.distance_to(edge_screen)
	var hit_radius := _player_live_crosshair_hit_radius(player)
	return rock_screen.distance_to(crosshair_screen) <= hit_radius + screen_radius


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		var rect: Control = weapon.crosshair
		return rect.global_position
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


func _set_strike_feedback_origin_here() -> void:
	var rocks_container = get_tree().get_first_node_in_group("rocks_container")
	if rocks_container and rocks_container.has_method("set_strike_feedback_origin"):
		rocks_container.set_strike_feedback_origin(global_position)


func _shake_hazard() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_rock_hazard"):
		player_cam.shake_camera_rock_hazard()


func _play_vfx(cue: StringName) -> void:
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("play"):
		pool.play(cue, global_position)


func _play_rocks_sfx(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	if _rocks_sfx == null or not is_instance_valid(_rocks_sfx):
		_rocks_sfx = get_tree().get_first_node_in_group("rocks_sfx")
	if _rocks_sfx and _rocks_sfx.has_method("play"):
		_rocks_sfx.play(sfx_name, from_position, pitch_scale, volume_db)
