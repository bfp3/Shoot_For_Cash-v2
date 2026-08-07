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

	if Input.is_action_just_pressed("escape"):
		if resolution_confirm.visible:
			GameSettings.revert_resolution()
			return
		if settings_menu.visible:
			_show_pause_root()
			return
		if visible:
			close_menu()
		else:
			open_menu()


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


func _show_settings() -> void:
	quit_control.hide()
	settings_menu.show()
	if settings_menu.has_method("refresh"):
		settings_menu.refresh()
	resolution_confirm.hide()


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_cancel_menu_pressed() -> void:
	close_menu()


func _on_settings_pressed() -> void:
	_show_settings()


func _on_settings_back_pressed() -> void:
	_show_pause_root()


func _on_open_resolution_confirm() -> void:
	resolution_confirm.show()


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
