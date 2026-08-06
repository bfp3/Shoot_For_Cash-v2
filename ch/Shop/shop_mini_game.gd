extends Control
## Minimalistic 2D arcade overlay that runs inside the shop panel.
## Toggle with Shift+2 while the shop is open.

const CREAM := Color(0.92156863, 0.8784314, 0.84705883, 1.0)
const BORDER_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const INK := Color(0.0824, 0.0941, 0.1098, 1.0)
const CROSSHAIR_RED := Color(0.78039217, 0.003921569, 0.007843138, 1.0)

const WALL_Y_RATIO := 0.78
const PILLAR_WIDTH_RATIO := 0.045
const PILLAR_INSET_RATIO := 0.12
const CROSSHAIR_RADIUS := 18.0
const PAD := Vector2(28.0, 28.0)
const HEADER_CLEARANCE := 120.0
const ROCK_SCRIPT := preload("res://ch/Shop/shop_mini_rock.gd")

@export_group("Rock Pulse")
## Upward impulse applied when a rock is pulsed (higher = faster launch).
@export_range(50.0, 2000.0, 1.0) var launch_impulse := 450.0
## Gravity scale while falling back down behind the wall (higher = faster fall).
@export_range(0.05, 5.0, 0.01) var fall_gravity_scale := 0.25
## Sideways kick added to each pulse.
@export_range(0.0, 400.0, 1.0) var launch_x_jitter := 55.0
@export_range(1, 10, 1) var rocks_per_wave := 2
@export_range(0.0, 1.0, 0.01) var pulse_stagger := 0.2
@export_range(0.5, 8.0, 0.05) var wave_interval := 2.2
@export_range(0.1, 3.0, 0.05) var mouse_sensitivity := 0.4

var is_open := false
var _crosshair := Vector2.ZERO
var _wave_phase := 0.0
var _wave_timer := 0.0
var _pulsing := false
var _rocks: Array[RigidBody2D] = []
var _shot_flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _follow_panel: Control
var _header_clearance := HEADER_CLEARANCE
var _stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _play_area: Panel = $PlayArea
@onready var _wave_layer: Control = $PlayArea/WaveLayer
@onready var _physics_root: Node2D = $PlayArea/PhysicsRoot
@onready var _overlay: Control = $PlayArea/Overlay


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_setup_play_area_style()
	_wave_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_layer.draw.connect(_draw_waves_layer)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	_overlay.resized.connect(_on_overlay_resized)
	set_process(false)
	set_process_input(false)


func _setup_play_area_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BORDER_WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	_play_area.add_theme_stylebox_override("panel", style)
	_play_area.clip_contents = true


## Parent under the shop root and track the cream panel in screen space.
func attach_to_shop(shop_root: Control, main_panel: Control, header_clearance: float = HEADER_CLEARANCE) -> void:
	_follow_panel = main_panel
	_header_clearance = header_clearance
	if get_parent() != shop_root:
		reparent(shop_root)
	top_level = true
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_to_panel()


func _sync_to_panel() -> void:
	if _follow_panel == null or not is_instance_valid(_follow_panel):
		return
	if not _follow_panel.is_visible_in_tree():
		return
	var panel_rect := _follow_panel.get_global_rect()
	var panel_h := maxf(_follow_panel.size.y, 1.0)
	var header_px := panel_rect.size.y * (_header_clearance / panel_h)
	var pad_x := PAD.x * (panel_rect.size.x / maxf(_follow_panel.size.x, 1.0))
	var pad_y := PAD.y * (panel_rect.size.y / panel_h)
	var top_left := panel_rect.position + Vector2(pad_x, header_px)
	var bottom_right := panel_rect.position + panel_rect.size - Vector2(pad_x, pad_y)
	var next_size := bottom_right - top_left
	if next_size.x < 64.0 or next_size.y < 64.0:
		return
	global_position = top_left
	size = next_size
	# Keep physics space aligned with the inset overlay.
	if _physics_root and _overlay:
		_physics_root.position = _overlay.position


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_stored_mouse_mode = Input.mouse_mode
	_reset_game()
	_sync_to_panel()
	modulate.a = 0.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	_sync_to_panel()
	_center_crosshair()
	_wave_layer.queue_redraw()
	_overlay.queue_redraw()
	_start_wave()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_pulsing = false
	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	if not is_open:
		hide()
		_clear_rocks()
		_shot_flashes.clear()


