extends CanvasLayer

@onready var main_control: Control = $Control
@onready var center_container: CenterContainer = $Control/CenterContainer
@onready var quit_control: Control = %QuitControl
@onready var settings_menu: Control = %Settings_menu
@onready var resolution_confirm: Control = %ResolutionConfirm

@export var pivot_offset_ratio: Vector2 = Vector2(0.5, 0.5)
@export var anim_duration: float = 0.25

var active := false
var animating := false
var stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	# Let this menu (its _input and its tweens) keep running while the
	# SceneTree is paused - required so the close animation can play
	# and Escape still works after we call get_tree().paused = true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	settings_menu.hide()
	resolution_confirm.hide()


func disable() -> void:
	active = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode


func enable() -> void:
	active = true


func _input(_event: InputEvent) -> void:
	if OS.is_debug_build():
		if Input.is_key_label_pressed(KEY_KP_0):
			center_container.visible = !center_container.visible

	var toggle_pause := Input.is_action_just_pressed("escape") or Input.is_action_just_pressed("pause")
	var cancel := (
		Input.is_action_just_pressed("ui_cancel")
		or Input.is_action_just_pressed("controller_back_button")
	)

	# Map popup owns Back / B / Escape while it's open (and pause isn't).
	if not visible and (cancel or toggle_pause):
		var map_menu := get_tree().get_first_node_in_group("map_menu")
		if map_menu and map_menu is CanvasItem and (map_menu as CanvasItem).visible:
			if map_menu.has_method("_on_close_map_pressed"):
				map_menu._on_close_map_pressed()
			get_viewport().set_input_as_handled()
			return

	if toggle_pause or (cancel and visible):
		if resolution_confirm.visible:
			GameSettings.revert_resolution()
			get_viewport().set_input_as_handled()
			return
		if settings_menu.visible:
			# Volume edit modal owns Back first.
			if settings_menu.has_method("is_volume_editing") and settings_menu.is_volume_editing():
				settings_menu.end_volume_edit()
				get_viewport().set_input_as_handled()
				return
			_show_pause_root()
			get_viewport().set_input_as_handled()
			return
		if visible:
			close_menu()
			get_viewport().set_input_as_handled()
		elif toggle_pause:
			open_menu()
			get_viewport().set_input_as_handled()


func open_menu() -> void:
	# animating guard stops a second Escape press from starting a
	# conflicting tween mid-animation
	if visible or animating:
		return
	animating = true

	stored_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	main_control.scale = Vector2.ONE * 0.01
	_show_pause_root()
	show()

	sfx_open_shop()

	var backgroundColor := $Control/CenterContainer/ColorRect
	backgroundColor.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(main_control, "scale", Vector2.ONE, anim_duration)
	tween.parallel().tween_property(backgroundColor, "modulate:a", 0.25, anim_duration).set_delay(0.2)
	await tween.finished

	animating = false
	_focus_pause_root()


func close_menu() -> void:
	if !visible or animating:
		return
	if GameSettings.is_resolution_pending():
		GameSettings.revert_resolution()
	animating = true

	sfx_close_menu()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(main_control, "scale", Vector2.ONE * 0.01, anim_duration)
	await tween.finished

	hide()
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode
	_show_pause_root()
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

	animating = false


func start() -> void:
	_show_pause_root()
	if visible:
		close_menu()
	else:
		open_menu()


func _show_pause_root() -> void:
	quit_control.show()
	settings_menu.hide()
	resolution_confirm.hide()
	if visible and not animating:
		_focus_pause_root()


func _show_settings() -> void:
	quit_control.hide()
	settings_menu.show()
	if settings_menu.has_method("refresh"):
		settings_menu.refresh()
	resolution_confirm.hide()
	UiFocus.grab_in(settings_menu)


func _focus_pause_root() -> void:
	var resume := quit_control.get_node_or_null("QuitMenu/HBoxContainer/VBoxContainer/CancelMenu") as Control
	var settings_btn := quit_control.get_node_or_null("QuitMenu/HBoxContainer/VBoxContainer/Settings") as Control
	var map_btn := quit_control.get_node_or_null("QuitMenu/HBoxContainer/VBoxContainer/OpenMap") as Control
	var title_btn := quit_control.get_node_or_null("QuitMenu/HBoxContainer/VBoxContainer/BackToTitle") as Control
	var quit_btn := quit_control.get_node_or_null("QuitMenu/HBoxContainer/VBoxContainer/CloseGame") as Control
	UiFocus.wire_vertical([resume, settings_btn, map_btn, title_btn, quit_btn])
	UiFocus.grab_in(quit_control, resume)


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_open_map_pressed() -> void:
	await close_menu()
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_ticket_map"):
		menus.ensure_ticket_map()
	var map_menu := get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu.has_method("open_pop_up"):
		await map_menu.open_pop_up()
	elif map_menu and map_menu.has_method("display_ticket"):
		await map_menu.display_ticket()


func _on_back_to_title_pressed() -> void:
	# Smooth transition back to the title screen — no scene reload / full restart.
	if GameSettings.is_resolution_pending():
		GameSettings.revert_resolution()
	animating = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("return_to_title"):
		await round_manager.return_to_title()
		return

	# Fallback if round manager path is missing.
	gl_PlayerState.reset_all()
	await get_tree().process_frame
	get_tree().reload_current_scene()


func _on_cancel_menu_pressed() -> void:
	close_menu()


func _on_settings_pressed() -> void:
	_show_settings()


func _on_settings_back_pressed() -> void:
	_show_pause_root()


func _on_open_resolution_confirm() -> void:
	resolution_confirm.show()
	var keep := resolution_confirm.get_node_or_null("%KeepButton") as Control
	UiFocus.grab_in(resolution_confirm, keep)


func sfx_open_shop() -> void:
	$SFX/shop_open_sfx_01.play(0.3)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.play()


func sfx_close_menu() -> void:
	$SFX/shop_close_sfx_01.play()
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.play()
