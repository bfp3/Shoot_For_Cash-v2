extends Area3D

@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D
@onready var splash_sfx_01: AudioStreamPlayer = $splash_sfx_01
@onready var splash_sfx_02: AudioStreamPlayer = $splash_sfx_02
@onready var sfx_array : Array = [splash_sfx_01,splash_sfx_02]
var detected_bodies: Array[Node3D] = []

@export var round_manager : RoundManager
#func _ready() -> void:
	#await get_tree().create_timer(1.0).timeout
	#monitoring = true
	#monitorable = true 


func _on_body_entered(body: Node3D) -> void:
	if body.name.contains('Balloon'):
		return
	
	if body.is_in_group('pineapple'):
		if body.taken_hit == false:
			return
		gl_PlayerState.log_hit('pineapple', 'pineapple', 0)
		splash_particles(body)
		splash_sfx()
		return
	
	if !(body is RockInstance):
		return

	if body.linear_velocity.y > 0.0:
		splash_sfx()
		return
		
		
	if body.current_state == RockInstance.State.ACTIVE:
		if body.rock_activated == false:
			return
		
		splash_particles(body)
		splash_sfx()

		var missed_rock_type_name : String = body.rock_type_name
		body.rock_activated = false
		body.enter_state(RockInstance.State.MISSED)
		gl_PlayerState.log_rock_missed(missed_rock_type_name)

		if missed_rock_type_name.contains('hazard'):
			return



func reset_detected_bodies() -> void:
	return
	
func deactivate_splash_zone() -> void:
	self.set_deferred('monitoring', false)
	self.set_deferred('monitorable', false)

func activate_splash_zone() -> void:
	self.set_deferred('monitoring', true)
	self.set_deferred('monitorable', true)
	var tween = create_tween()
	tween.tween_property($Visual, 'transparency', 0.0,1.0)

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
