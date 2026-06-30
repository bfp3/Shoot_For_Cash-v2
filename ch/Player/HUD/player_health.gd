extends Control

@export var total_health := 20
@onready var health_remaining: RichTextLabel = $Control/Health_remaining

func _ready() -> void:
	update_label()

func take_damage() -> void:
	print('taking damage')

	total_health -= 1
	update_label()
	if total_health <= 0:
		$"..".hide()
		%Player.stop_player()
		
	
func gain_health(health_added : int) -> void:
	total_health += health_added
	update_label()
	
func update_label() -> void:
	health_remaining.text = '[wave]' + str(total_health)
