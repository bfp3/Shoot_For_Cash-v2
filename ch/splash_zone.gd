extends Area3D

@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D
@onready var splash_sfx_01: AudioStreamPlayer = $splash_sfx_01
@onready var splash_sfx_02: AudioStreamPlayer = $splash_sfx_02
@onready var sfx_array : Array = [splash_sfx_01,splash_sfx_02]
var detected_bodies: Array[Node3D] = []

#func _ready() -> void:
	#await get_tree().create_timer(1.0).timeout
	#monitoring = true
	#monitorable = true


func _on_body_entered(body: Node3D) -> void:
	# Check if we've already seen this body
	
	if !body is RockInstance:
		return
	
	if body.current_state == body.State.DISABLED:
		return
		
	if body in detected_bodies:
		if body.current_state == body.State.ACTIVE:
			splash_particles(body)
			splash_sfx()
			gl_PlayerState.log_rock_missed()
			#body.reset_rock_back_on()
			body.enter_state(body.State.MISSED)
			print('happenning')
			return
		
	if body.current_state == body.State.ACTIVE:
		if !detected_bodies.has(body):
			detected_bodies.append(body)
			splash_sfx()

func reset_detected_bodies() -> void:

	monitoring = false
	monitorable = false
	detected_bodies.clear()
	
	
func activate_splash_zone() -> void:
	monitoring = true
	monitorable = true

func splash_sfx() -> void:
	var _sfx = sfx_array.pick_random()
	_sfx.pitch_scale = randf_range(0.9,1.0)
	_sfx.play()

func splash_particles(body: Node3D) -> void:
	var particles: GPUParticles3D = gpu_particles_3d.duplicate()

	get_tree().get_current_scene().add_child(particles)
	particles.global_position = body.global_position
	particles.emitting = true

	await get_tree().create_timer(particles.lifetime).timeout
	particles.queue_free()
