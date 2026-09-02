extends StaticBody3D
#
#@onready var mineSFX = $mineHitSound
#@onready var redMesh = $redBaseMesh
#@onready var x_mark = $redBaseMesh/xMark
#@onready var x_mark2 = $redBaseMesh/xMark2
#
#var fadeDuration = 3.0
#var processDelta = 0.0
#var fading = false
#
#func _ready():
	#redMesh.material_override = redMesh.material_override.duplicate()
#
#func _process(delta):
	#self.rotate_z(0.03)
	#processDelta = delta
#
#func _on_area_3d_body_entered(body):
	#if "bullet" in body.name:
		#if x_mark != null and x_mark2 != null:
			#x_mark.visible = false
			#x_mark2.visible = false
		#mineSFX.play()
		#GameManager.mine += 1
		#fade_away(redMesh)
		#
#func fade_away(targetMesh):
	#fading = true
	#var timer = 0.0
	#var startColor = redMesh.material_override.albedo_color
	#var endColor = Color(0, 0, 0, 0)
#
	#while timer < fadeDuration:
		#var lerpFactor = timer / fadeDuration
		#var newColor = startColor.lerp(endColor, lerpFactor)
		#targetMesh.material_override.albedo_color = newColor
#
		#await get_tree().create_timer(processDelta).timeout
		#timer += processDelta
		#
	#if targetMesh != null:
		#targetMesh.queue_free()
		#
	#fading = false
	#
	#if is_instance_valid(self):
		#queue_free()
