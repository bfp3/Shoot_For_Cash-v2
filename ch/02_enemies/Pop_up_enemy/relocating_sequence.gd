extends Node

var parent: Node = null

func _ready():
	parent = get_parent()
#
#
#func walk_to_position() -> void:
	#if parent.current_marker:
		#parent.current_marker.is_occupied = false
		#parent.current_marker = null
#
	#var markers_parent := parent.get_tree().get_first_node_in_group("spotter_marker_3d")
	#if markers_parent == null:
		#print("No marker group found.")
		#return
#
	#var marker_list := []
	#for child in markers_parent.get_children():
		#if child is Marker3D and !child.is_occupied:
			#marker_list.append(child)
#
	#if marker_list.is_empty():
		#print("No available markers found.")
		#return
#
	#var chosen_marker: Marker3D = marker_list.pick_random()
	#chosen_marker.is_occupied = true
	#var target_pos: Vector3 = chosen_marker.global_position
#
	#if parent.global_position == target_pos and marker_list.size() > 1:
		#marker_list.erase(chosen_marker)
		#chosen_marker = marker_list.pick_random()
		#target_pos = chosen_marker.global_position
		#chosen_marker.is_occupied = true
#
	#var start_pos = parent.global_position
	#var distance = start_pos.distance_to(target_pos)
	#var duration = distance / parent.walk_speed
#
	#await parent.get_tree().create_timer(0.1).timeout
	#parent.look_at(target_pos, Vector3.UP, false)
#
	#var walk_tween := parent.create_tween()
	#walk_tween.tween_property(parent, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
#
	#var bob_tween := parent.create_tween()
	#var bob_cycles := int(duration * parent.bob_speed)
	#for i in range(bob_cycles):
		#var up_down_time = duration / (bob_cycles * 2.0)
		#bob_tween.tween_property(parent, "global_position:y", parent.bob_amount, up_down_time).as_relative()
		#bob_tween.tween_property(parent, "global_position:y", -parent.bob_amount, up_down_time).as_relative()
#
	#bob_tween.tween_property(parent, "global_position:y", start_pos.y, 0.1)
	#await walk_tween.finished
#
	#parent.global_position.y = target_pos.y
	#parent.current_marker = chosen_marker
	#parent.looking_over_wall_sequence.peeking_over_wall_sequence()
#
#
#func attach_self_to_nearest_marker() -> void:
	#var markers_parent := parent.get_tree().get_first_node_in_group("spotter_marker_3d")
	#if markers_parent == null:
		#print("No marker group found.")
		#return
#
	#var marker_list := []
	#for child in markers_parent.get_children():
		#if child is Marker3D and !child.is_occupied:
			#marker_list.append(child)
#
	#if marker_list.is_empty():
		#print("No available markers found.")
		#return
#
	#marker_list.sort_custom(func(a, b):
		#return parent.global_position.distance_squared_to(a.global_position) < parent.global_position.distance_squared_to(b.global_position))
#
	#var closest_marker: Marker3D = marker_list[0]
	#closest_marker.is_occupied = true
	#parent.current_marker = closest_marker
#
#func add_unique_marker(pos: Vector3) -> void:
	#parent.get_node('Mesh/Unique_marker').global_position = pos
