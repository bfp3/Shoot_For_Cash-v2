extends RigidBody3D

const SPEED = 50
@onready var timer = $Timer
@onready var rayCast = $RayCast3D

func shoot(paramTransform):
		
	transform = paramTransform
#
	apply_impulse(transform.basis.z * -SPEED * 2)
#
#	$BulletTracer.init(Vector3.ZERO, Vector3(0,0,1))
#
func cleanUp():
	queue_free()
	
func _on_timer_timeout():
	cleanUp()
