#@tool
extends EditorScript

var updated_scenes := 0
var updated_players := 0

func _run():
	var files := []
	find_scene_files("res://", files)

	print("--------------------------------")
	print("Searching ", files.size(), " scenes...")
	print("--------------------------------")

	for scene_path in files:
		process_scene(scene_path)

	print("--------------------------------")
	print("Finished!")
	print("Scenes Updated: ", updated_scenes)
	print("Audio Players Updated: ", updated_players)
	print("--------------------------------")


func find_scene_files(path:String, results:Array):
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var file := dir.get_next()

		if file == "":
			break

		if file.begins_with("."):
			continue

		var full := path.path_join(file)

		if dir.current_is_dir():
			find_scene_files(full, results)
		elif file.get_extension() == "tscn":
			results.append(full)

	dir.list_dir_end()
func process_scene(scene_path:String):

	var packed:PackedScene = load(scene_path)
	if packed == null:
		return

	var root = packed.instantiate()

	var changed = replace_audio(root)

	if changed:
		packed.pack(root)
		ResourceSaver.save(packed, scene_path)

		updated_scenes += 1
		print("Updated: ", scene_path)

	root.free()


func replace_audio(node:Node) -> bool:

	var changed := false

	if node is AudioStreamPlayer \
	or node is AudioStreamPlayer2D \
	or node is AudioStreamPlayer3D:

		if node.stream:

			var path = node.stream.resource_path

			if path.to_lower().ends_with(".wav"):

				var ogg = path.get_basename() + ".ogg"

				if ResourceLoader.exists(ogg):

					node.stream = load(ogg)
					updated_players += 1
					changed = true

					print(path, " -> ", ogg)

	for child in node.get_children():
		if replace_audio(child):
			changed = true

	return changed
