extends Node3D

@onready var ammo_crate_preload = preload("res://300_assets/Ammo/Ammo_pickup.tscn")

@export var score_to_beat_for_the_level := 801
@export var player_current_score := 0
@export var dev_mode := false
@export var retry_world := false

var pineapple_intro := false
var timer_start_time := 600.0
var doing_pineapple_intro := false
var done_crt_intro := false
@export_group("Level Select", "")

@export var level_1 := false
@export var level_2 := false
@export var level_3 := false
@export var level_4 := false


func reposition_egg_and_markers() -> void:
	#$Egg_cage.hide()
	#$Egg_cage.global_position = Vector3(-1.0, -1.3, 0.886)
	$Egg_cage.global_position.y -= 5
	#%Target_markers.global_position = Vector3(-1.0, -1.857, 0.886)
	

func retry_version() -> void:
	if level_1:
		$Lighting/Direction_light_retry.show()
		$Lighting/DirectionalLight3D.hide()
		
	if level_2:
		#var RETRY_STAGE_ENVIRONMENT = preload('res://800_3D_materials/skyEnvironments/Retry_stage_environment.tres')
		$Lighting/Direction_light_retry.show()
		$Lighting/DirectionalLight3D.hide()
		#$Lighting/WorldEnvironment.environment = RETRY_STAGE_ENVIRONMENT
		
	if level_3:
		pass
		
	if level_4:
		pass
		
		
		
func _ready() -> void:
	EventBus.instance.level_restarted.emit()
		
	if retry_world:
		GameManager.in_retry_world = true
	
	if dev_mode:
		EventBus.instance.in_dev_mode.emit()

	if !GameManager.in_retry_world:
		GameManager.reset_score()
		#$Lighting/DirectionalLight3D.show()
		#$Lighting/Direction_light_retry.hide()

	else:
		#$Cannon_Launcher.launcher_container.reduce_arc_trajectory()
		$Radar_view_panel.hide()
		%Hostage_side_panel.hide()
		GameManager.reset_score_retry()
		reposition_egg_and_markers()
		$Lighting/DirectionalLight3D.hide()
		if $Lighting/Direction_light_retry:
			$Lighting/Direction_light_retry.show()
		
	var world_env : WorldEnvironment = get_tree().get_first_node_in_group('world_env')
	world_env.environment.glow_bloom = 0.0
	GameManager.world_env = world_env
	GameManager.apply_retry_environment_if_needed()
	
	world_env.environment.background_energy_multiplier = 1.0

	
	%Intro_sequence.no_intro_sequence()
	
	connect_signals()
	#$Lighting/WorldEnvironment.environment.fog_enabled = true
	
	
	start_intro_sequence()
	$GameLoopManager.start_next_phase()
	BackgroundForTransition.fade_out()


	
func _input(event: InputEvent) -> void:
	if Input.is_key_label_pressed(KEY_4):
		print('------')
		GameManager.current_score_displayed = 700
		GameManager.current_score_not_displayed = 700
		#print('Orphaned nodes')
		#print_orphan_nodes()
		#GameManager.current_score_displayed = ScoreGl.winning_score - 1
		#GameManager.current_score_not_displayed = ScoreGl.winning_score - 1
		print('------')
		
		
func start_intro_sequence() -> void:
	if !pineapple_intro:
		$TV_hud.crt_start_up()
		await get_tree().create_timer(0.2).timeout
		$Zoom_in_sequence.begin_zoom_out_process()
		await get_tree().create_timer(1.0).timeout
		pineapple_intro = false
		var SHOW_PRIZE_SHORT_VERSION = preload("res://lib/Pineapples_display_intro/Show_prize_short_version.tscn")
		var pineapple_instance = SHOW_PRIZE_SHORT_VERSION.instantiate()
		
		#await get_tree().create_timer(2.0).timeout
		add_child(pineapple_instance)
		#await pineapple_instance.finished_display
		done_crt_intro = true
		

	else:
		if !done_crt_intro:
			done_crt_intro = true
			$TV_hud.crt_start_up()


func connect_signals() -> void:
	var level_timer = get_tree().get_first_node_in_group("level_timer")
	if level_timer:
		level_timer.ammo_countdown_finished.connect(continue_sequence)
		
	#var hostage_killed : Node3D = get_tree().get_first_node_in_group("Bunny_Cage_physical")
	#if hostage_killed:
		#hostage_killed.hostage_killed_signal.connect(level_failed)
	

func continue_sequence() -> void:
	$Level_transitions/continue_sequence.player_survived() 
	#
#func level_failed() -> void:	
	##$Level_transitions/player_failed_sequence.start_sequence_losing()
	#
