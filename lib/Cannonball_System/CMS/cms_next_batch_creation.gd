extends Node

#@onready var cms: CMS = $".."
#@onready var batch_handler = $BatchProbabilityHandler
#@onready var bonus_handler = $BonusShotHandler
#
#const MIN_SHOTS := 1
#const MAX_SHOTS := 10
#const MAX_RED_SHOTS_ALLOWED:= 5
#const MAX_ORANGE_SHOTS_ALLOWED := 1  # New limit for orange shots
#
#var  current_round := 0
#var next_batch := []
#
#func create_new_batch() -> void:
	#current_round = cms.current_round
#
	#var min_shots = clamp(3 + current_round - 1, MIN_SHOTS, MAX_SHOTS)
	#var bonus_chance = clamp(0.1 + (current_round * 0.03), 0.1, 0.5)
#
	#next_batch.clear()
	#var red_count : int = 0
	#var orange_count : int = 0
#
	#for i in range(min_shots):
		#var shot_type = batch_handler.generate_single_shot()
#
		#if shot_type == "RED":
			#if red_count >= MAX_RED_SHOTS_ALLOWED:
				#shot_type = "GREY"
			#else:
				#red_count += 1
		#elif shot_type == "ORANGE":
			#if orange_count >= MAX_ORANGE_SHOTS_ALLOWED:
				#shot_type = "GREY"
			#else:
				#orange_count += 1
#
		#var shot_data = {
			#"type": shot_type
		#}
		#next_batch.append(shot_data)
#
	#if randf() < bonus_chance:
		#var bonus_type = bonus_handler.generate_bonus_shot()
		#var bonus_data = {
			#"type": bonus_type
		#}
		#next_batch.append(bonus_data)
	#
	#phase_completed()
#
#
#func phase_completed() -> void:
	#if cms:
		#cms.send_data_to_launchers(next_batch)
	#else:
		#push_warning("CMS reference lost when trying to send batch!")