func _reset_game() -> void:
	_clear_rocks()
	_shot_flashes.clear()
	_wave_timer = 0.0
	_wave_phase = 0.0
	_pulsing = false
	_center_crosshair()


func _clear_rocks() -> void:
	for rock in _rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	_rocks.clear()
	if _physics_root:
		for child in _physics_root.get_children():
			child.queue_free()


func _center_crosshair() -> void:
	var area := _overlay.size
	if area.x <= 1.0 or area.y <= 1.0:
		return
	_crosshair = area * 0.5


func _on_overlay_resized() -> void:
	if is_open:
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_overlay.queue_redraw()
		_wave_layer.queue_redraw()


func _process(delta: float) -> void:
	if not is_open:
		return
	_sync_to_panel()
	_wave_phase += delta * 2.2
	_update_flashes(delta)
	_cleanup_fallen_rocks()

	if not _pulsing and _alive_rock_count() == 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_start_wave()

	_wave_layer.queue_redraw()
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_crosshair += (event as InputEventMouseMotion).relative * mouse_sensitivity
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_shoot()
			get_viewport().set_input_as_handled()


func _start_wave() -> void:
	if _pulsing:
		return
	_pulsing = true
	_prepare_rocks()
	await _pulse_rocks()
	_pulsing = false
	_wave_timer = wave_interval


func _prepare_rocks() -> void:
	_clear_rocks()
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var count := rocks_per_wave
	for i in count:
		var column_t := float(i + 1) / float(count + 1)
		var radius := _rng.randf_range(14.0, 26.0)
		var rock: RigidBody2D = ROCK_SCRIPT.new()
		_physics_root.add_child(rock)
		rock.setup(radius, _make_rock_outline(radius))
		rock.position = Vector2(
			area.x * column_t + _rng.randf_range(-18.0, 18.0),
			wall_y + radius + _rng.randf_range(8.0, 22.0)
		)
		rock.rotation = _rng.randf_range(-0.25, 0.25)
		_rocks.append(rock)


func _pulse_rocks() -> void:
	# Copy in case the array mutates while awaiting.
	var to_pulse: Array[RigidBody2D] = _rocks.duplicate()
	for rock in to_pulse:
		if not is_open:
			return
		if not is_instance_valid(rock) or rock.hit:
			continue
		rock.pulse(launch_impulse, launch_x_jitter, fall_gravity_scale)
		if pulse_stagger > 0.0:
			await get_tree().create_timer(pulse_stagger).timeout


