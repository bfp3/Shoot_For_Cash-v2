extends RigidBody3D

const ON_TARGET_SFX = preload('uid://dqbrbkai0p60l')
const INVISIBLE_XRAY_SHADER := preload("res://ch/Rocks/fake_rock_xray.gdshader")
const INVISIBLE_XRAY_TINT := Color(1.35, 0.72, 0.12, 1.0)

## When true, multi-shot oranges rise to the hit / midpoint Y instead of a fixed apex.
@export var aim_apex_at_hit_height := true
## When true, spawn X snaps to the nearest aim-grid column.
@export var snap_x_to_nearest_column := true
## When true, any RockInstance that physically collides with this orange makes it explode.
@export var explode_on_rock_collision := true

var cash_value := 0
var original_cash_value := 0
## When false, HIT state skips log_hit / cash (end-of-round explode cleanup).
var _award_cash_on_hit := true



@export var force_multiplier := 1.5
var pitch_adjustment := 0.02
var _orange_sfx: Node = null
var taken_hit = false
@onready var main_col: CollisionShape3D = $main_col
@onready var invisible_col: Area3D = get_node_or_null("%InvisibleCol") as Area3D
@onready var invisible_col_shape: CollisionShape3D = get_node_or_null("%InvisibleCol/CollisionShape3D") as CollisionShape3D

## Dedicated physics layer for the invisible-orange Area3D (independent of main_col).
const INVISIBLE_COL_LAYER := 10

enum ExitSide {
	LEFT,
	RIGHT,
	TOP
}

var exit_side : ExitSide

enum State {
	INACTIVE,
	PREPARE_ROCK,
	ACTIVE,
	MISSED,
	HIT,
	DISABLED
}
@export var pulse_magnitude := 0.8

@export var current_state : State = State.INACTIVE


var	force_mult : Array = [3,4]
var force_mult_index := 0

var rock_type_gravity_scale := 0.4

## Stagger index for basic rocks caught in this orange's blast.
var _blast_destroy_stagger_index := 0
const BLAST_DESTROY_STAGGER_SEC := 0.075
const BLAST_DOMAIN_EXPANSION := 14.0
const SMOKE_BLOW_BUFFER := 5.0

@onready var orange_mesh := $Mesh/small_rock

@onready var current_mesh : MeshInstance3D= orange_mesh

var max_health : int = 0


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

## Soft apex lock for multi-shot launches (world Y). INF = disabled.
var _apex_target_y := INF
var _apex_lock_active := false
## This launch uses InvisibleCol for all aim / overlap / shooting — never main_col.
var _invisible_mode := false
## Peek through the reticle like fake-rock / hidden-crate x-ray (not a one-shot unlock).
var _invisible_until_aim := false
var _invisible_xray_mat: ShaderMaterial = null
var _invisible_xray_originals: Dictionary = {}
var _invisible_overlay: MeshInstance3D = null
## Same visual layers as hidden-crate (16) and fake-rock overlay (20), plus default.
const INVISIBLE_OVERLAY_LAYERS := 1 | 32768 | 524288


func _process(_delta: float) -> void:
	if _invisible_until_aim and rock_activated and not rock_destroyed:
		_update_invisible_aim_reveal()


func _physics_process(_delta: float) -> void:
	if not _apex_lock_active or not rock_activated or falling or rock_destroyed:
		return
	## Invisible oranges spawn on the cell — pin Y even if gravity tugs downward.
	if _invisible_until_aim:
		global_position.y = _apex_target_y
		if linear_velocity.y != 0.0:
			linear_velocity.y = 0.0
		return
	if global_position.y < _apex_target_y:
		return
	# Hold at the hit height until the fall timer kicks in — keep the soft hover feel.
	global_position.y = _apex_target_y
	if linear_velocity.y > 0.0:
		linear_velocity.y = 0.0


