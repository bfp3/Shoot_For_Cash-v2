extends Control

signal ammo_selection_complete(bullets_selected: int)

@onready var selector_gui = $AmmoSelectorGUI
@onready var bullet_pool = $TotalBulletsRemaining

func _ready() -> void:
	begin_ammo_selection(6, 36)

func begin_ammo_selection(max_loadout: int, total_bullets: int):
	selector_gui.setup(max_loadout)
	bullet_pool.setup(total_bullets)
	show()

func close_ammo_selector():
	hide()
	var selected_bullets = selector_gui.get_selected_count()
	ammo_selection_complete.emit(selected_bullets)
	ammo_selection_complete.emit()
	#emit_signal("ammo_selection_complete", selected_bullets)
