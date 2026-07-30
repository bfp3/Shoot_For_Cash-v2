extends Node
class_name RoundManager

const LEVEL_LAYOUT_00_OPENING_SCENE = preload('uid://88s7u86w4lfr')
const LEVEL_LAYOUT_01_MOSS = preload('uid://bc6weh2tp6rox')
const LEVEL_LAYOUT_02_REDD = preload('uid://bbpjw4jqdvt5g')
const LEVEL_LAYOUT_03_GLORY = preload('uid://b3gni42s8751h')

const current_rock_sequence : Array = [
	# BLAKE VER START
	[1,3]
	,[311,1,1,3,3]
	,[311, 313, 3,3,1,42]

	,[6,6,45,46]
	,[312,2,3,4,5]
	,[312,3,4,5,6,43]
	
	,[1,1,3,3,5,5,7,7]
	,[48,7,8,7,8,47]
	,[311,312,317,318, 41, 47, 1, 8]
	
	,[3,4,5,6,7,7,6,5,4,3]
	,[1,8,2,7,3,6,4,5,41,42,43,44,45,46,47,48]
	,[42,4,44,6,46,8,8,8,8,47,311,312,313,314,315,316,317,318]
	
	# BLAKE VER END
	]


var current_sequence_index := 0
var current_wave := 0
var success := false
var wave_ending := false
var player_failed := false
var force_shop_open := false
var in_display_text_prompt := false
var player_can_progress := false

# Set the instant we hit three strikes. Blocks any further state
# transitions so nothing already "in flight" (awaits, etc.) can push
# the round machine forward after the game is over.
var game_over_triggered := false

var bullet_active := false
var bullet_active_counter := 0.0

var orange_active := 0

var transitioning_worlds := false
var pineapple_mode := false
@export var current_round := 0


@export var player : Player
@export var scene_transition_screen : Control 
@export var shop_main_menu : Control
@export var tally_menu : Control
@export var round_timer : RoundTimer
@export var place_name : Control
@export var rocks_container: RockManager
@export var music_manager : Node
@export var birds : Node3D
@export var balloon_container : Node3D
@export var blue_balloon : Node3D
@export var level_layout : Node3D
@export var wave_progress_indication : Control
@export var wave_progress_feedback : Control


var egg_pulse : Egg

enum RoundState {
	INACTIVE,
	CHECK_EVENTS,
	SHOP_START,
	SHOP_END,
	ROUND_START,
	WAVE_START,
	WAVE_END,
	BONUS_ROUND,
	ROUND_END,
	CHECK_SCORE,
	TALLY_START,
	TALLY_END,
	PAUSE,
	RESUME,
	GAME_WON,
	START_START
	}

@export var current_round_state : RoundState = RoundState.INACTIVE
var bonus_oranges_ready := false


func _ready() -> void:
	EventBus.instance.all_rocks_destroyed.connect(successful_round)
	EventBus.instance.rocks_cleared_end_wave.connect(check_if_rocks_still_in_air)
	EventBus.instance.bonus_oranges.connect(bonus_oranges)
	
	EventBus.instance.has_hit_three_strikes.connect(handle_three_strikes)
	EventBus.instance.add_strike.connect(handle_rock_missed)
	#EventBus.instance.hazard_hit.connect(handle_rock_missed)
	move_to_start()
	
func bonus_oranges() -> void:
	bonus_oranges_ready = true

	
func check_round_for_strikes() -> void:
	current_round = current_sequence_index + 1
	wave_progress_feedback.reset_strikes()
	gl_PlayerState.dataset.total_current_strikes = 0


func handle_rock_missed() -> void:
	wave_progress_feedback.add_strike()
	check_if_rocks_still_in_air()
	
	

# Three strikes = instant loss. This short-circuits the round/wave state
# machine entirely rather than routing through WAVE_END/ROUND_END.
func handle_three_strikes() -> void:
	wave_ending = true
	player_failed = true
	success = false

	stop_timer()
	stop_player()
	
	
	await get_tree().create_timer(0.3, false).timeout
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	wave_progress_feedback.start_miss()
	wave_ending = true
	unsuccessful_round_locked()

