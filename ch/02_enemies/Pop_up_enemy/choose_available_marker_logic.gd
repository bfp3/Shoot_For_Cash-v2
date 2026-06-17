extends Node

@onready var parent: Poppers = $'..'


func get_available_marker(closest: bool = true) -> Marker3D:
	
	
	
	var markers_parent := get_tree().get_first_node_in_group("spotter_marker_3d")
	if markers_parent == null:
		print("No marker group found.")
		return null
	
	var marker_list := []
	for child in markers_parent.get_children():
		if child is Marker3D and !child.is_occupied:
			marker_list.append(child)
	
	if marker_list.is_empty():
		print("No available markers found.")
		return null
	
	if closest:
		marker_list.sort_custom(func(a, b):
			return parent.global_position.distance_squared_to(a.global_position) < parent.global_position.distance_squared_to(b.global_position)
		)
	else:
		marker_list.shuffle()
	
	return marker_list[0]
