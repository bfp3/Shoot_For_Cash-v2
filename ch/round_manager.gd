extends Node
class_name RoundManager

const LEVEL_LAYOUT_000_JETZ = preload("uid://ceklxgxfwiv1t")
const LEVEL_LAYOUT_00_OPENING_SCENE = preload('uid://88s7u86w4lfr')
const LEVEL_LAYOUT_01_MOSS = preload('uid://bc6weh2tp6rox')
const LEVEL_LAYOUT_02_REDD = preload('uid://bbpjw4jqdvt5g')
const LEVEL_LAYOUT_03_GLORY = preload('uid://cu16ohrbbd3rb')
const LEVEL_LAYOUT_04_NOIR = preload("res://sc/All_level_layouts/level_layout_04_noir.tscn")
const LEVEL_LAYOUT_05_VESPER = preload("res://sc/All_level_layouts/level_layout_05_vesper.tscn")

#const LEVEL_LAYOUT_03_GLORY = preload('uid://b3gni42s8751h')



const LEVEL_FILE_PATH := 'res://sc/island-shipper.txt'
const LEVEL_ISLAND_NAME := 'shipper'
## How often to check the level file for edits while playing (seconds).
const LEVEL_RELOAD_POLL_INTERVAL := 0.35

## Populated from LEVEL_FILE_PATH via Parser — one array of spawn dicts per round.
var current_rock_sequence : Array = []
var _level_file_mtime := 0
var _level_reload_poll_accum := 0.0

## Debug level editor (press D from shop). One-round sandbox under island/range `test`.
var level_editor_menu: Control = null
var level_editor_open := false
var level_editor_test_active := false
var _level_editor_finishing := false
var _saved_rock_sequence: Array = []
var _saved_sequence_index := 0
var _saved_player_round := 0
var _saved_current_round := 0

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

## Per-range progress so swapping Moss ↔ Redd restores where you left off.
## Keys are level ids (`moss`, `redd`); values are { sequence_index, round }.
var _level_progress: Dictionary = {}

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
@export var bonus_target_manager : Node3D
@export var level_layout : Node3D
@export var wave_progress_indication : Control
@export var wave_progress_feedback : Control


var egg_pulse : Egg

## When true, missed rocks in the active round do not award strikes (`no-lives` keyword).
var no_lives_this_round := false
## Active bonus subtype from the level file (`protect`, etc.). Empty = normal round.
var bonus_type_this_round := ""
## Bonus target was destroyed during `bonus-type1` — no bonus cash, still advance.
var protect_bonus_failed := false
## Scene default for Rocks.randomize_later_waves (restored when `shuffle` is off).
var _rocks_randomize_baseline := false
var _rocks_randomize_baseline_captured := false

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
	load_level_sequence()
	_capture_rocks_randomize_baseline()
	# Pull any disk-persisted range progress into the runtime cache.
	var stored = gl_PlayerState.dataset.get('level_progress', {})
	if stored is Dictionary:
		_level_progress = (stored as Dictionary).duplicate(true)

	EventBus.instance.all_rocks_destroyed.connect(successful_round)
	EventBus.instance.rocks_cleared_end_wave.connect(check_if_rocks_still_in_air)
	EventBus.instance.bonus_oranges.connect(bonus_oranges)
	
	EventBus.instance.has_hit_three_strikes.connect(handle_three_strikes)
	EventBus.instance.add_strike.connect(handle_rock_missed)
	#EventBus.instance.hazard_hit.connect(handle_rock_missed)
	move_to_start()


func _capture_rocks_randomize_baseline() -> void:
	if _rocks_randomize_baseline_captured:
		return
	if rocks_container:
		_rocks_randomize_baseline = rocks_container.randomize_later_waves
		_rocks_randomize_baseline_captured = true


## Apply or clear the per-round `shuffle` keyword on RockManager.
func _apply_shuffle_modifier(enabled: bool) -> void:
	_capture_rocks_randomize_baseline()
	if rocks_container == null:
		return
	if enabled:
		rocks_container.randomize_later_waves = true
		print('RoundManager: shuffle active for this round only')
	else:
		rocks_container.randomize_later_waves = _rocks_randomize_baseline


func _process(delta: float) -> void:
	_level_reload_poll_accum += delta
	if _level_reload_poll_accum < LEVEL_RELOAD_POLL_INTERVAL:
		return
	_level_reload_poll_accum = 0.0
	reload_level_if_changed()


func _level_file_abs_path() -> String:
	return ProjectSettings.globalize_path(LEVEL_FILE_PATH)


