extends Node3D

@onready var explosion_sfx: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx
@onready var explosion_sfx_2: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx2

@onready var explosion_sfx_3: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx3
@onready var area_3d: Area3D = $Explosion_particles/Area3D

@onready var fire: GPUParticles3D = $Explosion_particles/Fire
@onready var smoke: GPUParticles3D = $Explosion_particles/Smoke
@onready var smoke_2: GPUParticles3D = $Explosion_particles/Smoke2

@onready var dirt_hole: Node3D = $Dirt_hole

#@onready var explosion_csg = $Explosion_csg
@export var holes_in_ground_bool := true
var number_of_craters := 1
var blast_radius : float # = 100.0
var instanced_from_craft := false

#signal explosion

func _ready() -> void:	
	#randomize_decal_sizes_and_rotations()

	$Test_Mesh.visible = false
	$Test_Mesh.queue_free()
	if $Explosion_csg_sphere:
		$Explosion_csg_sphere.queue_free()
	else:
		pass
	dirt_hole.queue_free()
	smoke_2.emitting = true
	fire.emitting = true
	smoke.emitting = true
	explosion_sfx.play()
	explosion_sfx_2.play()
	explosion_sfx_3.play()
	#dirt_hole.visible = true
	if $Explosion_csg:
		$Explosion_csg.visible = false
	else:
		pass

	#if $Explosion_csg:
		#create_hole_in_floor_mesh()
	#else:
		#pass
#
#func create_hole_in_floor_mesh() -> void:
	#
	##var rand_size_circle = randi_range(40, 60)
	##explosion_csg.radius = rand_size_circle
	#var new_crater = explosion_csg.duplicate()
	##explosion_csg.radius = (blast_radius/2)
	#explosion_csg.outer_radius = (blast_radius/2)
	#$Explosion_csg/CSGSphere3D.radius = (blast_radius/3)
	##if explosion_csg.radius >= 323:
		##number_of_craters += 1
		##add_child(new_crater)
		##new_crater.name = "New_Explosion"
		##new_crater.global_position = global_position + Vector3(blast_radius/2,0,blast_radius/2)
	##explosion_csg.global_position.y = global_position.y #+ (blast_radius/2)
	##$Explosion_csg/Circle_decal2.global_position.y = explosion_csg.global_position.y - (blast_radius)
	##var rand_pos = Vector3(global_position.x + randf_range(-20.0,20.0), global_position.y, global_position.z + randf_range(-20.0,20.0))
	#
	##var sub_holes_amount = randi_range(0, 10)
	##
	##for i in sub_holes_amount:
		##randomize()
		##var rand_sub_holes_size = randi_range(100, 200)
		##var new_sub_hole = explosion_csg.duplicate()
		##explosion_csg.add_child(new_sub_hole)
		##new_sub_hole.operation = CSGShape3D.OPERATION_UNION
		##new_sub_hole.radius = rand_sub_holes_size
		##new_sub_hole.global_position = rand_pos
		#
	#if number_of_craters >= 2:
		#$Explosion_csg.visible = true
		#new_crater.visible = true
		#var hole_in_ground = get_tree().get_first_node_in_group('floor_prototype_mesh')
		#explosion_csg.reparent(hole_in_ground)
		#new_crater.reparent(hole_in_ground)
#
	#else:
		#$Explosion_csg.visible = true
		#var hole_in_ground = get_tree().get_first_node_in_group('floor_prototype_mesh')
		#explosion_csg.reparent(hole_in_ground)
	#
	#explosion_area()
	#
#func explosion_area() -> void:
	#
	#var collision_shape = CollisionShape3D.new()
	#area_3d.add_child(collision_shape)
	#collision_shape.shape = SphereShape3D.new()
	#
	#collision_shape.shape.radius = blast_radius / 2
	#await get_tree().create_timer(0.05).timeout
	#collision_shape.shape.radius = blast_radius / 20
	#area_3d.monitoring = false
	#area_3d.monitorable = false
	#
	
		
func randomize_decal_sizes_and_rotations() -> void:
	randomize()
	var rand_size_circle : int = randi_range(20, 100)
	#var rand_size_noise_texture = randi_range(100, 300)
	$Dirt_hole/Circle_decal.size = Vector3(rand_size_circle, 12, rand_size_circle)
	#$Dirt_hole/Noise_texture.size = Vsector3(rand_size_noise_texture, 12, rand_size_noise_texture)
	
	$Dirt_hole/Circle_decal.rotation_degrees.y = randi_range(0, 360)
	#$Dirt_hole/Noise_texture.rotation_degrees.y = randi_range(0, 360)
	
	
func _on_timer_timeout() -> void:
	#$Explosion_particles.queue_free()
	queue_free()


func _on_area_3d_body_entered(_body: Node3D) -> void:
	return
	#if !instanced_from_craft:
		#if body.is_in_group("Player") or body.is_in_group("Friendly_tank") or body.is_in_group("Enemy"):
			#body.die()
			#
		#if body.is_in_group("Watchtower"):
			#body.die()
