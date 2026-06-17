extends Node3D



func _ready() -> void:
	var HUD_CRT = get_tree().get_first_node_in_group('TV_CRT_Filter')
	if HUD_CRT:
		HUD_CRT.crt_start_up()
	#BackgroundForTransition.fade_in()
	
	
	
#
#@onready var zoom_out_sequence: Node3D = %Zoom_out_sequence
#var counter_to_win := 3

	#EventBus.instance.enemy_popper_shot.connect(_enemy_taken_out)
	#EventBus.instance.enemy_present.connect(_count_enemies)
	#EventBus.instance.game_won.connect(game_won)
	##get_viewport().debug_draw = Viewport.DEBUG_DRAW_UNSHADED
#
#func _count_enemies() -> void:
	##counter_to_win += 1+
	#return
#
#
#func _enemy_taken_out() -> void:
	#counter_to_win -= 1
	#if counter_to_win <= 0:
		#game_won()
#
		#
#func game_won() -> void:
	#
	#await get_tree().create_timer(5.0).timeout
	#
	#var birds : Node3D = get_tree().get_first_node_in_group('fly_by_birds')
	#if birds:
		#birds.bird_fly_by()
	#
	#EventBus.instance.release_hostages_start.emit()
	#
	#await get_tree().create_timer(5.0).timeout
	#
	#EventBus.instance.player_has_hit_winning_score.emit()
	#zoom_out_sequence.begin_winning_zoom_out_process()
	#
	#
