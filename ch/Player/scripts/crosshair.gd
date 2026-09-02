extends Control

class_name Player_Crosshair

@export var amount_of_shakes := 1
@export var shake_amount := 1.1
@export var move_speed := 0.1


@export var temp_dur := 0.5

var scope_tween : Tween = null
var inner_scope_tween : Tween = null
var orig_scale : Vector2
var inner_orig_scale : Vector2

@export var rotating_crosshair_bool := false

@export_group("Target Laser Dot")
## One red laser/dot drawn on each Target currently inside the reticle.
@export var target_laser_enabled := true
## Edit colour / alpha of each lock-on laser dot.
@export var target_laser_color := Color(1.0, 0.0, 0.0, 0.72)
## Uniform scale of each dot (template: CanvasLayer/Crosshair/RedDot).
@export var target_laser_scale := 0.42
@export var target_laser_fade_speed := 16.0

@onready var up = $Inner_scope/center_container/up
@onready var down = $Inner_scope/center_container/down
@onready var left = $Inner_scope/center_container/left
@onready var right = $Inner_scope/center_container/right
## Template only — cloned per locked rock; kept hidden at reticle center.
@onready var red_dot: TextureRect = $RedDot

var up_pos_y : float
var down_pos_y : float
var left_pos_x : float
var right_pos_x : float

@export var target_color := Color.ORANGE_RED
@export var default_color := Color.WHITE
@export var transition_speed := 0.05
var orig_pos := Vector2.ZERO

@export_group("Low Ammo Warning")
## Show blinking LOW AMMO on the reticle when ammo is below this (and above 0).
@export var low_ammo_threshold := 20
@export var low_ammo_blink_sec := 0.35
@export var low_ammo_blink_min_alpha := 0.2
@export var low_ammo_blink_max_alpha := 1.0

@onready var low_ammo_label: RichTextLabel = get_node_or_null("LowAmmoLabel") as RichTextLabel

var _low_ammo_warning_active := false
var _low_ammo_blink_tween: Tween

@export_group("Avoider Hit Feedback")
## Reticle tint when a red-avoider snaps onto the crosshair.
@export var avoider_hit_color := Color(1.0, 0.05, 0.05, 1.0)
@export_range(0.05, 0.5, 0.01) var avoider_hit_flicker_sec := 0.1
@export_range(1, 8, 1) var avoider_hit_flicker_times := 4
@export_range(0.05, 1.0, 0.05) var avoider_hit_fade_sec := 0.35

var _avoider_hit_token := 0
var _avoider_hit_tween: Tween

var _weapon_style_cached := false
var _default_inner_modulate := Color.WHITE
var _default_outer_modulate := Color.WHITE
var _default_line_colors: Dictionary = {}

var _laser_layer: Control
var _laser_pool: Array[TextureRect] = []
var _laser_alpha: Array[float] = []

const PLANTED_CROSSHAIR_MAX := 5
const PLANTED_ARMED_MODULATE := Color(1.0, 0.85, 0.45, 0.92)
const PLANTED_UNARMED_MODULATE := Color(1.0, 0.85, 0.45, 0.32)
const PLANTED_ARM_FLASH_SEC := 0.15
## Planted traps: node, aim, age, radius, armed, arm_delay, lifetime, rotation_speed, rotating, dissipating
var _planted_crosshairs: Array[Dictionary] = []


func _ready() -> void:
	modulate = Color.TRANSPARENT
	self.hide()
	await crosshair_fade_out_mode()
	
	#EventBus.instance.open_shop.connect(_on_shop_entered)
	#EventBus.instance.close_shop.connect(_on_shop_finished)

	up_pos_y = up.position.y
	down_pos_y = down.position.y
	left_pos_x = left.position.x
	right_pos_x = right.position.x
	
#	EventBus.instance.wrapping_up_a_level.connect(_fade_out)
	self.show()
	_cache_default_weapon_style()
	_setup_target_laser_dots()
	set_process(true)


func _process(delta: float) -> void:
	#_update_target_laser_dots(delta)
	_update_planted_crosshairs(delta)
	%SmallDisplay.rotation += 0.1
	#%Crosshair.modulate.a = 1.0
	#if Input.is_action_pressed("shootWeapon"):
		#%Crosshair.modulate.a = 1.0
	#else:
		#modulate.a -= 0.1
	#modulate.a -= 0.1

