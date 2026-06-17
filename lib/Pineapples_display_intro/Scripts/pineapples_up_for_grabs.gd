extends Control

@onready var pineapple: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_2: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_3: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer/MarginContainer/TextureRect

@onready var pineapple_panel: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer
@onready var pineapple_panel_2: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer
@onready var pineapple_panel_3: PanelContainer = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer

signal finished_display

func _ready() -> void:
	pineapple.modulate = Color('000000')
	pineapple_2.modulate = Color('000000')
	pineapple_3.modulate = Color('000000')
	
	pineapple_panel.modulate = Color('FFFFFF00')
	pineapple_panel_2.modulate = Color('FFFFFF00')
	pineapple_panel_3.modulate = Color('FFFFFF00')
	
	self.modulate = Color('FFFFFF00')
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color('FFFFFF'), 0.25)
	tween.tween_property(pineapple_panel, "modulate", Color('FFFFFF'), 0.25)
	tween.tween_property(pineapple_panel_2, "modulate", Color('FFFFFF'), 0.25)
	tween.tween_property(pineapple_panel_3, "modulate", Color('FFFFFF'), 0.25)
	await tween.finished
	
	start_tween()
	
func start_tween() -> void:
	
	await get_tree().create_timer(0.25).timeout
	shake_pineapple(pineapple)
	await get_tree().create_timer(0.25).timeout
	shake_pineapple(pineapple_2)
	await get_tree().create_timer(0.75).timeout
	await shake_pineapple(pineapple_3)
	
	hide_pineapples()
	
func shake_pineapple(target_pineapple : TextureRect) -> void:
	change_modulate(target_pineapple)
	
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(change_modulate)
	tween.tween_property(target_pineapple, "rotation", -0.1, 0.1)
	tween.tween_property(target_pineapple, "rotation", 0.1, 0.1)
	tween.tween_property(target_pineapple, "rotation", -0.1, 0.1)
	tween.tween_property(target_pineapple, "rotation", 0.1, 0.15)
	tween.tween_property(target_pineapple, "rotation", -0.1, 0.12)
	tween.tween_property(target_pineapple, "rotation", 0.1, 0.12)
	tween.tween_property(target_pineapple, "rotation", -0.1, 0.12)
	tween.tween_property(target_pineapple, "rotation", 0.0, 0.15)
	await tween.finished

func change_modulate(target_pineapple : TextureRect) -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_property(target_pineapple, "modulate", Color('FFFFFF'), 0.25)
	await tween.finished
	
func hide_pineapples() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)

	# Fade out pineapple textures
	tween.tween_property(pineapple, "modulate", Color('FFFFFF00'), 0.25)
	tween.parallel().tween_property(pineapple_2, "modulate", Color('FFFFFF00'), 0.25)
	tween.parallel().tween_property(pineapple_3, "modulate", Color('FFFFFF00'), 0.25)

	# Fade out panels
	tween.tween_property(pineapple_panel, "modulate", Color('FFFFFF00'), 0.25)
	tween.tween_property(pineapple_panel_2, "modulate", Color('FFFFFF00'), 0.25)
	tween.tween_property(pineapple_panel_3, "modulate", Color('FFFFFF00'), 0.25)

	# Fade out whole UI
	tween.tween_property(self, "modulate", Color('FFFFFF00'), 0.25)

	await tween.finished
	finished_display.emit()
