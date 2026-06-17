extends RigidBody3D

@onready var hitSound = $hitSound
@onready var pop_sfx = $popSFX
@onready var yellow: MeshInstance3D = $Mesh/yellow
@onready var green: MeshInstance3D = $Mesh/green
@onready var blue: MeshInstance3D = $Mesh/blue
@onready var red: MeshInstance3D = $Mesh/red


func _ready():
	#setInvisible()
	#randomTargetColour()
	pop_sfx.play()
	$bulletHole.visible = false
	
#func _physics_process(delta):
	#
	#var force_value = 0.00               #0.008
	#var current_velocity = get_linear_velocity()
#
	#if current_velocity.x > 0:
		#apply_impulse(Vector3(force_value, 0, 0), Vector3(force_value, 0, 0))
	#elif current_velocity.x < 0:
		#apply_impulse(Vector3(-force_value, 0, 0), Vector3(-force_value, 0, 0))


func setInvisible():
	yellow.visible = false
	green.visible = false
	red.visible = false
	blue.visible = false
	
func randomTargetColour():
	var colorNodes = [blue]		#yellow, green, blue
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
	return
	#if "bucket" in body.name:
		#axis_lock_linear_z = false
		#axis_lock_angular_x = false
		#axis_lock_angular_y = false
		#physics_material_override.bounce = 0
		#
#
	#if "bullet" in body.name:
		#var targetColour = checkTargetColour()
		##PowerCounter.adjustPowerByTargetColour(targetColour)
		#axis_lock_linear_z = false
		#axis_lock_angular_x = false
		#axis_lock_angular_y = false
		#
##		$bulletHole.global_position = body.global_position
##		$bulletHole.global_position.z -= -0.246
##		$bulletHole.visible = true
#
##		apply_impulse(Vector3(0,2.05,40), body.position)		#this will make the target spin
		##apply_central_impulse(Vector3(0,2,60))				#this will make the target go backwards with no spin
		#apply_impulse(Vector3(0,2,60))
		#hitSound.play()
		#body.cleanUp()
#		queue_free()



func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group('bullet'):
		GameManager.score += 1
		axis_lock_angular_z = false
		
		# Get the collision position
		var impact_position = body.global_position
		$bulletHole.global_position = impact_position
		$bulletHole.global_position.z += 0.246
		$bulletHole.visible = true

		# Calculate the impulse direction (from bullet to target)
		var impulse_direction = (global_position - impact_position).normalized() * -1  # Adjust force as needed
		
		# Apply impulse at point of impact
		apply_impulse(impulse_direction, impact_position)

		$hitSound.play()
		body.cleanUp()


func _on_exit_sound_finished():
	queue_free()