func _read_level_file_mtime() -> int:
	return int(FileAccess.get_modified_time(_level_file_abs_path()))


## Reloads island-shipper.txt when it has been saved on disk.
func reload_level_if_changed() -> bool:
	if level_editor_test_active:
		return false
	var mtime := _read_level_file_mtime()
	if mtime == 0:
		return false
	if mtime == _level_file_mtime and not current_rock_sequence.is_empty():
		return false
	load_level_sequence()
	return true


func register_level_editor(menu: Control) -> void:
	level_editor_menu = menu


## Open level editor from shop / start menu (debug). Soft-closes menus without starting a round.
## Returns true if the editor opened (caller should consume the toggle key).
func open_level_editor_from_shop() -> bool:
	if not OS.is_debug_build():
		return false
	if level_editor_test_active or level_editor_open:
		return false
	if level_editor_menu == null:
		push_warning("RoundManager: level editor menu missing")
		return false

	var start_menu := get_tree().get_first_node_in_group("start_menu_ui") as Control
	var shop_open := shop_main_menu != null and shop_main_menu.visible
	var start_open := start_menu != null and start_menu.visible

	# Prefer shop / start menu, but also allow when already in a shop-phase state.
	if not shop_open and not start_open:
		if current_round_state != RoundState.SHOP_START and current_round_state != RoundState.INACTIVE:
			return false

	level_editor_open = true
	if shop_open and shop_main_menu.has_method("soft_hide_for_level_editor"):
		shop_main_menu.soft_hide_for_level_editor()
	elif shop_open:
		shop_main_menu.hide()
	if start_open:
		if start_menu.has_method("sfx_close_shop"):
			start_menu.sfx_close_shop()
		start_menu.hide()
		if "current_state" in start_menu:
			start_menu.current_state = start_menu.State.INACTIVE

	level_editor_menu.open_menu()
	return true


## BACK from editor → resume shop without advancing the round.
func exit_level_editor_to_shop() -> void:
	level_editor_open = false
	if level_editor_menu and level_editor_menu.has_method("close_menu"):
		level_editor_menu.close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if shop_main_menu and shop_main_menu.has_method("soft_show_from_level_editor"):
		shop_main_menu.soft_show_from_level_editor()
	elif shop_main_menu:
		EventBus.instance.open_shop.emit()


## Parse editor text as island test / range test / round, then play that one round.
func begin_level_editor_test(text: String) -> void:
	if not OS.is_debug_build():
		return
	if level_editor_test_active or _level_editor_finishing:
		return

	var round_data: Dictionary = Parser.parse_round_text(text)
	var spawns: Array = round_data.get("spawns", [])
	var is_bonus_only = (
		String(round_data.get("bonus", "")) != ""
		or not round_data.get("bonus_targets", []).is_empty()
	)
	if spawns.is_empty() and not is_bonus_only:
		push_warning("Level editor: no spawn commands parsed — returning to editor")
		level_editor_open = true
		if level_editor_menu:
			level_editor_menu.open_menu()
		return

	_saved_rock_sequence = current_rock_sequence.duplicate(true)
	_saved_sequence_index = current_sequence_index
	_saved_player_round = int(gl_PlayerState.dataset.round)
	_saved_current_round = current_round

	current_rock_sequence = [round_data]
	current_sequence_index = 0
	current_wave = 0
	current_round = 1
	level_editor_open = false
	level_editor_test_active = true
	_reset_level_editor_round_runtime()

	print("Level editor: starting test round (bonus=%s, targets=%d, repeat=%s, spawns=%d)" % [
		str(round_data.get("bonus", "")),
		int(round_data.get("bonus_targets", []).size()),
		str(round_data.get("repeat", 3)),
		int(spawns.size()),
	])

	# Shop balloons aren't added during editor tests — spawn this round's balloons now.
	# Clear any leftovers from the shop / previous test first (`add_balloon` early-outs if started).
	if balloon_container:
		if balloon_container.started or balloon_container.balloons_in_play > 0:
			await balloon_container.end_round()
		await balloon_container.add_balloon(round_data.get("spawns", []))

	enter_state(RoundState.SHOP_END)


