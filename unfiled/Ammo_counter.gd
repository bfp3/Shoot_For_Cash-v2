extends Control

var max_ammo = 6
var current_ammo = 6

@onready var ammoContainer = $VBoxContainer
@onready var ammoCountLabel = $VBoxContainer/AmmoCountLabel


func _ready():
	updateAmmoLabel()

func updateAmmoLabel():
	ammoCountLabel.text = "remaining: " + str(GameManager.battery)
	
#	if current_ammo == 0:
#		get_node("/root/GameOverScreen").gameOver()


func bulletShot():
	if current_ammo > 0:
		current_ammo -= 1
		updateAmmoLabel()
		

func adjustAmmoByColour(colour):
	
	match colour:
		Color(1, 0, 0):  # Yellow
			current_ammo += 1
		Color(1, 0, 1):  # Blue
			current_ammo = 6
		Color(1, 1, 0):  # Green
			current_ammo -= 1
		Color(0, 0, 1):  # Red
			current_ammo -= 2

		_:
			pass

	if current_ammo > max_ammo:
		current_ammo = max_ammo
	if current_ammo < 0:
		current_ammo = 0

	updateAmmoLabel()
