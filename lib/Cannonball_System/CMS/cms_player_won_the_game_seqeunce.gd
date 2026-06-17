extends Node

var game_over := false

func smoke_player_won_sequence() -> void:
	if game_over:
		return
		
	game_over = true
	#var delay_time : float = 0.05
	#for i in range(5):
		#for launcher in launcher_nodes:
			#launcher.smoke_up()
			#await get_tree().create_timer(delay_time).timeout
			#stagger_time_between_launcher_rounds += 0.05
