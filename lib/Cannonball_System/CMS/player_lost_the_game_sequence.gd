extends Node

func remove_all_active_bombs() -> void:
	var launcher_manager := get_tree().get_first_node_in_group('launcher_manager')
	if launcher_manager:
		launcher_manager.game_lost_remove_everything()
