extends Node

var mouse_sensitivity := 1.0

const DEFAULT_DATASET := {
	"cash": 109,
	"stage": 0,
	"stage_name": "start",
	"tickets": 0,
	"debug_add_cash": 1000,

	"round": 0,
	"earnings": 0,
	"fines": 0,
	"reroll": 0,
	"reroll_unlocked": 0,
	
	"rock_limit" : 1,

	"total_rocks_in_round": 0,
	"total_rocks_in_round_remaining": 0,
	"total_rocks_destroyed" : 0,
	"total_rocks_missed" : 0,
	"total_hazards": 0,
	"total_pineapples_destroyed": 0,
	
	
	"power_bonus_round_pineapples": 0,
	
	"power_auto_fire" : 0,
	"power_max_items_in_shop" : 3,
	"power_time_upgrade" : 0,
	"power_target_circle": 0,
	"power_gun_fire_rate": 0,
	"power_bullet_damage": 0,
	"power_bullet_speed": 0,
	"power_bullet_delay": 0,
	"power_gun": 0,
	"power_sky_mine" : 0,

	"power_ticket_moss": 0,
	"power_ticket_redd": 0,
}

var dataset: Dictionary = DEFAULT_DATASET.duplicate(true)

var round_finished := false

var _log: Array=[]
var _current_round_log: Array = []

func next_round() -> void:
	dataset.round += 1
	dataset.earnings = 0
	dataset.fines = 0
	dataset.total_rocks_destroyed = 0
	dataset.total_rocks_missed = 0
	dataset.total_hazards = 0
	dataset.total_pineapples_destroyed = 0
	round_finished = false
	_current_round_log.clear()

func get_all() -> Dictionary:
	return dataset

func get_cash() -> Dictionary:
	
	return {
		"cash": dataset.cash
		,"earnings": dataset.earnings
		,"fines": dataset.fines
	}
	
func add_cash(value : int) -> void:
	dataset.cash = dataset.cash + value
	dataset.earnings = dataset.earnings + value
	
func log_hit(item:String, item_type:String, value:int):
	var rock_data : Dictionary = gl_DataSet.dataset_float
	if not rock_data.has(item):
		printt('error in log hit: ', " ITEM:", item , " ITEM TYPE:", item_type )
		return
		
	dataset.cash = dataset.cash + value
	
	if value < 0:
		dataset.fines = dataset.fines + value
	else:
		dataset.earnings = dataset.earnings + value
		
	var d: Dictionary = {
		"round": dataset.round
		,"type": 'hit'
		,"item": item
		,"item_type": item_type
		,"value": value
	}
	

	_log.append(d)
	_current_round_log.append(d)
	
	if item.contains('hazard'):
		dataset.total_hazards += 1

		
	elif item.contains('pineapple'):
		dataset.total_pineapples_destroyed += 1
	
	else:
		dataset.total_rocks_destroyed += 1
		dataset.total_rocks_in_round_remaining -= 1
		check_all_rocks_cleared()
		EventBus.instance.rock_destroyed.emit()
		


func log_rocks(_total_rocks : int) -> void:
	dataset.total_rocks_in_round = _total_rocks
	dataset.total_rocks_in_round_remaining = _total_rocks
	
func log_rock_missed() -> void:
	dataset.total_rocks_missed += 1
	dataset.total_rocks_in_round_remaining -= 1
	check_all_rocks_cleared()
	


func check_all_rocks_cleared() -> void:
	#if round_finished:
		#return

	if dataset.total_rocks_in_round_remaining > 0:
		return

	round_finished = true

	if dataset.total_rocks_missed == 0:
		EventBus.instance.all_rocks_destroyed.emit()
	else:
		EventBus.instance.end_round_rock_missed.emit()


