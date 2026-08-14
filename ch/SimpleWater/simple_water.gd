@tool
extends Node3D
class_name SimpleWater

## Drop-in light ocean: one subdivided plane + wavy vertex shader.
## Replaces Boujie OutsetOcean when you only need the wave motion.

@export var water_size := Vector2(500.0, 500.0):
	set(value):
		water_size = value
		if is_node_ready():
			_rebuild_mesh()

@export_range(4, 256, 1) var subdivide := 72:
	set(value):
		subdivide = value
		if is_node_ready():
			_rebuild_mesh()

@export var water_material: ShaderMaterial:
	set(value):
		water_material = value
		if is_node_ready():
			_apply_material()

@export_group("Editor")
@export var rebuild_mesh := false:
	set(value):
		if value:
			_rebuild_mesh()
		rebuild_mesh = false

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_ensure_mesh_instance()
	_rebuild_mesh()
	_apply_material()


func _ensure_mesh_instance() -> void:
	_mesh_instance = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance)
		if Engine.is_editor_hint():
			_mesh_instance.owner = get_tree().edited_scene_root


func _rebuild_mesh() -> void:
	_ensure_mesh_instance()
	var plane := PlaneMesh.new()
	plane.size = water_size
	plane.subdivide_width = subdivide
	plane.subdivide_depth = subdivide
	_mesh_instance.mesh = plane
	_apply_material()


func _apply_material() -> void:
	if _mesh_instance == null:
		return
	if water_material:
		_mesh_instance.material_override = water_material
	elif _mesh_instance.material_override == null:
		var mat := load("res://ch/SimpleWater/simple_water_material.tres") as ShaderMaterial
		if mat:
			_mesh_instance.material_override = mat
