extends Node

# Upgrade stages

var dataset_float : Dictionary = {

	"power_bonus_round_pineapples" 	: [0, 1]
	,"power_max_ammo"				: [99]
	,"ammo_pack_size"				: [99]
	,"power_ammo"					: [99]
	,"power_sky_mine" 					: [0, 1, 2]
	,"power_balloon_buster" 			: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	,"power_target_circle"	: [60.0,80.0,120.0,160.0, 200.0, 240.0,280.0,380.0,420.0,460.0]
	#,"power_target_circle"	: [40.0,60.0,80.0,90.0,100.0,120.0, 130.0, 140.0,40.0,50.0]
	#,"power_gun_fire_rate"	: [1.25, 1.0, 0.9,0.8,0.65,0.50,0.35,0.20,0.15,0.10, 0.05]
	,"power_gun_fire_rate"	: [0.35,0.20,0.15,0.10, 0.05]
	,"power_bullet_damage" 	: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
	,"power_bullet_delay" 	: [0.1,0.08,0.05,0.02,0.01]
	,"power_bullet_speed" 	: [0.3, 0.2, 0.15, 0.1, 0.05, 0.03,0.02, 0.01, 0.005, 0.001]
	,"power_gun"				: [0]

	#,'power_time_upgrade' 	: [7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]		
	,'power_time_upgrade' 	: [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]		
	
	
	,"price_max_ammo"				: [10]
	,"price_ammo"					: [100]
	,"price_target_circle"			: [700,700,700,700,700,700,700,700,700,700]
	,"price_gun_fire_rate"			: [500, 500,500,500,500,500,500,500,500,500]
	,"price_bullet_damage" 			: [400,400,400,400,400,400,400,400,400,400]
	,"price_bullet_speed" 			: [400, 400, 400,400,400,400,400,400,400,400]
	,"price_bullet_delay" 			: [2, 4, 8, 16, 32, 64, 99, 124, 300, 801]
	,"price_gun"					: [0,0,0]
	,"price_sky_mine" 				: [300,500]
	,"price_balloon_buster"			: [3, 6, 12, 56,125,400,800.1200,2400]
	,'price_time_upgrade' 			: [500,500,500,500,500,500,500,500]
	,"price_bonus_round_pineapples" : [200]
	## First continue fee by title-screen difficulty. Each successful continue doubles it.
	,"continue_fee_beginner"		: [50]
	,"continue_fee_advanced"		: [100]
	,"continue_fee_expert"			: [150]
	
	,'power_ticket_moss' 			: [0]
	
	,'power_ticket_redd' 			: [0]
	,'power_ticket_noir' 			: [0]
	,'power_ticket_vesper' 			: [0]
	
	,'price_ticket_moss' 		: [0]
	,'price_ticket_redd' 		: [20000] #180
	,'price_ticket_glory' 		: [1800]
	,'price_ticket_noir' 		: [5000]
	,'price_ticket_vesper' 		: [5000]
	,'price_ticket_backwater' 	: [5000]
	,'price_ticket_sodomi' 		: [5000]
	
	
	#,"price_reroll" 		: [0,2,4,8,16,32,64,128,256,512,1024]

	,"price_reroll" 		: [10,20,40,80,160,320,640]
	
	,"reward_perfect_round"	: [50,1000,1500]
	,"price_play_round"		: [100]
	## Map: cash required to unlock island index+1 (Shipper→Anchor, Anchor→Squid, …).
	## Edit these values to change unlock prices on the island map.
	,"island_unlock_cost"		: [2500, 3500, 30, 40]
	## Cash required to enter each island's boss fight (index = island).
	,"boss_unlock_cost"			: [2500, 3500, 30, 40]
	## Cash awarded when surviving a boss clear (index = island).
	,"boss_clear_reward"		: [600, 1000, 15000, 20000, 25000]
	## Legacy single-value alias (cost to leave the first island). Prefer island_unlock_cost.
	## Map: rounds shown as current/total on each island button.
	,"map_rounds_per_island"	: [12]
	## Cash awarded when fully clearing a shooting range (moss, redd, …).
	,"range_clear_reward"		: [1200]
	
	,"reward_all_pineapples"		: [100]
	,"reward_egg"					: [300]
	# Targets / Rocks
	# item name, 			$value, 	health
	,"pineapple"			: [10,		1]
	,"orange"				: [0,		1]
	,"balloon_orange"		: [0,		1]
	,"hazard_type_1"		: [0,		1]
	
	,"rock_type_1"			: [2,		1]
	,"rock_type_2"			: [0,		3]
	,"rock_type_3"			: [20,		15]
	,"rock_type_4"			: [120,		30]
	,"rock_type_8"			: [0,		1]
	,"rock_type_9"			: [0,		1]
	,"rock_type_avoider"	: [0,		1]
	,"rock_type_chaser"		: [0,		1]
	## Grey rock: $1, 1 health. Misses do not strike.
	,"rock_type_grey"		: [1,		1]
	## Mothership: [bonus cash, hits to destroy].
	,"mothership_reward"	: [35,		3]
	## Shop range-target cash shown when entering a place.
	,"range_target_moss"	: [1000]
	,"range_target_redd"	: [2500]
	,"range_target_glory"	: [4000]
	,"range_target_jetz"	: [6000]
	,"range_target_noir"	: [8000]
	,"range_target_vesper"	: [10000]
	# Hazards
	#,"hazard_type_1"		: [-100,	1]
	,"hazard_type_2"		: [-20,		1]
	,"hazard_type_3"		: [-10,	1]
	,"hazard_type_4"		: [-10,	1]	
	
	,"seq_rocks_moss" 		: [
		[2,2,8]
		,[4,4,8]

		]
		
	}

