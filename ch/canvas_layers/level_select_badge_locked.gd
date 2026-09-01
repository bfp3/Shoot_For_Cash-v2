@tool
extends Control
class_name LevelSelectBadgeLocked

const SHING_SFX := preload("res://sfx/ninja_flicker.ogg")
const LOCKED_SPIN_RETURN_SEC := 0.25

@export_range(0.15, 2.5, 0.01, "or_greater") var badge_scale := 0.5:
	set(value):
		badge_scale = maxf(value, 0.05)
		scale = Vector2.ONE * badge_scale
		pivot_offset_ratio = Vector2(0.5, 0.5)

var locked := true

@onready var _button: Button = get_node_or_null("HitButton") as Button
@onready var _shing: AudioStreamPlayer = get_node_or_null("SFX/shing_sfx") as AudioStreamPlayer

var _wiggle: Tween
var _spin_tween: Tween
var _spin_token := 0
var _busy := false


func _ready() -> void:
	add_to_group("difficulty_badge")
	pivot_offset_ratio = Vector2(0.5, 0.5)
	if Engine.is_editor_hint():
		scale = Vector2.ONE * badge_scale



func lock_out_selection() -> void:
	if not is_visible_in_tree():
		return
	_busy = true
	_abort_spin()
	if _button:
		_button.disabled = true


func fade_away_for_selection(selected: Node) -> void:
	if selected == self or not is_visible_in_tree():
		return
	_abort_spin()
	if _button:
		_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale = Vector2.ONE
	hide()
	modulate.a = 0.0


func reset_selection_state() -> void:
	_busy = false
	_abort_spin()
	visible = true
	show()
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation_degrees = 0.0
	top_level = false
	z_index = 0
	if _button:
		_button.disabled = false
		_button.mouse_filter = Control.MOUSE_FILTER_STOP





func _blink_visible(duration: float) -> void:
	var elapsed := 0.0
	var shown := true
	while elapsed < duration and is_inside_tree():
		shown = not shown
		visible = shown
		var step := 0.08
		await get_tree().create_timer(step, true).timeout
		elapsed += step
	if is_inside_tree():
		visible = true
		show()


func _apply_center_pivot() -> void:
	if size.x < 1.0 or size.y < 1.0:
		size = custom_minimum_size
	pivot_offset_ratio = Vector2(0.5, 0.5)
	pivot_offset = size * 0.5


func _abort_spin() -> void:
	_spin_token += 1
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = null
