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

func _ready() -> void:
	set_physics_process(false)
	$Timer.start(3.0)
		
		
func _physics_process(delta):

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
		

func _XXphysics_process(delta):

	if target_node == null:
		$Mesh.look_at(move_direction, Vector3.UP, false)
		global_position += move_direction * current_speed * delta
		$Mesh.rotate_z(20.0 * delta)
	else:
		$Mesh.rotate_z(20.0 * delta)
		current_speed = lerp(current_speed, max_speed, delta * acceleration)
		$Mesh.look_at(move_direction, Vector3.UP, false)
		move_direction = (target_node.global_position - global_position).normalized()

		global_position += move_direction * current_speed * delta

		
func reconfigure_size(_red_bullet_glow_amount : float) -> void:
	var scale_steps : int = int(_red_bullet_glow_amount / 25.0)
	
	# Base size + growth per step
	var new_scale : float = 1.0 + (scale_steps * 0.25)

	$Mesh.scale = Vector3.ONE * new_scale
	
func bullet_setup(_target_node : Node3D, _target_pos : Vector3, red_bullet_glow_amount : float = 0.0) -> void:
	if target_node == null:
		max_speed = 100.0
		current_speed = 100.0
		set_physics_process(true)
		
		return
		
	$Decal.show()
	$Decal.emission_energy = 200.0
	#$Decal.modulate = Color(
		#randf_range(0.2,1.0),
		#randf_range(0.2,1.0),
		#randf_range(0.2,1.0), 
		#1.0)
		
	if red_bullet_glow_amount > 0.0:
		$Decal.show()
		$Decal.emission_energy = red_bullet_glow_amount #200.0
		reconfigure_size(red_bullet_glow_amount)
		
	target_node = _target_node
	target_pos = _target_pos

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
	set_physics_process(true)
	await get_tree().create_timer(0.05).timeout
	
	max_speed = power_bullet_speed

	#max_speed = 200.0





func cleanUp() -> void:
	target_node = null
	$Timer.start(2.0)
	return
	#print('bullet collided with something')
	
	
	#$Mesh.hide()
	##hide()
	#set_physics_process(false)
	#$CollisionShape3D.disabled = true
	#await get_tree().create_timer(2.1).timeout
	#queue_free()



func _on_timer_timeout() -> void:
	cleanUp()
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	cleanUp()
	
