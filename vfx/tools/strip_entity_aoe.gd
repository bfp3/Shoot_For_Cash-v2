extends SceneTree
## Strip migrated AoE nodes from entity scenes (after extract_vfx_scenes.gd).

const STRIPS := [
	{
		"path": "res://ch/Rocks/Rock_Instance.tscn",
		"nodes": [
			"AoE_RockDestroy",
			"Aoe_CrateDestroy",
			"Aoe_HazardDestroy",
			"Aoe_SmokecanDestroy",
			"Smoke_quick",
			"Sparks01",
		],
	},
	{
		"path": "res://ch/Rocks/Balloon.tscn",
		"nodes": ["AoE_Balloon", "Smoke_quick", "Sparks01"],
	},
	{
		"path": "res://ch/Rocks/Orange.tscn",
		"nodes": ["AoE_Oranges", "Smoke_quick", "Sparks01"],
	},
	{
		"path": "res://ch/Rocks/Pineapple.tscn",
		"nodes": ["AoE_Pineapples", "Smoke_quick", "Smoke_quick2", "AoE2Fail", "Sparks01"],
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for job in STRIPS:
		_strip(job)
	print("VFX strip done.")
	quit(0)


func _strip(job: Dictionary) -> void:
	var path: String = String(job.path)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Missing %s" % path)
		return
	var root: Node = packed.instantiate()
	for node_name in job.nodes:
		var n: Node = root.get_node_or_null(String(node_name))
		if n:
			n.free()
			print("Removed %s from %s" % [String(node_name), path])
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err: Error = scene.pack(root)
	if err != OK:
		push_error("pack failed %s" % path)
		root.free()
		return
	err = ResourceSaver.save(scene, path)
	print("Saved %s (%s)" % [path, error_string(err) if err != OK else "OK"])
	root.free()


func _set_owners(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owners(child, owner)