func _setup_target_laser_dots() -> void:
	## Keep the scene RedDot as a hidden template; live dots are clones on the rocks.
	if red_dot:
		red_dot.hide()
		red_dot.modulate.a = 0.0

	var canvas := get_parent()
	if canvas == null:
		return
	_laser_layer = canvas.get_node_or_null("TargetLaserDots") as Control
	if _laser_layer == null:
		_laser_layer = Control.new()
		_laser_layer.name = "TargetLaserDots"
		_laser_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_laser_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(_laser_layer)


func _acquire_laser_dot(index: int) -> TextureRect:
	#return
	while _laser_pool.size() <= index:
		var dot: TextureRect
		if red_dot:
			dot = red_dot.duplicate() as TextureRect
		else:
			dot = TextureRect.new()
			dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			dot.custom_minimum_size = Vector2(40, 40)
		dot.name = "TargetLaserDot_%d" % _laser_pool.size()
		dot.visible = false
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.top_level = true
		dot.pivot_offset_ratio = Vector2(0.5, 0.5)
		dot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		if _laser_layer:
			_laser_layer.add_child(dot)
		else:
			add_child(dot)
		_laser_pool.append(dot)
		_laser_alpha.append(0.0)
	return _laser_pool[index]


func _get_scoped_targets() -> Array:
	if not target_laser_enabled:
		return []
	var player := get_parent().get_parent() if get_parent() else null
	if player == null:
		return []
	if "current_state" in player and "State" in player:
		if player.current_state != player.State.ACTIVE:
			return []
	var weapon = player.get("weapon_shooting")
	if weapon == null or not weapon.has_method("get_targets_in_scope"):
		return []
	return weapon.get_targets_in_scope()


func _camera_for_laser():
	var player := get_parent().get_parent() if get_parent() else null
	if player == null:
		return null
	var weapon = player.get("weapon_shooting")
	if weapon and weapon.get("stable_camera"):
		return weapon.stable_camera
	return get_tree().get_first_node_in_group("player_cam")


func _update_target_laser_dots(delta: float) -> void:
	var scoped := _get_scoped_targets()
	var cam = _camera_for_laser()
	var active_count := 0

	if target_laser_enabled and cam != null:
		for entry in scoped:
			var target = entry.get("target") if entry is Dictionary else null
			if target == null or not is_instance_valid(target):
				continue
			if cam.is_position_behind(target.global_position):
				continue
			var screen_pos: Vector2 = cam.unproject_position(target.global_position)
			var dot := _acquire_laser_dot(active_count)
			_laser_alpha[active_count] = move_toward(
				_laser_alpha[active_count], 1.0, target_laser_fade_speed * delta
			)
			dot.self_modulate = target_laser_color
			dot.scale = Vector2.ONE * target_laser_scale
			dot.modulate.a = _laser_alpha[active_count]
			dot.visible = _laser_alpha[active_count] > 0.01
			## Center the texture on the rock's screen position.
			var half := (dot.size * dot.scale) * 0.5
			if half == Vector2.ZERO:
				half = Vector2(10, 10) * target_laser_scale
			dot.global_position = screen_pos - half
			active_count += 1

	## Fade out / hide unused pool slots.
	for i in _laser_pool.size():
		if i < active_count:
			continue
		_laser_alpha[i] = move_toward(_laser_alpha[i], 0.0, target_laser_fade_speed * delta)
		var unused := _laser_pool[i]
		unused.modulate.a = _laser_alpha[i]
		if _laser_alpha[i] <= 0.01:
			unused.visible = false
		else:
			unused.visible = true


func _cache_default_weapon_style() -> void:
	if _weapon_style_cached:
		return
	_weapon_style_cached = true
	var inner := $Inner_scope/center_container as Control
	var outer := $Large_outer_scope/center_container as Control
	_default_inner_modulate = inner.modulate
	_default_outer_modulate = outer.modulate
	for line in [up, down, left, right]:
		_default_line_colors[line] = line.default_color


## Alt weapon reticle: same layout as default, color only.
func apply_weapon_style(use_alt: bool, color: Color, _size_scale: float = 1.0, _arm_length_scale: float = 1.0, _rotate_45: bool = false) -> void:
	_cache_default_weapon_style()
	var inner := $Inner_scope/center_container as Control
	var outer := $Large_outer_scope/center_container as Control
	if not use_alt:
		inner.modulate = _default_inner_modulate
		outer.modulate = _default_outer_modulate
		for line in [up, down, left, right]:
			line.default_color = _default_line_colors.get(line, Color(1, 1, 1, 0.96))
		return

	inner.modulate = color
	outer.modulate = color
	for line in [up, down, left, right]:
		line.default_color = color