## Clear leftovers from the previous test so the next TEST doesn't instantly fail
## (e.g. total_current_strikes still at 3 — tests skip the shop SHOP_START reset).
func _reset_level_editor_round_runtime() -> void:
	force_shop_open = false
	wave_ending = false
	player_failed = false
	success = false
	game_over_triggered = false
	bullet_active = false
	bullet_active_counter = 0.0
	bonus_oranges_ready = false
	orange_active = 0
	pineapple_mode = false
	bonus_type_this_round = ""
	protect_bonus_failed = false

	gl_PlayerState.round_finished = false
	gl_PlayerState.dataset.total_current_strikes = 0
	gl_PlayerState.dataset.total_rocks_in_round = 0
	gl_PlayerState.dataset.total_rocks_in_round_remaining = 0
	gl_PlayerState.dataset.total_white_rocks = 0
	gl_PlayerState.dataset.total_rocks_destroyed = 0
	gl_PlayerState.dataset.total_hazards = 0

	if wave_progress_feedback and wave_progress_feedback.has_method("reset_strikes"):
		wave_progress_feedback.reset_strikes()
	if rocks_container:
		rocks_container.reset_all_rocks()
	if player and player.has_method("begin_level_editor_ammo"):
		player.begin_level_editor_ammo()


## Backspace during a test round — abort and return to the editor with text kept.
func abort_level_editor_test() -> void:
	if not level_editor_test_active or _level_editor_finishing:
		return
	print("Level editor: aborting test round (Backspace)")
	wave_ending = true
	force_shop_open = true
	player_failed = true
	success = false
	stop_timer()
	stop_player()
	if player and player.has_method("end_level_editor_ammo"):
		player.end_level_editor_ammo()
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
	enter_state(RoundState.ROUND_END)


func _restore_level_editor_sequence() -> void:
	current_rock_sequence = _saved_rock_sequence
	current_sequence_index = _saved_sequence_index
	current_round = _saved_current_round
	gl_PlayerState.dataset.round = _saved_player_round
	_saved_rock_sequence = []


## End of a level-editor test round (success, fail, or abort) → editor, not tally/shop.
func finish_level_editor_test_round() -> void:
	if _level_editor_finishing:
		return
	_level_editor_finishing = true

	stop_timer()
	stop_player()
	music_manager.shop_music_lower_volume()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()

	# Drop any oranges still in play so they don't carry into the next test.
	if orange_active > 0:
		EventBus.instance.oranges_start_falling.emit()
		var orange_wait := 0.0
		while orange_active > 0 and orange_wait < 3.0:
			await get_tree().process_frame
			orange_wait += get_process_delta_time()
		orange_active = 0

	await get_tree().create_timer(0.2, false).timeout

	while bullet_active:
		await get_tree().process_frame
		bullet_active_counter += 1.0
		if bullet_active_counter > 60.0:
			bullet_active = false
	bullet_active_counter = 0.0

	force_shop_open = false
	success = false
	pineapple_mode = false
	player_failed = false
	wave_ending = false
	current_wave = 0
	bonus_oranges_ready = false
	orange_active = 0
	game_over_triggered = false
	no_lives_this_round = false
	bonus_type_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
	gl_PlayerState.dataset.total_current_strikes = 0
	gl_PlayerState.round_finished = false
	if wave_progress_feedback and wave_progress_feedback.has_method("reset_strikes"):
		wave_progress_feedback.reset_strikes()

	# Fly remaining test balloons away (same end-of-round exit as normal play).
	if balloon_container:
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method('cleanup_bonus_round'):
		bonus_target_manager.cleanup_bonus_round()

	_restore_level_editor_sequence()
	level_editor_test_active = false
	if player and player.has_method("end_level_editor_ammo"):
		player.end_level_editor_ammo()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_round_state = RoundState.SHOP_START
	level_editor_open = true
	_level_editor_finishing = false

	if level_editor_menu:
		level_editor_menu.open_menu()
	else:
		exit_level_editor_to_shop()


## Active shooting range key used when parsing LEVEL_FILE_PATH.
func get_active_range_name() -> String:
	var range_id := String(gl_PlayerState.dataset.level_name).to_lower()
	if range_id == '' or range_id == gl_DataSet.get_start_place_name() or range_id == 'start':
		return gl_DataSet.get_default_range_name()
	return gl_DataSet.resolve_place_name(range_id)


func load_level_sequence() -> void:
	if not Parser.loadIslandFile(LEVEL_FILE_PATH):
		push_error('RoundManager: failed to load level file %s' % LEVEL_FILE_PATH)
		current_rock_sequence = []
		return

	var previous_count := current_rock_sequence.size()
	var range_id := get_active_range_name()
	current_rock_sequence = Parser.get_rock_sequences(LEVEL_ISLAND_NAME, range_id)
	_level_file_mtime = _read_level_file_mtime()

	if current_rock_sequence.is_empty():
		push_warning('RoundManager: level file loaded but produced no rounds for range "%s".' % range_id)
	else:
		# Only rewind if the level file lost rounds (index past the end).
		# index == size means the range is fully cleared — keep that.
		if current_sequence_index > current_rock_sequence.size():
			current_sequence_index = current_rock_sequence.size()

		if previous_count > 0:
			print('RoundManager: reloaded %s range "%s" (%d rounds) — next wave/shop uses the new data.' % [
				LEVEL_FILE_PATH,
				range_id,
				current_rock_sequence.size(),
			])

