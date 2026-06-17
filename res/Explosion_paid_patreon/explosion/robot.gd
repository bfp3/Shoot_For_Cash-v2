extends Node3D

var meshInst = MeshInstance3D
var matInst = Material

@export var emissionCurve : Curve
@export var resetCurve : Curve
@export var emissionColorRamp : Gradient 
@export var resetColorRamp : Gradient 

func _ready():
	meshInst = $GFX
	
	var originalMat = meshInst.get_active_material(0)
	matInst = originalMat.duplicate(true)
	matInst.emission_enabled = true
	setEmission(0.0, Color(0.0, 0.0, 0.0))
	
	meshInst.set_surface_override_material(0, matInst)
	powerUp()
	
func powerUp():
	playEmissionCurve(emissionCurve, emissionColorRamp, 3)
	
func powerDown():
	print('active')
	playEmissionCurve(resetCurve, resetColorRamp, 2);

func playEmissionCurve(curve:Curve, colorRamp:Gradient, duration:float):
	var inverseDuration = 1.0/duration
	
	var timeElapsed = 0.0
	var interpolation = 0.0
	
	var deltaTime = 0.0
	
	while(timeElapsed < duration):
		deltaTime = get_process_delta_time()
		
		interpolation = timeElapsed * inverseDuration
		setEmission(
				curve.sample(interpolation), 
				colorRamp.sample(interpolation)
				)
		
		timeElapsed += deltaTime
		#await get_tree().process_frame
	
	setEmission(curve.sample(1.0), colorRamp.sample(1.0))
	
func setEmission(value:float, color_ramp:Color):
	matInst.emission_energy_multiplier = value
	matInst.emission = color_ramp
	#print(value)
