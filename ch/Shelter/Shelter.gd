extends Node3D

@onready var door = $RigidBody3D2
@onready var hinge = $Hinge
@onready var textLabel = $Control/Text

var isOpening = false

func _ready():
	textLabel.visible = false
#	hinge.angular_limit.enable = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
#	$Lights/RotatingLight.rotate_y(delta/2)
#	if isOpening and hinge.angular_limit/upper < 90.0:
#		hinge.angle += 45.0 * delta  # Adjust the speed of the door rotation here
#	elif not isOpening and hinge.angular_limit/lower > 0.0:
#		hinge.angle -= 45.0 * delta

	
func _input(event):
	if event.is_action_pressed("enterButton"):
		if textLabel.visible:
			isOpening = not isOpening
			textLabel.visible = false

func _on_area_3d_body_entered(body):
	if "player" in body.name:
		pass
#		textLabel.visible = true
#		textLabel.text = "Shoot to open"


func _on_area_3d_body_exited(body):
	pass
#	textLabel.visible = false
