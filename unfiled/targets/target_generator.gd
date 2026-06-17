extends Node3D

var targetInstance = load("res://environmentAssets/target.tscn")
var redTargetInstance = load("res://environmentAssets/redTarget.tscn")
var greenTargetInstance = load("res://environmentAssets/greenTarget.tscn")


enum {STATE_BEGIN, STATE_MIDDLE, STATE_END, STATE_CURRENT}
var gsState = STATE_BEGIN
var giTargetsTotal:int = 0
var giTargetsLeft:int = 0


func start():
	sceneChange(STATE_BEGIN)
		
func sceneChange(state):
	
	if state != STATE_CURRENT:
		gsState = state
	
	match gsState:
		
		STATE_BEGIN:
			targetSetCreate(1, Vector3(-3, 5, -5), Vector3(3, 5, 5))
			gsState = STATE_MIDDLE
			
		
		STATE_MIDDLE:
			targetSetCreate(3, Vector3(-10, 5, -5), Vector3(10, 5, 5))

		
		STATE_END:
			targetSetCreate(6, Vector3(-10, 5, -5), Vector3(10, 5, 5))
			
func targetSetCreate(n, min_position, max_position):

	var newTarget	
	
	for i in range(n):
		
		var random_x = randf() * (max_position.x - min_position.x) + min_position.x
		var random_y = randf() * (max_position.y - min_position.y) + min_position.y
		var random_z = randf() * (max_position.z - min_position.z) + min_position.z
		
		var colourTarget = targetInstance
		if randf() < 0.1:
			colourTarget = redTargetInstance
#		if randf() > 0.999999:
#			colourTarget = greenTargetInstance
		
#		newTarget = colourTarget.instantiate()
#		newTarget.global_position = Vector3(random_x, random_y, random_z)

#		add_child(newTarget)

		#this is how I get the target to face the player's position

		var targetNode = Node3D.new()
		targetNode.global_position = Vector3(random_x, random_y, random_z)

		add_child(targetNode)
		
		var target = colourTarget.instantiate()
		targetNode.add_child(target)
		
		var player = get_parent().get_node("player")
		targetNode.look_at(player.global_position, Vector3(0, 1, 0))
		
		add_child(targetNode)

	giTargetsLeft = n

func targetHit(target):
	giTargetsLeft -= 1
	giTargetsTotal += 1

	if giTargetsTotal >= 6 and giTargetsLeft == 0:
		sceneChange(STATE_END)
	
	elif giTargetsLeft == 0:
		await get_tree().create_timer(1.0).timeout
		sceneChange(STATE_CURRENT)
		