## Configure apex / column targeting for a multi-shot spawn. Call after update_active.
func configure_multi_launch(hit_pos: Vector3) -> void:
	_apex_lock_active = false
	_apex_target_y = INF

	var spawn_x := hit_pos.x
	if snap_x_to_nearest_column:
		var rocks := _get_rock_manager()
		if rocks != null and rocks.has_method("nearest_column_x"):
			spawn_x = rocks.nearest_column_x(hit_pos.x)

	global_position.x = spawn_x
	global_position.z = hit_pos.z

	if aim_apex_at_hit_height:
		_apex_target_y = hit_pos.y
		_apex_lock_active = true


func prepare_invisible_launch() -> void:
	_invisible_mode = true
	_invisible_until_aim = true


## Hidden until the reticle peeks it. Sits on the aim cell (not the underground pool Y).
func configure_invisible_launch(aim_pos: Vector3) -> void:
	_invisible_mode = true
	_invisible_until_aim = true
	_apex_lock_active = true
	_apex_target_y = aim_pos.y
	freeze = false
	sleeping = false
	global_position = aim_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_hide_until_aim_reveal()


func _hide_until_aim_reveal() -> void:
	show()
	_disable_rigid_collision()
	_set_invisible_col_active(true)
	_set_invisible_explosion_hidden(true)
	if has_node("%GoldParticless"):
		%GoldParticless.emitting = false
	if has_node("Mesh/small_rock/Fire"):
		$Mesh/small_rock/Fire.emitting = false
		$Mesh/small_rock/Fire.hide()
	if has_node("Mesh"):
		$Mesh.show()
	## Authored pineapple mesh is an ArrayMesh under a mesh-less parent — peek uses
	## a dedicated sphere overlay (same approach as fake-rock x-ray).
	if orange_mesh:
		orange_mesh.hide()
	_setup_invisible_xray()
	if not is_in_group("Target"):
		add_to_group("Target")


func _set_invisible_explosion_hidden(hidden: bool) -> void:
	if not has_node("Explosion_area"):
		return
	if not hidden:
		return
	$Explosion_area.monitoring = false
	$Explosion_area.hide()
	if has_node("Explosion_area/CollisionShape3D"):
		$Explosion_area/CollisionShape3D.disabled = true
	if has_node("%explosion_radius_mesh"):
		%explosion_radius_mesh.hide()
		%explosion_radius_mesh.transparency = 1.0


func _ensure_invisible_overlay() -> MeshInstance3D:
	if _invisible_overlay != null and is_instance_valid(_invisible_overlay):
		return _invisible_overlay
	var mesh_root: Node = get_node_or_null("Mesh")
	if mesh_root == null:
		return null
	_invisible_overlay = MeshInstance3D.new()
	_invisible_overlay.name = "InvisibleXrayOverlay"
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.radial_segments = 16
	sphere.rings = 8
	_invisible_overlay.mesh = sphere
	_invisible_overlay.layers = INVISIBLE_OVERLAY_LAYERS
	_invisible_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_invisible_overlay.extra_cull_margin = 4.0
	_invisible_overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh_root.add_child(_invisible_overlay)
	return _invisible_overlay


func _setup_invisible_xray() -> void:
	var overlay := _ensure_invisible_overlay()
	if _invisible_xray_mat == null:
		_invisible_xray_mat = ShaderMaterial.new()
		_invisible_xray_mat.shader = INVISIBLE_XRAY_SHADER
		_invisible_xray_mat.render_priority = 2
		_invisible_xray_mat.set_shader_parameter("use_albedo_tex", 0.0)
		_invisible_xray_mat.set_shader_parameter("albedo_tint", INVISIBLE_XRAY_TINT)
		_invisible_xray_mat.set_shader_parameter("emission_color", INVISIBLE_XRAY_TINT)
		_invisible_xray_mat.set_shader_parameter("emission_mul", 0.85)
	if overlay:
		if not _invisible_xray_originals.has(overlay):
			_invisible_xray_originals[overlay] = overlay.material_override
		overlay.material_override = _invisible_xray_mat
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.transparency = 0.0
		overlay.visible = true
	_apply_invisible_xray(Vector2.ZERO, 0.0)


