extends Control

var activated := false


func start() -> void:
	if activated:
		return
		
	activated = true
	show()
	await get_tree().create_timer(0.1).timeout
	$perfectScoreParticles.emitting = true
