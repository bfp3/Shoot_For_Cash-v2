extends Node



func next_rounds_prize_allocation() -> int:
	if GameManager.in_retry_world:
		return GameManager.pineapples_missed_this_round
	
	var player_collection := GameManager.total_number_of_pineapples_collected
	if player_collection <= 0:
		var total_return : int = ScoreGl.MAX_PINEAPPLES_PER_ROUND
		return total_return
	
	elif player_collection > 0:
		var total_return : int = ScoreGl.PINEAPPLES_AMOUNT_TO_COMPLETE - GameManager.total_number_of_pineapples_collected
		return total_return
		
	else:
		print_debug('cannot compute how many pineapples to allocate')
		var total_return : int = ScoreGl.MAX_PINEAPPLES_PER_ROUND
		return total_return
