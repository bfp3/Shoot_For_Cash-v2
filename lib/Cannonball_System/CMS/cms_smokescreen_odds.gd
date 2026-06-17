extends Node

@onready var cms: CMS = $".."

var current_round := 0
var round_smokescreen_begins := 3
var smokescreen_probability := 0.3

func check_for_smokescreen_odds():
	current_round = cms.current_round
	
	if current_round >= round_smokescreen_begins:
		return run_smokescreen_odds()

	else:
		return false
		
func run_smokescreen_odds():
	if randf() > smokescreen_probability: # 70% chance
		return true
	else:
		return false
