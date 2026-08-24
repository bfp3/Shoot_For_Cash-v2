extends Node

var mouse_sensitivity := 1.0

## Persistent meta across title / quit (completed ranges + per-range round index).
## Written/read when persist_mode == LOAD (Load Game on Quick Start, or any exported build).
const META_SAVE_PATH := "user://shoot_for_cash_progress.cfg"
const META_SECTION := "progress"

## Dataset keys stored for mid-run resume (money, upgrades, tickets, location).
const RUN_SAVE_KEYS: Array[String] = [
	"cash",
	"level_name",
	"round",
	"total_winnings",
	"cents_total_earned",
	"tickets",
	"reroll",
	"reroll_unlocked",
	"ammo_packs_bought",
]

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
	## Highest overworld island index unlocked (0 = Shipper Island).
	"unlocked_island_index": 0,
	## Island indices whose boss fight has been cleared.
	"cleared_boss_islands": [],
	## Island indices whose boss is permanently enterable (afforded once or cleared).
	"unlocked_boss_islands": [],
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
	## Highest overworld island index unlocked (0 = Shipper Island).
	"unlocked_island_index": 0,
	## Island indices whose boss fight has been cleared.
	"cleared_boss_islands": [],
	## Island indices whose boss is permanently enterable (afforded once or cleared).
	"unlocked_boss_islands": [],
}

var dataset: Dictionary = DEFAULT_DATASET.duplicate(true)

var round_finished := false
## Unbanked round pool that has already been cashed into `dataset.cash` this round.
var cash_banked_this_round := 0
## Cash banked at the end-of-round BANK balloon so far this shooting range (HUD BankedLabel).
var cash_banked_this_range := 0
## Ladder multiplier applied when cash enters the unbanked pool. Banking resets to 2.
const DEFAULT_CASH_MULTIPLIER := 2
var cash_multiplier := DEFAULT_CASH_MULTIPLIER

var _log: Array=[]
var _current_round_log: Array = []


func _ready() -> void:
	## Exported builds always persist mid-run progress. Editor stays Test Mode by default.
	if is_export_build():
		persist_mode = PersistMode.LOAD
		_load_meta_progress_from_disk()
	else:
		persist_mode = PersistMode.TEST


## True outside the Godot editor (exported debug + release).
func is_export_build() -> bool:
	return not OS.has_feature("editor")


func is_persist_enabled() -> bool:
	return persist_mode == PersistMode.LOAD


## Fresh Test Mode session: keep any disk file, wipe runtime progress only.
func begin_test_session() -> void:
	persist_mode = PersistMode.TEST
	dataset["completed_places"] = []
	dataset["level_progress"] = {}
	dataset["unlocked_island_index"] = 0
	dataset["cleared_boss_islands"] = []
	dataset["unlocked_boss_islands"] = []


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
	dataset["unlocked_island_index"] = 0
	dataset["cleared_boss_islands"] = []
	dataset["unlocked_boss_islands"] = []
	if dataset.has("shot_count"):
		dataset.erase("shot_count")
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
	cash_banked_this_round = 0
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
	if value <= 0:
		dataset.bonus_cash = dataset.bonus_cash + value
		return
	add_to_cash_pool(value)


func add_to_cash_pool(value: int, _world_origin: Vector3 = Vector3.INF) -> void:
	if value == 0:
		return
	if value > 0:
		value *= get_cash_multiplier()
	dataset.bonus_cash = int(dataset.bonus_cash) + value
	if EventBus.instance:
		EventBus.instance.cash_pool_changed.emit(int(dataset.bonus_cash))


func get_round_cash_kept() -> int:
	return cash_banked_this_range + int(dataset.bonus_cash)


func reset_range_banked_cash() -> void:
	cash_banked_this_range = 0
	cash_banked_this_round = 0


func get_cash_multiplier() -> int:
	return maxi(cash_multiplier, 1)


func set_cash_multiplier(value: int) -> void:
	cash_multiplier = maxi(value, 1)
	if EventBus.instance and EventBus.instance.has_signal("cash_multiplier_changed"):
		EventBus.instance.cash_multiplier_changed.emit(cash_multiplier)


func increase_cash_multiplier(by: int = 1) -> void:
	set_cash_multiplier(get_cash_multiplier() + by)


func reset_cash_multiplier() -> void:
	set_cash_multiplier(DEFAULT_CASH_MULTIPLIER)


