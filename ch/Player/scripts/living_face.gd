@tool
extends Control
## Procedural living face at the crosshair center. Geometry only — no sprites.
## Driven by a CrosshairPersonality Resource (Happy v1).

const CrosshairPersonalityScript = preload("res://ch/Player/scripts/crosshair_personality.gd")

enum FaceExpression {
	IDLE,
	HAPPY,
	EXCITED,
	SCARED,
	HURT,
	SAD,
	ANGRY,
	DEAD,
}

@export_group("Personality")
@export var personality: Resource:
	set(value):
		personality = value
		_apply_personality_defaults()
		queue_redraw()

@export_group("Layout")
@export_range(0.25, 3.0, 0.05) var face_scale := 1.0:
	set(value):
		face_scale = value
		queue_redraw()
@export var face_offset := Vector2.ZERO:
	set(value):
		face_offset = value
		queue_redraw()
@export_range(0.0, 1.0, 0.05) var face_alpha := 0.92:
	set(value):
		face_alpha = value
		queue_redraw()
## Keep the exact aim point clear (pixels at local scale).
@export_range(0.0, 8.0, 0.5) var aim_dead_zone_px := 2.5

@export_group("Preview")
@export var preview_expression: FaceExpression = FaceExpression.IDLE:
	set(value):
		preview_expression = value
		if Engine.is_editor_hint():
			_set_expression(value, true)
			queue_redraw()

var _time := 0.0
var _expression: FaceExpression = FaceExpression.IDLE
var _flash_token := 0
var _look_offset := Vector2.ZERO
var _wander_offset := Vector2.ZERO
var _squash := Vector2.ONE
var _params := {}
var _target_params := {}
var _mouth_pts: PackedVector2Array = PackedVector2Array()
var _look_target: Node3D = null
var _look_acquire_msec := 0
var _look_poll_accum := 0.0
var _shot_times: Array[float] = []
var _blink_left := 1.0
var _blink_right := 1.0
var _blink_left_timer := 0.0
var _blink_right_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	#pivot_offset = size * 0.5
	if personality == null:
		personality = CrosshairPersonalityScript.new()
	_apply_personality_defaults()
	_set_expression(FaceExpression.IDLE, true)
	_schedule_blinks()
	if not Engine.is_editor_hint():
		_connect_game_signals()
	queue_redraw()
	set_process(true)


func _apply_personality_defaults() -> void:
	if personality == null:
		return
	face_scale = float(personality.face_scale)


func _process(delta: float) -> void:
	_time += delta
	_update_blinks(delta)
	_update_params_lerp(delta)
	_update_squash(delta)
	if Engine.is_editor_hint():
		_look_offset = _look_offset.lerp(Vector2.ZERO, delta * 2.0)
	else:
		_update_fire_rate_window()
		_update_look(delta)
		_refresh_low_health_baseline()
	queue_redraw()


