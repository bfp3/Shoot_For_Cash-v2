extends Node3D

@onready var multi_label: Label3D = $mutli_label

var tween: Tween = null

const MULTI_SHOT_DATA := {
	2: {"name":"DOUBLE",  "reward":10,   "color":"ff8400", "font_size":32},
	3: {"name":"TRIPLE",  "reward":20,   "color":"ff2f00", "font_size":50},
	4: {"name":"QUAD",    "reward":20,   "color":"ff00b7", "font_size":60},
	5: {"name":"5X",      "reward":0,  "color":"c400ff", "font_size":70},
	6: {"name":"6X",      "reward":0,  "color":"7b00ff", "font_size":80},
	7: {"name":"7X",      "reward":0,  "color":"006eff", "font_size":90},
	8: {"name":"8X",      "reward":0,  "color":"00d9ff", "font_size":100},
	9: {"name":"9X",      "reward":0,  "color":"00ff88", "font_size":110},
	10: {"name":"10X",    "reward":0,  "color":"ffe600", "font_size":120},
}

func multi_shot(multiplier: int, pos : Vector3) -> void:

	
	if !MULTI_SHOT_DATA.has(multiplier):
		return
	
	
	start_oranges(multiplier, pos)
		
	var data = MULTI_SHOT_DATA[multiplier]

	#gl_PlayerState.add_cash(data.reward)
	gl_PlayerState.dataset.bonus_cash += data.reward

	#multi_label.text = "%s SHOT\n%d$" % [data.name, data.reward]
	#multi_label.text = data.name
	multi_label.text = "$" + str(data.reward)
	multi_label.modulate = Color(data.color)
	multi_label.modulate.a = 0.0
	multi_label.outline_modulate.a = 0.0
	multi_label.font_size = data.font_size
	multi_label.show()
	multi_label.global_position = pos
	
	
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

func check_if_within_zone(pos : float) -> int:
	var zone_a_reward := 10
	var zone_b_reward := 20
	
	if pos > 3.3:
		return 0
	
	if pos <= 3.3 && pos > 0.65:
		return zone_a_reward
		
	if pos <= 0.65:
		return zone_b_reward

		
	else:
		return 0 

func start_oranges(multiplier : int, _pos : Vector3) -> void:
	var orange_container := get_tree().get_first_node_in_group('orange_container')
	for i in range(multiplier - 1):
		
		orange_container.launch_orange(_pos)
		await get_tree().create_timer(0.5).timeout
