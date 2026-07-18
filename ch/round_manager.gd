extends Node
class_name RoundManager

@export var rounds_until_shop := 3

var player_failed := false
var compulsory_rocks_destroyed := false
var in_display_text_prompt := false
var force_shop_open := false
var player_can_progress := false

const current_rock_sequence : Array = [
	# First
	[1,33,33]
	,[41,1,33,33]
	,[311,323,41,33,1,33]
#
	 ##Second
	,[2,2,32,34,34,34]
	,[42,2,2,32,34,44,34,34]
	,[312,332,324,42,2,2,32,34,44,34,34]
#
	## Third
	,[33,5,7,37,37,5,33]
	,[33,5,7,37,37,45,5,47,47,33]
	,[33,5,7,37,37,45,5,47,47,33,323,314,325,316,327]

	# Fourth
	,[2,32,4,34,34,6,6,36,36,8,8,38]
	,[42,2,32,4,34,34,44,6,6,46,36,36,8,8,38,46]
	,[42,2,32,4,34,34,44,6,6,46,36,36,8,8,38,46,311,312,313,314,315,316,317,318]

	]

var current_sequence_index := 0
var current_wave := 0


const LEVEL_LAYOUT_00_OPENING_SCENE = preload('uid://88s7u86w4lfr')
const LEVEL_LAYOUT_01_MOSS = preload('uid://bc6weh2tp6rox')
const LEVEL_LAYOUT_02_REDD = preload('uid://bbpjw4jqdvt5g')
const LEVEL_LAYOUT_03_GLORY = preload('uid://b3gni42s8751h')

var game_has_been_beaten := false

var bullet_active := false
var bullet_active_counter := 0.0
var round_finished := false
var transitioning_worlds := false
var pineapple_mode := false

@export var level_layout : Node3D
@export var scene_transition_screen : Control 
@export var current_round := 0
@export var rounds_to_complete := 5
@export var switched_on := true
@export var confetti_cannon : Node3D
@export var shop_main_menu : Control
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
	CHECK_EVENTS,
	SHOP_START,
	SHOP_END,
	ROUND_START,
	WAVE_START,
	WAVE_END,
	ROUND_END,
	CHECK_ROUNDS,
	TALLY_START,
	TALLY_END,
	PAUSE,
	RESUME,
	GAME_WON,
	NEXT_LEVEL,
	END_DEMO
	}

@export var current_round_state : RoundState = RoundState.INACTIVE

var success := false

func _ready() -> void:
	current_sequence_index = 0
	current_wave = 0
	force_shop_open = false
	
	move_to_start()
	#move_to_moss()
	#EventBus.instance.close_shop.connect(enter_state.bind(RoundState.SHOP_END))
	#EventBus.instance.game_won.connect(enter_state.bind(RoundState.GAME_WON))
	EventBus.instance.all_rocks_destroyed.connect(successful_round)
	EventBus.instance.rocks_cleared_end_wave.connect(next_wave)
	EventBus.instance.end_round_rock_missed.connect(unsuccessful_round)
	EventBus.instance.all_white_compulsory_rocks_destroyed.connect(white_rocks_destroyed)
	await get_tree().process_frame
	enter_state(current_round_state)
	
	
func white_rocks_destroyed() -> void:
	compulsory_rocks_destroyed = true

func successful_round() -> void:
	print('successful round')
	if gl_PlayerState.dataset.total_hazards > 0:
		unsuccessful_round()
		return
	
	success = true
	
	$Gold_sfx.play()
	$Gold_sfx.pitch_scale += 0.05
	
	if current_wave >= 2:
		player_can_progress = true
		
		await get_tree().create_timer(0.2).timeout
		if gl_PlayerState.dataset.total_hazards <= 0:
			if gl_PlayerState.dataset.perfect_rounds >= 3:
				gl_PlayerState.dataset.power_bonus_round_pineapples = 1
				perfect_score_feedback()
			else:
				if !pineapple_mode:
					perfect_score_feedback()
				
	#perfect_score_feedback()
	enter_state(RoundState.ROUND_END)
	
	
func unsuccessful_round() -> void:
	print('unsuccessful round')
	stop_timer()
	player_failed = true
	rounds_until_shop = 0
	force_shop_open = true
	%Splash_zone.deactivate_splash_zone()
	enter_state(RoundState.ROUND_END)
	
	
