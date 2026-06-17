extends Node
class_name HealthManager

@onready var health_panel := get_tree().get_first_node_in_group('hostage_health_bar_manager')
@onready var ammo_panel := get_tree().get_first_node_in_group('Ammo_management_system')
@onready var HUD_lines := get_tree().get_first_node_in_group('HUD_Lines')
@onready var HUD_lamp := get_tree().get_first_node_in_group('HUD_lamp')
@onready var HUD_lamp_mini := get_tree().get_first_node_in_group('HUD_lamp_mini')
@onready var radar_panel := get_tree().get_first_node_in_group('radar_subviewport')
@onready var egg_cage := get_tree().get_first_node_in_group('Egg_Cage')
@onready var CRT := get_tree().get_first_node_in_group('TV_CRT_Filter')
#@onready var CMS := get_tree().get_first_node_in_group('CMS')
@onready var game_loop_manager := get_tree().get_first_node_in_group('game_loop_manager')
@onready var HUD_feedback : HUD_feedback_corner = get_tree().get_first_node_in_group('HUD_feedback_corner')

@onready var egg_low_health: AudioStreamPlayer = $Node/Egg_low_health

@export var total_health_points := 5
var damage_counter := 0

func flash_damage() -> void:
	$Damage_rect.show()
	await get_tree().create_timer(0.1).timeout
	$Damage_rect.hide()
	

func egg_took_damage() -> void:
	total_health_points = clamp(total_health_points - 1, 0, total_health_points)
	damage_counter = clamp(damage_counter + 1, 0, 99)
	update_visual()
	flash_damage()
	
	
	if total_health_points <= 2:
		if egg_low_health.playing:
			return
		else:
			egg_low_health.play()
			$Node/Egg_low_health2.play()
			health_panel.play_low_health_anim()
			
			$Damage_rect.show()
			$Damage_rect/AnimationPlayer.play('low_health')
	
func update_damage_counters() -> void:
	
	if health_panel:
		health_panel.start_health_calc_phase()
		
	if egg_cage:
		egg_cage.reduce_health_star()
		
	check_if_game_over()
		
func check_if_game_over() -> void:
	if total_health_points <= 0:
		EventBus.instance.game_lost.emit()
		#CMS._on_player_lost()
		game_loop_manager.game_lost()
		HUD_feedback.game_lost()
		health_panel.create_tween().tween_property(health_panel.get_parent().get_parent(), 'modulate', Color.TRANSPARENT, 0.5)
		radar_panel.create_tween().tween_property(radar_panel, 'modulate', Color.TRANSPARENT, 0.85)
		ammo_panel.create_tween().tween_property(ammo_panel, 'modulate', Color.TRANSPARENT, 0.75)
		HUD_lamp.create_tween().tween_property(HUD_lamp, 'modulate', Color.TRANSPARENT, 0.5)
		HUD_lamp_mini.create_tween().tween_property(HUD_lamp_mini, 'modulate', Color.TRANSPARENT, 0.25)
		HUD_lines.create_tween().tween_property(HUD_lines, 'modulate', Color.TRANSPARENT, 1.25)

func player_died() -> void:
	EventBus.instance.game_lost.emit()
	#CMS._on_player_lost()
	game_loop_manager.game_lost()
	HUD_feedback.game_lost()
	health_panel.create_tween().tween_property(health_panel.get_parent().get_parent(), 'modulate', Color.TRANSPARENT, 0.5)
	radar_panel.create_tween().tween_property(radar_panel, 'modulate', Color.TRANSPARENT, 0.85)
	ammo_panel.create_tween().tween_property(ammo_panel, 'modulate', Color.TRANSPARENT, 0.75)
	HUD_lamp.create_tween().tween_property(HUD_lamp, 'modulate', Color.TRANSPARENT, 0.5)
	HUD_lamp_mini.create_tween().tween_property(HUD_lamp_mini, 'modulate', Color.TRANSPARENT, 0.25)
	HUD_lines.create_tween().tween_property(HUD_lines, 'modulate', Color.TRANSPARENT, 1.25)

func update_visual() -> void:
	#if total_health_points <= 2:
	if CRT is CRT_TV_Filter:
		#CRT.crt_tween_warp_amount(damage_counter, 1.5)
		CRT.crt_vignette_intensity(damage_counter / 9.0, 0.1)