func bonus_oranges() -> void:
	bonus_oranges_ready = true

	
func check_round_for_strikes() -> void:
	current_round = current_sequence_index + 1
	wave_progress_feedback.reset_strikes()
	gl_PlayerState.dataset.total_current_strikes = 0


## Reads round modifiers like `no-lives` / `bonus-type1` / `shuffle` from the active sequence entry only.
func apply_current_round_modifiers() -> void:
	no_lives_this_round = false
	bonus_type_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
	if current_rock_sequence.is_empty():
		return
	if current_sequence_index < 0 or current_sequence_index >= current_rock_sequence.size():
		return
	var round_data = current_rock_sequence[current_sequence_index]
	if round_data is Dictionary:
		bonus_type_this_round = String(round_data.get('bonus', ''))
		no_lives_this_round = bool(round_data.get('no_lives', false)) or bonus_type_this_round != ""
		_apply_shuffle_modifier(bool(round_data.get('shuffle', false)))
		if no_lives_this_round:
			print('RoundManager: no-lives active for this round only')
		if bonus_type_this_round != "":
			print('RoundManager: bonus-%s active for this round' % bonus_type_this_round)


func is_current_round_no_lives() -> bool:
	return no_lives_this_round


func is_bonus_type1_round() -> bool:
	return bonus_type_this_round == 'type1'


## Bonus target destroyed — end the wave early with no bonus cash (still progress the round).
func on_bonus_type1_failed() -> void:
	if protect_bonus_failed or wave_ending:
		return
	protect_bonus_failed = true
	wave_ending = true
	stop_timer()
	stop_player()
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
	# Not a strike-out: player still advances after round end.
	success = true
	player_failed = false
	force_shop_open = false
	enter_state(RoundState.WAVE_END)


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


## Player shot the early-exit target — bail out of the round and reopen the shop.
## Does not advance the round sequence or mark progress.
func abort_round_to_shop() -> void:
	if wave_ending or game_over_triggered or transitioning_worlds:
		return
	if current_round_state == RoundState.SHOP_START or current_round_state == RoundState.INACTIVE:
		return

	wave_ending = true
	player_failed = true
	force_shop_open = false
	success = false

	stop_timer()
	stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()

	if balloon_container:
		balloon_container.end_round()

	music_manager.shop_music_lower_volume()
	current_wave = 0
	bullet_active = false

	enter_state(RoundState.SHOP_START)


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
	apply_current_round_modifiers()
	
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
	if force_shop_open or _level_editor_finishing:
		return
	
	if gl_PlayerState.dataset.total_current_strikes >= 3:
		wave_progress_feedback.start_miss()
		unsuccessful_round_locked()
		return
	
	current_wave += 1
	
	rocks_container.enter_state(rocks_container.State.ROUND_END)

	await get_tree().create_timer(0.1, false).timeout
	if force_shop_open or _level_editor_finishing:
		return

	if current_wave == 1 and is_bonus_type1_round() and bonus_target_manager:
		if bonus_target_manager.has_method('begin_bonus_round'):
			var targets: Array = []
			if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
				var round_data = current_rock_sequence[current_sequence_index]
				if round_data is Dictionary:
					targets = round_data.get('bonus_targets', [])
			bonus_target_manager.begin_bonus_round(targets)

	gl_PlayerState.next_wave()

	if current_wave == 1:
		var rock_seq := update_rock_sequence()
		# Always prepare (even empty) so bonus-type1 target-only rounds don't hang on old rock state.
		rocks_container.start_manual_rock_round(rock_seq)
		
	else:
		var rock_seq := update_rock_sequence()
		rocks_container.shuffle_current_sequence(rock_seq)

	player.start_player()

	if current_wave == 1:
		round_timer.enter_state(round_timer.State.RESTARTING)
	else:
		round_timer.timer_rollup_sequence()

	await get_tree().create_timer(0.75, false).timeout
	if force_shop_open or _level_editor_finishing:
		return
		
	if egg_pulse:
		egg_pulse.activate_pulse_wave()

	wave_ending = false   # only now can a wave-end signal be accepted
	
	await get_tree().create_timer(1.9, false).timeout
	if force_shop_open or _level_editor_finishing:
		return
	
	EventBus.instance.egg_pulsed.emit()
	
