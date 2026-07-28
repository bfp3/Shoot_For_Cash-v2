extends CanvasLayer
@export var splash_control: Control


func start() -> void:
	splash_control.enter_state(splash_control.State.START)
