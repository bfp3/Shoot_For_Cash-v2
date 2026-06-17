extends RigidBody3D

var alarm = true


#func _process(delta):
	#if GameManager.spotted and alarm:
		#alarms()


func alarms():
	alarm = false
	$OmniLight3D.light_energy = 0
	$OmniLight3D.omni_range = 0
	$OmniLight3D.light_color = Color(1, 0, 0, 1)
	$OmniLight3D2.light_energy = 0
	$OmniLight3D2.omni_range = 0
	$OmniLight3D2.light_color = Color(1, 0, 0, 1)



	
	# red lights version 
#	$OmniLight3D.light_energy = 10
#	$OmniLight3D.omni_range = 60
#	$OmniLight3D.light_color = Color(1, 0, 0, 1)
#	$OmniLight3D2.light_energy = 5
#	$OmniLight3D2.omni_range = 30
#	$OmniLight3D2.light_color = Color(1, 0, 0, 1)


	await get_tree().create_timer(11.0).timeout
	reset()
	
	await get_tree().create_timer(4.0).timeout
	alarm = true
	
		
func reset():
	
	$OmniLight3D.light_energy = 1
	$OmniLight3D.omni_range = 6
	$OmniLight3D.light_color = Color(1, 1, 1, 1)
	$OmniLight3D2.light_energy = 1
	$OmniLight3D2.omni_range = 6
	$OmniLight3D2.light_color = Color(1, 1, 1, 1)
