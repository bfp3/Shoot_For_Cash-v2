extends Node

var mouse_sensitivity := 1.0

## Persistent meta across title / quit (completed ranges + per-range round index).
## Only written/read when persist_mode == LOAD (Load Game on Quick Start).
const META_SAVE_PATH := "user://shoot_for_cash_progress.cfg"
const META_SECTION := "progress"

enum PersistMode {
	TEST, ## Default while developing — session memory only, no disk I/O.
	LOAD, ## Load Game — read/write user:// save file.
}

## Default is Test Mode so closing the editor does not restore old clears.
var persist_mode: PersistMode = PersistMode.TEST

const RESTART_DATASET := {
	"cash": 500,
	"level_name": "moss", # overwritten in reset_level() from gl_DataSet default range
	"tickets": 1,
	"debug_add_cash": 1000,
	
	# Round is set to 1, so that we can play the game instead of going back to start menu
	"round": 1,
	"total_winnings" : 0,
	"bonus_cash": 0,
	"fines": 0,
	"reroll": 0,
	"reroll_unlocked": 0,
	"bonus_cash_this_round": 0,
	"perfect_rounds" : 0,
	"rock_limit" : 3,
	'total_current_strikes' : 0,
	"total_white_rocks" : 0,
	"total_rocks_in_round": 0,
	"total_rocks_in_round_remaining": 0,
	"total_rocks_destroyed" : 0,
	"total_hazards": 0,
	"total_pineapples_destroyed": 0,
	"total_oranges_destroyed" : 0,
	
	"power_bonus_round_pineapples": 0,
	
	"power_auto_fire" : 0,
	"power_balloon_buster" : 0,
	"power_max_items_in_shop" : 3,
	"power_time_upgrade" : 0,
	"power_target_circle": 0,
	"power_gun_fire_rate": 0,
	"power_bullet_damage": 0,
	"power_bullet_speed": 0,
	"power_bullet_delay": 0,
	"power_gun": 1,
	"power_sky_mine" : 0,
	"power_max_ammo": 0,
	"ammo_packs_bought": 0,

	"power_ticket_moss": 0,
	"power_ticket_redd": 0,
	"cents_total_earned": 0.0,
	"completed_places": [],
	"level_progress": {},
}

const DEFAULT_DATASET := {
	"cash": 500,
	"stage": 0,
	"level_name": "start",
	"tickets": 0,
	"debug_add_cash": 1000,
	"total_winnings" : 0,
	"round": 0,
	"bonus_cash": 0,
	"fines": 0,
	"reroll": 0,
	"reroll_unlocked": 0,
	"bonus_cash_this_round": 0,
	"perfect_rounds" : 0,
	"rock_limit" : 3,
	"total_current_strikes" : 0,
	"total_white_rocks" : 0,
	"total_rocks_in_round": 0,
	"total_rocks_in_round_remaining": 0,
	"total_rocks_destroyed" : 0,
	"total_hazards": 0,
	"total_pineapples_destroyed": 0,
	"total_oranges_destroyed" : 0,
	
	"power_bonus_round_pineapples": 0,
	
	"power_auto_fire" : 0,
	"power_balloon_buster" : 0,
	"power_max_items_in_shop" : 3,
	"power_time_upgrade" : 0,
	"power_target_circle": 0,
	"power_gun_fire_rate": 0,
	"power_bullet_damage": 0,
	"power_bullet_speed": 0,
	"power_bullet_delay": 0,
	"power_gun": 0,
	"power_sky_mine" : 0,
	"power_max_ammo": 0,
	"ammo_packs_bought": 0,

	"power_ticket_moss": 0,
	"power_ticket_redd": 0,
	"cents_total_earned": 0.0,
	"completed_places": [],
	"level_progress": {},
}

var dataset: Dictionary = DEFAULT_DATASET.duplicate(true)

var round_finished := false

var _log: Array=[]
var _current_round_log: Array = []


func _ready() -> void:
	# Test Mode by default — do not pull disk progress on boot.
	persist_mode = PersistMode.TEST


func is_persist_enabled() -> bool:
	return persist_mode == PersistMode.LOAD


