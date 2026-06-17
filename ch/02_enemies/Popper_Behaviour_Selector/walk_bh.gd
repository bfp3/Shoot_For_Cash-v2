extends Node3D

@onready var choose_available_marker_logic: Node = %Choose_available_marker_logic

var walk_tween: Tween = null
var bob_tween: Tween = null
var turn_tween_ref: Tween = null

signal finished
var cancelled : bool


func start(parent : CharacterBody3D) -> void:
	cancelled = false
	start_walk(parent)
	
func cancel() -> void:
	cancelled = true

	if walk_tween and walk_tween.is_running():
		walk_tween.kill()

	if bob_tween and bob_tween.is_running():
		bob_tween.kill()

	if turn_tween_ref and turn_tween_ref.is_running():
		turn_tween_ref.kill()

func _on_finished() -> void:
	finished.emit()

func start_walk(parent : CharacterBody3D) -> void:
	var walk_speed := 3.0
	var bob_amount := 0.2
	var bob_speed := 4.0

	#if parent.current_marker:
		#parent.current_marker.free()
	
	var chosen_marker = choose_available_marker_logic.get_available_marker()
	if chosen_marker == null:
		print_debug("Unable to find a marker for me to move to")
		return

	var target_pos: Vector3 = chosen_marker.global_position

	await get_tree().create_timer(0.1).timeout

	var distance := parent.global_position.distance_to(target_pos)
	var duration := distance / walk_speed
	
	#can use await here if you want delay walk until the turn is complete
	turn_tween(target_pos, parent) 
	
	walk_tween = create_tween()
	walk_tween.tween_property(parent, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN_OUT)
	
	bob_tween = create_tween()
	var bob_cycles := int(duration * bob_speed)
	for i in range(bob_cycles):
		var up_down_time := duration / (bob_cycles * 2.0)
		bob_tween.tween_property(%Mesh, "global_position:y", bob_amount, up_down_time).as_relative()
		bob_tween.tween_property(%Mesh, "global_position:y", -bob_amount, up_down_time).as_relative()

	await walk_tween.finished

	_on_finished()
	
func turn_tween(_target_pos: Vector3, _parent: CharacterBody3D) -> void:
	var duration := 0.5
	var direction = (_target_pos - _parent.global_position).normalized()
	var target_angle = rad_to_deg(atan2(direction.x, direction.z)) + 180.0 #Model is oriented the wrong way 

	var current_angle = _parent.rotation_degrees.y
	var delta_angle = wrapf(target_angle - current_angle, -180.0, 180.0)
	var final_angle = current_angle + delta_angle

	turn_tween_ref = create_tween()
	turn_tween_ref.tween_property(_parent, "rotation_degrees:y", final_angle, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	await turn_tween_ref.finished
