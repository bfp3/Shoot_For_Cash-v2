extends RigidBody3D

@onready var hitSound = $SFX/hitSound
@onready var bounce_sfx = $SFX/BounceSFX
@onready var pop_sfx = $SFX/popSFX
@onready var yellow = $yellow
@onready var green =$green
@onready var red = $red
@onready var blue = $blue


func _ready():
	setInvisible()
	randomTargetColour()
	pop_sfx.play()
	$bulletHole.visible = false
	
func _physics_process(delta):
	
	var force_value = -0.12               #0.008
	var current_velocity = get_linear_velocity()

	if current_velocity.x > 0:
		apply_impulse(Vector3(-force_value, 0, 0), Vector3(-force_value, 0, 0))
	elif current_velocity.x < 0:
		apply_impulse(Vector3(force_value, 0, 0), Vector3(force_value, 0, 0))


func setInvisible():
	yellow.visible = false
	green.visible = false
	red.visible = false
	blue.visible = false
	
func randomTargetColour():
	var colorNodes = [red]		#yellow, green
	var randomIndex = randi() % colorNodes.size()
	colorNodes[randomIndex].visible = true

func checkTargetColour():
	
	if yellow.visible:
		return Color(1, 0, 0)
	elif blue.visible:
		return Color(1, 0, 1)
	elif green.visible:
		return Color(1, 1, 0)
	elif red.visible:
		return Color(0, 0, 1)
	else:
		return Color(1, 1, 1)
	pass

func _on_body_entered(body):

	if "bucket" in body.name:
		axis_lock_linear_z = false
		axis_lock_angular_x = false
		axis_lock_angular_y = false
		physics_material_override.bounce = 0
		

	if "bullet" in body.name:
		var targetColour = checkTargetColour()
		#PowerCounter.adjustPowerByTargetColour(targetColour)
		axis_lock_linear_z = false
		axis_lock_angular_x = false
		axis_lock_angular_y = false
		
#		$bulletHole.global_position = body.global_position
#		$bulletHole.global_position.z -= -0.246
#		$bulletHole.visible = true

#		apply_impulse(Vector3(0,2.05,40), body.position)		#this will make the target spin
		apply_central_impulse(Vector3(0,2,60))					#this will make the target go backwards with no spin
		hitSound.play()
		body.cleanUp()
#		queue_free()

	if "target_rolling_blue" in body.name:
			# The red target exploded, apply impulse to the blue target
			var impulse_direction = (body.global_transform.origin - global_transform.origin).normalized()
			body.apply_impulse(Vector3(-20,10,0), (impulse_direction) * 2)
			bounce_sfx.play() 
			

func _on_exit_sound_finished():
	queue_free()
