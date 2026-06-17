extends RigidBody3D

var target_hit := false
@export var magnitude := 1.2
var hit_by_bullet := false

func _ready() -> void:
	EventBus.instance.egg_pulsed.connect(full_range)


func create_smoke_screen_timer() -> void:
	var timer = Timer.new()
	add_child(timer)
	$Mesh/Bomb_mesh/AnimationPlayer.play('glowing')
	

func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property(%Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished
	destroy_self()


func destroy_self() -> void:
	var hit_sound : AudioStreamPlayer = %hitSound
	if hit_sound == null: return
	hit_sound.reparent(get_tree().get_current_scene())
	hit_sound.play_sound()
	shake_camera_on_impact()
	self.queue_free()


func shake_camera_on_impact() -> void:
	var player_cam = get_tree().get_first_node_in_group('player_cam')
	var distance_from_player = global_position.distance_to(player_cam.global_position)
	player_cam.shake_camera_based_on_position(distance_from_player)

func smoke_particles() -> void:
	var new_particles : GPUParticles3D
	if !hit_by_bullet:
		new_particles = %Smoke_quick
	else:
		new_particles = %Smoke_quick2
		
	if new_particles:
		new_particles.add_to_group("smoke_particles")
		new_particles.emitting = true
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		new_particles.global_position = global_position


func _on_area_3d_area_entered(area: Area3D) -> void:
	
	if area.is_in_group('bullet') && !target_hit:
		hit_by_bullet = true
		EventBus.instance.rock_destroyed.emit()
		if area.has_method('cleanUp'):
			area.cleanUp()

		target_hit = true
		self.freeze = true
		was_hit_tween()
		return

func full_range() -> void:
	var x_variation = randf_range(-1.0, 1.0)
	var z_variation = randf_range(-1.0, 1.0)
	var upward_force = randf_range(7.0, 10.0)
	var impulse = Vector3(x_variation, upward_force, z_variation) * magnitude
	apply_central_impulse(impulse)
