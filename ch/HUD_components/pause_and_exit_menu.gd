extends CanvasLayer

@onready var main_control: Control = $Control
@onready var center_container: CenterContainer = $Control/CenterContainer
@onready var settings_menu: Control = $Control/Settings_menu

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

	if OS.is_debug_build():
		if Input.is_key_label_pressed(KEY_KP_0):
			center_container.visible = !center_container.visible

	if Input.is_action_just_pressed("escape"):
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

	# PERFECT RESET - start collapsed at the pivot, then reveal
	#main_control.pivot_offset = main_control.size * pivot_offset_ratio
	main_control.scale = Vector2.ONE * 0.01
	show()

	sfx_open_shop()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(main_control, "scale", Vector2.ONE, anim_duration)
	await tween.finished

	animating = false

func close_menu() -> void:
	if !visible or animating:
		return
	animating = true

	#main_control.pivot_offset = main_control.size * pivot_offset_ratio
	sfx_close_menu()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(main_control, "scale", Vector2.ONE * 0.01, anim_duration)
	await tween.finished


	hide()
	get_tree().paused = false
	Input.mouse_mode = stored_mouse_mode
	settings_menu.visible = false

	animating = false

func start() -> void:
	settings_menu.visible = false
	if visible:
		close_menu()
	else:
		open_menu()

func _on_close_game_pressed() -> void:
	get_tree().quit()

func _on_cancel_menu_pressed() -> void:
	close_menu()

func _on_settings_pressed() -> void:
	settings_menu.visible = !settings_menu.visible

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
