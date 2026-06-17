extends Node3D

func _on_target_propeller_body_entered(body):
			
	if body is RigidBody3D:
		body.apply_impulse(Vector3(0, 10, 0), Vector3(0, 0, 0))
