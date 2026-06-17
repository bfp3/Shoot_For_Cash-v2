extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	$player/Head/Camera3D.current = true
#	$Camera3D.current = true
#	$Camera3D.fov = 179
#	pass
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
#	$Camera3D.position.z += 0.5

#	$background/eyeOfSauron.position.y +=0.05
#	$mainSky/nightSky.position.x +=0.01
#	$birdContainer.position.x +=1.5
#	$birdContainer2.position.z -=1.5
#	$Trees/Trees9.position.y -= 2

#	Camera effect
#	if $Camera3D.fov >= 75:
#		$Camera3D.fov -= 0.6
#
#	if $Camera3D.position.z >= -22.42:
#		$player/Camera/Camera3D.current = true
		
#	if $birdContainer.position.x >= 600:
#		$birdContainer.position.x = -700
		
#	if $Trees/Trees9.position.y > -5:
##		$Trees/Trees9.position.x = 303
##		$Trees/Trees9.position.y = 100
##		$Trees/Trees9.position.z = -449
##		$Trees/Trees9.position.y -= 2


func _on_timer_timeout():
	$music.play()
