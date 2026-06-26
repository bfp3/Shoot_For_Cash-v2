extends Node

# Upgrade stages

var dataset_float : Dictionary = {


	#,"power_bullet_delay" 	: [0.40,0.32,0.25,0.18,0.12,0.08,0.05,0.02,0.01]
	"power_max_items_in_shop" 		: [1,2,3]
	
	,"power_bonus_round_pineapples" 	: [0, 1]
	,"power_auto_fire" 				: [0, 1]
	,"power_sky_mine" 				: [0, 1]
	
	,"power_target_circle"	: [20.0,30.0,40.0,50.0,60.0,70.0,80.0,90.0,100.0,120.0,200.0]
	,"power_gun_fire_rate"	: [1.25, 1.0, 0.9,0.8,0.65,0.50,0.35,0.20,0.15,0.10, 0.05]
	,"power_bullet_damage" 	: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
	,"power_bullet_delay" 	: [0.1,0.08,0.05,0.02,0.01]
	,"power_bullet_speed" 	: [1.0, 0.8, 0.5, 0.4, 0.2, 0.15, 0.1, 0.05,0.02, 0.01, 0.005]
	
	,"power_gun"				: [0]
	
	,'power_time_upgrade' 	: [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]	
	
	
	,"price_bonus_round_pineapples" 	: [20]
	,"price_auto_fire" 				: [135]
	,"price_target_circle"			: [0,7, 20, 40, 260, 320, 440, 550, 1000, 1500]
	,"price_gun_fire_rate"			: [0, 2, 4, 8, 32, 99, 204, 350, 550, 998]
	,"price_bullet_damage" 			: [0,4, 8, 16, 50, 101, 202, 350, 500, 680, 801]
	,"price_bullet_speed" 			: [0,2, 3, 6, 8, 12, 16, 20, 30, 40, 50]
	,"price_bullet_delay" 			: [0,2, 4, 8, 16, 32, 64, 99, 124, 300, 801]
	,"price_gun"						: [0,0,0]
	,"price_sky_mine" 				: [10]
	,"price_max_items_in_shop" 		: [2,10,30]
	,'price_time_upgrade' 			: [0, 22, 24, 26, 30, 220, 180, 160, 140, 1000]
	
	,'power_ticket_moss' 			: [0]
	,'power_ticket_redd' 			: [0]
	
	,'price_ticket_moss' 		: [100]
	,'price_ticket_redd' 		: [180]
	,'price_ticket_glory' 		: [1800]
	,'price_ticket_backwater' 	: [5000]
	,'price_ticket_sodomi' 		: [5000]
	
	
	,"price_reroll" 		: 2
	
	
	# ONE OFFS
	,"ONE_OFF" 				: [13]
	
	
	# Targets / Rocks
	# item name, 			$value, 	health
	,"rock_type_1"			: [1,		1]
	,"rock_type_2"			: [12,		9]
	,"rock_type_3"			: [20,		15]
	,"rock_type_4"			: [120,		30]
	
	,"pineapple"				: [10,		1]
	
	# Hazards
	# item name, 			$value, 	health
	,"hazard_type_1"		: [-12,		5]
	,"hazard_type_2"		: [-20,		1]
	,"hazard_type_3"		: [-100,	1]
	,"hazard_type_4"		: [-100,	1]

	,"round_moss_small"		: [12,	34, 35,	66,	45]
	,"round_moss_reds"		: [0,	3,	0,	66,	45]
	
	,"total_rocks_area_1"	: [20, 40, 60, 80, 100]
	,"total_rocks_area_2"	: [300]
	,"total_rocks_area_3"	: [1000]
	,"total_rocks_area_4"	: [1000]
	,"total_rocks_area_5"	: [10000]

	,"rock_limit_moss" 		: [10]
	,"rock_limit_redd"		: [15]
	,"rock_limit_glory"		: [20]
	,"rock_limit_blackwaters" : [25]
	,"rock_limit_sodomi" 	: [30]
	}

var dataset_string : Dictionary = {
	 "place_name" 				: ['moss','redd','end game','blackwaters', 'sodomi', 'start']
	
	
	,"tooltip_gun"						: ["You'll probably need this."]
	,"tooltip_bonus_round_pineapples" 	: ['Flying Pineapples']
	,"tooltip_auto_fire" 				: ['Just point, no click.']
	,"tooltip_sky_mine" 					: ["Rock Go BOOM"]
	,"tooltip_target_circle" 			: [""]
	,"tooltip_gun_fire_rate"				: ["Less cooldown time"]
	,"tooltip_bullet_damage" 			: ["Break Rocks Easier."]
	,"tooltip_bullet_speed" 				: ["Bullets Travel Faster."]
	,"tooltip_time_upgrade"				: ["+1 sec to the timer"]
	
	#,"tooltip_max_items_in_shop": ['Add +1 Item To The Shop Permanently']
	#,"tooltip_bullet_delay"				: ["Bullet Delay * NOT USED"]
	
	,"tooltip_ticket_moss"		: ['Ticket To Moss, Where It All Begins']
	,"tooltip_ticket_redd"		: ['Ticket To Redd, No More Of This Chump Change']
	
	,"wall_quote_start"			: ["Good Luck."]
	,"wall_quote_moss"			: ["Good Habits\nSave Lives"]
	,"wall_quote_redd"			: ["Don't Get In\nThe Way Of\nLove"]
	,"wall_quote_glory"			: ["Morning\nGlory"]
	}
	
# DATASET.get_value('bullet_speed',4)

func get_value(_name : String, _index : int = 0) -> float:
	
	if dataset_float.has(_name):
		var ary = dataset_float[_name]
		if _index >= ary.size():
			_index = ary.size() -1

		return ary[_index]
		
	return -1

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
