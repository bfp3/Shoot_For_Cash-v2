class_name ShopMiniFruit
extends RigidBody2D
## 2D pineapple / orange / cherry for the shop mini-game.

enum FruitKind { PINEAPPLE, ORANGE, CHERRY }

signal flyaway_finished(fruit: ShopMiniFruit, destroyed: bool)
signal orange_exploded(fruit: ShopMiniFruit, pos: Vector2)

var kind: FruitKind = FruitKind.PINEAPPLE
var radius := 28.0
var pulsed := false
var hit := false
var flying_away := false
var hanging := false
var start_scale := 1.0
var shrink_speed := 0.85
var fly_speed := 180.0
## Screen-local Y the orange should stop and hang at (set by game before pulse).
var hang_apex_y := 120.0

## Pixels per second toward the hang point (higher = faster climb).
var ascent_speed := 900.0
var _center_target := Vector2.ZERO
var _sprite: Sprite2D
var _base_texture_size := Vector2.ONE
var _ascent_tween: Tween
var _apex_bob_time := 0.0
var _sparkles: GPUParticles2D

const ORANGE_APEX_Y := 120.0
const ORANGE_BOB_AMP := 5.5
const ORANGE_BOB_FREQ := 3.2
const ORANGE_SPIN_SPEED := 3.8


func setup(
	p_kind: FruitKind,
	p_radius: float,
	texture: Texture2D,
	p_physics_material: PhysicsMaterial = null
) -> void:
	kind = p_kind
	radius = p_radius
	mass = maxf(0.4, radius / 18.0)
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	linear_damp = 0.35
	angular_damp = 0.12
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	# Oranges never collide with rocks/fruit — only their blast ring interacts.
	if kind == FruitKind.ORANGE:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 1
		collision_mask = 1
	match kind:
		FruitKind.PINEAPPLE:
			modulate = Color("ffd500ff")
		FruitKind.ORANGE:
			modulate = Color("ff7700ff")
		FruitKind.CHERRY:
			modulate = Color("e6283cff")
			linear_damp = 0.05
			angular_damp = 0.04
	if p_physics_material:
		physics_material_override = p_physics_material
	_ensure_collision()
	_ensure_sprite(texture)
	if kind == FruitKind.ORANGE:
		_ensure_sparkles()
	hit = false
	pulsed = false
	flying_away = false
	hanging = false
	_apex_bob_time = 0.0
	show()


func _ensure_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.85
	shape_node.shape = circle
	# Disable shape when orange so it never bumps pillars/fruit/rocks.
	shape_node.disabled = kind == FruitKind.ORANGE


func _ensure_sprite(texture: Texture2D) -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	_sprite.texture = texture
	if texture:
		_base_texture_size = texture.get_size()
		var longest := maxf(_base_texture_size.x, _base_texture_size.y)
		var s := (radius * 2.0) / maxf(longest, 1.0)
		start_scale = s
		_sprite.scale = Vector2.ONE * s
	_sprite.show()