func _make_rock_outline(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := _rng.randi_range(7, 11)
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var bump := _rng.randf_range(0.62, 1.12)
		var jag := 1.0 + 0.08 * sin(angle * 3.0 + _rng.randf() * 2.0)
		pts.append(Vector2(cos(angle), sin(angle)) * radius * bump * jag)
	pts.append(pts[0])
	return pts


func _alive_rock_count() -> int:
	var count := 0
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.hit:
			count += 1
	return count


func _cleanup_fallen_rocks() -> void:
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	var remaining: Array[RigidBody2D] = []
	for rock in _rocks:
		if not is_instance_valid(rock):
			continue
		if rock.hit:
			rock.queue_free()
			continue
		# Despawn once fully back behind the wall after being pulsed.
		if rock.pulsed and rock.position.y > wall_y + rock.radius + 40.0 and rock.linear_velocity.y > 0.0:
			rock.queue_free()
			continue
		# Safety: off the top or far sides.
		if rock.position.y < -80.0 or rock.position.x < -80.0 or rock.position.x > _overlay.size.x + 80.0:
			rock.queue_free()
			continue
		remaining.append(rock)
	_rocks = remaining


func _update_flashes(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for flash in _shot_flashes:
		flash["t"] = float(flash["t"]) - delta
		if float(flash["t"]) > 0.0:
			remaining.append(flash)
	_shot_flashes = remaining


func _try_shoot() -> void:
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	_shot_flashes.append({"pos": _crosshair, "t": 0.12})
	for i in range(_rocks.size() - 1, -1, -1):
		var rock := _rocks[i]
		if not is_instance_valid(rock) or rock.hit:
			continue
		# Only hittable once emerged above the wall.
		if rock.position.y > wall_y:
			continue
		if rock.position.distance_to(_crosshair) <= rock.radius + 10.0:
			var hit_pos := rock.position
			rock.mark_hit()
			rock.queue_free()
			_rocks.remove_at(i)
			_shot_flashes.append({"pos": hit_pos, "t": 0.22, "burst": true})
			break


func _draw_waves_layer() -> void:
	return
	var area := _wave_layer.size
	if area.x < 4.0 or area.y < 4.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var band_top := wall_y - area.y * 0.16
	var band_bottom := wall_y - 2.0
	var line_count := 4
	for i in line_count:
		var t := float(i) / float(maxi(line_count - 1, 1))
		var base_y := lerpf(band_top, band_bottom, t)
		var amp := lerpf(7.0, 3.0, t)
		var pts := PackedVector2Array()
		var steps := 36
		for s in steps + 1:
			var x := area.x * float(s) / float(steps)
			var y := base_y + sin(_wave_phase * (1.0 + t * 0.35) + x * 0.028 + t * 2.0) * amp
			pts.append(Vector2(x, y))
		_wave_layer.draw_polyline(pts, INK, 1.5, true)


func _draw_overlay() -> void:
	var area := _overlay.size
	if area.x < 4.0 or area.y < 4.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	# Cream ground mask so rocks appear to rise/fall behind the wall.
	_overlay.draw_rect(Rect2(0.0, wall_y, area.x, area.y - wall_y + 2.0), CREAM, true)
	_draw_pillars(area, wall_y)
	_draw_wall(area, wall_y)
	_draw_flashes()
	_draw_crosshair(_crosshair)


func _draw_pillars(area: Vector2, wall_y: float) -> void:
	var pillar_w := area.x * PILLAR_WIDTH_RATIO
	var inset := area.x * PILLAR_INSET_RATIO
	var top := area.y * 0.18
	var height := wall_y - top
	_draw_pillar_outline(inset, top, pillar_w, height)
	_draw_pillar_outline(area.x - inset - pillar_w, top, pillar_w, height)


func _draw_pillar_outline(x: float, y: float, w: float, h: float) -> void:
	var pts := PackedVector2Array([
		Vector2(x, y + h),
		Vector2(x, y),
		Vector2(x + w, y),
		Vector2(x + w, y + h),
		Vector2(x, y + h),
	])
	_overlay.draw_polyline(pts, INK, 2.0, true)
	var mid_x := x + w * 0.55
	_overlay.draw_line(Vector2(mid_x, y), Vector2(mid_x, y + h), INK, 1.25, true)
	_overlay.draw_line(Vector2(x - 3.0, y), Vector2(x + w + 3.0, y), INK, 2.0, true)


func _draw_wall(area: Vector2, wall_y: float) -> void:
	_overlay.draw_line(Vector2(0.0, wall_y), Vector2(area.x, wall_y), INK, 2.5, true)


func _draw_flashes() -> void:
	for flash in _shot_flashes:
		var pos: Vector2 = flash["pos"]
		var t := float(flash["t"])
		var alpha := clampf(t / 0.12, 0.0, 1.0)
		var color := Color(CROSSHAIR_RED.r, CROSSHAIR_RED.g, CROSSHAIR_RED.b, alpha)
		if flash.get("burst", false):
			var r := (0.22 - t) * 90.0
			_overlay.draw_arc(pos, maxf(r, 4.0), 0.0, TAU, 18, color, 1.5, true)
		else:
			_overlay.draw_circle(pos, 3.0, color)


func _draw_crosshair(pos: Vector2) -> void:
	var r := CROSSHAIR_RADIUS
	_overlay.draw_arc(pos, r, 0.0, TAU, 48, CROSSHAIR_RED, 2.0, true)
	_overlay.draw_circle(pos, 2.2, CROSSHAIR_RED)
	var tick := 7.0
	_overlay.draw_line(pos + Vector2(0, -r - tick), pos + Vector2(0, -r), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(0, r), pos + Vector2(0, r + tick), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(-r - tick, 0), pos + Vector2(-r, 0), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(r, 0), pos + Vector2(r + tick, 0), CROSSHAIR_RED, 2.0, true)
