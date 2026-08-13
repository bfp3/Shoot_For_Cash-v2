extends Control

## Editable ACCESS HOLD OUT overlay used by MapIslandSelect.

@onready var message_label: RichTextLabel = %MessageLabel

@export var fade_in_duration := 0.18
@export var hold_duration := 1.6
@export var fade_out_duration := 0.35

var _busy := false
var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_busy() -> bool:
	return _busy


func play(cost: int) -> void:
	if _busy:
		return
	_busy = true
	if _tween:
		_tween.kill()

	var money_text := CommonCode.format_money(cost)
	if message_label:
		message_label.text = "[center][wave]YOU NEED %s[/wave][/center]" % money_text

	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	_tween.tween_interval(hold_duration)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	await _tween.finished

	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	_tween = null
