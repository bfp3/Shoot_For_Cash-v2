extends Node3D


func _on_area_3d_body_entered(body):
	if "player" in body.name:
		GameManager.player_in_shelter = true


func _on_area_3d_body_exited(body):
	if "player" in body.name:
		GameManager.player_in_shelter = false
