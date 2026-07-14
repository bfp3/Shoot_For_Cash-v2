extends Node
class_name RoundManager

@export var rounds_until_shop := 3

const LEVEL_LAYOUT_00_OPENING_SCENE = preload('uid://88s7u86w4lfr')
const LEVEL_LAYOUT_01_MOSS = preload('uid://bc6weh2tp6rox')
const LEVEL_LAYOUT_02_REDD = preload('uid://bbpjw4jqdvt5g')
const LEVEL_LAYOUT_03_GLORY = preload('uid://b3gni42s8751h')

const DEMO_END_SCREEN = preload('uid://dpbgyfs2kgdtr')

var game_has_been_beaten := false

var current_rock_sequence : Array = []
var seq_rock_pointer := -1

var bullet_active := false
var bullet_active_counter := 0.0
var round_finished := false
var transitioning_worlds := false
@export var pineapple_mode := false

@export var level_layout : Node3D
@export var scene_transition_screen : Control 
@export var current_round := 0
@export var rounds_to_complete := 5
@export var switched_on := true
@export var confetti_cannon : Node3D
@export var upgrade_menu : Control
@export var tally_menu : Control
@export var round_timer : RoundTimer
@export var place_name : Control
@export var player : Player
@export var current_song : AudioStreamPlayer
@export var ending_song : AudioStreamPlayer
@export var rocks_container: RockManager
@export var music_manager : Node
@export var hud_system : TextureRect
@export var birds : Node3D
@export var balloon_container : Node3D
var egg_pulse : Egg


enum RoundState {
	INACTIVE,
	FIRST_ROUND,
	ROUND_START,
	ROUND_IN_PROGRESS,
	ROUND_END,
	CHECK_ROUNDS,
	TALLY_START,
	TALLY_END,
	SHOP_START,
	SHOP_END,
	PAUSE,
	RESUME,
	GAME_WON,
	NEXT_LEVEL,
	END_DEMO
	}

@export var current_round_state : RoundState = RoundState.INACTIVE

var success := false

func _ready() -> void:
	move_to_start()
	#EventBus.instance.close_shop.connect(enter_state.bind(RoundState.SHOP_END))
	#EventBus.instance.game_won.connect(enter_state.bind(RoundState.GAME_WON))
	EventBus.instance.all_rocks_destroyed.connect(successful_round)
	EventBus.instance.end_round_rock_missed.connect(unsuccessful_round)
	
	await get_tree().process_frame
	enter_state(current_round_state)
	
func successful_round() -> void:

	success = true
	print('successful round')
	perfect_score_feedback()
	enter_state(RoundState.ROUND_END)
	
	

func unsuccessful_round() -> void:
	print('unsuccessful round')
	enter_state(RoundState.ROUND_END)
	pass

func enter_state(new_state : RoundState) -> void:
	if transitioning_worlds:
		return
	
	current_round_state = new_state

	
	match new_state:
		RoundState.INACTIVE:
			update_round_inactive()
			
		RoundState.FIRST_ROUND:
			update_round_first_round()
			
		RoundState.ROUND_START:
			update_round_start()
			
		RoundState.ROUND_IN_PROGRESS:
			update_round_in_progress()
			
		RoundState.ROUND_END:
			update_round_end()
			
		RoundState.CHECK_ROUNDS:
			update_check_rounds()
			
		RoundState.TALLY_START:
			update_tally_start()
			
		RoundState.TALLY_END:
			update_tally_end()
			
		RoundState.SHOP_START:
			update_shop_start()
			
		RoundState.SHOP_END:
			update_shop_end()
			
		RoundState.PAUSE:
			update_pause()
		
		RoundState.RESUME:
			update_resume()
				
		RoundState.GAME_WON:
			update_game_won()
			
		RoundState.END_DEMO:
			update_end_demo()
			
func update_round_inactive() -> void:
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.INACTIVE)
	
	
func update_round_first_round() -> void:
	player.stop_player()
	await get_tree().create_timer(0.5).timeout
	enter_state(RoundState.SHOP_START)


