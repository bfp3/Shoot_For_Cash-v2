class_name ShopMiniRock
extends RigidBody2D
## Outline rock for the shop mini-game. Pulsed upward, then falls behind the wall.

enum RockKind { BASIC, BLACK, RED, AVOIDER, CHASER }

@export var outline_color := Color(0.95, 0.82, 0.12, 1.0)
@export var fill_color := Color(0.95, 0.826, 0.123, 1.0)  # for BASIC
@export var black_color := Color(0.08, 0.08, 0.08, 1.0)
@export var black_fill_color := Color(0.05, 0.05, 0.05, 1.0)
@export var red_color := Color(0.5, 0.5, 0.5, 1.0)
@export var red_fill_color := Color(0.78, 0.78, 0.78, 0.686)
@export var avoider_color := Color(1.0, 0.25, 0.18, 1.0)
@export var avoider_fill_color := Color(0.85, 0.12, 0.08, 0.9)
@export var chaser_color := Color(0.25, 0.55, 1.0, 1.0)
@export var chaser_fill_color := Color(0.15, 0.4, 0.95, 0.85)
@export var outline_width := 2.0

@export_group("Physics Material")
@export var physics_material: PhysicsMaterial:
	set(value):
		physics_material = value
		physics_material_override = value

@export_group("Trail")
@export var trail_enabled := true
@export var trail_length := 18
@export var trail_width := 3.0
@export var trail_color := Color(1.0, 0.0, 0.0, 0.55)

@export_group("Red Rock")
@export var red_hits_to_destroy := 3
@export var red_hit_bounce_force := 280.0
@export var red_hit_torque := 180.0

@export_group("Yellow Particles")
@export var yellow_particles_enabled := true
@export_range(1, 64, 1) var yellow_particle_amount := 10
@export var yellow_particle_color := Color(0.95, 0.78, 0.18, 0.85)
@export_range(0.05, 2.0, 0.01) var yellow_particle_lifetime := 0.45
@export_range(10.0, 200.0, 1.0) var yellow_particle_speed := 55.0
@export_range(0.5, 8.0, 0.1) var yellow_particle_scale := 2.5

@export_group("Rock Avoider")
@export var avoider_seek_accel := 900.0
@export var avoider_max_speed := 420.0
@export var avoider_arm_delay_sec := 0.45
@export var avoider_lifetime_sec := 4.0
@export var avoider_explodes_when_hitting_rock := false
@export var avoider_explodes_when_hitting_avoider := false

@export_group("Rock Chaser")
@export var chaser_flee_accel := 900.0
@export var chaser_max_speed := 420.0
@export var chaser_arm_delay_sec := 0.35
@export var chaser_lock_time_sec := 2.0
@export var chaser_bounds_padding := 12.0
@export var chaser_float_gravity := 0.05
@export var chaser_lock_torque := 2200.0

var kind: RockKind = RockKind.BASIC
var radius := 18.0
var outline_points: PackedVector2Array = PackedVector2Array()
var pulsed := false
var hit := false
var hits_remaining := 1
## level-beginner spawn metadata for aimed launches.
var spawn_column := 1
var spawn_entry: Dictionary = {}
var launch_delay_sec := 0.0
var _trail: Line2D
var _world_history: PackedVector2Array = PackedVector2Array()
var _yellow_fx: GPUParticles2D

## Host shop mini-game (provides crosshair / strike / destroy callbacks).
var host: Node = null

var _avoider_armed := false
var _avoider_arm_token := 0
var _avoider_life_token := 0
var _chaser_armed := false
var _chaser_arm_token := 0
var _chaser_lock_progress := 0.0
var _chaser_locked := false
var _chaser_lock_pos := Vector2.ZERO
var _chaser_lock_spin_applied := false


