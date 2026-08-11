extends Node3D

@onready var gpu_container: Node3D = $GPU_container


#
#func _ready() -> void:
	#EventBus.instance.game_won.connect(confetti)
	

func confetti() -> void:
	await get_tree().create_timer(2.0).timeout
	if gpu_container == null:
		return
	for i in gpu_container.get_children():
		if i is GPUParticles3D:
			i.emitting = true
			i.show()

func start_confetti() -> void:
	if gpu_container == null:
		return
	for i in gpu_container.get_children():
		if i is GPUParticles3D:
			i.emitting = true
			i.show()