func _clear_invisible_xray() -> void:
	for mesh in _invisible_xray_originals.keys():
		if mesh == null or not is_instance_valid(mesh):
			continue
		mesh.material_override = _invisible_xray_originals[mesh]
	_invisible_xray_originals.clear()
	if _invisible_overlay != null and is_instance_valid(_invisible_overlay):
		_invisible_overlay.visible = false
	if orange_mesh:
		orange_mesh.show()
	_apply_invisible_xray(Vector2.ZERO, 0.0)


func _update_invisible_aim_reveal() -> void:
	if not _invisible_until_aim:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		_apply_invisible_xray(Vector2.ZERO, 0.0)
		return
	if "current_state" in player and "State" in player and player.current_state != player.State.ACTIVE:
		_apply_invisible_xray(Vector2.ZERO, 0.0)
		return
	var aim := _invisible_aim_center_px(player)
	var radius := _invisible_aim_radius_px(player)
	_apply_invisible_xray(aim, radius)


func _invisible_aim_center_px(player: Node) -> Vector2:
	var canvas := Vector2.ZERO
	if player != null and player.has_method("_aim_screen_center"):
		canvas = player._aim_screen_center()
	else:
		canvas = _player_crosshair_screen_pos(player)
	var vp := get_viewport()
	if vp:
		return vp.get_screen_transform() * canvas
	return canvas


func _invisible_aim_radius_px(player: Node) -> float:
	var radius := 60.0
	if player != null and player.has_method("get_current_crosshair_hit_radius"):
		radius = float(player.get_current_crosshair_hit_radius())
	var vp := get_viewport()
	if vp:
		var scale := vp.get_screen_transform().get_scale()
		if scale.x > 0.001:
			radius *= scale.x
	return maxf(radius, 28.0)


func _apply_invisible_xray(center_px: Vector2, radius_px: float) -> void:
	if _invisible_xray_mat == null:
		return
	var softness := maxf(14.0, radius_px * 0.12)
	_invisible_xray_mat.set_shader_parameter("xray_center_px", center_px)
	_invisible_xray_mat.set_shader_parameter("xray_radius_px", radius_px)
	_invisible_xray_mat.set_shader_parameter("xray_softness_px", softness)
	_invisible_xray_mat.set_shader_parameter("emission_mul", 0.85 if radius_px > 0.0 else 0.0)


func get_aim_global_position() -> Vector3:
	if _invisible_mode and invisible_col != null and is_instance_valid(invisible_col):
		return invisible_col.global_position
	if main_col != null and is_instance_valid(main_col):
		return main_col.global_position
	return global_position


func get_aim_world_radius() -> float:
	if _invisible_mode and invisible_col_shape != null and is_instance_valid(invisible_col_shape):
		if invisible_col_shape.shape is SphereShape3D:
			var world_scale := invisible_col_shape.global_transform.basis.get_scale()
			return (invisible_col_shape.shape as SphereShape3D).radius * absf(world_scale.x)
	if main_col != null and is_instance_valid(main_col):
		return absf(main_col.global_transform.basis.get_scale().x) * 0.5
	if current_mesh:
		return maxf(current_mesh.scale.x, 0.2) * 0.5
	return 0.5


func _set_invisible_col_active(active: bool) -> void:
	if invisible_col == null or not is_instance_valid(invisible_col):
		return
	if invisible_col_shape:
		invisible_col_shape.disabled = not active
	invisible_col.collision_layer = 0
	invisible_col.collision_mask = 0
	if active:
		invisible_col.set_collision_layer_value(INVISIBLE_COL_LAYER, true)
	invisible_col.set_deferred("monitorable", active)
	invisible_col.set_deferred("monitoring", active)


func _disable_rigid_collision() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(8, false)
	set_collision_mask_value(8, false)
	set_collision_mask_value(1, false)
	if main_col:
		main_col.disabled = true