var dataset_string : Dictionary = {
	 "place_name" 				: ['moss','redd','glory','jetz','noir', 'vesper', 'start']
	## Overworld island display names (index 0 = starting island). Edit freely.
	,"island_names"				: [
		'Shipper Island',
		'Anchor Island',
		'Squid Island',
		'Pelican Island',
		'Island 5',
	]
	## Floating "not enough cash" text on the island map (Next / Anchor button).
	,"map_earn_more_money_text"	: ["Earn More Money"]
	## Shop challenge banner per place (parallel to place_name). Empty = hide banner.
	,"shop_challenge_text"		: [
		"ACCURACY\nfor the WIN", ## moss
		"", ## redd
		"6 Shots Only", ## glory
		"That's all for now,\nenjoy endless mode.", ## jetz
		"", ## noir (was Don't Shoot Oranges — re-enable later)
		"", ## vesper
		"", ## start
	]
	## Runtime special challenge ids per place (parallel to place_name). Empty = none.
	## Known ids: no_shoot_oranges, six_shots_only
	,"special_challenge"		: [
		"", ## moss
		"", ## redd
		"six_shots_only", ## glory
		"", ## jetz
		"", ## noir (was no_shoot_oranges — re-enable later)
		"", ## vesper
		"", ## start
	]
	## Boss shop banner. Use %d for hold-out seconds.
	,"shop_challenge_boss"		: ["HOLD OUT %d"]
	
	,"tooltip_gun"						: ["You'll Need This"]
	,"tooltip_bonus_round_pineapples" 	: ['Flying Pineapples']
	,"tooltip_sky_mine" 				: ["[wave]BOOM[/wave]"]
	,"tooltip_target_circle" 			: ["Do you even know what a Reticle is?"]
	,"tooltip_gun_fire_rate"			: ["Faster Reload"]
	,"tooltip_bullet_damage" 			: ["The Big One's Hurt"]
	,"tooltip_bullet_speed" 			: ["Just buy it"]
	,"tooltip_time_upgrade"				: ["+1 to Timer"]
	,"tooltip_balloon_buster"			: ["Pop Balloons For Free"]
	#,"tooltip_bullet_delay"			: ["Bullet Delay * NOT USED"]
	
	,"tooltip_ticket_moss"		: ['Ticket To Moss, Where It All Begins']
	,"tooltip_ticket_redd"		: ['Ticket To Redd, No More Of This Chump Change']
	
	,"wall_quote_start"			: ["Good Luck."]
	,"wall_quote_moss"			: ["Good Habits\nSave Lives"]
	,"wall_quote_redd"			: ["Don't Get In\nThe Way Of\nLove"]
	,"wall_quote_glory"			: ["Morning\nGlory"]
	,"wall_quote_jetz"			: ["Testing\nRoom"]
	}
	