func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	await tween.finished


func crosshair_shake() -> void:
	crosshair_inner_tween()
	crosshair_shooting_something()
	var rossy := get_node_or_null("Rossy")
	if rossy and rossy.has_method("notify_shot"):
		rossy.notify_shot()
	#outer_crosshair_rotation_tween()
	var scope = $Large_outer_scope/center_container
	orig_scale = scale
	if scope_tween:
		scope_tween.kill()
		#return
	
	scope_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for i in range(amount_of_shakes):
		scope_tween.tween_property(scope, "scale", Vector2.ONE * 1.25, 0.1)
		scope_tween.tween_interval(0.15)
		#scope_tween.parallel().tween_property($Inner_scope, "modulate", Color('ffffff40'), 0.05)
		scope_tween.tween_property(scope, "scale", Vector2.ONE * shake_amount, move_speed)
		
		scope_tween.tween_property(scope, "scale", Vector2.ONE, move_speed)
	await scope_tween.finished
	scale = orig_scale

	
func crosshair_inner_tween() -> void:

	var _scope = $Inner_scope/center_container
	inner_crosshair_rotation_tween()
	
	if inner_scope_tween:
		inner_scope_tween.kill()
		#return

	inner_scope_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	inner_scope_tween.tween_property(left, "position:x", -160.0, 0.2).as_relative()
	inner_scope_tween.parallel().tween_property(right, "position:x", 160.0, 0.2).as_relative()
	inner_scope_tween.parallel().tween_property(up, "position:y", -160.0, 0.2).as_relative()
	inner_scope_tween.parallel().tween_property(down, "position:y", 160.0, 0.2).as_relative()
	
	#inner_scope_tween.tween_interval(0.1)
	
	inner_scope_tween.tween_property(left, "position:x", left_pos_x, temp_dur)
	inner_scope_tween.parallel().tween_property(right, "position:x", right_pos_x, temp_dur)
	inner_scope_tween.parallel().tween_property(up, "position:y", up_pos_y, temp_dur)
	inner_scope_tween.parallel().tween_property(down, "position:y", down_pos_y, temp_dur)
	
	
	await inner_scope_tween.finished
	scale = orig_scale
	return
	
	
func inner_crosshair_rotation_tween() -> void:
	if !rotating_crosshair_bool:
		return
	var scope = $Inner_scope/center_container
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(scope, "rotation", 0.2, 0.25).as_relative()
	tween.tween_property(scope, "rotation", -0.4, 0.25).as_relative()
	tween.tween_property(scope, "rotation", 0, 0.25)
	
	
func outer_crosshair_rotation_tween() -> void:
	#if !rotating_crosshair_bool:
		#return
	var scope = $Large_outer_scope/center_container
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(scope, "rotation", 0.05, 0.25).as_relative()
	tween.tween_property(scope, "rotation", -0.1, 0.25).as_relative()
	tween.tween_property(scope, "rotation", 0, 0.25)

#func crosshair_dull_mode() -> void:
	#return
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "modulate", Color('FFFFFF30'), 1.0)
	#await tween.finished
	
	
func crosshair_active_mode() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color('FFFFFF'), 1.0)
	await tween.finished
	
func change_crosshair_colours() -> void:
	var large = $Large_outer_scope/center_container
	var small = $Inner_scope/center_container
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(small, "modulate", Color.GOLD, 0.25)
	tween.tween_property(large, "modulate", Color.GOLD, 0.5)
	

func cross_hair_fade_in() -> void:
	var round_end_label : TextureProgressBar = %Bullet_icon

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color('ffffff'),0.25)
	await tween.finished

	round_end_label.show()
	%Bullet_icon2.show()
	
	
func cannot_shoot_obstacle_in_way() -> void:
	return
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "modulate", Color.BLACK ,0.1)
	#tween.parallel().tween_property(self, "rotation", 0.1 ,0.1)
	#tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	#tween.parallel().tween_property(self, "rotation", -0.1 ,0.1)
	#tween.tween_property(self, "rotation", 0.0 ,0.1)




func crosshair_shooting_something() -> void:
	

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.ORANGE ,0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