func _player_crosshair_screen_pos(player: Node) -> Vector2:
	var offset := Vector2(20.0, 20.0)
	if player and "CROSSHAIR_CENTER_OFFSET" in player:
		offset = player.CROSSHAIR_CENTER_OFFSET
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("crosshair") is Control:
		return (weapon.crosshair as Control).global_position + offset
	var crosshair: Control = player.get_node_or_null("%Crosshair") as Control
	if crosshair:
		return crosshair.global_position + offset
	return get_viewport().get_visible_rect().size * 0.5


func _get_rock_manager() -> RockManager:
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm != null:
		var rocks = rm.get("rocks_container")
		if rocks is RockManager:
			return rocks
	var scene := get_tree().current_scene
	if scene != null:
		var node := scene.get_node_or_null("Rocks")
		if node is RockManager:
			return node
	return null



func _ready() -> void:
	
	start_pos = global_position
	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_orange_body_entered):
		body_entered.connect(_on_orange_body_entered)
	
	# End-of-round explode is driven by RoundManager with a stagger (not EventBus).
	EventBus.instance.open_shop.connect(update_disabled)
	await get_tree().create_timer(0.2).timeout
	
	enter_state(State.INACTIVE)

	
	cash_value = int(gl_DataSet.get_value('orange', 0))
	original_cash_value = cash_value

func start_falling() -> void:
	## End-of-round cleanup: explode like a shot, but skip blast radius (and cash).
	## Note: launch uses update_active() without enter_state(ACTIVE), so state may
	## still be INACTIVE while rock_activated is true — don't gate on state alone.
	if rock_destroyed or current_state == State.HIT:
		return
	if not rock_activated:
		return
	rock_destroyed = true
	start_destroyed_process(false, false)


func force_end_of_round_explode() -> void:
	## Round wrap used to explode leftovers; they now despawn quietly so the tally isn't held.
	dismiss_quietly_for_round_end()


## Hide and park this orange with no cash, blast, or SFX. Next round can reuse the body.
func dismiss_quietly_for_round_end() -> void:
	var was_live := rock_activated
	_award_cash_on_hit = false
	_invisible_until_aim = false
	_invisible_mode = false
	_clear_invisible_xray()
	_set_invisible_col_active(false)
	if was_live:
		var round_manager: RoundManager = get_tree().get_first_node_in_group("round_manager")
		if round_manager:
			round_manager.orange_active = maxi(int(round_manager.orange_active) - 1, 0)
	remove_from_group("Target")
	reset_stats()
	disable_collision()
	freeze = true
	hide()
	enter_state(State.INACTIVE)
	_award_cash_on_hit = true

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
	
func update_prepare_rock() -> void:
	reset_stats()
	await get_tree().process_frame
	force_mult.shuffle()
	await get_tree().process_frame
	
func update_active() -> void:
	var keep_invisible := _invisible_until_aim
	var keep_invisible_mode := _invisible_mode
	disable_collision()
	reset_stats()
	_invisible_until_aim = keep_invisible
	_invisible_mode = keep_invisible_mode
	enable_collision()
	reset_rock_back_on()
	#update_gravity(0.0)
	update_gravity(0.01)
	global_position = start_pos
	# X is set by the launcher (multi-shot hit / column snap). Keep a mild random only
	# when neither new targeting export is on.
	if not aim_apex_at_hit_height and not snap_x_to_nearest_column:
		global_position.x = randi_range(-8, 8)
	health = 1
	linear_damp = 5.0
	rock_activated = true
	apply_torque_impulse(Vector3.UP * 1000.0)
	_play_orange_sfx("launch_sound")
	if _invisible_until_aim:
		_hide_until_aim_reveal()
		return
	%GoldParticless.emitting = true
	$Mesh/small_rock/Fire.emitting = true
	$Mesh/small_rock/Fire.show()
	add_to_group('Target')
	orange_mesh.show()
	$Mesh.show()
	_play_orange_sfx("explosion_sfx")
	_play_vfx(&"orange_hit")
	
