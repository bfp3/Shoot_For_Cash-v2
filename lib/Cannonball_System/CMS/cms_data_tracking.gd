extends Node


#func _ready() -> void:
	#GlobalsPlayerStats.current_round = 0
#
	#launcher_nodes = get_children().filter(func(c): return c.has_method("assign_round_parameters"))
	#total_launchers = launcher_nodes.size()
	#
	#GlobalsPlayerStats.current_round = total_launchers
#
	#randomize()
#
#func set_next_batch(batch: Array) -> void:
	#if game_over:
		#return
	#next_batch = batch
#
#
#
#func start_round_loop() -> void:
   #
	#if GameManager.current_score_not_displayed >= GameManager.score_to_beat_for_the_level:
		#is_pineapple_round = randf() < 0.8
	#else:
		#is_pineapple_round = false
#
	#counter += 1
	#total_rounds_shot += 1
	#if !first_round:
		#GlobalsPlayerStats.current_round += 1
		#
	#get_shots_prepped()
	#
#func get_shots_prepped() -> void:
	#currently_shooting = true
	##%Bomb_container_array.turn_off_checking()
	#
	#if total_rounds_shot > smokescreen_threshold && !already_run_smokescreen && smokescreen_mode:
		#var rand_num = randf_range(0.0, 1.0)
		#if rand_num > 0.05:
			#already_run_smokescreen = true
			#launcher_is_smokescreen = true
			#stagger_time_between_launcher_rounds = 0.1
			#await run_round()
			#await get_tree().create_timer(0.5).timeout
			#stagger_time_between_launcher_rounds = 0.5
			#launcher_is_smokescreen = false
			#run_round()
			##await get_tree().create_timer(2.0).timeout
			##%Bomb_container_array.start_checking_empty()
			#first_round = false
			#return
	#
	#else:
		#stagger_time_between_launcher_rounds = 0.5
		#run_round()
		#
		##await get_tree().create_timer(1.0).timeout
		##%Bomb_container_array.start_checking_empty()
		#first_round = false
	#
#
#
#func run_round() -> void:

	#if next_batch.is_empty():
		#push_warning("No shot batch provided.")
		#return
#
	#var batch_index := 0
	#var batch_size := next_batch.size()
#
	#for launcher in launcher_nodes:
		#if batch_index >= batch_size:
			#break
#
		#launcher.visual_fire()
#
		#var shot_data: Dictionary = next_batch[batch_index]
		#prepare_target_for_launch(launcher, shot_data)
#
		#batch_index += 1
		#await get_tree().create_timer(stagger_time_between_launcher_rounds).timeout
#
	#already_run_smokescreen = false
	#currently_shooting = false
