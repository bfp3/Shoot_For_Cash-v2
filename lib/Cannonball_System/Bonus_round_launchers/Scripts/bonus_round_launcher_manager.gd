extends Node3D

@onready var bonus_cannon_unit: Node3D = $Bonus_cannon_unit

func _on_game_won_lost() -> void:
	bonus_cannon_unit._on_game_won_lost()
	if get_children().size() > 0:
		for i in get_children():
			if i != null:
				if i.has_method('was_hit_tween'):
					i.was_hit_tween()
					await get_tree().create_timer(0.15).timeout