func update_wave_end() -> void:
	enter_state(RoundState.CHECK_SCORE)
	
func update_bonus_round() -> void:
	pass

func update_check_score() -> void:
	if current_wave >= get_current_round_wave_count() or force_shop_open:
		enter_state(RoundState.ROUND_END)
	else:
		enter_state(RoundState.WAVE_START)


## Waves for the active round — built from `repeat` sections (see parser).
func get_current_round_wave_count() -> int:
	const DEFAULT_WAVES := 1
	if current_rock_sequence.is_empty():
		return DEFAULT_WAVES
	if current_sequence_index >= current_rock_sequence.size():
		return DEFAULT_WAVES

	var round_data = current_rock_sequence[current_sequence_index]
	if round_data is Dictionary:
		var waves = round_data.get('waves', [])
		if waves is Array and not waves.is_empty():
			return waves.size()
		return maxi(int(round_data.get('repeat', DEFAULT_WAVES)), 1)

	return DEFAULT_WAVES


func update_rock_sequence() -> Array:
	# Pick up any saves that landed between poll ticks.
	reload_level_if_changed()

	if current_rock_sequence.is_empty():
		return []
		
	if current_sequence_index >= current_rock_sequence.size():
		return []

	var round_data = current_rock_sequence[current_sequence_index]
	var source: Array = []
	if round_data is Dictionary:
		var waves = round_data.get('waves', [])
		if waves is Array and not waves.is_empty():
			# current_wave is 1-based during play; 0 before the first WAVE_START.
			var wave_idx := clampi(maxi(current_wave - 1, 0), 0, waves.size() - 1)
			source = waves[wave_idx]
		else:
			source = round_data.get('spawns', [])
	elif round_data is Array:
		source = round_data
	else:
		return []

	# Deep-copy spawn dicts so wave shuffles don't mutate the level data.
	var copy: Array = []
	for entry in source:
		if entry is Dictionary:
			copy.append(entry.duplicate())
		else:
			copy.append(entry)
	return copy



func update_round_end() -> void:
	if level_editor_test_active:
		if is_bonus_type1_round() and bonus_target_manager and bonus_target_manager.has_method('resolve_bonus_round'):
			var survived := not protect_bonus_failed and not player_failed
			bonus_target_manager.resolve_bonus_round(survived)
		await finish_level_editor_test_round()
		return

	# Capture the round outcome now - `success` gets reset to false further
	# down before we need to act on it again.
	stop_timer()
	if gl_PlayerState.dataset.total_current_strikes < 3:
		success = true
	var round_was_successful := success

	if is_bonus_type1_round() and bonus_target_manager and bonus_target_manager.has_method('resolve_bonus_round'):
		var survived := not protect_bonus_failed and round_was_successful and not player_failed
		bonus_target_manager.resolve_bonus_round(survived)

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
	# Protect bonus rounds skip the post-round pineapple perfect bonus.
	if round_was_successful and not is_bonus_type1_round():
		player_can_progress = true

		perfect_score_feedback()
				
		if gl_PlayerState.dataset.total_current_strikes <= 0:

			wave_progress_feedback.start_bonus()
			
			player.round_finished(false)
			pineapple_mode = true
			
			pineapple_round()
			while pineapple_mode:
				await get_tree().process_frame
	elif round_was_successful:
		player_can_progress = true
	
	
	EventBus.instance.oranges_start_falling.emit()
	await get_tree().create_timer(1.0, false).timeout
	
	if player_failed:
		bonus_oranges_ready = false
		
	if bonus_oranges_ready and not is_bonus_type1_round():
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
	bonus_type_this_round = ""
	protect_bonus_failed = false

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
		_save_level_progress()

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
	
	# Level-complete screen owns the next step — don't also open the shop underneath it.
	if game_over_triggered:
		return
	enter_state(RoundState.SHOP_START)

	
func update_shop_start() -> void:
	no_lives_this_round = false
	bonus_type_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
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


