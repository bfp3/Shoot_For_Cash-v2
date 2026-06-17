extends Node3D

var stagger_time := 0.5

func send_in_the_pineapples() -> void:
	
	for i in get_children():
		if i.has_method('send_pineapple'):
			i.send_pineapple()
		await get_tree().create_timer(stagger_time).timeout
