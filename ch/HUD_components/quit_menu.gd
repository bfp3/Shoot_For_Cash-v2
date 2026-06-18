extends PanelContainer

var active = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	#EventBus.instance.open_tally_card.connect(disable)
	EventBus.instance.open_shop.connect(disable)
	EventBus.instance.close_shop.connect(enable)

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


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_cancel_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false
