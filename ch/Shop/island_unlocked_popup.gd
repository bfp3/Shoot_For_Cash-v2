extends Control

## Editable "You've unlocked [island]" overlay — open/close like the pause menu.

signal dismissed

@onready var message_label: RichTextLabel = %MessageLabel
@onready var close_button: Button = %CloseButton
@onready var dim: ColorRect = $Dim
@onready var panel: Control = $CenterContainer/Panel
@onready var confetti: CPUParticles2D = $Confetti

@export var anim_duration := 0.25

var _dismissed := false
var _animating := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if panel:
		panel.pivot_offset = panel.size * 0.5
	if confetti:
		confetti.emitting = false
		confetti.one_shot = true
		confetti.lifetime = 3.0
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if dim and not dim.gui_input.is_connected(_on_dim_gui_input):
		dim.gui_input.connect(_on_dim_gui_input)


func is_open() -> bool:
	return visible and not _dismissed and not _animating


func play(island_name: String) -> void:
	if _animating:
		return
	_dismissed = false
	_animating = true

	if message_label:
		message_label.text = "[center][wave]%s[/wave]\nUnlocked[/center]" % island_name.to_upper()

	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	await get_tree().process_frame
	if panel:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2.ONE * 0.01
	if dim:
		dim.modulate.a = 0.0

	sfx_open()
	_restart_confetti()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	if panel:
		tween.tween_property(panel, "scale", Vector2.ONE, anim_duration)
	if dim:
		tween.parallel().tween_property(dim, "modulate:a", 1.0, anim_duration).set_delay(0.12)
	await tween.finished

	_animating = false
	if close_button and is_instance_valid(close_button):
		close_button.grab_focus()

	while not _dismissed and is_inside_tree() and visible:
		await get_tree().process_frame

	if not is_inside_tree():
		return

	await _play_close_animation()
	dismissed.emit()


func force_close() -> void:
	_dismissed = true
	_animating = false
	if confetti:
		confetti.emitting = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel:
		panel.scale = Vector2.ONE
	if dim:
		dim.modulate.a = 1.0


func _play_close_animation() -> void:
	if _animating:
		return
	_animating = true
	sfx_close()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	if panel:
		tween.tween_property(panel, "scale", Vector2.ONE * 0.01, anim_duration)
	await tween.finished

	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel:
		panel.scale = Vector2.ONE
	if dim:
		dim.modulate.a = 1.0
	if confetti:
		confetti.emitting = false
	_animating = false


func _restart_confetti() -> void:
	if confetti == null:
		return
	confetti.one_shot = true
	confetti.lifetime = 3.0
	confetti.restart()
	confetti.emitting = true


func _on_close_pressed() -> void:
	if _animating:
		return
	_dismissed = true


func _on_dim_gui_input(event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismissed = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dismissed or _animating:
		return
	if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("controller_back_button") or event.is_action("escape")):
		_dismissed = true
		get_viewport().set_input_as_handled()


func sfx_open() -> void:
	var open_sfx := get_node_or_null("SFX/shop_open_sfx_01") as AudioStreamPlayer
	var click1 := get_node_or_null("SFX/hud_click_1") as AudioStreamPlayer
	var click2 := get_node_or_null("SFX/hud_click_2") as AudioStreamPlayer
	var click3 := get_node_or_null("SFX/hud_click_3") as AudioStreamPlayer
	var hum := get_node_or_null("SFX/low_humming") as AudioStreamPlayer
	if open_sfx:
		open_sfx.play(0.3)
	if click1:
		click1.play()
	if click2:
		click2.play()
	if click3:
		click3.play()
	if hum:
		hum.play()


func sfx_close() -> void:
	var close_sfx := get_node_or_null("SFX/shop_close_sfx_01") as AudioStreamPlayer
	var click1 := get_node_or_null("SFX/hud_click_1") as AudioStreamPlayer
	var click2 := get_node_or_null("SFX/hud_click_2") as AudioStreamPlayer
	var click3 := get_node_or_null("SFX/hud_click_3") as AudioStreamPlayer
	var hum := get_node_or_null("SFX/low_humming") as AudioStreamPlayer
	if close_sfx:
		close_sfx.play()
	if click1:
		click1.play()
	if click2:
		click2.play()
	if click3:
		click3.play()
	if hum:
		hum.play()