# DATASET.get_value('bullet_speed',4)

func get_value(_name : String, _index : int = 0) -> float:
	
	if dataset_float.has(_name):
		var ary = dataset_float[_name]
		if _index >= ary.size():
			_index = ary.size() -1

		return ary[_index]
		
	return -1
	
func get_array(_name : String) -> Array:
	
	if dataset_float.has(_name):
		var ary = dataset_float[_name]
		return ary
		
	return []

func get_string(_name : String, _index : int=0) -> String:
	
	if dataset_string.has(_name):
		var ary = dataset_string[_name]
		if _index > ary.size():
			_index = ary.size()

		return ary[_index]
			
	return ''
	
	
func get_price(_name : String) -> int:
	
	if _name == '':
		return 0

	var power_name = 'power_' + _name
	var price_name = 'price_' + _name
	var price = get_value(price_name, gl_PlayerState.dataset[power_name])
	price = int(price)
	return price
	
	
func update_rocks(amount : int = 1) -> void:

	var stage = gl_PlayerState.dataset["stage"]
	var key = "total_rocks_area_" + str(stage)

	if dataset_float.has(key):

		dataset_float[key][0] -= amount
		dataset_float[key][0] = max(dataset_float[key][0], 0)

	else:
		push_warning("Invalid rock key: " + key)
		
func get_remaining_rocks() -> int:

	var stage = gl_PlayerState.dataset["stage"]
	var key = "total_rocks_area_" + str(stage)

	if dataset_float.has(key):
		return dataset_float[key][0]

	return 0


## --- Place / range name helpers (single source: dataset_string.place_name) ---

## Ordered list of place ids: moss, redd, glory, jetz, …
func get_place_names() -> PackedStringArray:
	var raw: Array = dataset_string.get("place_name", [])
	var out: PackedStringArray = PackedStringArray()
	for entry in raw:
		out.append(String(entry).to_lower())
	return out


func get_place_name(index: int) -> String:
	var names := get_place_names()
	if index < 0 or index >= names.size():
		return ""
	return names[index]


func get_place_index(place_id: String) -> int:
	place_id = place_id.to_lower()
	# Alias: "test" → testing room (same index as jetz / place 3).
	if place_id == "test":
		place_id = get_testing_place_name()
	var names := get_place_names()
	for i in names.size():
		if names[i] == place_id:
			return i
	return -1


func has_place(place_id: String) -> bool:
	return get_place_index(place_id) >= 0


## Normalize aliases ("test") to the canonical place_name entry.
func resolve_place_name(place_id: String) -> String:
	place_id = place_id.to_lower()
	if place_id == "test":
		return get_testing_place_name()
	var idx := get_place_index(place_id)
	if idx < 0:
		return place_id
	return get_place_name(idx)


func get_start_place_name() -> String:
	var names := get_place_names()
	for n in names:
		if n == "start":
			return n
	return "start"


## First playable range (index 0 in place_name, skipping "start" if it's first).
func get_default_range_name() -> String:
	var names := get_place_names()
	for n in names:
		if n != "start":
			return n
	return "moss"


## HUD / shop label: "moss3" → "MOSS". Trailing digits are internal range ids.
func display_place_name(place_id: String) -> String:
	var raw := resolve_place_name(place_id).strip_edges().to_upper()
	var end := raw.length()
	while end > 0:
		var code := raw.unicode_at(end - 1)
		if code < 48 or code > 57:
			break
		end -= 1
	var display := raw.substr(0, end).strip_edges()
	if display.is_empty() or display == "START":
		return get_default_range_name().to_upper()
	return display