func check_if_rocks_still_in_air() -> void:
	if wave_ending:
		return

	if gl_PlayerState.dataset.total_rocks_in_round_remaining > 0:
		return

	wave_ending = true
	stop_timer()
	enter_state(RoundState.WAVE_END)

func successful_round() -> void:
	if wave_ending:
		return
	wave_ending = true

	wave_progress_feedback.start_perfect()

	success = true
	$Gold_sfx.play()
	$Gold_sfx.pitch_scale += 0.05
	enter_state(RoundState.WAVE_END)

func unsuccessful_round() -> void:
	if wave_ending:
		return

	wave_progress_feedback.start_miss()
	wave_ending = true
	unsuccessful_round_locked()




func unsuccessful_round_locked() -> void:
	stop_timer()
	player_failed = true
	force_shop_open = true
	success = false
	EventBus.instance.end_round_rock_missed.emit()
	%Splash_zone.deactivate_splash_zone()
	enter_state(RoundState.WAVE_END)


func round_timer_time_out() -> void:
	if wave_ending:
		return
	wave_ending = true

	stop_timer()


	success = true
	enter_state(RoundState.WAVE_END)

	

func check_prompts() -> void:
	if current_sequence_index >= current_rock_sequence.size():
		start_game_over()
		return
	

func enter_state(new_state: RoundState) -> void:
	if transitioning_worlds or game_over_triggered:
		return
		
	current_round_state = new_state
	
	match new_state:
		RoundState.INACTIVE:
			update_round_inactive()
		
		RoundState.CHECK_EVENTS:
			update_check_events()
		
		RoundState.SHOP_START:
			update_shop_start()
		
		RoundState.SHOP_END:
			update_shop_end()
		
		RoundState.ROUND_START:
			update_round_start()
		
		RoundState.WAVE_START:
			update_wave_start()
		
		RoundState.WAVE_END:
			update_wave_end()
		
		RoundState.BONUS_ROUND:
			update_bonus_round()
		
		RoundState.ROUND_END:
			update_round_end()
		
		RoundState.CHECK_SCORE:
			update_check_score()
		
		RoundState.TALLY_START:
			update_tally_start()
		
		RoundState.TALLY_END:
			update_tally_end()
		
		RoundState.PAUSE:
			update_pause()
		
		RoundState.RESUME:
			update_resume()
		
		RoundState.GAME_WON:
			update_game_won()
			
		RoundState.START_START:
			update_start_menu()
			
func update_start_menu() -> void:
	%Start_menu_shop_clone.open_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Gold_sfx.pitch_scale = 0.7
	rocks_container.reset_all_rocks()
	check_round_for_strikes()
	# Add Balloons from Array into the Level during the SHOP phase
	if current_round > 0:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			balloon_container.add_balloon(rock_seq)

func update_round_inactive() -> void:
	rocks_container.enter_state(rocks_container.State.INACTIVE)

func update_check_events() -> void:
	check_prompts()
	
	while in_display_text_prompt:
		await get_tree().process_frame


func update_round_start() -> void:
	# Check for any prompts
	check_prompts()
	
	while in_display_text_prompt:
		await get_tree().process_frame
	
	# Reset variables for a fresh round
	success = false
	player_failed = false
	bonus_oranges_ready = false
	current_wave = 0
	gl_PlayerState.dataset.bonus_cash_this_round = 20
	gl_PlayerState.next_round() # This is placed here to prevent going to round 1 
	
	# If we are in the starting world, don't continue further
	if gl_PlayerState.dataset.level_name == 'start':
		return
		
	# Start playing the level's music
	if current_round == 1:
		music_manager.first_round()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	wave_progress_feedback.reset()
	
	player.update_player_stats()
	music_manager.shop_music_raise_volume()
	enter_state(RoundState.WAVE_START)
	

