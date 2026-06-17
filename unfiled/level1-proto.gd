extends Node3D

@onready var ammo_crate_preload = preload("res://300_assets/Ammo/Ammo_pickup.tscn")

@onready var t1 = $targetCreator/targetLoadPoint
@onready var wallContainer = $decoration/wallContainer
@onready var pillarContainer = $decoration/pillarContainer
@onready var wireFrame = $wireFrames/wireFrame
@onready var wireframeContainer = $wireFrames
@onready var tallBase = $tallBaseContainer/tallBase
var colourSand = Color.hex(0xd88f49ff)

signal game_finished

#var backForthModule = load("res://600_scripts/700_misc/backForth.gd")		#come back to this

var newTarget = load("res://200_characters/targets/target_rolling.tscn")

const SWING_RANGE = 2
var gf_swingCount = SWING_RANGE

var right = false
var spawning_ammo := false

const buildingBlocks = 1

@export var play_intro := false

@export var play_dynamic_intro := false
@export var timer_start_time := 600.0

@export var score_to_beat_for_the_level := 801

func _ready():
	
	if play_dynamic_intro:
		$Dynamic_intro_sequence.start()
	
	if play_intro:
		play_intro = false
		%Intro_sequence.prepare_intro_sequence()
		
	else:
		%Intro_sequence.no_intro_sequence()
	
	connect_signals()
	$Lighting/WorldEnvironment.environment.fog_enabled = true

	#await get_tree().create_timer(2.0).timeout
	$GameLoopManager.start_next_phase()
	await get_tree().create_timer(3.0).timeout
	GameManager.score_to_beat_for_the_level = score_to_beat_for_the_level
	#%Target_launcher_operator.pineapple_start_round_loop()
	
	#makeWalls(1, 28)
#	backForthModule.exec()
#	backForthModule.exec(sphereGeneration, 0, 48, 100, 1)


func connect_signals() -> void:
	var level_timer = get_tree().get_first_node_in_group("level_timer")
	if level_timer:
		#level_timer.timed_out.connect(level_completed_sequence)
		level_timer.ammo_countdown_finished.connect(continue_sequence)
		level_timer.ammo_countdown_finished.connect(spawn_ammo_crate)
		
	var hostage_killed : Node3D = get_tree().get_first_node_in_group("Egg_Cage")
	if hostage_killed:
		hostage_killed.hostage_killed_signal.connect(level_failed)
	
	#var ammo_progress_bar : ProgressBar = get_tree().get_first_node_in_group("ammo_drop_progress_bar")
	#if ammo_progress_bar:
		#ammo_progress_bar.ammo_countdown_finished.connect(spawn_ammo_crate)

func spawn_ammo_crate() -> void:
	if spawning_ammo:
		return
		
	spawning_ammo = true
	
	var all_markers = %Target_markers.get_children()
	var inactive_markers = all_markers.filter(func(marker):
		return not marker.is_in_cage  # or marker.some_boolean == false
	)

	if inactive_markers.is_empty():
		return

	var chosen_marker = inactive_markers.pick_random()
	var ammo_crate = ammo_crate_preload.instantiate()
	ammo_crate.parachuting_in = true
	ammo_crate.global_position = chosen_marker.global_position + Vector3(0, 15, 0)
	add_child(ammo_crate)
	await get_tree().create_timer(1.0).timeout
	spawning_ammo = false
	

func continue_sequence() -> void:
	$Level_transitions/continue_sequence.player_survived() 

func level_completed_sequence() -> void:
	return
	game_finished.emit()
	$Level_transitions/level_completed_sequence.start_sequence()
	
func level_failed() -> void:
	print('here twp')
	$Level_transitions/player_failed_sequence.start_sequence_losing()

