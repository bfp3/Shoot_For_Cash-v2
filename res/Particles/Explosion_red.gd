extends Node3D

@onready var explosion_sfx: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx
@onready var explosion_sfx_2: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx2

@onready var explosion_sfx_3: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx3
@onready var area_3d: Area3D = $Explosion_particles/Area3D

@onready var fire: GPUParticles3D = $Explosion_particles/Fire
@onready var smoke: GPUParticles3D = $Explosion_particles/Smoke
@onready var smoke_2: GPUParticles3D = $Explosion_particles/Smoke2

@onready var dirt_hole: Node3D = $Dirt_hole

@onready var explosion_csg = $Explosion_csg
@export var holes_in_ground_bool := true
var number_of_craters := 1
var blast_radius : float # = 100.0

#signal explosion

func _ready() -> void:	
	#randomize_decal_sizes_and_rotations()

	$Test_Mesh.visible = false
	$Test_Mesh.queue_free()
	dirt_hole.queue_free()
	smoke_2.emitting = true
	fire.emitting = true
	smoke.emitting = true
	explosion_sfx.play()
	explosion_sfx_2.play()
	explosion_sfx_3.play()
	#dirt_hole.visible = true
	
	$Explosion_csg.visible = false


	#create_hole_in_floor_mesh()

func create_hole_in_floor_mesh() -> void:

	var new_crater = explosion_csg.duplicate()
	explosion_csg.radius = (blast_radius/2)

	if number_of_craters >= 2:
		$Explosion_csg.visible = true
		new_crater.visible = true
		var hole_in_ground = get_tree().get_first_node_in_group('floor_prototype_mesh')
		explosion_csg.reparent(hole_in_ground)
		new_crater.reparent(hole_in_ground)

	else:
		$Explosion_csg.visible = true
		var hole_in_ground = get_tree().get_first_node_in_group('floor_prototype_mesh')
		explosion_csg.reparent(hole_in_ground)
		explosion_csg.global_position.y = -explosion_csg.height/2 + 20
	
	explosion_area()
	
func explosion_area() -> void:
	print(blast_radius)
	if blast_radius >= 1:
		var collision_shape = CollisionShape3D.new()
		area_3d.add_child(collision_shape)
		collision_shape.shape = SphereShape3D.new()
		
		collision_shape.shape.radius = blast_radius / 2
		await get_tree().create_timer(0.05).timeout
		collision_shape.shape.radius = blast_radius / 20
		area_3d.monitoring = false
		area_3d.monitorable = false
	
	else:
		var collision_shape = CollisionShape3D.new()
		area_3d.add_child(collision_shape)
		collision_shape.shape = SphereShape3D.new()
		
		collision_shape.shape.radius = 35
		await get_tree().create_timer(0.05).timeout
		collision_shape.shape.radius = blast_radius / 20
		area_3d.monitoring = false
		area_3d.monitorable = false
	
	
		
func randomize_decal_sizes_and_rotations() -> void:
	randomize()
	var rand_size_circle = randi_range(20, 100)
	#var rand_size_noise_texture = randi_range(100, 300)
	$Dirt_hole/Circle_decal.size = Vector3(rand_size_circle, 12, rand_size_circle)
	#$Dirt_hole/Noise_texture.size = Vsector3(rand_size_noise_texture, 12, rand_size_noise_texture)
	
	$Dirt_hole/Circle_decal.rotation_degrees.y = randi_range(0, 360)
	#$Dirt_hole/Noise_texture.rotation_degrees.y = randi_range(0, 360)
	
	
func _on_timer_timeout() -> void:
	#$Explosion_particles.queue_free()
	queue_free()

#
#func _on_area_3d_body_entered(body: Node3D) -> void:
	#if body.is_in_group("Player") or body.is_in_group("Friendly_tank") or body.is_in_group("Enemy"):
		#print(body.name)
		#body.die(10)
		#
	#if body.is_in_group("Watchtower"):
		#body.die()
