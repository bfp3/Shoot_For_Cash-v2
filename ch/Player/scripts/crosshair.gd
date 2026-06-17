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

@onready var up = $Inner_scope/center_container/up
@onready var down = $Inner_scope/center_container/down
@onready var left = $Inner_scope/center_container/left
@onready var right = $Inner_scope/center_container/right

var up_pos_y : float
var down_pos_y : float
var left_pos_x : float
var right_pos_x : float

@export var target_color := Color.ORANGE_RED
@export var default_color := Color.WHITE
@export var transition_speed := 0.05
var orig_pos := Vector2.ZERO


func _ready() -> void:
	modulate = Color.TRANSPARENT
	self.hide()
	await crosshair_fade_out_mode()
	
	EventBus.instance.open_shop.connect(_on_shop_entered)
	EventBus.instance.close_shop.connect(_on_shop_finished)

	up_pos_y = up.position.y
	down_pos_y = down.position.y
	left_pos_x = left.position.x
	right_pos_x = right.position.x
	
#	EventBus.instance.wrapping_up_a_level.connect(_fade_out)
	self.show()
	$Panel.hide()

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

	$Inner_scope4/AnimationPlayer.pause()
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
	await get_tree().create_timer(0.1).timeout
	$Inner_scope4/AnimationPlayer.play('back_forth')
	
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

func cannot_shoot_obstacle_in_way() -> void:
	return
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.BLACK ,0.1)
	tween.parallel().tween_property(self, "rotation", 0.1 ,0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	tween.parallel().tween_property(self, "rotation", -0.1 ,0.1)
	tween.tween_property(self, "rotation", 0.0 ,0.1)


func crosshair_shooting_something() -> void:
	
	%Cooldown_progressBar.hide()
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.ORANGE ,0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func crosshair_nothing_to_shoot() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.5 ,0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	#await tween.finished
	
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




func set_targeting_state(is_targeting: bool) -> void:
	#print("YE")
	return
	#var color = target_color if is_targeting else default_color
	#var large = $Large_outer_scope/center_container
	##var small = $Inner_scope/center_container
	#var small = $Inner_scope/blackTexture
	#
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(small, "modulate", color, transition_speed)
	#tween.parallel().tween_property(large, "modulate", color, transition_speed)