func _draw() -> void:
	var p = personality
	if p == null:
		return
	var center: Vector2 = size * 0.5 + face_offset
	var s: float = face_scale
	var col: Color = p.line_color
	col.a *= face_alpha * float(_params.get("alpha", 1.0))
	var width: float = float(p.line_width) * s * float(_params.get("line_mul", 1.0))

	var amp: float = float(p.idle_amplitude) * float(_params.get("amp_mul", 1.0))
	var breath: float = 1.0 + sin(_time * float(p.idle_frequency)) * float(p.breathing_amount) * 0.04
	var left_bob: float = sin(_time * float(p.idle_frequency) + float(p.left_eye_phase)) * amp
	var right_bob: float = sin(_time * float(p.idle_frequency) * 1.07 + float(p.right_eye_phase)) * amp
	var mouth_bob: float = sin(_time * float(p.mouth_frequency) + float(p.mouth_phase)) * float(p.mouth_amplitude) * float(_params.get("mouth_amp_mul", 1.0))

	var look: Vector2 = (_look_offset + _wander_offset) * s
	var eye_open_l: float = float(_params.get("eye_open", 1.0)) * _blink_left
	var eye_open_r: float = float(_params.get("eye_open", 1.0)) * _blink_right
	var eye_narrow: float = float(_params.get("eye_narrow", 0.0))

	var eye_y: float = float(p.eye_height) * s
	var left_pos: Vector2 = center + Vector2(-float(p.eye_spacing) * 0.5 * s, eye_y + float(p.eye_y_asymmetry) * s + left_bob) + look
	var right_pos: Vector2 = center + Vector2(float(p.eye_spacing) * 0.5 * s, eye_y - float(p.eye_y_asymmetry) * 0.35 * s + right_bob) + look * 0.92

	# Keep aim hole clear — pull features slightly away from exact center if needed.
	left_pos = _away_from_dead_zone(left_pos, center)
	right_pos = _away_from_dead_zone(right_pos, center)

	var squash_center: Vector2 = center
	draw_set_transform(squash_center, 0.0, _squash)
	var draw_origin: Vector2 = -squash_center

	_draw_eye(left_pos + draw_origin, float(p.eye_size_left) * s * breath, eye_open_l, eye_narrow, col, width)
	_draw_eye(right_pos + draw_origin, float(p.eye_size_right) * s * breath, eye_open_r, eye_narrow, col, width)

	if bool(p.draw_brows):
		var brow_ang: float = deg_to_rad(float(p.brow_angle_deg) + float(_params.get("brow_angle", 0.0)))
		_draw_brow(left_pos + draw_origin + Vector2(0, -float(p.eye_size_left) * s * 1.6), float(p.eye_size_left) * s * 1.8, -brow_ang, col, width)
		_draw_brow(right_pos + draw_origin + Vector2(0, -float(p.eye_size_right) * s * 1.6), float(p.eye_size_right) * s * 1.8, brow_ang, col, width)

	var mouth_curve: float = float(p.mouth_curvature) * float(_params.get("mouth_curve", 1.0))
	var mouth_w: float = float(p.mouth_width) * s * float(_params.get("mouth_width_mul", 1.0))
	var mouth_h: float = float(p.mouth_height) * s * absf(mouth_curve)
	var mouth_pos: Vector2 = center + Vector2(0.0, float(p.mouth_y) * s + mouth_bob) + look * 0.15
	mouth_pos = _away_from_dead_zone(mouth_pos, center, 1.2)
	_draw_mouth(mouth_pos + draw_origin, mouth_w, mouth_h, mouth_curve, col, width)

	if bool(p.draw_cheeks) and float(_params.get("cheeks", 0.0)) > 0.01:
		var cheek_a: Color = col
		cheek_a.a *= 0.35 * float(_params.get("cheeks", 0.0))
		var cr: float = 0.7 * s
		draw_arc(left_pos + draw_origin + Vector2(-1.2 * s, 1.8 * s), cr, 0.2, PI - 0.2, 8, cheek_a, width * 0.7, true)
		draw_arc(right_pos + draw_origin + Vector2(1.2 * s, 1.8 * s), cr, 0.2, PI - 0.2, 8, cheek_a, width * 0.7, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _away_from_dead_zone(pos: Vector2, center: Vector2, mul: float = 1.0) -> Vector2:
	var d := pos - center
	var min_d := aim_dead_zone_px * mul
	if d.length() < min_d and d.length() > 0.001:
		return center + d.normalized() * min_d
	if d.length() <= 0.001:
		return center + Vector2(0, min_d)
	return pos


func _draw_eye(pos: Vector2, radius: float, open_amount: float, narrow: float, color: Color, width: float) -> void:
	var ry := maxf(radius * clampf(open_amount, 0.05, 1.0) * (1.0 - narrow * 0.55), 0.15)
	var rx := maxf(radius * (1.0 + narrow * 0.2), 0.2)
	# Soft ellipse via polyline
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps) * TAU
		pts.append(pos + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pts, color, width, true)
	# Tiny pupil hint (keeps center of eye readable without filling aim hole)
	if open_amount > 0.35:
		var pupil := color
		pupil.a *= 0.85
		draw_circle(pos, maxf(rx * 0.22, 0.35), pupil)