## Strikeout: subtract range-banked cash from the wallet. Multiplier is kept.
func lose_range_banked_cash() -> int:
	var amount := cash_banked_this_range
	reset_range_banked_cash()
	if amount <= 0:
		return 0
	dataset.cash = maxi(int(dataset.cash) - amount, 0)
	if EventBus.instance:
		EventBus.instance.update_money.emit()
	return amount


func bank_cash_pool(apply_to_wallet: bool = true) -> int:
	var amount := int(dataset.bonus_cash)
	dataset.bonus_cash = 0
	if amount <= 0:
		return 0
	var previous_cash := int(dataset.cash)
	cash_banked_this_round += amount
	cash_banked_this_range += amount
	if apply_to_wallet:
		add_cash(amount)
	if EventBus.instance:
		EventBus.instance.cash_pool_banked.emit(amount, previous_cash, int(dataset.cash))
	return amount


func forfeit_cash_pool() -> int:
	var amount := int(dataset.bonus_cash)
	dataset.bonus_cash = 0
	if amount <= 0:
		return 0
	if EventBus.instance:
		EventBus.instance.cash_pool_forfeited.emit(amount)
	return amount


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

	
func log_hit(item:String, item_type:String, value:int, world_origin: Vector3 = Vector3.INF):
	var rock_data : Dictionary = gl_DataSet.dataset_float
	if not rock_data.has(item):
		printt('error in log hit: ', " ITEM:", item , " ITEM TYPE:", item_type )
		return
		
	#dataset.cash = dataset.cash + value
	
	if value < 0:
		dataset.fines = dataset.fines + value
	else:
		add_to_cash_pool(value, world_origin)
		
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

	elif item.contains('mothership'):
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
	if rock_type_name.contains('mothership'):
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
	if item.contains('rock_type_juggle') or item.contains('juggle'):
		return
	if item.contains('mothership'):
		return

	dataset.total_rocks_in_round_remaining -= 1
	

	if item.contains('rock_type_1'):
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
	var max_strikes := get_max_strikes()
	if dataset.total_current_strikes >= max_strikes:
		EventBus.instance.has_hit_three_strikes.emit()
	else:
		EventBus.instance.add_strike.emit()


func set_max_strikes(value: int) -> void:
	dataset["max_strikes"] = maxi(value, 1)


func get_max_strikes() -> int:
	return maxi(int(dataset.get("max_strikes", 3)), 1)
	

func check_all_rocks_cleared() -> void:
	if dataset.total_white_rocks <= 0:
		EventBus.instance.all_white_compulsory_rocks_destroyed.emit()

	if dataset.total_rocks_in_round_remaining > 0:
		return

	var round_manager = get_tree().get_first_node_in_group('round_manager')
	if round_manager != null:
		var rocks = round_manager.get("rocks_container")
		if rocks != null and rocks.has_method("try_continue_sequence"):
			if rocks.try_continue_sequence():
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


func get_cleared_boss_islands() -> Array:
	var raw = dataset.get("cleared_boss_islands", [])
	return raw if raw is Array else []


func is_boss_cleared(island_index: int) -> bool:
	return island_index in get_cleared_boss_islands()


func mark_boss_cleared(island_index: int) -> void:
	var cleared := get_cleared_boss_islands().duplicate()
	if island_index not in cleared:
		cleared.append(island_index)
		dataset["cleared_boss_islands"] = cleared
	mark_boss_unlocked(island_index)
	save_meta_progress()


func get_unlocked_boss_islands() -> Array:
	var raw = dataset.get("unlocked_boss_islands", [])
	return raw if raw is Array else []


## Permanently enterable (cash gate passed once, or boss cleared).
func is_boss_unlocked(island_index: int) -> bool:
	return island_index in get_unlocked_boss_islands() or is_boss_cleared(island_index)


func mark_boss_unlocked(island_index: int) -> void:
	var unlocked := get_unlocked_boss_islands().duplicate()
	if island_index in unlocked:
		return
	unlocked.append(island_index)
	dataset["unlocked_boss_islands"] = unlocked
	save_meta_progress()


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


## Best endless survival time for a place (seconds). 0 = never recorded.
func get_endless_best_seconds(place_id: String = "") -> float:
	if place_id.is_empty():
		place_id = gl_DataSet.get_testing_place_name()
	var entry := get_level_progress_entry(place_id)
	return float(entry.get("endless_best_sec", 0.0))


