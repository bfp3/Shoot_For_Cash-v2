extends Node

var reveal_chances_guaranteed := [
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0
]

var reveal_chances_unguaranteed := [
	0.95,  # 1st dot
	0.90,  # 2nd dot
	0.75,  # 3rd
	0.35,  # 4th
	0.30,  # 5th
	0.20   # 6th
]

var reveal_chances := []
var guaranteed := false
var fallback_chance := 0.10

# Track how many dots have been hidden
var hidden_count := 0
var max_hidden := 2

func should_reveal_true_color(dot_index: int) -> bool:
	if !guaranteed:
		reveal_chances = reveal_chances_unguaranteed
	else:
		reveal_chances = reveal_chances_guaranteed
	
	# Force reveal if 2 have already been hidden
	if hidden_count >= max_hidden:
		return true

	var chance = reveal_chances[dot_index] if dot_index < reveal_chances.size() else fallback_chance
	var reveal = randf() < chance

	if !reveal:
		hidden_count += 1
	
	return reveal
