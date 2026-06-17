extends RigidBody3D

@onready var hitSound = $hitSound
@onready var countdown_sfx = $countdownSFX
@onready var pop_sfx = $popSFX


var hit = false

func _ready():
	$CollisionShape3D2.disabled = true
	self.visible = false
	self.freeze = true
	$bulletHole.visible = false
	start()
	
func start():
	beep(0)
	
func beep(numberOfBeeps):
	
	for i in range(numberOfBeeps):
		countdown_sfx.play()
#		await get_tree().create_timer(1.15).timeout
	
	$CollisionShape3D2.disabled = false
	pop_sfx.play()
	self.visible = true
	self.freeze = false
	

func _on_body_entered(body):
	
#	var counterNode = get_node("../Sandbox4/Counter")
	
	if hit:
		return

	if "bullet" in body.name:
		lock_rotation = false
		$bulletHole.global_position = body.global_position
		$bulletHole.global_position.z -= -0.246
		$bulletHole.visible = true

		hit = true

		hitSound.play()
		body.cleanUp()

#		get_parent().get_parent().targetHit(self)	#target generator code

#		apply_impulse(body.position, Vector3.ZERO)

#		get_parent().get_parent().get_parent().find_child("Counter").addScore()
		
		await get_tree().create_timer(2).timeout

		queue_free()
