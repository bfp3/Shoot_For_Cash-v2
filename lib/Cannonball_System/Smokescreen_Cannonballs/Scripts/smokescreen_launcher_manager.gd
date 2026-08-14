extends Node3D

#@export var stagger_time := 0.05
#@onready var cms : CMS = get_tree().get_first_node_in_group("CMS")
#
#const MAX_SMOKERS := 8
#
##func _ready() -> void:
	##send_smokescreen()
#
#func send_smokescreen() -> void:
	#
	#var number_of_smokers = cms.current_round
	#number_of_smokers = clamp(number_of_smokers, 3, MAX_SMOKERS)
	#
	#for i in range(number_of_smokers):
		#$Smokescreen_launcher.send_smokescreen()
		##await get_tree().create_timer(stagger_time).timeout
		#
	#if cms:
		#cms.smokescreen_finished()
		#
	##await get_tree().create_timer(2.0).timeout
	##send_smokescreen()