## Smooth return to the title screen (no scene reload / Wormfood intro).
func return_to_title() -> void:
	if transitioning_worlds:
		return
	transitioning_worlds = true

	# Soft-close open menus.
	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method('soft_hide_for_level_editor'):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()
			if "current_state" in shop_main_menu:
				shop_main_menu.current_state = shop_main_menu.SkillState.INACTIVE
	var start_clone := get_node_or_null("%Start_menu_shop_clone") as Control
	if start_clone == null:
		start_clone = get_tree().get_first_node_in_group("start_menu_ui") as Control
	if start_clone and start_clone.visible:
		start_clone.hide()
		if "current_state" in start_clone:
			start_clone.current_state = start_clone.State.INACTIVE

	var map_menu := get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu is CanvasItem and (map_menu as CanvasItem).visible:
		if map_menu.has_method("close_pop_up"):
			map_menu.close_pop_up()

	stop_timer()
	stop_player()
	force_shop_open = false
	wave_ending = false
	player_failed = false
	success = false
	game_over_triggered = false
	current_wave = 0
	current_sequence_index = 0
	current_round = 0
	current_round_state = RoundState.INACTIVE
	# Keep range round progress — rehydrate from player meta after reset_all.

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method('cleanup_bonus_round'):
		bonus_target_manager.cleanup_bonus_round()

	if scene_transition_screen and scene_transition_screen.has_method('set_destination_place'):
		scene_transition_screen.set_destination_place('start')
	if scene_transition_screen:
		await scene_transition_screen.next_level_start()

	gl_PlayerState.reset_all()
	gl_PlayerState.dataset.level_name = 'start'
	# Restore runtime progress cache from persisted meta (not wiped by reset_all).
	var stored = gl_PlayerState.dataset.get('level_progress', {})
	_level_progress = (stored as Dictionary).duplicate(true) if stored is Dictionary else {}

	move_to_start()
	if rocks_container:
		rocks_container.hide()
	if wave_progress_feedback:
		wave_progress_feedback.hide()
	if place_name and place_name.has_method('update_place_name'):
		place_name.update_place_name()

	# Reset shop round buttons to a fresh locked/available baseline.
	if shop_main_menu and shop_main_menu.has_method('sync_rounds_to_progress'):
		shop_main_menu.sync_rounds_to_progress(0, 0)

	if player and player.has_method('title_screen_start'):
		player.title_screen_start()

	# Keep title hidden under the transition until it finishes.
	var scene_mgr := get_tree().get_first_node_in_group('scene_manager')
	var splash: Node = get_node_or_null('../SplashScreenCanvasLayer')
	if splash == null and scene_mgr and is_instance_valid(scene_mgr.get("splash_screen")):
		splash = scene_mgr.splash_screen

	if scene_transition_screen:
		await scene_transition_screen.next_level_finish()

	# Only now — after arriving at start — reveal the title UI.
	if is_instance_valid(splash) and splash.has_method('show_title_ready'):
		await splash.show_title_ready()
	elif is_instance_valid(splash):
		splash.show()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enter_state(RoundState.INACTIVE)
	transitioning_worlds = false


func _layout_for_level(level_id: String) -> PackedScene:
	## Layouts are bound to place_name *index* so renaming entries in
	## gl_DataSet.dataset_string.place_name keeps the same scenery.
	level_id = gl_DataSet.resolve_place_name(level_id)
	var idx := gl_DataSet.get_place_index(level_id)
	match idx:
		0:
			return LEVEL_LAYOUT_01_MOSS
		1:
			return LEVEL_LAYOUT_02_REDD
		2:
			return LEVEL_LAYOUT_03_GLORY
		3:
			return LEVEL_LAYOUT_000_JETZ
		4:
			return LEVEL_LAYOUT_04_NOIR
		5:
			return LEVEL_LAYOUT_05_VESPER
		_:
			return null


func _save_level_progress() -> void:
	var level_id := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	if level_id == '' or level_id == gl_DataSet.get_start_place_name() or level_id == 'start':
		return
	var entry := {
		'sequence_index': current_sequence_index,
		'round': maxi(current_round, 1),
		'player_round': int(gl_PlayerState.dataset.round),
	}
	_level_progress[level_id] = entry
	gl_PlayerState.set_level_progress_entry(level_id, entry)


func _restore_level_progress(level_id: String) -> void:
	level_id = gl_DataSet.resolve_place_name(level_id)
	var saved: Dictionary = _level_progress.get(level_id, {})
	if saved.is_empty():
		saved = gl_PlayerState.get_level_progress_entry(level_id)
	if saved.is_empty():
		# Fully cleared ranges still count as completed even if entry was lost.
		if gl_PlayerState.is_place_completed(level_id) and current_rock_sequence.size() > 0:
			current_sequence_index = current_rock_sequence.size()
			current_round = current_sequence_index
			gl_PlayerState.dataset.round = current_round
			return
		current_sequence_index = 0
		current_round = 1
		gl_PlayerState.dataset.round = 1
		return
	current_sequence_index = int(saved.get('sequence_index', 0))
	current_round = int(saved.get('round', maxi(current_sequence_index + 1, 1)))
	gl_PlayerState.dataset.round = int(saved.get('player_round', current_round))


