extends Area3D

@onready var gpu_particles_3d: GPUParticles3D = $GPUParticles3D
@onready var splash_sfx_01: AudioStreamPlayer = $splash_sfx_01
@onready var splash_sfx_02: AudioStreamPlayer = $splash_sfx_02
@onready var sfx_array : Array = [splash_sfx_01,splash_sfx_02]
var detected_bodies: Array[Node3D] = []

func _ready() -> void:
	disable_edge_zone()

func _on_body_entered(body: Node3D) -> void:
	return
	#if body.is_in_group('pineapple'):
		#print('yes that is a pineapple')
		#body.hit_out_of_bounds()
		#splash_particles(body)
		#splash_sfx()
		#gl_PlayerState.log_rock_missed()
		#body.enter_state(RockInstance.State.MISSED)
	
	#%Player_health.take_damage()

func activate_edge_zone() -> void:
	$CollisionShape3D.disabled = false
	$CollisionShape3D2.disabled = false
	$CollisionShape3D3.disabled = false
	
	self.monitorable = true
	self.monitoring = true
	
func disable_edge_zone() -> void:
	$CollisionShape3D.disabled = true
	$CollisionShape3D2.disabled = true
	$CollisionShape3D3.disabled = true
	
	self.monitorable = false
	self.monitoring = false
	
#func reset_detected_bodies() -> void:
	#var tween = create_tween()
	#tween.tween_property($Visual, 'transparency', 1.0, 2.0)
	#monitoring = false
	#monitorable = false
	#detected_bodies.clear()
	#
	#
#func activate_splash_zone() -> void:
	#monitoring = true
	#monitorable = true
	#var tween = create_tween()
	#tween.tween_property($Visual, 'transparency', 0.0,1.0)

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