## Fresh Test Mode session: keep any disk file, wipe runtime progress only.
func begin_test_session() -> void:
	persist_mode = PersistMode.TEST
	dataset["completed_places"] = []
	dataset["level_progress"] = {}


## Load Game: enable disk I/O and hydrate runtime from the save file.
func begin_load_game_session() -> void:
	persist_mode = PersistMode.LOAD
	dataset["completed_places"] = []
	dataset["level_progress"] = {}
	_load_meta_progress_from_disk()


func has_meta_save_file() -> bool:
	return FileAccess.file_exists(META_SAVE_PATH)


## Wipe disk save + runtime progress. Keeps current persist_mode.
func clear_meta_progress() -> void:
	dataset["completed_places"] = []
	dataset["level_progress"] = {}
	if FileAccess.file_exists(META_SAVE_PATH):
		var abs_path := ProjectSettings.globalize_path(META_SAVE_PATH)
		DirAccess.remove_absolute(abs_path)


func next_round() -> void:
	dataset.perfect_rounds = 0
	dataset.round += 1
	dataset.bonus_cash = 0
	dataset.fines = 0
	dataset.total_strikes = 0
	dataset.total_white_rocks = 0
	dataset.total_rocks_in_round = 0
	dataset.total_rocks_destroyed = 0
	dataset.total_hazards = 0
	dataset.total_pineapples_destroyed = 0
	dataset.total_rocks_in_round_remaining = 0
	dataset.bonus_cash_this_round = 0
	round_finished = false
	_current_round_log.clear()
	
func next_wave() -> void:
	dataset.total_white_rocks = 0
	dataset.total_rocks_destroyed = 0
	dataset.total_hazards = 0
	dataset.total_pineapples_destroyed = 0
	dataset.total_rocks_in_round_remaining = 0
	round_finished = false
	#_current_round_log.clear()

func get_all() -> Dictionary:
	return dataset

func get_cash() -> Dictionary:
	
	return {
		"cash": dataset.cash
		,"bonus_cash": dataset.bonus_cash
		,"fines": dataset.fines
	}
	
func add_cash(value : int) -> void:
	dataset.cash = dataset.cash + value
	if value > 0:
		add_place_cash_earned(value)

func subtract_penalties_from_cash() -> void:
	dataset.cash = dataset.cash + dataset.fines

func add_bonus(value : int) -> void:
	dataset.bonus_cash = dataset.bonus_cash + value


## Lifetime winnings while playing a place (map button display).
func add_place_cash_earned(amount: int, place_id: String = "") -> void:
	if amount <= 0:
		return
	if place_id.is_empty():
		place_id = gl_DataSet.resolve_place_name(String(dataset.get("level_name", "")))
	if place_id.is_empty() or place_id == gl_DataSet.get_start_place_name() or place_id == "start":
		return
	var entry := get_level_progress_entry(place_id)
	entry["cash_earned"] = int(entry.get("cash_earned", 0)) + amount
	set_level_progress_entry(place_id, entry)


func get_place_cash_earned(place_id: String) -> int:
	var entry := get_level_progress_entry(place_id)
	return int(entry.get("cash_earned", 0))

	
func log_hit(item:String, item_type:String, value:int):
	var rock_data : Dictionary = gl_DataSet.dataset_float
	if not rock_data.has(item):
		printt('error in log hit: ', " ITEM:", item , " ITEM TYPE:", item_type )
		return
		
	#dataset.cash = dataset.cash + value
	
	if value < 0:
		dataset.fines = dataset.fines + value
	else:
		dataset.bonus_cash = dataset.bonus_cash + value
		
	var d: Dictionary = {
		"round": dataset.round
		,"type": 'hit'
		,"item": item
		,"item_type": item_type
		,"value": value
	}
	

	_log.append(d)
	_current_round_log.append(d)
	
	if item.contains('rock_type_1'):
		dataset.total_white_rocks -= 1
		
	elif item.contains('rock_type_4'):
		EventBus.instance.rock_destroyed.emit()
		check_all_rocks_cleared()
		return
	
	elif item.contains('hazard'):
		if item_type.contains('balloon'):
			return
		#add_strike()
		return

	# Smokecans are obstacles only — do not gate round progress.
	elif item.contains('rock_type_8') or item.contains('smokecan'):
		return
		
		
	elif item.contains('pineapple'):
		dataset.total_pineapples_destroyed += 1
		return
		
	elif item.contains('orange'):
		dataset.total_oranges_destroyed += 1
		return
	
	else:
		pass
		
	dataset.total_rocks_in_round -= 1
	dataset.total_rocks_destroyed += 1
	dataset.total_rocks_in_round_remaining -= 1
	EventBus.instance.rock_destroyed.emit()
	check_all_rocks_cleared()
		

