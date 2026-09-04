extends SceneTree
## Headless exporter: GridMappieces.tscn -> GridMappieces.meshlib
## Run:
##   Godot_v4.6-dev6_win64.exe --headless --path <project> --script res://res/gridmaps/export_gridmap_meshlibrary.gd

const SOURCE := "res://res/gridmaps/GridMappieces.tscn"
const OUTPUT := "res://res/gridmaps/GridMappieces.meshlib"


func _initialize() -> void:
	var packed: PackedScene = load(SOURCE)
	if packed == null:
		push_error("Failed to load %s" % SOURCE)
		quit(1)
		return

	var scene: Node = packed.instantiate()
	var lib := MeshLibrary.new()
	_import_direct_children(scene, lib)
	lib.set_meta("_editor_source_scene", SOURCE)
	scene.free()

	var err := ResourceSaver.save(lib, OUTPUT)
	if err != OK:
		push_error("Failed to save %s (error %s)" % [OUTPUT, err])
		quit(1)
		return

	print("Saved MeshLibrary with %s items to %s" % [lib.get_item_list().size(), OUTPUT])
	for id in lib.get_item_list():
		var mesh: Mesh = lib.get_item_mesh(id)
		print("  [%s] %s  surfaces=%s  aabb=%s" % [id, lib.get_item_name(id), mesh.get_surface_count(), mesh.get_aabb()])

	quit(0)


func _import_direct_children(scene_root: Node, lib: MeshLibrary) -> void:
	var next_id := 0
	for child in scene_root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue

		lib.create_item(next_id)
		lib.set_item_name(next_id, mi.name)
		lib.set_item_mesh(next_id, _bake_item_mesh(mi))
		lib.set_item_mesh_transform(next_id, Transform3D.IDENTITY)
		if lib.has_method("set_item_mesh_cast_shadow"):
			lib.call("set_item_mesh_cast_shadow", next_id, mi.cast_shadow)
		next_id += 1


func _bake_item_mesh(item: MeshInstance3D) -> Mesh:
	var extras: Array[MeshInstance3D] = []
	_collect_mesh_children(item, extras)

	if extras.is_empty():
		return _duplicate_with_materials(item)

	var combined := ArrayMesh.new()
	_append_surfaces(combined, item, Transform3D.IDENTITY)
	for extra in extras:
		_append_surfaces(combined, extra, _relative_transform(extra, item))
	return combined


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _collect_mesh_children(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			out.append(child)
		_collect_mesh_children(child, out)


func _duplicate_with_materials(mi: MeshInstance3D) -> Mesh:
	var item_mesh: Mesh = mi.mesh.duplicate()
	for i in item_mesh.get_surface_count():
		var mat := _surface_material(mi, i)
		if mat:
			item_mesh.surface_set_material(i, mat)
	return item_mesh


func _append_surfaces(am: ArrayMesh, mi: MeshInstance3D, xform: Transform3D) -> void:
	for s in mi.mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(mi.mesh, s, xform)
		var mat := _surface_material(mi, s)
		if mat:
			st.set_material(mat)
		st.commit(am)


func _surface_material(mi: MeshInstance3D, surface: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var override_mat := mi.get_surface_override_material(surface)
	if override_mat:
		return override_mat
	return mi.mesh.surface_get_material(surface)
