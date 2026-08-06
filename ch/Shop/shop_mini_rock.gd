extends RigidBody2D
## Outline rock for the shop mini-game. Pulsed upward, then falls behind the wall.

const INK := Color(0.0824, 0.0941, 0.1098, 1.0)

var radius := 18.0
var outline_points: PackedVector2Array = PackedVector2Array()
var pulsed := false
var hit := false


func setup(p_radius: float, points: PackedVector2Array) -> void:
	radius = p_radius
	outline_points = points
	mass = maxf(0.35, radius / 20.0)
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.4
	lock_rotation = false
	contact_monitor = false
	_ensure_collision()
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


func pulse(upward_impulse: float, x_jitter: float, fall_gravity: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	var x_kick := randf_range(-x_jitter, x_jitter)
	apply_central_impulse(Vector2(x_kick, -upward_impulse) * mass)
	apply_torque_impulse(randf_range(-120.0, 120.0) * mass)


func mark_hit() -> void:
	hit = true
	freeze = true
	hide()


func _draw() -> void:
	if outline_points.size() < 2:
		return
	draw_polyline(outline_points, INK, 2.0, true)