## Red-avoider landed on reticle: turn red, flicker visibility, fade back to white.
func play_avoider_hit_feedback() -> void:
	_avoider_hit_token += 1
	var token := _avoider_hit_token
	if _avoider_hit_tween and _avoider_hit_tween.is_valid():
		_avoider_hit_tween.kill()
	_avoider_hit_tween = null

	visible = true
	modulate = Color(avoider_hit_color.r, avoider_hit_color.g, avoider_hit_color.b, 1.0)

	var flickers := maxi(avoider_hit_flicker_times, 1)
	var step := maxf(avoider_hit_flicker_sec, 0.05)
	for _i in flickers:
		if token != _avoider_hit_token:
			return
		visible = false
		await get_tree().create_timer(step, false).timeout
		if token != _avoider_hit_token:
			return
		visible = true
		await get_tree().create_timer(step, false).timeout

	if token != _avoider_hit_token:
		return
	visible = true
	modulate = Color(avoider_hit_color.r, avoider_hit_color.g, avoider_hit_color.b, 1.0)
	_avoider_hit_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_avoider_hit_tween.tween_property(self, "modulate", Color.WHITE, maxf(avoider_hit_fade_sec, 0.05))
	await _avoider_hit_tween.finished


func crosshair_nothing_to_shoot() -> void:
	return
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.5 ,0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	#await tween.finished
	
