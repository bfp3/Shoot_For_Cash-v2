@tool
extends MeshInstance3D
class_name VectorWireframeMesh

## Builds a vector-style mesh: filled faces plus crease edges.
## Face colour, edge colour, line thickness, and glow are all inspector-controlled.
## Internal triangle diagonals are hidden using a crease-angle test.

const WIRE_SHADER: Shader = preload("res://res/Shaders/vector_wireframe.gdshader")
const WIRE_SHADER_TRANSPARENT: Shader = preload("res://res/Shaders/vector_wireframe_transparent.gdshader")
const POINT_SCALE := 1000.0
const FACE_ALPHA_OPAQUE := 0.999

@export var source_mesh: Mesh:
	set(value):
		if source_mesh == value:
			return
		_disconnect_source()
		source_mesh = value
		_connect_source()
		_rebuild()

@export_group("Vector Wireframe")
@export var face_color := Color(0.03, 0.08, 0.16, 1.0):
	set(value):
		face_color = value
		_apply_params()

@export var edge_color := Color(1.0, 0.72, 0.28, 1.0):
	set(value):
		edge_color = value
		_apply_params()

@export_range(0.0, 60.0, 0.1, "or_greater") var edge_thickness := 1.8:
	set(value):
		edge_thickness = value
		_apply_params()

@export_range(0.0, 60.0, 0.1) var glow_amount := 60.0:
	set(value):
		glow_amount = value
		_apply_params()

@export_range(0., 4.0, 0.1) var edge_softness := 1.2:
	set(value):
		edge_softness = value
		_apply_params()

@export_range(1.0, 80.0, 1.0) var crease_angle_degrees := 25.0:
	set(value):
		crease_angle_degrees = value
		_rebuild()

@export_group("Line Gaps")
@export_range(0.0, 1.0, 0.01) var line_gap_amount := 0.85:
	set(value):
		line_gap_amount = value
		_apply_params()

@export_range(1.0, 24.0, 0.1) var line_gap_spacing := 4.0:
	set(value):
		line_gap_spacing = value
		_apply_params()

@export_range(0.0, 12.0, 0.05) var line_gap_size := 1.4:
	set(value):
		line_gap_size = value
		_apply_params()

@export_range(0.0, 4.0, 0.05) var line_gap_softness := 0.55:
	set(value):
		line_gap_softness = value
		_apply_params()

@export_range(0.0, 180.0, 1.0) var line_gap_angle := 0.0:
	set(value):
		line_gap_angle = value
		_apply_params()

@export_range(0.0, 1.0, 0.01) var line_gap_offset := 0.0:
	set(value):
		line_gap_offset = value
		_apply_params()

var _mat: ShaderMaterial
var _wire_mesh: ArrayMesh
var _building := false


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _enter_tree() -> void:
	if source_mesh == null and mesh != null and mesh.get_meta("vector_wireframe", false) != true:
		source_mesh = mesh
	_connect_source()
	_rebuild()


func _exit_tree() -> void:
	_disconnect_source()


func _connect_source() -> void:
	if source_mesh != null and not source_mesh.changed.is_connected(_rebuild):
		source_mesh.changed.connect(_rebuild)


func _disconnect_source() -> void:
	if source_mesh != null and source_mesh.changed.is_connected(_rebuild):
		source_mesh.changed.disconnect(_rebuild)


func _apply_params() -> void:
	if _mat == null:
		return
	var wanted: Shader = WIRE_SHADER_TRANSPARENT if face_color.a < FACE_ALPHA_OPAQUE else WIRE_SHADER
	if _mat.shader != wanted:
		_mat.shader = wanted
	_mat.set_shader_parameter("face_color", face_color)
	_mat.set_shader_parameter("edge_color", edge_color)
	_mat.set_shader_parameter("edge_thickness", edge_thickness)
	_mat.set_shader_parameter("glow_amount", glow_amount)
	_mat.set_shader_parameter("edge_softness", edge_softness)
	_mat.set_shader_parameter("line_gap_amount", line_gap_amount)
	_mat.set_shader_parameter("line_gap_spacing", line_gap_spacing)
	_mat.set_shader_parameter("line_gap_size", line_gap_size)
	_mat.set_shader_parameter("line_gap_softness", line_gap_softness)
	_mat.set_shader_parameter("line_gap_angle", line_gap_angle)
	_mat.set_shader_parameter("line_gap_offset", line_gap_offset)