func setup(p_radius: float, points: PackedVector2Array, p_kind: RockKind = RockKind.BASIC) -> void:
	radius = p_radius
	outline_points = points
	kind = p_kind
	_avoider_armed = false
	_chaser_armed = false
	_chaser_lock_progress = 0.0
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	match kind:
		RockKind.BASIC:
			hits_remaining = 1
		RockKind.BLACK:
			hits_remaining = 1
		RockKind.RED:
			hits_remaining = maxi(red_hits_to_destroy, 1)
		RockKind.AVOIDER, RockKind.CHASER:
			hits_remaining = 1
	mass = maxf(0.35, radius / 20.0)
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_damp = 0.5
	angular_damp = 0.1
	lock_rotation = false
	can_sleep = false
	contact_monitor = kind == RockKind.AVOIDER
	max_contacts_reported = 8 if kind == RockKind.AVOIDER else 0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	collision_layer = 1
	collision_mask = 1
	if physics_material:
		physics_material_override = physics_material
	if kind == RockKind.AVOIDER and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_ensure_collision()
	_ensure_trail()
	_ensure_yellow_particles()
	queue_redraw()


func is_clearable_target() -> bool:
	# Avoiders are hazards — they do not gate wave clear.
	return kind != RockKind.AVOIDER


func counts_as_fall_strike() -> bool:
	# Black + avoider falling away is fine; chaser/basic/red miss = strike.
	return kind != RockKind.BLACK and kind != RockKind.AVOIDER


func _ensure_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = radius #* 0.9
	shape_node.shape = circle


func _ensure_trail() -> void:
	_trail = get_node_or_null("Trail") as Line2D
	if _trail == null:
		_trail = Line2D.new()
		_trail.name = "Trail"
		_trail.z_index = 40
		_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_trail)
	# Detach from rock rotation so the trail stays world-stable and visible.
	_trail.top_level = true
	_trail.global_rotation = 0.0
	_trail.width = trail_width
	_trail.default_color = trail_color
	_trail.clear_points()
	_trail.visible = trail_enabled
	_world_history.clear()


