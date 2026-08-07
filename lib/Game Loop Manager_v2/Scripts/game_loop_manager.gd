extends Node

#class_name GameLoopManager
#
#@export var phases: Array[PackedScene] = []
#
#var current_phase: Node = null
#var phase_index: int = 0
#var game_ended := false
#var game_loop_current_round := 1
#
#func _ready():
	#EventBus.instance.game_won.connect(_on_game_won)
	#GameManager.silence_phase_done = false
	#return
#
#func start_next_phase() -> void:
	#
	#if current_phase:
		#current_phase.queue_free()
#
	#if phase_index >= phases.size():
		#phase_index = 0 # or handle end of loop specially
		#game_loop_current_round += 1 #onto the next round, used by other nodes
#
	#current_phase = phases[phase_index].instantiate()
	#add_child(current_phase)
#
	#current_phase.start_phase() # You can define a common method all phases have
	#current_phase.phase_complete.connect(_on_phase_complete)
#
#func _on_game_won() -> void:
	#game_ended = true
#
#func _on_phase_complete() -> void:
	#if game_ended:
		#return
	#phase_index += 1
	#start_next_phase()
	#
#func game_lost() -> void:
	#game_ended = true
#
#func _on_settle_phase_complete() -> void:
	#phase_index = 2
	#game_loop_current_round += 1
	#start_next_phase()
