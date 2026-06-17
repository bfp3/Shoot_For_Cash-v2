extends Node3D

@onready var tallBase = $tallBaseContainer/tallBase
@onready var player = $"player-v2"
@onready var death_sfx = $SFX/DeathSFX
@onready var fader = $ScreenFade/ColorRect
@onready var missile_timer = $MissileTimer
@onready var missile_spawn_1: Marker3D = $MissileSpawn1
@onready var missile_spawn_2: Marker3D = $MissileSpawn2
@onready var missile_spawn = $MissileSpawn


var missilePreload #= preload("res://200_assets/weapons/missile.tscn")
var newMissile = missilePreload.instantiate()

var missileSpotted = false
var hasDied = false
var deathSound = true

# TRIGGERS 
var entered_1 = true
var entered_2 = true
var entered_3 = true
var musicStart = true
var lightSFX = true

var spottedSoundSFX = true
var random_number = randf_range(20, 40)


func _ready():
	
	fadeIn()

	add_child(newMissile)
	newMissile.global_position = missile_spawn.position
	
	missile_timer.wait_time = random_number
	
	$SensorContainer/SensorContainer/Sensor2/AnimationPlayer.play("idle")
	$SensorContainer/SensorContainer/Sensor3/AnimationPlayer.play("idle")
	
	$SensorContainer/SensorContainer2/Sensor1/AnimationPlayer.play("idle")
	$SensorContainer/SensorContainer2/Sensor2/AnimationPlayer.play("idle")
	$SensorContainer/SensorContainer2/Sensor3/AnimationPlayer.play("idle")
	
	$MissilePlatform/MeshInstance3D3/tooBright.visible = true
	
#	$SFX/openingSequence.play()
		
	await get_tree().create_timer(4.0).timeout
	
	$dialogue/Instructions.play()

func _process(delta):
	
	if GameManager.holdPositionAudio && GameManager.player_in_shelter && GameManager.spotted:
		holdYourPosition()
	
	# this starts the death sequence
	if GameManager.spotted:
		$SFX/Alternative.playing = false
		$SFX/WindSFX.playing = false
		
		spottedSound()
		handleMissileSpotted()

	
	if hasDied:
		hasDied = false
		dying(delta)

func _lightSFX():
	if lightSFX:
		lightSFX = false
		$dialogue/light_out.play()

func handleMissileSpotted():
	
	if !missileSpotted:
		missileSpotted = true
		newMissile.spotted()

	if newMissile.position.y <= 500.0:
		newMissile.position.y += 1.5

	else:
		newMissile.visible = false
		GameManager.spotted = false
		hasDied = true
		newMissile.position = missile_spawn.position
		
func spottedSound():
	
	if spottedSoundSFX:
		spottedSoundSFX = false
		$"dialogue/don'tForget".stop()
		$dialogue/goggles_talk.stop()
		$dialogue/Bunker2_reached.stop()
		
		await get_tree().create_timer(2.5).timeout

		$dialogue/head_for_a_bunker.play()
		
		return

func holdYourPosition():
	GameManager.holdPositionAudio = false
	$dialogue/holdYourPosition.play()

func dying(delta):
	
	if deathSound:
		deathSound = false
		death_sfx.playing = true

		
		if GameManager.player_in_shelter == false:
			fadeOut()
			missileSpotted = false
		
		elif GameManager.player_in_shelter == true:
			fadeAlive()
			hasDied = false
			missileSpotted = false
			deathSound = true
			newMissile.resetPosition()

func fadeOut():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	await get_tree().create_timer(4.0).timeout
	
	$dialogue/Dead_van_dialogue.play()
	
	await get_tree().create_timer(3.0).timeout
	
	get_tree().reload_current_scene()

func fadeAlive():
	
	fader.modulate = Color(1,1,1, 1)
	fader.visible = true
		
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 1.0, 3.0)
	
	fadeIn()

	GameManager.holdPositionAudio = true
	GameManager.spotted = false
	GameManager.sirenEnd = false
	spottedSoundSFX = true
	lightSFX = true
	
	

func fadeIn():
	
	var new = fader.create_tween() 
	new.tween_property(fader, "modulate:a", 0.0, 3.0)
	
	
# first sensor
func _on_area_3d__bunker_1_body_entered(body):
		
	if "player" in body.name && entered_1:	
		$dialogue/head_for_a_bunker.stop()
		$dialogue/Bunker2_reached.stop()
		$dialogue/holdYourPosition.stop()
		$dialogue/Instructions.stop()
		$dialogue/goggles_talk.stop()
		
		$"dialogue/don'tForget".play()
		entered_1 = false


# second bunker + goggles
func _on_objective_trigger_body_entered(body):
	
	if "player" in body.name:
		newMissile.global_position = missile_spawn_1.position
	
	if "player" in body.name && entered_2:
		$dialogue/head_for_a_bunker.stop()
		$"dialogue/don'tForget".stop()
		$dialogue/Bunker2_reached.stop()
		$dialogue/holdYourPosition.stop()
		$dialogue/Instructions.stop()
		
		$dialogue/goggles_talk.play()
		entered_2 = false
		
func _on_third_bunker_area_body_entered(body):
	if "player" in body.name && entered_3:
		entered_3 = false
		$triggers/goggles_instructions_trigger/MarkdownLabel.visible = true
		$triggers/goggles_instructions_trigger/MarkdownLabel.text = str("Press [L2] to activate Goggles")

# turn off the distant light
func _on_turned_down_the_lights_body_entered(body):
	if "player" in body.name:
		$MissilePlatform/MeshInstance3D3/tooBright.visible = false
		$Bunker_B/Sensor.visible = true
		$Bunker_B/Sensor/AnimationPlayer.play("RESET")
		newMissile.global_position = missile_spawn.position
		$Lighting/sun2.visible = true

func _on_music_trigger_body_entered(body):
	if "player" in body.name && musicStart:
		$SFX/Alternative.play()
		musicStart = false
		newMissile.global_position = missile_spawn_2.position


func _on_goggles_instructions_trigger_body_exited(body):
	$triggers/goggles_instructions_trigger/MarkdownLabel.visible = false


func _on_missile_timer_timeout():
	GameManager.spotted = true
	missile_timer.wait_time = random_number
	missile_timer.start()
	



func _on_ending_trigger_body_entered(body: Node3D) -> void:
	if "player" in body.name:
		ending()


func ending():
	var endingFade = $EndingFade/ColorRect
	
	var new = endingFade.create_tween()
	
	new.tween_property(endingFade, "modulate:a", 1.0, 3.0)
	
	await get_tree().create_timer(5.0).timeout
	
	get_tree().change_scene_to_file("res://700_2D_nodes_UI/02_level_card_transitions/april_14.tscn")
