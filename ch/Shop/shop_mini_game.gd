extends Control
## Minimalistic 2D arcade overlay that runs inside the shop panel.
## Toggle with Shift+2 while the shop is open.

## Master size for rocks and their hit/target radius. 1.0 = default.
@export_range(0.25, 3.0, 0.05) var size_scale := 1.0

const CREAM := Color(0.92156863, 0.8784314, 0.84705883, 1.0)
const BORDER_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const INK := Color(0.0824, 0.0941, 0.1098, 1.0)
const CROSSHAIR_RED := Color(0.78039217, 0.003921569, 0.007843138, 1.0)

const WALL_Y_RATIO := 0.88
const PILLAR_WIDTH_RATIO := 0.015 #0.045
const PILLAR_INSET_RATIO := 0.02 # 0.12
const CROSSHAIR_RADIUS := 18.0
const PAD := Vector2(28.0, 28.0)
const HEADER_CLEARANCE := 120.0
const MAX_STRIKES := 10

@export_group("Rock Pulse")
@export_range(50.0, 2000.0, 1.0) var launch_impulse := 450.0
@export_range(0.05, 5.0, 0.01) 	var fall_gravity_scale := 0.25
@export_range(0.0, 400.0, 1.0) 	var launch_x_jitter := 55.0
@export_range(0.0, 800.0, 1.0) 	var pulse_torque := 140.0
@export_range(0.0, 1.0, 0.01) 	var aim_together_chance := 0.8
@export_range(1, 10, 1) 		var rocks_per_wave := 4
@export_range(0.0, 1.0, 0.01) 	var pulse_stagger := 0.2
@export_range(0.5, 8.0, 0.05) 	var wave_interval := 2.2
@export_range(0.1, 3.0, 0.05) 	var mouse_sensitivity := 0.4

@export_group("Rock Types")
@export var basic_outline_color := Color(0.95, 0.82, 0.12, 1.0)
@export_range(0.0, 1.0, 0.01) var black_rock_chance := 0.15
@export_range(0.0, 1.0, 0.01) var red_rock_chance := 0.2
@export var red_hits_to_destroy := 3
@export var red_hit_bounce_force := 280.0
@export var red_hit_torque := 180.0

@export_group("Trail")
@export var trail_enabled := true
@export_range(2, 40, 1) var trail_length := 10
@export_range(0.5, 8.0, 0.1) var trail_width := 2.0
@export var trail_color := Color(1, 1, 1, 0.35)

@export_group("Money")
@export var money_per_destroy := 0.10
@export var black_rock_penalty := 1.0

@export_group("Screen Shake")
@export_range(0.0, 40.0, 0.1) var fire_shake_strength := 3.5
@export_range(0.0, 2.0, 0.01) var fire_shake_time := 0.08
@export_range(0.0, 40.0, 0.1) var destroy_shake_strength := 8.0
@export_range(0.0, 2.0, 0.01) var destroy_shake_time := 0.14
@export_range(1.0, 30.0, 0.1) var shake_decay := 12.0

var is_open := false
var _crosshair := Vector2.ZERO
var _wave_phase := 0.0
var _wave_timer := 0.0
var _wave_index := 0
var _pulsing := false
var _game_over := false
var _strikes := 0
var _money := 0.0
var _rocks: Array[RigidBody2D] = []
var _shot_flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _follow_panel: Control
var _header_clearance := HEADER_CLEARANCE
var _stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _shake_trauma := 0.0
var _shake_strength := 0.0
var _multikill_timer := 0.0

@onready var _play_area: Panel = $PlayArea
@onready var _content: Control = $PlayArea/Content
@onready var _wave_layer: Control = $PlayArea/Content/WaveLayer
@onready var _physics_root: Node2D = $PlayArea/Content/PhysicsRoot
@onready var _overlay: Control = $PlayArea/Content/Overlay
@onready var _crosshair_node: Control = $PlayArea/Content/Overlay/Crosshair
@onready var _crosshair_texture: TextureRect = $PlayArea/Content/Overlay/Crosshair/CrosshairTexture
@onready var _money_label: RichTextLabel = $PlayArea/Content/Overlay/MoneyLabel
@onready var _strike_label: RichTextLabel = $PlayArea/Content/Overlay/StrikeLabel
@onready var _wave_label: RichTextLabel = $PlayArea/Content/Overlay/WaveAnnounceLabel
@onready var _multikill_label: RichTextLabel = $PlayArea/Content/Overlay/MultiKillLabel
@onready var _game_over_panel: Control = $PlayArea/Content/Overlay/GameOverPanel
@onready var _game_over_money: RichTextLabel = $PlayArea/Content/Overlay/GameOverPanel/MoneyEarned
@onready var _retry_button: Button = $PlayArea/Content/Overlay/GameOverPanel/RetryButton
@onready var _aoe: Node2D = $PlayArea/Content/AOE2D
@onready var _sfx_take_damage: AudioStreamPlayer = $SFX/take_damage_sfx
@onready var _sfx_hit_flicker: AudioStreamPlayer = $SFX/Flicker_sound