func update_hit() -> void:
	update_gravity(1.0)
	%GoldParticless.emitting = false
	$Mesh/small_rock/Fire.emitting = false
	$Mesh/small_rock/Fire.hide()
	_play_orange_sfx("Pineapple_sound_hit")
	disable_collision()
	if _award_cash_on_hit:
		gl_PlayerState.log_hit('orange', 'orange', cash_value, global_position)
	_play_orange_sfx("Pineapple_shot_explode")
	
	await get_tree().create_timer(0.3).timeout
	_play_orange_sfx("Pineapple_destroyed")
	
func update_missed() -> void:
	reset_stats()
	disable_collision()

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
			print("We are in some other state pineapple", current_state)

func update_disabled() -> void:
	update_gravity(1.0)
	disable_collision()
	remove_from_group('Target')



func disable_collision() -> void:
	_disable_rigid_collision()
	_set_invisible_col_active(false)


func enable_collision() -> void:
	_disable_rigid_collision()
	if _invisible_mode:
		_set_invisible_col_active(true)
		return
	if main_col:
		main_col.disabled = false
	set_collision_layer_value(8, true)
	set_collision_mask_value(8, true)
	set_collision_mask_value(1, true)
	set_collision_layer_value(1, true)


func update_gravity(_gravity_scale : float) -> void:
	gravity_scale = _gravity_scale
	pass

func reset_rock_back_on() -> void:
	#enter_state(State.MISSED)
	current_rock_type 	= "Small Rock"
	rock_type_name 		= "rock_type_1"

	var base_health := int(gl_DataSet.get_value("rock_type_1", 1))

	#var base_scale  := Vector3.ONE * 2 #* 0.35

	# Random subtype: 1x / 2x / 3x
	$hit_wall_timer.stop()
	$Mesh.scale = Vector3.ONE
	health = base_health
	#cash_value = base_cash # * size_multiplier
	max_health = health
	orange_mesh.visible = true
	main_col.scale = Vector3.ONE #base_scale
	current_mesh = orange_mesh
	current_mesh.scale = Vector3.ONE * 2#base_scale

	rock_type_gravity_scale = 0.2
	show()

func reset_stats() -> void:
	hide()
	$Mesh.scale = Vector3.ONE
	$Mesh.show()
	$hit_wall_timer.stop()
	pitch_adjustment = 0.02
	taken_hit = false
	rock_activated = false
	current_mesh = orange_mesh
	current_rock_type = ""
	rock_type_name = ""
	health = 0
	cash_value = original_cash_value
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	falling = false
	rock_destroyed = false
	is_deactivated = false
	_apex_lock_active = false
	_apex_target_y = INF
	_invisible_until_aim = false
	_invisible_mode = false
	_clear_invisible_xray()
	_set_invisible_col_active(false)
	global_position = start_pos


func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ONE / 99, 0.10)
	await tween.finished


func _cleanup_after_end_of_round_explode() -> void:
	if has_node("%explosion_radius_mesh"):
		%explosion_radius_mesh.hide()
		%explosion_radius_mesh.transparency = 1.0
	if has_node("Mesh"):
		$Mesh.hide()
	if current_mesh and is_instance_valid(current_mesh):
		current_mesh.hide()
	global_position = start_pos
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func shake_camera() -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")
	if player_cam and player_cam.has_method("shake_camera_orange"):
		player_cam.shake_camera_orange()

