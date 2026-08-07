extends Control

## Lightweight launcher — loads Main.tscn for intro, or fast-travels into a range.

const MAIN_SCENE := "res://sc/Main.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_intro_pressed() -> void:
	RestarterScript.clear_pending_fast_travel()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_moss_pressed() -> void:
	RestarterScript.request_fast_travel("moss")


func _on_redd_pressed() -> void:
	RestarterScript.request_fast_travel("redd")


func _on_glory_pressed() -> void:
	RestarterScript.request_fast_travel("glory")


func _on_testing_pressed() -> void:
	pass
