extends Node

@onready var health_panel := get_tree().get_first_node_in_group('hostage_health_bar_manager')
@onready var ammo_panel := get_tree().get_first_node_in_group('Ammo_management_system')
@onready var HUD_lines := get_tree().get_first_node_in_group('HUD_Lines')
@onready var HUD_lamp := get_tree().get_first_node_in_group('HUD_lamp')
@onready var HUD_lamp_mini := get_tree().get_first_node_in_group('HUD_lamp_mini')
@onready var radar_panel := get_tree().get_first_node_in_group('radar_subviewport')
@onready var egg_cage := get_tree().get_first_node_in_group('Egg_Cage')
@onready var CRT := get_tree().get_first_node_in_group('TV_CRT_Filter')

func check_if_game_over() -> void:
	if !health_panel:
		return
	health_panel.create_tween().tween_property(health_panel.get_parent().get_parent(), 'modulate', Color.TRANSPARENT, 0.5)
	radar_panel.create_tween().tween_property(radar_panel, 'modulate', Color.TRANSPARENT, 0.85)
	ammo_panel.create_tween().tween_property(ammo_panel, 'modulate', Color.TRANSPARENT, 0.75)
	HUD_lamp.create_tween().tween_property(HUD_lamp, 'modulate', Color.TRANSPARENT, 0.5)
	HUD_lamp_mini.create_tween().tween_property(HUD_lamp_mini, 'modulate', Color.TRANSPARENT, 0.25)
	HUD_lines.create_tween().tween_property(HUD_lines, 'modulate', Color.TRANSPARENT, 1.25)
