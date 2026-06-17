extends RigidBody3D

@export var speed: float = 25.0
@export var gravity: float = 0.2  # Gravity strength (used for custom gravity, if needed)
@export var arc_strength: float = 5.0  # How much upward arc is added to the shot
var hit_something: bool = false

func shoot(target_pos: Vector3):
	var direction = (target_pos - global_position).normalized()
	
	# Calculate initial velocity with some upward arc
	var launch_velocity = direction * speed
	launch_velocity.y += arc_strength  # Adds upward velocity component to simulate arc

	# Set the rigidbody's initial velocity
	linear_velocity = launch_velocity
	
	# Optionally apply an impulse (this can be adjusted or removed based on how you want it to behave)
	# apply_impulse(Vector3.ZERO, Vector3(0, arc_strength * strength, 0))  # Impulse only for additional effect

	# Rotate the bullet to face the movement direction
	look_at(target_pos, Vector3.UP)

func _physics_process(delta: float):
	#gravity += 0.01
	#gravity += 0.5
	if $RayCast3D.is_colliding() or $RayCast3D2.is_colliding():
		hit_something = true
		cleanUp()
	if hit_something:
		return
	
	# Apply gravity over time
	linear_velocity.y -= gravity * delta  # Simulates gravity
	#$Mesh.look_at($Marker3D.global_position, Vector3.UP, true)

func _on_body_entered(body: Node):
	hit_something = true
	queue_free()  # Destroy the projectile


func _on_timer_timeout() -> void:
	queue_free()

func cleanUp() -> void:
	_on_timer_timeout()
