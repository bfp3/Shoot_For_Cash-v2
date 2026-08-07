extends Control

## Keep / Revert overlay after a resolution change (15s countdown).

signal kept
signal reverted

@onready var countdown_label: Label = %CountdownLabel
@onready var keep_button: Button = %KeepButton
@onready var revert_button: Button = %RevertButton


func _ready() -> void:
	hide()
	keep_button.pressed.connect(_on_keep)
	revert_button.pressed.connect(_on_revert)
	GameSettings.resolution_confirm_started.connect(_on_started)
	GameSettings.resolution_confirm_tick.connect(_on_tick)
	GameSettings.resolution_confirm_finished.connect(_on_finished)


func _on_started(_seconds: float) -> void:
	show()
	_on_tick(ceili(GameSettings.confirm_seconds_left()))


func _on_tick(seconds_left: float) -> void:
	countdown_label.text = "Keep this resolution?\nReverting in %d..." % int(seconds_left)


func _on_finished(_kept: bool) -> void:
	hide()


func _on_keep() -> void:
	GameSettings.keep_resolution()
	kept.emit()


func _on_revert() -> void:
	GameSettings.revert_resolution()
	reverted.emit()