func log_white_rock() -> void:
	dataset.total_white_rocks += 1


func log_rocks(_total_rocks : int, rock_type_name : String) -> void:
	if rock_type_name.contains('hazard'):
		return
	# Smokecan — obstacle only (same as rock-black / hazard for wave clear).
	if rock_type_name.contains('rock_type_8') or rock_type_name.contains('smokecan'):
		return
	if rock_type_name.contains('rock_type_avoider') or rock_type_name.contains('avoider'):
		return
	
	dataset.total_rocks_in_round += 1
	dataset.total_rocks_in_round_remaining += 1
	
func log_rock_missed(item : String = '') -> void:
	# Hazards / smokecans are never added to total_rocks_in_round_remaining (see log_rocks).
	# If they still decrement it on splash/OOB, a batch can zero out remaining and end
	# the wave while real rocks are still in the air / waiting to launch.
	if item.contains('hazard'):
		return
	if item.contains('rock_type_8') or item.contains('smokecan'):
		return
	if item.contains('rock_type_avoider') or item.contains('avoider'):
		return

	dataset.total_rocks_in_round_remaining -= 1
	

	if item.contains('rock_type_1') or item.contains('rock_type_chaser'):
		add_strike()
		#return
		

	if dataset.total_rocks_in_round_remaining > 0:
		return
		
	

	check_all_rocks_cleared()


func add_strike() -> void:
	# `no-lives` on the active round only — never a global / permanent disable.
	var round_manager = get_tree().get_first_node_in_group('round_manager')
	if round_manager != null and round_manager.has_method('is_current_round_no_lives'):
		if round_manager.is_current_round_no_lives():
			return

	dataset.total_current_strikes += 1
	if dataset.total_current_strikes >= 3:
		EventBus.instance.has_hit_three_strikes.emit()

	else:
		EventBus.instance.add_strike.emit()
	

func check_all_rocks_cleared() -> void:
	if dataset.total_white_rocks <= 0:
		EventBus.instance.all_white_compulsory_rocks_destroyed.emit()

	if dataset.total_rocks_in_round_remaining > 0:
		return

	round_finished = true

	if dataset.total_white_rocks <= 0:
		EventBus.instance.all_rocks_destroyed.emit()
		dataset.perfect_rounds += 1
	else:
		EventBus.instance.rocks_cleared_end_wave.emit()


func update_total_winnings(grand_total : int) -> void:
	dataset.total_winnings += grand_total


func get_cents_total_earned() -> float:
	return float(dataset.get("cents_total_earned", 0.0))


func add_cents_total_earned(amount: float) -> void:
	if amount <= 0.0:
		return
	dataset["cents_total_earned"] = get_cents_total_earned() + amount


func get_completed_places() -> Array:
	var places = dataset.get("completed_places", [])
	return places if places is Array else []


func is_place_completed(place_id: String) -> bool:
	place_id = gl_DataSet.resolve_place_name(place_id)
	for p in get_completed_places():
		if gl_DataSet.resolve_place_name(String(p)) == place_id:
			return true
	return false


func mark_place_completed(place_id: String) -> void:
	place_id = gl_DataSet.resolve_place_name(place_id)
	if place_id.is_empty() or place_id == gl_DataSet.get_start_place_name():
		return
	if is_place_completed(place_id):
		save_meta_progress()
		return
	var places := get_completed_places().duplicate()
	places.append(place_id)
	dataset["completed_places"] = places
	save_meta_progress()