func update_wave_start() -> void:
	wave_progress_feedback.start()
	
	
	await get_tree().create_timer(0.1, false).timeout
	
	if gl_PlayerState.dataset.total_current_strikes >= 3:
		wave_progress_feedback.start_miss()
		unsuccessful_round_locked()
		return
	
	current_wave += 1
	
	rocks_container.enter_state(rocks_container.State.ROUND_END)

	await get_tree().create_timer(0.1, false).timeout

	gl_PlayerState.next_wave()

	if current_wave == 1:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			rocks_container.start_manual_rock_round(rock_seq)
		
	else:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			rocks_container.shuffle_current_sequence(rock_seq)

	player.start_player()

	if current_wave == 1:
		round_timer.enter_state(round_timer.State.RESTARTING)
	else:
		round_timer.timer_rollup_sequence()

	await get_tree().create_timer(0.75, false).timeout
		
	if egg_pulse:
		egg_pulse.activate_pulse_wave()

	wave_ending = false   # only now can a wave-end signal be accepted
	
	await get_tree().create_timer(1.9, false).timeout
	
	EventBus.instance.egg_pulsed.emit()
	
func update_wave_end() -> void:
	enter_state(RoundState.CHECK_SCORE)
	
func update_bonus_round() -> void:
	pass

func update_check_score() -> void:
	if current_wave >= 3 or force_shop_open:
		enter_state(RoundState.ROUND_END)
	else:
		enter_state(RoundState.WAVE_START)

func update_rock_sequence() -> Array:
	if current_rock_sequence.is_empty():
		return []
		
	if current_sequence_index >= current_rock_sequence.size():
		return []
	
	return current_rock_sequence[current_sequence_index].duplicate()



func update_round_end() -> void:
	# Capture the round outcome now - `success` gets reset to false further
	# down before we need to act on it again.
	stop_timer()
	if gl_PlayerState.dataset.total_current_strikes < 3:
		success = true
	var round_was_successful := success

	await get_tree().create_timer(0.25, false).timeout
	music_manager.shop_music_lower_volume()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)

	while bullet_active:
		await get_tree().process_frame
		bullet_active_counter += 1.0
		if bullet_active_counter > 60.0:
			bullet_active = false
	bullet_active_counter = 0.0
	
	# Only check PASS/PERFECT if the round wasn't cut short by a failure
	if round_was_successful:
		player_can_progress = true

		perfect_score_feedback()
				
		if gl_PlayerState.dataset.total_current_strikes <= 0:

			wave_progress_feedback.start_bonus()
			
			player.round_finished(false)
			pineapple_mode = true
			
			pineapple_round()
			while pineapple_mode:
				await get_tree().process_frame
	
	
	EventBus.instance.oranges_start_falling.emit()
	await get_tree().create_timer(1.0, false).timeout
	
	if player_failed:
		bonus_oranges_ready = false
		
	if bonus_oranges_ready:
		$'../BonusOranges'.start_bonus_oranges()
		
	while bonus_oranges_ready:
		await get_tree().process_frame
	
	
	
	while orange_active > 0 && success:
		await get_tree().process_frame
	
		
	orange_active = 0
		
	if gl_PlayerState.dataset.power_bonus_round_pineapples > 0:
		EventBus.instance.pineapple_round_used.emit()
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0

	force_shop_open = false
	success = false
	pineapple_mode = false

	if current_sequence_index >= current_rock_sequence.size():
		start_game_over()
		return

	stop_player()

	if round_was_successful:
		current_sequence_index += 1
		player_can_progress = false
		shop_main_menu.mark_round_as_perfect()
		shop_main_menu.increase_round_available()
		birds.start_birds()

	current_wave = 0
	balloon_container.end_round()
	enter_state(RoundState.TALLY_START)


func update_tally_start() -> void:
	EventBus.instance.open_tally_card.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_tally_end() -> void:
	if !player_failed:
		gl_PlayerState.add_cash(gl_PlayerState.dataset.bonus_cash)
	
	check_prompts()
	
	while in_display_text_prompt:
		await get_tree().process_frame
	
	enter_state(RoundState.SHOP_START)

	
func update_shop_start() -> void:
	EventBus.instance.open_shop.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Gold_sfx.pitch_scale = 0.7
	rocks_container.reset_all_rocks()
	check_round_for_strikes()
	# Add Balloons from Array into the Level during the SHOP phase
	if current_round > 0:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			balloon_container.add_balloon(rock_seq)
	
func update_shop_end() -> void:
	update_check_events()
	enter_state(RoundState.ROUND_START)


func update_pause() -> void:
	if round_timer:
		round_timer.enter_state(round_timer.State.PAUSE_TIMER)


func update_resume() -> void:
	if round_timer:
		round_timer.enter_state(round_timer.State.RESUME_TIMER)

