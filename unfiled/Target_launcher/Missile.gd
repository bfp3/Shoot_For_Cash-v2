extends CharacterBody3D

var target: Node3D
var move_speed = 50.0
var exploded = false

var face_target_y
var face_target_x

var started_moving := false

func setup(_target, _move_speed, turn_speed):
	target = _target
	move_speed = _move_speed
	face_target_y = $FaceTargetY
	face_target_x = $FaceTargetY/FaceTargetX
	face_target_y.turn_speed = turn_speed
	face_target_x.turn_speed = turn_speed

func _physics_process(delta):
	if !is_instance_valid(target):
		return

	started_moving = true
	
	var target_pos = target.global_position
	face_target_y.face_point(target_pos, delta)
	face_target_x.face_point(target_pos, delta)

	var move_dir = -$FaceTargetY/FaceTargetX/DirRef.global_transform.basis.z.normalized()
	velocity = move_dir * move_speed
	
	if !is_instance_valid(target) && started_moving: 
		explode()
		
		
	move_and_slide()

func explode():
	if exploded:
		return
	exploded = true
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	$Graphics/TrailParticles.emitting = false
	$ExplosionParticles.restart()
	$Graphics/Rocket.hide()
	$DeleteTimer.start()