@onready var _sfx_hit: AudioStreamPlayer = $SFX/hitSound
@onready var _sfx_explosion: AudioStreamPlayer = $SFX/explosion_sfx
@onready var _sfx_shoot: AudioStreamPlayer = $SFX/Shoot_sfx
@onready var _sfx_miss: AudioStreamPlayer = $SFX/cannot_shoot_sfx
@onready var _sfx_pulse: AudioStreamPlayer = $SFX/EggPulseSfx
@onready var _sfx_splash_01: AudioStreamPlayer = $SFX/splash_sfx_01
@onready var _sfx_splash_02: AudioStreamPlayer = $SFX/splash_sfx_02
@onready var _splash_aoe: Node2D = get_node_or_null("PlayArea/Content/SplashAOE2D") as Node2D
@onready var _miss_label: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/MissLabel") as RichTextLabel
@onready var _mouse_sfx: Node = $Mouse_turning_SFX

var _miss_timer := 0.0


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
	_retry_button.pressed.connect(_on_retry_pressed)
	_game_over_panel.hide()
	_wave_label.modulate.a = 0.0
	_multikill_label.modulate.a = 0.0
	if _miss_label:
		_miss_label.modulate.a = 0.0
	_refresh_hud()
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
	if _content:
		_content.size = size
		_content.position = _shake_offset()


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
	_reset_run()
	_sync_to_panel()
	modulate.a = 0.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	_sync_to_panel()
	_center_crosshair()
	_wave_layer.queue_redraw()
	_overlay.queue_redraw()
	_begin_next_wave()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_pulsing = false
	_game_over = false
	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	if not is_open:
		hide()
		_clear_rocks()
		_shot_flashes.clear()


func _reset_run() -> void:
	_clear_rocks()
	_shot_flashes.clear()
	_wave_timer = 0.0
	_wave_phase = 0.0
	_wave_index = 0
	_pulsing = false
	_game_over = false
	_strikes = 0
	_money = 0.0
	_shake_trauma = 0.0
	_multikill_timer = 0.0
	_miss_timer = 0.0
	_game_over_panel.hide()
	_wave_label.modulate.a = 0.0
	_multikill_label.modulate.a = 0.0
	if _miss_label:
		_miss_label.modulate.a = 0.0
	_refresh_hud()
	_center_crosshair()


func _on_retry_pressed() -> void:
	_reset_run()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(true)
	_begin_next_wave()


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
	_update_crosshair_node()


func _update_crosshair_node() -> void:
	if _crosshair_node:
		_crosshair_node.position = _crosshair - _crosshair_node.size * 0.5


func _on_overlay_resized() -> void:
	if is_open:
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_update_crosshair_node()
		_overlay.queue_redraw()
		_wave_layer.queue_redraw()


func _process(delta: float) -> void:
	if not is_open:
		return
	_sync_to_panel()
	_wave_phase += delta * 2.2
	_update_flashes(delta)
	_update_shake(delta)
	_cleanup_fallen_rocks()

	if _multikill_timer > 0.0:
		_multikill_timer -= delta
		if _multikill_timer <= 0.0:
			_multikill_label.modulate.a = 0.0

	if _miss_timer > 0.0:
		_miss_timer -= delta
		if _miss_timer <= 0.0 and _miss_label:
			_miss_label.modulate.a = 0.0

	if not _game_over and not _pulsing and _alive_rock_count() == 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_begin_next_wave()

	_wave_layer.queue_redraw()
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or _game_over:
		return
	if event is InputEventMouseMotion:
		_crosshair += (event as InputEventMouseMotion).relative * mouse_sensitivity
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_update_crosshair_node()
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_shoot()
			get_viewport().set_input_as_handled()


