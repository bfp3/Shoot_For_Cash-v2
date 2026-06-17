extends MeshInstance3D

var glowMaterial
var pulseSpeed = 1
var minEmission = 0.1
var maxEmission = 2
var pulseDirection = 1

func _ready():
	glowMaterial = self.material_override

func _process(delta):
	var currentEmission = glowMaterial.emission_energy_multiplier

	if pulseDirection == 1:
		currentEmission += delta * pulseSpeed
		if currentEmission >= maxEmission:
			currentEmission = maxEmission
			pulseDirection = -1
	else:
		currentEmission -= delta * pulseSpeed
		if currentEmission <= minEmission:
			currentEmission = minEmission
			pulseDirection = 1

	glowMaterial.emission_energy_multiplier = currentEmission
