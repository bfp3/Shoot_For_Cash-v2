extends Control

## Bottom-of-screen reticle sensitivity feedback. Reuses GameSettings stage text.

@onready var title_label: RichTextLabel = %ReticleSensTitle
@onready var value_label: RichTextLabel = %ReticleSensValue
@onready var hint_left: RichTextLabel = %ReticleSensHintLeft
@onready var hint_right: RichTextLabel = %ReticleSensHintRight

@export var show_duration := 1.6
@export var anim_duration := 0.22

var _hide_tween: Tween
var _rest_position := Vector2.ZERO


func _ready() -> void:
	_rest_position = position
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	modulate.a = 0.0


func show_sensitivity(level: int, from_controller: bool) -> void:
	value_label.text = GameSettings.sensitivity_display_text(level)
	if from_controller:
		# Bound in project.godot to Joypad shoulder buttons (LB/RB), not triggers.
		hint_left.text = "LB"
		hint_right.text = "RB"
	else:
		hint_left.text = "-"
		hint_right.text = "+"

	if _hide_tween:
		_hide_tween.kill()

	show()
	modulate.a = 1.0
	position = _rest_position + Vector2(0.0, 40.0)

	_hide_tween = create_tween()
	_hide_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hide_tween.tween_property(self, "position", _rest_position, anim_duration)
	_hide_tween.parallel().tween_property(self, "modulate:a", 1.0, anim_duration * 0.5)
	_hide_tween.tween_interval(show_duration)
	_hide_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_hide_tween.tween_callback(hide)