func _begin_next_wave() -> void:
	if _pulsing or _game_over:
		return
	_pulsing = true
	_wave_index += 1
	await _show_wave_announce(_wave_index)
	if not is_open or _game_over:
		_pulsing = false
		return
	_prepare_rocks()
	await _pulse_rocks()
	_pulsing = false
	_wave_timer = wave_interval


func _show_wave_announce(wave: int) -> void:
	_wave_label.text = "[i]%s" % _wave_display_name(wave)
	_wave_label.modulate.a = 0.0
	_wave_label.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_wave_label, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_wave_label, "scale", Vector2.ONE, 0.25)
	tween.tween_interval(0.7)
	tween.tween_property(_wave_label, "modulate:a", 0.0, 0.25)
	await tween.finished


func _wave_display_name(wave: int) -> String:
	const ORDINALS := ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth"]
	if wave >= 1 and wave <= ORDINALS.size():
		return "%s Wave" % ORDINALS[wave - 1]
	return "Wave %d" % wave


func _prepare_rocks() -> void:
	_clear_rocks()
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var count := rocks_per_wave
	for i in count:
		var column_t := float(i + 1) / float(count + 1)
		var radius := _rng.randf_range(14.0, 26.0) * 0.5 * size_scale
		var kind := _roll_rock_kind()
		var rock := ShopMiniRock.new()
		_physics_root.add_child(rock)
		rock.outline_color = basic_outline_color
		rock.red_hits_to_destroy = red_hits_to_destroy
		rock.red_hit_bounce_force = red_hit_bounce_force
		rock.red_hit_torque = red_hit_torque
		rock.trail_enabled = trail_enabled
		rock.trail_length = trail_length
		rock.trail_width = trail_width
		rock.trail_color = trail_color
		rock.setup(radius, _make_rock_outline(radius), kind)
		rock.position = Vector2(
			area.x * column_t + _rng.randf_range(-18.0, 18.0),
			wall_y + radius + _rng.randf_range(8.0, 22.0) * size_scale
		)
		rock.rotation = _rng.randf_range(-0.25, 0.25)
		_rocks.append(rock)


func _roll_rock_kind() -> ShopMiniRock.RockKind:
	var roll := _rng.randf()
	if roll < black_rock_chance:
		return ShopMiniRock.RockKind.BLACK
	if roll < black_rock_chance + red_rock_chance:
		return ShopMiniRock.RockKind.RED
	return ShopMiniRock.RockKind.BASIC


func _pulse_rocks() -> void:
	var to_pulse: Array[RigidBody2D] = []
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.hit:
			to_pulse.append(rock)
	if to_pulse.is_empty():
		return

	var aim_together := _rng.randf() < aim_together_chance and to_pulse.size() >= 2
	var center := Vector2.ZERO
	if aim_together:
		for rock in to_pulse:
			center += rock.position
		center /= float(to_pulse.size())

	if _sfx_pulse:
		_sfx_pulse.play()
	
	_add_shake(destroy_shake_strength, destroy_shake_time)

	for rock in to_pulse:
		if not is_open or _game_over:
			return
		if not is_instance_valid(rock) or rock.hit:
			continue
		var x_impulse := _rng.randf_range(-launch_x_jitter, launch_x_jitter)
		if aim_together:
			var toward := center.x - rock.position.x
			x_impulse = clampf(toward * 0.85, -launch_impulse * 0.55, launch_impulse * 0.55)
			x_impulse += _rng.randf_range(-launch_x_jitter * 0.25, launch_x_jitter * 0.25)
		var torque := _rng.randf_range(-pulse_torque, pulse_torque)
		if absf(torque) < pulse_torque * 0.35:
			torque = pulse_torque * (1.0 if _rng.randf() > 0.5 else -1.0)
		rock.pulse(launch_impulse, x_impulse, fall_gravity_scale, torque)
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
	if pts.is_empty():
		# Safe fallback so we never index an empty outline.
		pts.append(Vector2(radius, 0.0))
		pts.append(Vector2(0.0, radius))
		pts.append(Vector2(-radius, 0.0))
		pts.append(Vector2(0.0, -radius))
	pts.append(pts[0])
	return pts


