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

var _weapon_style_cached := false
var _default_inner_modulate := Color.WHITE
var _default_outer_modulate := Color.WHITE
var _default_line_colors: Dictionary = {}

var _laser_layer: Control
var _laser_pool: Array[TextureRect] = []
var _laser_alpha: Array[float] = []


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
	$Panel.hide()
	_cache_default_weapon_style()
	_setup_target_laser_dots()


func _process(delta: float) -> void:
	_update_target_laser_dots(delta)


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

func _on_shop_entered() -> void:
	if gl_PlayerState.dataset.power_gun == 0:
		return
		
	await get_tree().create_timer(0.85).timeout

	orig_pos = global_position
	%Large_outer_scope.hide()
	$Panel.show()

	var target_pos: Vector2
	if gl_PlayerState.dataset.power_target_circle > 4:
		target_pos = Vector2(1605.0, 212.0)
		$Panel.hide()
	else:
		target_pos = Vector2(1525.0, 212.0)

	global_position = target_pos + Vector2(0, 20) # start slightly lower


	modulate.a = 0.0
	$Inner_scope.modulate.a = 0.0

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "global_position", target_pos, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property($Inner_scope, "modulate:a", 1.0, 0.4)
	
func _on_shop_finished() -> void:
	modulate = Color.TRANSPARENT
	$Inner_scope.modulate = Color('ffffff42')
	global_position = orig_pos
	%Large_outer_scope.show()
	$Panel.hide()

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	await tween.finished


func crosshair_shake() -> void:


	crosshair_inner_tween()
	crosshair_shooting_something()
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
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func crosshair_nothing_to_shoot() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.5 ,0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	#await tween.finished
	
func out_of_ammo_display() -> void:
	#crosshair_nothing_to_shoot()
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

	
func crosshair_fade_out_mode() -> void:
	
	#var outer_scope : Control = %Large_outer_scope
	#var inner_scope : Control = %Inner_scope
	var round_end_label : Label = $OutOfTimeLabel
	
	round_end_label.modulate = Color.TRANSPARENT
	round_end_label.show()
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color('ffffff00'),0.25)
	#tween.tween_property(round_end_label, "modulate", Color('ffffff23'),0.25)
	#tween.tween_property(outer_scope, "modulate", Color('FFFFFF00'),0.25)
	#tween.parallel().tween_property(inner_scope, "modulate", Color('FFFFFF00'),0.25)
	await tween.finished
	
	
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "modulate", Color('FFFFFF00'),0.25)
	#await tween.finished



func duplicate_inner_scope() -> void:
	var original: Control = $Inner_scope
	var _duplicate_scope: Control = original.duplicate()

	# Add it somewhere outside the original hierarchy
	get_tree().current_scene.add_child(_duplicate_scope)

	# Keep it exactly where it currently is
	_duplicate_scope.global_position = original.global_position
	#duplicate.global_rotation = original.global_rotation
	_duplicate_scope.scale = original.scale

	# Make it independent of its parent
	_duplicate_scope.top_level = true

	await get_tree().create_timer(5.0).timeout

	if is_instance_valid(duplicate):
		_duplicate_scope.queue_free()

func set_targeting_state(_is_targeting: bool) -> void:
	## Live lock-ons are driven by _update_target_laser_dots (one dot per rock in scope).
	pass
