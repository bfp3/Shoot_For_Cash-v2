extends Control

@export var game_start_menu : Control

@onready var purchased_ticket:= $MainPanel/TreePanel/PurchasedTicket
const RED_SHOP = preload('uid://hy4w24j6p2er')
const MOSS_SHOP = preload('uid://bcvk6h5k84n3h')
const END_CARD = preload('uid://hy4w24j6p2er')

var ticket_location := ''

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	pass


func display_ticket() -> void:
	return
	var ticket_bought = gl_PlayerState.dataset.level_name
	
	match ticket_bought:
		"start":
			purchased_ticket.name_label.text = "Ticket to Moss"
			purchased_ticket.upgrade_icon = MOSS_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "moss"
			
		"moss":
			purchased_ticket.name_label.text = "Ticket to Redd"
			purchased_ticket.upgrade_icon = RED_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "redd"
			
		"redd":
			purchased_ticket.name_label.text = "To end the demo"
			purchased_ticket.upgrade_icon = END_CARD
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "end game"
			print('headed to finish')

	open_pop_up()
	
func open_pop_up() -> void:
	ticket_location = "moss"
	modulate.a = 0.0
	show()
	position = Vector2.ZERO
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	await tween.finished
	
func close_pop_up() -> void:
	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, 0.25)
	await  tween2.finished
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func _on_next_round_pressed() -> void:
	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, 0.25)
	await  tween2.finished
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func ticket_used() -> void:
	if gl_PlayerState.change_location(ticket_location) == true:
		game_start_menu.enter_state(game_start_menu.State.CLOSE_MENU)
		_on_next_round_pressed()
	
	#if gl_PlayerState.change_location(ticket_location) == true:
		#$"..".enter_state($"..".SkillState.CLOSE_MENU)
		
		
	#await get_tree().create_timer(3.5).timeout
	#%Transport_Tickets.check_tickets()
