extends Node3D

@onready var tallBase = $tallBaseContainer/tallBase
@onready var player = $"player-v2"
@onready var death_sfx = $SFX/DeathSFX
@onready var fader = $ScreenFade/ColorRect
@onready var missile_spawn = $MissileSpawn
@onready var hovering_cam = $HoveringCam

var missilePreload # preload("res://200_assets/weapons/missile.tscn")
var newMissile #= missilePreload.instantiate()

var missileSpotted = false
var hasDied = false
var deathSound = true


func _ready():
	fadeIn()
#	$SensorContainer/SensorContainer/Sensor1/AnimationPlayer.play("idle")
#	$HoveringCam/SecurityCart/AnimationPlayer.play("driving around")
	newMissile.global_position = missile_spawn.position
	
	add_child(newMissile)
#	$SFX/openingSequence.play()
	
	if GameManager.respawn >= 1:
		fadeIn()
		
	else:
		pass
	
	#GenerateWalls.makeWalls(12, 28)
#	$SFX/OasisSong.playing = false
#	$SFX/WindSFX.playing = false

func _process(delta):
	
	$"Decoration/Level_Layout/Shelter-shell61/SafetyMessage".material_override.uv1_offset.x -= 0.002
	# this starts the death sequence
	if GameManager.spotted:
		handleMissileSpotted()
	
	if hasDied:
		hasDied = false
		dying(delta)
	

func handleMissileSpotted():
	if !missileSpotted:
		
		missileSpotted = true
		newMissile.spotted()
		$SFX/OasisSong.playing = false
		$SFX/WindSFX.playing = false
		
		
	if newMissile.position.y <= 600:
		newMissile.position.y += 1
		
	else:
		newMissile.visible = false
		hasDied = true
		

func dying(delta):
	if deathSound:
		deathSound = false
		
#		await get_tree().create_timer(2.0).timeout		#this controls how much time you have until the missile
		
		death_sfx.playing = true
		
		if GameManager.player_in_shelter == false:
			fadeOut()
			GameManager.respawn += 1
		
		elif GameManager.player_in_shelter == true:
			fadeOutAlive()
			hasDied = false
			GameManager.spotted = false
			missileSpotted = false
			hasDied = false
			deathSound = true
			newMissile.resetSpotted()


func fadeOut():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	await get_tree().create_timer(2.0).timeout
	
	get_tree().reload_current_scene()

func fadeOutAlive():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	fadeIn()
	

func fadeIn():
	
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 0.0, 3.0)


func _on_area_3d_body_entered(body):
	if "bullet" in body.name:
		$SFX/OasisSong.playing = true
