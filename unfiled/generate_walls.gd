extends Node3D

var levelScript
var mines_hit = 0
var total_mines = 1
var minePositionY = 1
var spinningPolePositions = []

var colourSand = Color.hex(0xd88f49ff)
var colourWhite = Color.hex(0xff0000ff)


var tallBaseLoad = preload("res://200_characters/environment_decoration/exported_Mesh/tallBase.tscn")
var spinTargetLoad = preload("res://200_characters/targets/target_spinning_pole.tscn")
var mineLoad = preload("res://200_characters/targets/MineFlatShape.tscn")

var tallBase = tallBaseLoad.instantiate()
var spinTarget = spinTargetLoad.instantiate()
var mine = mineLoad.instantiate()

func generateSpinningPolesAndSpheres(count):
	spinningPolePositions.clear()
	
	for i in range(count):
		var randomPos = randUniquePos()
		
		var spinningPole = spinTarget
		spinningPole.position = randomPos
		add_child(spinningPole)

		var sphere = createSphereBehindPole(randomPos)
		add_child(sphere)
		
func randUniquePos():
	var newPos = randPos()

	var minDistance = 5.0
	for pos in spinningPolePositions:
		var distance = newPos.distance_to(pos)
		if distance < minDistance:
			return randUniquePos()

	return newPos

func createSphereBehindPole(polePosition):
	var sphereContainer = mine
	
	var mineMesh = sphereContainer.get_node("redBaseMesh")
	
	mineMesh.material_override = mineMesh.material_override.duplicate()
	
	sphereContainer.position = polePosition + Vector3(0, minePositionY, 1.5)
	return sphereContainer


func randPos():
	return Vector3(randf_range(10, 15), 2.5, randf_range(64, 65))
	

func ratio100(base, ratio):
	return base * ratio / 100.0

func makeWalls(number, length):
	
	#setting ratios, mesh's, and variables
	const WALL_WIDTH_RATIO = 5
	
	const WALL_HEIGHT_RATIO = 2
	
	const PILLAR_HEIGHT_RATIO = 35
	const PILLAR_LEMGTH_RATIO = 8
	
	const SPACER_LEMGTH_RATIO = 18
	const WALL_TO_WALL_RATIO = 135
	
	var wallW = ratio100(length, WALL_WIDTH_RATIO)
	var wallH = ratio100(length, WALL_HEIGHT_RATIO)
	var pillarH = ratio100(length, PILLAR_HEIGHT_RATIO)
	var pillarL = ratio100(length, PILLAR_LEMGTH_RATIO)
	var spacer = ratio100(length, SPACER_LEMGTH_RATIO)
	var pathWidth = ratio100(length, WALL_TO_WALL_RATIO)

	
	var wallMesh = CSGBox3D.new()
	wallMesh.size = Vector3(wallW, wallH, length)
	wallMesh.position =  Vector3(0, wallH/2, 0)
	wallMesh.use_collision = true
	
	
	var wallMaterial = StandardMaterial3D.new()
	wallMaterial.albedo_color = colourSand
	wallMesh.material_override = wallMaterial


	var pillarMesh = CSGBox3D.new()
	pillarMesh.size = Vector3(wallW, pillarH ,pillarL)
	pillarMesh.position =  wallMesh.position
	pillarMesh.position.y = pillarH/2
	pillarMesh.position.z =  pillarMesh.position.z - length / 2 + pillarL / 2
	pillarMesh.use_collision = true
	pillarMesh.material_override = wallMaterial
	
	var pillarMaterial = StandardMaterial3D.new()
	pillarMaterial.albedo_color = colourSand

	for i in range(number):

		var rightWall = wallMesh.duplicate()
		var rightPillar = pillarMesh.duplicate()
		
		if i > 0:
			rightWall.position.z += i * (length + spacer) + (length / 2)
			rightPillar.position.z += i * (length + spacer) + (length / 2)
		else:
			rightWall.position.z += length / 2
			rightPillar.position.z += length / 2
			
		var leftWall = rightWall.duplicate()
		var leftPillar = rightPillar.duplicate()
		
		leftWall.position.x += pathWidth
		leftPillar.position.x += pathWidth
		
		add_child(rightWall)
		add_child(leftWall)
		add_child(rightPillar)
		add_child(leftPillar)


		if i >= 2:
			tallFramePillars(leftWall.position.x, leftWall.position.z - (spacer/2) - (length/2))
			tallFramePillars(rightWall.position.x, rightWall.position.z - (spacer/2) - (length/2))


func tallFramePillars(posX, posZ):
	var dz = posZ
	var dx = posX
	var dy = 36
	
	for i in range(2):
		var newTallBase = tallBase.duplicate()
		newTallBase.position = Vector3(dx, 12, dz)
		
		if i >= 1:
			newTallBase.position.y = dy
		add_child(newTallBase)

func _on_mine_hit():
	mines_hit += 1


	if mines_hit == total_mines:

		# Reset the minefield (replace with a fresh set of spinning poles and mines)
		reset_minefield()

func reset_minefield():
	generateSpinningPolesAndSpheres(total_mines)
