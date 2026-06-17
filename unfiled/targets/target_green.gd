extends RigidBody3D

@onready var hitSound = $hitSound
@onready var countdown_sfx = $countdownSFX
@onready var pop_sfx = $popSFX

var hit = false

func _ready():
	pass
#	$CollisionShape3D2.disabled = true
#	self.visible = false
#	self.freeze = true
#	start()
	
func start():
	beep(2)
	
func beep(numberOfBeeps):
	
	for i in range(numberOfBeeps):
		countdown_sfx.play()
		await get_tree().create_timer(1.15).timeout
	
	$CollisionShape3D2.disabled = false
	pop_sfx.play()
	self.visible = true
	self.freeze = false

func _on_body_entered(body):
	var counterNode = get_node("../Sandbox4/Counter")
	
	if hit:
		return

	if "bullet" in body.name:
		hit = true

		hitSound.play()
		body.cleanUp()

#		get_parent().get_parent().get_node("targetGenerator").targetHit(self)

		apply_impulse(body.position, Vector3.ZERO)

#		get_parent().get_parent().get_parent().find_child("Counter").doubleScore()

		await get_tree().create_timer(2).timeout
#
		queue_free()
