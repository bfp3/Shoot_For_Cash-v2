extends TextureRect
@onready var rock_large: TextureRect 	= $RockLarge 	# 0.2 scale
@onready var rock_small: TextureRect 	= $RockSmall 	# 0.121 scale
@onready var rock_small_2: TextureRect 	= $RockSmall2 	# 0.074 scale
 

#func _ready() -> void:
	#
	#rock_scale_tween(rock_large)
	#rock_scale_tween(rock_small, 0.121, 0.1)
	#rock_scale_tween(rock_small_2, 0.074, 0.06)
	#rock_rotation_tween(rock_large)
	#rock_rotation_tween(rock_small)
	#rock_rotation_tween(rock_small_2)

func rock_scale_tween(_rock_node : TextureRect, start_scale : float = 0.2, end_scale : float = 0.18) -> void:
	var dur := randf_range(1.5, 1.7)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_rock_node, "scale", Vector2.ONE * start_scale, dur)
	tween.tween_property(_rock_node, "scale", Vector2.ONE * end_scale, 1.5)
	await tween.finished
	rock_scale_tween(_rock_node, start_scale, end_scale)
 
func rock_rotation_tween(_rock_node = TextureRect) -> void:
	var dur := randf_range(1.0, 1.2)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_rock_node, "rotation", -0.25, dur)
	tween.tween_property(_rock_node, "rotation", 0.25, dur)
	await tween.finished
	rock_rotation_tween(_rock_node)