func _ensure_yellow_particles() -> void:
	_yellow_fx = get_node_or_null("YellowParticles") as GPUParticles2D
	if kind != RockKind.BASIC or not yellow_particles_enabled:
		if _yellow_fx:
			_yellow_fx.emitting = false
			_yellow_fx.hide()
		return
	if _yellow_fx == null:
		_yellow_fx = GPUParticles2D.new()
		_yellow_fx.name = "YellowParticles"
		_yellow_fx.z_index = -2
		add_child(_yellow_fx)
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = maxf(radius * 0.35, 4.0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = yellow_particle_speed * 0.35
	mat.initial_velocity_max = yellow_particle_speed
	mat.gravity = Vector3(0, 40, 0)
	mat.scale_min = yellow_particle_scale * 0.6
	mat.scale_max = yellow_particle_scale
	mat.color = yellow_particle_color
	_yellow_fx.process_material = mat
	_yellow_fx.amount = yellow_particle_amount
	_yellow_fx.lifetime = yellow_particle_lifetime
	_yellow_fx.explosiveness = 0.0
	_yellow_fx.local_coords = false
	_yellow_fx.emitting = false
	_yellow_fx.show()


func get_draw_color() -> Color:
	match kind:
		RockKind.BLACK:
			return black_color
		RockKind.RED:
			return red_color
		RockKind.AVOIDER:
			return avoider_color
		RockKind.CHASER:
			return chaser_color
		_:
			return outline_color

func get_fill_color() -> Color:
	match kind:
		RockKind.BLACK:
			return black_fill_color
		RockKind.RED:
			return red_fill_color
		RockKind.AVOIDER:
			return avoider_fill_color
		RockKind.CHASER:
			if _chaser_locked:
				return Color(0.45, 0.75, 1.0, 0.95)
			var t := clampf(_chaser_lock_progress / maxf(chaser_lock_time_sec, 0.01), 0.0, 1.0)
			return chaser_fill_color.lerp(Color(0.55, 0.85, 1.0, 0.95), t)
		_:
			return fill_color

func pulse(upward_impulse: float, x_impulse: float, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.12
	apply_central_impulse(Vector2(x_impulse, -upward_impulse) * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))
	if _yellow_fx and kind == RockKind.BASIC and yellow_particles_enabled:
		_yellow_fx.emitting = true
	_on_pulsed()


## Launch with a precomputed 2D velocity (Y+ down), matching BallisticAim2D.
func pulse_ballistic(velocity: Vector2, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_damp = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.12
	apply_central_impulse(velocity * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))
	if _yellow_fx and kind == RockKind.BASIC and yellow_particles_enabled:
		_yellow_fx.emitting = true
	_on_pulsed()


func _on_pulsed() -> void:
	if kind == RockKind.AVOIDER:
		_arm_avoider()
		_start_avoider_lifetime()
		_sync_avoider_exceptions()
	elif kind == RockKind.CHASER:
		_arm_chaser()


## `charged_shot` is true when the scope has been shrunk — required to destroy red rocks.
## Returns true when the rock is fully destroyed by this hit.
func apply_shot(away_from_crosshair: Vector2 = Vector2.ZERO, crosshair_pos: Vector2 = Vector2.ZERO, charged_shot: bool = false) -> bool:
	if hit:
		return false

	# Avoider: any shot / reticle contact is handled as a strike detonation by the host.
	if kind == RockKind.AVOIDER:
		return false

	# Chaser: must finish the lock timer before it can be shot.
	if kind == RockKind.CHASER and not _chaser_locked:
		return false

	linear_velocity = Vector2.ZERO

	# Red rocks only break on a charged (shrunk-scope) shot.
	if kind == RockKind.RED and not charged_shot:
		_bounce_from_shot(away_from_crosshair, crosshair_pos)
		return false

	if kind == RockKind.RED and charged_shot:
		hit = true
		freeze = true
		hide()
		_stop_fx()
		return true

	hits_remaining -= 1
	if hits_remaining > 0:
		_bounce_from_shot(away_from_crosshair, crosshair_pos)
		return false

	hit = true
	freeze = true
	hide()
	_stop_fx()
	return true


func _bounce_from_shot(away_from_crosshair: Vector2, crosshair_pos: Vector2) -> void:
	var dir := away_from_crosshair
	if dir.length_squared() < 0.001:
		dir = Vector2(randf_range(-1.0, 1.0), -1.0).normalized()
	else:
		dir = dir.normalized()

	dir = Vector2.UP / 2.0
	if crosshair_pos.x > 567.0:
		dir.x = -1.3
	else:
		dir.x = 1.3

	apply_central_impulse(dir * red_hit_bounce_force * mass)
	apply_torque_impulse(randf_range(-red_hit_torque, red_hit_torque) * mass * maxf(radius, 1.0))
	angular_velocity += signf(dir.x) * red_hit_torque * 0.08
	queue_redraw()


func mark_destroyed() -> void:
	hit = true
	freeze = true
	hide()
	_stop_fx()
	_avoider_arm_token += 1
	_avoider_life_token += 1
	_chaser_arm_token += 1


func _stop_fx() -> void:
	if _trail:
		_trail.hide()
		_trail.clear_points()
	if _yellow_fx:
		_yellow_fx.emitting = false


func _physics_process(delta: float) -> void:
	if hit or not pulsed:
		return
	if kind == RockKind.AVOIDER:
		_update_avoider(delta)
	elif kind == RockKind.CHASER:
		_update_chaser(delta)
	if not trail_enabled or _trail == null:
		return
	_update_trail_from_history()


func _update_trail_from_history() -> void:
	_world_history.insert(0, global_position)
	while _world_history.size() > trail_length:
		_world_history.remove_at(_world_history.size() - 1)
	_trail.clear_points()
	# World-space trail (top_level, no rotation) — points relative to trail origin at (0,0) global.
	_trail.global_position = Vector2.ZERO
	_trail.global_rotation = 0.0
	for p in _world_history:
		_trail.add_point(p)
	_trail.width = trail_width
	_trail.default_color = trail_color
	_trail.visible = true


func _draw() -> void:
	if outline_points.size() < 2:
		return

	var fill := PackedVector2Array()
	for i in outline_points.size() - 1:
		fill.append(outline_points[i])
	if fill.size() >= 3:
		draw_colored_polygon(fill, get_fill_color())

	if kind == RockKind.BLACK:
		draw_polyline(outline_points, black_color, outline_width, true)
		var arm := radius * 0.45
		draw_line(Vector2(-arm, -arm), Vector2(arm, arm), red_color, 3.0, true)
		draw_line(Vector2(arm, -arm), Vector2(-arm, arm), red_color, 3.0, true)
		return

	if kind == RockKind.CHASER and not _chaser_locked and _chaser_lock_progress > 0.0:
		var t := clampf(_chaser_lock_progress / maxf(chaser_lock_time_sec, 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * t, 24, Color(0.6, 0.85, 1.0, 0.9), 3.0, true)

	draw_polyline(outline_points, get_draw_color(), outline_width, true)


# --- Avoider -----------------------------------------------------------------

func _aim_pos() -> Vector2:
	if host and host.has_method("get_aim_crosshair"):
		return host.get_aim_crosshair()
	return global_position


func _aim_radius() -> float:
	if host and host.has_method("get_aim_radius"):
		return float(host.get_aim_radius())
	return 40.0


func _arm_avoider() -> void:
	_avoider_armed = false
	_avoider_arm_token += 1
	var token := _avoider_arm_token
	await get_tree().create_timer(avoider_arm_delay_sec).timeout
	if token != _avoider_arm_token or hit or kind != RockKind.AVOIDER:
		return
	_avoider_armed = true
	_sync_avoider_exceptions()


func _start_avoider_lifetime() -> void:
	_avoider_life_token += 1
	var token := _avoider_life_token
	await get_tree().create_timer(maxf(avoider_lifetime_sec, 0.1)).timeout
	if token != _avoider_life_token or hit or kind != RockKind.AVOIDER:
		return
	_expire_avoider(false)


func _update_avoider(delta: float) -> void:
	if not _avoider_armed:
		return
	var to_aim := _aim_pos() - global_position
	if to_aim.length_squared() > 0.0001:
		var desired := to_aim.normalized() * avoider_max_speed
		linear_velocity = linear_velocity.move_toward(desired, avoider_seek_accel * delta)

	if global_position.distance_to(_aim_pos()) <= _aim_radius() + radius:
		_expire_avoider(true)


func _expire_avoider(from_crosshair: bool) -> void:
	if hit or kind != RockKind.AVOIDER:
		return
	mark_destroyed()
	if host and host.has_method("on_shop_avoider_finished"):
		host.on_shop_avoider_finished(self, from_crosshair)


func _on_body_entered(body: Node) -> void:
	if kind != RockKind.AVOIDER or hit or not _avoider_armed:
		return
	if body == self or body is not ShopMiniRock:
		return
	var other: ShopMiniRock = body
	if other.hit or not other.pulsed:
		return

	if other.kind == RockKind.AVOIDER:
		if avoider_explodes_when_hitting_avoider:
			other._expire_avoider(false)
			_expire_avoider(false)
		return

	# Blow up the other rock (scored clear via host).
	if host and host.has_method("on_shop_avoider_destroyed_rock"):
		host.on_shop_avoider_destroyed_rock(other)
	else:
		other.mark_destroyed()
	if avoider_explodes_when_hitting_rock:
		_expire_avoider(false)


func _sync_avoider_exceptions() -> void:
	if kind != RockKind.AVOIDER:
		return
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self or child is not ShopMiniRock:
			continue
		var other: ShopMiniRock = child
		if other.kind != RockKind.AVOIDER:
			continue
		if avoider_explodes_when_hitting_avoider:
			remove_collision_exception_with(other)
			other.remove_collision_exception_with(self)
		else:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)


# --- Chaser ------------------------------------------------------------------

func _arm_chaser() -> void:
	_chaser_armed = false
	_chaser_arm_token += 1
	var token := _chaser_arm_token
	await get_tree().create_timer(chaser_arm_delay_sec).timeout
	if token != _chaser_arm_token or hit or kind != RockKind.CHASER:
		return
	_chaser_armed = true
	gravity_scale = chaser_float_gravity
	linear_damp = 0.85
	_clamp_chaser_to_play_bounds(true)


func _update_chaser(delta: float) -> void:
	if not _chaser_armed:
		return

	# Locked = freeze translation, keep spinning so it's clear you can shoot.
	if _chaser_locked:
		linear_velocity = Vector2.ZERO
		global_position = _chaser_lock_pos
		gravity_scale = 0.0
		_update_chaser_lock_progress(delta)
		queue_redraw()
		return

	var bounds := _chaser_play_bounds()
	var away := global_position - _aim_pos()
	var desired := Vector2.ZERO
	if away.length_squared() > 0.0001:
		desired = away.normalized() * chaser_max_speed
	desired = _chaser_steer_inside_bounds(desired, bounds)
	linear_velocity = linear_velocity.move_toward(desired, chaser_flee_accel * delta)
	_clamp_chaser_to_play_bounds(false)
	_update_chaser_lock_progress(delta)
	queue_redraw()


func _update_chaser_lock_progress(delta: float) -> void:
	var in_scope := global_position.distance_to(_aim_pos()) <= _aim_radius() + radius
	if in_scope:
		_chaser_lock_progress = minf(_chaser_lock_progress + delta, chaser_lock_time_sec)
		if not _chaser_locked and _chaser_lock_progress >= chaser_lock_time_sec:
			_begin_chaser_lock()
	else:
		_chaser_lock_progress = 0.0
		if _chaser_locked:
			_end_chaser_lock()


func _begin_chaser_lock() -> void:
	_chaser_locked = true
	_chaser_lock_pos = global_position
	linear_velocity = Vector2.ZERO
	gravity_scale = 0.0
	can_sleep = false
	sleeping = false
	if not _chaser_lock_spin_applied:
		_chaser_lock_spin_applied = true
		var spin_dir := 1.0 if randf() > 0.5 else -1.0
		apply_torque_impulse(spin_dir * chaser_lock_torque)
		angular_velocity = spin_dir * chaser_lock_torque * 0.08


func _end_chaser_lock() -> void:
	_chaser_locked = false
	_chaser_lock_spin_applied = false
	gravity_scale = chaser_float_gravity
	can_sleep = true


func _chaser_play_bounds() -> Rect2:
	if host and host.has_method("get_chaser_play_bounds"):
		var rect: Rect2 = host.get_chaser_play_bounds()
		var pad := chaser_bounds_padding
		return Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad, pad) * 2.0)
	# Fallback: stay on-screen above the wall line.
	return Rect2(Vector2(40, 40), Vector2(720, 400))


