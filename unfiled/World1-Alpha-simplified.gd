extends Node3D

@onready var tallBase = $tallBaseContainer/tallBase
@onready var player = $"player-v2"
@onready var death_sfx = $SFX/DeathSFX
@onready var fader = $ScreenFade/ColorRect
@onready var missile_spawn = $MissileSpawn
@onready var hovering_cam = $HoveringCam

var missilePreload = preload("res://200_assets/weapons/missile.tscn")
var newMissile = missilePreload.instantiate()

var missileSpotted = false
var hasDied = false
var deathSound = true

var entered_1 = true
var entered_2 = true
var entered_3 = true
var musicStart = true

var spottedSoundSFX = true

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
		
	await get_tree().create_timer(4.0).timeout
	
	$dialogue/HeadforBunker.play()
	
	
#	GenerateWalls.makeWalls(12, 28)
#	$SFX/OasisSong.playing = false
#	$SFX/WindSFX.playing = false

func _process(delta):
	
	if GameManager.holdPositionAudio && GameManager.player_in_shelter && GameManager.spotted:
		holdYourPosition()
	
	# this starts the death sequence
	if GameManager.spotted:
		
		spottedSound()
		handleMissileSpotted()
		$Decoration/Boundaries/StaticBody3D/GlassRedContainer.visible = true
		$Decoration/Boundaries/StaticBody3D/GlassRight.visible = false
		$Decoration/Boundaries/StaticBody3D/GlassTop.visible = false
		$Decoration/Boundaries/StaticBody3D/GlassLeft.visible = false
	
	if hasDied:
		hasDied = false
		dying(delta)
	

func handleMissileSpotted():
	if !missileSpotted:

		missileSpotted = true
		newMissile.spotted()
		$SFX/OasisSong.playing = false
		$SFX/WindSFX.playing = false

	if newMissile.position.z >= 150:
		newMissile.position.x -= 0.3
		newMissile.position.y += 0.3
		newMissile.position.z -= 1.0
		

	else:
		newMissile.visible = false
		hasDied = true
		newMissile.position = missile_spawn.position
		
func spottedSound():
	if spottedSoundSFX:
		$dialogue/HeadforBunker.stop()
		$dialogue/Bunker1.stop()
		$dialogue/Objective_Van.stop()
		$dialogue/Bunker2_reached.stop()
		
		await get_tree().create_timer(3.5).timeout
		
		$dialogue/head_for_a_bunker.play()
		spottedSoundSFX = false

func holdYourPosition():
	GameManager.holdPositionAudio = false
	$dialogue/holdYourPosition.play()

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
			missileSpotted = false
			deathSound = true
			newMissile.resetSpotted()


func fadeOut():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	await get_tree().create_timer(4.0).timeout
	
	$dialogue/Dead_van_dialogue.play()
	
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func fadeOutAlive():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	fadeIn()
	
	GameManager.sirenEnd = false
	$Decoration/Boundaries/StaticBody3D/GlassRedContainer.visible = false
	$Decoration/Boundaries/StaticBody3D/GlassRight.visible = true
	$Decoration/Boundaries/StaticBody3D/GlassTop.visible = true
	$Decoration/Boundaries/StaticBody3D/GlassLeft.visible = true
	GameManager.holdPositionAudio = true
	GameManager.spotted = false
	
	

func fadeIn():
	
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 0.0, 3.0)
	spottedSoundSFX = true
	GameManager.sirenEnd = false



# first bunker
func _on_area_3d__bunker_1_body_entered(body):
	if "player" in body.name && entered_1:	
		$dialogue/HeadforBunker.stop()
		$dialogue/head_for_a_bunker.stop()
		
		$dialogue/Bunker1.play()
		entered_1 = false


# second bunker + objective
func _on_objective_trigger_body_entered(body):
	if "player" in body.name && entered_2:
		$dialogue/head_for_a_bunker.stop()
		$dialogue/Bunker1.stop()
		$dialogue/Bunker2_reached.stop()
		$dialogue/HeadforBunker.stop()
		$dialogue/holdYourPosition.stop()
		
		$dialogue/Objective_Van.play()
		entered_2 = false


# turn off the distant light
func _on_turned_down_the_lights_body_entered(body):
	if "player" in body.name:
		$Bunker_B2/SpotLight3D2.visible = false
		$Floor/Bridge/Wall.visible = false



func _on_music_trigger_body_entered(body):
	if "player" in body.name && musicStart:
		$SFX/Alternative.play()
		musicStart = false


func _on_third_bunker_area_body_entered(body):
	
	if "player" in body.name && entered_3:
		$dialogue/disarm_launcher.play()
		entered_3 = false
