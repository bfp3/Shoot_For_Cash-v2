extends RigidBody3D

@onready var popper_basic: Popper_Behaviour = $'../../..'
@export var ripple_speed := 20.0 # Units per second - higher means faster ripple
@export var magnitude : float = 2.75# popper_basic.pulse_magnitude
@export var full_range_pulse := false
@export var camera_pan := false
@onready var egg : Egg_Cage = get_tree().get_first_node_in_group("Egg_Cage")
var is_jumping := false
var stunned := false

func find_parent_by_group(group_name: String) -> Node:
	var node = get_parent()
	while node:
		if node.is_in_group(group_name):
			return node
		node = node.get_parent()
	return null


func _ready() -> void:
	set_process(false)
	#hide()
	#$CollisionShape3D.disabled = true
	top_level = false

func start_stun(parent : CharacterBody3D) -> void:
	%Mesh.hide()
	global_transform = popper_basic.global_transform
	top_level = true
	
	switch_everything_on()
	
	var x_variation = randf_range(-2.0, 2.0)
	var z_variation = 0.0 #randf_range(-1.0, 1.0)
	var upward_force = randf_range(7.0, 10.0)
	var impulse = Vector3(x_variation, upward_force, z_variation) * magnitude
	apply_central_impulse(impulse)
	apply_torque_impulse(impulse / 4)


func _process(delta: float) -> void:
	if !is_jumping:
		set_process(false)
		
	if is_jumping && self.global_position.y <= popper_basic.global_position.y:
		set_process(false)
		switch_everything_off()
		
	#print(popper_basic.global_position.y)


func tween_back_to_orig() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(%Mesh, "rotation_degrees", Vector3.ZERO, 1.0)
	tween.parallel().tween_property(%Mesh, "position", Vector3.ZERO, 1.0)
	tween.parallel().tween_property(popper_basic, "rotation_degrees", Vector3.ZERO, 1.0)


func crosshair_spotted_me() -> void:
	pass

func switch_everything_off() -> void:
	await get_tree().create_timer(2.0).timeout
	$CollisionShape3D.disabled = true
	freeze = true
	$CollisionShape3D.disabled = true
	popper_basic.global_transform = self.global_transform
	%Mesh.global_transform = popper_basic.global_transform
	await get_tree().create_timer(0.1).timeout
	%Mesh.show()
	hide()
	tween_back_to_orig()
	top_level = false
	global_position = popper_basic.global_position
	rotation_degrees = popper_basic.rotation_degrees
	stunned = false
	is_jumping = false
	$Area3D.monitorable = false
	$Area3D.monitoring = false
	$safeguard_timer.stop()
	await get_tree().create_timer(0.5).timeout
	_on_finished()
	
func _on_finished() -> void:
	get_parent()._on_finished()
	#popper_basic._on_behavior_finished()
	

func switch_everything_on() -> void:
	$CollisionShape3D.disabled = false
	freeze = false
	is_jumping = true
	show()
	stunned = true
	$Area3D.monitorable = true
	$Area3D.monitoring = true
	$safeguard_timer.start()
	
	await get_tree().create_timer(0.5).timeout
	set_process(true)



func _on_area_3d_area_entered(area: Area3D) -> void:
	return
	if area.is_in_group('bullet'):
		var camera : Camera3D = get_tree().get_first_node_in_group('player_cam')
		var player : Player = get_tree().get_first_node_in_group('Player')
		var orig_transform := player.global_transform
		var target_pos = global_position + Vector3(2, 5, -10)
		var target_basis = Basis().looking_at(global_position - target_pos, Vector3.UP)
		var target_transform = Transform3D(target_basis, target_pos)
		
		freeze = true
		if camera_pan:
			await camera_tween(camera, target_transform)

		
		popper_basic.global_transform = global_transform
		popper_basic.global_position = global_position
		popper_basic.show()
		
		self.hide()
		var _pitch = randf_range(0.9,1.15)
		%duck_sfx.pitch_scale
		CommonCode.play_sound_duplicate_instance(%duck_sfx, 0.0, %duck_sfx.volume_db + 5.0)
		await get_tree().create_timer(0.15).timeout
		
		popper_basic.health -= 1
		popper_basic.ev_HitByPlayerBullet()
		
		#%Dying_sequence.die()
		
		
		if camera_pan:
			camera_part_2(camera, orig_transform)
		
		#self.queue_free()


func camera_tween(camera : Camera3D, target_transform : Transform3D) -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera, "global_transform", target_transform, 0.5)
	await tween.finished

	
func camera_part_2(camera : Camera3D, orig_transform : Transform3D) -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera, "global_transform", orig_transform, 0.75)
	await tween.finished


func _on_safeguard_timer_timeout() -> void:
	return
	#print('this was activated _ timer time out')
	#set_process(false)
	#switch_everything_off()
