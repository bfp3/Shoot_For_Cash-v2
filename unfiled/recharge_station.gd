extends Node3D

@onready var station_sfx = $SFX/RechargeStationSFX
@onready var recharging_sfx = $SFX/RechargeSoundSFX

func _ready():
	station_sfx.playing = true

func _on_area_3d_body_entered(body):
	if "player" in body.name and GameManager.powerPoints <= 30:
		recharging_sfx.play()
		GameManager.health += 50
		
	else:
		pass
