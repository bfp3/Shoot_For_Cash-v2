extends Node3D

@onready var multi_label: Label3D = $mutli_label


var bonus_cash_labels_zone_a = null
var bonus_cash_labels_zone_b = null

var tween: Tween = null

const MULTI_SHOT_DATA := {
	2: {"name":"DOUBLE",  "reward":0,   "color":"ff8400", "font_size":32},
	3: {"name":"TRIPLE",  "reward":0,   "color":"ff2f00", "font_size":50},
	4: {"name":"QUAD",    "reward":0,   "color":"ff00b7", "font_size":60},
	5: {"name":"5X",      "reward":0,  "color":"c400ff", "font_size":70},
	6: {"name":"6X",      "reward":0,  "color":"7b00ff", "font_size":80},
	7: {"name":"7X",      "reward":0,  "color":"006eff", "font_size":90},
	8: {"name":"8X",      "reward":0,  "color":"00d9ff", "font_size":100},
	9: {"name":"9X",      "reward":0,  "color":"00ff88", "font_size":110},
	10: {"name":"10X",    "reward":0,  "color":"ffe600", "font_size":120},
}

## Shrunken-scope hit callouts (no immediate repeat).
var SHRINK_CALLOUTS: PackedStringArray = PackedStringArray([
	"360 NO SCOPE",
	"SNIPED!",
	"WOW",
	"IMPRESSIVE",
	"CLEAN!",
])
## Expanded-scope hit callouts (no immediate repeat).
var EXPAND_CALLOUTS: PackedStringArray = PackedStringArray([
	"ZOOMING!",
	"BIG SHOT",
	"DAYUM!",
	"WIDE OPEN!",
])

var _shrink_callout_bag: Array[String] = []
var _expand_callout_bag: Array[String] = []
var _last_shrink_callout := ""
var _last_expand_callout := ""




func multi_shot(multiplier: int, pos : Vector3) -> void:

	
	if !MULTI_SHOT_DATA.has(multiplier):
		return
	
	
	#start_oranges(multiplier, pos)
	#start_oranges(2, pos)
		
	var data = MULTI_SHOT_DATA[multiplier]

	#gl_PlayerState.add_cash(data.reward)
	gl_PlayerState.add_to_cash_pool(data.reward, pos)

	#multi_label.text = "%s SHOT\n%d$" % [data.name, data.reward]
	#multi_label.text = data.name
	#multi_label.text = "$" + str(data.reward)
	multi_label.text = str(data.name)
	multi_label.modulate = Color(data.color)
	multi_label.modulate.a = 0.0
	multi_label.outline_modulate.a = 0.0
	multi_label.font_size = data.font_size
	multi_label.show()
	multi_label.global_position.x = pos.x
	multi_label.global_position.y = pos.y
	
	if gl_PlayerState.dataset.total_hazards > 0:
		return
	
	$MultiShotSFX.play()

	if tween:
		tween.kill()

	tween = create_tween().set_ease(Tween.EASE_OUT)

	tween.tween_property(multi_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 1.0, 0.2)

	tween.tween_interval(1.5)

	tween.tween_property(multi_label, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 0.0, 0.2)


## Orbit-around-rock bonus: pop "360!" above the rock (same Label3D / SFX as multi-shot).
func show_360(pos: Vector3) -> void:
	_play_named_banner("360!", pos, Color("ffe600"), 72)


## Hit while the scope is shrunk (right-click / no-scope mechanic).
func show_shrink_scope_callout(pos: Vector3) -> void:
	var text := _next_callout(SHRINK_CALLOUTS, _shrink_callout_bag, _last_shrink_callout)
	_last_shrink_callout = text
	_play_named_banner(text, pos, Color("7bffd8"), 38)


## Hit while the scope is expanded (held shootWeapon).
func show_expand_scope_callout(pos: Vector3) -> void:
	var text := _next_callout(EXPAND_CALLOUTS, _expand_callout_bag, _last_expand_callout)
	_last_expand_callout = text
	_play_named_banner(text, pos, Color("ff8400"), 32)


## Shuffle through `pool` without repeating the previous line back-to-back.
func _next_callout(pool: PackedStringArray, bag: Array[String], last: String) -> String:
	if pool.is_empty():
		return ""
	if bag.is_empty():
		for line in pool:
			bag.append(String(line))
		bag.shuffle()
		## Avoid starting a fresh bag on the same line we just showed.
		if bag.size() > 1 and bag[0] == last:
			var first: String = bag.pop_front()
			bag.append(first)
	var pick: String = bag.pop_front()
	return pick


func _play_named_banner(text: String, pos: Vector3, color: Color, font_size: int) -> void:
	if text.is_empty():
		return
	multi_label.text = text
	multi_label.modulate = color
	multi_label.modulate.a = 0.0
	multi_label.outline_modulate.a = 0.0
	multi_label.font_size = font_size
	multi_label.show()
	multi_label.global_position.x = pos.x
	multi_label.global_position.y = pos.y

	if gl_PlayerState.dataset.total_hazards > 0:
		return

	$MultiShotSFX.play()

	if tween:
		tween.kill()

	tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(multi_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 1.0, 0.15)
	tween.tween_interval(0.85)
	tween.tween_property(multi_label, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 0.0, 0.2)

func check_if_within_zone(pos : float) -> int:
	return -1
	#var zone_a_reward := 10
	#var zone_b_reward := 20
	#
	#bonus_cash_labels_zone_a = get_tree().get_first_node_in_group('zone_a')
	#bonus_cash_labels_zone_b = get_tree().get_first_node_in_group('zone_b')
	#
	#if pos > 3.3:
		#return 0
	#
	#if pos <= 3.3 && pos > 0.65:
		#bonus_cash_labels_zone_a.start()
		#return zone_a_reward
		#
	#if pos <= 0.65:
		#bonus_cash_labels_zone_b.start()
		#return zone_b_reward
#
		#
	#else:
		#return 0 

func start_oranges(multiplier : int, _pos : Vector3) -> void:
	var orange_container := get_tree().get_first_node_in_group('orange_container')
	orange_container.launch_orange(_pos)
	#for i in range(multiplier - 1):
		#
		#orange_container.launch_orange(_pos)
		#await get_tree().create_timer(0.5).timeout
