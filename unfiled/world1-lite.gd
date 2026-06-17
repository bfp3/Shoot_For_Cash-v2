extends Node3D

@onready var tallBase = $tallBaseContainer/tallBase

func _ready():
#	GenerateWalls.makeWalls(12, 28)
	$SFX/OasisSong.playing = false
	GameManager.powerPoints += 300

func _process(delta):
	
	if GameManager.mine >= 1:
		$Gate_simplified/Geometry/TrapDoor2.use_collision = false
		$Gate_simplified/Geometry/TrapDoor2.visible = false
		$floor3/foreground/CollisionShape3D.disabled = true

		await get_tree().create_timer(3.0).timeout
		
		$Gate_simplified/Geometry/TrapDoor2.use_collision = true
		$Gate_simplified/Geometry/TrapDoor2.visible = true
		$floor3/foreground/CollisionShape3D.disabled = false
	
	if GameManager.score == 1:
		$SFX/OasisSong.playing = false
		$SFX/WindSFX.playing = false
		
