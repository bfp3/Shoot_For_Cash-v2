extends GPUParticles3D

var duplicate_particles := false

func _ready() -> void:
	pass
		
func connect_signal() -> void:
	var parent_scene = get_tree().current_scene
	self.reparent(parent_scene, true)
	global_transform = global_transform  # Ensure world position stays the same
	one_shot = true
	emitting = false  # Stop emitting new particles
	emitting = true   # Restart emission so one-shot plays out
	duplicate_particles = true
	if duplicate_particles:
		finished.connect(_on_finished)

func _on_finished() -> void:
	if duplicate_particles:
		self.queue_free()
