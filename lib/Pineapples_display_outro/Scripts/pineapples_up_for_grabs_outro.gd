extends Control

@onready var ring_duplicate: Control = $Ring_duplicate

@onready var pineapple: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_2: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_3: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer/MarginContainer/TextureRect

@onready var pineapple_panel: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer
@onready var pineapple_panel_2: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer
@onready var pineapple_panel_3: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer
@onready var color_rect: ColorRect = $ColorRect
@onready var text_box: Control = $Text_box

@export var colour_bronze = Color('854505e6')
@export var colour_silver = Color('bdbdbd99') 
@export var colour_gold = Color('f5d50a') 

signal finished_display


func _ready() -> void:

	pineapple.modulate = Color('000000')
	pineapple_2.modulate = Color('000000')
	pineapple_3.modulate = Color('000000')
	
	pineapple_panel.modulate = Color('FFFFFF00')
	pineapple_panel_2.modulate = Color('FFFFFF00')
	pineapple_panel_3.modulate = Color('FFFFFF00')
	
	#self.modulate = Color('FFFFFF00')
	$PanelContainer.modulate = Color('FFFFFF00')
	
	#$Dots_phase2.first_phase()
	
func start() -> void:
	$Dots_phase2.first_phase()

func first_phase() -> void:
	$Dots_phase.start_dots_phase()
	await get_tree().create_timer(1.0).timeout
	second_phase()
	
func second_phase() -> void:
	
	var tween = create_tween().set_ease(Tween.EASE_IN)
	
	tween.tween_property($PanelContainer, "modulate", Color('FFFFFF'), 0.25)
	tween.parallel().tween_property($SFX/Panel_fade_in, "playing", true, 0.01)
	
	tween.tween_interval(1.0)
	
	await tween.finished

	
	third_phase()
	
func third_phase() -> void:
	await get_tree().create_timer(0.25).timeout
	shake_pineapple(pineapple)
	await get_tree().create_timer(0.5).timeout
	create_rings_during_shake(pineapple, 1, colour_bronze, 0.25)
	await get_tree().create_timer(0.25).timeout
	shake_pineapple(pineapple_2)
	await get_tree().create_timer(0.5).timeout
	create_rings_during_shake(pineapple_2, 1, colour_silver, 0.5)
	await get_tree().create_timer(0.35).timeout
	shake_pineapple(pineapple_3)
	await get_tree().create_timer(0.5).timeout
	create_rings_during_shake(pineapple_3, 1, colour_gold, 1.0)
	
	await get_tree().create_timer(1.0).timeout
	
	hide_pineapples()

func create_rings_during_shake(pineapple_target : Control, amount_of_rings : int, start_colour : Color, dur : float) -> void:
	for i in range(amount_of_rings):
		var ring = ring_duplicate.duplicate()
		add_child(ring)
		ring.show()
		ring.scale = Vector2.ONE * 3
		ring.modulate = start_colour
		ring.pivot_offset = ring.size / 2
		ring.global_position = pineapple_target.global_position
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ring, "modulate", Color('FFFFFF00'), dur)
		tween.parallel().tween_property(ring, "scale", Vector2.ONE * 6, dur)
		tween.tween_callback(ring.queue_free)
		await tween.finished


func shake_pineapple(target_pineapple : TextureRect) -> void:
	change_modulate(target_pineapple)
	
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property($SFX/Pine_shake_1, "playing", true, 0.01).set_delay(0.25)
	tween.tween_callback(change_modulate)
	tween.tween_property(target_pineapple, "rotation", -0.05, 0.1)
	tween.tween_property(target_pineapple, "rotation", 0.05, 0.1)
	tween.tween_property(target_pineapple, "rotation", -0.05, 0.1)
	tween.tween_property(target_pineapple, "rotation", 0.05, 0.15)
	tween.tween_property(target_pineapple, "rotation", -0.05, 0.12)
	tween.tween_property(target_pineapple, "rotation", 0.05, 0.12)
	tween.tween_property(target_pineapple, "rotation", -0.05, 0.12)
	tween.tween_property(target_pineapple, "rotation", 0.0, 0.15)
	await tween.finished

func change_modulate(target_pineapple : TextureRect) -> void:
	var dur : float = 0.25
	
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_interval(dur)
	tween.tween_property(target_pineapple, "modulate", Color('FFFFFF'), dur)
	tween.parallel().tween_property(target_pineapple.get_parent().get_parent(), "modulate", Color('FFFFFF'), dur)
	tween.tween_interval(dur)
	tween.tween_property(target_pineapple, "modulate", Color('FFFFFF00'), dur)
	tween.parallel().tween_property(target_pineapple.get_parent().get_parent(), "modulate", Color('FFFFFF00'), dur)
	await tween.finished
	
func hide_pineapples() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	
	tween.tween_interval(0.5)
	
	tween.tween_property(pineapple, "modulate", Color('FFFFFF00'), 0.25)
	tween.parallel().tween_property(pineapple_2, "modulate", Color('FFFFFF00'), 0.25)
	tween.parallel().tween_property(pineapple_3, "modulate", Color('FFFFFF00'), 0.25)

	tween.tween_property(pineapple_panel, "modulate", Color('FFFFFF00'), 0.25)
	tween.tween_property(pineapple_panel_2, "modulate", Color('FFFFFF00'), 0.25)
	tween.tween_property(pineapple_panel_3, "modulate", Color('FFFFFF00'), 0.25)
	
	tween.tween_callback($Dots_phase.fade_dots_phase)
	tween.tween_callback(smoke_particles)
	
	
	# Fade out whole UI
	tween.tween_property($PanelContainer, "modulate", Color('FFFFFF00'), 0.25)
	
	tween.parallel().tween_property($SFX/Panel_fade_in, "playing", true, 0.01)
	
	tween.tween_interval(1.5)
	
	tween.tween_callback(text_box.display_text)
	tween.tween_interval(1.0)
	tween.tween_callback(emit_finished) #.set_delay(1.5)
	
	tween.tween_interval(1.5)
	tween.parallel().tween_property($ColorRect, "modulate", Color('00000000'), 1.5)
	
	
	tween.tween_interval(1.0)
	await tween.finished
	
	await get_tree().create_timer(10.0).timeout
	self.queue_free()
	
	
func smoke_particles() -> void:
	var array_of_smoke : Array= [$Smoke_sprite, $Smoke_sprite2, $Smoke_sprite3]
	
	$Smoke_sprite.show()
	$Smoke_sprite2.show()
	$Smoke_sprite3.show()
	
	$Smoke_sprite.play("default")
	$Smoke_sprite2.play("default")
	$Smoke_sprite3.play("default")
	
	await $Smoke_sprite3.animation_finished
	
	for i in array_of_smoke:
		var tween = create_tween()
		tween.tween_property(i, "modulate", Color('FFFFFF00'), 0.25).set_ease(Tween.EASE_OUT)
		
func emit_finished() -> void:
	finished_display.emit()
