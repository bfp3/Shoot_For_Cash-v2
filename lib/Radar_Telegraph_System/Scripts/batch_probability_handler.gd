extends Node

func generate_batch(min_shots: int) -> Array:
	var result := []

	for i in range(min_shots):
		result.append(generate_single_shot())

	return result

func generate_single_shot() -> String:
	var r = randf()

	if r < 0.2:
		return "RED"
	elif r < 0.5:
		return "ORANGE"
	else:
		return "GREY"
