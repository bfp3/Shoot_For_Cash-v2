extends Control

@export var game_start_menu : Control

const RED_SHOP = preload('uid://hy4w24j6p2er')
const MOSS_SHOP = preload('uid://bcvk6h5k84n3h')
const END_CARD = preload('uid://hy4w24j6p2er')

var ticket_location := ''
var _selecting_level := false

@onready var close_button: Button = $CloseMapButton
@onready var moss_button: Control = $TreePanel/Buttons/Level_button_selector
@onready var redd_button: Control = $TreePanel/Buttons/Level_button_selector2


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _selecting_level:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("controller_back_button") or event.is_action("ui_cancel"):
		_on_close_map_pressed()
		get_viewport().set_input_as_handled()


func open_pop_up() -> void:
	_selecting_level = false
	ticket_location = String(gl_PlayerState.dataset.level_name).to_lower()
	_refresh_level_buttons()

	modulate.a = 0.0
	show()
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	await tween.finished
	var preferred: Control = moss_button if moss_button and moss_button.visible else close_button
	UiFocus.grab_in(self, preferred)


func close_pop_up() -> void:
	if not visible:
		return
	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween2.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_restore_focus_after_close()


func _restore_focus_after_close() -> void:
	var shop := get_tree().get_first_node_in_group("shop_main_menu") as Control
	if shop and shop.is_visible_in_tree():
		UiFocus.grab_in(shop)
		return
	if game_start_menu and game_start_menu.is_visible_in_tree():
		UiFocus.grab_in(game_start_menu)


func _on_next_round_pressed() -> void:
	await close_pop_up()


func _on_close_map_pressed() -> void:
	await close_pop_up()


## First gun purchase / ticket flows that still call the old name.
func display_ticket() -> void:
	await open_pop_up()



func _refresh_level_buttons() -> void:
	# Moss is always available after the opening purchase flow.
	if moss_button:
		moss_button.visible = true
		moss_button.level_locked = false
		if moss_button.has_method('set_unlocked_visuals'):
			moss_button.set_unlocked_visuals()
		elif moss_button.current_state != moss_button.State.UNLOCKED:
			moss_button.current_state = moss_button.State.UNLOCKED
			moss_button.level_name_label.text = "[wave]" + String(moss_button.level_name).to_upper()

	# Redd is playable from the map once the player has left start.
	if redd_button:
		redd_button.visible = true
		redd_button.level_locked = false
		if redd_button.has_method('set_unlocked_visuals'):
			redd_button.set_unlocked_visuals()
		else:
			redd_button.current_state = redd_button.State.UNLOCKED
			redd_button.level_name_label.text = "[wave]" + String(redd_button.level_name).to_upper()
			redd_button.level_name_label.add_theme_font_size_override("normal_font_size", 109)
			if redd_button.has_node('HSeparator'):
				redd_button.get_node('HSeparator').scale.x = 1.0


## Called by level select buttons after their press animation.
func select_level(level_id: String) -> void:
	if _selecting_level:
		return
	_selecting_level = true
	level_id = level_id.to_lower()
	ticket_location = level_id

	var current := String(gl_PlayerState.dataset.level_name).to_lower()
	if level_id == current:
		await close_pop_up()
		_selecting_level = false
		return

	await close_pop_up()

	# Kick off travel first so `transitioning_worlds` blocks any SHOP_END from the start menu.
	var moved := gl_PlayerState.change_location(level_id)
	if moved and game_start_menu and game_start_menu.visible:
		# Soft-close only — do not enter CLOSE_MENU (that would call SHOP_END).
		if game_start_menu.has_method('sfx_close_shop'):
			game_start_menu.sfx_close_shop()
		game_start_menu.hide()
		game_start_menu.current_state = game_start_menu.State.INACTIVE

	_selecting_level = false


func ticket_used() -> void:
	# Legacy path — prefer select_level from map buttons.
	await select_level(ticket_location if ticket_location != '' else 'moss')
