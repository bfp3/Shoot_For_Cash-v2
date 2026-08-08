extends Control

## Lightweight launcher — loads Main.tscn for intro, or fast-travels into a range.
## Shift+2 toggles the shop mini-game overlay (same as the main shop).

const MAIN_SCENE := "res://sc/Main.tscn"
const SHOP_MINI_GAME_SCENE := preload("res://ch/Shop/ShopMiniGame.tscn")

@onready var _launcher_panel: Control = $Center
@onready var _mini_game_host: Control = $MiniGameHost

var _shop_mini_game: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_shop_mini_game()
	var first_btn := $Center/Panel/Margin/VBox/GoToIntro as Control
	UiFocus.wire_vertical([
		$Center/Panel/Margin/VBox/GoToIntro,
		$Center/Panel/Margin/VBox/GoToMoss,
		$Center/Panel/Margin/VBox/GoToRedd,
		$Center/Panel/Margin/VBox/GoToGlory,
		$Center/Panel/Margin/VBox/GoToTesting,
		$Center/Panel/Margin/VBox/GoToMiniGame,
	])
	UiFocus.grab_in(_launcher_panel, first_btn)


func _setup_shop_mini_game() -> void:
	_shop_mini_game = SHOP_MINI_GAME_SCENE.instantiate()
	add_child(_shop_mini_game)
	if _shop_mini_game.has_method("attach_to_shop"):
		_shop_mini_game.attach_to_shop(self)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('select_button'):
		_toggle_shop_mini_game()
		get_viewport().set_input_as_handled()


func _toggle_shop_mini_game() -> void:
	if _shop_mini_game == null or not _shop_mini_game.has_method("toggle"):
		return
	var opening := not bool(_shop_mini_game.get("is_open"))
	if opening:
		_launcher_panel.hide()
	_shop_mini_game.toggle()
	if not opening:
		# Closing — wait a frame so close() can finish its fade before showing buttons.
		await get_tree().create_timer(0.2).timeout
		if _shop_mini_game and not _shop_mini_game.is_open:
			_launcher_panel.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			UiFocus.grab_in(_launcher_panel, $Center/Panel/Margin/VBox/GoToIntro)


func _on_intro_pressed() -> void:
	_close_mini_game_if_open()
	RestarterScript.clear_pending_fast_travel()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_moss_pressed() -> void:
	_close_mini_game_if_open()
	RestarterScript.request_fast_travel(gl_DataSet.get_place_name(0))


func _on_redd_pressed() -> void:
	_close_mini_game_if_open()
	RestarterScript.request_fast_travel(gl_DataSet.get_place_name(1))


func _on_glory_pressed() -> void:
	_close_mini_game_if_open()
	RestarterScript.request_fast_travel(gl_DataSet.get_place_name(2))


func _on_testing_pressed() -> void:
	_close_mini_game_if_open()
	RestarterScript.request_fast_travel(gl_DataSet.get_testing_place_name())


func _close_mini_game_if_open() -> void:
	if _shop_mini_game and _shop_mini_game.has_method("close") and _shop_mini_game.is_open:
		_shop_mini_game.close()
