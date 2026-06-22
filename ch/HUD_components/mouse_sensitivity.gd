extends HSlider

func _ready() -> void:
	min_value = 1.0
	max_value = 10.0
	step = 0.1
	value = 3.0

	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	gl_PlayerState.mouse_sensitivity = new_value