func update_round_start() -> void:

	success = false
	
	while game_has_been_beaten:
		await get_tree().process_frame
	
	if gl_PlayerState.dataset.stage_name == 'start':
		go_to_fake_round()
		return
		
	if gl_PlayerState.dataset.round == 0:
		music_manager.first_round()
	
	
	
	if gl_PlayerState.dataset.power_balloon_buster > 0:
		player.start_player()
		
	while gl_PlayerState.dataset.power_balloon_buster > 0:
		#gl_PlayerState.dataset.power_balloon_buster = 0
		#print('true')
		#if bullet_active:
			#bullet_active = false
			#await get_tree().create_timer(1.0).timeout
		await get_tree().process_frame
		
	gl_PlayerState.next_round() # This is placed here to prevent going to round 1 

	current_round = gl_PlayerState.dataset.round
	
	
	
	#seq_rock_pointer = 0
	
	
	current_rock_sequence = [
		[3,3,1]
		,[2,2,6]
		,[3,3,1]

		,[2,2,14,4]
		,[2,2,14,4]
		,[3,3,1,1,8]
		
		,[3,3,1,1,18]
		,[3,3,1,1,18, 18]
		,[3,3,1,1,18, 18]
		#,[3,13,1,1]
		#,[2,2,14,4]
		#,[3,13,1,13]
		]
	
	
	var rock_seq := update_rock_sequence()
	#rock_seq = [5,5,1,1,6,6]
	
	
	
	print('Next Rock Seq ', rock_seq)
	rocks_container.start_manual_rock_round(rock_seq)

	
	
	if rounds_until_shop == 3:
		round_timer.enter_state(round_timer.State.RESTARTING)
	player.update_player_stats()
	player.start_player()
	music_manager.shop_music_raise_volume()
	await get_tree().create_timer(0.75).timeout
	egg_pulse.activate_pulse_wave()
	
	await get_tree().create_timer(2.0).timeout
	enter_state(RoundState.ROUND_IN_PROGRESS)

func update_rock_sequence() -> Array:
	seq_rock_pointer += 1
	if seq_rock_pointer > current_rock_sequence.size() - 1:
		seq_rock_pointer = 0
		return current_rock_sequence[seq_rock_pointer]
		
	else:
		return current_rock_sequence[seq_rock_pointer]


func go_to_fake_round() -> void:
	round_timer.enter_state(round_timer.State.RESTARTING)
	if gl_PlayerState.dataset.power_gun > 0:
		player.start_player()
	await get_tree().create_timer(1.0).timeout
	music_manager.shop_music_raise_volume()
	await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(2.0).timeout
	enter_state(RoundState.ROUND_IN_PROGRESS)
	round_timer.enter_state(round_timer.State.RUNNING)
	#check_round_events()

func update_round_in_progress() -> void:
	round_finished = false
	if round_timer.current_state != round_timer.State.RUNNING:
		round_timer.enter_state(round_timer.State.RUNNING)



func update_round_end() -> void:

	if round_finished:
		return
	pineapple_mode = false
	#if pineapple_mode:
	#
		#await get_tree().process_frame
		
	
	#$'../Pineapple'.stop_pineapples()
	#player.round_finished(true)
	
	round_finished = true
	birds.start_birds()
	
	await get_tree().create_timer(0.25).timeout

	#stop_timer()
	
	music_manager.shop_music_lower_volume()
		
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)

	while bullet_active == true:
		await get_tree().process_frame

		bullet_active_counter += 1.0

		if bullet_active_counter > 60.0:
			bullet_active = false

	bullet_active_counter = 0.0
	
	if success:
		
		success = false
		#perfect_score_feedback()
		if gl_PlayerState.dataset.power_bonus_round_pineapples > 0:
			player.round_finished(false)
			#rocks_container.enter_state(rocks_container.State.INACTIVE)
			#await get_tree().create_timer(0.1).timeout
			#rocks_container.enter_state(rocks_container.State.PREPARE_ROCKS)
			#await get_tree().create_timer(0.1).timeout
			#egg_pulse.activate_pulse_wave()
			#await get_tree().create_timer(1.0).timeout
			pineapple_mode = true
			pineapple_round()
			while pineapple_mode:
				await get_tree().process_frame
					
			#stop_player()
		
			await get_tree().create_timer(1.0).timeout
			enter_state(RoundState.CHECK_ROUNDS)
		
		else:
			#stop_player()
			await get_tree().create_timer(1.0).timeout
			enter_state(RoundState.CHECK_ROUNDS)
		
	else:
		
		enter_state(RoundState.CHECK_ROUNDS)
	
	if gl_PlayerState.dataset.power_bonus_round_pineapples > 0:
		EventBus.instance.pineapple_round_used.emit()
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0

func update_check_rounds() -> void:
	rounds_until_shop = clamp(rounds_until_shop - 1, 0, 100)
	
	if round_timer.time_left <= 0.0: #rounds_until_shop == 0 || 
		rounds_until_shop = 3
		player.round_finished(true)
		stop_player()
		await get_tree().create_timer(1.0).timeout
		enter_state(RoundState.TALLY_START)
	else:
		enter_state(RoundState.ROUND_START)
		


func update_tally_start() -> void:
	#$'../PlayerBalloon'.reposition_balloon()
	check_how_many_rounds_left()
	EventBus.instance.open_tally_card.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_tally_end() -> void:
	#await get_tree().create_timer(0.5).timeout
	balloon_container.add_balloon()
	enter_state(RoundState.SHOP_START)

	
