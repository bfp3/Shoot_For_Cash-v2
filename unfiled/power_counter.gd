extends Control

#@onready var ammoContainer = $MarginContainer/VBoxContainer
#@onready var ammoCountLabel = $MarginContainer/VBoxContainer/AmmoCountLabel
#
#func _ready():
#	updatePower()
#
#func updatePower():
#	ammoCountLabel.text = "Energy remaining: " + str(int(GameManager.powerPoints))
#
#func adjustPowerByTargetColour(colour):
#
#	match colour:
#		Color(1, 0, 1):  # Blue
#			GameManager.powerPoints += 2
#
#		Color(0, 0, 1):  # Red
#			GameManager.powerPoints += 1
#
#		Color(1, 0, 0):  # Yellow
#			GameManager.powerPoints -= 2
#
#		Color(1, 1, 0):  # Green
#			GameManager.powerPoints -= 2
#
#		_:
#			pass
#
#	updatePower()