func _alive_rock_count() -> int:
	var count := 0
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.hit:
			count += 1
	return count


func _cleanup_fallen_rocks() -> void:
	if _game_over:
		return
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	var remaining: Array[RigidBody2D] = []
	for rock in _rocks:
		if not is_instance_valid(rock):
			continue
		if rock.hit:
			rock.queue_free()
			continue
		if rock.pulsed and rock.position.y > wall_y + rock.radius + 40.0 and rock.linear_velocity.y > 0.0:
			var fall_pos := rock.position
			var mini := rock as ShopMiniRock
			var kind: ShopMiniRock.RockKind = mini.kind if mini else ShopMiniRock.RockKind.BASIC
			_play_splash(fall_pos)
			# Black rocks are hazards to avoid — letting them fall is success (no strike).
			if kind != ShopMiniRock.RockKind.BLACK:
				_add_strike()
			rock.queue_free()
			continue
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
	if _game_over:
		return

	
	_play_fire_sfx()
	_add_shake(fire_shake_strength, fire_shake_time)
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	_shot_flashes.append({"pos": _crosshair, "t": 0.12})
	var destroyed_count := 0
	var hit_any := false
	# Hit every rock under the crosshair this frame (multi-kill).
	for i in range(_rocks.size() - 1, -1, -1):
		if i < 0 or i >= _rocks.size():
			continue
		var rock := _rocks[i] as ShopMiniRock
		if rock == null or not is_instance_valid(rock) or rock.hit:
			continue
		if rock.position.y > wall_y:
			continue
		if rock.position.distance_to(_crosshair) > rock.radius + (12.0 * size_scale):
			continue
		hit_any = true
		var hit_pos := rock.position
		var kind: ShopMiniRock.RockKind = rock.kind
		# Bounce away from the crosshair center.
		
		
		
		var away_from_crosshair := rock.position - _crosshair
		var destroyed: bool = rock.apply_shot(away_from_crosshair)
		
		if not destroyed:
			_play_hit_sfx()
			_shot_flashes.append({"pos": hit_pos, "t": 0.18, "burst": true})
			continue
		destroyed_count += 1
		_rocks.remove_at(i)
		_on_rock_destroyed(rock, hit_pos, kind)

	if destroyed_count >= 2:
		_show_multikill(destroyed_count)
	elif not hit_any:
		_on_shot_missed()


func _on_shot_missed() -> void:

	if _sfx_miss:
		_sfx_miss.play(0.91)
	if _miss_label:
		_miss_label.text = "[i]MISS"
		_miss_label.modulate.a = 1.0
		_miss_timer = 0.45
	_shot_flashes.append({"pos": _crosshair, "t": 0.16, "burst": true})


func _on_rock_destroyed(rock: RigidBody2D, hit_pos: Vector2, kind: ShopMiniRock.RockKind) -> void:
	if _sfx_hit_flicker:
		_sfx_hit_flicker.play()
		
	await get_tree().create_timer(0.25, false).timeout
	
	_play_destroy_sfx()
	_play_aoe(hit_pos)
	_add_shake(destroy_shake_strength, destroy_shake_time)
	_shot_flashes.append({"pos": hit_pos, "t": 0.22, "burst": true})
	if kind == ShopMiniRock.RockKind.BLACK:
		# Hazard: money penalty only — no strike (they're meant to be avoided).
		_add_money(-black_rock_penalty)
	else:
		_add_money(money_per_destroy)
	if is_instance_valid(rock):
		rock.queue_free()

func _show_multikill(count: int) -> void:
	var text := "DOUBLE SHOT"
	if count == 3:
		text = "TRIPLE SHOT"
	elif count == 4:
		text = "QUAD SHOT"
	elif count > 4:
		text = "%dX SHOT" % count
	_multikill_label.text = "[i][wave]%s" % text
	_multikill_label.modulate.a = 1.0
	_multikill_timer = 1.1


func _add_money(amount: float) -> void:
	_money = maxf(0.0, _money + amount)
	_refresh_hud()


func _add_strike() -> void:
	if _game_over:
		return
	_strikes = mini(_strikes + 1, MAX_STRIKES)
	_refresh_hud()
	if _strikes >= MAX_STRIKES:
		_trigger_game_over()


func _trigger_game_over() -> void:
	_game_over = true
	_pulsing = false
	_clear_rocks()
	_game_over_money.text = "[center]You earned\n[color=#c70102]$%.2f[/color]" % _money
	_game_over_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(false)