func apply_hit_reaction(screen_offset : Vector2) -> void:

	gravity_scale = 0.1
	linear_velocity = Vector3.ZERO
	
	
	
	var camera = get_viewport().get_camera_3d()

	#screen_offset = Vector2.UP

	if camera == null:
		return

	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	var force_dir = (right * screen_offset.x) + (up * -screen_offset.y)
	var vertical_amount = force_dir.dot(up)

	if vertical_amount < 0.0:
		force_dir -= up * vertical_amount
		force_dir += up * 0.15

	force_dir = force_dir.normalized()
	#apply_central_impulse(force_dir * force_mult[force_mult_index])
	
	fly_off_into_the_distance()
	
	# spin a bit too
	var torque_dir = Vector3(
		force_dir.z,
		1.0,
		-force_dir.x
	).normalized()
	
	torque_dir = torque_dir * force_mult[force_mult_index]
	apply_torque_impulse(torque_dir * hit_torque_strength)

	

	# Quick squash/stretch feedback
	if current_mesh.scale <= Vector3.ONE * 0.3:
		current_mesh.get_node('damage_mesh').show()
		await get_tree().create_timer(0.08).timeout
		current_mesh.get_node('damage_mesh').hide()
		gravity_scale = rock_type_gravity_scale

		return
		
	if current_mesh:
		var original_scale := current_mesh.scale
		current_mesh.get_node('damage_mesh').show()
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		tween.tween_property(
			current_mesh,
			"scale",
			original_scale * 0.85,
			0.08
		)

		tween.tween_property(
			current_mesh,
			"scale",
			original_scale,
			0.12
		)
		
		await tween.finished
		current_mesh.get_node('damage_mesh').hide()
	
	gravity_scale = rock_type_gravity_scale
	
	
func fly_off_into_the_distance() -> void:
	var strength : float = [2.0,3.0].pick_random()
	var x_direction := 1.0
	if global_position.x <= -1.0:
		x_direction = -15.0
	
	else:
		x_direction = 15.0
	linear_damp = 0.5
	apply_central_impulse(Vector3(x_direction,-2.0,-35) * -strength)
		

		
func hit_by_player(damage : int, screen_offset : Vector2 = Vector2.ZERO) -> void:
	health -= damage
	taken_hit = true
	smoke_particles_duplicates()
	if health > 0:
		play_hit_sfx()
		apply_hit_reaction(screen_offset)
		return
	
	rock_destroyed = true
	start_destroyed_process()
	



func bounce_rocks() -> void:
	update_gravity(0.04)
	#update_gravity(0.0)
	global_position = start_pos

func start_destroyed_process(expand_blast: bool = true, award_cash: bool = true) -> void:

	if !rock_activated:
		return
		
	_award_cash_on_hit = award_cash
	rock_destroyed = true
	_invisible_until_aim = false
	_clear_invisible_xray()
	
	if expand_blast:
		expand_blast_radius()

	
	#$Mesh/Yellow_particles.emitting = true
	rock_activated = false
	freeze = true
	enter_state(State.HIT)
	
	#if !destroyed_by_marked:
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager:
		round_manager.orange_active -= 1
	
	remove_from_group('Target')

	play_destroy_sfx()

	## Special challenge (e.g. Noir): shooting an orange = strike, no bonus cash.
	var challenge_fail := false
	if award_cash and round_manager and round_manager.has_method("has_active_special_challenge"):
		challenge_fail = bool(round_manager.has_active_special_challenge("no_shoot_oranges"))
	if award_cash:
		if challenge_fail:
			if round_manager.has_method("on_special_challenge_orange_shot"):
				round_manager.on_special_challenge_orange_shot()
		else:
			gl_PlayerState.add_bonus(cash_value)
			#money_label_3d.money_is_money(global_position, cash_value)
	

	is_deactivated = true
	#$Mesh.hide()
	#freeze = true
	
	await was_hit_tween()
	
#
	#var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(current_mesh, "scale", current_mesh.scale * 1.5, 0.33)
	#await tween.finished

	shake_camera()

	## End-of-round explode: park/hide so the blast mesh isn't left floating in the sky.
	if not award_cash:
		_cleanup_after_end_of_round_explode()
	
	_award_cash_on_hit = true
	

func play_hit_sfx() -> void:
	var vol := randf_range(-25.0, -20.0)
	var pitch := randf_range(0.9, 1.2)
	await get_tree().create_timer(0.05, false).timeout
	_play_orange_sfx("take_damage_sfx", 0.01, pitch, vol)
	await get_tree().create_timer(0.1,false).timeout
	_play_orange_sfx("take_damage_sfx", 0.02, pitch, vol)


