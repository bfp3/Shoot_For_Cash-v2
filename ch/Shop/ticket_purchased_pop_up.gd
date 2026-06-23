extends CenterContainer
@onready var purchased_ticket:= $MainPanel/TreePanel/PurchasedTicket
const RED_SHOP = preload('uid://hy4w24j6p2er')
const MOSS_SHOP = preload('uid://bcvk6h5k84n3h')
const END_CARD = preload('uid://di3u081qrsqpy')

var ticket_location := ''

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()


func display_ticket() -> void:
	var ticket_bought = gl_PlayerState.dataset.stage_name
	
	match ticket_bought:
		"start":
			purchased_ticket.name_label.text = "Ticket to Moss"
			purchased_ticket.upgrade_icon = MOSS_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "moss"
			print('headed to moss')
			
		"moss":
			purchased_ticket.name_label.text = "Ticket to Redd"
			purchased_ticket.upgrade_icon = RED_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "redd"
			print('headed to moss')
			
		"redd":
			purchased_ticket.name_label.text = "To end the demo"
			purchased_ticket.upgrade_icon = END_CARD
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			ticket_location = "end game"
			print('headed to finish')

	
	modulate.a = 0.0
	show()
	self.mouse_filter = 0
	$MainPanel/TreePanel/PurchasedTicket.disabled = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	%ticket_particles.emitting = true
	await %ticket_particles.finished


	%ticket_particles2.emitting = true
	await %ticket_particles2.finished

	%ticket_particles3.emitting = true
	await %ticket_particles3.finished
	
	%ticket_particles4.emitting = true
	await %ticket_particles4.finished


func _on_next_round_pressed() -> void:
	var tween2 = create_tween()
	tween2.tween_property(self, "modulate:a", 0.0, 0.25)
	await  tween2.finished
	mouse_filter = 2
	hide()

func ticket_used() -> void:
	
	if gl_PlayerState.change_location(ticket_location) == true:
		$"..".enter_state($"..".SkillState.CLOSE_MENU)
		_on_next_round_pressed()
		
	
	await get_tree().create_timer(3.5).timeout
	%Transport_Tickets.check_tickets()
