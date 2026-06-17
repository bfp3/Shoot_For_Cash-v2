extends Control

const RADAR_TELEGRAPHER = preload("res://lib/Radar_Telegraph_System/Radar_telegrapher_system.tscn")
const HUD_ON_CLICK = preload("res://sfx/HUD on click.wav")
const HUD_ON_V2 = preload("res://sfx/HUD on_v2.wav")
const LOW_HUMMING_SFX_SCENE = preload("res://lib/Game Loop Manager_v2/low_humming_sfx_scene.tscn")
const LOW_PITCH_HUMMING = preload("res://sfx/low_pitch_humming.wav")

var radar_telegrapher := false

signal phase_complete


func start_phase() -> void:
	blink_HUD_light()
	change_hud_line_colour()
	switch_hud_crt()
	play_sound()
	await get_tree().create_timer(0.5).timeout
	#radar_telegrapher_start()
	phase_completed()


func radar_telegrapher_start() -> void:
	#await get_tree().create_timer(0.13).timeout
	var new_radar_telegrapher = RADAR_TELEGRAPHER.instantiate()
	add_child(new_radar_telegrapher)
	new_radar_telegrapher.create_new_batch_only()
	#if radar_telegrapher:
		#new_radar_telegrapher.start_process()
	#else:
		#new_radar_telegrapher.create_new_batch_only()

func radar_telegrapher_complete() -> void:
	phase_completed()

func change_hud_line_colour() -> void:
	var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
	if crt:
		crt.crt_vignette_intensity(0.25, 0.5)
	return

func play_sound() -> void:
	
	var existing_soundscape = get_tree().get_first_node_in_group("soundscape")
	if existing_soundscape:
		existing_soundscape.lower_sound_HUD_ON()
		
	CommonCode.play_sound_instance(HUD_ON_CLICK, -49.0)
		
	await get_tree().create_timer(0.13).timeout
	
	CommonCode.play_sound_instance(HUD_ON_V2, -20.0)
	
	await get_tree().create_timer(0.05).timeout
	
	var low_hum = get_tree().get_first_node_in_group('Temporary_low_humming')
	if low_hum == null:
		var low_hum_instance = LOW_HUMMING_SFX_SCENE.instantiate()
		get_tree().get_current_scene().add_child(low_hum_instance)
		low_hum_instance.add_to_group("Temporary_low_humming")
	
	else:
		low_hum.play_sound()

func blink_HUD_light() -> void:
	var HUD_lamp = get_tree().get_first_node_in_group("HUD_lamp")
	if HUD_lamp != null:
		HUD_lamp.hud_lamp_on_phase()

func switch_hud_crt() -> void:
	var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
	crt.tween_brightness(2.2)
	crt.tween(0.1, 1.0)

func phase_completed() -> void:
	phase_complete.emit()