func update_shop_start() -> void:
	EventBus.instance.open_shop.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	

func update_shop_end() -> void:
	#red_circle.display_circle()
	hud_system.reset_hud()
	#await get_tree().create_timer(0.5).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	enter_state(RoundState.ROUND_START)
	if current_round > 2:
		$'../PlayerBalloon'.check_balloons_status()
	

func update_pause() -> void:
	if round_timer:
		round_timer.enter_state(round_timer.State.PAUSE_TIMER)


func update_resume() -> void:
	if round_timer:
		round_timer.enter_state(round_timer.State.RESUME_TIMER)

func update_game_won() -> void:
	#$'../Cannon_Launcher'.send_in_the_pineapples()
	stop_timer()
	game_has_been_beaten = true
	music_manager.game_won()
	ending_song.play()
	
	%Shop_Main_Menu.enter_state(%Shop_Main_Menu.SkillState.CLOSE_MENU)
	%TallyCard.enter_state(%TallyCard.State.CLOSE_MENU)
	stop_player()
	
	await get_tree().create_timer(1.0).timeout
	enter_state(RoundState.INACTIVE)
	
	await get_tree().create_timer(60.0).timeout
	
	
	
	
	#BackgroundForTransition.fade_out()
	

	


			
func move_to_start() -> void:
	if level_layout.get_children().size() > 0:
		level_layout.get_child(0).queue_free()
	#var current_level_layout = level_layout.get_node_or_null('current_level_layout')
	#if current_level_layout:
		#current_level_layout.queue_free()
	
	var level_mesh = LEVEL_LAYOUT_00_OPENING_SCENE.instantiate()
	level_layout.add_child(level_mesh)
	level_mesh.name = 'current_level_layout'

func move_to_moss() -> void:
	
	current_rock_sequence = gl_DataSet.get_array('seq_rocks_moss')
	
	printt('I have updated the rock waves in Moss ', current_rock_sequence)
	
	transitioning_worlds = true
	player.display_hud()
	gl_PlayerState.dataset["stage"] = 1
	#gl_PlayerState.dataset["rock_limit"] = 1
	gl_PlayerState.dataset["reroll_unlocked"] = 1

		
	music_manager.stop_opening_song()
	
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0).timeout
	level_layout.get_child(0).queue_free()
	#var current_level_layout = level_layout.get_node_or_null('current_level_layout')
	#if current_level_layout:
		#current_level_layout.queue_free()
	rocks_container.show()
	var level_scenery = LEVEL_LAYOUT_01_MOSS.instantiate()
	level_layout.add_child(level_scenery)
	
	level_scenery.name = 'current_level_layout'
	
	await get_tree().create_timer(1.0).timeout
	
	if egg_pulse == null:
		find_egg()
	
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	
	if current_round == 0:
		#await get_tree().create_timer(0.5).timeout
		$'../PlayerBalloon'.add_balloon()
	
	#rocks_container.reset_rock_back_on()
	await get_tree().create_timer(3.0).timeout
	transitioning_worlds = false
	enter_state(RoundState.SHOP_END)
	#$"../MainGameCanvasLayer/Intro_Prompt".start()
	
	
func move_to_redd() -> void:
	transitioning_worlds = true
	player.hide_hud()
	gl_PlayerState.dataset["rock_limit"] = 1
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0).timeout

	level_layout.get_child(0).queue_free()
	#var current_level_layout = level_layout.get_node_or_null('current_level_layout')
	#if current_level_layout:
		#current_level_layout.queue_free()
	
	var new_scene = LEVEL_LAYOUT_02_REDD.instantiate()
	level_layout.add_child(new_scene)
	
	new_scene.name = 'current_level_layout'
	
	
	await get_tree().create_timer(1.0).timeout
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	if egg_pulse == null:
		find_egg()
	#rocks_container.reset_rock_back_on()

	await get_tree().create_timer(1.0).timeout
	transitioning_worlds = false
	enter_state(RoundState.SHOP_END)
	player.display_hud()
	
func move_to_glory() -> void:
	
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0).timeout

	level_layout.get_child(0).queue_free()
	#var current_level_layout = level_layout.get_node_or_null('current_level_layout')
	#if current_level_layout:
		#current_level_layout.queue_free()
	
	var new_scene = LEVEL_LAYOUT_03_GLORY.instantiate()
	level_layout.add_child(new_scene)
	
	new_scene.name = 'current_level_layout'
	
	await get_tree().create_timer(0.1).timeout
	#if egg_pulse == null:
	find_egg()
	
	await get_tree().create_timer(1.0).timeout
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	
	#rocks_container.reset_rock_back_on()

	await get_tree().create_timer(1.0).timeout
	transitioning_worlds = false
	enter_state(RoundState.SHOP_END)