func _draw_brow(pos: Vector2, length: float, angle: float, color: Color, width: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var a := pos - dir * length * 0.5
	var b := pos + dir * length * 0.5
	draw_line(a, b, color, width, true)


func _draw_mouth(pos: Vector2, width_px: float, height_px: float, curvature: float, color: Color, line_w: float) -> void:
	var count := 12
	if _mouth_pts.size() != count:
		_mouth_pts.resize(count)
	for i in count:
		var t := float(i) / float(count - 1)
		var x := lerpf(-width_px * 0.5, width_px * 0.5, t)
		# Smile / frown via cosine bowl; curvature > 0 = smile down in screen Y.
		var y := -cos((t - 0.5) * PI) * height_px * 0.5 * curvature
		# Slight asymmetry
		y += sin(t * PI) * 0.15 * signf(curvature)
		_mouth_pts[i] = pos + Vector2(x, y)
	draw_polyline(_mouth_pts, color, line_w, true)


func _params_for(expr: FaceExpression) -> Dictionary:
	match expr:
		FaceExpression.IDLE:
			return {"eye_open": 1.0, "eye_narrow": 0.0, "mouth_curve": 1.0, "mouth_width_mul": 1.0, "mouth_amp_mul": 1.0, "amp_mul": 1.0, "alpha": 1.0, "cheeks": 0.35, "brow_angle": 0.0, "line_mul": 1.0}
		FaceExpression.HAPPY:
			return {"eye_open": 1.05, "eye_narrow": 0.05, "mouth_curve": 1.35, "mouth_width_mul": 1.15, "mouth_amp_mul": 1.2, "amp_mul": 1.15, "alpha": 1.0, "cheeks": 0.85, "brow_angle": -4.0, "line_mul": 1.0}
		FaceExpression.EXCITED:
			return {"eye_open": 1.2, "eye_narrow": 0.0, "mouth_curve": 1.55, "mouth_width_mul": 1.25, "mouth_amp_mul": 1.6, "amp_mul": 1.45, "alpha": 1.0, "cheeks": 1.0, "brow_angle": -8.0, "line_mul": 1.05}
		FaceExpression.SCARED:
			return {"eye_open": 1.35, "eye_narrow": 0.0, "mouth_curve": 0.25, "mouth_width_mul": 0.7, "mouth_amp_mul": 1.8, "amp_mul": 1.6, "alpha": 1.0, "cheeks": 0.1, "brow_angle": 12.0, "line_mul": 1.0}
		FaceExpression.HURT:
			return {"eye_open": 0.45, "eye_narrow": 0.7, "mouth_curve": -0.9, "mouth_width_mul": 0.9, "mouth_amp_mul": 0.5, "amp_mul": 0.4, "alpha": 1.0, "cheeks": 0.2, "brow_angle": 18.0, "line_mul": 1.1}
		FaceExpression.SAD:
			return {"eye_open": 0.85, "eye_narrow": 0.15, "mouth_curve": -0.85, "mouth_width_mul": 0.95, "mouth_amp_mul": 0.55, "amp_mul": 0.55, "alpha": 1.0, "cheeks": 0.15, "brow_angle": 10.0, "line_mul": 1.0}
		FaceExpression.ANGRY:
			return {"eye_open": 0.75, "eye_narrow": 0.45, "mouth_curve": -0.35, "mouth_width_mul": 0.85, "mouth_amp_mul": 0.4, "amp_mul": 0.7, "alpha": 1.0, "cheeks": 0.0, "brow_angle": 28.0, "line_mul": 1.15}
		FaceExpression.DEAD:
			return {"eye_open": 0.2, "eye_narrow": 0.9, "mouth_curve": -0.2, "mouth_width_mul": 1.0, "mouth_amp_mul": 0.0, "amp_mul": 0.0, "alpha": 0.55, "cheeks": 0.0, "brow_angle": 0.0, "line_mul": 0.9}
	return _params_for(FaceExpression.IDLE)


func _set_expression(expr: FaceExpression, instant: bool = false) -> void:
	_expression = expr
	_target_params = _params_for(expr)
	if instant or _params.is_empty():
		_params = _target_params.duplicate()


func _update_params_lerp(delta: float) -> void:
	if _target_params.is_empty():
		return
	var speed: float = 8.0
	if personality:
		speed = float(personality.expression_transition_speed)
	var t := clampf(delta * speed, 0.0, 1.0)
	for k in _target_params.keys():
		var a := float(_params.get(k, _target_params[k]))
		var b := float(_target_params[k])
		_params[k] = lerpf(a, b, t)


func _update_squash(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))


