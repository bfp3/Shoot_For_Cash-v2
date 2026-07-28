extends CanvasLayer

var active := false
var stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	hide()


func disable() -> void:
	active = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode


func enable() -> void:
	active = true


func _input(_event: InputEvent) -> void:
	#if !active:
		#return

	if Input.is_action_just_pressed("escape"):
		if visible:
			close_menu()
		else:
			open_menu()


func open_menu() -> void:
	if visible:
		return

	stored_mouse_mode = Input.mouse_mode
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if !visible:
		return

	visible = false
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode
	$Settings_menu.visible = false


func start() -> void:
	$Settings_menu.visible = false

	if visible:
		close_menu()
	else:
		open_menu()


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_cancel_menu_pressed() -> void:
	close_menu()


func _on_settings_pressed() -> void:
	$Settings_menu.visible = !$Settings_menu.visible