func out_of_ammo_display() -> void:
	#crosshair_nothing_to_shoot()
	set_low_ammo_warning(false)
	var no_ammo_label : RichTextLabel = $OutOfAmmoLabel
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(no_ammo_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(no_ammo_label, "modulate:a", 0.2 ,0.1)
	tween.tween_property(no_ammo_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(no_ammo_label, "modulate:a", 0.2 ,0.1)
	tween.tween_property(no_ammo_label, "modulate:a", 1.0, 0.1)
	#tween.tween_interval(0.2)
	#tween.tween_property(no_ammo_label, "modulate:a", 0.0 ,0.1)

func out_of_ammo_hide() -> void:
	var no_ammo_label : RichTextLabel = $OutOfAmmoLabel
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(no_ammo_label, "modulate:a", 0.0, 0.1)


## Blinking "LOW AMMO" under the reticle while ammo is critically low.
func set_low_ammo_warning(active: bool) -> void:
	if active == _low_ammo_warning_active:
		return
	_low_ammo_warning_active = active
	if low_ammo_label == null:
		low_ammo_label = get_node_or_null("LowAmmoLabel") as RichTextLabel
	if low_ammo_label == null:
		return
	if _low_ammo_blink_tween:
		_low_ammo_blink_tween.kill()
		_low_ammo_blink_tween = null
	if not active:
		low_ammo_label.hide()
		low_ammo_label.modulate.a = 0.0
		return

	low_ammo_label.text = "LOW AMMO"
	low_ammo_label.show()
	low_ammo_label.modulate.a = low_ammo_blink_max_alpha
	_low_ammo_blink_tween = create_tween().set_loops()
	_low_ammo_blink_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half := maxf(low_ammo_blink_sec, 0.05)
	_low_ammo_blink_tween.tween_property(low_ammo_label, "modulate:a", low_ammo_blink_min_alpha, half)
	_low_ammo_blink_tween.tween_property(low_ammo_label, "modulate:a", low_ammo_blink_max_alpha, half)

	
func crosshair_fade_out_mode() -> void:

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color('ffffff00'),0.25)
	await tween.finished

func plant_crosshair_trap(arm_delay: float = 1.5) -> bool:
	var original: Control = $Inner_scope
	if original == null:
		return false

	while _planted_crosshairs.size() >= PLANTED_CROSSHAIR_MAX:
		_dissipate_planted_crosshair(0, false, "force")

	var plant: Control = original.duplicate() as Control
	if plant == null:
		return false

	var host := get_parent()
	if host == null:
		plant.queue_free()
		return false

	var player = _player_for_plants()
	arm_delay = maxf(0.0, arm_delay)
	var starts_armed := arm_delay <= 0.0
	var lifetime := 7.0
	var rotation_speed := 120.0
	var pulse_scale := 2.8
	var pulse_duration := 0.4
	if player:
		lifetime = maxf(0.5, float(player.get("planted_crosshair_lifetime")))
		rotation_speed = float(player.get("planted_crosshair_rotation_speed"))
		pulse_scale = float(player.get("planted_crosshair_pulse_scale"))
		pulse_duration = float(player.get("planted_crosshair_pulse_duration"))

	host.add_child(plant)
	plant.top_level = true
	plant.global_position = original.global_position
	plant.scale = original.scale
	plant.pivot_offset_ratio = Vector2(0.5, 0.5)
	plant.rotation = 0.0
	plant.modulate = PLANTED_ARMED_MODULATE if starts_armed else PLANTED_UNARMED_MODULATE
	plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Disable cooldown bar / anim on the planted copy.
	var cooldown := plant.get_node_or_null("Cooldown_progressBar3")
	if cooldown:
		cooldown.hide()
	var anim := plant.get_node_or_null("AnimationPlayer")
	if anim:
		anim.stop()
	## Pulse VFX uses RingTexture duplicates — hide the copy on the planted scope.
	var planted_ring := plant.get_node_or_null("RingTexture") as Control
	if planted_ring:
		planted_ring.hide()

	var aim_tex := plant.get_node_or_null("TextureRect") as Control
	var aim_pos: Vector2 = aim_tex.global_position if aim_tex else plant.global_position
	var weapon = _weapon_for_plants()
	var radius: float = weapon.power_target_circle if weapon else 60.0

	_play_planted_sfx(1)
	var ring_src := $Inner_scope/RingTexture as Control
	var pulse_center: Vector2 = (
		ring_src.get_global_rect().get_center() if ring_src else plant.get_global_rect().get_center()
	)
	var pulse_base_scale: Vector2 = _control_global_scale(ring_src) if ring_src else Vector2.ONE
	_spawn_outer_ring_pulse(pulse_center, pulse_base_scale, pulse_scale, pulse_duration)

	_planted_crosshairs.append({
		"node": plant,
		"aim": aim_pos,
		"age": 0.0,
		"radius": radius,
		"armed": starts_armed,
		"arm_delay": arm_delay,
		"lifetime": lifetime,
		"rotation_speed": rotation_speed,
		"rotating": starts_armed,
		"pulse_scale": pulse_scale,
		"pulse_duration": pulse_duration,
		"dissipating": false,
	})
	if starts_armed:
		_play_planted_sfx(2)
	return true


func _player_for_plants():
	var canvas := get_parent()
	if canvas == null:
		return null
	return canvas.get_parent()


func _weapon_for_plants():
	var player = _player_for_plants()
	if player == null:
		return null
	return player.get("weapon_shooting")


## 1 plant, 2 armed/live, 3 overlap trigger, 4 natural dissipate.
func _play_planted_sfx(which: int) -> void:
	var player = _player_for_plants()
	if player == null:
		return
	var node_name := "planted_crosshair"
	if which >= 2:
		node_name = "planted_crosshair%d" % which
	var sfx := player.get_node_or_null("SFX/%s" % node_name) as AudioStreamPlayer
	if sfx == null:
		return
	sfx.play()


func _control_global_scale(node: Control) -> Vector2:
	if node == null:
		return Vector2.ONE
	return node.get_global_transform_with_canvas().get_scale()


func pulse_ring_texture(
	pulse_scale_mult: float = -1.0,
	pulse_duration: float = -1.0,
	modulate_color: Variant = null
) -> void:
	var player = _player_for_plants()
	var scale_mult := pulse_scale_mult
	var duration := pulse_duration
	if scale_mult < 0.0:
		scale_mult = float(player.get("shoot_ring_pulse_scale")) if player else 2.0
	if duration < 0.0:
		duration = float(player.get("shoot_ring_pulse_duration")) if player else 0.35
	var ring_src := $Inner_scope/RingTexture as Control
	if ring_src == null:
		return
	_spawn_outer_ring_pulse(
		ring_src.get_global_rect().get_center(),
		_control_global_scale(ring_src),
		scale_mult,
		duration,
		modulate_color
	)


func _spawn_outer_ring_pulse(
	at_center: Vector2,
	base_scale: Vector2,
	pulse_scale_mult: float,
	pulse_duration: float,
	modulate_color: Variant = null
) -> void:
	var ring_src: Control = $Inner_scope/RingTexture as Control
	if ring_src == null:
		return
	var host := get_parent()
	if host == null:
		return
	var pulse: Control = ring_src.duplicate() as Control
	if pulse == null:
		return
	host.add_child(pulse)
	pulse.top_level = true
	pulse.visible = true
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Keep the duplicated layout/size; only center the pivot for clean expand.
	pulse.pivot_offset_ratio = Vector2(0.5, 0.5)
	pulse.rotation = 0.0
	## Start at the live ring's on-screen size (includes Inner_scope scale), then grow.
	var start_scale := base_scale
	if start_scale == Vector2.ZERO:
		start_scale = _control_global_scale(ring_src)
	pulse.scale = start_scale
	if modulate_color is Color:
		var c: Color = modulate_color
		pulse.modulate = Color(c.r, c.g, c.b, 0.9)
	else:
		pulse.modulate = Color(ring_src.modulate.r, ring_src.modulate.g, ring_src.modulate.b, 0.9)
	## Match the live ring's screen center, then expand around it.
	var sz: Vector2 = pulse.size
	if sz == Vector2.ZERO:
		sz = ring_src.size
	if sz == Vector2.ZERO:
		sz = Vector2(251, 251)
	pulse.global_position = at_center - sz * start_scale * 0.5
	var expand := maxf(pulse_scale_mult, 1.0)
	var end_scale := start_scale * expand
	var dur := maxf(pulse_duration, 0.05)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(pulse, "scale", end_scale, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(pulse.queue_free)


func _update_planted_crosshairs(delta: float) -> void:
	if _planted_crosshairs.is_empty():
		return

	var weapon = _weapon_for_plants()
	var i := 0
	while i < _planted_crosshairs.size():
		var entry: Dictionary = _planted_crosshairs[i]
		var plant: Control = entry.get("node")
		if plant == null or not is_instance_valid(plant):
			_planted_crosshairs.remove_at(i)
			continue
		if bool(entry.get("dissipating", false)):
			i += 1
			continue

		entry["age"] = float(entry.get("age", 0.0)) + delta
		if float(entry["age"]) >= float(entry.get("lifetime", 7.0)):
			_dissipate_planted_crosshair(i, true, "timeout")
			continue

		if not bool(entry.get("armed", true)):
			if float(entry["age"]) >= float(entry.get("arm_delay", 1.5)):
				entry["armed"] = true
				entry["rotating"] = true
				_play_planted_sfx(2)
				var arm_tween := create_tween()
				arm_tween.tween_property(plant, "modulate", PLANTED_ARMED_MODULATE, PLANTED_ARM_FLASH_SEC)
			else:
				_planted_crosshairs[i] = entry
				i += 1
				continue

		if bool(entry.get("rotating", false)):
			plant.rotation_degrees += float(entry.get("rotation_speed", 120.0)) * delta

		if weapon and weapon.has_method("get_targets_in_scope"):
			var aim: Vector2 = entry.get("aim", plant.global_position)
			var radius: float = float(entry.get("radius", 60.0))
			var hits: Array = weapon.get_targets_in_scope(aim, radius, false)
			if not hits.is_empty():
				var hit_target = hits[0].get("target")
				if is_instance_valid(hit_target) and weapon.has_method("apply_planted_scope_hit"):
					weapon.apply_planted_scope_hit(hit_target, aim)
				_dissipate_planted_crosshair(i, true, "trigger")
				continue

		_planted_crosshairs[i] = entry
		i += 1


func _dissipate_planted_crosshair(index: int, animate: bool, reason: String = "timeout") -> void:
	if index < 0 or index >= _planted_crosshairs.size():
		return
	var entry: Dictionary = _planted_crosshairs[index]
	var plant: Control = entry.get("node")
	_planted_crosshairs.remove_at(index)
	if plant == null or not is_instance_valid(plant):
		return

	entry["rotating"] = false
	plant.rotation = plant.rotation

	if not animate:
		plant.queue_free()
		return

	if reason == "trigger":
		_play_planted_sfx(3)
	else:
		_play_planted_sfx(4)

	var plant_ring := plant.get_node_or_null("RingTexture") as Control
	var pulse_center: Vector2 = plant.get_global_rect().get_center()
	var pulse_base_scale: Vector2 = Vector2.ONE
	if plant_ring:
		pulse_center = plant_ring.get_global_rect().get_center()
		pulse_base_scale = _control_global_scale(plant_ring)
	_spawn_outer_ring_pulse(
		pulse_center,
		pulse_base_scale,
		float(entry.get("pulse_scale", 2.8)),
		float(entry.get("pulse_duration", 0.4))
	)

	entry["dissipating"] = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(plant, "modulate:a", 0.0, 0.22)
	tween.tween_property(plant, "scale", plant.scale * 1.15, 0.22)
	tween.chain().tween_callback(plant.queue_free)


func duplicate_inner_scope() -> void:
	plant_crosshair_trap()


func set_targeting_state(_is_targeting: bool) -> void:
	## Live lock-ons are driven by _update_target_laser_dots (one dot per rock in scope).
	pass