## Testing / free-play room — conventionally place_name index 3 ("jetz").
func get_testing_place_name() -> String:
	var names := get_place_names()
	if names.size() > 3:
		var candidate := names[3]
		if candidate != "start":
			return candidate
	for n in names:
		if n == "jetz" or n == "test":
			return n
	return get_default_range_name()


func is_testing_place(place_id: String) -> bool:
	place_id = resolve_place_name(place_id)
	return place_id == get_testing_place_name() or place_id == "test"


func get_wall_quote_key(place_id: String = "") -> String:
	if place_id.is_empty():
		place_id = String(gl_PlayerState.dataset.level_name)
	place_id = resolve_place_name(place_id)
	return "wall_quote_%s" % place_id


func get_ticket_price_key(place_id: String) -> String:
	return "price_ticket_%s" % resolve_place_name(place_id)


func get_range_target_key(place_id: String) -> String:
	return "range_target_%s" % resolve_place_name(place_id)


func get_range_target(place_id: String = "") -> int:
	if place_id.is_empty():
		place_id = String(gl_PlayerState.dataset.level_name)
	var key := get_range_target_key(place_id)
	var value := int(get_value(key, 0))
	return maxi(value, 0)


func get_ticket_power_key(place_id: String) -> String:
	return "power_ticket_%s" % resolve_place_name(place_id)


## Special challenge id for a place (e.g. "no_shoot_oranges", "six_shots_only"). Empty = none.
func get_special_challenge(place_id: String = "") -> String:
	if place_id.is_empty():
		place_id = String(gl_PlayerState.dataset.level_name)
	place_id = resolve_place_name(place_id)
	var idx := get_place_index(place_id)
	if idx < 0:
		return ""
	return String(get_string("special_challenge", idx)).strip_edges()


func has_special_challenge(challenge_id: String, place_id: String = "") -> bool:
	if challenge_id.is_empty():
		return false
	return get_special_challenge(place_id) == challenge_id


## --- Overworld island map helpers ---

func get_island_names() -> PackedStringArray:
	var raw: Array = dataset_string.get("island_names", [])
	var out := PackedStringArray()
	for entry in raw:
		out.append(String(entry))
	return out


func get_island_name(index: int) -> String:
	var names := get_island_names()
	if index < 0 or index >= names.size():
		return ""
	return names[index]


func get_island_count() -> int:
	return get_island_names().size()


## Cash required to unlock the island at `to_island_index` (must be >= 1).
func get_island_unlock_cost(to_island_index: int) -> int:
	if to_island_index <= 0:
		return 0
	var costs: Array = dataset_float.get("island_unlock_cost", [])
	var cost_i := to_island_index - 1
	if costs.is_empty():
		return int(get_value("cash_needed_next_island", 0))
	if cost_i >= costs.size():
		cost_i = costs.size() - 1
	return int(costs[cost_i])


func get_map_earn_more_money_text() -> String:
	var text := get_string("map_earn_more_money_text", 0)
	if text.is_empty():
		return "Earn More Money"
	return text


func get_boss_unlock_cost(island_index: int) -> int:
	var costs: Array = dataset_float.get("boss_unlock_cost", [])
	if costs.is_empty():
		return 10000
	var i := clampi(island_index, 0, costs.size() - 1)
	return int(costs[i])


func get_boss_clear_reward(island_index: int) -> int:
	var rewards: Array = dataset_float.get("boss_clear_reward", [])
	if rewards.is_empty():
		return 5000
	var i := clampi(island_index, 0, rewards.size() - 1)
	return int(rewards[i])


## Flat clear bonus for finishing every round in a shooting range.
## Prefers `reward $N` from island-shipper.txt over dataset `range_clear_reward`.
func get_range_clear_reward(_place_id: String = "") -> int:
	var range_name := resolve_place_name(_place_id) if not _place_id.is_empty() else ""
	if range_name.is_empty() and gl_PlayerState:
		range_name = resolve_place_name(String(gl_PlayerState.dataset.get("level_name", "")))
	if Parser and Parser.has_method("get_range_reward") and not range_name.is_empty():
		var from_script := int(Parser.get_range_reward("shipper", range_name))
		if from_script > 0:
			return from_script
	return int(get_value("range_clear_reward", 0))
