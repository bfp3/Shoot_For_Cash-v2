class_name ShopMiniRock
extends RigidBody2D
## Outline rock for the shop mini-game. Pulsed upward, then falls behind the wall.

enum RockKind { BASIC, BLACK, RED }

@export var outline_color := Color(0.95, 0.82, 0.12, 1.0)
@export var black_color := Color(0.08, 0.08, 0.08, 1.0)
@export var red_color := Color(0.78, 0.02, 0.02, 1.0)
@export var outline_width := 2.0

@export_group("Trail")
@export var trail_enabled := true
@export var trail_length := 10
@export var trail_width := 2.0
@export var trail_color := Color(1, 1, 1, 0.35)

@export_group("Red Rock")
@export var red_hits_to_destroy := 3
@export var red_hit_bounce_force := 280.0
@export var red_hit_torque := 180.0

var kind: RockKind = RockKind.BASIC
var radius := 18.0
var outline_points: PackedVector2Array = PackedVector2Array()
var pulsed := false
var hit := false
var hits_remaining := 1
var _trail: Line2D
var _world_history: PackedVector2Array = PackedVector2Array()


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
	linear_damp = 0.0
	angular_damp = 0.35
	lock_rotation = false
	contact_monitor = false
	_ensure_collision()
	_ensure_trail()
	queue_redraw()


func _ensure_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.9
	shape_node.shape = circle


func _ensure_trail() -> void:
	_trail = get_node_or_null("Trail") as Line2D
	if _trail == null:
		_trail = Line2D.new()
		_trail.name = "Trail"
		_trail.z_index = -1
		_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_trail)
	_trail.width = trail_width
	_trail.default_color = trail_color
	_trail.clear_points()
	_trail.visible = trail_enabled


func get_draw_color() -> Color:
	match kind:
		RockKind.BLACK:
			return black_color
		RockKind.RED:
			return red_color
		_:
			return outline_color


func pulse(upward_impulse: float, x_impulse: float, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	apply_central_impulse(Vector2(x_impulse, -upward_impulse) * mass)
	apply_torque_impulse(torque_impulse * mass)


## Returns true when the rock is fully destroyed by this hit.
func apply_shot(hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if hit:
		return false
	hits_remaining -= 1
	if kind == RockKind.RED and hits_remaining > 0:
		var dir := hit_dir
		if dir.length_squared() < 0.001:
			dir = Vector2(randf_range(-1.0, 1.0), -1.0).normalized()
		else:
			dir = dir.normalized()
		apply_central_impulse(dir * red_hit_bounce_force * mass)
		apply_torque_impulse(randf_range(-red_hit_torque, red_hit_torque) * mass)
		queue_redraw()
		return false
	hit = true
	freeze = true
	hide()
	if _trail:
		_trail.hide()
	return true


func mark_destroyed() -> void:
	hit = true
	freeze = true
	hide()
	if _trail:
		_trail.hide()


func _physics_process(_delta: float) -> void:
	if not trail_enabled or hit or not pulsed or _trail == null:
		return
	_update_trail_from_history()


func _update_trail_from_history() -> void:
	_world_history.insert(0, global_position)
	while _world_history.size() > trail_length:
		_world_history.remove_at(_world_history.size() - 1)
	_trail.clear_points()
	var xf := global_transform.affine_inverse()
	for p in _world_history:
		_trail.add_point(xf * p)
	_trail.width = trail_width
	_trail.default_color = trail_color


func _draw() -> void:
	if outline_points.size() < 2:
		return
	draw_polyline(outline_points, get_draw_color(), outline_width, true)
	# Red rocks show remaining hits as tiny ticks.
	if kind == RockKind.RED and hits_remaining > 0 and not hit:
		for i in hits_remaining:
			var a := -0.4 + float(i) * 0.4
			draw_circle(Vector2(a * radius * 0.35, -radius * 0.15), 2.0, red_color)
