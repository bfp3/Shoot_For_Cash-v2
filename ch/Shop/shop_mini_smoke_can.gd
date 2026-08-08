class_name ShopMiniSmokeCan
extends RigidBody2D
## Smoke can obstacle. Climbs, flashes at apex for 2s, then explodes with smoke.
## Shot cans clear without smoking (matches 3D rock_instance SMOKECAN).

signal smoked(can: ShopMiniSmokeCan, pos: Vector2)
signal destroyed(can: ShopMiniSmokeCan, pos: Vector2)
signal exploded(can: ShopMiniSmokeCan, pos: Vector2)
signal apex_tick(can: ShopMiniSmokeCan)

enum Phase { IDLE, RISING, FLASHING, DONE }

@export var body_color := Color(0.35, 0.38, 0.42, 1.0)
@export var rim_color := Color(0.08, 0.09, 0.11, 1.0)
@export var stripe_color := Color(0.78, 0.55, 0.12, 1.0)
@export var flash_color := Color(1.0, 0.35, 0.12, 1.0)
## Total warning blink time at apex before the smoke explosion.
@export_range(0.5, 5.0, 0.05) var flash_duration := 2.0
@export_range(0.04, 0.4, 0.01) var flash_blink_interval := 0.1

var radius := 14.0
var pulsed := false
var hit := false
var smoke_triggered := false
## True when the player shot this can — no smoke on destroy.
var shot_by_player := false
var spawn_column := 1
var spawn_entry: Dictionary = {}
var launch_delay_sec := 0.0

var _phase: Phase = Phase.IDLE
var _was_rising := false
var _flash_elapsed := 0.0
var _blink_on := false
var _base_modulate := Color.WHITE


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
	shot_by_player = false
	_phase = Phase.IDLE
	_was_rising = false
	_flash_elapsed = 0.0
	_blink_on = false
	modulate = _base_modulate
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
	_phase = Phase.RISING
	_was_rising = false
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.1
	apply_central_impulse(Vector2(x_impulse, -upward_impulse) * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))


func pulse_ballistic(velocity: Vector2, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	_phase = Phase.RISING
	_was_rising = false
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_damp = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.1
	apply_central_impulse(velocity * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))


func _physics_process(delta: float) -> void:
	if hit or shot_by_player or _phase == Phase.IDLE or _phase == Phase.DONE:
		return

	if _phase == Phase.RISING:
		# Godot 2D: up is negative Y.
		if linear_velocity.y < -8.0:
			_was_rising = true
		if _was_rising and linear_velocity.y >= -2.0:
			_begin_apex_flash()
		return

	if _phase == Phase.FLASHING:
		_flash_elapsed += delta
		var blink_step := int(_flash_elapsed / maxf(flash_blink_interval, 0.01))
		var on := (blink_step % 2) == 0
		if on != _blink_on:
			_blink_on = on
			modulate = flash_color if on else _base_modulate
			queue_redraw()
			if on:
				apex_tick.emit(self)
		if _flash_elapsed >= flash_duration:
			_explode_at_apex()


func _begin_apex_flash() -> void:
	if _phase == Phase.FLASHING or hit:
		return
	_phase = Phase.FLASHING
	_flash_elapsed = 0.0
	_blink_on = true
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	modulate = flash_color
	queue_redraw()
	apex_tick.emit(self)


func _explode_at_apex() -> void:
	if hit or _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	hit = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0
	modulate = _base_modulate
	var pos := position
	trigger_smoke()
	exploded.emit(self, pos)
	hide()


func trigger_smoke() -> void:
	if smoke_triggered or shot_by_player:
		return
	smoke_triggered = true
	smoked.emit(self, position)


## Player shot — clear without releasing smoke (3D SMOKECAN behaviour).
func apply_shot() -> bool:
	if hit:
		return false
	hit = true
	shot_by_player = true
	_phase = Phase.DONE
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0
	modulate = _base_modulate
	var pos := position
	destroyed.emit(self, pos)
	hide()
	return true


func _draw() -> void:
	var h := radius * 1.7
	var w := radius * 1.15
	var rect := Rect2(-w * 0.5, -h * 0.55, w, h)
	var fill := flash_color if (_phase == Phase.FLASHING and _blink_on) else body_color
	draw_rect(rect, fill, true)
	draw_rect(rect, rim_color, false, 2.0)
	# Top lid.
	draw_rect(Rect2(-w * 0.55, -h * 0.62, w * 1.1, h * 0.14), rim_color, true)
	# Warning stripe.
	draw_rect(Rect2(-w * 0.5, -h * 0.05, w, h * 0.22), stripe_color, true)
	draw_line(Vector2(0.0, -h * 0.62), Vector2(0.0, -h * 0.85), rim_color, 2.0, true)
