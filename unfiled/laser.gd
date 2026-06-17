extends RayCast3D

@onready var beam_mesh = $BeamMesh
@onready var end_particles_top = $EndParticles
@onready var end_particles_bottom = $EndParticles2



func _process(delta):
	var cast_point
	force_raycast_update()
	
	if is_colliding():
		cast_point = to_local(get_collision_point())
		
		beam_mesh.mesh.height = cast_point.y
		beam_mesh.position.y = cast_point.y/2
		
		end_particles_top.position.y = cast_point.y
		end_particles_bottom.position.y = cast_point.y - (cast_point.y)
