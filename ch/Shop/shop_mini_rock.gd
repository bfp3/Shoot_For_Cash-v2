class_name ShopMiniRock
extends RigidBody2D
## Outline rock for the shop mini-game. Pulsed upward, then falls behind the wall.

enum RockKind { BASIC, BLACK, RED }

@export var outline_color := Color(0.95, 0.82, 0.12, 1.0)
@export var fill_color := Color(0.95, 0.826, 0.123, 1.0)  # for BASIC
@export var black_color := Color(0.08, 0.08, 0.08, 1.0)
@export var black_fill_color := Color(0.05, 0.05, 0.05, 1.0)
@export var red_color := Color(0.5, 0.5, 0.5, 1.0)
@export var red_fill_color := Color(0.78, 0.78, 0.78, 0.686)
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

var kind: RockKind = RockKind.BASIC
var radius := 18.0
var outline_points: PackedVector2Array = PackedVector2Array()
var pulsed := false
var hit := false
var hits_remaining := 1
var _trail: Line2D
var _world_history: PackedVector2Array = PackedVector2Array()
var _yellow_fx: GPUParticles2D


func setup(p_radius: float, points: PackedVector2Array, p_kind: RockKind = RockKind.BASIC) -> void:
	radius = p_radius
	outline_points = points
	kind = p_kind
	match kind:
		RockKind.BASIC:
			hits_remaining = 1
		RockKind.BLACK:
			hits_remaining = 1
		RockKind.RED:
			hits_remaining = maxi(red_hits_to_destroy, 1)
	mass = maxf(0.35, radius / 20.0)
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_damp = 0.5
	angular_damp = 0.1
	lock_rotation = false
	can_sleep = false
	contact_monitor = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	collision_layer = 1
	collision_mask = 1
	if physics_material:
		physics_material_override = physics_material
	_ensure_collision()
	_ensure_trail()
	_ensure_yellow_particles()
	queue_redraw()


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
		_:
			return outline_color

func get_fill_color() -> Color:
	match kind:
		RockKind.BLACK:
			return black_fill_color
		RockKind.RED:
			return red_fill_color
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


## `charged_shot` is true when the scope has been shrunk — required to destroy red rocks.
## Returns true when the rock is fully destroyed by this hit.
func apply_shot(away_from_crosshair: Vector2 = Vector2.ZERO, crosshair_pos: Vector2 = Vector2.ZERO, charged_shot: bool = false) -> bool:
	if hit:
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


func _stop_fx() -> void:
	if _trail:
		_trail.hide()
		_trail.clear_points()
	if _yellow_fx:
		_yellow_fx.emitting = false


func _physics_process(_delta: float) -> void:
	if not trail_enabled or hit or not pulsed or _trail == null:
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

	draw_polyline(outline_points, get_draw_color(), outline_width, true)
