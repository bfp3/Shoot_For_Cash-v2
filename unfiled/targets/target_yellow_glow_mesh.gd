extends MeshInstance3D

var glowMaterial
var pulseSpeed = 0.05  # Adjust the speed of the pulsation
var minEmission = 0.001  # Adjust the minimum emission value
var maxEmission = 0.1 # Adjust the maximum emission value
var pulseDirection = 1  # 1 for increasing, -1 for decreasing

func _ready():
	glowMaterial = self.material_override

func _process(delta):
	# Calculate the new emission value
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

	# Update the material's emission
	glowMaterial.emission_energy_multiplier = currentEmission