func play_destroy_sfx() -> void:
	_play_orange_sfx("take_damage_sfx", 0.02)
	await get_tree().create_timer(0.1, false).timeout
	_play_orange_sfx("hitSound")
	await get_tree().create_timer(0.1, false).timeout
	_play_orange_sfx("explosion_sfx")
	

func _on_start_falling_timer_timeout() -> void:
	## Oranges stay put at apex after launch — fall-back disabled.
	pass


func _on_orange_body_entered(body: Node) -> void:
	if not explode_on_rock_collision:
		return
	if not rock_activated or rock_destroyed or is_deactivated:
		return
	if body == null or body == self:
		return
	if body is not RockInstance:
		return
	var rock := body as RockInstance
	if not rock.rock_activated or rock.rock_destroyed:
		return
	start_destroyed_process()


func smoke_particles() -> void:
	_play_vfx(&"orange_destroy")


func smoke_particles_duplicates() -> void:
	_play_vfx(&"orange_hit")


func _play_vfx(cue: StringName) -> void:
	var pool := get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("play"):
		pool.play(cue, global_position)


func start_bullet_to_target() -> void:
	play_accurate_sounds()
	
	
func play_accurate_sounds() -> void:
	_play_orange_stream(ON_TARGET_SFX, -30.0, 0.7 + pitch_adjustment)
	pitch_adjustment += 0.05


func create_shot_instance(sound_file : AudioStream, volume_db : float, pitch_scale : float = 0.02) -> void:
	_play_orange_stream(sound_file, volume_db, pitch_scale)


func _orange_sfx_manager() -> Node:
	if _orange_sfx != null and is_instance_valid(_orange_sfx):
		return _orange_sfx
	var tree := get_tree()
	if tree:
		_orange_sfx = tree.get_first_node_in_group("orange_sfx")
	return _orange_sfx


