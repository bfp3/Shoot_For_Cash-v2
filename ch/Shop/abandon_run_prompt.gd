extends Control

signal confirmed
signal cancelled

@onready var _yes: Button = %YesButton
@onready var _no: Button = %NoButton

var _busy := false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _yes:
		_yes.pressed.connect(_on_yes)
	if _no:
		_no.pressed.connect(_on_no)


func open_prompt() -> void:
	if _busy:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	show()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	await tween.finished
	UiFocus.grab_in(self, _no)


func close_prompt() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	modulate.a = 1.0
	_busy = false


func _on_no() -> void:
	if _busy:
		return
	close_prompt()
	cancelled.emit()


func _on_yes() -> void:
	if _busy:
		return
	_busy = true
	close_prompt()
	confirmed.emit()
