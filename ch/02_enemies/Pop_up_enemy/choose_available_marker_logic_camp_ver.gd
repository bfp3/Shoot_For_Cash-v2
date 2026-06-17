extends Node


@onready var parent := $"../.."
var last_marker_index := -1  # Start before the first marker

func get_available_marker() -> Marker3D:
	var popper_camp = parent.get_parent()
	var markers_parent: Node = popper_camp.get_node("Poppers_markers") if popper_camp.has_node("Poppers_markers") else null

	if markers_parent == null:
		print("No marker group found.")
		return null

	var children := markers_parent.get_children()
	var total := children.size()
	
	if total == 0:
		print("No marker children found.")
		return null

	# Start searching from the next index, loop around
	for i in range(total):
		var index := (last_marker_index + 1 + i) % total
		var child = children[index]

		if child is Marker3D and !child.is_occupied:
			last_marker_index = index
			return child

	print("No available markers found.")
	return null


func free() -> void:
	return
	
	var popper_camp = parent.get_parent()  # This gets Popper_Camp_X
	if popper_camp.has_node("Poppers_markers"):
		popper_camp.free_markers()
	parent.current_marker.is_occupied = false
	parent.current_marker = null
