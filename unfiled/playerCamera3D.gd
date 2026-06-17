extends Camera3D

#var breathAmplitude : float = 0.01
#var breathSpeed : float = 0.5      
#
#var originalY : float
#var currentY : float
#var timer : float = 0.0
#
#func _ready():
#	originalY = position.y
#	currentY = originalY
#
#func _process(delta):
#
#	timer += delta
#
#	currentY = originalY + (sin(timer * breathSpeed) * breathAmplitude)
#	position.y = currentY
