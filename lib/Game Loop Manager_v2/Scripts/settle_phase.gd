extends Control
class_name Settle_Phase

const SOUNDSCAPE_SFX = preload("res://500_sequences/Game Loop Manager_v2/soundscape_sfx.tscn")
const BIRDS_NOISES = preload("res://400_sounds/HUD Sfx/birds_noises.wav")
const SCORE_TALLY_SFX = preload("res://400_sounds/HUD Sfx/score_tally_sfx.wav")
const SCORE_TALLY_SFX_REVERSE = preload("res://400_sounds/HUD Sfx/score_tally_sfx_reverse_2.wav")
const SCORE_MANAGER_SEQUENCE = preload("res://500_sequences/Score Manager sequence/Score Manager Sequence.tscn")

@onready var label: Label = $Label
@onready var game_loop_manager : GameLoopManager = get_tree().get_first_node_in_group('game_loop_manager')
@onready var ammo_management_system = get_tree().get_first_node_in_group('Ammo_management_system')
@onready var player : Player = get_tree().get_nodes_in_group('Player')[0]
@onready var low_hum = get_tree().get_first_node_in_group('Temporary_low_humming')
@onready var soundscape = get_tree().get_first_node_in_group("soundscape")
@onready var HUD_feedback : HUD_feedback_corner = get_tree().get_first_node_in_group("HUD_feedback_corner")
@onready var HUD_lamp = get_tree().get_first_node_in_group("HUD_lamp")
@onready var HUD_lines = get_tree().get_first_node_in_group("HUD_Lines")
@onready var crt = get_tree().get_first_node_in_group("TV_CRT_Filter")
@onready var crosshair : Player_Crosshair = get_tree().get_nodes_in_group('HUD_crosshair')[0]

signal phase_complete

func start_phase() -> void:
	chance_of_wind_blowing()
	prepare_cms_next_batch()
	HUD_lamp.hud_lamp_settle_phase()
	make_crosshair_duller()
	EventBus.instance.settle_phase_started.emit()
	await get_tree().create_timer(0.1).timeout

	change_hud_line_colour_red()
	await get_tree().create_timer(0.1).timeout

	pull_up_score()
	await get_tree().create_timer(0.2).timeout

	fade_out_sequence()


func make_crosshair_duller() -> void:
	return
	if !GameManager.player_has_winning_score:
		crosshair.crosshair_dull_mode()
		player.toggle_player_shooting_off()


func play_hum_sound() -> void:
	low_hum.play_sound()
	GlobalMusic.turn_down_music()


func pull_up_score() -> void:
	if HUD_feedback:
		HUD_feedback.pull_up_score_tally()

	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(instantiate_sms)
	await tween.finished


func instantiate_sms() -> void:
	var new_sms = SCORE_MANAGER_SEQUENCE.instantiate()
	get_parent().add_child(new_sms)


func chance_of_wind_blowing() -> void:
	var rand := randi_range(1,10)
	if rand >= 6:
		CommonCode.bird_fly_by()
		#CommonCode.set_all_particles_blow_away(Vector3(0.0, 1.0, 5.0), 5.0)
	else:
		pass
		
func fade_out_sequence() -> void:
	low_hum.HUD_off_mode()
	await get_tree().create_timer(0.25).timeout

	change_hud_line_colour()
	ammo_management_system.reset_ammo_after_round_delay()
	await get_tree().create_timer(1.25).timeout

	phase_completed()


func change_hud_line_colour() -> void:
	if !GameManager.player_has_winning_score:
		HUD_lines.turn_white()
		HUD_lines.vs_half()


func change_hud_line_colour_red() -> void:
	if !GameManager.player_has_winning_score:
		crt.tween(0.1, 1.0)
		HUD_lines.turn_white()
		HUD_lines.vs_half()
	play_hum_sound()


func pulse_ring() -> void:
	_spawn_pulse_ring()
	await get_tree().create_timer(2.0).timeout
	_spawn_pulse_ring()


func _spawn_pulse_ring() -> void:
	var new_pulse = $Round_tally/Light2.duplicate()
	new_pulse.modulate = Color('8a8a8a8a')
	$Round_tally.add_child(new_pulse)

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 8.0, 2.5)


func play_sound() -> void:
	if soundscape:
		soundscape.complete_silence()
	else:
		var new_soundscape = SOUNDSCAPE_SFX.instantiate()
		get_tree().get_current_scene().add_child(new_soundscape)


func silence_hum_sound() -> void:
	low_hum.fade_out_sound()


func phase_completed() -> void:	
	game_loop_manager._on_settle_phase_complete()
	# phase_complete.emit() # Optional: toggle based on your signal needs


func prepare_cms_next_batch() -> void:
	var cms : CMS = get_tree().get_first_node_in_group("CMS")
	if cms:
		cms.cms_start_process()