func set_level_progress_entry(place_id: String, entry: Dictionary) -> void:
	place_id = gl_DataSet.resolve_place_name(place_id)
	if place_id.is_empty() or place_id == gl_DataSet.get_start_place_name() or place_id == "start":
		return
	var stored: Dictionary = {}
	var raw = dataset.get("level_progress", {})
	if raw is Dictionary:
		stored = (raw as Dictionary).duplicate(true)
	stored[place_id] = entry.duplicate(true)
	dataset["level_progress"] = stored
	save_meta_progress()


func get_level_progress_entry(place_id: String) -> Dictionary:
	place_id = gl_DataSet.resolve_place_name(place_id)
	var stored = dataset.get("level_progress", {})
	if stored is Dictionary:
		var entry = stored.get(place_id, {})
		return entry if entry is Dictionary else {}
	return {}


func save_meta_progress() -> void:
	if not is_persist_enabled():
		return
	var cfg := ConfigFile.new()
	cfg.load(META_SAVE_PATH) # ok if missing
	cfg.set_value(META_SECTION, "completed_places", get_completed_places())
	cfg.set_value(META_SECTION, "level_progress", dataset.get("level_progress", {}))
	cfg.save(META_SAVE_PATH)


func load_meta_progress() -> void:
	if not is_persist_enabled():
		return
	_load_meta_progress_from_disk()


func _load_meta_progress_from_disk() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(META_SAVE_PATH) != OK:
		return
	var places = cfg.get_value(META_SECTION, "completed_places", [])
	if places is Array:
		dataset["completed_places"] = places.duplicate()
	var progress = cfg.get_value(META_SECTION, "level_progress", {})
	if progress is Dictionary:
		dataset["level_progress"] = (progress as Dictionary).duplicate(true)


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
	if dataset.has(power_name):
		return dataset[power_name]
		
	else:
		return -1
	
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
	_new_location = gl_DataSet.resolve_place_name(_new_location)
	if _new_location == gl_DataSet.resolve_place_name(String(dataset.level_name)):
		print('we are already here do not move')
		return false

	if not gl_DataSet.has_place(_new_location):
		print('error in change location')
		return false
	if _new_location == gl_DataSet.get_start_place_name() or _new_location == 'start':
		print('error in change location - cannot travel to start')
		return false

	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager == null:
		print('error change location - cannot find round manager')
		return false

	if not round_manager.has_method('travel_to_level'):
		print('error change location - round manager missing travel_to_level')
		return false

	# travel_to_level owns dataset.level_name updates after the fade begins.
	round_manager.travel_to_level(_new_location)
	return true


func reset_cash_debug_tool() -> void:
	dataset.cash = 0
	
func buy_all_upgrades() -> void:
	dataset.power_target_circle = 9
	dataset.power_gun_fire_rate = 9
	dataset.power_bullet_damage = 9
	dataset.power_bullet_speed = 9
	dataset.power_bullet_delay = 9

func reset_all() -> void:
	# Keep range completion / round progress across title returns (session memory).
	var kept_places = get_completed_places().duplicate()
	var kept_progress = dataset.get("level_progress", {})
	if kept_progress is Dictionary:
		kept_progress = (kept_progress as Dictionary).duplicate(true)
	else:
		kept_progress = {}

	dataset = DEFAULT_DATASET.duplicate(true)
	dataset["completed_places"] = kept_places
	dataset["level_progress"] = kept_progress

	_log.clear()
	_current_round_log.clear()
	# Only overlay disk when Load Game is active.
	if is_persist_enabled():
		load_meta_progress()


func reset_level() -> void:
	var kept_places = get_completed_places().duplicate()
	var kept_progress = dataset.get("level_progress", {})
	if kept_progress is Dictionary:
		kept_progress = (kept_progress as Dictionary).duplicate(true)
	else:
		kept_progress = {}

	dataset = RESTART_DATASET.duplicate(true)
	dataset.level_name = gl_DataSet.get_default_range_name()
	dataset["completed_places"] = kept_places
	dataset["level_progress"] = kept_progress
	_log.clear()
	_current_round_log.clear()
	if is_persist_enabled():
		load_meta_progress()