func _chaser_steer_inside_bounds(desired: Vector2, bounds: Rect2) -> Vector2:
	var pos := global_position
	var edge := maxf(chaser_bounds_padding * 0.5, 6.0)
	var out := desired
	if pos.x <= bounds.position.x + edge and out.x < 0.0:
		out.x = absf(out.x)
	elif pos.x >= bounds.end.x - edge and out.x > 0.0:
		out.x = -absf(out.x)
	if pos.y <= bounds.position.y + edge and out.y < 0.0:
		out.y = absf(out.y)
	elif pos.y >= bounds.end.y - edge and out.y > 0.0:
		out.y = -absf(out.y)
	if out.length_squared() < 0.0001:
		out = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * chaser_max_speed * 0.5
	return out


func _clamp_chaser_to_play_bounds(force_center_if_outside: bool) -> void:
	var bounds := _chaser_play_bounds()
	var pos := global_position
	var was_out := not bounds.has_point(pos)
	pos.x = clampf(pos.x, bounds.position.x, bounds.end.x)
	pos.y = clampf(pos.y, bounds.position.y, bounds.end.y)
	if force_center_if_outside and was_out:
		pos = bounds.get_center()
	global_position = pos
	if is_equal_approx(pos.x, bounds.position.x) and linear_velocity.x < 0.0:
		linear_velocity.x = 0.0
	elif is_equal_approx(pos.x, bounds.end.x) and linear_velocity.x > 0.0:
		linear_velocity.x = 0.0
	if is_equal_approx(pos.y, bounds.position.y) and linear_velocity.y < 0.0:
		linear_velocity.y = 0.0
	elif is_equal_approx(pos.y, bounds.end.y) and linear_velocity.y > 0.0:
		linear_velocity.y = 0.0