## Swap scenery + round data for a shooting range. Used for first arrival and mid-run map travel.
func travel_to_level(level_id: String) -> void:
	level_id = gl_DataSet.resolve_place_name(level_id)
	var layout_scene := _layout_for_level(level_id)
	if layout_scene == null:
		push_error('RoundManager: unknown level "%s"' % level_id)
		return
	if transitioning_worlds:
		return

	var start_name := gl_DataSet.get_start_place_name()
	var coming_from_start := String(gl_PlayerState.dataset.level_name).to_lower() == start_name or String(gl_PlayerState.dataset.level_name).to_lower() == 'start'
	var already_here := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name)) == level_id
	if already_here:
		return

	transitioning_worlds = true
	_save_level_progress()

	# Soft-close shop / start menu so nothing fires SHOP_END during the fade.
	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method('soft_hide_for_level_editor'):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()

	stop_timer()
	stop_player()
	force_shop_open = false
	wave_ending = false
	player_failed = false
	success = false
	game_over_triggered = false
	current_wave = 0
	current_round_state = RoundState.INACTIVE

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method('cleanup_bonus_round'):
		bonus_target_manager.cleanup_bonus_round()

	player.display_hud()
	gl_PlayerState.dataset.level_name = level_id

	if coming_from_start:
		gl_PlayerState.dataset['stage'] = 1
		gl_PlayerState.dataset['reroll_unlocked'] = 1
		music_manager.stop_opening_song()

	if scene_transition_screen.has_method('set_destination_place'):
		scene_transition_screen.set_destination_place(level_id)
	scene_transition_screen.next_level_start()
	await get_tree().create_timer(1.0, false).timeout
	if coming_from_start:
		await get_tree().create_timer(1.0, false).timeout

	# Replace level layout under the fade.
	if level_layout.get_child_count() > 0:
		for child in level_layout.get_children():
			child.queue_free()
		await get_tree().process_frame

	rocks_container.show()
	var level_scenery = layout_scene.instantiate()
	level_layout.add_child(level_scenery)
	level_scenery.name = 'current_level_layout'
	# Let Compatibility/Web compile the new layout's pipelines under the fade.
	await get_tree().process_frame
	await get_tree().process_frame

	await get_tree().create_timer(1.0, false).timeout

	load_level_sequence()
	_restore_level_progress(level_id)
	# Only clamp if the level file shrank; keep completed ranges at the end index.
	if current_rock_sequence.size() > 0 and current_sequence_index > current_rock_sequence.size():
		current_sequence_index = current_rock_sequence.size()
	if current_sequence_index >= current_rock_sequence.size() and current_rock_sequence.size() > 0:
		current_round = current_rock_sequence.size()
	else:
		current_round = mini(current_sequence_index + 1, maxi(current_rock_sequence.size(), 1))
	gl_PlayerState.dataset.round = current_round

	shop_main_menu.setup_shop_for_rounds()
	shop_main_menu.sync_rounds_to_progress(current_sequence_index, current_rock_sequence.size())
	shop_main_menu.update_place_label()
	wave_progress_feedback.show()
	find_egg()

	scene_transition_screen.next_level_finish()
	place_name.update_place_name()
	await get_tree().create_timer(1.0, false).timeout

	if coming_from_start:
		var player_balloon := get_node_or_null('../PlayerBalloon')
		if player_balloon and player_balloon.has_method('add_balloon'):
			player_balloon.add_balloon()
		gl_PlayerState.dataset.tickets += 1
		shop_main_menu.update_next_ticket()
		await get_tree().create_timer(3.0, false).timeout

	transitioning_worlds = false
	enter_state(RoundState.SHOP_START)
	player.show_ammo_panel()


## Travel by place name or by index into gl_DataSet.place_name (0, 1, 2, …).
## Replaces move_to_moss / move_to_redd / move_to_glory.
func move_to_new_range(range_id = null) -> void:
	var place := ""
	if range_id == null:
		place = gl_DataSet.get_default_range_name()
	elif typeof(range_id) == TYPE_INT or typeof(range_id) == TYPE_FLOAT:
		place = gl_DataSet.get_place_name(int(range_id))
	else:
		place = gl_DataSet.resolve_place_name(String(range_id))
	if place.is_empty() or place == gl_DataSet.get_start_place_name() or place == "start":
		push_error("RoundManager.move_to_new_range: invalid range %s" % str(range_id))
		return
	await travel_to_level(place)


