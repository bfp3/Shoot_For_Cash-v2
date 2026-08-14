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
		if body.rock_type == RockInstance.RockSize.AVOIDER and not body.avoider_destroys_on_out_of_bounds:
			## Still splash for feedback, but keep the avoider alive.
			splash_particles(body)
			splash_sfx()
			return
		
		splash_particles(body)
		## Soft water splash only for black rocks — no strike sting / OOB hit SFX.
		var missed_rock_type_name : String = body.rock_type_name
		var is_hazard := missed_rock_type_name.contains("hazard")
		if not is_hazard:
			splash_sfx()

		body.rock_activated = false
		## Strike-worthy only — black rocks skip the OOB impact sting.
		if not is_hazard and body.has_method("out_of_bounds"):
			body.out_of_bounds()
		body.enter_state(RockInstance.State.MISSED)

		var rocks_container = null
		if round_manager:
			rocks_container = round_manager.get("rocks_container")
		if rocks_container == null:
			rocks_container = get_tree().get_first_node_in_group("rocks_container")
		if not is_hazard and rocks_container and rocks_container.has_method("set_strike_feedback_origin"):
			rocks_container.set_strike_feedback_origin(body.global_position)

		gl_PlayerState.log_rock_missed(missed_rock_type_name)

		if is_hazard:
			if rocks_container and rocks_container.has_method("check_wave_clear_if_no_live_rocks"):
				rocks_container.call_deferred("check_wave_clear_if_no_live_rocks")
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


func restart() -> void:
	detected_bodies.clear()
	deactivate_splash_zone()
