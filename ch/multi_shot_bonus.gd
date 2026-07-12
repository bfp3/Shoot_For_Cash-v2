extends Node3D

@onready var multi_label: Label3D = $mutli_label

var tween: Tween = null

const MULTI_SHOT_DATA := {
	2: {"name":"DOUBLE",  "reward":10,   "color":"ff8400", "font_size":32},
	3: {"name":"TRIPLE",  "reward":30,   "color":"ff2f00", "font_size":50},
	4: {"name":"QUAD",    "reward":60,   "color":"ff00b7", "font_size":60},
	5: {"name":"5X",      "reward":100,  "color":"c400ff", "font_size":70},
	6: {"name":"6X",      "reward":150,  "color":"7b00ff", "font_size":80},
	7: {"name":"7X",      "reward":210,  "color":"006eff", "font_size":90},
	8: {"name":"8X",      "reward":280,  "color":"00d9ff", "font_size":100},
	9: {"name":"9X",      "reward":360,  "color":"00ff88", "font_size":110},
	10: {"name":"10X",    "reward":500,  "color":"ffe600", "font_size":120},
}

func multi_shot(multiplier: int) -> void:
	if !MULTI_SHOT_DATA.has(multiplier):
		return

	var data = MULTI_SHOT_DATA[multiplier]

	gl_PlayerState.add_cash(data.reward)

	multi_label.text = "%s SHOT\n%d" % [data.name, data.reward]
	multi_label.modulate = Color(data.color)
	multi_label.modulate.a = 0.0
	multi_label.outline_modulate.a = 0.0
	multi_label.font_size = data.font_size
	multi_label.show()

	$MultiShotSFX.play()

	if tween:
		tween.kill()

	tween = create_tween().set_ease(Tween.EASE_OUT)

	tween.tween_property(multi_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 1.0, 0.2)

	tween.tween_interval(1.0)

	tween.tween_property(multi_label, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(multi_label, "outline_modulate:a", 0.0, 0.2)
