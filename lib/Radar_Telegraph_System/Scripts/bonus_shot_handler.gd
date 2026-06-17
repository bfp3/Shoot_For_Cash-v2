extends Node

func generate_bonus_shot() -> String:
	return $"../BatchProbabilityHandler".generate_single_shot()