func _refresh_hud() -> void:
	if _money_label:
		_money_label.text = "[right]$%.2f" % _money
	if _strike_label:
		var marks := ""
		for i in MAX_STRIKES:
			marks += "X" if i < _strikes else "·"
			if i < MAX_STRIKES - 1:
				marks += " "
		_strike_label.text = "[center]%s" % marks


func _play_fire_sfx() -> void:
	if _sfx_shoot == null:
		return
	_sfx_shoot.pitch_scale = _rng.randf_range(0.95, 1.08)
	_sfx_shoot.play()


func _play_hit_sfx() -> void:
	if _sfx_take_damage == null:
		return
	_sfx_take_damage.volume_db = _rng.randf_range(-25.0, -20.0)
	_sfx_take_damage.pitch_scale = _rng.randf_range(0.9, 1.2)
	_sfx_take_damage.play(0.01)


func _play_destroy_sfx() -> void:
	# Non-blocking — avoids hitching the game when shooting.
	if _sfx_take_damage:
		_sfx_take_damage.volume_db = _rng.randf_range(-25.0, -20.0)
		_sfx_take_damage.pitch_scale = _rng.randf_range(0.9, 1.2)
		_sfx_take_damage.play(0.02)
	if _sfx_hit:
		_sfx_hit.play()

	#if _sfx_hit_flicker:
		#_sfx_hit_flicker.play()
		
	if _sfx_explosion:
		_sfx_explosion.play()


func _play_splash(local_pos: Vector2) -> void:
	var splash := _sfx_splash_01
	if _rng.randf() > 0.5 and _sfx_splash_02:
		splash = _sfx_splash_02
	if splash:
		splash.pitch_scale = _rng.randf_range(0.9, 1.0)
		splash.play()
	if _splash_aoe:
		_splash_aoe.position = _physics_root.position + Vector2(local_pos.x, _overlay.size.y * WALL_Y_RATIO)
		if _splash_aoe.has_method("play_at"):
			_splash_aoe.play_at(_splash_aoe.global_position)


func _play_aoe(local_pos: Vector2) -> void:
	if _aoe == null:
		return
	# Rock positions are PhysicsRoot-local; AOE is a Content sibling.
	_aoe.position = _physics_root.position + local_pos
	if _aoe.has_method("play_at"):
		_aoe.play_at(_aoe.global_position)

func _add_shake(strength: float, time: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_trauma = maxf(_shake_trauma, time)


func _shake_offset() -> Vector2:
	if _shake_trauma <= 0.0 or _shake_strength <= 0.0:
		return Vector2.ZERO
	var falloff := clampf(_shake_trauma * shake_decay * 0.35, 0.0, 1.0)
	return Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake_strength * falloff


func _update_shake(delta: float) -> void:
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - delta)
		if _shake_trauma <= 0.0:
			_shake_strength = 0.0
	if _content:
		_content.position = _shake_offset()
		_content.size = size


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
	_overlay.draw_rect(Rect2(0.0, wall_y, area.x, area.y - wall_y + 2.0), CREAM, true)
	_draw_pillars(area, wall_y)
	_draw_wall(area, wall_y)
	_draw_flashes()
	# Fallback crosshair if no custom texture assigned.
	if _crosshair_texture == null or _crosshair_texture.texture == null:
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
			_overlay.draw_arc(pos, maxf(r, 14.0), 0.0, TAU, 18, color, 1.5, true)
		else:
			_overlay.draw_circle(pos, 3.0, color)


func _draw_crosshair(pos: Vector2) -> void:
	var r := CROSSHAIR_RADIUS
	_overlay.draw_arc(pos, r, 0.0, TAU, 48, CROSSHAIR_RED, 2.0, true)
	_overlay.draw_circle(pos, 12.2, Color("ff000028"))
	var tick := 30.0
	_overlay.draw_line(pos + Vector2(0, -r - tick), pos + Vector2(0, -r), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(0, r), pos + Vector2(0, r + tick), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(-r - tick, 0), pos + Vector2(-r, 0), CROSSHAIR_RED, 2.0, true)
	_overlay.draw_line(pos + Vector2(r, 0), pos + Vector2(r + tick, 0), CROSSHAIR_RED, 2.0, true)
