extends CanvasLayer

var active = false
var stored_mouse_mode : Input.MouseMode

func _ready() -> void:
	hide()


func disable() -> void:
	active = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func enable() -> void:
	active = true

func _input(event: InputEvent) -> void:
	if !active:
		return
		
	if Input.is_action_just_pressed("escape"):
		visible = !visible
		
		if visible:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func start() -> void:
	$Settings_menu.visible = false
	stored_mouse_mode = Input.mouse_mode
	visible = !visible
		
	if visible:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_tree().paused = false
		Input.mouse_mode = stored_mouse_mode

func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_cancel_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode
	visible = false
	$Settings_menu.visible = false

func _on_settings_pressed() -> void:
	$Settings_menu.visible = !$Settings_menu.visible