func _schedule_blinks() -> void:
	_blink_left_timer = randf_range(1.8, 4.2)
	_blink_right_timer = _blink_left_timer + randf_range(0.05, 0.35)


func _update_blinks(delta: float) -> void:
	if _expression == FaceExpression.DEAD:
		_blink_left = 0.15
		_blink_right = 0.15
		return
	_blink_left_timer -= delta
	_blink_right_timer -= delta
	if _blink_left_timer <= 0.0:
		_blink_left = 0.12
		_blink_left_timer = randf_range(2.0, 5.0)
	else:
		_blink_left = lerpf(_blink_left, 1.0, clampf(delta * 14.0, 0.0, 1.0))
	if _blink_right_timer <= 0.0:
		_blink_right = 0.12
		_blink_right_timer = randf_range(2.1, 5.2)
	else:
		_blink_right = lerpf(_blink_right, 1.0, clampf(delta * 14.0, 0.0, 1.0))


func _connect_game_signals() -> void:
	var bus := EventBus.instance
	if bus == null:
		return
	if not bus.add_strike.is_connected(_on_damage):
		bus.add_strike.connect(_on_damage)
	if not bus.hazard_hit.is_connected(_on_damage):
		bus.hazard_hit.connect(_on_damage)
	if not bus.has_hit_three_strikes.is_connected(_on_three_strikes):
		bus.has_hit_three_strikes.connect(_on_three_strikes)
	if not bus.all_rocks_destroyed.is_connected(_on_perfect):
		bus.all_rocks_destroyed.connect(_on_perfect)
	if not bus.rest_balloon_shot.is_connected(_on_happy_moment):
		bus.rest_balloon_shot.connect(_on_happy_moment)
	elif not bus.checkpoint_shot.is_connected(_on_happy_moment):
		bus.checkpoint_shot.connect(_on_happy_moment)
	if not bus.next_round.is_connected(_on_round_reset):
		bus.next_round.connect(_on_round_reset)
	if not bus.level_restarted.is_connected(_on_round_reset):
		bus.level_restarted.connect(_on_round_reset)
	if not bus.open_shop.is_connected(_on_round_reset):
		bus.open_shop.connect(_on_round_reset)


## Called from Player_Crosshair.crosshair_shake().
func notify_shot() -> void:
	if Engine.is_editor_hint():
		return
	if _expression == FaceExpression.DEAD:
		return
	_shot_times.append(_time)
	var excited_thresh: float = float(personality.excited_shots_per_sec) if personality else 6.0
	var hold: float = float(personality.shoot_hold_sec) if personality else 0.14
	var squash: float = float(personality.shoot_squash) if personality else 0.12
	_squash = Vector2(1.0 + squash * 0.35, 1.0 - squash)
	_flash(FaceExpression.EXCITED if _shots_per_sec() >= excited_thresh else FaceExpression.HAPPY, hold)


