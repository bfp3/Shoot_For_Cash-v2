extends CenterContainer
@onready var purchased_ticket: UpgradeNode = $MainPanel/TreePanel/PurchasedTicket
const RED_SHOP = preload('uid://hy4w24j6p2er')
const MOSS_SHOP = preload('uid://bcvk6h5k84n3h')
const GUN_ICON_SHOP = preload('uid://icyevci50hge')


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()


func display_ticket() -> void:
	var ticket_bought = gl_PlayerState.dataset.stage_name
	if purchased_ticket.tooltip != null:
		purchased_ticket.tooltip.queue_free()
		
		
	match ticket_bought:
		"start":
			purchased_ticket.name_label.text = "Ticket to Moss"
			purchased_ticket.upgrade_icon = MOSS_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			print('headed to moss')
			
		"moss":
			purchased_ticket.name_label.text = "Ticket to Redd"
			purchased_ticket.upgrade_icon = RED_SHOP
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			print('headed to moss')
			
		"redd":
			purchased_ticket.texture = GUN_ICON_SHOP
			purchased_ticket.name_label.text = "Ticket to The End"
			purchased_ticket.upgrade_icon_textureRect.texture = purchased_ticket.upgrade_icon
			print('headed to moss')

	
	modulate.a = 0.0
	show()
	self.mouse_filter = 0
	
	
	$BackgroundParticles.emitting = true
	$MainPanel/TreePanel/PurchasedTicket.disabled = true
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
	$BackgroundParticles.emitting = false
	hide()
