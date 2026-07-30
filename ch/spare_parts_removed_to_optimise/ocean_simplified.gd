@tool
extends Node

## A water material designer tool which allows easy editing of shader
## parameters using GerstnerWaves. Synchronizes level-of-detail settings between
## a water shader, the active camera, an ocean, and a camera follower.

## Emitted when level-of-detail settings are updated.
## This signal may fire in the editor. Make sure any connected scripts are also
## tool scripts.
signal updated_lod(far_distance: float, middle_distance: float, unit_size: float)

## Water shader material designed to work with this Designer node
@export var material: ShaderMaterial
## Update material and ocean when this Designer is ready.
@export var update_on_ready := false
## Update material and ocean when the active camera's far changes.
@export var update_when_camera_far_changes := false

@export_category("Optional Nodes to Update")
## Optionally specify an ocean node, this Designer will update its farplane to
## match the active camera's far
@export_node_path("Ocean") var ocean_path := NodePath("")
## Optionally specify a CameraFollower3D, this Designer will update its
## snap unit to the ocean's max unit size.
@export_node_path("CameraFollower3D") var camera_follower_path := NodePath("")

@export_category("Waves")
## Waves that physically raise and lower the water mesh
@export var height_waves: Array[GerstnerWave] = []

@export_category("Editor Tools")
## Update all parameters controlled by this Designer node.
@export var editor_update_all_params := false

var _previous_far := 0.0


func _ready():
	if not Engine.is_editor_hint() and update_on_ready:
		# because I can connect to any node in the scene tree from here,
		# I want to be safe and wait for the whole tree to be ready.
		get_tree().root.ready.connect(self.update)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('escape'):
		get_parent().visible = !get_parent().visible


func freeze_ocean() -> void:
	material.set_shader_parameter("freeze_time", true)


func _process(_delta):
	if editor_update_all_params:
		editor_update_all_params = false
		update()
	if update_when_camera_far_changes and not Engine.is_editor_hint():
		var camera = get_viewport().get_camera_3d()
		if camera and camera.far != _previous_far:
			_previous_far = camera.far
			update()


## Update level-of-detail settings and wave parameters on the shader, and
## optionally an ocean and a camera follower.
func update():
	_update_lod()
	_update_wave_params()


func _update_lod():
	var camera = get_viewport().get_camera_3d()
	var ocean = get_node_or_null(ocean_path)
	var follower = get_node_or_null(camera_follower_path)
	if camera:
		var middle = camera.far / 2.0
		var unit_size = 1.0
		if ocean:
			middle = ocean.total_width / 2.0
			ocean.far_edge = camera.far
			ocean.build_farplane()
			unit_size = ocean.max_unit_size
			if follower:
				follower.snap_unit = ocean.max_unit_size
		updated_lod.emit(camera.far, middle, unit_size)


func _update_wave_params():
	var num_waves = min(8, len(height_waves))
	material.set_shader_parameter("WaveCount", num_waves)
	var steepnesses = []
	var amplitudes = []
	var directions = []
	var frequencies = []
	var speeds = []
	var phases = []
	for i in range(num_waves):
		var res = height_waves[i]
		steepnesses.append(res.steepness)
		amplitudes.append(res.amplitude)
		directions.append(res.direction_degrees)
		frequencies.append(res.frequency)
		speeds.append(res.speed)
		phases.append(res.phase_degrees)
	material.set_shader_parameter("WaveSteepnesses", PackedFloat32Array(steepnesses))
	material.set_shader_parameter("WaveAmplitudes", PackedFloat32Array(amplitudes))
	material.set_shader_parameter("WaveDirectionsDegrees", PackedFloat32Array(directions))
	material.set_shader_parameter("WaveFrequencies", PackedFloat32Array(frequencies))
	material.set_shader_parameter("WaveSpeeds", PackedFloat32Array(speeds))
	material.set_shader_parameter("WavePhases", PackedFloat32Array(phases))
