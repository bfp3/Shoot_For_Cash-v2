extends Node3D

var breathAmplitude : float = 0.01
var breathSpeed : float = 1.2

var originalY : float
var currentY : float
var originalX : float
var currentX : float
var timer : float = 0.0

func _ready():
	originalY = position.y
	currentY = originalY
	originalX = position.x
	currentX = originalX

func _process(delta):

	timer += delta

	currentY = originalY + (sin(timer * breathSpeed) * breathAmplitude)
	position.y = currentY
	
	currentX = originalX + (sin(timer * breathSpeed) * breathAmplitude)
	position.x = currentX
