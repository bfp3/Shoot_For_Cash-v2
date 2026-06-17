extends Area3D

var target_node : Node3D = null
var target_pos : Vector3
var acceleration := 6.0
var current_speed := 30.0
var max_speed := 60.0 #30.0
var rotation_speed := 10.0

var power_bullet_damage := 1
var power_bullet_speed := 30.0
	
var move_direction : Vector3 = Vector3.BACK

var homing_strength := 0.0
var start_homing := true

func _ready() -> void:
	#set_physics_process(false)
	$Timer.start(4.0)
		
		

func _physics_process(delta):
	
	if start_homing:
		homing_strength = lerp(homing_strength, 25.0, delta * acceleration)
	
	if target_node == null:
		global_position += move_direction * current_speed * delta
		return

	if !is_instance_valid(target_node):
		target_node = null
		return

	current_speed = lerp(current_speed, max_speed, delta * acceleration)

	var to_target = (target_node.global_position - global_position).normalized()

	# Smooth steering instead of instant snap
	move_direction = move_direction.slerp(to_target, homing_strength * delta).normalized()

	var distance = global_position.distance_to(target_node.global_position)
	var move_amount = current_speed * delta

	if move_amount >= distance:
		global_position = target_node.global_position
		cleanUp()
		return

	global_position += move_direction * move_amount

	$Mesh.look_at(global_position + move_direction, Vector3.UP)

func XX_physics_process(delta):

	if target_node == null:
		global_position += move_direction * current_speed * delta
		return

	current_speed = lerp(current_speed, max_speed, delta * acceleration)

	var to_target = target_node.global_position - global_position
	var distance = to_target.length()

	move_direction = to_target.normalized()

	var move_amount = current_speed * delta

	# prevent tunneling / overshoot
	if move_amount >= distance:
		global_position = target_node.global_position
		cleanUp()
		return

	global_position += move_direction * move_amount

	$Mesh.look_at(global_position + move_direction, Vector3.UP, false)
		
func reconfigure_size(_red_bullet_glow_amount : float) -> void:
	var scale_steps : int = int(_red_bullet_glow_amount / 25.0)
	
	# Base size + growth per step
	var new_scale : float = 1.0 + (scale_steps * 0.25)

	$Mesh.scale = Vector3.ONE * new_scale
	
func bullet_setup(_target_node : Node3D, _target_pos : Vector3, red_bullet_glow_amount : float = 0.0) -> void:
	#if target_node == null:
		##set_physics_process(true)
		#return

	target_node = _target_node
	target_pos = _target_pos

	#go_straight_and_then_go_to_target()
	#fast_pause_and_instant_bullets()
	quick_and_instant_bullets()
	
	
func fast_pause_and_instant_bullets() -> void:
	max_speed = power_bullet_speed / 100.0  #10.0
	set_physics_process(true)
	await get_tree().create_timer(0.5).timeout
	max_speed = 0.0
	await get_tree().create_timer(0.5).timeout
	max_speed = power_bullet_speed
	#max_speed = 1000.0
	look_at(target_node.global_position, Vector3.UP, true)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(target_node):
		look_at(target_node.global_position, Vector3.UP, true)
	$Mesh/Bullet_mesh.hide()
 
func quick_and_instant_bullets() -> void:
	max_speed = 10.0 #130.0
	homing_strength = 100.0
	set_physics_process(true)
	await get_tree().create_timer(0.05).timeout
	
	max_speed = power_bullet_speed * 10

	#max_speed = 200.0
func go_straight_and_then_go_to_target() -> void:

	set_physics_process(true)

	move_direction = global_transform.basis.z.normalized()

	current_speed = 15.0
	max_speed = power_bullet_speed / 2

	homing_strength = 0.0

	# Phase 1 — straight launch
	await get_tree().create_timer(0.25).timeout

	# Phase 2 — gradual curve begins
	homing_strength = 3.0
	start_homing = true
	await get_tree().create_timer(0.4).timeout

	# Phase 3 — strong lock-on
	homing_strength = 25.0
	max_speed = power_bullet_speed
	
	

func cleanUp() -> void:
	await get_tree().create_timer(0.1).timeout
	target_node = null
	$Timer.start(3.0)
	$Mesh.hide()
	$Trails.emitting = false
	return
	#print('bullet collided with something')
	
	#trails_reparent()
	
	#hide()
	#set_physics_process(false)
	#$CollisionShape3D.disabled = true
	#await get_tree().create_timer(2.1).timeout
	#queue_free()



func _on_timer_timeout() -> void:
	#cleanUp()
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	cleanUp()
	
