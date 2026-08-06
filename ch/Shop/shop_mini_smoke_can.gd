class_name ShopMiniSmokeCan
extends RigidBody2D
## Smoke can that obscures rocks with a particle cloud when launched or shot.

signal smoked(can: ShopMiniSmokeCan, pos: Vector2)
signal destroyed(can: ShopMiniSmokeCan, pos: Vector2)

@export var body_color := Color(0.35, 0.38, 0.42, 1.0)
@export var rim_color := Color(0.08, 0.09, 0.11, 1.0)
@export var stripe_color := Color(0.78, 0.55, 0.12, 1.0)

var radius := 14.0
var pulsed := false
var hit := false
var smoke_triggered := false


func setup(p_radius: float, p_physics_material: PhysicsMaterial = null) -> void:
	radius = p_radius
	mass = maxf(0.4, radius / 16.0)
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_damp = 0.45
	angular_damp = 0.2
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	collision_layer = 1
	collision_mask = 1
	if p_physics_material:
		physics_material_override = p_physics_material
	_ensure_collision()
	hit = false
	pulsed = false
	smoke_triggered = false
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


func pulse(upward_impulse: float, x_impulse: float, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.1
	apply_central_impulse(Vector2(x_impulse, -upward_impulse) * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))
	# Start smoking shortly after launch so the cloud covers in-flight rocks.
	_trigger_smoke_delayed(0.12)


func _trigger_smoke_delayed(delay: float) -> void:
	if smoke_triggered:
		return
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(self) or hit:
		return
	trigger_smoke()


func trigger_smoke() -> void:
	if smoke_triggered:
		return
	smoke_triggered = true
	smoked.emit(self, position)


func apply_shot() -> bool:
	if hit:
		return false
	hit = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0
	var pos := position
	trigger_smoke()
	destroyed.emit(self, pos)
	hide()
	return true


func _draw() -> void:
	var h := radius * 1.7
	var w := radius * 1.15
	var rect := Rect2(-w * 0.5, -h * 0.55, w, h)
	draw_rect(rect, body_color, true)
	draw_rect(rect, rim_color, false, 2.0)
	# Top lid.
	draw_rect(Rect2(-w * 0.55, -h * 0.62, w * 1.1, h * 0.14), rim_color, true)
	# Warning stripe.
	draw_rect(Rect2(-w * 0.5, -h * 0.05, w, h * 0.22), stripe_color, true)
	draw_line(Vector2(0.0, -h * 0.62), Vector2(0.0, -h * 0.85), rim_color, 2.0, true)
