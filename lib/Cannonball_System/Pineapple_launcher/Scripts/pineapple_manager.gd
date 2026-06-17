extends Node3D

var stagger_time := 0.05

@onready var launcher_array := [$Pineapple_launcher, $Pineapple_launcher2, $Pineapple_launcher3]

func send_in_the_pineapples() -> void:
	
	var amount_of_pineapples := 3 #GameManager.pineapples_available_within_level
	
	#$Pineapple_launcher.send_pineapple()
	#await get_tree().create_timer(0.25).timeout
	#$Pineapple_launcher2.send_pineapple()
	#await get_tree().create_timer(0.30).timeout
	#$Pineapple_launcher3.send_pineapple()
	#await get_tree().create_timer(0.35).timeout
	
	for i in range(amount_of_pineapples):
		if i >= 3:
			i = 0
		launcher_array[i].send_pineapple()
		await get_tree().create_timer(stagger_time).timeout
		#EventBus.instance.pineapple_launched.emit()
		stagger_time += 0.005
