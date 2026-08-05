class_name BallisticAim
extends RefCounted

## Gravity scale used during aimed launches — must match what the rigid body uses in flight.
const LAUNCH_GRAVITY_SCALE := 0.15


static func gravity_accel(gravity_scale: float = LAUNCH_GRAVITY_SCALE) -> float:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	return g * maxf(gravity_scale, 0.001)


## Initial velocity so the body passes through `to_pos` at time `flight_time`.
## When `flight_time` <= 0 and `to_pos` is above `from_pos`, uses apex-at-target time plus
## `extra_flight_time` (slower arc, still passes through the aim cell).
static func velocity_to_point(
	from_pos: Vector3,
	to_pos: Vector3,
	flight_time: float = -1.0,
	gravity_scale: float = LAUNCH_GRAVITY_SCALE,
	extra_flight_time: float = 0.0
) -> Vector3:
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y
	var dz := to_pos.z - from_pos.z
	var g := gravity_accel(gravity_scale)
	var hang := maxf(extra_flight_time, 0.0)

	var t := flight_time
	if t <= 0.0:
		if dy > 0.01:
			t = sqrt(2.0 * dy / g) + hang
		else:
			var dist := sqrt(dx * dx + dy * dy + dz * dz)
			t = maxf(0.35, dist / 15.0) + hang

	if t < 0.001:
		t = 0.35

	var vx := dx / t
	var vz := dz / t
	var vy := (dy + 0.5 * g * t * t) / t
	return Vector3(vx, vy, vz)


static func impulse_to_point(
	body: RigidBody3D,
	from_pos: Vector3,
	to_pos: Vector3,
	flight_time: float = -1.0,
	gravity_scale: float = LAUNCH_GRAVITY_SCALE,
	impulse_scale: float = 1.0,
	extra_flight_time: float = 0.0
) -> Vector3:
	var mass := maxf(body.mass, 0.001)
	return velocity_to_point(from_pos, to_pos, flight_time, gravity_scale, extra_flight_time) * mass * impulse_scale


static func configure_body_for_ballistic_launch(
	body: RigidBody3D,
	gravity_scale: float = LAUNCH_GRAVITY_SCALE
) -> void:
	body.linear_damp = 0.0
	body.gravity_scale = gravity_scale
	body.constant_force = Vector3.ZERO