func _play_orange_sfx(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	var mgr := _orange_sfx_manager()
	if mgr and mgr.has_method("play"):
		mgr.play(sfx_name, from_position, pitch_scale, volume_db)


func _play_orange_stream(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var mgr := _orange_sfx_manager()
	if mgr and mgr.has_method("play_stream"):
		mgr.play_stream(stream, volume_db, pitch_scale)
		
func hit_out_of_bounds() -> void:
	if !rock_activated:
		return
	rock_activated = false
	rock_destroyed = true
	disable_collision()
	
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager:
		round_manager.orange_active -= 1
	
	freeze = true

	remove_from_group('Target')
	# Penalize instead of reward
	gl_PlayerState.log_hit('orange', 'orange', 0)
	is_deactivated = true
	$Mesh.hide()
	enter_state(State.MISSED)





func _on_explosion_area_body_entered(body: Node3D) -> void:

	#if body.name.contains('Balloon'):
		#if body.balloon_type == body.BalloonType.BLUE:
			#return
		#body.destroyed_by_shratnel()
	
	#if body.name.contains('range') || body.name.contains('apple'):
	if body.name.contains('apple'): #pineapple
		var strength : float = [2.0,3.0].pick_random()
		body.rock_destroyed = true
		body.apply_central_impulse(body.global_position - global_position * -strength)
		await get_tree().create_timer(1.6,false).timeout
		body.rock_destroyed = false
		await get_tree().create_timer(0.1, false).timeout
		body.start_destroyed_process()
		#body.axis_lock_linear_z = true

	
	if body is RockInstance:
		if body.rock_type == body.RockSize.HAZARD or body.rock_type == body.RockSize.HAZARD_SMALL or (body.has_method("is_stay_black") and body.is_stay_black()):
			_neutralize_black_rock_from_orange(body)
			return

		# Pineapples / non-basic rocks: no staggered chain — keep existing short delay.
		var is_basic = body.rock_type == body.RockSize.SMALL
		if body.has_method("is_standard_rock"):
			is_basic = bool(body.is_standard_rock())
		if not is_basic:
			await get_tree().create_timer(randf_range(0.1, 0.15), false).timeout
			body.start_destroyed_process()
			return
		
		if body.rock_type != body.RockSize.AVOIDER:
			body.start_destroyed_process()
			return
		
		# Basic rocks: stagger destroy chain so they don't all pop at once.
		var stagger_i := _blast_destroy_stagger_index
		_blast_destroy_stagger_index += 1
		await get_tree().create_timer(
			float(stagger_i) * BLAST_DESTROY_STAGGER_SEC,
			false
		).timeout
		if is_instance_valid(body):
			body.start_destroyed_process()

		#body.hit_by_player(100, Vector2.ZERO)
		
		
func _neutralize_black_rock_from_orange(body: RockInstance) -> void:
	## Orange hit a black rock: never award a strike. Two modes via RoundManager flag.
	body._orange_neutralized_hazard = true
	body.cash_value = 2
	body.ignores_x_out_of_bounds = true

	var instant := false
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm != null:
		instant = bool(rm.get("orange_black_rock_instant_explode"))

	if instant:
		## Explode in place for $2 — no fly-off, no hazard fail particles.
		if is_instance_valid(body):
			body.start_destroyed_process()
		return

	## Blow away, then explode in the distance (still no strike / no fail particles).
	var impulse_dir = fly_away_from_player()
	body.apply_central_impulse(impulse_dir)
	await get_tree().create_timer(randf_range(1.6, 2.0), false).timeout
	if is_instance_valid(body):
		body.start_destroyed_process()


func fly_away_from_player() -> Vector3:
	var strength : float = [4.0].pick_random()
	
	var player := get_tree().get_first_node_in_group('Player')

	var dir : Vector3= self.global_position - player.global_position.normalized()
	dir = dir * 2
	#dir.y /= 3
	#apply_central_impulse(dir * strength)
	var _direction = dir * strength
	return _direction
	
func expand_blast_radius() -> void:
	#return
	_blast_destroy_stagger_index = 0
	_set_invisible_explosion_hidden(false)
	%explosion_radius_mesh.show()
	%explosion_radius_mesh.transparency = 0.2
	#%explosion_radius_mesh.transparency = 1.0
	var blast_node : Area3D = %Explosion_area
	blast_node.scale = Vector3.ONE
	blast_node.show()
	blast_node.monitoring = true
	$Explosion_area/CollisionShape3D.disabled = false
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.1)
	tween.tween_property(blast_node, "scale", Vector3.ONE * BLAST_DOMAIN_EXPANSION, 0.25)
	tween.parallel().tween_property(%explosion_radius_mesh, "transparency", 1.0, 0.45)
	tween.parallel().tween_property($Explosion_area/CollisionShape3D, "disabled", true, 0.01).set_delay(0.3)
	#tween.tween_interval(0.1)
	await tween.finished
	$Explosion_area/CollisionShape3D.disabled = true
	blast_node.scale = Vector3.ONE

	blast_node.hide()
	blast_node.monitoring = false



#func check_position_for_wall() -> void:
	#var bottom_y := -3.0
	#match exit_side:
		#ExitSide.LEFT:
			#
			#if global_position.x > 15.5 || global_position.y <= bottom_y:
				#hit_out_of_bounds()
			##if global_position.x > -18.5:
				##hit_out_of_bounds()
#
		#ExitSide.RIGHT:
			#if global_position.x < -15.5 || global_position.y <= bottom_y:
				#hit_out_of_bounds()
			##if global_position.x > 15.5:
				##hit_out_of_bounds()
#
		#ExitSide.TOP:
			#if global_position.y > 9.0 || global_position.y <= bottom_y:
				#hit_out_of_bounds()
				#
		#
#
#func start_timer() -> void:
	#$hit_wall_timer.start()
#
#func _on_hit_wall_timer_timeout() -> void:
	#check_position_for_wall()
	#if is_deactivated:
		#$hit_wall_timer.stop()
		#return
		#
	#else:
		#$hit_wall_timer.start()
