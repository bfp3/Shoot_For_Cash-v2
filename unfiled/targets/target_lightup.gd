extends MeshInstance3D

#var lightScene = load("res://200_characters/targets/target_lightup.tscn")
#var lightInstance = lightScene.instantiate()
#
#func _ready():
	#
	#lightInstance.material_override.albedo_color = Color(1,1,1,1)
	#lightInstance.material_override.emission = lightInstance.material_override.albedo_color
	#add_child(lightInstance)
	#lightInstance.visible = false
	#
#
#
#func _process(delta):
	#pass
#
	#
#func changeTargetColorHit():
	#var targetLightup = get_node("target_lightup")
	#
	#if targetLightup.material_override.albedo_color == Color(1,1,1,1):
		#targetLightup.material_override.albedo_color = Color(Color.GREEN, 1.0)
#
#
#func changeTargetColorFail():
	#var targetLightup = get_node("target_lightup")
	#
	#if targetLightup.material_override.albedo_color == Color(1,1,1,1):
		#targetLightup.material_override.albedo_color = Color(Color.RED, 1.0)
