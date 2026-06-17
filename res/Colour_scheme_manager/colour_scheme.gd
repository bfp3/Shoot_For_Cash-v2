#@tool
extends Node

@export var disabled := false

@onready var directional_light_3d: DirectionalLight3D = $'../Lighting/DirectionalLight3D'
@onready var world_environment: WorldEnvironment = $'../Lighting/WorldEnvironment'
@onready var wall_reference: CSGCombiner3D = $'../Cannon_Launcher/Launcher_zone_mesh/CSGCombiner3D'
@onready var floor: CSGBox3D = $'../floor'


@export_group('Lighting And Environment Colours', "")
@export var sky_top_colour := Color('1a1e26')
@export var sky_horizon_colour := Color('b3b3b3')
@export var ground_horizon_color := Color('000000')
@export var ground_bottom_color := Color('000000')
@export var directional_light_colour := Color('54607a')

@export_group('Meshes', "")
@export var wall_colour := Color('9fa5b3')
@export var floor_colour := Color('9fa5b3')

#Directional light was 140



func _process(delta: float) -> void:
	
	if disabled:
		return
		
		
	if directional_light_3d:
		directional_light_3d.light_color = directional_light_colour

	if wall_reference:
		var material = wall_reference.material_override
		if material and material is StandardMaterial3D:
			material.albedo_color = wall_colour
			
	if floor:
		var material = floor.material_override
		if material and material is StandardMaterial3D:
			material.albedo_color = floor_colour

	if world_environment:
		var env := world_environment.environment
		if env and env.sky:
			var sky_material := env.sky.sky_material
			if sky_material and sky_material is ProceduralSkyMaterial:
				sky_material.sky_top_color = sky_top_colour
				sky_material.sky_horizon_color = sky_horizon_colour
				sky_material.ground_bottom_color = ground_bottom_color
				sky_material.ground_horizon_color = ground_horizon_color
