extends RigidBody3D

@onready var hitSound = $hitSound
@onready var pop_sfx = $popSFX

@onready var yellow = $yellow
@onready var green =$green
@onready var red = $red
@onready var blue = $blue

var score = 0

signal bullet_hit


func _ready():
	$bulletHole.visible = false

func _physics_process(delta):
	self.rotation_degrees.y += 2
	

func _on_body_entered(body):
	return
	if "bullet" in body.name:
		GameManager.score +=1
		axis_lock_angular_z = false
		$bulletHole.global_position = body.global_position
		$bulletHole.global_position.z -= -0.246
		$bulletHole.visible = true


		apply_impulse(body.position, Vector3(0,0.05,0))
		hitSound.play_sound()
		body.cleanUp()

#		get_parent().get_parent().targetHit(self)	#target generator code
#
#		queue_free()

func _on_exit_sound_finished():
	queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group('bullet'):
		GameManager.score +=1
		axis_lock_angular_z = false
		#$bulletHole.global_position = body.global_position
		$bulletHole.global_position.z -= -0.246
		$bulletHole.visible = true

		apply_impulse(body.position, Vector3(0,0.05,0))
		hitSound.play_sound()
		body.cleanUp()
