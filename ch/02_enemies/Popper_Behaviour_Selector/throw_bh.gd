extends Node3D

var throw_smoke := false
var cancelled := false
var tween_throwing: Tween = null
var speed_of_throw := 0.5

signal finished


func start(parent : CharacterBody3D) -> void:
	cancelled = false
	start_throwing(parent)

func _on_finished() -> void:
	finished.emit()

func cancel() -> void:
	cancelled = true
	if tween_throwing:
		tween_throwing.kill()


func start_throwing(parent : CharacterBody3D) -> void:
	await turn_tween(parent)
	if cancelled:
		return

	tween_throwing = create_tween()
	tween_throwing.tween_property(%Mesh, "rotation_degrees:x", -45.0, 0.2)
	#tween_throwing.parallel().tween_property(popper_root, "global_position:y", -0.2, 0.2).as_relative().set_ease(Tween.EASE_OUT_IN)
	
	tween_throwing.tween_callback(func():
		if not cancelled:
			call_throwing_script(parent)
	)
	
	tween_throwing.tween_interval(0.25)
	tween_throwing.parallel().tween_property(%Mesh, "rotation_degrees:x", 45.0, 0.175)
	#tween_throwing.parallel().tween_property(popper_root, "global_position:y", 0.25, 0.175).as_relative().set_ease(Tween.EASE_IN_OUT)

	#tween_throwing.tween_property(popper_root, "global_position:y", -0.1, 0.1).as_relative().set_ease(Tween.EASE_OUT_IN)
	tween_throwing.parallel().tween_property(%Mesh, "rotation_degrees:x", 0.0, 0.1)

	tween_throwing.tween_interval(speed_of_throw)	
	await tween_throwing.finished

	_on_finished()

func turn_tween(parent : CharacterBody3D) -> void:
	var target_pos: Vector3 = get_tree().get_first_node_in_group('Player').global_position
	var duration := 0.25
	var direction = (target_pos - parent.global_position).normalized()
	var target_angle = rad_to_deg(atan2(direction.x, direction.z)) + 180.0

	var current_angle = parent.rotation_degrees.y
	var delta_angle = wrapf(target_angle - current_angle, -180.0, 180.0)
	var final_angle = current_angle + delta_angle

	var turn_tween = create_tween()
	turn_tween.tween_property(parent, "rotation_degrees:y", final_angle, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	await turn_tween.finished

func call_throwing_script(parent : CharacterBody3D) -> void:
	var throw_projectile_script : Node = get_tree().get_first_node_in_group('Projectile_Manager_Popper')
	if !throw_smoke:
		throw_projectile_script.prepare_rock(parent.get_node('%spawn_projectile_marker').global_position, 'rock')
	else:
		throw_projectile_script.prepare_rock(parent.get_node('%spawn_projectile_marker').global_position, 'smokebomb')


#func fake_mesh_tween() -> void:
	#var orig_pos: Vector3 = %Copy_mesh.global_position
	#var orig_rot: Vector3 = %Copy_mesh.rotation_degrees
	#%Copy_mesh.look_at(parent.egg.global_position, Vector3.UP, false)
	#%Copy_mesh.show()
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(%Copy_mesh, "global_position:y", 0.75, 0.25).as_relative()
	#tween.tween_property(%Copy_mesh, "global_position", orig_pos, 0.25)
	#await tween.finished
	#%Copy_mesh.rotation_degrees = orig_rot
	#%Copy_mesh.hide()
