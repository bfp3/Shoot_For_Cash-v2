extends Control

@onready var loadout_slots = $LoadoutSlots
@onready var confirm_button = $ConfirmButton
@onready var ammo_slot: Panel = $Ammo_slot_duplicate/ammo_slot

var max_loadout = 6

func setup(max_loadout_slots: int):
	max_loadout = max_loadout_slots
	loadout_slots.get_children().clear()
	for i in range(max_loadout):
		var slot = ammo_slot.duplicate()
		slot.show()
		loadout_slots.add_child(slot)
		slot.make_empty_outline()
		slot.global_position.x = slot.size.x * i + 100

func get_selected_count() -> int:
	var count = 0
	for slot in loadout_slots.get_children():
		if slot.has_bullet():
			count += 1
	return count

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)

func _on_confirm_pressed():
	get_parent().close_ammo_selector()
