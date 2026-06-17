extends Node3D

@onready var gpu_container: Node3D = $GPU_container


#
#func _ready() -> void:
	#EventBus.instance.game_won.connect(confetti)
	

func confetti() -> void:
	pass
	##$RandomSound11.play()
	#await get_tree().create_timer(2.0).timeout
	##$RandomSound1.play()
	##await get_tree().create_timer(0.5).timeout
	#
	#for i in gpu_container.get_children():
		#var new_particles = i
		##new_particles.duplicate_particles = true
		#new_particles.emitting = true
		#new_particles.show()
		
func start_confetti() -> void:
	pass
	#for i in gpu_container.get_children():
		#var new_particles = i
		#new_particles.emitting = true
		#new_particles.show()
		