func update_end_demo() -> void:
	
	enter_state(RoundState.INACTIVE)
	game_has_been_beaten = true
	scene_transition_screen.demo_end_fadein()
	await get_tree().create_timer(0.5).timeout
	EventBus.instance.game_beaten.emit()

	await get_tree().create_timer(0.5).timeout

	level_layout.get_child(0).queue_free()

	var new_scene = LEVEL_LAYOUT_03_GLORY.instantiate()
	level_layout.add_child(new_scene)
	new_scene.name = 'current_level_layout'
	
	await get_tree().create_timer(0.5).timeout
	#if egg_pulse == null:
	find_egg()
	
	
	await get_tree().create_timer(1.0).timeout
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()

	await get_tree().create_timer(1.0).timeout
	
	var demo_screen : Control = $'../MainGameCanvasLayer/DemoEndScreen'
	demo_screen.enter_state(demo_screen.State.OPEN_MENU)
	

	
func stop_player() -> void:
	player.stop_player()


func stop_timer() -> void:
	round_timer.stop_timer()

func find_egg() -> void:
	egg_pulse = get_tree().get_first_node_in_group('Egg_Cage')

func check_round_events() -> void:
	pass
	#if current_round % 3 == 0:
		#await get_tree().create_timer(3.0).timeout
		#egg_pulse.activate_pulse_wave()


func perfect_score_feedback() -> void:
	player.perfect_score()

func pineapple_round() -> void:
	
	%PerfectParticles.emitting = true
	%PerfectParticles2.emitting = true


	gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	await get_tree().create_timer(1.0).timeout

	$'../Pineapple'.pineapple_round_1()
	await get_tree().create_timer(2.0).timeout
	
	$'../Pineapple'.pineapple_round_2()
	await get_tree().create_timer(2.0).timeout
	
	$'../Pineapple'.pineapple_round_3()
	
	while gl_PlayerState.dataset.total_pineapples_destroyed < 3:
		await get_tree().process_frame
		
	#await get_tree().create_timer(2.5).timeout
		
	if gl_PlayerState.dataset.total_pineapples_destroyed > 2:

		%PerfectPineappleRound.play(0.5)
		pineapple_mode = false
	
		
	else:
		pineapple_mode = false
	
	
	$'../Pineapple'.stop_pineapples()
	EventBus.instance.pineapple_round_used.emit()
	


	
	
	
	
func restart() -> void:
	# Runtime state
	game_has_been_beaten = false
	bullet_active = false
	bullet_active_counter = 0.0
	round_finished = false
	transitioning_worlds = false
	pineapple_mode = false
	success = false
	current_round = 0

	# Reset state machine
	current_round_state = RoundState.INACTIVE

	# Reset music/timer/player
	stop_timer()
	stop_player()

	if current_song:
		current_song.stop()
	if ending_song:
		ending_song.stop()

	# Reset world
	#move_to_start()
	move_to_moss()
	#find_egg()

	# Reset player
	player.round_finished(false)
	player.display_hud()
	player.update_player_stats()

	# Reset UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud_system.reset_hud()

	# Reset scenery
	rocks_container.hide()
	birds.start_birds()

	# Return to the beginning
	await get_tree().process_frame

	#enter_state(RoundState.ROUND_START)
func game_over() -> void:
	player.stop_player()
	stop_timer()
	enter_state(RoundState.INACTIVE)

func start_game_over() -> void:
	var game_over_menu = get_tree().get_first_node_in_group('game_over_screen')
	if game_over_menu:
		game_over_menu.update_open_menu()
	else:
		print('cannot find game over')
		
	player.stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func check_how_many_rounds_left() -> void:
	#print('Current Round = ', current_round)
	increase_rock_limit()
	if current_round > rounds_to_complete:
		%Game_Won.show()
		update_game_won()

func increase_rock_limit() -> void:
	#gl_PlayerState.dataset.rock_limit += 3
	#gl_PlayerState.dataset.rock_limit = 9
	pass
	#if current_round == 6:
		#gl_PlayerState.dataset.rock_limit = 5
		#return
		#
	#if current_round == 13:
		#gl_PlayerState.dataset.rock_limit = 7
		#return
		#
	#if current_round == 20:
		#gl_PlayerState.dataset.rock_limit = 9
		#return
		
#func _process(delta: float) -> void:
	#print(gl_PlayerState.dataset.rock_limit)
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('backward'):
		seq_rock_pointer = -1
		print(pineapple_mode)
		pineapple_mode = false
		#enter_state(RoundState.TALLY_START)
