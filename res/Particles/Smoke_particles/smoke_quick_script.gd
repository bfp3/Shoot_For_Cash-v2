extends GPUParticles3D

var duplicate_particles := false

func _ready() -> void:
	if duplicate_particles:
		add_to_group("smoke_particles")
	one_shot = true
	
	#finished.connect(_on_finished)

func _on_finished() -> void:
	if duplicate_particles:
		self.queue_free()

func smoke_particles() -> void:
	var new_particles = self #.duplicate()
	if new_particles:
		
		new_particles.add_to_group("smoke_particles")
		new_particles.duplicate_particles = true
		new_particles.emitting = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		#new_particles.global_position = global_position