## Deprecated aliases — prefer move_to_new_range(name_or_index).
func move_to_moss() -> void:
	await move_to_new_range(0)


func move_to_redd() -> void:
	await move_to_new_range(1)


func move_to_glory() -> void:
	await move_to_new_range(2)

	
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
	game_over_triggered = true

	# Lock in full clear immediately (survives title / quit before Close).
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	if current_rock_sequence.size() > 0:
		current_sequence_index = current_rock_sequence.size()
		current_round = current_sequence_index
		gl_PlayerState.dataset.round = current_round
	_save_level_progress()
	gl_PlayerState.mark_place_completed(place)

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
	# Full restartable wipe — keep disk meta; runtime cache reloads from player state.
	var stored = gl_PlayerState.dataset.get('level_progress', {})
	_level_progress = (stored as Dictionary).duplicate(true) if stored is Dictionary else {}
	
	
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

	move_to_new_range(0)

	player.round_finished(false)
	player.display_hud()
	player.update_player_stats()

	# Reset UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Reset scenery
	rocks_container.hide()
	birds.start_birds()


## Debug (Shift+M / Main-lofi): same end-state as travel, with no transition waits.
func debug_restart_to_moss() -> void:
	await debug_restart_to_level(gl_DataSet.get_default_range_name())


func debug_restart_to_level(level_id) -> void:
	if typeof(level_id) == TYPE_INT or typeof(level_id) == TYPE_FLOAT:
		level_id = gl_DataSet.get_place_name(int(level_id))
	else:
		level_id = gl_DataSet.resolve_place_name(String(level_id))
	current_sequence_index = 0
	current_round = 0
	current_wave = 0
	force_shop_open = false
	wave_ending = false
	bullet_active = false
	bullet_active_counter = 0.0
	transitioning_worlds = false
	pineapple_mode = false
	success = false
	game_over_triggered = false
	current_round_state = RoundState.INACTIVE

	stop_timer()
	stop_player()
	player.round_finished(false)
	player.display_hud()
	player.update_player_stats()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	birds.start_birds()

	await move_to_level_instant(level_id)


## Instant default-range setup — everything move_to_new_range(0) does at the end, no fade timers.
func move_to_moss_instant() -> void:
	await move_to_level_instant(gl_DataSet.get_default_range_name())


## Instant range setup by name or index — no fade timers.
func move_to_level_instant(level_id) -> void:
	if typeof(level_id) == TYPE_INT or typeof(level_id) == TYPE_FLOAT:
		level_id = gl_DataSet.get_place_name(int(level_id))
	else:
		level_id = gl_DataSet.resolve_place_name(String(level_id))
	var layout_scene := _layout_for_level(level_id)
	if layout_scene == null:
		push_error('RoundManager: unknown level "%s" for instant travel' % level_id)
		return

	transitioning_worlds = true
	player.display_hud()
	gl_PlayerState.dataset["stage"] = 1
	gl_PlayerState.dataset["reroll_unlocked"] = 1
	gl_PlayerState.dataset["round"] = 1
	gl_PlayerState.dataset["level_name"] = level_id
	music_manager.stop_opening_song()

	# Keep transition overlay off-screen (no slide animation).
	if scene_transition_screen and scene_transition_screen.has_method("_reset_next_level"):
		scene_transition_screen._reset_next_level()

	if level_layout.get_child_count() > 0:
		for child in level_layout.get_children():
			child.queue_free()
		await get_tree().process_frame

	rocks_container.show()
	var level_scenery = layout_scene.instantiate()
	level_layout.add_child(level_scenery)
	level_scenery.name = 'current_level_layout'
	await get_tree().process_frame
	await get_tree().process_frame

	shop_main_menu.setup_shop_for_rounds()
	shop_main_menu.update_place_label()
	wave_progress_feedback.show()
	find_egg()
	place_name.update_place_name()

	var player_balloon := get_node_or_null('../PlayerBalloon')
	if player_balloon and player_balloon.has_method('add_balloon'):
		player_balloon.add_balloon()

	gl_PlayerState.dataset.tickets += 1
	shop_main_menu.update_next_ticket()

	current_sequence_index = 0
	current_round = 1
	load_level_sequence()
	transitioning_worlds = false
	enter_state(RoundState.SHOP_START)

	
func _input(event: InputEvent) -> void:
	if !OS.is_debug_build():
		set_process_input(false)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE and level_editor_test_active:
			abort_level_editor_test()
			get_viewport().set_input_as_handled()
	#if Input.is_action_just_pressed('backward'):
		#enter_state(RoundState.TALLY_START)
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