## Records a run if it beats the stored best. Returns the new best.
func record_endless_best_seconds(seconds: float, place_id: String = "") -> float:
	if seconds <= 0.0:
		return get_endless_best_seconds(place_id)
	if place_id.is_empty():
		place_id = gl_DataSet.get_testing_place_name()
	place_id = gl_DataSet.resolve_place_name(place_id)
	var entry := get_level_progress_entry(place_id)
	var best := float(entry.get("endless_best_sec", 0.0))
	if seconds > best:
		best = seconds
		entry["endless_best_sec"] = best
		set_level_progress_entry(place_id, entry)
	return best


func save_meta_progress() -> void:
	if not is_persist_enabled():
		return
	var cfg := ConfigFile.new()
	cfg.load(META_SAVE_PATH) # ok if missing
	cfg.set_value(META_SECTION, "completed_places", get_completed_places())
	cfg.set_value(META_SECTION, "level_progress", dataset.get("level_progress", {}))
	cfg.set_value(META_SECTION, "unlocked_island_index", int(dataset.get("unlocked_island_index", 0)))
	cfg.set_value(META_SECTION, "cleared_boss_islands", get_cleared_boss_islands())
	cfg.set_value(META_SECTION, "unlocked_boss_islands", get_unlocked_boss_islands())
	_write_run_checkpoint_to_cfg(cfg)
	cfg.save(META_SAVE_PATH)


## Export-only: write a full mid-run checkpoint after a round finishes (post-tally cash bank).
func save_run_checkpoint_after_round() -> void:
	if not is_export_build():
		return
	persist_mode = PersistMode.LOAD
	_sync_shot_count_from_player()
	save_meta_progress()


func _write_run_checkpoint_to_cfg(cfg: ConfigFile) -> void:
	for key in RUN_SAVE_KEYS:
		if dataset.has(key):
			cfg.set_value(META_SECTION, key, dataset[key])
	for key in dataset.keys():
		var key_s := String(key)
		if key_s.begins_with("power_"):
			cfg.set_value(META_SECTION, key_s, dataset[key])
	## Prefer live magazine; fall back to last stored checkpoint.
	var live_ammo := _read_live_shot_count()
	if live_ammo >= 0:
		dataset["shot_count"] = live_ammo
		cfg.set_value(META_SECTION, "shot_count", live_ammo)
	elif dataset.has("shot_count"):
		cfg.set_value(META_SECTION, "shot_count", int(dataset.shot_count))


func _sync_shot_count_from_player() -> void:
	var live := _read_live_shot_count()
	if live >= 0:
		dataset["shot_count"] = live


func _read_live_shot_count() -> int:
	var tree := get_tree()
	if tree == null:
		return int(dataset.get("shot_count", -1))
	var player := tree.get_first_node_in_group("Player")
	if player != null and "shot_count" in player:
		return int(player.shot_count)
	return int(dataset.get("shot_count", -1))


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
	dataset["unlocked_island_index"] = int(cfg.get_value(META_SECTION, "unlocked_island_index", 0))
	var bosses = cfg.get_value(META_SECTION, "cleared_boss_islands", [])
	if bosses is Array:
		dataset["cleared_boss_islands"] = bosses.duplicate()
	var unlocked_bosses = cfg.get_value(META_SECTION, "unlocked_boss_islands", [])
	if unlocked_bosses is Array:
		dataset["unlocked_boss_islands"] = unlocked_bosses.duplicate()
	## Older saves: cleared bosses count as permanently unlocked.
	var merged := get_unlocked_boss_islands().duplicate()
	for i in get_cleared_boss_islands():
		var idx := int(i)
		if idx not in merged:
			merged.append(idx)
	dataset["unlocked_boss_islands"] = merged
	_load_run_checkpoint_from_cfg(cfg)


func _load_run_checkpoint_from_cfg(cfg: ConfigFile) -> void:
	for key in RUN_SAVE_KEYS:
		if not cfg.has_section_key(META_SECTION, key):
			continue
		dataset[key] = cfg.get_value(META_SECTION, key)
	## Restore any power_* keys present in the save (including tickets).
	if cfg.has_section(META_SECTION):
		for key in cfg.get_section_keys(META_SECTION):
			var key_s := String(key)
			if key_s.begins_with("power_"):
				dataset[key_s] = cfg.get_value(META_SECTION, key_s)
	if cfg.has_section_key(META_SECTION, "shot_count"):
		dataset["shot_count"] = int(cfg.get_value(META_SECTION, "shot_count", -1))


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
	reset_range_banked_cash()
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
	reset_range_banked_cash()
	if is_persist_enabled():
		load_meta_progress()
