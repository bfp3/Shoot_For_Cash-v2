extends HBoxContainer

@onready var ticket: Button = $VBoxContainer/Tickets/Ticket
@onready var ticket_2: Button = $VBoxContainer/Tickets/Ticket2
@onready var ticket_3: Button = $VBoxContainer/Tickets/Ticket3
@onready var ticket_4: Button = $VBoxContainer/Tickets/Ticket4
@onready var ticket_5: Button = $VBoxContainer/Tickets/Ticket5

@onready var tickets_array : Array = [ticket,ticket_2,ticket_3,ticket_4,ticket_5]

@onready var shop_main_menu: Control = $'../../../..'

func _ready():
	update_tickets()


func update_tickets() -> void:
	for i in tickets_array:
		i._update_tickets()

func check_tickets() -> void:
	for i in tickets_array:
		i.check_tickets()

#
#func Xupdate_tickets() -> void:
	#ticket.location_name = gl_DataSet.get_string("place_name",0).capitalize()
	#ticket_2.location_name = gl_DataSet.get_string("place_name",1).capitalize()
	#ticket_3.location_name = gl_DataSet.get_string("place_name",2).capitalize()
	#ticket_4.location_name = gl_DataSet.get_string("place_name",3).capitalize()
	#ticket_5.location_name = gl_DataSet.get_string("place_name",4).capitalize()
#
	#var tickets_bought : int = gl_PlayerState.dataset.tickets
	#
	#for i in tickets_array:
		#i.disabled = true
	#
	#for i in range(min(tickets_bought, tickets_array.size())):
		#tickets_array[i].enter_state(tickets_array[i].TicketState.AVAILABLE)
		#