func update_game_won() -> void:
	stop_timer()
	music_manager.game_won()
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
	gl_PlayerState.dataset["reroll_unlocked"] = 1
	gl_PlayerState.dataset["round"] = 1
	music_manager.stop_opening_song()
	
	
	
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0, false).timeout
	
	if level_layout.get_child(0) != null:
		level_layout.get_child(0).queue_free()

	rocks_container.show()
	var level_scenery = LEVEL_LAYOUT_01_MOSS.instantiate()
	level_layout.add_child(level_scenery)
	
	level_scenery.name = 'current_level_layout'
	
	await get_tree().create_timer(1.0, false).timeout
	shop_main_menu.setup_shop_for_rounds()
	wave_progress_feedback.show()
	if egg_pulse == null:
		find_egg()
	
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	
	#if current_round == 0:
	$'../PlayerBalloon'.add_balloon()
		
	gl_PlayerState.dataset.tickets += 1
	shop_main_menu.update_next_ticket()
		
	await get_tree().create_timer(3.0, false).timeout
	transitioning_worlds = false
	
	current_round = 1
	enter_state(RoundState.SHOP_START)
	
	
func move_to_redd() -> void:
	transitioning_worlds = true
	player.hide_hud()
	gl_PlayerState.dataset["rock_limit"] = 1
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0, false).timeout

	level_layout.get_child(0).queue_free()
	
	var new_scene = LEVEL_LAYOUT_02_REDD.instantiate()
	level_layout.add_child(new_scene)
	
	new_scene.name = 'current_level_layout'
	
	await get_tree().create_timer(1.0, false).timeout
	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	if egg_pulse == null:
		find_egg()

	await get_tree().create_timer(1.0, false).timeout
	transitioning_worlds = false
	enter_state(RoundState.SHOP_END)
	player.display_hud()

	
func stop_player() -> void:
	player.stop_player()



func stop_timer() -> void:
	round_timer.stop_timer()

func find_egg() -> void:
	egg_pulse = get_tree().get_first_node_in_group('Egg_Cage')

func perfect_score_feedback() -> void:
	player.perfect_score()

func pineapple_round() -> void:
	stop_timer()
	$"../Pineapple".start_bonus_round()
	
	while gl_PlayerState.dataset.total_pineapples_destroyed < 3 and pineapple_mode:
		await get_tree().process_frame

	if player_failed:
		$'../Pineapple'.stop_pineapples()
		EventBus.instance.pineapple_round_used.emit()
		return
		
	if gl_PlayerState.dataset.total_pineapples_destroyed > 2:

		%PerfectPineappleRound.play(0.5)
		pineapple_mode = false
	
	else:
		pineapple_mode = false
	
	$'../Pineapple'.stop_pineapples()
	EventBus.instance.pineapple_round_used.emit()


func start_game_over() -> void:
	var game_over_menu = get_tree().get_first_node_in_group('game_over_screen')
	if game_over_menu:
		game_over_menu.update_open_menu()
	else:
		print('cannot find game over')
		
	player.stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func restart() -> void:
	current_sequence_index = 0
	current_round = 0
	current_wave = 0
	force_shop_open = false
	
	
	# Runtime state
	wave_ending = false
	bullet_active = false
	bullet_active_counter = 0.0

	transitioning_worlds = false
	pineapple_mode = false
	success = false
	game_over_triggered = false

	# Reset state machine
	current_round_state = RoundState.INACTIVE

	# Reset music/timer/player
	stop_timer()
	stop_player()

	move_to_moss()

	player.round_finished(false)
	player.display_hud()
	player.update_player_stats()

	# Reset UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Reset scenery
	rocks_container.hide()
	birds.start_birds()


	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('backward'):
		enter_state(RoundState.TALLY_START)
#func _input(event: InputEvent) -> void:
	#if Input.is_key_label_pressed(KEY_8):
		#unsuccessful_round()
#
	#if Input.is_key_label_pressed(KEY_7):
		#successful_round()
		#
	#if Input.is_key_label_pressed(KEY_6) && !success:
		#success = true
		#shop_main_menu.mark_round_as_perfect()
		#
		#shop_main_menu.increase_round_available()
		#
		#current_wave = 3
		#successful_round()
