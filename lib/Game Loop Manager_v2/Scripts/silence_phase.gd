extends Control

const HUD_ON_CLICK = preload("res://sfx/HUD on click.wav")
const SOUNDSCAPE_SFX = preload("res://lib/Game Loop Manager_v2/soundscape_sfx.tscn")
const BIRDS_NOISES = preload("res://sfx/birds_noises.wav")

signal phase_complete

func start_phase() -> void:
	change_hud_line_colour()
	prepare_cms_first_load()
	start_soundscape()
	await get_tree().create_timer(0.15).timeout
	CommonCode.play_sound_instance(BIRDS_NOISES, 0.0)
	blink_HUD_light()

	if !GameManager.silence_phase_done:
		await get_tree().create_timer(1.5).timeout
		phase_completed()
	else:
		phase_completed()


func prepare_cms_first_load() -> void:
	await get_tree().create_timer(0.2).timeout
	
	var launcher_manager = get_tree().get_nodes_in_group('launcher_manager')[0]
	if launcher_manager:
		launcher_manager.update_amount_of_launchers()
	
	await get_tree().create_timer(0.5).timeout
	
	var CMS = get_tree().get_first_node_in_group("CMS")
	if CMS != null:
		CMS.cms_start_process()

func change_hud_line_colour() -> void:
	var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
	if HUD_lines != null:
		HUD_lines.turn_red()
		HUD_lines.vs_off()

func blink_HUD_light() -> void:
	var HUD_lamp = get_tree().get_first_node_in_group("HUD_lamp")
	if HUD_lamp != null:
		HUD_lamp.silence_phase_blinking()
		
func start_soundscape() -> void:
	var existing_soundscape = get_tree().get_first_node_in_group("soundscape")
	if existing_soundscape == null:
		var new_soundscape = SOUNDSCAPE_SFX.instantiate()
		get_tree().get_current_scene().add_child(new_soundscape)
	else:
		existing_soundscape.sound_silence_phase()


func phase_completed() -> void:
	GameManager.silence_phase_done = true
	phase_complete.emit()
