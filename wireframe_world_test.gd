extends Node3D

@export var spin_speed := 0.22

@onready var _camera: Camera3D = $Camera3D
@onready var _meshes: Node3D = $Meshes


func _ready() -> void:
	if _camera:
		_camera.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _meshes and spin_speed != 0.0:
		_meshes.rotate_y(spin_speed * delta)
