extends Control

## Editable "You've unlocked [island]" overlay used by MapIslandSelect.

signal dismissed

@onready var message_label: RichTextLabel = %MessageLabel
@onready var close_button: Button = %CloseButton
@onready var dim: ColorRect = $Dim

@export var fade_out_duration := 0.3

var _dismissed := false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if dim and not dim.gui_input.is_connected(_on_dim_gui_input):
		dim.gui_input.connect(_on_dim_gui_input)


func is_open() -> bool:
	return visible and not _dismissed


func play(island_name: String) -> void:
	_dismissed = false
	if message_label:
		message_label.text = "[center][wave]%s[/wave]\nUnlocked[/center]" % island_name.to_upper()

	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	await get_tree().process_frame
	if close_button and is_instance_valid(close_button):
		close_button.grab_focus()

	while not _dismissed and is_inside_tree() and visible:
		await get_tree().process_frame

	if not is_inside_tree():
		return

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	await fade.finished

	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0
	dismissed.emit()


func force_close() -> void:
	_dismissed = true
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0


func _on_close_pressed() -> void:
	_dismissed = true


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismissed = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dismissed:
		return
	if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("controller_back_button") or event.is_action("escape")):
		_dismissed = true
		get_viewport().set_input_as_handled()
