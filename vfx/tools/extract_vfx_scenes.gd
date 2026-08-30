extends SceneTree
## Headless: extract AoE roots from rock/balloon/orange/pineapple into res://vfx/*.tscn
## Run: Godot --headless --path <project> --script res://vfx/tools/extract_vfx_scenes.gd

const OUT_DIR := "res://vfx/"

const JOBS := [
	{
		"src": "res://ch/Rocks/Rock_Instance.tscn",
		"node": "AoE_RockDestroy",
		"out": "aoe_rock_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Rock_Instance.tscn",
		"node": "Aoe_CrateDestroy",
		"out": "aoe_crate_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Rock_Instance.tscn",
		"node": "Aoe_HazardDestroy",
		"out": "aoe_hazard_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Rock_Instance.tscn",
		"node": "Aoe_SmokecanDestroy",
		"out": "aoe_smokecan_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Balloon.tscn",
		"node": "AoE_Balloon",
		"out": "aoe_balloon_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Orange.tscn",
		"node": "AoE_Oranges",
		"out": "aoe_orange_destroy.tscn",
	},
	{
		"src": "res://ch/Rocks/Pineapple.tscn",
		"node": "AoE_Pineapples",
		"out": "aoe_pineapple_destroy.tscn",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for job in JOBS:
		_extract(job)
	_build_hit_from_rock()
	_build_hit_from_orange()
	_build_showroom()
	print("VFX extract done.")
	quit(0)


func _extract(job: Dictionary) -> void:
	var packed: PackedScene = load(job.src) as PackedScene
	if packed == null:
		push_error("Missing %s" % job.src)
		return
	var root: Node = packed.instantiate()
	var src: Node = root.get_node_or_null(String(job.node))
	if src == null:
		push_error("Missing node %s in %s" % [job.node, job.src])
		root.free()
		return
	var copy: Node = src.duplicate()
	copy.name = String(job.node)
	if copy is Node3D:
		(copy as Node3D).top_level = true
		(copy as Node3D).global_position = Vector3.ZERO
	_set_owners_recursive(copy, copy)
	_stop_emitters(copy)
	var scene := PackedScene.new()
	var err: Error = scene.pack(copy)
	if err != OK:
		push_error("pack failed %s: %s" % [String(job.out), error_string(err)])
		copy.free()
		root.free()
		return
	var path: String = OUT_DIR + String(job.out)
	err = ResourceSaver.save(scene, path)
	var status: String = error_string(err) if err != OK else "OK"
	print("Saved %s (%s)" % [path, status])
	copy.free()
	root.free()


func _build_hit_from_rock() -> void:
	var packed: PackedScene = load("res://ch/Rocks/Rock_Instance.tscn") as PackedScene
	if packed == null:
		return
	var root: Node = packed.instantiate()
	var host := Node3D.new()
	host.name = "AoE_RockHit"
	host.top_level = true
	host.set_script(load("res://res/aoe_script.gd"))
	for child_name in ["Smoke_quick", "Sparks01"]:
		var n: Node = root.get_node_or_null(child_name)
		if n == null:
			continue
		var c: Node = n.duplicate()
		host.add_child(c)
		c.owner = host
		_set_owners_recursive(c, host)
	_stop_emitters(host)
	if host.get("delays") != null:
		host.set("delays", {&"Smoke_quick": 0.0, &"Sparks01": 0.0})
	var scene := PackedScene.new()
	scene.pack(host)
	ResourceSaver.save(scene, OUT_DIR + "aoe_rock_hit.tscn")
	print("Saved aoe_rock_hit.tscn")
	host.free()
	root.free()


func _build_hit_from_orange() -> void:
	var packed: PackedScene = load("res://ch/Rocks/Orange.tscn") as PackedScene
	if packed == null:
		return
	var root: Node = packed.instantiate()
	var host := Node3D.new()
	host.name = "AoE_OrangeHit"
	host.top_level = true
	host.set_script(load("res://res/aoe_script.gd"))
	for child_name in ["Smoke_quick", "Sparks01"]:
		var n: Node = root.get_node_or_null(child_name)
		if n == null:
			continue
		var c: Node = n.duplicate()
		host.add_child(c)
		c.owner = host
		_set_owners_recursive(c, host)
	_stop_emitters(host)
	if host.get("delays") != null:
		host.set("delays", {&"Smoke_quick": 0.0, &"Sparks01": 0.0})
	var scene := PackedScene.new()
	scene.pack(host)
	ResourceSaver.save(scene, OUT_DIR + "aoe_orange_hit.tscn")
	print("Saved aoe_orange_hit.tscn")
	host.free()
	root.free()


func _build_showroom() -> void:
	var show := Node3D.new()
	show.name = "VfxShowroom"
	var files := [
		"aoe_rock_destroy.tscn",
		"aoe_crate_destroy.tscn",
		"aoe_hazard_destroy.tscn",
		"aoe_smokecan_destroy.tscn",
		"aoe_rock_hit.tscn",
		"aoe_balloon_destroy.tscn",
		"aoe_orange_destroy.tscn",
		"aoe_orange_hit.tscn",
		"aoe_pineapple_destroy.tscn",
	]
	var x := 0.0
	for f in files:
		var fname: String = String(f)
		var path: String = OUT_DIR + fname
		if not ResourceLoader.exists(path):
			continue
		var p: PackedScene = load(path) as PackedScene
		if p == null:
			continue
		var inst: Node = p.instantiate()
		inst.name = fname.get_basename()
		show.add_child(inst)
		inst.owner = show
		_set_owners_recursive(inst, show)
		if inst is Node3D:
			(inst as Node3D).position = Vector3(x, 0, 0)
		x += 4.0
	var scene := PackedScene.new()
	scene.pack(show)
	var out_path: String = OUT_DIR + "VFX_showroom.tscn"
	ResourceSaver.save(scene, out_path)
	print("Saved VFX_showroom.tscn")
	show.free()


func _set_owners_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owners_recursive(child, owner)


func _stop_emitters(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	for child in node.get_children():
		_stop_emitters(child)
