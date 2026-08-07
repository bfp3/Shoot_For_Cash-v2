extends Control
#const WATCHTOWER_RADAR_RING = preload("res://700_2D_nodes_UI/Decal_placeholders/Watchtower_radar_ring.png")
#
#@onready var dot_reveal_probability: Node = $"../DotRevealProbability"
#
#@onready var white: Control = $Dot_control
#@onready var dots_presentation: Control = $"../Dots_presentation/PanelContainer/MarginContainer/HBoxContainer"
#
#@export var col_red := Color('c93636')  # red tone
#@export var col_orange := Color('bd4520')  # orange tone
#@export var col_grey := Color(0.5, 0.5, 0.5)
#@export var col_black := Color(0.15, 0.15, 0.15)
#
#func generate_dots_from_batch(batch: Array) -> void:
	#clear_existing_dots()
	#
	#for i in batch.size():
		#var shot_type = batch[i]["type"]
		#var new_dot := white.duplicate()
		#
		#var show_true_color = dot_reveal_probability.should_reveal_true_color(i)
		#new_dot.modulate = get_color_for_shot(shot_type) if show_true_color else col_black
#
		#if new_dot.modulate == Color(0.15, 0.15, 0.15):
			#new_dot.get_child(0).get_child(1).show()
			##new_dot.pivot_offset = new_dot.size / 2
			#new_dot.get_child(0).scale /= 2
			#new_dot.get_child(0).color_black = true
			#new_dot.get_child(0).texture = WATCHTOWER_RADAR_RING
			##new_dot.get_child(0).position.y = 0
		##print('pos ', new_dot.get_child(0).position)
		##new_dot.get_child(0).position.y = 0
		#new_dot.modulate.a = 0
		#new_dot.visible = true
		#dots_presentation.add_child(new_dot)
		#fade_in_animation(new_dot)
		#await get_tree().create_timer(0.5).timeout
#
	##
	##for shot_type in batch:
		##var new_dot := white.duplicate()
		##new_dot.modulate = get_color_for_shot(shot_type)
		##new_dot.visible = true
		##new_dot.modulate.a = 0
		##dots_presentation.add_child(new_dot)
		##fade_in_animation(new_dot)
		##await get_tree().create_timer(0.5).timeout
#
#func get_color_for_shot(shot: String) -> Color:
	#match shot:
		#"RED":
			#return col_red
		#"ORANGE":
			#return col_orange
		#"GREY":
			#return col_grey
		#_:
			#return col_black  # fallback for unknown types
#
#func fade_in_animation(shot : Control) -> void:
#
	##if col_black:
		##scale = scale / 3
	#
	#var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(shot, "modulate:a", 255, 5.0)
#
#func clear_existing_dots():
	#var fade_node = $"../Dots_presentation"
	#var children = dots_presentation.get_children()
	#if children.size() == 0:
		#return
	##children.reverse()
	##for child in children:
		##var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		##tween.tween_property(child, "modulate:a", 0, 0.15)
		###tween.parallel().tween_property(child, "scale", Vector2.ONE / 6, 0.15)
		##await tween.finished
		##if child != null:
			##child.queue_free()
	##var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	##tween.tween_property(fade_node, "modulate", Color('ffffff00'), 1.0)
	##await tween.finished
	#
	#for child in children:
		#if child != null:
			#child.get_child(0).fade_away()
			##child.queue_free()
			#
	#await get_tree().create_timer(1.1).timeout
	#if dots_presentation.get_children().size() > 0:
		#for i in dots_presentation.get_children():
			#i.queue_free()
	##fade_node.modulate = Color('ffffff')
	#
		#