func check_score() -> void:	
	if dataset.total_rocks_in_round_remaining <= 0:
		dataset.rock_limit += 1
		return
		#if dataset.total_hazards == 0:
			#dataset.rock_limit += 1
			#print("Increase Rock Limit")
			#return
			#
	#if dataset.total_rocks_missed == 0:
		#if dataset.rocks_remaining <= 0 && dataset.total_hazards == 0:
			#dataset.rock_limit += 1
			#print("Increase Rock Limit")
			#return
			#
		#if dataset.total_rocks_destroyed >= dataset.total_rocks_in_round && dataset.total_rocks_missed == 0:
			#if dataset.total_hazards > 0:
				#print("Rock Limit Stays The Same")
			#else:
				#dataset.rock_limit += 1
				#print("Increase Rock Limit")
		#return
		
	else:
		print("rocks missed ", dataset.total_rocks_missed)
			

func log_buy(power_name:String, price:float, unit:int=1) -> bool:
	
	if not dataset.has(power_name):
		print('error in log buy')
		return false
	
	dataset[power_name] += unit
	dataset.cash = dataset.cash - price

	EventBus.instance.purchase_made.emit(power_name)
	
	var d: Dictionary = {
		"round": dataset.round
		,"type": 'buy'
		,"item": power_name
		,"item_type": 'power'
		,"price": price
	}
	
	_log.append(d)
	_current_round_log.append(d)
	return true
	
	
func purchase_ticket(location_name:String, price:int) -> bool:
	print('make this a log buy function later')
	if dataset.cash < price:
		return false

	dataset.cash -= price
	#dataset.tickets[location_name] = true

	return true
	
func owns_ticket(location_name:String) -> bool:
	return dataset.tickets.get(location_name, false)

func get_item_hits(_round:int) -> Dictionary:
	
	var d: Dictionary
	
	var ary: Array = _log.filter(func(i:Dictionary): return i.round == _round && i.type == 'hit')
	
	for item in ary:
		if d.has(item.item_type):
			d[item.item_type] = d[item.item_type] + 1
		else:
			d[item.item_type] = 1
			
	return d
	
func get_power_level(power_name:String) -> int:
	return dataset[power_name]
	
func get_demo_stats() -> Dictionary:

	var total_destroyed := 0
	var total_money_earned := 0
	var total_fines := 0

	for entry in _log:

		if entry.type == "hit":

			total_destroyed += 1

			if entry.value > 0:
				total_money_earned += entry.value
			elif entry.value < 0:
				total_fines += abs(entry.value)

	return {
		"rounds" : dataset.round,
		"cash_remaining" : dataset.cash,
		"rocks_destroyed" : total_destroyed,
		"money_earned" : total_money_earned,
		"fines" : total_fines
	}


func change_location(_new_location : String) -> bool:
	var old_location = dataset.stage_name
	_new_location = _new_location.to_lower()
	print(_new_location)
	if _new_location == dataset.stage_name:
		print('we are already here do not move')
		return false
	
	var location_names : Array = gl_DataSet.dataset_string["place_name"]
	
	if not location_names.has(_new_location):
		print('error in change location')
		return false
	
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager == null:
		print('error change location - cannot find round manager')
		return false
	
	if old_location == gl_DataSet.get_string('place_name', 5) && _new_location == gl_DataSet.get_string('place_name', 0):
		round_manager.move_to_moss()
		dataset.stage_name = _new_location
		print('moving to moss')
		return true
		
	if old_location == gl_DataSet.get_string('place_name', 0) && _new_location == gl_DataSet.get_string('place_name', 1):
		round_manager.move_to_redd()
		dataset.stage_name = _new_location
		print('moving to redd')
		return true
		
	if old_location == gl_DataSet.get_string('place_name', 1) && _new_location == gl_DataSet.get_string('place_name', 2):
		#round_manager.move_to_glory()
		round_manager.update_end_demo()
		dataset.stage_name = _new_location
		return true
	#round_manager.move_location()
	
	else:
		return false


func reset_cash_debug_tool() -> void:
	dataset.cash = 0
	
func buy_all_upgrades() -> void:
	dataset.power_target_circle = 9
	dataset.power_gun_fire_rate = 9
	dataset.power_bullet_damage = 9
	dataset.power_bullet_speed = 9
	dataset.power_bullet_delay = 9

func reset_all() -> void:
	dataset = DEFAULT_DATASET.duplicate(true)

	_log.clear()
	_current_round_log.clear()
