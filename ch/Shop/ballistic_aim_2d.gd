class_name BallisticAim2D
extends RefCounted
## 2D ballistic solve for ShopMiniGame (Y+ down, matching Godot 2D gravity).

static func gravity_accel(gravity_scale: float) -> float:
	var g := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	return g * maxf(gravity_scale, 0.001)


## Initial velocity so the body passes through `to_pos` at time `flight_time`.
## When `flight_time` <= 0 and `to_pos` is above `from_pos`, uses apex-at-target time plus
## `extra_flight_time` (slower arc, still passes through the aim cell).
static func velocity_to_point(
	from_pos: Vector2,
	to_pos: Vector2,
	flight_time: float = -1.0,
	gravity_scale: float = 0.35,
	extra_flight_time: float = 0.0
) -> Vector2:
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y
	var g := gravity_accel(gravity_scale)
	var hang := maxf(extra_flight_time, 0.0)

	var t := flight_time
	if t <= 0.0:
		# Aiming upward (smaller Y): apex at target when t = sqrt(-2*dy/g).
		if dy < -0.01:
			t = sqrt(-2.0 * dy / g) + hang
		else:
			var dist := from_pos.distance_to(to_pos)
			t = maxf(0.35, dist / 400.0) + hang

	if t < 0.001:
		t = 0.35

	var vx := dx / t
	# y = y0 + vy*t + 0.5*g*t^2  (Y+ down)
	var vy := (dy - 0.5 * g * t * t) / t
	return Vector2(vx, vy)


static func impulse_to_point(
	body: RigidBody2D,
	from_pos: Vector2,
	to_pos: Vector2,
	flight_time: float = -1.0,
	gravity_scale: float = 0.35,
	impulse_scale: float = 1.0,
	extra_flight_time: float = 0.0
) -> Vector2:
	var mass := maxf(body.mass, 0.001)
	return velocity_to_point(from_pos, to_pos, flight_time, gravity_scale, extra_flight_time) * mass * impulse_scale