func _rebuild() -> void:
	if _building:
		return
	_building = true
	_ensure_material()
	_apply_params()
	if source_mesh == null:
		_building = false
		return
	_wire_mesh = _build_wire_mesh(source_mesh)
	mesh = _wire_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_building = false


func _ensure_material() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = WIRE_SHADER
	material_override = _mat


func _build_wire_mesh(from: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.set_meta("vector_wireframe", true)
	var cos_crease := cos(deg_to_rad(crease_angle_degrees))
	for s in from.get_surface_count():
		var packed := _bake_surface(from.surface_get_arrays(s), cos_crease)
		if packed.is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, packed)
	return out


func _bake_surface(arrays: Array, cos_crease: float) -> Array:
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return []
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if src_verts.is_empty():
		return []
	var src_idx: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		src_idx = arrays[Mesh.ARRAY_INDEX]
	else:
		src_idx.resize(src_verts.size())
		for i in src_verts.size():
			src_idx[i] = i
	if src_idx.size() < 3:
		return []

	var tri_verts: Array[PackedVector3Array] = []
	var tri_normals: PackedVector3Array = PackedVector3Array()
	for i in range(0, src_idx.size() - 2, 3):
		var a := src_verts[src_idx[i]]
		var b := src_verts[src_idx[i + 1]]
		var c := src_verts[src_idx[i + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		tri_verts.append(PackedVector3Array([a, b, c]))
		tri_normals.append(n)

	var edge_faces := _collect_edge_faces(tri_verts, tri_normals)

	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_colors := PackedColorArray()
	for t in tri_verts.size():
		var tv := tri_verts[t]
		var n := tri_normals[t]
		var draw := PackedByteArray()
		draw.resize(3)
		draw[0] = 1 if _is_feature_edge(tv[1], tv[2], n, edge_faces, cos_crease) else 0
		draw[1] = 1 if _is_feature_edge(tv[2], tv[0], n, edge_faces, cos_crease) else 0
		draw[2] = 1 if _is_feature_edge(tv[0], tv[1], n, edge_faces, cos_crease) else 0
		var bary := _bary_for_triangle(draw)
		for v in 3:
			out_verts.append(tv[v])
			out_normals.append(n)
			out_colors.append(Color(bary[v].x, bary[v].y, bary[v].z, 1.0))

	if out_verts.is_empty():
		return []
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	out[Mesh.ARRAY_NORMAL] = out_normals
	out[Mesh.ARRAY_COLOR] = out_colors
	return out


func _bary_for_triangle(draw: PackedByteArray) -> Array[Vector3]:
	var bary: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for edge_i in 3:
		if draw[edge_i] == 1:
			continue
		for v in 3:
			var b := bary[v]
			b[edge_i] = 1.0
			bary[v] = b
	return bary


func _collect_edge_faces(tri_verts: Array[PackedVector3Array], tri_normals: PackedVector3Array) -> Dictionary:
	var edge_faces := {}
	for t in tri_verts.size():
		var tv := tri_verts[t]
		var n := tri_normals[t]
		_add_edge_face(edge_faces, tv[0], tv[1], n)
		_add_edge_face(edge_faces, tv[1], tv[2], n)
		_add_edge_face(edge_faces, tv[2], tv[0], n)
	return edge_faces


func _add_edge_face(edge_faces: Dictionary, a: Vector3, b: Vector3, n: Vector3) -> void:
	var key := _edge_key(a, b)
	if not edge_faces.has(key):
		edge_faces[key] = []
	edge_faces[key].append(n)


func _is_feature_edge(a: Vector3, b: Vector3, n: Vector3, edge_faces: Dictionary, cos_crease: float) -> bool:
	var faces: Array = edge_faces.get(_edge_key(a, b), [])
	if faces.size() <= 1:
		return true
	for other in faces:
		if other.dot(n) < cos_crease:
			return true
	return false


func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka := _pt_key(a)
	var kb := _pt_key(b)
	if ka < kb:
		return ka + "|" + kb
	return kb + "|" + ka


func _pt_key(p: Vector3) -> String:
	return "%d,%d,%d" % [
		roundi(p.x * POINT_SCALE),
		roundi(p.y * POINT_SCALE),
		roundi(p.z * POINT_SCALE),
	]
