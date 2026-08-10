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
@onready var glory_button: Control = $TreePanel/Buttons/Level_button_selector3
@onready var noir_button: Control = $TreePanel/Buttons/Level_button_selector4
@onready var vesper_button: Control = $TreePanel/Buttons/Level_button_selector5
@onready var map_cash_label: RichTextLabel = %MapCashBalanceLabel
@onready var cash_needed_label: RichTextLabel = %CashNeededAmountLabel


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
	_refresh_map_cash_labels()

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


func _map_level_buttons() -> Array:
	return [moss_button, redd_button, glory_button, noir_button, vesper_button]


## Demo map only shows Moss / Redd / Glory.
func _map_visible_level_buttons() -> Array:
	return [moss_button, redd_button, glory_button]


func _unlock_map_button(button: Control) -> void:
	if button == null:
		return
	button.visible = true
	button.level_locked = false
	if button.has_method('set_unlocked_visuals'):
		button.set_unlocked_visuals()
	elif button.get('current_state') != null and button.get('State') != null:
		if button.current_state != button.State.UNLOCKED:
			button.current_state = button.State.UNLOCKED
			if button.get('level_name_label'):
				button.level_name_label.text = "[wave]" + String(button.level_name).to_upper()


func _refresh_level_buttons() -> void:
	for button in [noir_button, vesper_button]:
		if button:
			button.visible = false
	for button in _map_visible_level_buttons():
		_unlock_map_button(button)
		if button.has_method("refresh_map_progress"):
			button.refresh_map_progress()
	_apply_completion_stamps(false)


func _refresh_map_cash_labels() -> void:
	var cash := int(gl_PlayerState.dataset.cash)
	if map_cash_label:
		map_cash_label.text = "$" + str(cash)
	var needed := int(gl_DataSet.get_value("cash_needed_next_island", 0))
	if needed < 0:
		needed = 10000
	if cash_needed_label:
		cash_needed_label.text = "$" + str(needed)


## Stamp the place button that matches place_id (tally-card style when animate).
func mark_place_completed(place_id: String, animate: bool = true) -> void:
	place_id = gl_DataSet.resolve_place_name(place_id)
	for button in _map_level_buttons():
		if button == null:
			continue
		var button_place := gl_DataSet.resolve_place_name(String(button.level_name).to_lower())
		if button_place != place_id:
			continue
		if button.has_method("mark_completed"):
			await button.mark_completed(animate)
		return
	_apply_completion_stamps(false)


func _apply_completion_stamps(animate: bool) -> void:
	for button in _map_level_buttons():
		if button and button.has_method("_refresh_completion_stamp"):
			button._refresh_completion_stamp(animate)


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
	await select_level(ticket_location if ticket_location != '' else gl_DataSet.get_default_range_name())