func next_wave() -> void:
	stop_timer()
	await get_tree().create_timer(0.5).timeout
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
	
	if current_round == 0:
		in_display_text_prompt = true
		$"../MainGameCanvasLayer/Intro_Prompt".start()
	
	while in_display_text_prompt:
		await get_tree().process_frame
	
		
	success = false
	player_failed = false
	compulsory_rocks_destroyed = false
	
	while game_has_been_beaten:
		await get_tree().process_frame
	
	if gl_PlayerState.dataset.stage_name == 'start':
		go_to_fake_round()
		return
		
	if gl_PlayerState.dataset.round == 2:
		music_manager.first_round()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if gl_PlayerState.dataset.power_balloon_buster > 0:
		player.start_player()
		
	while gl_PlayerState.dataset.power_balloon_buster > 0:
		#gl_PlayerState.dataset.power_balloon_buster = 0
		
		#if bullet_active:
			#bullet_active = false
			#await get_tree().create_timer(1.0).timeout
		await get_tree().process_frame
	
	if rounds_until_shop == 3:
		gl_PlayerState.next_round() # This is placed here to prevent going to round 1 
	
	else:
		gl_PlayerState.next_wave()

	#current_round = gl_PlayerState.dataset.round
	
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
	
	
	gl_PlayerState.dataset.bonus_cash_this_round = 20
	
	var rock_seq := update_rock_sequence()
	if rock_seq != []:
		#print('Next Rock Seq ', rock_seq)
		rocks_container.start_manual_rock_round(rock_seq)
		
	else:
		start_game_over()
	
	if rounds_until_shop == 3:
		round_timer.enter_state(round_timer.State.RESTARTING)
		
	else:
		round_timer.timer_rollup_sequence()
		
	player.update_player_stats()
	player.start_player()
	music_manager.shop_music_raise_volume()
	await get_tree().create_timer(0.75).timeout
	egg_pulse.activate_pulse_wave()
	
	await get_tree().create_timer(2.0).timeout
	enter_state(RoundState.ROUND_IN_PROGRESS)



func update_rock_sequence() -> Array:
	if current_rock_sequence.is_empty():
		return []
		
	if current_sequence_index >= current_rock_sequence.size():
		return []
	
	return current_rock_sequence[current_sequence_index].duplicate()



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
	current_wave += 1

	if current_wave >= 3 or force_shop_open:
		
		force_shop_open = false

		if current_sequence_index >= current_rock_sequence.size():
			start_game_over()
			return
			
		stop_player()
		rounds_until_shop = 3
		
		if compulsory_rocks_destroyed == true && player_failed != true:
			current_sequence_index += 1
			player_can_progress = false
			compulsory_rocks_destroyed = false
		
		await get_tree().create_timer(1.0).timeout
		current_wave = 0
		balloon_container.end_round()
		enter_state(RoundState.TALLY_START)
	else:
		rounds_until_shop -= 1
		enter_state(RoundState.ROUND_START)
		


func update_tally_start() -> void:
	#$'../PlayerBalloon'.reposition_balloon()
	EventBus.instance.open_tally_card.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_tally_end() -> void:
	#await get_tree().create_timer(0.5).timeout
	if !player_failed:
		gl_PlayerState.add_cash(gl_PlayerState.dataset.bonus_cash)
	
	if current_sequence_index >= current_rock_sequence.size():
		start_game_over()
		return
	
	# Check whether to add balloons
	enter_state(RoundState.SHOP_START)

	
func update_shop_start() -> void:
	$Gold_sfx.pitch_scale = 0.7
	EventBus.instance.open_shop.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rocks_container.reset_all_rocks()
	if current_round > 0:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			balloon_container.add_balloon(rock_seq)
	
func update_shop_end() -> void:
	#red_circle.display_circle()
	hud_system.reset_hud()
	#await get_tree().create_timer(0.5).timeout
	
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
	stop_timer()
	music_manager.game_won()
	ending_song.play()
	stop_player()
	enter_state(RoundState.INACTIVE)


			
func move_to_start() -> void:
	if level_layout.get_children().size() > 0:
		level_layout.get_child(0).queue_free()
	
	var level_mesh = LEVEL_LAYOUT_00_OPENING_SCENE.instantiate()
	level_layout.add_child(level_mesh)
	level_mesh.name = 'current_level_layout'

func move_to_moss() -> void:
	transitioning_worlds = true
	player.display_hud()
	gl_PlayerState.dataset["stage"] = 1
	#gl_PlayerState.dataset["rock_limit"] = 1
	gl_PlayerState.dataset["reroll_unlocked"] = 1
	
	gl_PlayerState.dataset.round += 1
		
	music_manager.stop_opening_song()
	
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0).timeout
	
	
	if level_layout.get_child(0) != null:
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
		
	gl_PlayerState.dataset.tickets += 1
	shop_main_menu.update_next_ticket()
		
	#rocks_container.reset_rock_back_on()
	await get_tree().create_timer(2.0).timeout
	%Grand_total_prompt.start()
	await get_tree().create_timer(1.0).timeout
	transitioning_worlds = false
	
	in_display_text_prompt = true
	
	while in_display_text_prompt:
		await get_tree().process_frame
		
	#enter_state(RoundState.SHOP_END)
	enter_state(RoundState.SHOP_START)

	
	
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
	current_sequence_index = 0
	current_round = 0
	current_wave = 0
	force_shop_open = false
	
	# Runtime state
	game_has_been_beaten = false
	bullet_active = false
	bullet_active_counter = 0.0
	round_finished = false
	transitioning_worlds = false
	pineapple_mode = false
	success = false

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
