extends OptionButton

var resolution_modes := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	clear()

	# Populate dropdown
	for resolution in resolution_modes:
		add_item("%d x %d" % [resolution.x, resolution.y])

	# Select current resolution if it exists in the list
	var current_size := DisplayServer.window_get_size()

	for i in range(resolution_modes.size()):
		if resolution_modes[i] == current_size:
			select(i)
			break

	item_selected.connect(_on_resolution_selected)


func _on_resolution_selected(index: int) -> void:
	var resolution = resolution_modes[index]

	DisplayServer.window_set_size(resolution)

	print("Resolution changed to: %dx%d" % [resolution.x, resolution.y])
