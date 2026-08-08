extends RigidBody3D

#@onready var hitSound = $hitSound
#@onready var pop_sfx = $popSFX
#@onready var green_target = $green2
#
#var fadeDuration = 3.0
#var processDelta = 0.0
#var fading = false
#var score = 0
#
#func _ready():
	#green_target.material_override = green_target.material_override.duplicate()
#
#func _physics_process(delta):
	#processDelta = delta
#
#func _on_body_entered(body):
	#
	#if "bullet" in body.name:
		#GameManager.score +=1
		#axis_lock_angular_z = false
#
		#apply_impulse(body.position, Vector3(0,0.05,0))
		#hitSound.play()
		#body.cleanUp()
		#
		#fade_away(green_target)
#
#func fade_away(targetMesh):
	#fading = true
	#var timer = 0.0
	#var startColor = green_target.material_override.albedo_color
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
		#emit_signal("mine_hit")