func _ensure_sparkles() -> void:
	_sparkles = get_node_or_null("Sparkles") as GPUParticles2D
	if _sparkles == null:
		_sparkles = GPUParticles2D.new()
		_sparkles.name = "Sparkles"
		add_child(_sparkles)
	_sparkles.emitting = false
	_sparkles.one_shot = false
	_sparkles.amount = 18
	_sparkles.lifetime = 0.55
	_sparkles.explosiveness = 0.15
	_sparkles.local_coords = true
	_sparkles.z_index = 2
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = maxf(radius * 0.35, 4.0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 55.0
	mat.gravity = Vector3(0, 28, 0)
	mat.scale_min = 0.012
	mat.scale_max = 0.028
	mat.color = Color(1.0, 0.92, 0.45, 0.9)
	_sparkles.process_material = mat
	_sparkles.texture = preload("res://res/white_circle_256.png")


func pulse(upward_impulse: float, x_impulse: float, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.1

	if kind == FruitKind.ORANGE:
		# Scripted smooth climb from the wall up to the hang point — no gravity fall.
		gravity_scale = 0.0
		freeze = true
		hanging = false
		if upward_impulse > 1.0:
			ascent_speed = upward_impulse
		_start_orange_ascent(x_impulse)
		return

	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	apply_central_impulse(Vector2(x_impulse, -upward_impulse) * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))


## Angled launch for cherries (degrees from straight up, + = right).
func pulse_angled(speed: float, angle_deg_from_up: float, fall_gravity: float, torque_impulse: float) -> void:
	if pulsed or hit:
		return
	pulsed = true
	freeze = false
	sleeping = false
	gravity_scale = fall_gravity
	linear_velocity = Vector2.ZERO
	angular_velocity = torque_impulse * 0.1
	var rad := deg_to_rad(angle_deg_from_up)
	# Godot 2D: -Y is up.
	var dir := Vector2(sin(rad), -cos(rad)).normalized()
	apply_central_impulse(dir * speed * mass)
	if absf(torque_impulse) > 0.01:
		apply_torque_impulse(torque_impulse * mass * maxf(radius, 1.0))


func _start_orange_ascent(x_impulse: float = 0.0) -> void:
	if _ascent_tween:
		_ascent_tween.kill()
	var target_y := hang_apex_y if hang_apex_y > 1.0 else ORANGE_APEX_Y
	var dist := maxf(position.y - target_y, 1.0)
	var duration := clampf(dist / maxf(ascent_speed, 1.0), 0.12, 2.5)
	# Small horizontal drift from the pulse, then settle.
	var target_x := position.x + clampf(x_impulse * 0.02, -36.0, 36.0)
	_ascent_tween = create_tween().set_parallel(true)
	_ascent_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ascent_tween.tween_property(self, "position:y", target_y, duration)
	_ascent_tween.tween_property(self, "position:x", target_x, duration)
	_ascent_tween.set_parallel(false)
	_ascent_tween.tween_callback(_on_orange_reached_apex)


func _on_orange_reached_apex() -> void:
	if hit:
		return
	position.y = hang_apex_y if hang_apex_y > 1.0 else ORANGE_APEX_Y
	linear_velocity = Vector2.ZERO
	freeze = true
	hanging = true
	_apex_bob_time = 0.0
	if _sparkles:
		_sparkles.restart()
		_sparkles.emitting = true


## Pineapple: fly-into-distance. Orange: explode. Cherry: pop for cash.
## Returns true if the shot was accepted.
func apply_shot(center_target: Vector2) -> bool:
	if hit or flying_away:
		return false

	if kind == FruitKind.ORANGE:
		_explode_orange()
		return true

	if kind == FruitKind.CHERRY:
		_pop_cherry()
		return true

	flying_away = true
	freeze = true
	linear_velocity = Vector2.ZERO
	# Visible tumble while shrinking into the distance.
	angular_velocity = randf_range(10.0, 18.0) * (1.0 if randf() > 0.5 else -1.0)
	collision_layer = 0
	collision_mask = 0
	_center_target = center_target
	return true


## Start pineapple flyaway without awarding via orange explode path.
func begin_flyaway(center_target: Vector2) -> bool:
	if kind != FruitKind.PINEAPPLE:
		return false
	return apply_shot(center_target)


func _explode_orange() -> void:
	if hit:
		return
	if _ascent_tween:
		_ascent_tween.kill()
		_ascent_tween = null
	hit = true
	hanging = false
	flying_away = false
	freeze = true
	linear_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _sparkles:
		_sparkles.emitting = false
	var pos := position
	hide()
	orange_exploded.emit(self, pos)


func _pop_cherry() -> void:
	if hit:
		return
	hit = true
	hanging = false
	flying_away = false
	freeze = true
	linear_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	hide()
	flyaway_finished.emit(self, true)


func _physics_process(delta: float) -> void:
	if hit:
		return

	if hanging and kind == FruitKind.ORANGE:
		_apex_bob_time += delta
		var base_y := hang_apex_y if hang_apex_y > 1.0 else ORANGE_APEX_Y
		position.y = base_y + sin(_apex_bob_time * ORANGE_BOB_FREQ) * ORANGE_BOB_AMP
		rotation += ORANGE_SPIN_SPEED * delta
		return

	if not flying_away:
		return

	var to_center := _center_target - position
	if to_center.length_squared() > 1.0:
		position += to_center.normalized() * fly_speed * delta
	rotation += angular_velocity * delta
	if _sprite:
		var next_scale := _sprite.scale.x - shrink_speed * start_scale * delta
		if next_scale <= start_scale * 0.08:
			_finish_flyaway(true)
			return
		_sprite.scale = Vector2.ONE * next_scale
		radius = maxf(2.0, radius * (next_scale / maxf(start_scale, 0.001)))


func _finish_flyaway(destroyed: bool) -> void:
	if hit:
		return
	hit = true
	flying_away = false
	freeze = true
	hide()
	flyaway_finished.emit(self, destroyed)


func mark_destroyed() -> void:
	if _ascent_tween:
		_ascent_tween.kill()
		_ascent_tween = null
	hit = true
	flying_away = false
	hanging = false
	freeze = true
	if _sparkles:
		_sparkles.emitting = false
	hide()
