extends Node


func start_pulse() -> void:
	$PulseSFX.play()
	EventBus.instance.egg_pulsed.emit()
