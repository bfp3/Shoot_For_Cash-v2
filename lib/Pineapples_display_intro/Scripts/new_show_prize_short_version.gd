extends Control
#
#@onready var ring_duplicate: Control = $Ring_duplicate
#
#@onready var pineapple: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer/MarginContainer/TextureRect
#@onready var pineapple_2: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer/MarginContainer/TextureRect
#@onready var pineapple_3: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer/MarginContainer/TextureRect
#
#@onready var pineapple_panel: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer
#@onready var pineapple_panel_2: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer
#@onready var pineapple_panel_3: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer
#
#@onready var color_rect: ColorRect = $ColorRect
#@onready var text_box: Control = $Text_box
#
#@onready var smoke_sprite: AnimatedSprite2D = $Smoke_sprite
#@onready var smoke_sprite_2: AnimatedSprite2D = $Smoke_sprite2
#@onready var smoke_sprite_3: AnimatedSprite2D = $Smoke_sprite3
#
#@export var colour_bronze = Color('854505e6')
#@export var colour_silver = Color('bdbdbd99') 
#@export var colour_gold = Color('f5d50a') 
#@export var time_until_pineapples_disappear := 1.5
#
#signal finished_display
#
#@export var pineapples_for_this_round := 0
#
#@onready var pineapples := [pineapple, pineapple_2, pineapple_3]
#@onready var pineapple_panels := [pineapple_panel, pineapple_panel_2, pineapple_panel_3]
#@onready var smoke_sprites := [smoke_sprite, smoke_sprite_2, smoke_sprite_3]
#@onready var dots := [$Dots_phase/Dot, $Dots_phase/Dot2, $Dots_phase/Dot3]

#func allocate_pineapples_for_next_round() -> int:
	#var total_pineapples_up_for_grabs = $Prize_allocation.next_rounds_prize_allocation()
	#total_pineapples_up_for_grabs = clamp(total_pineapples_up_for_grabs, 0, ScoreGl.MAX_PINEAPPLES_PER_ROUND)
	#GameManager.pineapples_available_within_level = total_pineapples_up_for_grabs
	#return total_pineapples_up_for_grabs
	#
#func _ready() -> void:
	#pineapples_for_this_round = GameManager.pineapples_available_within_level
	#GameManager.pineapples_missed_this_round = 0
	#
	#for i in range(3):
		#dots[i].hide()
		#smoke_sprites[i].hide()
		#pineapples[i].modulate = Color('FFFFFF00')
		#pineapple_panels[i].modulate = Color('FFFFFF00')
	#
	#$PanelContainer.modulate = Color('FFFFFF00')
	#first_phase()
#
#func first_phase() -> void:
	#$Dots_phase.start_dots_phase()
	#second_phase()
#
#func second_phase() -> void:
	#var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property($PanelContainer, "modulate", Color('FFFFFF'), 1.0)
	#tween.parallel().tween_property($SFX/Panel_fade_in, "playing", true, 0.01)
	#third_phase()
#
#func third_phase() -> void:
	#for i in range(pineapples_for_this_round):
		#dots[i].show()
		#shake_pineapple(pineapples[i])
#
#func shake_pineapple(target_pineapple : TextureRect) -> void:	
	#var scale_control := target_pineapple.get_parent().get_parent()
	#var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
#
	#tween.tween_property($SFX/Pine_shake_1, "playing", true, 0.01).set_delay(0.25)
	#tween.tween_callback(change_modulate.bind(target_pineapple))
	#tween.tween_property(scale_control, "rotation", -0.1, 0.1)
	#tween.tween_property(scale_control, "rotation", 0.1, 0.1)
	#tween.tween_property(scale_control, "rotation", -0.1, 0.12)
	#tween.tween_property(scale_control, "rotation", 0.1, 0.15)
	#tween.tween_property(scale_control, "rotation", -0.1, 0.12)
	#tween.tween_property(scale_control, "rotation", 0.0, 0.15)
	#tween.tween_interval(time_until_pineapples_disappear)
	#await tween.finished
	#hide_pineapples()
#
#func change_modulate(target_pineapple : TextureRect) -> void:
	#var dur : float = 0.25
	#var scale_control := target_pineapple.get_parent().get_parent()
#
	#scale_control.scale = Vector2.ZERO
#
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(target_pineapple, "modulate", Color('FFFFFF'), dur)
	#tween.parallel().tween_property(scale_control, "modulate", Color('FFFFFF'), dur)
	#tween.parallel().tween_property(scale_control, "scale", Vector2.ONE,  0.5)
	#tween.tween_interval(dur)
	#await tween.finished
#
#func hide_pineapples() -> void:
	#var dur : float = 0.5
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
#
	#tween.tween_callback($Dots_phase.fade_dots_phase)
	#tween.tween_interval(0.25)
	#tween.tween_callback(smoke_particles)
#
	#for i in range(pineapples_for_this_round):
		#tween.parallel().tween_property(pineapples[i], "modulate", Color('FFFFFF00'), dur)
		#tween.parallel().tween_property(pineapples[i].get_parent().get_parent(), "scale", Vector2.ZERO, 0.25)
		#tween.parallel().tween_property(pineapple_panels[i], "modulate", Color('FFFFFF00'), dur)
#
	#tween.tween_property($PanelContainer, "modulate", Color('FFFFFF00'), 0.25)
	#tween.tween_callback(emit_finished)
	#tween.tween_interval(1.5)
	#tween.parallel().tween_property($ColorRect, "modulate", Color('00000000'), 1.5)
	#tween.tween_interval(1.0)
#
	#await tween.finished
	#await get_tree().create_timer(1.0).timeout
	#queue_free()
#
#func smoke_particles() -> void:
	#for i in range(pineapples_for_this_round):
		#smoke_sprites[i].show()
		#smoke_sprites[i].play("default")
#
	#await smoke_sprites[pineapples_for_this_round - 1].animation_finished
#
	#for i in range(pineapples_for_this_round):
		#var tween = create_tween()
		#tween.tween_property(smoke_sprites[i], "modulate", Color('FFFFFF00'), 0.25).set_ease(Tween.EASE_OUT)
#
#func emit_finished() -> void:
	#finished_display.emit()
