extends Node3D

var targetInstance = load("res://environmentAssets/target.tscn")

enum {STATE_BEGIN, STATE_MIDDLE, STATE_END, STATE_CURRENT}
var gsState = STATE_BEGIN
var giTargetsTotal:int = 0
var giTargetsLeft:int = 0

func _ready():
	sceneChange(STATE_BEGIN)

func sceneChange(state):
	
	if state != STATE_CURRENT:
		gsState = state
	
	match gsState:
		
		STATE_BEGIN:
			targetSetCreate(1, Vector3(-10, 1, -20), Vector3(10, 5, -10))
			gsState = STATE_MIDDLE
		
		STATE_MIDDLE:
			targetSetCreate(2, Vector3(-10, 1, -20), Vector3(10, 5, -10))
		
		STATE_END:
			targetSetCreate(3, Vector3(-10, 1, -20), Vector3(10, 5, -10))

func targetSetCreate(n, min_position, max_position):	

	var newTarget
	
	for i in range(n):
		
		var random_x = randf() * (max_position.x - min_position.x) + min_position.x
		var random_y = randf() * (max_position.y - min_position.y) + min_position.y
		var random_z = randf() * (max_position.z - min_position.z) + min_position.z
		
		newTarget = targetInstance.instantiate()
		newTarget.global_position = Vector3(random_x, random_y, random_z)
		newTarget.rotation_degrees.y = 180
		
		add_child(newTarget)

	giTargetsLeft = n

func targetHit(target):
	
	giTargetsLeft -= 1
	giTargetsTotal += 1

	if giTargetsTotal == 6:
		sceneChange(STATE_END)
	
	elif giTargetsLeft == 0:
		sceneChange(STATE_CURRENT)