func _on_damage() -> void:
	if _expression == FaceExpression.DEAD:
		return
	_refresh_low_health_baseline()
	if _is_low_health():
		_set_expression(FaceExpression.SAD)
		_squash = Vector2(1.08, 0.9)
		return
	var hold: float = float(personality.hurt_hold_sec) if personality else 0.4
	_squash = Vector2(1.1, 0.88)
	_flash(FaceExpression.HURT, hold)


func _on_three_strikes() -> void:
	_flash_token += 1
	_set_expression(FaceExpression.DEAD)
	_look_target = null
	_look_offset = Vector2.ZERO


func _on_perfect() -> void:
	if _expression == FaceExpression.DEAD:
		return
	var hold: float = float(personality.happy_hold_sec) if personality else 0.85
	_flash(FaceExpression.HAPPY, hold)


func _on_happy_moment() -> void:
	if _expression == FaceExpression.DEAD or _is_low_health():
		return
	var hold: float = (float(personality.happy_hold_sec) if personality else 0.85) * 0.75
	_flash(FaceExpression.HAPPY, hold)


func _on_round_reset() -> void:
	_flash_token += 1
	_look_target = null
	_look_offset = Vector2.ZERO
	_shot_times.clear()
	_set_expression(FaceExpression.SAD if _is_low_health() else FaceExpression.IDLE)


func _flash(expr: FaceExpression, hold_sec: float) -> void:
	_flash_token += 1
	var token := _flash_token
	_set_expression(expr)
	await get_tree().create_timer(hold_sec, false).timeout
	if token != _flash_token:
		return
	if _expression == FaceExpression.DEAD:
		return
	_set_expression(FaceExpression.SAD if _is_low_health() else FaceExpression.IDLE)


func _is_low_health() -> bool:
	if Engine.is_editor_hint() or gl_PlayerState == null:
		return false
	var strikes := int(gl_PlayerState.dataset.get("total_current_strikes", 0))
	var max_strikes := 3
	if gl_PlayerState.has_method("get_max_strikes"):
		max_strikes = gl_PlayerState.get_max_strikes()
	var remain := maxi(max_strikes - strikes, 0)
	var threshold: int = int(personality.low_health_strikes_remaining) if personality else 1
	return remain <= threshold and strikes > 0


func _refresh_low_health_baseline() -> void:
	if _expression == FaceExpression.DEAD:
		return
	if _expression == FaceExpression.HURT or _expression == FaceExpression.HAPPY or _expression == FaceExpression.EXCITED:
		return
	if _is_low_health():
		if _expression != FaceExpression.SAD and _expression != FaceExpression.SCARED:
			_set_expression(FaceExpression.SAD)
	elif _expression == FaceExpression.SAD or _expression == FaceExpression.SCARED:
		_set_expression(FaceExpression.IDLE)


func _update_fire_rate_window() -> void:
	var cutoff := _time - 1.0
	while not _shot_times.is_empty() and _shot_times[0] < cutoff:
		_shot_times.remove_at(0)


func _shots_per_sec() -> float:
	return float(_shot_times.size())


func _update_look(delta: float) -> void:
	var p = personality
	if p == null or not bool(p.eye_look_enabled):
		_look_offset = _look_offset.lerp(Vector2.ZERO, delta * 3.0)
		return

	_look_poll_accum += delta
	var interval: float = 1.0 / maxf(float(p.look_poll_hz), 1.0)
	if _look_poll_accum >= interval:
		_look_poll_accum = 0.0
		_poll_look_target()

	var desired := Vector2.ZERO
	if is_instance_valid(_look_target):
		desired = _screen_look_offset_toward(_look_target)
	else:
		# Rare idle wander
		desired = Vector2(
			sin(_time * float(p.eye_wander_frequency)) * float(p.eye_wander_amount),
			cos(_time * float(p.eye_wander_frequency) * 0.73 + 1.2) * float(p.eye_wander_amount) * 0.55
		)

	_look_offset = _look_offset.lerp(desired, clampf(delta * float(p.eye_look_speed), 0.0, 1.0))
	_wander_offset = _wander_offset.lerp(Vector2.ZERO, delta * 2.0)


