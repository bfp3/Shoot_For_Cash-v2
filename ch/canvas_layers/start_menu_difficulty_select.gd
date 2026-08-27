extends Control

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var _busy := false

@onready var _buttons: Node = %DifficultySelectButtons
@onready var _back_button: Button = %MapButton


func _ready() -> void:
	add_to_group("difficulty_select")
	default_scale = scale
	default_position = position
	pivot_offset_ratio = Vector2(0.5, 0.5)
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _buttons and _buttons.has_signal("level_chosen"):
		_buttons.level_chosen.connect(_on_level_chosen)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)


func open_pop_up() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	show()
	CommonCode.apply_ui_overlay_blur()
	if _buttons and _buttons.has_method("refresh_unlocks"):
		_buttons.refresh_unlocks()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await tween.finished
	if _buttons:
		var beginner := _buttons.get_node_or_null("Beginner") as Control
		UiFocus.grab_in(self, beginner)


func close_pop_up() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	scale = default_scale
	modulate.a = 1.0


func _on_level_chosen(place: String, stage_title: String = "BEGINNER") -> void:
	if _busy:
		return
	place = place.strip_edges().to_lower()
	if place.is_empty():
		return
	_busy = true
	close_pop_up()
	if gl_PlayerState.has_method("set_run_difficulty"):
		gl_PlayerState.set_run_difficulty(stage_title)
	else:
		gl_PlayerState.dataset.run_difficulty = stage_title
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("travel_to_level"):
		await rm.travel_to_level(place)
	_busy = false


func _on_back_pressed() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_pause"):
		menus.ensure_pause()
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif pause_menu and pause_menu.has_method("start"):
		pause_menu.start()
