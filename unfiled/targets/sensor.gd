extends StaticBody3D

@onready var spotted_SFX = $SFX/BeamSpottedSFX
@onready var light_ray_mesh = $securityCamera/LightRayMesh
@onready var anim = $AnimationPlayer
@onready var area_3d = $securityCamera/Area3D

var player : Node = null

func _ready():
	anim.stop()
	spotted_SFX.playing = false

func _process(delta):
	var target_direction: Vector3
	
	if GameManager.player_in_shelter:
		GameManager.is_sensor_affected = false

	if player != null:
		target_direction = (player.global_transform.origin - global_transform.origin + Vector3(0, 3, 0)).normalized()
		look_at(area_3d.global_transform.origin + target_direction, Vector3.UP)



func _on_area_3d_body_entered(body):
	if "player" in body.name:
		player = body
		GameManager.is_sensor_affected = true
		GameManager.spotted = true
		$SFX/staticSound.play()
		$SFX/CleansingProtocol.play()
		

func _on_area_3d_body_exited(body):
	if "player" in body.name:
		player = null
		GameManager.is_sensor_affected = false
		$SFX/staticSound.stop()
		$SFX/CleansingProtocol.stop()