func _poll_look_target() -> void:
	var p = personality
	if p == null:
		return
	var now := Time.get_ticks_msec()
	var persist: float = float(p.eye_look_persist_sec)
	if is_instance_valid(_look_target):
		var keep := true
		if not _look_target is RockInstance:
			keep = false
		elif (_look_target as RockInstance).current_state != RockInstance.State.ACTIVE:
			keep = false
		elif (now - _look_acquire_msec) * 0.001 > persist + 0.75:
			# Allow retarget after persist window if something closer exists
			pass
		else:
			return
		if keep and (now - _look_acquire_msec) * 0.001 < persist:
			return
		if not keep:
			_look_target = null

	var next := _find_interesting_rock()
	if next != null:
		_look_target = next
		_look_acquire_msec = now


func _find_interesting_rock() -> Node3D:
	var p = personality
	if p == null:
		return null
	var weapon := _find_weapon()
	var cam := _find_camera()
	var aim := _crosshair_aim_center()
	var best: Node3D = null
	var best_score := INF
	var look_radius: float = float(p.eye_look_radius_px)

	var candidates: Array = []
	if weapon != null and weapon.has_method("get_targets_in_scope"):
		var hits: Array = weapon.get_targets_in_scope(aim, look_radius, false)
		for hit in hits:
			if hit is Dictionary and hit.has("target"):
				candidates.append(hit["target"])
	if candidates.is_empty() and get_tree():
		for node in get_tree().get_nodes_in_group("Target"):
			candidates.append(node)

	for node in candidates:
		if node == null or not is_instance_valid(node):
			continue
		if not (node is RockInstance):
			continue
		var rock := node as RockInstance
		if rock.current_state != RockInstance.State.ACTIVE or not rock.visible:
			continue
		# Prefer shootable yellows over pure hazards for "interesting"
		var name_s := String(rock.rock_type_name)
		if name_s.contains("hazard") and not name_s.contains("stay"):
			continue
		var world_pos: Vector3 = rock.global_position
		if rock.has_method("get_aim_global_position"):
			world_pos = rock.get_aim_global_position()
		if cam and cam.is_position_behind(world_pos):
			continue
		var screen: Vector2 = cam.unproject_position(world_pos) if cam else Vector2.ZERO
		var dist := screen.distance_to(aim)
		if dist > look_radius:
			continue
		if dist < best_score:
			best_score = dist
			best = rock
	return best


func _screen_look_offset_toward(target: Node3D) -> Vector2:
	var p = personality
	var cam := _find_camera()
	if p == null or cam == null or not is_instance_valid(target):
		return Vector2.ZERO
	var world_pos: Vector3 = target.global_position
	if target.has_method("get_aim_global_position"):
		world_pos = target.get_aim_global_position()
	if cam.is_position_behind(world_pos):
		return Vector2.ZERO
	var screen: Vector2 = cam.unproject_position(world_pos)
	var aim := _crosshair_aim_center()
	var dir := screen - aim
	if dir.length() < 0.001:
		return Vector2.ZERO
	var offset: Vector2 = dir.normalized() * float(p.eye_look_strength)
	var look_max: float = float(p.eye_look_max)
	if offset.length() > look_max:
		offset = offset.limit_length(look_max)
	return offset

func _crosshair_aim_center() -> Vector2:
	# Rossy is centered on the Crosshair Control; aim is Control center.
	return global_position + size * 0.5


func _find_weapon() -> Node:
	var player := get_tree().get_first_node_in_group("Player") if get_tree() else null
	if player and player.get("weapon_shooting") != null:
		return player.weapon_shooting
	return null


func _find_camera() -> Camera3D:
	var player := get_tree().get_first_node_in_group("Player") if get_tree() else null
	if player and player.get("camera_3d") is Camera3D:
		return player.camera_3d
	if get_viewport():
		return get_viewport().get_camera_3d()
	return null
