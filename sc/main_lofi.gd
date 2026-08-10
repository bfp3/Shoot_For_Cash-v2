extends Control

## Lightweight launcher — loads Main.tscn for intro, or fast-travels into a range.
## Shift+2 toggles the shop mini-game overlay (same as the main shop).
## Side panel: Test Mode (default, no disk save) / Clear Save / Load Game.

const MAIN_SCENE := "res://sc/Main.tscn"
const SHOP_MINI_GAME_SCENE_PATH := "res://ch/Shop/ShopMiniGame.tscn"

@onready var _launcher_panel: Control = $Center
#@onready var _mini_game_host: Control = $MiniGameHost
@onready var _session_status: RichTextLabel = $Center/HBox/SessionPanel/Margin/VBox/SessionStatus
@onready var _test_btn: Button = $Center/HBox/SessionPanel/Margin/VBox/TestMode
@onready var _clear_btn: Button = $Center/HBox/SessionPanel/Margin/VBox/ClearSave
@onready var _load_btn: Button = $Center/HBox/SessionPanel/Margin/VBox/LoadGame
@onready var _confirm: Control = $ConfirmClear
@onready var _confirm_label: RichTextLabel = $ConfirmClear/Center/Panel/Margin/VBox/Prompt

var _shop_mini_game: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gl_PlayerState.begin_test_session()
	_refresh_session_ui()
	_confirm.hide()
	var first_btn := $Center/HBox/LaunchPanel/Margin/VBox/GoToIntro as Control
	UiFocus.wire_vertical([
		$Center/HBox/LaunchPanel/Margin/VBox/GoToIntro,
		$Center/HBox/LaunchPanel/Margin/VBox/GoToMoss,
		$Center/HBox/LaunchPanel/Margin/VBox/GoToRedd,
		$Center/HBox/LaunchPanel/Margin/VBox/GoToGlory,
		$Center/HBox/LaunchPanel/Margin/VBox/GoToTesting,
		$Center/HBox/LaunchPanel/Margin/VBox/GoToMiniGame,
		_test_btn,
		_clear_btn,
		_load_btn,
	])
	UiFocus.grab_in(_launcher_panel, first_btn)


func _ensure_shop_mini_game() -> void:
	if _shop_mini_game != null and is_instance_valid(_shop_mini_game):
		return
	var packed := ResourceLoader.load(SHOP_MINI_GAME_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed == null:
		push_warning("Main-lofi: failed to load ShopMiniGame")
		return
	_shop_mini_game = packed.instantiate()
	add_child(_shop_mini_game)
	if _shop_mini_game.has_method("attach_to_shop"):
		_shop_mini_game.attach_to_shop(self)


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back_button"):
			_on_confirm_no_pressed()
			get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed('select_button'):
		_toggle_shop_mini_game()
		get_viewport().set_input_as_handled()


func _refresh_session_ui() -> void:
	var is_test := not gl_PlayerState.is_persist_enabled()
	var has_save := gl_PlayerState.has_meta_save_file()
	if is_test:
		_session_status.text = "[center][color=#2a6a2a]Test Mode[/color]\nNo disk saves while you play.[/center]"
		_test_btn.text = "Test Mode ✓"
		_load_btn.text = "Load Game"
	else:
		_session_status.text = "[center][color=#a10204]Load Game[/color]\nProgress writes to disk.[/center]"
		_test_btn.text = "Test Mode"
		_load_btn.text = "Load Game ✓"
	_clear_btn.disabled = false
	_load_btn.disabled = false
	if not has_save and is_test:
		_session_status.text += "\n[center][i](no save file on disk)[/i][/center]"


func _on_test_mode_pressed() -> void:
	gl_PlayerState.begin_test_session()
	_refresh_session_ui()


func _on_load_game_pressed() -> void:
	gl_PlayerState.begin_load_game_session()
	_refresh_session_ui()


func _on_clear_save_pressed() -> void:
	_confirm_label.text = "[center]Are You Sure?\n\nThis deletes your saved progress.[/center]"
	_confirm.show()
	UiFocus.grab_in(_confirm, $ConfirmClear/Center/Panel/Margin/VBox/HBox/Yes)


func _on_confirm_yes_pressed() -> void:
	gl_PlayerState.clear_meta_progress()
	# Stay in whatever mode was selected; wipe only the file + runtime.
	if not gl_PlayerState.is_persist_enabled():
		gl_PlayerState.begin_test_session()
	_confirm.hide()
	_refresh_session_ui()
	UiFocus.grab_in(_launcher_panel, _clear_btn)


func _on_confirm_no_pressed() -> void:
	_confirm.hide()
	UiFocus.grab_in(_launcher_panel, _clear_btn)


func _toggle_shop_mini_game() -> void:
	_ensure_shop_mini_game()
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
			UiFocus.grab_in(_launcher_panel, $Center/HBox/LaunchPanel/Margin/VBox/GoToIntro)


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