func _input(event: InputEvent) -> void:

	if Input.is_key_label_pressed(KEY_0):
		game_finished.emit()
	
	if Input.is_key_label_pressed(KEY_TAB):
		$Lighting/WorldEnvironment.environment.adjustment_enabled = !$Lighting/WorldEnvironment.environment.adjustment_enabled

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
#			sphereGeneration(leftWall.position.x, leftWall.position.z - (spacer/2) - (length/2))
#			sphereGeneration(rightWall.position.x, rightWall.position.z - (spacer/2) - (length/2))
#		if i == 2:
#			sphereGeneration(leftWall.position.x, leftWall.position.z - (spacer/2) - (length/2))
#			wireFrames(leftWall.position.x, leftWall.position.z - (spacer/2) - (length/2))
#			wireFrames(rightWall.position.x, rightWall.position.z - (spacer/2) - (length/2))

#func _process(delta):
#
#	if wireframeContainer.position.x >= 0 and !right:
#		wireframeContainer.position.x += 0.01
#
#	if wireframeContainer.position.x >= 2 and !right:
#		right = true
#
#	if right:
#		wireframeContainer.position.x -= 0.01
#
#	if wireframeContainer.position.x <= 0.1:
#		right = false
	
func sphereGeneration(posX, posZ):
	
	var sphere = CSGSphere3D.new()
	sphere.radius = 1.8
	sphere.radial_segments = 36
	sphere.rings = 36
	sphere.position = Vector3(posX,48,posZ)


	var sphereMaterial = StandardMaterial3D.new()
	sphereMaterial.albedo_color = colourSand
	sphere.material_override = sphereMaterial

	add_child(sphere)
	
#	var dz = posZ
#	var dx = posX
	
#	for i in range(1):
#		var newSphere = sphere.duplicate()
#		newSphere.position.x = dx
#		newSphere.position.z = dz
#
#		add_child(newSphere)


func target():
	return
	var nextTarget = newTarget.instantiate()
	nextTarget.position = t1.global_transform.origin
	add_child(nextTarget)
	
	if gf_swingCount > 1:
		t1.position.x = 24
		gf_swingCount -= 1
		
	else:
		t1.position.x = 24
		gf_swingCount += 1


#
#func _input(event):
	#if Input.is_action_just_released("newTarget"):
		#target()
		

func _on_timer_timeout():
	target()
	

func tallFramePillars(posX, posZ):
	var dz = posZ
	var dx = posX
	var dy = 36
	
	for i in range(2):
		var newTallBase = tallBase.duplicate()
		newTallBase.position.x = dx
		newTallBase.position.z = dz
		if i >= 1:
			newTallBase.position.y = dy
		add_child(newTallBase)
		
func wireFrames(posX, posZ):

	
	var width = 4.8
	var scale = 4.0
	wireFrame.scale.x = scale
	width = scale * width
	var dx = posX - (width/2)
	var dy = 5
	var dz = posZ
	
	
	
	for i in range(3):
		var newWireFrame = wireFrame.duplicate()
		newWireFrame.transform.origin.z = dz
		
		newWireFrame.transform.origin.x = dx
		
		newWireFrame.transform.origin.y = dy
		dy += 8
		
#		if i > 4:
#			newWireFrame.transform.origin.x = -dx
#			dy -= 16
#			newWireFrame.transform.origin.y = dy
#			newWireFrame.name = "wireFrame"
		
		get_node("wireFrames").add_child(newWireFrame)

func fence():

	var dz = 30
	var dx = 0
	for i in range(buildingBlocks):
		var newFence = wallContainer.duplicate()
		newFence.transform.origin.z = dz
		dz += 30.0
		
#		if i > 1:
#			newPillar.transform.origin.x = dx

		add_child(newFence)
		
func pillars():
	var dz = 30
	var dx = 0
	for i in range(buildingBlocks):
		var newPillar = pillarContainer.duplicate()
		newPillar.transform.origin.z = dz
		dz += 30
		if i > 1:
			newPillar.rotation_degrees.y += -10
		
#		if i % 4 == 0 and i > 0:
#			dx -= 10
#		newPillar.transform.origin.x = dx
			
		add_child(newPillar)
#
#func calcHorizonDrop(z):
#	const R = 6371000
#	return  snappedf( sqrt( (R * R) - (z * z) ) - R, .001)


#	fence()
#	pillars()
