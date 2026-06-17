extends RigidBody3D


var health := 1
var target_hit := false
var has_been_marked := false
@export var magnitude := 2.0

func _ready() -> void:
	EventBus.instance.egg_pulsed.connect(_on_pulse)

func _on_pulse() -> void:
	apply_central_force(Vector3.UP * magnitude)

func was_hit_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished
	destroy_self()


func destroy_self() -> void:
	var hit_sound : AudioStreamPlayer = %hitSound
	if hit_sound == null: return
	hit_sound.reparent(get_tree().get_current_scene())
	hit_sound.play_sound()
	EventBus.instance.cannonball_destroyed.emit()
	shake_camera_on_impact()
	
	self.queue_free()

func shake_camera_on_impact() -> void:
	var player_cam = get_tree().get_first_node_in_group('player_cam')
	var distance_from_player = global_position.distance_to(player_cam.global_position)
	player_cam.shake_camera_based_on_position(distance_from_player)

func smoke_particles() -> void:
	var new_particles : GPUParticles3D
	new_particles = $Smoke_quick
		
	if new_particles:
		new_particles.add_to_group("smoke_particles")
		new_particles.emitting = true
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		new_particles.global_position = global_position


func _on_area_3d_area_entered(area: Area3D) -> void:
	
	if area.is_in_group('bullet') && !target_hit:
		if !has_been_marked:
			print("has not been marked")
			return
			
		EventBus.instance.rock_destroyed.emit()
		var money_3d_label = get_tree().get_current_scene().get_node_or_null('Money_Label3D')
		if money_3d_label:
			money_3d_label.money_is_money(global_position)

		if area.has_method('cleanUp'):
			area.cleanUp()

		target_hit = true
		
		was_hit_tween()
		
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(%Tile_mesh, "scale", %Tile_mesh.scale * 1.5, 0.33)
		await tween.finished
			
		return


func marking_myself_as_target() -> void:
	has_been_marked = true
