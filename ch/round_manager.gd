extends Node
class_name RoundManager

## Level editor is only available inside the Godot editor (never in exported builds).
static func is_level_editor_available() -> bool:
	return OS.has_feature("editor")

## Level scenery paths — loaded on demand (never preload all islands into Main).
## Keep these under sc/All_level_layouts only. Do NOT point at sc/2025_Levels/* giants.
const LAYOUT_PATH_START := "res://sc/All_level_layouts/level_layout_00_start.tscn"
const LAYOUT_PATH_BY_PLACE_INDEX := {
	0: "res://sc/All_level_layouts/level_layout_moss_01.tscn",
	1: "res://sc/All_level_layouts/level_layout_02_redd.tscn",
	2: "res://sc/All_level_layouts/level_layout_03_glory.tscn",
	#3: "res://sc/All_level_layouts/level_layout_000_jetz.tscn",
	3: "res://sc/All_level_layouts/level_layout_hood_01.tscn",
	4: "res://sc/All_level_layouts/level_layout_04_noir.tscn",
	5: "res://sc/All_level_layouts/level_layout_05_vesper.tscn",
}


## Boss arena layouts by overworld island index (0 = Shipper, 1 = Anchor, …).
const LAYOUT_PATH_BOSS_BY_ISLAND := {
	0: "res://sc/All_level_layouts/level_layout_moss_02.tscn",
	1: "res://sc/All_level_layouts/level_layout_moss_03.tscn",
}
## Script ranges that are not in gl_DataSet.place_name (e.g. moss2 in level-beginner.txt).
const LAYOUT_PATH_BY_PLACE_NAME := {
	"moss1": "res://sc/All_level_layouts/level_layout_moss_01.tscn",
	"moss2": "res://sc/All_level_layouts/level_layout_moss_02.tscn",
	"moss3": "res://sc/All_level_layouts/level_layout_moss_03.tscn",
	"moss4": "res://sc/All_level_layouts/level_layout_moss_04.tscn",
	"moss5": "res://sc/All_level_layouts/level_layout_moss_05.tscn",
	"moss6": "res://sc/All_level_layouts/level_layout_moss_06.tscn",
	"moss7": "res://sc/All_level_layouts/level_layout_moss_07.tscn",
	"moss8": "res://sc/All_level_layouts/level_layout_moss_08.tscn",
	"moss9": "res://sc/All_level_layouts/level_layout_moss_09.tscn",
	"moss10": "res://sc/All_level_layouts/level_layout_moss_10.tscn",
	"moss11": "res://sc/All_level_layouts/level_layout_moss_11.tscn",
	"hood": "res://sc/All_level_layouts/level_layout_hood_01.tscn",
	"mine": "res://sc/All_level_layouts/level_layout_mine_01.tscn",
	"kings": "res://sc/All_level_layouts/level_layout_moss_crossy_bridge.tscn"
}


## Camera3D.environment resources per place / boss (layouts no longer carry WorldEnvironment).
const ENV_PATH_BY_LEVEL := {
	"start": "res://res/skyEnvironments/greyscale_world.tres",
	"moss": "res://res/moss_env_v2.tres",
	"moss1": "res://res/moss_env_v2.tres",
	"moss2": "res://res/moss_env_v2.tres",
	"moss3": "res://res/moss_env_v2.tres",
	"moss4": "res://res/moss_env_v2.tres",
	"moss5": "res://res/moss_env_v2.tres",
	"moss6": "res://res/moss_env_v2.tres",
	"moss7": "res://res/moss_env_v2.tres",
	"moss8": "res://res/wireframe_glow_effect.tres",
	"moss9": "res://res/skyEnvironments/boss_2_world_env.tres",
	"moss10": "res://res/skyEnvironments/boss_2_world_env.tres",
	"moss11": "res://res/skyEnvironments/moss_11_illustrated_env.tres",
	
	
	"redd": "res://res/world_env_redd.tres",
	"glory": "res://res/skyEnvironments/Level_simple_art_style.tres",
	"jetz": "res://res/skyEnvironments/greyscale_world.tres",
	"noir": "res://res/start_04_world_env.tres",
	"vesper": "res://res/start_05_world_env.tres",
	"hood": "res://res/skyEnvironments/greyscale_world.tres",
	"mine": "res://mine_temp/mine_sunset_env.tres",
	"kings": "res://res/skyEnvironments/moss_crossy_world_env.tres"
	
}
const ENV_PATH_BY_LAYOUT := {
	LAYOUT_PATH_START: "res://res/skyEnvironments/greyscale_world.tres",
	"res://sc/All_level_layouts/level_layout_mosscr.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_02_redd.tscn": "res://res/world_env_redd.tres",
	"res://sc/All_level_layouts/level_layout_03_glory.tscn": "res://res/skyEnvironments/Level_simple_art_style.tres",
	"res://sc/All_level_layouts/level_layout_000_jetz.tscn": "res://res/skyEnvironments/greyscale_world.tres",
	"res://sc/All_level_layouts/level_layout_04_noir.tscn": "res://res/start_04_world_env.tres",
	"res://sc/All_level_layouts/level_layout_05_vesper.tscn": "res://res/start_05_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_01.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_moss_02.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_moss_03.tscn": "res://res/skyEnvironments/boss_2_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_04.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_moss_05.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_moss_06.tscn": "res://res/moss_env_v2.tres",
	"res://sc/All_level_layouts/level_layout_moss_07.tscn": "res://res/skyEnvironments/boss_2_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_08.tscn": "res://res/skyEnvironments/boss_2_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_09.tscn": "res://res/skyEnvironments/boss_2_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_10.tscn": "res://res/skyEnvironments/boss_2_world_env.tres",
	"res://sc/All_level_layouts/level_layout_moss_11.tscn": "res://res/skyEnvironments/moss_11_illustrated_env.tres",
	"res://sc/All_level_layouts/level_layout_hood.tscn": "res://res/skyEnvironments/greyscale_world.tres",
	"res://sc/All_level_layouts/level_layout_mine_01.tscn": "res://mine_temp/mine_sunset_env.tres",
}


const SCRIPT_LIGHT_STEP := 0.25
const SCRIPT_LIGHT_TWEEN_SEC := 3.0
var _script_light_tween: Tween
var _script_light_base: Dictionary = {}

## Cached PackedScenes so revisiting Moss/Redd/etc. does not re-parse from disk.
var _layout_cache: Dictionary = {} # path -> PackedScene
var _layout_load_requested: Dictionary = {} # path -> true

const LEVEL_FILE_BEGINNER := "res://sc/level-beginner.txt"
const LEVEL_FILE_ADVANCED := "res://sc/level-advanced.txt"
const LEVEL_FILE_EXPERT := "res://sc/level-expert.txt"
const LEVEL_FILE_MYSTERY := "res://sc/level-mystery.txt"
const LEVEL_FILE_CHALLENGE_01 := "res://sc/level-challenge-01.txt"
const LEVEL_FILE_CHALLENGE_02 := "res://sc/level-challenge-02.txt"
const LEVEL_FILE_CHALLENGE_03 := "res://sc/level-challenge-03.txt"
const LEVEL_FILE_CHALLENGE_04 := "res://sc/level-challenge-04.txt"
const LEVEL_FILE_CHALLENGE_05 := "res://sc/level-challenge-05.txt"
const LEVEL_FILE_CHALLENGE_06 := "res://sc/level-challenge-06.txt"

var LEVEL_FILE_PATH := LEVEL_FILE_BEGINNER
const LEVEL_ISLAND_NAME := 'shipper'
## How often to check the level file for edits while playing (seconds).
const LEVEL_RELOAD_POLL_INTERVAL := 0.35

## Populated from LEVEL_FILE_PATH via Parser — one array of spawn dicts per round.
var current_rock_sequence : Array = []
var _level_file_mtime := 0
var _level_reload_poll_accum := 0.0

## Debug level editor (press D from shop). One-round sandbox under island/range `test`.
var level_editor_menu: Control = null
var round_editor_menu: Control = null
var level_editor_open := false
var round_editor_open := false
var level_editor_test_active := false
var _level_editor_finishing := false
## Which editor to reopen after a test round: "level" | "round"
var _editor_test_return := "level"
var _saved_rock_sequence: Array = []
var _saved_sequence_index := 0
var _saved_player_round := 0
var _saved_current_round := 0

var current_sequence_index := 0
var current_wave := 0
var success := false
var wave_ending := false
## True during WAVE_START setup so leftover clear signals cannot WAVE_END
## before the new script has begun. Distinct from `wave_ending`, which also
## makes RockManager treat the round as closing and skip a fresh start.
var _suppress_wave_end := false
var player_failed := false
var force_shop_open := false
var _continue_open := false
var _continue_resuming := false
var _continue_grace := false
var _continue_intro_shown := false
var in_display_text_prompt := false
var player_can_progress := false

## Boss survival mode — one looping round with a fixed timer.
var _boss_mode := false
var _boss_island_index := 0
var _boss_timer_seconds := 120.0
var _boss_looping := false
## After a boss win tally, open the island map instead of the shop.
var _boss_open_map_after_tally := false
## After a non-boss hold-out win tally, travel to the next range in level-beginner.txt.
var _advance_range_after_hold_out := false
## Tally Level Select / NEXT / Replay: leave to the grid, next range, or restart this range.
var _tally_exit_to_level_select := false
var _tally_travel_next_level := false
var _tally_replay_level := false
## After returning from a finished level, reopen the numbered grid instead of Beginner/Advanced/Expert.
var _reopen_on_level_grid := false
## Island whose boss was just cleared — map plays unlock ceremony on this page.
var _boss_ceremony_island := -1
## Optional UI bar driven while a map travel loads a layout (0–100).
var _travel_progress_bar: Range = null
## Glory "6 Shots Only": weapon-fire count this round (not magazine ammo).
var _shots_fired_this_round := 0
const SIX_SHOTS_LIMIT := 6
## Endless (Jetz): keep looping rocks; count-up survival timer.
var _endless_looping := false
var _endless_elapsed_sec := 0.0
var _travel_progress_target := 0.0
var _travel_progress_display := 0.0
## Higher = snappier catch-up while still looking smooth.
@export var travel_progress_smooth_speed := 180.0
## While waiting on load, keep the bar crawling so hitch frames hurt less.
@export var travel_progress_crawl_per_sec := 35.0
@export var travel_progress_crawl_ceiling := 88.0
## false = orange blows black rocks away then they explode (no strike).
## true = orange instantly explodes black rocks for $2 (no fly-off, no fail particles).
@export var orange_black_rock_instant_explode := false
## After shop MapButton → start + map, closing the map should reopen the shop.
var _reopen_shop_after_map := false

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

## Skip the WAVE_START round banner after a checkpoint already showed it.
var _skip_next_wave_banner := false
## True while a checkpoint shot is being processed.
var _rest_balloon_advancing := false
## Resume spawn index inside the current range after a checkpoint was shot.

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

## Title-screen scenery pan (level select). X is world metres on `level_layout`.
@export_group("Title Layout Pan")
@export var layout_pan_beginner_x := 27.0
@export var layout_pan_advanced_x := 54.0
@export var layout_pan_expert_x := 81.0
@export var layout_pan_duration := 0.45
var _layout_pan_tween: Tween


var egg_pulse : Egg

## When true, missed rocks in the active round do not award strikes (`no-lives` keyword).
var no_lives_this_round := false
## Debug chat `no-lives` / `lives` — persists across rounds until toggled off.
var debug_no_lives := false
## Script `ammo-unlimited` — this round only; shots do not consume bullets.
var ammo_unlimited_this_round := false
## `difficulty-easy` / `difficulty-normal` / `difficulty-hard` / `difficulty-expert` for the active range (legacy gravity). Prefer `pace-*` in the script.
var difficulty_this_round := ""

## Active bonus subtype from the level file (`protect`, etc.). Empty = normal round.
var bonus_type_this_round := ""
## Challenge 6 questionnaire — driven by `questionaire/quiz_controller.gd`.
var quiz_this_round := false
var _quiz_active := false
var _quiz_controller: QuizController = null
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
	START_START,
	CONTINUE
	}

@export var current_round_state : RoundState = RoundState.INACTIVE
var bonus_oranges_ready := false


func should_show_ammo_hud() -> bool:
	match current_round_state:
		RoundState.ROUND_START, RoundState.WAVE_START, RoundState.WAVE_END, RoundState.BONUS_ROUND, RoundState.CHECK_SCORE, RoundState.RESUME:
			return true
		_:
			return false


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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("cancel_button"):
		return
	if not _is_actively_playing_round():
		return
	abort_round_to_shop()
	get_viewport().set_input_as_handled()


## True only while a live round/wave is in progress (not shop, tally, map, etc.).
func _is_actively_playing_round() -> bool:
	if wave_ending or game_over_triggered or transitioning_worlds:
		return false
	if level_editor_open or level_editor_test_active:
		return false
	match current_round_state:
		RoundState.ROUND_START, RoundState.WAVE_START, RoundState.WAVE_END, RoundState.BONUS_ROUND, RoundState.CHECK_SCORE:
			return true
		_:
			return false


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
	_update_travel_progress_smooth(delta)
	_level_reload_poll_accum += delta
	if _level_reload_poll_accum < LEVEL_RELOAD_POLL_INTERVAL:
		return
	_level_reload_poll_accum = 0.0
	reload_level_if_changed()


func _level_file_abs_path() -> String:
	return ProjectSettings.globalize_path(LEVEL_FILE_PATH)


func _read_level_file_mtime() -> int:
	return int(FileAccess.get_modified_time(_level_file_abs_path()))


## Reloads level-beginner.txt when it has been saved on disk.
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


func register_round_editor(menu: Control) -> void:
	round_editor_menu = menu


## Open level editor from shop / start menu (debug). Soft-closes menus without starting a round.
## Returns true if the editor opened (caller should consume the toggle key).
func open_level_editor_from_shop() -> bool:
	
	if not is_level_editor_available():
		return false
	
	if level_editor_test_active or level_editor_open or round_editor_open:
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


## Open round editor (Shift+F). Requires being on a range that exists in level-beginner.txt.
## Only the Back button closes it — Shift+F while open does nothing.
func open_round_editor_from_shop() -> bool:
	if not is_level_editor_available():
		return false
	if level_editor_test_active or level_editor_open:
		return false
	if round_editor_open:
		return true
	if round_editor_menu == null:
		push_warning("RoundManager: round editor menu missing")
		return false

	var range_id := get_active_range_name().to_lower()
	var place := String(gl_PlayerState.dataset.level_name).to_lower()
	if place.is_empty() or place == "start" or place == gl_DataSet.get_start_place_name():
		push_warning("Round editor: travel into a range first")
		return false
	if not Parser.file_has_range(LEVEL_FILE_PATH, range_id):
		push_warning("Round editor: range '%s' not found in %s" % [range_id, LEVEL_FILE_PATH])
		return false

	var start_menu := get_tree().get_first_node_in_group("start_menu_ui") as Control
	var shop_open := shop_main_menu != null and shop_main_menu.visible
	var start_open := start_menu != null and start_menu.visible
	if not shop_open and not start_open:
		if current_round_state != RoundState.SHOP_START and current_round_state != RoundState.INACTIVE:
			return false

	round_editor_open = true
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

	round_editor_menu.open_menu()
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


func exit_round_editor_to_shop() -> void:
	round_editor_open = false
	if round_editor_menu and round_editor_menu.has_method("close_menu"):
		round_editor_menu.close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if shop_main_menu and shop_main_menu.has_method("soft_show_from_level_editor"):
		shop_main_menu.soft_show_from_level_editor()
	elif shop_main_menu:
		EventBus.instance.open_shop.emit()


## Round editor: swap scenery to `range_name` without opening the shop.
func debug_editor_travel_to_range(range_name: String) -> void:
	if not is_level_editor_available():
		return
	if transitioning_worlds:
		return
	range_name = range_name.strip_edges().to_lower()
	if range_name.is_empty():
		return
	var keep_editor := round_editor_open
	await travel_to_level(range_name, false)
	round_editor_open = keep_editor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if keep_editor and round_editor_menu and round_editor_menu.has_method("keep_open_after_travel"):
		round_editor_menu.keep_open_after_travel()
	elif keep_editor and round_editor_menu:
		round_editor_menu.show()


## Parse editor text as island test / range test / round, then play that one round.
func begin_level_editor_test(text: String) -> void:
	_editor_test_return = "level"
	await _begin_editor_test_round(text)


func begin_round_editor_test(text: String) -> void:
	_editor_test_return = "round"
	round_editor_open = false
	await _begin_editor_test_round(text)


func _begin_editor_test_round(text: String) -> void:
	if not is_level_editor_available():
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
		_reopen_editor_after_test()
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
	round_editor_open = false
	level_editor_test_active = true
	_reset_level_editor_round_runtime()
	_ensure_gun_equipped_for_map()

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
	_skip_next_wave_banner = false
	_rest_balloon_advancing = false

	gl_PlayerState.round_finished = false
	gl_PlayerState.cash_banked_this_round = 0
	if gl_PlayerState.has_method("reset_range_banked_cash"):
		gl_PlayerState.reset_range_banked_cash()
	gl_PlayerState.dataset.bonus_cash = 0
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
	## Test rounds use the same magazine as play (12) unless the script has `ammo-unlimited`.


## Backspace during a test round — abort and return to the editor with text kept.
func abort_level_editor_test() -> void:
	if not level_editor_test_active or _level_editor_finishing:
		return
	print("Level editor: aborting test round (Backspace)")
	wave_ending = true
	force_shop_open = true
	player_failed = true
	success = false
	pineapple_mode = false
	stop_timer()
	stop_player()
	_bank_round_cash_pool(true)
	_reset_range_banked_after_loss()
	_apply_ammo_unlimited(false)
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
	_continue_open = false
	_continue_resuming = false
	_continue_grace = false
	var continue_screen := get_tree().get_first_node_in_group("continue_screen")
	if continue_screen and continue_screen.has_method("close_now"):
		continue_screen.close_now()
	elif continue_screen:
		continue_screen.hide()

	stop_timer()
	stop_player()
	music_manager.shop_music_lower_volume()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()

	clear_live_oranges_quietly()
	EventBus.instance.oranges_start_falling.emit()

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
	difficulty_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
	_apply_difficulty_runtime()
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
	_apply_ammo_unlimited(false)
	if player and player.has_method("end_level_editor_ammo"):
		player.end_level_editor_ammo()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_round_state = RoundState.SHOP_START
	_level_editor_finishing = false
	_reopen_editor_after_test()


func _reopen_editor_after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _editor_test_return == "round" and round_editor_menu:
		round_editor_open = true
		level_editor_open = false
		round_editor_menu.open_menu()
		return
	if level_editor_menu:
		level_editor_open = true
		round_editor_open = false
		level_editor_menu.open_menu()
		return
	exit_level_editor_to_shop()


## Active shooting range key used when parsing LEVEL_FILE_PATH.
func get_active_range_name() -> String:
	var range_id := String(gl_PlayerState.dataset.level_name).to_lower()
	if _boss_mode:
		return _boss_range_name(_boss_island_index)
	if range_id.begins_with("boss"):
		if range_id == "boss range" or range_id == "boss_range":
			return "boss"
		return range_id
	if range_id == '' or range_id == gl_DataSet.get_start_place_name() or range_id == 'start':
		return gl_DataSet.get_default_range_name()
	return gl_DataSet.resolve_place_name(range_id)


## Next range after `place_id` in the active level file, including `boss-` ranges. Empty if none.
func _next_level_in_script(place_id: String) -> String:
	var cur := gl_DataSet.resolve_place_name(place_id).to_lower()
	if cur.is_empty():
		return ""
	var found := false
	for raw in list_script_levels():
		var name := String(raw).to_lower()
		if found:
			return name
		if name == cur:
			found = true
	return ""


## Ordered playable ranges in the active difficulty file (includes `boss-` prefixes).
func list_script_levels() -> PackedStringArray:
	apply_level_file_for_difficulty()
	var out: PackedStringArray = []
	for raw in Parser.list_ranges_in_file(LEVEL_FILE_PATH):
		var name := String(raw).to_lower()
		if name.is_empty() or name == "start":
			continue
		out.append(name)
	return out


## 1-based index in the active difficulty script (beginner moss2 → 2). 0 if unknown.
func get_script_level_number(place_id: String) -> int:
	var key := gl_DataSet.resolve_place_name(place_id).to_lower()
	if key.is_empty() or key == "start" or key == gl_DataSet.get_start_place_name().to_lower():
		return 0
	var levels := list_script_levels()
	for i in levels.size():
		if String(levels[i]).to_lower() == key:
			return i + 1
	return 0


func has_next_script_level(place_id: String = "") -> bool:
	if place_id.is_empty():
		place_id = String(gl_PlayerState.dataset.level_name)
	return not _next_level_in_script(place_id).is_empty()


## True after the last round of this range, win or lose aside — used to treat the range as a "level".
func is_range_complete_tally() -> bool:
	if player_failed or level_editor_test_active:
		return false
	## Hold-out win is a range clear even if the sequence index has not advanced yet.
	if _advance_range_after_hold_out and not _boss_mode:
		return true
	if current_rock_sequence.is_empty():
		return false
	return current_sequence_index >= current_rock_sequence.size()


func request_tally_level_select() -> void:
	if gl_PlayerState and gl_PlayerState.has_method("get_run_difficulty") and gl_PlayerState.has_method("set_select_difficulty"):
		gl_PlayerState.set_select_difficulty(gl_PlayerState.get_run_difficulty())
	_tally_exit_to_level_select = true
	_tally_travel_next_level = false
	_tally_replay_level = false
	_reopen_on_level_grid = not is_challenge_run()
	enter_state(RoundState.TALLY_END)


## Shop MapButton / tally Level Select: reset the run and reopen the numbered grid for this difficulty.
## Challenge runs return to difficulty select (where the challenge row lives) instead of the Beginner grid.
func return_to_level_select() -> void:
	if gl_PlayerState:
		var stage := "BEGINNER"
		if gl_PlayerState.has_method("get_run_difficulty"):
			stage = String(gl_PlayerState.get_run_difficulty())
		elif gl_PlayerState.has_method("get_select_difficulty"):
			stage = String(gl_PlayerState.get_select_difficulty())
		if gl_PlayerState.has_method("set_select_difficulty"):
			gl_PlayerState.set_select_difficulty(stage)
	_reopen_on_level_grid = not is_challenge_run()
	await return_to_difficulty_select()


func is_challenge_run() -> bool:
	var stage := ""
	if gl_PlayerState and gl_PlayerState.has_method("get_run_difficulty"):
		stage = String(gl_PlayerState.get_run_difficulty())
	elif gl_PlayerState and gl_PlayerState.has_method("get_select_difficulty"):
		stage = String(gl_PlayerState.get_select_difficulty())
	stage = stage.strip_edges().to_upper().replace("_", " ")
	return stage.begins_with("CHALLENGE")


func request_tally_next_level() -> void:
	_tally_travel_next_level = true
	_tally_exit_to_level_select = false
	_tally_replay_level = false
	enter_state(RoundState.TALLY_END)


func request_tally_replay() -> void:
	_tally_replay_level = true
	_tally_exit_to_level_select = false
	_tally_travel_next_level = false
	enter_state(RoundState.TALLY_END)


## Restart the current range from round 1 with no play fee (tally Replay).
func _replay_current_level_from_start() -> void:
	player_failed = false
	success = false
	game_over_triggered = false
	force_shop_open = false
	wave_ending = false
	bullet_active = false
	bullet_active_counter = 0.0
	pineapple_mode = false
	bonus_type_this_round = ""
	protect_bonus_failed = false
	current_wave = 0
	current_sequence_index = 0
	current_round = 1
	gl_PlayerState.dataset.round = 1
	if gl_PlayerState.has_method("reset_range_banked_cash"):
		gl_PlayerState.reset_range_banked_cash()
	check_round_for_strikes()
	if rocks_container:
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if player:
		if player.has_method("refill_starting_ammo_animated"):
			await player.refill_starting_ammo_animated()
		elif player.has_method("refill_starting_ammo"):
			player.refill_starting_ammo(true)
		elif player.has_method("refill_ammo_to_max_animated"):
			await player.refill_ammo_to_max_animated()
		elif player.has_method("refill_ammo_to_max"):
			player.refill_ammo_to_max(true)
		player.round_finished(false)
		player.display_hud()
	if shop_main_menu and shop_main_menu.has_method("sync_rounds_to_progress"):
		shop_main_menu.sync_rounds_to_progress(current_sequence_index, current_rock_sequence.size())
	_save_level_progress()
	enter_state(RoundState.SHOP_END)


func _settle_completed_level() -> void:
	if player_failed or level_editor_test_active:
		return
	if not is_range_complete_tally():
		return
	var place := gl_DataSet.resolve_place_name(get_active_range_name())
	if place.is_empty() or place == "start":
		return
	if gl_PlayerState.has_method("mark_level_cleared"):
		gl_PlayerState.mark_level_cleared(gl_PlayerState.get_run_difficulty(), place)
	if not gl_PlayerState.is_place_completed(place):
		gl_PlayerState.mark_place_completed(place)
		_save_level_progress()


## Next playable range after `place_id` in level-beginner.txt header order. Empty if none.
func _next_range_in_script(place_id: String) -> String:
	var cur := gl_DataSet.resolve_place_name(place_id).to_lower()
	if cur.is_empty():
		return ""
	var found := false
	for raw in Parser.list_ranges_in_file(LEVEL_FILE_PATH):
		var name := String(raw).to_lower()
		if name.is_empty() or name == "start" or name == "boss" or name.begins_with("boss-"):
			continue
		if found:
			return name
		if name == cur:
			found = true
	return ""


## True when `place_id` is the last playable `range` header in level-beginner.txt.
func _is_last_playable_range(place_id: String) -> bool:
	var cur := gl_DataSet.resolve_place_name(place_id).to_lower()
	if cur.is_empty():
		return false
	var last := ""
	for raw in Parser.list_ranges_in_file(LEVEL_FILE_PATH):
		var name := String(raw).to_lower()
		if name.is_empty() or name == "start" or name == "boss" or name.begins_with("boss-"):
			continue
		last = name
	return not last.is_empty() and cur == last


## island 0 → "boss", island 1 → "boss-2", island 2 → "boss-3", …
func _boss_range_name(island_index: int = -1) -> String:
	if island_index < 0:
		island_index = _boss_island_index
	if island_index <= 0:
		return "boss"
	return "boss-%d" % (island_index + 1)


func is_boss_mode() -> bool:
	return _boss_mode


## True for boss arenas and any range/round with `hold out <ms>` in the level script.
func is_hold_out_round() -> bool:
	if _boss_mode:
		return true
	return _get_current_hold_out_ms() > 0


func _hold_out_should_finish_on_pineapples() -> bool:
	if rocks_container == null or not rocks_container.has_method("should_end_hold_out_on_pineapples"):
		return false
	return bool(rocks_container.should_end_hold_out_on_pineapples())


func _get_current_hold_out_ms() -> int:
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var round_data = current_rock_sequence[current_sequence_index]
		if round_data is Dictionary:
			var ms := int(round_data.get("hold_out_ms", 0))
			if ms > 0:
				return ms
	return Parser.get_boss_timer_ms(LEVEL_ISLAND_NAME, get_active_range_name())


func is_endless_mode() -> bool:
	if _boss_mode:
		return false
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name)).to_lower()
	return place == gl_DataSet.get_testing_place_name().to_lower() or place == "jetz" or place == "test"


## Seconds survived in endless mode (for tally). -1 if not endless / no run.
func get_endless_elapsed_seconds() -> float:
	if _endless_elapsed_sec > 0.0:
		return _endless_elapsed_sec
	if not is_endless_mode():
		return -1.0
	if round_timer and round_timer.has_method("get_elapsed_seconds"):
		return float(round_timer.get_elapsed_seconds())
	return 0.0


func _snapshot_endless_elapsed() -> void:
	if not is_endless_mode():
		return
	var t := 0.0
	if round_timer and round_timer.has_method("get_elapsed_seconds"):
		t = float(round_timer.get_elapsed_seconds())
	## Never overwrite a good snapshot with 0 after stop_timer clears count-up.
	if t > _endless_elapsed_sec:
		_endless_elapsed_sec = t


func record_endless_run_result() -> void:
	if not is_endless_mode():
		return
	_snapshot_endless_elapsed()
	var lived := _endless_elapsed_sec
	if lived <= 0.0:
		return
	if gl_PlayerState.has_method("record_endless_best_seconds"):
		gl_PlayerState.record_endless_best_seconds(lived, String(gl_PlayerState.dataset.level_name))


## Seconds for RoundTimer when this round is a hold-out; -1 = use normal power_time_upgrade.
## Endless returns 0 to signal count-up mode (no duration limit).
func get_active_timer_seconds() -> float:
	if is_endless_mode():
		return 0.0
	if is_hold_out_round():
		if _boss_timer_seconds <= 0.0:
			_refresh_boss_timer_from_parser()
		if _boss_timer_seconds > 0.0:
			return _boss_timer_seconds
	return -1.0


## Actual countdown length for the current round (hold-out override or power_time_upgrade).
func get_current_countdown_seconds() -> float:
	if is_endless_mode():
		return 0.0
	var override_sec := get_active_timer_seconds()
	if override_sec > 0.0:
		return override_sec
	if round_timer and float(round_timer.start_time) > 0.0:
		return float(round_timer.start_time)
	return float(gl_DataSet.get_value("power_time_upgrade", gl_PlayerState.dataset.get("power_time_upgrade", 10)))


func _refresh_boss_timer_from_parser() -> void:
	var timer_ms := _get_current_hold_out_ms()
	if timer_ms <= 0 and _boss_mode:
		var range_id := _boss_range_name(_boss_island_index)
		timer_ms = Parser.get_boss_timer_ms(LEVEL_ISLAND_NAME, range_id)
		if timer_ms <= 0 and range_id != "boss":
			## Fallback to classic boss timer if boss-N has none yet.
			timer_ms = Parser.get_boss_timer_ms(LEVEL_ISLAND_NAME, "boss")
		if timer_ms <= 0:
			## Fallback: any island key ending in |boss / |boss-N.
			for key in Parser.boss_timer_ms_by_range.keys():
				var key_s := String(key)
				if key_s.ends_with("|%s" % range_id) or key_s.ends_with("|boss"):
					timer_ms = int(Parser.boss_timer_ms_by_range[key])
					if timer_ms > 0:
						break
		if timer_ms <= 0:
			timer_ms = 120000
	_boss_timer_seconds = float(timer_ms) / 1000.0


func _apply_boss_timer_to_hud() -> void:
	if not is_hold_out_round() or round_timer == null:
		return
	if _boss_timer_seconds <= 0.0:
		_refresh_boss_timer_from_parser()
	round_timer.start_time = _boss_timer_seconds
	round_timer.time_left = _boss_timer_seconds
	if round_timer.has_method("update_text"):
		round_timer.update_text()


func apply_level_file_for_difficulty(stage: String = "") -> void:
	if stage.strip_edges().is_empty() and gl_PlayerState and gl_PlayerState.has_method("get_run_difficulty"):
		stage = String(gl_PlayerState.get_run_difficulty())
	var key := stage.strip_edges().to_upper()
	key = key.replace("[WAVE]", "").replace("[/WAVE]", "")
	key = key.replace("_", " ")
	match key:
		"ADVANCED":
			LEVEL_FILE_PATH = LEVEL_FILE_ADVANCED
		"EXPERT":
			LEVEL_FILE_PATH = LEVEL_FILE_EXPERT
		"MYSTERY", "???":
			LEVEL_FILE_PATH = LEVEL_FILE_MYSTERY
		"CHALLENGE 1", "CHALLENGE1", "CHALLENGE 01":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_01
		"CHALLENGE 2", "CHALLENGE2", "CHALLENGE 02":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_02
		"CHALLENGE 3", "CHALLENGE3", "CHALLENGE 03":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_03
		"CHALLENGE 4", "CHALLENGE4", "CHALLENGE 04":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_04
		"CHALLENGE 5", "CHALLENGE5", "CHALLENGE 05":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_05
		"CHALLENGE 6", "CHALLENGE6", "CHALLENGE 06":
			LEVEL_FILE_PATH = LEVEL_FILE_CHALLENGE_06
		_:
			LEVEL_FILE_PATH = LEVEL_FILE_BEGINNER


func load_level_sequence() -> void:
	apply_level_file_for_difficulty()
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
		## Keep shop round buttons aligned with the live shipper round count.
		if shop_main_menu and shop_main_menu.visible and shop_main_menu.has_method("sync_rounds_to_progress"):
			shop_main_menu.sync_rounds_to_progress(current_sequence_index, current_rock_sequence.size())

	_refresh_boss_timer_from_parser()


## Clear leftover smoke mines when leaving a range; spawn preamble threats only if missing.
func _sync_range_default_threats(force_replace: bool = false) -> void:
	if rocks_container == null:
		return
	var entries: Array = []
	if Parser and Parser.has_method("get_range_threats"):
		entries = Parser.get_range_threats(LEVEL_ISLAND_NAME, get_active_range_name())
	## Fallback: first round dict's default_threats (same range).
	if entries.is_empty() and not current_rock_sequence.is_empty():
		var first = current_rock_sequence[0]
		if first is Dictionary:
			entries = first.get("default_threats", [])
	if rocks_container.has_method("spawn_default_threats"):
		rocks_container.spawn_default_threats(entries, force_replace)
	elif force_replace and rocks_container.has_method("clear_threat_mines"):
		rocks_container.clear_threat_mines()


func bonus_oranges() -> void:
	bonus_oranges_ready = true


## Leftover oranges never hold the round open. Hide and park them with no VFX / cash.
func clear_live_oranges_quietly() -> void:
	if not is_inside_tree():
		orange_active = 0
		return
	var seen: Dictionary = {}
	for container in get_tree().get_nodes_in_group("orange_container"):
		if not is_instance_valid(container):
			continue
		for child in container.get_children():
			_dismiss_orange_node(child, seen)
	for node in get_tree().get_nodes_in_group("orange"):
		_dismiss_orange_node(node, seen)
	orange_active = 0


func _dismiss_orange_node(node: Node, seen: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	if seen.has(node):
		return
	seen[node] = true
	if node.has_method("dismiss_quietly_for_round_end"):
		node.dismiss_quietly_for_round_end()
	elif node.has_method("reset_stats"):
		node.reset_stats()


## Oranges used to share the pineapple group. Never treat them as live pineapples.
func _node_is_orange(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("orange"):
		return true
	var script = node.get_script()
	if script and String(script.resource_path).get_file() == "orange.gd":
		return true
	return String(node.name).begins_with("Orange")

	
func check_round_for_strikes() -> void:
	current_round = current_sequence_index + 1
	wave_progress_feedback.reset_strikes()
	gl_PlayerState.dataset.total_current_strikes = 0
	# Restore this round's strike cap (default 3, or `strikes N` from the script).
	var strikes := 3
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var round_data = current_rock_sequence[current_sequence_index]
		if round_data is Dictionary:
			strikes = int(round_data.get('max_strikes', 3))
	_apply_round_max_strikes(strikes)
	if player and player.has_method("reset_accuracy_streak"):
		player.reset_accuracy_streak()


func _max_strikes() -> int:
	if gl_PlayerState and gl_PlayerState.has_method("get_max_strikes"):
		return gl_PlayerState.get_max_strikes()
	return 3


func get_current_range_round_count() -> int:
	return maxi(current_rock_sequence.size(), 1)


func select_sequence_index(index: int) -> void:
	current_sequence_index = index


## True once this range has been cleared (free play + half reward thereafter).
func is_active_range_beaten() -> bool:
	var place := gl_DataSet.resolve_place_name(get_active_range_name())
	if place.is_empty() or place == "start":
		return false
	if gl_PlayerState.has_method("is_level_cleared"):
		if gl_PlayerState.is_level_cleared(gl_PlayerState.get_run_difficulty(), place):
			return true
	return gl_PlayerState.is_place_completed(place)


## PLAY / continue fee for the current range (`play $100` in the active level file).
## Uses that script amount even when it is $0. Falls back to data_set `price_play_round` when the range has no play line.
func get_current_play_price() -> int:
	var range_id := get_active_range_name()
	if Parser and Parser.has_method("has_play_price") and Parser.has_play_price(LEVEL_ISLAND_NAME, range_id):
		return maxi(int(Parser.get_play_price(LEVEL_ISLAND_NAME, range_id)), 0)
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var round_data = current_rock_sequence[current_sequence_index]
		if round_data is Dictionary and round_data.has("play_price"):
			return maxi(int(round_data.get("play_price", 0)), 0)
	if not current_rock_sequence.is_empty() and current_rock_sequence[0] is Dictionary:
		var first: Dictionary = current_rock_sequence[0]
		if first.has("play_price"):
			return maxi(int(first.get("play_price", 0)), 0)
	return _dataset_play_price()


func _dataset_play_price() -> int:
	if gl_DataSet and gl_DataSet.has_method("get_value"):
		var fallback := int(gl_DataSet.get_value("price_play_round", 0))
		if fallback >= 0:
			return fallback
	return 1


## Range-clear bonus for the current range (`reward $400` in level-beginner).
## Falls back to data_set `range_clear_reward` when the range has no reward line.
## After the range has been beaten once, winnings are half the script amount.
func get_current_range_reward() -> int:
	var reward := 0
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var round_data = current_rock_sequence[current_sequence_index]
		if round_data is Dictionary:
			var from_round := int(round_data.get("reward", 0))
			if from_round > 0:
				reward = from_round
	if reward <= 0 and Parser and Parser.has_method("get_range_reward"):
		var from_range := int(Parser.get_range_reward(LEVEL_ISLAND_NAME, get_active_range_name()))
		if from_range > 0:
			reward = from_range
	if reward <= 0:
		reward = int(gl_DataSet.get_value("range_clear_reward", 0))
	if reward > 0 and is_active_range_beaten():
		return int(reward / 2)
	return reward


## Script `reward $N` for the current range, with no half-after-clear. Used by the tally grade row.
func get_script_range_reward() -> int:
	var range_id := get_active_range_name()
	if Parser and Parser.has_method("has_range_reward") and Parser.has_range_reward(LEVEL_ISLAND_NAME, range_id):
		return maxi(int(Parser.get_range_reward(LEVEL_ISLAND_NAME, range_id)), 0)
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var round_data = current_rock_sequence[current_sequence_index]
		if round_data is Dictionary and round_data.has("reward"):
			return maxi(int(round_data.get("reward", 0)), 0)
	if not current_rock_sequence.is_empty() and current_rock_sequence[0] is Dictionary:
		var first: Dictionary = current_rock_sequence[0]
		if first.has("reward"):
			return maxi(int(first.get("reward", 0)), 0)
	if gl_DataSet and gl_DataSet.has_method("get_value"):
		var fallback := int(gl_DataSet.get_value("range_clear_reward", 0))
		if fallback >= 0:
			return fallback
	return 0


func get_resume_spawn_index() -> int:
	## Mid-script resume is retired — balloon-rest no longer stores a fail-resume cursor.
	return 0


func _clear_player_ammo() -> void:
	_apply_ammo_unlimited(false)
	if player and player.has_method("clear_ammo"):
		player.clear_ammo()
	elif player and "shot_count" in player:
		player.shot_count = 0


func _apply_ammo_unlimited(enabled: bool) -> void:
	ammo_unlimited_this_round = enabled
	if player:
		player.debug_infinite_ammo = enabled


## Editor TEST does not press Play — load the same starting mag as a real round.
func _apply_editor_test_starting_ammo() -> void:
	if not level_editor_test_active:
		return
	if player and player.has_method("end_level_editor_ammo"):
		player.end_level_editor_ammo()
	if player and player.has_method("refill_starting_ammo"):
		player.refill_starting_ammo(false)


## Player shot the balloon-rest: clear strikes and continue the script.
## Does NOT save a mid-script resume point — retries always start from the top.
func on_rest_balloon_shot() -> void:
	if _rest_balloon_advancing or player_failed or game_over_triggered:
		return
	_rest_balloon_advancing = true


	var strike_hud = null
	if wave_progress_feedback and "strike_hud" in wave_progress_feedback:
		strike_hud = wave_progress_feedback.strike_hud

	if strike_hud and strike_hud.has_method("checkpoint_move_to_center"):
		await strike_hud.checkpoint_move_to_center()
	if strike_hud and strike_hud.has_method("checkpoint_clear_struck"):
		await strike_hud.checkpoint_clear_struck()
	if strike_hud and strike_hud.has_method("checkpoint_return_home"):
		await strike_hud.checkpoint_return_home()

	if wave_progress_feedback:
		wave_progress_feedback.strikes_int = 0
		if wave_progress_feedback.strike_label:
			wave_progress_feedback.strike_label.text = ""

	check_round_for_strikes()
	_rest_balloon_advancing = false
	if rocks_container and rocks_container.has_method("flush_pending_ammo"):
		rocks_container.flush_pending_ammo()
	if rocks_container and rocks_container.has_method("end_rest_balloon_hold"):
		rocks_container.end_rest_balloon_hold()


func _is_editor_playtest() -> bool:
	return level_editor_test_active or level_editor_open or round_editor_open


func is_rest_balloon_ceremony() -> bool:
	return _rest_balloon_advancing


func _bank_round_cash_pool(force_wallet: bool = false) -> void:
	if gl_PlayerState and gl_PlayerState.has_method("bank_cash_pool"):
		gl_PlayerState.bank_cash_pool(force_wallet or not _is_editor_playtest())


func _forfeit_round_cash_pool() -> void:
	if gl_PlayerState and gl_PlayerState.has_method("forfeit_cash_pool"):
		gl_PlayerState.forfeit_cash_pool()


## Checkpoint cash is already in the wallet. Clear range HUD counters so the
## next attempt starts Pool and Banked at $0.
func _reset_range_banked_after_loss() -> void:
	if gl_PlayerState and gl_PlayerState.has_method("reset_range_banked_cash"):
		gl_PlayerState.reset_range_banked_cash()




func _show_round_cash_hud() -> void:
	var hud = get_tree().get_first_node_in_group("money_manager")
	if hud and hud.has_method("show_for_round"):
		hud.show_for_round()


func _hide_round_cash_hud() -> void:
	var hud = get_tree().get_first_node_in_group("money_manager")
	if hud and hud.has_method("hide_for_menus"):
		hud.hide_for_menus()


## Reads round modifiers like `no-lives` / `bonus-type1` / `shuffle` / `difficulty-easy` / `strikes N` from the active sequence entry only.
func apply_current_round_modifiers() -> void:
	no_lives_this_round = false
	ammo_unlimited_this_round = false
	bonus_type_this_round = ""
	quiz_this_round = false
	difficulty_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
	_apply_round_max_strikes(3)
	_apply_ammo_unlimited(false)
	if current_rock_sequence.is_empty():
		_apply_difficulty_runtime()
		return
	if current_sequence_index < 0 or current_sequence_index >= current_rock_sequence.size():
		_apply_difficulty_runtime()
		return
	var round_data = current_rock_sequence[current_sequence_index]
	if round_data is Dictionary:
		bonus_type_this_round = String(round_data.get('bonus', ''))
		quiz_this_round = bool(round_data.get('quiz', false)) or not (round_data.get('quiz_questions', []) as Array).is_empty()
		no_lives_this_round = bool(round_data.get('no_lives', false)) or bonus_type_this_round != "" or quiz_this_round
		difficulty_this_round = String(round_data.get('difficulty', '')).to_lower()
		_apply_shuffle_modifier(bool(round_data.get('shuffle', false)))
		_apply_round_max_strikes(int(round_data.get('max_strikes', 3)))
		_apply_ammo_unlimited(bool(round_data.get('ammo_unlimited', false)))
		if no_lives_this_round:
			print('RoundManager: no-lives active for this round only')
		if ammo_unlimited_this_round:
			print('RoundManager: ammo-unlimited active for this round only')
		if bonus_type_this_round != "":
			print('RoundManager: bonus-%s active for this round' % bonus_type_this_round)
		if quiz_this_round:
			print('RoundManager: quiz mode active for this round')
		if difficulty_this_round != "":
			print('RoundManager: difficulty-%s active for this round' % difficulty_this_round)
		var hold_ms := int(round_data.get('hold_out_ms', 0))
		if hold_ms > 0:
			print('RoundManager: hold out %d ms for this round' % hold_ms)
	_apply_difficulty_runtime()
	_refresh_boss_timer_from_parser()


func is_quiz_round() -> bool:
	return quiz_this_round


func set_quiz_active(active: bool) -> void:
	_quiz_active = active


func is_quiz_active() -> bool:
	return _quiz_active


func _ensure_quiz_controller() -> QuizController:
	if _quiz_controller != null and is_instance_valid(_quiz_controller):
		return _quiz_controller
	const QUIZ_CONTROLLER_SCENE := preload("res://questionaire/quiz_controller.tscn")
	_quiz_controller = QUIZ_CONTROLLER_SCENE.instantiate() as QuizController
	if _quiz_controller == null:
		_quiz_controller = QuizController.new()
	_quiz_controller.name = "QuizController"
	add_child(_quiz_controller)
	return _quiz_controller


func _start_quiz_round_if_needed() -> void:
	if not quiz_this_round:
		return
	var round_data: Dictionary = {}
	if current_sequence_index >= 0 and current_sequence_index < current_rock_sequence.size():
		var raw = current_rock_sequence[current_sequence_index]
		if raw is Dictionary:
			round_data = raw
	var quiz := _ensure_quiz_controller()
	quiz.begin(self, rocks_container, round_data)


## After Challenge 6 quiz ends, run the Challenge 4 rock script in the same round.
func begin_post_quiz_rocks() -> void:
	_quiz_active = false
	quiz_this_round = false
	no_lives_this_round = false
	_apply_round_max_strikes(3)
	if rocks_container and rocks_container.has_method("set_quiz_hold"):
		rocks_container.set_quiz_hold(false)

	var spawns := _load_challenge_04_spawns()
	if spawns.is_empty():
		push_warning("RoundManager: post-quiz Challenge 4 spawns empty — ending round")
		successful_round()
		return

	wave_ending = false
	if rocks_container and rocks_container.has_method("start_manual_rock_round"):
		rocks_container.start_manual_rock_round(spawns)
	if player and player.has_method("start_player"):
		player.start_player()
	print("RoundManager: post-quiz — starting Challenge 4 rock sequence (%d cmds)" % spawns.size())


func _load_challenge_04_spawns() -> Array:
	if Parser == null or not Parser.has_method("peek_rock_sequences_from_file"):
		return []
	var range_id := "jetz"
	if has_method("get_active_range_name"):
		range_id = get_active_range_name()
	var sequences: Array = Parser.peek_rock_sequences_from_file(
		LEVEL_FILE_CHALLENGE_04,
		LEVEL_ISLAND_NAME,
		range_id
	)
	if sequences.is_empty():
		sequences = Parser.peek_rock_sequences_from_file(LEVEL_FILE_CHALLENGE_04, "shipper", "jetz")
	if sequences.is_empty():
		return []
	return _flatten_round_spawns(sequences[0])


func _apply_round_max_strikes(count: int) -> void:
	var strikes := maxi(count, 1)
	if gl_PlayerState and gl_PlayerState.has_method("set_max_strikes"):
		gl_PlayerState.set_max_strikes(strikes)
	var strike_hud = null
	if wave_progress_feedback and "strike_hud" in wave_progress_feedback:
		strike_hud = wave_progress_feedback.strike_hud
	if strike_hud != null and strike_hud.has_method("ensure_strike_slots"):
		strike_hud.ensure_strike_slots(strikes)
	if strikes != 3:
		print('RoundManager: strikes %d for this round' % strikes)


func _apply_difficulty_runtime() -> void:
	if rocks_container and rocks_container.has_method("set_difficulty_gravity"):
		rocks_container.set_difficulty_gravity(difficulty_this_round)
	if player == null:
		return
	if difficulty_this_round == "hard" or difficulty_this_round == "expert":
		if player.has_method("set_difficulty_bullet_speed"):
			player.set_difficulty_bullet_speed(0.1)
	elif player.has_method("clear_difficulty_bullet_speed"):
		player.clear_difficulty_bullet_speed()


func is_current_round_no_lives() -> bool:
	return no_lives_this_round or debug_no_lives


func is_bonus_type1_round() -> bool:
	return bonus_type_this_round == 'type1'


func get_active_special_challenge() -> String:
	return gl_DataSet.get_special_challenge(String(gl_PlayerState.dataset.level_name))


func has_active_special_challenge(challenge_id: String) -> bool:
	return gl_DataSet.has_special_challenge(challenge_id, String(gl_PlayerState.dataset.level_name))


## Legacy hook — Glory six-ammo is now a magazine cap on the player (`get_max_ammo`).
## Always allows fire; kept so older call sites stay safe.
func try_register_weapon_shot() -> bool:
	return true


func reset_shots_fired_this_round() -> void:
	_shots_fired_this_round = 0


## Noir (and similar): shooting an orange costs a strike (no bonus cash).
func on_special_challenge_orange_shot() -> void:
	if not has_active_special_challenge("no_shoot_oranges"):
		return
	if player_failed or game_over_triggered:
		return
	gl_PlayerState.add_strike()


## Legacy: scoring a double / multi instantly fills strikes (no longer used by Glory).
func on_special_challenge_double() -> void:
	if not has_active_special_challenge("no_doubles"):
		return
	_fail_special_challenge()


func _fail_special_challenge() -> void:
	if player_failed or game_over_triggered:
		return
	## May fire after rocks clear (wave already ending as a success) — convert to a fail.
	var max_strikes := 3
	if gl_PlayerState and gl_PlayerState.has_method("get_max_strikes"):
		max_strikes = gl_PlayerState.get_max_strikes()
	gl_PlayerState.dataset.total_current_strikes = max_strikes
	success = false
	player_failed = true
	wave_ending = true
	force_shop_open = false
	stop_timer()
	stop_player()
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
	EventBus.instance.has_hit_three_strikes.emit()


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
	if _continue_open or _continue_resuming or _continue_grace:
		return
	wave_progress_feedback.add_strike()
	check_if_rocks_still_in_air()
	
	

# Three strikes = instant loss. This short-circuits the round/wave state
# machine entirely rather than routing through WAVE_END/ROUND_END.
func handle_three_strikes() -> void:
	if _continue_open or _continue_resuming:
		return
	restore_final_round_atmosphere()
	wave_ending = true
	player_failed = true
	success = false

	## Round / level editor tests never use arcade continue — bounce back to the editor.
	if level_editor_test_active:
		stop_timer()
		stop_player()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if rocks_container:
			rocks_container.enter_state(rocks_container.State.ROUND_END)
			rocks_container.reset_all_rocks()
		await finish_level_editor_test_round()
		return

	if music_manager and music_manager.has_method("stop_all_music_immediate"):
		music_manager.stop_all_music_immediate()
	if music_manager and music_manager.has_method("raise_game_over_music"):
		music_manager.raise_game_over_music()
	if rocks_container and rocks_container.has_method("stop_script_sfx_immediate"):
		rocks_container.stop_script_sfx_immediate()

	_continue_open = true
	if round_timer:
		round_timer.enter_state(round_timer.State.PAUSE_TIMER)
	else:
		stop_timer()
	stop_player()
	var resume_in_place := _is_continue_resume_in_place()
	if resume_in_place:
		_freeze_gameplay_for_continue()
	else:
		await _clear_round_entities_for_retry()
	
	var strike_hud = null
	if wave_progress_feedback and "strike_hud" in wave_progress_feedback:
		strike_hud = wave_progress_feedback.strike_hud
	if strike_hud and strike_hud.has_method("wait_until_finale_finished"):
		await strike_hud.wait_until_finale_finished()
	else:
		await get_tree().create_timer(2.0, false).timeout

	if level_editor_test_active:
		_continue_open = false
		_unfreeze_gameplay_for_continue()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _play_strike_finale_return()
		await finish_level_editor_test_round()
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enter_state(RoundState.CONTINUE)

func check_if_rocks_still_in_air() -> void:
	if wave_ending or _suppress_wave_end or _continue_open or _continue_resuming or _continue_grace:
		return
	if _quiz_active:
		return

	if gl_PlayerState.dataset.total_rocks_in_round_remaining > 0:
		return

	if rocks_container and rocks_container.has_method("try_continue_sequence"):
		if rocks_container.try_continue_sequence():
			return
	if rocks_container and rocks_container.has_method("is_holding_wave"):
		if rocks_container.is_holding_wave():
			return

	if is_hold_out_round():
		if _hold_out_should_finish_on_pineapples():
			finish_round_after_last_pineapple()
			return
		## Play-once: script finished and sky clear — win (do not loop rocks).
		_finish_hold_out_success()
		return

	if is_endless_mode():
		_loop_endless_sequence()
		return

	wave_ending = true
	stop_timer()
	enter_state(RoundState.WAVE_END)

func successful_round() -> void:
	if wave_ending or _suppress_wave_end or _continue_open or _continue_resuming or _continue_grace:
		return
	## Quiz ends itself via successful_round / unsuccessful_round_locked when finished.
	if _quiz_active and _quiz_controller != null and _quiz_controller.is_active():
		return
	if rocks_container and rocks_container.has_method("try_continue_sequence"):
		if rocks_container.try_continue_sequence():
			return
	if rocks_container and rocks_container.has_method("is_holding_wave"):
		if rocks_container.is_holding_wave():
			return
	if is_hold_out_round():
		if _hold_out_should_finish_on_pineapples():
			finish_round_after_last_pineapple()
			return
		## Play-once: script finished and sky clear — win (do not loop rocks).
		_finish_hold_out_success()
		return

	if is_endless_mode():
		_loop_endless_sequence()
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




func unsuccessful_round_locked(skip_tally: bool = false) -> void:
	if _quiz_controller != null and _quiz_controller.has_method("stop"):
		_quiz_controller.stop()
	_quiz_active = false
	_snapshot_endless_elapsed()
	record_endless_run_result()
	stop_timer()
	player_failed = true
	_advance_range_after_hold_out = false
	_suppress_wave_end = false
	force_shop_open = true
	success = false
	current_wave = 0
	_clear_player_ammo()
	EventBus.instance.end_round_rock_missed.emit()
	%Splash_zone.deactivate_splash_zone()
	clear_live_oranges_quietly()
	## Stop staggered launches immediately (boss waits can be several seconds).
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container:
		balloon_container.end_round()
	_forfeit_round_cash_pool()
	if skip_tally:
		if gl_PlayerState.has_method("lose_range_banked_cash"):
			gl_PlayerState.lose_range_banked_cash()
		_return_to_shop_after_strikeout()
		return
	enter_state(RoundState.WAVE_END)


## Strike-out: skip the tally card and reopen the shop (same cleanup as a fail).
func _return_to_shop_after_strikeout() -> void:
	force_shop_open = false
	current_wave = 0
	_save_level_progress()
	if music_manager and music_manager.has_method("shop_music_lower_volume"):
		music_manager.shop_music_lower_volume()
	if _boss_mode:
		player_failed = false
		success = false
		current_sequence_index = 0
		wave_ending = false
		check_round_for_strikes()
	stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enter_state(RoundState.SHOP_START)


## Player shot the early-exit target — bail out of the round and reopen the shop.
## Does not advance the round sequence or mark progress.
func abort_round_to_shop() -> void:
	if wave_ending or game_over_triggered or transitioning_worlds:
		return
	if current_round_state == RoundState.SHOP_START or current_round_state == RoundState.INACTIVE:
		return

	if _quiz_controller != null and _quiz_controller.has_method("stop"):
		_quiz_controller.stop()
	_quiz_active = false

	_advance_range_after_hold_out = false
	wave_ending = true
	player_failed = true
	force_shop_open = false
	success = false
	_boss_looping = false
	_suppress_wave_end = false

	stop_timer()
	stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_live_oranges_quietly()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()

	if balloon_container:
		balloon_container.end_round()
	_bank_round_cash_pool(true)
	_reset_range_banked_after_loss()

	music_manager.shop_music_lower_volume()
	current_wave = 0
	bullet_active = false
	_clear_player_ammo()

	enter_state(RoundState.SHOP_START)


func round_timer_time_out() -> void:
	if wave_ending or _continue_open or _continue_resuming or _continue_grace:
		return
	## Pineapple finale owns the end — ignore timer if already running.
	if rocks_container and rocks_container.has_method("is_hold_out_pineapple_finale_active"):
		if bool(rocks_container.is_hold_out_pineapple_finale_active()):
			stop_timer()
			return
	## Timer ran out before script end: still run the pineapple phase if the script has one.
	if rocks_container and rocks_container.has_method("jump_to_pineapple_finale_from_script"):
		if bool(rocks_container.jump_to_pineapple_finale_from_script()):
			return
	_finish_hold_out_success()


## `pineapples` keyword hit: stop the countdown; finale owns the round end.
func begin_pineapple_finale_from_script() -> void:
	clear_live_oranges_quietly()
	if rocks_container and rocks_container.has_method("exit_threat_mines_right_for_pineapple_win"):
		rocks_container.exit_threat_mines_right_for_pineapple_win()
	stop_timer()


## Survive hold-out by timer or by finishing the script (no pineapple finale).
func _finish_hold_out_success() -> void:
	if wave_ending or _continue_open or _continue_resuming or _continue_grace:
		return
	wave_ending = true
	clear_live_oranges_quietly()
	stop_timer()
	await _wait_for_live_pineapples_after_timeout()
	if not _can_finish_after_timer_timeout():
		return
	success = true
	if is_hold_out_round():
		player_failed = false
		if not _boss_mode and not is_endless_mode() and not level_editor_test_active:
			_advance_range_after_hold_out = true
	enter_state(RoundState.WAVE_END)


## Last scripted pineapple of the round is gone and nothing else remains — end now.
func finish_round_after_last_pineapple() -> void:
	if wave_ending or _continue_open or _continue_resuming or _continue_grace:
		return
	if pineapple_mode:
		return
	wave_ending = true
	clear_live_oranges_quietly()
	if rocks_container and rocks_container.has_method("exit_threat_mines_right_for_pineapple_win"):
		rocks_container.exit_threat_mines_right_for_pineapple_win()
	stop_timer()
	await get_tree().create_timer(0.5, false).timeout
	if not _can_finish_after_timer_timeout():
		## Continue / fail already owns the session — don't leave WAVE_END hanging.
		if not _continue_open and not player_failed and not game_over_triggered:
			wave_ending = false
		return
	success = true
	if is_hold_out_round():
		player_failed = false
		if not _boss_mode and not is_endless_mode() and not level_editor_test_active:
			_advance_range_after_hold_out = true
	enter_state(RoundState.WAVE_END)


## Timer hit 0 during a pineapple cue or while one is airborne: wait until it is gone, then 0.5s, then end.
func _wait_for_live_pineapples_after_timeout() -> void:
	if not _any_live_pineapples():
		return
	while _any_live_pineapples() and is_inside_tree():
		if not _can_finish_after_timer_timeout():
			return
		await get_tree().process_frame
	if not _can_finish_after_timer_timeout():
		return
	await get_tree().create_timer(0.5, false).timeout


func _can_finish_after_timer_timeout() -> bool:
	if not is_inside_tree():
		return false
	if game_over_triggered or _continue_open or player_failed:
		return false
	return true


func _any_live_pineapples() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("pineapple_container"):
		if node != null and node.has_method("is_pineapple_in_play") and bool(node.is_pineapple_in_play()):
			return true
	if rocks_container and rocks_container.has_method("any_live_pineapples"):
		if bool(rocks_container.any_live_pineapples()):
			return true
	for node in get_tree().get_nodes_in_group("pineapple"):
		if not is_instance_valid(node):
			continue
		if _node_is_orange(node):
			continue
		if bool(node.get("rock_activated")):
			return true
	return false

	

func check_prompts() -> void:
	if current_sequence_index >= current_rock_sequence.size():
		var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		## Cleared ranges stay playable — clamp onto the last round and continue.
		if gl_PlayerState.is_place_completed(place):
			_clamp_sequence_index_for_replay()


func is_range_clear_win_tally() -> bool:
	if player_failed or _boss_mode or level_editor_test_active:
		return false
	if current_rock_sequence.is_empty():
		return false
	if current_sequence_index < current_rock_sequence.size():
		return false
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	if place.is_empty() or place == "start":
		return false
	return not gl_PlayerState.is_place_completed(place)


## After 100% clear, keep Play working by replaying the last round (or any selected round).
func _clamp_sequence_index_for_replay() -> void:
	if current_rock_sequence.is_empty():
		return
	if current_sequence_index >= current_rock_sequence.size():
		current_sequence_index = current_rock_sequence.size() - 1
	current_round = current_sequence_index + 1
	gl_PlayerState.dataset.round = current_round
	

func enter_state(new_state: RoundState) -> void:
	if transitioning_worlds or game_over_triggered:
		return
	if (_continue_open or _continue_resuming) and new_state != RoundState.CONTINUE:
		match new_state:
			RoundState.WAVE_END, RoundState.CHECK_SCORE, RoundState.ROUND_END, RoundState.TALLY_START, RoundState.TALLY_END, RoundState.SHOP_START:
				return
			_:
				pass
		
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

		RoundState.CONTINUE:
			update_continue()
			
func update_start_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Gold_sfx.pitch_scale = 0.7
	rocks_container.reset_all_rocks()
	check_round_for_strikes()
	# Add Balloons from Array into the Level during the SHOP phase
	if current_round > 0:
		var rock_seq := update_rock_sequence()
		if rock_seq != []:
			balloon_container.add_balloon(rock_seq)

	## Start menu removed from boot flow — open difficulty select instead of the island map.
	_hide_start_menu_ui()
	_ensure_gun_equipped_for_map()
	if player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
	_open_difficulty_select_menu()


func update_continue() -> void:
	_continue_open = true
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var screen: Node = null
	if menus and menus.has_method("ensure_continue"):
		screen = menus.ensure_continue()
	if screen == null:
		screen = get_tree().get_first_node_in_group("continue_screen")
	var fee := 1
	var cash := 0
	if gl_PlayerState.has_method("get_continue_fee"):
		fee = int(gl_PlayerState.get_continue_fee())
	elif has_method("get_current_play_price"):
		fee = int(get_current_play_price())
	if gl_PlayerState.has_method("get_spendable_cash"):
		cash = int(gl_PlayerState.get_spendable_cash())
	else:
		cash = int(gl_PlayerState.dataset.get("cash", 0)) + int(gl_PlayerState.dataset.get("bonus_cash", 0))
	_fade_gameplay_hud_for_continue(false, false, false)
	await _play_continue_loss_scatter()
	if gl_PlayerState.has_method("get_spendable_cash"):
		cash = int(gl_PlayerState.get_spendable_cash())
	else:
		cash = int(gl_PlayerState.dataset.get("cash", 0))
	var outcome := "give_up"
	if screen and screen.has_method("play"):
		outcome = String(await screen.play(fee, cash))
	_continue_open = false
	if outcome == "flip_win":
		## Coin-flip win: still restart the round from the top (no mid-script resume).
		await _play_strike_finale_return()
		await _restart_round_after_continue()
	elif outcome == "paid":
		## Paid continue: replay the round from the start (debt allowed).
		await _play_strike_finale_return()
		await _restart_round_after_continue()
	elif outcome == "level_select":
		await _play_strike_finale_return()
		await return_to_level_select()
	else:
		await _game_over_from_continue()


func _freeze_gameplay_for_continue() -> void:
	if rocks_container and rocks_container.has_method("pause_sequence_for_continue"):
		rocks_container.pause_sequence_for_continue()
	if balloon_container:
		balloon_container.process_mode = Node.PROCESS_MODE_DISABLED
	if has_node("%Splash_zone"):
		%Splash_zone.deactivate_splash_zone()
	_set_group_rigid_bodies_frozen("pineapple", true)
	_set_group_rigid_bodies_frozen("orange", true)


func _unfreeze_gameplay_for_continue() -> void:
	if balloon_container:
		balloon_container.process_mode = Node.PROCESS_MODE_INHERIT
	if rocks_container and rocks_container.has_method("freeze_live_rocks"):
		rocks_container.freeze_live_rocks(false)
	_set_group_rigid_bodies_frozen("pineapple", false)
	_set_group_rigid_bodies_frozen("orange", false)


func _set_group_rigid_bodies_frozen(group_name: String, frozen: bool) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(group_name):
		if node is RigidBody3D:
			(node as RigidBody3D).freeze = frozen
			(node as RigidBody3D).sleeping = frozen


func _is_continue_resume_in_place() -> bool:
	## Mid-script continue is retired — always wipe and restart from the top.
	return false


## Same wipe as abort / backspace: rocks, balloons, pineapples gone for a fresh retry.
func _clear_round_entities_for_retry() -> void:
	if balloon_container:
		balloon_container.process_mode = Node.PROCESS_MODE_INHERIT
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container:
		await balloon_container.end_round()
	if has_node("%Splash_zone"):
		%Splash_zone.deactivate_splash_zone()
	clear_live_oranges_quietly()
	_set_group_rigid_bodies_frozen("pineapple", false)
	_set_group_rigid_bodies_frozen("orange", false)


func _play_continue_loss_scatter() -> void:
	var money := get_tree().get_first_node_in_group("money_manager")
	if money and money.has_method("play_round_loss_scatter"):
		await money.play_round_loss_scatter()
	else:
		_forfeit_round_cash_pool()
	if money and money.has_method("fade_out_for_continue"):
		money.fade_out_for_continue()
	elif money:
		money.hide()


func _play_strike_finale_return() -> void:
	var strike_hud = null
	if wave_progress_feedback and "strike_hud" in wave_progress_feedback:
		strike_hud = wave_progress_feedback.strike_hud
	if strike_hud and strike_hud.has_method("play_finale_return"):
		await strike_hud.play_finale_return()


func _refill_ammo_after_continue() -> void:
	if player == null:
		return
	if player.has_method("refill_starting_ammo_animated"):
		await player.refill_starting_ammo_animated()
	elif player.has_method("refill_starting_ammo"):
		player.refill_starting_ammo(true)
	elif player.has_method("refill_ammo_to_max_animated"):
		await player.refill_ammo_to_max_animated()
	elif player.has_method("refill_ammo_to_max"):
		player.refill_ammo_to_max(true)


func _fade_gameplay_hud_for_continue(visible: bool, include_money: bool = true, include_strikes: bool = true) -> void:
	if visible:
		if player and player.has_method("show_ammo_panel"):
			player.show_ammo_panel()
		if include_strikes and wave_progress_feedback and wave_progress_feedback.has_method("show_strike_hud"):
			wave_progress_feedback.show_strike_hud()
		if include_money:
			var money := get_tree().get_first_node_in_group("money_manager")
			if money and money.has_method("fade_in_for_continue"):
				money.fade_in_for_continue()
			elif money:
				if money.has_method("show_for_round"):
					money.show_for_round()
				else:
					money.show()
		return
	if player and player.has_method("fade_out_ammo_panel"):
		player.fade_out_ammo_panel()
	elif player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
	if include_strikes and wave_progress_feedback and wave_progress_feedback.has_method("hide_strike_hud"):
		wave_progress_feedback.hide_strike_hud()
	if not include_money:
		return
	var money_out := get_tree().get_first_node_in_group("money_manager")
	if money_out and money_out.has_method("fade_out_for_continue"):
		money_out.fade_out_for_continue()
	elif money_out:
		money_out.hide()


func _resume_after_continue() -> void:
	_continue_resuming = true
	wave_ending = true
	check_round_for_strikes()
	player_failed = false
	success = false
	game_over_triggered = false
	force_shop_open = false
	current_round_state = RoundState.WAVE_START
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade_gameplay_hud_for_continue(true)
	await _refill_ammo_after_continue()
	if wave_progress_feedback and wave_progress_feedback.has_method("play_countdown_banners"):
		await wave_progress_feedback.play_countdown_banners(3)
	elif wave_progress_feedback and wave_progress_feedback.has_method("play_named_banner"):
		await wave_progress_feedback.play_named_banner("3")
		await wave_progress_feedback.play_named_banner("2")
		await wave_progress_feedback.play_named_banner("1")
	wave_ending = false
	_unfreeze_gameplay_for_continue()
	var needs_pulse := true
	if rocks_container and rocks_container.has_method("resume_from_continue"):
		needs_pulse = bool(rocks_container.resume_from_continue())
	if needs_pulse and rocks_container:
		rocks_container.enter_state(rocks_container.State.PULSE_ROCKS)
	if player:
		player.start_player()
	if is_hold_out_round() or is_endless_mode():
		if round_timer:
			round_timer.enter_state(round_timer.State.RESUME_TIMER)
	if music_manager and music_manager.has_method("first_round"):
		music_manager.first_round()
	_continue_resuming = false
	_continue_grace = true
	await get_tree().create_timer(1.0, false).timeout
	_continue_grace = false


## Paid continue with `resume_in_place` off: start this range's round from spawn 0.
func _restart_round_after_continue() -> void:
	_continue_resuming = true
	wave_ending = true
	_unfreeze_gameplay_for_continue()
	check_round_for_strikes()
	player_failed = false
	success = false
	game_over_triggered = false
	force_shop_open = false
	bonus_oranges_ready = false
	current_wave = 0
	_shots_fired_this_round = 0
	apply_current_round_modifiers()
	if balloon_container:
		var rock_seq := update_rock_sequence()
		if not rock_seq.is_empty():
			balloon_container.add_balloon(rock_seq)
	if wave_progress_feedback:
		wave_progress_feedback.reset()
	if player:
		player.update_player_stats()
		if player.has_method("ensure_ammo_panel_visible"):
			player.ensure_ammo_panel_visible()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_round_state = RoundState.WAVE_START
	_fade_gameplay_hud_for_continue(true)
	await _refill_ammo_after_continue()
	_skip_next_wave_banner = true
	if music_manager and music_manager.has_method("first_round"):
		music_manager.first_round()
	await update_wave_start()
	_continue_resuming = false
	_continue_grace = true
	await get_tree().create_timer(1.0, false).timeout
	_continue_grace = false


func _game_over_from_continue() -> void:
	_snapshot_endless_elapsed()
	record_endless_run_result()
	_unfreeze_gameplay_for_continue()
	stop_timer()
	if player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
	if wave_progress_feedback and wave_progress_feedback.has_method("hide_strike_hud"):
		wave_progress_feedback.hide_strike_hud()
	var money := get_tree().get_first_node_in_group("money_manager")
	if money and money.has_method("hide_for_menus"):
		money.hide_for_menus()
	await reload_to_boot()


func play_run_over_and_restart() -> void:
	if transitioning_worlds:
		return
	_continue_open = false
	_unfreeze_gameplay_for_continue()
	stop_timer()
	stop_player()
	force_shop_open = false
	wave_ending = false
	game_over_triggered = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu:
		if pause_menu.has_method("close_now"):
			pause_menu.close_now()
		elif pause_menu is CanvasItem:
			(pause_menu as CanvasItem).hide()
	get_tree().paused = false

	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var screen: Node = null
	if menus and menus.has_method("ensure_continue"):
		screen = menus.ensure_continue()
	if screen == null:
		screen = get_tree().get_first_node_in_group("continue_screen")
	if screen and screen.has_method("play_run_loss_overlay"):
		await screen.play_run_loss_overlay()
	await _game_over_from_continue()


func _hide_start_menu_ui() -> void:
	var start_clone := get_node_or_null("%Start_menu_shop_clone") as Control
	if start_clone == null:
		return
	start_clone.hide()
	if "current_state" in start_clone:
		start_clone.current_state = start_clone.State.INACTIVE


func _ensure_gun_equipped_for_map() -> void:
	if int(gl_PlayerState.dataset.get("power_gun", 0)) < 1:
		gl_PlayerState.dataset.power_gun = 1
	if player and player.get("player_gun"):
		## Equip data, but keep the mesh hidden until Play.
		if player.player_gun.has_method("update_guns"):
			player.player_gun.update_guns()
		if player.player_gun.has_method("hide_for_menus"):
			player.player_gun.hide_for_menus()


func _open_difficulty_select_menu() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var select_menu: Node = null
	if menus and menus.has_method("ensure_difficulty_select"):
		select_menu = menus.ensure_difficulty_select()
	if select_menu == null:
		select_menu = get_tree().get_first_node_in_group("difficulty_select")
	if select_menu == null:
		push_warning("RoundManager: difficulty select missing — opening island map")
		_open_island_map_menu()
		return
	if select_menu is CanvasItem:
		(select_menu as CanvasItem).z_index = 41
	CommonCode.apply_ui_overlay_blur()
	var open_levels := _reopen_on_level_grid
	_reopen_on_level_grid = false
	if open_levels:
		var stage := "BEGINNER"
		if gl_PlayerState and gl_PlayerState.has_method("get_select_difficulty"):
			stage = String(gl_PlayerState.get_select_difficulty())
		elif gl_PlayerState and gl_PlayerState.has_method("get_run_difficulty"):
			stage = String(gl_PlayerState.get_run_difficulty())
		var level_menu: Node = null
		if menus and menus.has_method("ensure_level_select"):
			level_menu = menus.ensure_level_select()
		if level_menu == null:
			level_menu = get_tree().get_first_node_in_group("level_select")
		if level_menu == null:
			push_warning("RoundManager: level select missing")
			if select_menu.has_method("open_pop_up"):
				select_menu.open_pop_up()
			return
		if level_menu is CanvasItem:
			(level_menu as CanvasItem).z_index = 41
		if level_menu.has_method("open_pop_up"):
			level_menu.open_pop_up(stage)
		return
	if select_menu.has_method("open_pop_up"):
		select_menu.open_pop_up()
	else:
		push_warning("RoundManager: difficulty select has no open_pop_up()")


func _open_island_map_menu() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var map_menu: Node = null
	if menus and menus.has_method("ensure_ticket_map"):
		map_menu = menus.ensure_ticket_map()
	if map_menu == null:
		map_menu = get_tree().get_first_node_in_group("map_menu")
	if map_menu == null:
		push_warning("RoundManager: MapIslandSelect missing — cannot open island map")
		return
	if map_menu is CanvasItem:
		(map_menu as CanvasItem).z_index = 40
	CommonCode.apply_ui_overlay_blur()
	if map_menu.has_method("open_pop_up"):
		map_menu.open_pop_up()
	else:
		push_warning("RoundManager: MapIslandSelect has no open_pop_up()")


func _open_island_map_after_boss_clear(cleared_island: int) -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var map_menu: Node = null
	if menus and menus.has_method("ensure_ticket_map"):
		map_menu = menus.ensure_ticket_map()
	if map_menu == null:
		map_menu = get_tree().get_first_node_in_group("map_menu")
	if map_menu == null:
		push_warning("RoundManager: MapIslandSelect missing — cannot open island map")
		return
	if map_menu is CanvasItem:
		(map_menu as CanvasItem).z_index = 40
	CommonCode.apply_ui_overlay_blur()
	if map_menu.has_method("open_pop_up_after_boss_clear"):
		await map_menu.open_pop_up_after_boss_clear(cleared_island)
	elif map_menu.has_method("open_pop_up"):
		await map_menu.open_pop_up()
	else:
		push_warning("RoundManager: MapIslandSelect has no open_pop_up()")


func _fade_boss_hud_before_map() -> void:
	var wait_t := 0.0
	if round_timer and round_timer.has_method("fade_out_timer"):
		round_timer.fade_out_timer()
		wait_t = maxf(wait_t, 0.45)
	elif round_timer:
		round_timer.hide()
	if wave_progress_feedback and wave_progress_feedback.has_method("hide_strike_hud"):
		wave_progress_feedback.hide_strike_hud()
		wait_t = maxf(wait_t, 0.35)
	if wait_t > 0.0:
		await get_tree().create_timer(wait_t, false).timeout


## Shop MapButton: return to the start island scenery, then open the map overlay.
func return_to_start_with_map() -> void:
	if transitioning_worlds:
		return
	CommonCode.apply_transition_blur()
	transitioning_worlds = true
	_reopen_shop_after_map = true

	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method("soft_hide_for_level_editor"):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()

	stop_timer()
	stop_player()
	force_shop_open = false
	wave_ending = false
	player_failed = false
	success = false
	_boss_mode = false
	_boss_looping = false
	current_wave = 0
	current_round_state = RoundState.INACTIVE

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()

	gl_PlayerState.dataset.level_name = gl_DataSet.get_start_place_name()
	move_to_start()
	await get_tree().process_frame
	await get_tree().process_frame

	if place_name and place_name.has_method("update_place_name"):
		place_name.update_place_name()

	transitioning_worlds = false
	CommonCode.apply_ui_overlay_blur()
	_open_island_map_menu()


func consume_reopen_shop_after_map() -> bool:
	if not _reopen_shop_after_map:
		return false
	_reopen_shop_after_map = false
	return true

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
	clear_live_oranges_quietly()
	current_wave = 0
	_shots_fired_this_round = 0
	_endless_elapsed_sec = 0.0
	_endless_looping = false
	gl_PlayerState.dataset.bonus_cash_this_round = 20
	gl_PlayerState.next_round() # This is placed here to prevent going to round 1 
	apply_current_round_modifiers()
	_apply_editor_test_starting_ammo()
	_show_round_cash_hud()
	
	# If we are in the starting world, don't continue further
	if gl_PlayerState.dataset.level_name == 'start':
		return
		
	CommonCode.apply_gameplay_blur()
	# Start playing the level's music
	if current_round == 1:
		music_manager.first_round()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	wave_progress_feedback.reset()
	
	player.update_player_stats()
	_apply_difficulty_runtime()
	if player.has_method("ensure_ammo_panel_visible"):
		player.ensure_ammo_panel_visible()
	music_manager.shop_music_raise_volume()
	enter_state(RoundState.WAVE_START)
	

func update_wave_start() -> void:
	## Fresh attempt always starts at the top of the round script (no mid-script resume).
	_suppress_wave_end = true
	var resume_index := 0
	if is_endless_mode():
		## Endless: no wave banners — just keep the strike HUD ready.
		if wave_progress_feedback and wave_progress_feedback.has_method("show_strike_hud"):
			wave_progress_feedback.show_strike_hud()
	elif current_wave == 0 and not _skip_next_wave_banner:
		if resume_index > 0 and wave_progress_feedback and wave_progress_feedback.has_method("play_named_banner"):
			await wave_progress_feedback.play_named_banner("CHECKPOINT")
		else:
			var total := get_current_range_round_count()
			var round_no := current_sequence_index + 1
			if wave_progress_feedback and wave_progress_feedback.has_method("show_round_banner"):
				wave_progress_feedback.show_round_banner(round_no, total)
			else:
				wave_progress_feedback.start()
	_skip_next_wave_banner = false
	
	
	await get_tree().create_timer(0.1, false).timeout
	if force_shop_open or _level_editor_finishing:
		_suppress_wave_end = false
		return
	
	if gl_PlayerState.dataset.total_current_strikes >= _max_strikes():
		_suppress_wave_end = false
		wave_progress_feedback.start_miss()
		unsuccessful_round_locked()
		return
	
	current_wave += 1
	
	rocks_container.enter_state(rocks_container.State.ROUND_END)

	await get_tree().create_timer(0.1, false).timeout
	if force_shop_open or _level_editor_finishing:
		_suppress_wave_end = false
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

	## Allow the rock script to start. `wave_ending` leftover from abort/lose
	## makes RockManager treat the round as closing and skip spawn 0.
	## `_suppress_wave_end` still blocks premature WAVE_END until setup finishes.
	wave_ending = false

	if current_wave == 1:
		if quiz_this_round:
			## Questionnaire owns rock-stay launches; hold the wave open.
			if rocks_container and rocks_container.has_method("set_quiz_hold"):
				rocks_container.set_quiz_hold(true)
			rocks_container.start_manual_rock_round([])
		else:
			var rock_seq := update_rock_sequence()
			# Always prepare (even empty) so bonus-type1 target-only rounds don't hang on old rock state.
			# Mid-script resume is retired — always spawn index 0.
			## Defaults already live from arrival — only ensure they're present.
			_sync_range_default_threats(false)
			rocks_container.start_manual_rock_round(rock_seq, 0)
		
	else:
		var rock_seq := update_rock_sequence()
		rocks_container.shuffle_current_sequence(rock_seq)

	player.start_player()

	if is_hold_out_round():
		_apply_boss_timer_to_hud()
		if current_wave == 1:
			round_timer.enter_state(round_timer.State.RESTARTING)
		else:
			round_timer.timer_rollup_sequence()
	elif is_endless_mode():
		## Count-up survival timer — no time limit.
		if round_timer:
			if round_timer.has_method("start_count_up"):
				round_timer.start_count_up()
			else:
				round_timer.show()
				round_timer.enter_state(round_timer.State.RUNNING)
	else:
		## Regular rounds: keep timer HUD hidden, but play the rollup SFX.
		if round_timer:
			round_timer.hide()
			if round_timer.has_method("rollup_without_timer"):
				round_timer.rollup_without_timer()

	await get_tree().create_timer(0.75, false).timeout
	if force_shop_open or _level_editor_finishing:
		_suppress_wave_end = false
		return
		
	#if egg_pulse:
		#egg_pulse.activate_pulse_wave()

	wave_ending = false   # only now can a wave-end signal be accepted
	_suppress_wave_end = false

	if quiz_this_round:
		_start_quiz_round_if_needed()
		return
	
	await get_tree().create_timer(1.9, false).timeout
	#await get_tree().create_timer(0.8, false).timeout
	
	if force_shop_open or _level_editor_finishing:
		return
	
	play_pulse_sound()
		
	EventBus.instance.egg_pulsed.emit()
	


func play_pulse_sound() -> void:
	$EggPulseSfx.play()
	await get_tree().create_timer(0.1, false).timeout
	$EggPulseSfxReverse.play()
	
	
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
## A range plays as one continuous round; `repeat` sections are flattened in-line.
func get_current_round_wave_count() -> int:
	const DEFAULT_WAVES := 1
	## Endless mode ignores shipper repeats — continuous rock loops instead.
	if is_endless_mode():
		return DEFAULT_WAVES
	if _boss_mode:
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
	return DEFAULT_WAVES


func update_rock_sequence() -> Array:
	# Pick up any saves that landed between poll ticks.
	reload_level_if_changed()

	if current_rock_sequence.is_empty():
		return []
		
	if current_sequence_index >= current_rock_sequence.size():
		return []

	var round_data = current_rock_sequence[current_sequence_index]
	if not (_boss_mode or is_endless_mode()):
		return _flatten_round_spawns(round_data)

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

	return _copy_spawn_list(source)


func _copy_spawn_list(source: Array) -> Array:
	var copy: Array = []
	for entry in source:
		if entry is Dictionary:
			copy.append(entry.duplicate(true))
		else:
			copy.append(entry)
	return copy


## Play a whole range as one script. `repeat` sections stay in order, with
## `wait` (until clear) between copies so the next section cannot overlap.
func _flatten_round_spawns(round_data) -> Array:
	if round_data is Array:
		return _copy_spawn_list(round_data)
	if not (round_data is Dictionary):
		return []
	var waves = round_data.get('waves', [])
	if not (waves is Array) or waves.is_empty():
		return _copy_spawn_list(round_data.get('spawns', []))
	var out: Array = []
	for i in waves.size():
		var wave = waves[i]
		if not (wave is Array):
			continue
		if i > 0:
			var last_cmd := ""
			if not out.is_empty() and out.back() is Dictionary:
				last_cmd = String(out.back().get('cmd', '')).to_lower()
			if last_cmd != 'wait-until-clear':
				out.append({'cmd': 'wait-until-clear'})
		out.append_array(_copy_spawn_list(wave))
	return out



func update_round_end() -> void:
	restore_final_round_atmosphere()
	if _boss_mode:
		await _finish_boss_round()
		return

	if level_editor_test_active:
		if is_bonus_type1_round() and bonus_target_manager and bonus_target_manager.has_method('resolve_bonus_round'):
			var survived := not protect_bonus_failed and not player_failed
			bonus_target_manager.resolve_bonus_round(survived)
		await finish_level_editor_test_round()
		return

	# Capture the round outcome now - `success` gets reset to false further
	# down before we need to act on it again.
	stop_timer()
	if gl_PlayerState.dataset.total_current_strikes < _max_strikes():
		success = true
	var round_was_successful := success

	if is_bonus_type1_round() and bonus_target_manager and bonus_target_manager.has_method('resolve_bonus_round'):
		var survived := not protect_bonus_failed and round_was_successful and not player_failed
		bonus_target_manager.resolve_bonus_round(survived)

	await get_tree().create_timer(0.25, false).timeout
	music_manager.shop_music_lower_volume()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
	## Ambient preamble threats stay put (script mines already cleared in ROUND_END).

	while bullet_active:
		await get_tree().process_frame
		bullet_active_counter += 1.0
		if bullet_active_counter > 60.0:
			bullet_active = false
	bullet_active_counter = 0.0
	
	# Only check PASS/PERFECT if the round wasn't cut short by a failure
	if round_was_successful and not is_bonus_type1_round():
		player_can_progress = true

		perfect_score_feedback()
	elif round_was_successful:
		player_can_progress = true
	
	
	## Leftover oranges do not delay the tally — park them and start the next round clean.
	clear_live_oranges_quietly()
	EventBus.instance.oranges_start_falling.emit()
	
	if player_failed:
		bonus_oranges_ready = false
		
	if bonus_oranges_ready and not is_bonus_type1_round():
		$'../BonusOranges'.start_bonus_oranges()
		
	while bonus_oranges_ready:
		await get_tree().process_frame

	orange_active = 0

	if not round_was_successful:
		_forfeit_round_cash_pool()
		EventBus.instance.pineapple_round_used.emit()
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0

	force_shop_open = false
	success = false
	pineapple_mode = false
	bonus_type_this_round = ""
	protect_bonus_failed = false

	if current_sequence_index >= current_rock_sequence.size():
		var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		if gl_PlayerState.is_place_completed(place):
			_clamp_sequence_index_for_replay()

	stop_player()

	if round_was_successful:
		var played_index := current_sequence_index
		var level_id := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		var prev_frontier := played_index
		if not is_endless_mode():
			var existing: Dictionary = {}
			if _level_progress.has(level_id) and _level_progress[level_id] is Dictionary:
				existing = _level_progress[level_id] as Dictionary
			else:
				existing = gl_PlayerState.get_level_progress_entry(level_id)
			prev_frontier = int(existing.get("sequence_index", played_index))
			## Never regress the frontier on a replay win; only advance when clearing the edge.
			current_sequence_index = maxi(prev_frontier, played_index + 1)
			player_can_progress = false
			shop_main_menu.mark_round_as_perfect(played_index)
			shop_main_menu.increase_round_available(played_index)
			birds.start_birds()
			_save_level_progress()
		else:
			player_can_progress = false
			
	elif player_failed:
		_save_level_progress()

	current_wave = 0
	balloon_container.end_round()
	## Strikeout pause already played on the strike HUD; tally can open.
	enter_state(RoundState.TALLY_START)


func update_tally_start() -> void:
	## Unlock the next numbered badge as soon as the tally exists, and persist it
	## so a quit-and-reload still has that level available.
	_settle_completed_level()
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_tally"):
		menus.ensure_tally()
	CommonCode.apply_ui_overlay_blur()
	if player and player.has_method("fade_out_ammo_panel"):
		player.fade_out_ammo_panel()
	elif player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
	EventBus.instance.open_tally_card.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func update_tally_end() -> void:
	## Remaining pool is already banked on a win, or forfeited on a 3-strike fail.
	if player_failed or int(gl_PlayerState.dataset.total_current_strikes) >= _max_strikes():
		_forfeit_round_cash_pool()
		if gl_PlayerState.has_method("lose_range_banked_cash"):
			gl_PlayerState.lose_range_banked_cash()
		else:
			_reset_range_banked_after_loss()
	else:
		pass
	## Exported builds: checkpoint money / ammo / round frontier / islands after each round.
	if not level_editor_test_active and gl_PlayerState.has_method("save_run_checkpoint_after_round"):
		gl_PlayerState.save_run_checkpoint_after_round()
	
	while in_display_text_prompt:
		await get_tree().process_frame

	if _tally_exit_to_level_select:
		_tally_exit_to_level_select = false
		_tally_travel_next_level = false
		_tally_replay_level = false
		_advance_range_after_hold_out = false
		_settle_completed_level()
		await return_to_difficulty_select()
		return

	if _tally_replay_level:
		_tally_replay_level = false
		_tally_travel_next_level = false
		_advance_range_after_hold_out = false
		_settle_completed_level()
		await _replay_current_level_from_start()
		return

	if _tally_travel_next_level:
		_tally_travel_next_level = false
		_tally_replay_level = false
		_advance_range_after_hold_out = false
		_settle_completed_level()
		var here := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		var next_place := _next_level_in_script(here)
		if next_place.is_empty():
			await return_to_difficulty_select()
			return
		await travel_to_level(next_place)
		return

	## Hold-out no longer auto-advances; tally NEXT / Level Select choose the destination.
	if _advance_range_after_hold_out:
		_advance_range_after_hold_out = false

	## First-time range clear is recorded; last-range no longer dumps to a stage-complete reload.
	if not player_failed and not _boss_mode and not level_editor_test_active:
		var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		if current_rock_sequence.size() > 0 and current_sequence_index >= current_rock_sequence.size():
			if gl_PlayerState.is_place_completed(place):
				_clamp_sequence_index_for_replay()
			else:
				gl_PlayerState.mark_place_completed(place)
				_save_level_progress()
			if gl_PlayerState.has_method("mark_level_cleared"):
				gl_PlayerState.mark_level_cleared(gl_PlayerState.get_run_difficulty(), place)

	# Level-complete screen owns the next step — don't also open the shop underneath it.
	if game_over_triggered:
		return

	## Boss win: fade timer + strikes, then open the island map after the tally.
	if _boss_open_map_after_tally:
		_boss_open_map_after_tally = false
		var ceremony_island := _boss_ceremony_island
		_boss_ceremony_island = -1
		await _fade_boss_hud_before_map()
		enter_state(RoundState.INACTIVE)
		await _open_island_map_after_boss_clear(ceremony_island)
		return

	## Boss loss: reset strikes and return to the boss-arena shop for a retry.
	if _boss_mode:
		player_failed = false
		success = false
		current_wave = 0
		current_sequence_index = 0
		wave_ending = false
		check_round_for_strikes()

	enter_state(RoundState.SHOP_START)

	
func update_shop_start() -> void:
	no_lives_this_round = false
	bonus_type_this_round = ""
	difficulty_this_round = ""
	protect_bonus_failed = false
	_apply_shuffle_modifier(false)
	_apply_difficulty_runtime()
	_clear_player_ammo()
	CommonCode.apply_ui_overlay_blur()
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


func pan_level_layout_for_stage(stage: String, duration: float = -1.0) -> void:
	var x := 0.0
	match stage.strip_edges().to_upper():
		"BEGINNER":
			x = layout_pan_beginner_x
		"ADVANCED":
			x = layout_pan_advanced_x
		"EXPERT":
			x = layout_pan_expert_x
	_tween_level_layout_x(x, layout_pan_duration if duration < 0.0 else duration)


func reset_level_layout_pan(instant: bool = false, duration: float = -1.0) -> void:
	var t := 0.0 if instant else (layout_pan_duration if duration < 0.0 else duration)
	_tween_level_layout_x(0.0, t)


func _tween_level_layout_x(x: float, duration: float) -> void:
	if level_layout == null or not is_instance_valid(level_layout):
		return
	if _layout_pan_tween != null and is_instance_valid(_layout_pan_tween):
		_layout_pan_tween.kill()
		_layout_pan_tween = null
	if duration <= 0.02:
		var pos := level_layout.position
		pos.x = x
		level_layout.position = pos
		return
	_layout_pan_tween = create_tween()
	_layout_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_layout_pan_tween.tween_property(level_layout, "position:x", x, duration)


func move_to_start() -> void:
	reset_level_layout_pan(true)
	if level_layout.get_children().size() > 0:
		level_layout.get_child(0).queue_free()

	# Sync load is fine here — only the start layout, not all islands.
	var layout_scene := _get_cached_layout(LAYOUT_PATH_START)
	if layout_scene == null:
		push_error("RoundManager: failed to load start layout")
		return
	var level_mesh = layout_scene.instantiate()
	var heavy := _detach_heavy_layout_nodes(level_mesh)
	level_layout.add_child(level_mesh)
	level_mesh.name = 'current_level_layout'
	apply_level_environment("start", LAYOUT_PATH_START)
	# Reattach ocean after the body is in the tree (WorldEnvironment is stripped).
	call_deferred("_reattach_heavy_layout_nodes", heavy)


## After a fade-to-black overlay, reload the main scene instead of reconstructing title by hand.
func reload_to_boot() -> void:
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gl_PlayerState.reset_all()
	await get_tree().process_frame
	get_tree().reload_current_scene()


## Return to the title screen as a cold boot: start island, Wormfood intro, Start button.
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
	if start_clone and start_clone.visible:
		start_clone.hide()
		if "current_state" in start_clone:
			start_clone.current_state = start_clone.State.INACTIVE

	var map_menu := get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu is CanvasItem and (map_menu as CanvasItem).visible:
		if map_menu.has_method("close_pop_up"):
			map_menu.close_pop_up()

	# Never leave the level-clear overlay covering the title.
	var game_over_menu = get_tree().get_first_node_in_group("game_over_screen")
	if game_over_menu and game_over_menu is CanvasItem:
		(game_over_menu as CanvasItem).hide()
		if "modulate" in game_over_menu:
			game_over_menu.modulate.a = 1.0
		if "current_state" in game_over_menu:
			game_over_menu.current_state = game_over_menu.State.INACTIVE

	var stage_complete := get_tree().get_first_node_in_group("stage_complete_screen")
	if stage_complete and stage_complete.has_method("close_now"):
		stage_complete.close_now()
	elif stage_complete:
		stage_complete.hide()

	var continue_screen := get_tree().get_first_node_in_group("continue_screen")
	var keep_continue_blackout := continue_screen != null and bool(continue_screen.get("_holding_blackout"))
	if continue_screen and not keep_continue_blackout:
		if continue_screen.has_method("close_now"):
			continue_screen.close_now()
		else:
			continue_screen.hide()

	var diff_select := get_tree().get_first_node_in_group("difficulty_select")
	if diff_select and diff_select.has_method("close_pop_up"):
		diff_select.close_pop_up()
	elif diff_select:
		diff_select.hide()

	var level_select := get_tree().get_first_node_in_group("level_select")
	if level_select and level_select.has_method("close_pop_up"):
		level_select.close_pop_up()
	elif level_select:
		level_select.hide()

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
	if keep_continue_blackout and is_instance_valid(continue_screen):
		if continue_screen.has_method("close_now"):
			continue_screen.close_now()
		else:
			continue_screen.hide()

	gl_PlayerState.reset_all()
	gl_PlayerState.dataset.level_name = 'start'
	apply_level_file_for_difficulty()
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
	if player and player.has_method('hide_ammo_panel_instant'):
		player.hide_ammo_panel_instant()

	# Keep title hidden under the transition until it finishes.
	var scene_mgr := get_tree().get_first_node_in_group('scene_manager')
	var splash: Node = null
	if scene_mgr and is_instance_valid(scene_mgr.get("splash_screen")):
		splash = scene_mgr.splash_screen
	if splash == null and scene_mgr:
		splash = scene_mgr.get_node_or_null("SplashScreenCanvasLayer")

	if scene_mgr and is_instance_valid(scene_mgr.get("main_game_canvas")):
		scene_mgr.main_game_canvas.hide()
	if scene_mgr and "_title_camera_swoop_done" in scene_mgr:
		scene_mgr._title_camera_swoop_done = false
	if scene_mgr and scene_mgr.has_method("apply_title_camera_pose"):
		scene_mgr.apply_title_camera_pose()

	if scene_transition_screen:
		await scene_transition_screen.next_level_finish()

	# Boot-style title: splash CanvasLayer (sibling of gameplay HUD) + Start button.
	if is_instance_valid(splash):
		if splash is CanvasLayer:
			(splash as CanvasLayer).layer = 20
			splash.process_mode = Node.PROCESS_MODE_INHERIT
			splash.visible = true
		if splash.has_method("start"):
			splash.start()
		elif splash.has_method("show_title_ready"):
			splash.show_title_ready()
		else:
			splash.show()
	else:
		# Last resort: back to Quick Start so the player is never soft-locked.
		push_warning("RoundManager: title splash missing — returning to Quick Start")
		get_tree().change_scene_to_file("res://sc/Main-lofi.tscn")
		transitioning_worlds = false
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_round_state = RoundState.INACTIVE
	transitioning_worlds = false


func is_in_active_run() -> bool:
	var level := String(gl_PlayerState.dataset.get("level_name", "")).strip_edges().to_lower() if gl_PlayerState else ""
	var start := "start"
	if gl_DataSet and gl_DataSet.has_method("get_start_place_name"):
		start = String(gl_DataSet.get_start_place_name()).strip_edges().to_lower()
	if not level.is_empty() and level != start and level != "start":
		return true
	match current_round_state:
		RoundState.INACTIVE, RoundState.START_START:
			return false
		_:
			return true


## Shop back → Yes: reset the run and reopen difficulty select on the start layout.
func return_to_difficulty_select() -> void:
	if transitioning_worlds:
		return
	transitioning_worlds = true

	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method("soft_hide_for_level_editor"):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()

	var map_menu := get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu is CanvasItem and (map_menu as CanvasItem).visible:
		if map_menu.has_method("close_pop_up"):
			map_menu.close_pop_up()

	var diff_select := get_tree().get_first_node_in_group("difficulty_select")
	if diff_select and diff_select.has_method("close_pop_up"):
		diff_select.close_pop_up()
	elif diff_select:
		diff_select.hide()

	var level_select := get_tree().get_first_node_in_group("level_select")
	if level_select and level_select.has_method("close_pop_up"):
		level_select.close_pop_up()
	elif level_select:
		level_select.hide()

	var stage_complete := get_tree().get_first_node_in_group("stage_complete_screen")
	if stage_complete and stage_complete.has_method("close_now"):
		stage_complete.close_now()
	elif stage_complete:
		stage_complete.hide()

	var continue_screen := get_tree().get_first_node_in_group("continue_screen")
	if continue_screen and continue_screen.has_method("close_now"):
		continue_screen.close_now()
	elif continue_screen:
		continue_screen.hide()

	stop_timer()
	stop_player()
	force_shop_open = false
	wave_ending = false
	player_failed = false
	success = false
	game_over_triggered = false
	_continue_open = false
	_continue_resuming = false
	_continue_grace = false
	_continue_intro_shown = false
	_boss_mode = false
	_boss_looping = false
	_advance_range_after_hold_out = false
	_tally_exit_to_level_select = false
	_tally_travel_next_level = false
	_tally_replay_level = false
	current_wave = 0
	current_sequence_index = 0
	current_round = 0
	current_round_state = RoundState.INACTIVE

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
		rocks_container.hide()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method("cleanup_bonus_round"):
		bonus_target_manager.cleanup_bonus_round()
	if wave_progress_feedback:
		wave_progress_feedback.hide()

	if scene_transition_screen and scene_transition_screen.has_method("set_destination_place"):
		scene_transition_screen.set_destination_place("start")
	if scene_transition_screen:
		await scene_transition_screen.next_level_start()

	reset_level_layout_pan(true)
	gl_PlayerState.reset_all()
	gl_PlayerState.dataset.level_name = gl_DataSet.get_start_place_name()
	var stored = gl_PlayerState.dataset.get("level_progress", {})
	_level_progress = (stored as Dictionary).duplicate(true) if stored is Dictionary else {}

	move_to_start()
	if place_name and place_name.has_method("update_place_name"):
		place_name.update_place_name()
	if shop_main_menu and shop_main_menu.has_method("sync_rounds_to_progress"):
		shop_main_menu.sync_rounds_to_progress(0, 0)
	if player and player.has_method("hide_ammo_panel_instant"):
		player.hide_ammo_panel_instant()
	if player and player.has_method("title_screen_end"):
		player.title_screen_end()

	var scene_mgr := get_tree().get_first_node_in_group("scene_manager")
	if scene_mgr and is_instance_valid(scene_mgr.get("splash_screen")):
		var splash: Node = scene_mgr.splash_screen
		if splash:
			splash.hide()
	if scene_mgr and is_instance_valid(scene_mgr.get("main_game_canvas")):
		scene_mgr.main_game_canvas.show()

	if scene_transition_screen:
		await scene_transition_screen.next_level_finish()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	transitioning_worlds = false
	enter_state(RoundState.START_START)


## Last-range survival: fade to black, show stage complete, then reload to title.
func _show_stage_complete_and_return_to_title() -> void:
	enter_state(RoundState.INACTIVE)
	stop_timer()
	stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var screen: Node = null
	if menus and menus.has_method("ensure_stage_complete"):
		screen = menus.ensure_stage_complete()
	if screen == null:
		screen = get_tree().get_first_node_in_group("stage_complete_screen")
	var stage_name := "BEGINNER"
	if gl_PlayerState.has_method("get_run_difficulty"):
		stage_name = String(gl_PlayerState.get_run_difficulty())
	elif gl_PlayerState.dataset.get("run_difficulty", "") != "":
		stage_name = String(gl_PlayerState.dataset.run_difficulty)
	var cash := int(gl_PlayerState.dataset.cash)
	if screen and screen.has_method("play"):
		await screen.play(stage_name, cash)
	await reload_to_boot()


func _layout_path_for_level(level_id: String) -> String:
	## Layouts are bound to place_name *index* so renaming entries in
	## gl_DataSet.dataset_string.place_name keeps the same scenery.
	level_id = gl_DataSet.resolve_place_name(level_id)
	var named := String(LAYOUT_PATH_BY_PLACE_NAME.get(level_id.to_lower(), ""))
	if not named.is_empty():
		return named
	var idx := gl_DataSet.get_place_index(level_id)
	if LAYOUT_PATH_BY_PLACE_INDEX.has(idx):
		return String(LAYOUT_PATH_BY_PLACE_INDEX[idx])
	## Unknown / placeholder ranges → testing room layout.
	var jetz_idx := gl_DataSet.get_place_index(gl_DataSet.get_testing_place_name())
	return String(LAYOUT_PATH_BY_PLACE_INDEX.get(jetz_idx, LAYOUT_PATH_BY_PLACE_INDEX.get(3, "")))


func _layout_for_level(level_id: String) -> PackedScene:
	var path := _layout_path_for_level(level_id)
	if path.is_empty():
		return null
	return _get_cached_layout(path)


func _request_layout_load(path: String) -> void:
	if path.is_empty() or _layout_cache.has(path):
		return
	if _layout_load_requested.get(path, false):
		return
	_layout_load_requested[path] = true
	## use_sub_threads=false: true races/crashes on mobile (Godot 4.6).
	var err := ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if err != OK:
		# Fall back to sync path later via _get_cached_layout.
		_layout_load_requested[path] = false


func _get_cached_layout(path: String) -> PackedScene:
	if _layout_cache.has(path):
		return _layout_cache[path] as PackedScene
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed:
		_layout_cache[path] = packed
	return packed


func _await_layout_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if _layout_cache.has(path):
		_set_travel_progress(0.55)
		return _layout_cache[path] as PackedScene

	_request_layout_load(path)
	var waited := 0
	while waited < 600:
		var prog: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, prog)
		if prog.size() > 0:
			## Resource load fills roughly the first half of the travel bar.
			_set_travel_progress(0.05 + clampf(float(prog[0]), 0.0, 1.0) * 0.5)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var packed := ResourceLoader.load_threaded_get(path) as PackedScene
				if packed:
					_layout_cache[path] = packed
					_set_travel_progress(0.55)
					return packed
				break
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			_:
				await get_tree().process_frame
				waited += 1
	_set_travel_progress(0.55)
	return _get_cached_layout(path)


func _set_travel_progress(fraction: float) -> void:
	_travel_progress_target = clampf(fraction, 0.0, 1.0) * 100.0
	if _travel_progress_bar == null or not is_instance_valid(_travel_progress_bar):
		return
	## Instant jump only for the very start / end so the bar never sticks short.
	if _travel_progress_target <= 2.0 or _travel_progress_target >= 99.5:
		_travel_progress_display = _travel_progress_target
		_travel_progress_bar.value = _travel_progress_display


func _clear_travel_progress_bar() -> void:
	if _travel_progress_bar and is_instance_valid(_travel_progress_bar):
		_travel_progress_bar.value = 100.0
	_travel_progress_bar = null
	_travel_progress_target = 0.0
	_travel_progress_display = 0.0


func _update_travel_progress_smooth(delta: float) -> void:
	if _travel_progress_bar == null or not is_instance_valid(_travel_progress_bar):
		return
	## Soft crawl while a real target sits still (threaded load plateaus / long frames).
	var soft_target := _travel_progress_target
	if _travel_progress_target < 99.0 and _travel_progress_display < travel_progress_crawl_ceiling:
		soft_target = maxf(
			_travel_progress_target,
			minf(_travel_progress_display + travel_progress_crawl_per_sec * delta, travel_progress_crawl_ceiling)
		)
	var speed := maxf(travel_progress_smooth_speed, 1.0)
	_travel_progress_display = move_toward(_travel_progress_display, soft_target, speed * delta)
	_travel_progress_bar.value = _travel_progress_display


## Let the bar visually catch up before a hitchy main-thread step (instantiate).
func _await_travel_progress_near(value: float, timeout_sec: float = 0.85) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec and _travel_progress_bar != null and is_instance_valid(_travel_progress_bar):
		if _travel_progress_display >= value - 0.5:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## Pull ocean out before add_child; strip any leftover WorldEnvironment (camera owns env now).
func _detach_heavy_layout_nodes(layout: Node) -> Array:
	var detached: Array = []
	var ocean := layout.get_node_or_null("OutsetOcean")
	if ocean:
		layout.remove_child(ocean)
		detached.append({"parent": layout, "node": ocean})
	## Layouts may still contain WorldEnvironment from older saves — remove so the camera env wins.
	var world_env := layout.get_node_or_null("WorldEnvironment")
	if world_env:
		layout.remove_child(world_env)
		world_env.queue_free()
	## Also strip nested WorldEnvironment under Lighting/, etc.
	_strip_world_environments_recursive(layout)
	return detached


func _strip_world_environments_recursive(node: Node) -> void:
	var to_free: Array[Node] = []
	for child in node.get_children():
		if child is WorldEnvironment:
			to_free.append(child)
		else:
			_strip_world_environments_recursive(child)
	for we in to_free:
		if we.get_parent():
			we.get_parent().remove_child(we)
		we.queue_free()


func _environment_path_for_level(level_id: String, layout_path: String = "") -> String:
	var key := gl_DataSet.resolve_place_name(level_id).to_lower()
	if key.is_empty():
		key = level_id.to_lower()
	if key == "start" or key == gl_DataSet.get_start_place_name().to_lower():
		key = "start"
	if ENV_PATH_BY_LEVEL.has(key):
		return String(ENV_PATH_BY_LEVEL[key])
	if not layout_path.is_empty() and ENV_PATH_BY_LAYOUT.has(layout_path):
		return String(ENV_PATH_BY_LAYOUT[layout_path])
	return String(ENV_PATH_BY_LEVEL.get("moss", "res://res/moss_env_v2.tres"))


## Switch the player Camera3D environment for the destination level.
func apply_level_environment(level_id: String, layout_path: String = "") -> void:
	restore_final_round_atmosphere(false)
	var path := _environment_path_for_level(level_id, layout_path)
	var cam = get_tree().get_first_node_in_group("player_cam")
	if cam and cam.has_method("set_level_environment_from_path"):
		cam.set_level_environment_from_path(path)
	elif cam:
		var env := load(path) as Environment
		if env:
			cam.set("environment", env)


## `light-dim` / `light-bright`: nudge every `directional_light` by ±0.25 over 3s.
func apply_script_light_shift(delta_energy: float) -> void:
	_snapshot_script_lights_if_needed()
	if _script_light_tween and _script_light_tween.is_valid():
		_script_light_tween.kill()
	_script_light_tween = create_tween()
	_script_light_tween.set_parallel(true)
	for light in get_tree().get_nodes_in_group("directional_light"):
		if not (light is DirectionalLight3D):
			continue
		var to_energy := maxf(float(light.light_energy) + delta_energy, 0.0)
		_script_light_tween.tween_property(light, "light_energy", to_energy, SCRIPT_LIGHT_TWEEN_SEC)


func restore_final_round_atmosphere(reapply_env: bool = true) -> void:
	if _script_light_tween and _script_light_tween.is_valid():
		_script_light_tween.kill()
	_script_light_tween = null
	for light in get_tree().get_nodes_in_group("directional_light"):
		if not (light is DirectionalLight3D):
			continue
		var id := light.get_instance_id()
		if _script_light_base.has(id):
			light.light_energy = float(_script_light_base[id])
	_script_light_base.clear()
	if reapply_env:
		var level_id := String(gl_PlayerState.dataset.get("level_name", ""))
		var path := _environment_path_for_level(level_id)
		var cam = get_tree().get_first_node_in_group("player_cam")
		if cam and cam.has_method("set_level_environment_from_path"):
			cam.set_level_environment_from_path(path)


func _snapshot_script_lights_if_needed() -> void:
	if not _script_light_base.is_empty():
		return
	for light in get_tree().get_nodes_in_group("directional_light"):
		if light is DirectionalLight3D:
			_script_light_base[light.get_instance_id()] = light.light_energy


func _reattach_heavy_layout_nodes(detached: Array) -> void:
	for item in detached:
		var parent: Node = item.get("parent")
		var node: Node = item.get("node")
		if parent == null or node == null or not is_instance_valid(parent) or not is_instance_valid(node):
			continue
		parent.add_child(node)


func _save_level_progress() -> void:
	var level_id := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	if level_id == '' or level_id == gl_DataSet.get_start_place_name() or level_id == 'start':
		return
	var level_name_l := String(gl_PlayerState.dataset.level_name).to_lower()
	if level_name_l.begins_with("boss") or String(level_id).begins_with("boss"):
		return
	var existing: Dictionary = {}
	if _level_progress.has(level_id) and _level_progress[level_id] is Dictionary:
		existing = (_level_progress[level_id] as Dictionary).duplicate(true)
	else:
		existing = gl_PlayerState.get_level_progress_entry(level_id)
	var entry := {
		'sequence_index': current_sequence_index,
		'round': maxi(current_round, 1),
		'player_round': int(gl_PlayerState.dataset.round),
		'cash_earned': int(existing.get('cash_earned', gl_PlayerState.get_place_cash_earned(level_id))),
		'entered': true,
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
	## Ignore any legacy mid-script resume saved from balloon-rest.


## Swap scenery + round data for a shooting range. Used for first arrival and mid-run map travel.
## use_transition_overlay: background travel banner/fade. Map button travel passes false and drives progress_bar instead.
func travel_to_level(level_id: String, use_transition_overlay: bool = true, progress_bar: Range = null) -> void:
	level_id = gl_DataSet.resolve_place_name(level_id)
	apply_level_file_for_difficulty()
	var layout_path := _layout_path_for_level(level_id)
	if layout_path.is_empty():
		push_error('RoundManager: unknown level "%s"' % level_id)
		return
	if transitioning_worlds:
		return

	var start_name := gl_DataSet.get_start_place_name()
	var coming_from_start := String(gl_PlayerState.dataset.level_name).to_lower() == start_name or String(gl_PlayerState.dataset.level_name).to_lower() == 'start'
	var already_here := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name)) == level_id
	if already_here:
		return

	_travel_progress_bar = progress_bar
	_travel_progress_display = 0.0
	_travel_progress_target = 0.0
	if progress_bar:
		progress_bar.value = 0.0
	_set_travel_progress(0.02)
	CommonCode.apply_transition_blur()
	if use_transition_overlay:
		_hold_title_camera_for_travel()

	# Kick layout load on a worker during the fade / map progress.
	_request_layout_load(layout_path)

	transitioning_worlds = true
	reset_level_layout_pan(true)
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
	_boss_mode = false
	_boss_looping = false
	_boss_open_map_after_tally = false
	_advance_range_after_hold_out = false
	_tally_exit_to_level_select = false
	_tally_travel_next_level = false
	_tally_replay_level = false
	_boss_ceremony_island = -1
	_clear_player_ammo()

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method('cleanup_bonus_round'):
		bonus_target_manager.cleanup_bonus_round()

	if use_transition_overlay and player and player.has_method("hide_hud"):
		player.hide_hud()
	else:
		player.display_hud()
	gl_PlayerState.dataset.level_name = level_id
	if gl_PlayerState.has_method("reset_range_banked_cash"):
		gl_PlayerState.reset_range_banked_cash()
	_set_travel_progress(0.08)

	if coming_from_start:
		gl_PlayerState.dataset['stage'] = 1
		gl_PlayerState.dataset['reroll_unlocked'] = 1
	## Always stop intro / title-select music on any level travel (map → range, start → range, etc.).
	if music_manager and music_manager.has_method("fade_out_title_menu_music"):
		music_manager.fade_out_title_menu_music()
	elif music_manager and music_manager.has_method("stop_opening_song"):
		music_manager.stop_opening_song()


	# Replace level layout under the fade / map.
	if level_layout.get_child_count() > 0:
		for child in level_layout.get_children():
			child.queue_free()
		await get_tree().process_frame

	var layout_scene := await _await_layout_scene(layout_path)
	if layout_scene == null:
		push_error('RoundManager: failed to load layout for "%s"' % level_id)
		transitioning_worlds = false
		_clear_travel_progress_bar()
		return

	## Prefill the bar before instantiate hitch so freezes are less noticeable.
	_set_travel_progress(0.88)
	await _await_travel_progress_near(82.0, 0.9)
	rocks_container.show()
	var level_scenery = layout_scene.instantiate()
	var heavy := _detach_heavy_layout_nodes(level_scenery)
	level_layout.add_child(level_scenery)
	level_scenery.name = 'current_level_layout'
	apply_level_environment(level_id, layout_path)
	# Let Compatibility/Web compile the new layout's pipelines under the fade.
	await get_tree().process_frame
	await get_tree().process_frame
	_reattach_heavy_layout_nodes(heavy)
	await get_tree().process_frame
	_set_travel_progress(0.93)

	#if use_transition_overlay:
		#await get_tree().create_timer(1.0, false).timeout

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

	## Ambient mines for this range (preamble `threat` lines). Force replace after travel.
	_sync_range_default_threats(true)

	shop_main_menu.setup_shop_for_rounds()
	shop_main_menu.sync_rounds_to_progress(current_sequence_index, current_rock_sequence.size())
	shop_main_menu.update_place_label()
	if not use_transition_overlay:
		wave_progress_feedback.show()
	find_egg()
	_set_travel_progress(0.95)


	if not use_transition_overlay and place_name:
		place_name.update_place_name()

	if coming_from_start:
		var player_balloon := get_node_or_null('../PlayerBalloon')
		if player_balloon and player_balloon.has_method('add_balloon'):
			player_balloon.add_balloon()
		gl_PlayerState.dataset.tickets += 1
		shop_main_menu.update_next_ticket()
		#if use_transition_overlay:
			#await get_tree().create_timer(3.0, false).timeout

	_set_travel_progress(1.0)
	transitioning_worlds = false
	## Mark this place as entered so the map can show round progress.
	_save_level_progress()
	_clear_travel_progress_bar()
	## Map travel (no overlay): shop + ammo open after the map's own exit timing.
	if use_transition_overlay:
		await _play_range_arrival_intro(level_id)


func _hold_title_camera_for_travel() -> void:
	var scene_mgr := get_tree().get_first_node_in_group("scene_manager")
	if scene_mgr and scene_mgr.has_method("hold_at_title_camera"):
		scene_mgr.hold_at_title_camera()


func _play_range_arrival_intro(level_id: String) -> void:
	CommonCode.apply_gameplay_blur()
	if player and player.has_method("hide_hud"):
		player.hide_hud()
	if wave_progress_feedback:
		wave_progress_feedback.hide()
	if place_name and place_name.has_method("play_arrival_card"):
		await place_name.play_arrival_card(level_id)
	var scene_mgr := get_tree().get_first_node_in_group("scene_manager")
	if scene_mgr and scene_mgr.has_method("begin_swoop_to_gameplay_camera"):
		scene_mgr.begin_swoop_to_gameplay_camera()
	var shop_delay := 0.0
	if place_name and "arrival_shop_delay_sec" in place_name:
		shop_delay = maxf(float(place_name.arrival_shop_delay_sec), 0.0)
	if shop_delay > 0.0:
		if scene_mgr and scene_mgr.has_method("await_camera_swoop"):
			await scene_mgr.await_camera_swoop()
		if not is_inside_tree():
			return
		await get_tree().create_timer(shop_delay, false).timeout
		if not is_inside_tree():
			return
		_open_shop_after_arrival()
		return
	_open_shop_after_arrival()
	if scene_mgr and scene_mgr.has_method("await_camera_swoop"):
		await scene_mgr.await_camera_swoop()


func _open_shop_after_arrival() -> void:
	if wave_progress_feedback:
		wave_progress_feedback.show()
	enter_state(RoundState.SHOP_START)


## Boss survival fight for an overworld island (0 → island_1_boss + range boss, 1 → island_2_boss + range boss-2).
func travel_to_boss(island_index: int = 0, use_transition_overlay: bool = true, progress_bar: Range = null) -> void:
	island_index = clampi(island_index, 0, maxi(gl_DataSet.get_island_count() - 1, 0))
	var layout_path := String(LAYOUT_PATH_BOSS_BY_ISLAND.get(island_index, ""))
	if layout_path.is_empty():
		## Fallback: reuse island 1 boss arena until other islands have layouts.
		layout_path = String(LAYOUT_PATH_BOSS_BY_ISLAND.get(0, ""))
	if layout_path.is_empty():
		push_error("RoundManager: no boss layout for island %d" % island_index)
		return
	if transitioning_worlds:
		return

	_travel_progress_bar = progress_bar
	_travel_progress_display = 0.0
	_travel_progress_target = 0.0
	if progress_bar:
		progress_bar.value = 0.0
	_set_travel_progress(0.02)
	CommonCode.apply_transition_blur()
	_request_layout_load(layout_path)
	transitioning_worlds = true
	reset_level_layout_pan(true)
	_save_level_progress()
	if music_manager and music_manager.has_method("fade_out_title_menu_music"):
		music_manager.fade_out_title_menu_music()
	elif music_manager and music_manager.has_method("stop_opening_song"):
		music_manager.stop_opening_song()

	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method("soft_hide_for_level_editor"):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()

	## Map stays open when travelling from a button progress bar; otherwise close it.
	if use_transition_overlay:
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
	current_round_state = RoundState.INACTIVE
	_boss_mode = true
	_boss_island_index = island_index
	_boss_looping = false
	_boss_open_map_after_tally = false
	_boss_ceremony_island = -1

	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method("cleanup_bonus_round"):
		bonus_target_manager.cleanup_bonus_round()

	player.display_hud()
	var boss_range := _boss_range_name(island_index)
	gl_PlayerState.dataset.level_name = boss_range
	_set_travel_progress(0.08)



	if level_layout.get_child_count() > 0:
		for child in level_layout.get_children():
			child.queue_free()
		await get_tree().process_frame

	var layout_scene := await _await_layout_scene(layout_path)
	if layout_scene == null:
		push_error("RoundManager: failed to load boss layout")
		_boss_mode = false
		transitioning_worlds = false
		_clear_travel_progress_bar()
		return

	_set_travel_progress(0.65)
	rocks_container.show()
	## Grow the rock pool while the transition covers the screen (batched, no hitch).
	if rocks_container and rocks_container.has_method("ensure_extra_rocks"):
		await rocks_container.ensure_extra_rocks(80, 4)
	_set_travel_progress(0.88)
	await _await_travel_progress_near(82.0, 0.9)
	var level_scenery = layout_scene.instantiate()
	var heavy := _detach_heavy_layout_nodes(level_scenery)
	level_layout.add_child(level_scenery)
	level_scenery.name = "current_level_layout"
	apply_level_environment(boss_range, layout_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_reattach_heavy_layout_nodes(heavy)
	await get_tree().process_frame
	if use_transition_overlay:
		await get_tree().create_timer(1.0, false).timeout
	_set_travel_progress(0.93)

	## Always reload so hold-out / boss range data is fresh.
	if not Parser.loadIslandFile(LEVEL_FILE_PATH):
		push_error("RoundManager: failed to load level file for boss")
	current_rock_sequence = Parser.get_rock_sequences(LEVEL_ISLAND_NAME, boss_range)
	if current_rock_sequence.is_empty() and boss_range != "boss":
		push_warning('RoundManager: no rounds for "%s"; falling back to "boss"' % boss_range)
		current_rock_sequence = Parser.get_rock_sequences(LEVEL_ISLAND_NAME, "boss")
	current_sequence_index = 0
	current_round = 1
	gl_PlayerState.dataset.round = 1

	_refresh_boss_timer_from_parser()
	_apply_boss_timer_to_hud()

	if current_rock_sequence.is_empty():
		push_warning("RoundManager: boss range has no rounds in %s" % LEVEL_FILE_PATH)

	if shop_main_menu:
		shop_main_menu.setup_shop_for_rounds()
		shop_main_menu.sync_rounds_to_progress(0, 1)
		shop_main_menu.update_place_label()
	wave_progress_feedback.show()
	find_egg()
	_set_travel_progress(0.96)

	if use_transition_overlay:
		scene_transition_screen.next_level_finish()
		place_name.update_place_name()
		await get_tree().create_timer(0.75, false).timeout
	else:
		place_name.update_place_name()

	_set_travel_progress(1.0)
	transitioning_worlds = false
	_clear_travel_progress_bar()
	check_round_for_strikes()
	CommonCode.apply_ui_overlay_blur()
	## Map travel (no overlay): shop + ammo open after the map's own exit timing.
	if use_transition_overlay:
		enter_state(RoundState.SHOP_START)


func _loop_boss_sequence() -> void:
	if not is_hold_out_round() or wave_ending or player_failed or _boss_looping or _continue_open or _continue_resuming:
		return
	## Pineapple finale owns the end of the round — do not feed more rocks.
	if rocks_container and rocks_container.has_method("is_hold_out_pineapple_finale_active"):
		if bool(rocks_container.is_hold_out_pineapple_finale_active()):
			return
	_boss_looping = true
	var rock_seq := update_rock_sequence()
	if rocks_container and not rock_seq.is_empty():
		rocks_container.start_manual_rock_round(rock_seq)
		## Mid-hold-out loops don't get a fresh egg pulse — launch immediately.
		rocks_container.enter_state(rocks_container.State.PULSE_ROCKS)
	_boss_looping = false


func _loop_endless_sequence() -> void:
	if not is_endless_mode() or wave_ending or player_failed or _endless_looping or _continue_open or _continue_resuming:
		return
	_endless_looping = true
	if current_rock_sequence.is_empty():
		_endless_looping = false
		return
	## Keep feeding rocks like boss hold-out — cycle shipper rounds continuously.
	current_sequence_index = (current_sequence_index + 1) % current_rock_sequence.size()
	current_round = current_sequence_index + 1
	var rock_seq := update_rock_sequence()
	if rocks_container and not rock_seq.is_empty():
		rocks_container.start_manual_rock_round(rock_seq)
		rocks_container.enter_state(rocks_container.State.PULSE_ROCKS)
	_endless_looping = false


func _finish_boss_round() -> void:
	stop_timer()
	stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_boss_looping = false
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container:
		balloon_container.end_round()

	var failed := player_failed or not success
	force_shop_open = false

	await get_tree().create_timer(0.35, false).timeout

	if failed:
		## Keep fail state for the tally card, then retry from shop after.
		player_failed = true
		success = false
		current_wave = 0
		current_sequence_index = 0
		wave_ending = false
		enter_state(RoundState.TALLY_START)
		return

	## Survived the timer — award clear bonus, celebrate, then tally → map ceremony.
	var reward := gl_DataSet.get_boss_clear_reward(_boss_island_index)
	if reward > 0:
		gl_PlayerState.add_cash(reward)
	gl_PlayerState.mark_boss_cleared(_boss_island_index)
	## Next-island unlock is granted during the map ceremony (after Close).
	_boss_ceremony_island = _boss_island_index

	$Gold_sfx.play()
	if round_timer and round_timer.has_method("play_boss_cleared_celebration"):
		await round_timer.play_boss_cleared_celebration()
	else:
		if wave_progress_feedback and wave_progress_feedback.has_method("start_perfect"):
			wave_progress_feedback.start_perfect()
		await get_tree().create_timer(1.25, false).timeout

	_boss_mode = false
	_boss_open_map_after_tally = true
	player_failed = false
	success = true
	current_wave = 0
	wave_ending = false
	enter_state(RoundState.TALLY_START)


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
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))

	# Lock progress at end-of-range.
	if current_rock_sequence.size() > 0:
		current_sequence_index = current_rock_sequence.size()
		current_round = current_sequence_index
		gl_PlayerState.dataset.round = current_round
	_save_level_progress()

	# Already cleared this range — stay in shop-ready replay mode (don't soft-lock Play).
	if gl_PlayerState.is_place_completed(place):
		game_over_triggered = false
		_clamp_sequence_index_for_replay()
		player.stop_player()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		enter_state(RoundState.SHOP_START)
		return

	game_over_triggered = true
	gl_PlayerState.mark_place_completed(place)

	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_game_over"):
		menus.ensure_game_over()

	player.stop_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var game_over_menu = get_tree().get_first_node_in_group('game_over_screen')
	if game_over_menu and game_over_menu.has_method("update_open_menu"):
		await game_over_menu.update_open_menu()
	else:
		push_warning('RoundManager: game over screen missing')
		game_over_triggered = false
		enter_state(RoundState.SHOP_START)


## After range-clear tally: go to start, open the map, then fly WINNINGS into map cash.
func open_island_map_after_range_clear(place_id: String, held_winnings: int = 0) -> void:
	place_id = gl_DataSet.resolve_place_name(place_id)
	game_over_triggered = false
	enter_state(RoundState.INACTIVE)
	await _arrive_at_start_for_map(false)

	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var map_menu: Node = null
	if menus and menus.has_method("ensure_ticket_map"):
		map_menu = menus.ensure_ticket_map()
	if map_menu == null:
		map_menu = get_tree().get_first_node_in_group("map_menu")
	if map_menu == null:
		push_warning("RoundManager: MapIslandSelect missing — cannot open island map after range clear")
		enter_state(RoundState.SHOP_START)
		return
	if map_menu is CanvasItem:
		(map_menu as CanvasItem).z_index = 40
	CommonCode.apply_ui_overlay_blur()
	if map_menu.has_method("open_pop_up_after_range_clear"):
		await map_menu.open_pop_up_after_range_clear(place_id, held_winnings)
	elif map_menu.has_method("open_pop_up"):
		await map_menu.open_pop_up()
		if map_menu.has_method("mark_place_completed"):
			await map_menu.mark_place_completed(place_id, true)
	else:
		enter_state(RoundState.SHOP_START)


func _arrive_at_start_for_map(use_transition: bool = true) -> void:
	transitioning_worlds = true
	stop_timer()
	stop_player()

	if shop_main_menu and shop_main_menu.visible:
		if shop_main_menu.has_method("soft_hide_for_level_editor"):
			shop_main_menu.soft_hide_for_level_editor()
		else:
			shop_main_menu.hide()
	if rocks_container:
		rocks_container.enter_state(rocks_container.State.ROUND_END)
		rocks_container.reset_all_rocks()
	if balloon_container and (balloon_container.started or balloon_container.balloons_in_play > 0):
		await balloon_container.end_round()
	if bonus_target_manager and bonus_target_manager.has_method("cleanup_bonus_round"):
		bonus_target_manager.cleanup_bonus_round()

	if scene_transition_screen and scene_transition_screen.has_method("set_destination_place"):
		scene_transition_screen.set_destination_place("start")
	if use_transition and scene_transition_screen and scene_transition_screen.has_method("next_level_start"):
		await scene_transition_screen.next_level_start()

	gl_PlayerState.dataset.level_name = gl_DataSet.get_start_place_name()
	move_to_start()
	if rocks_container:
		rocks_container.hide()
	if wave_progress_feedback:
		wave_progress_feedback.hide()
	if place_name and place_name.has_method("update_place_name"):
		place_name.update_place_name()
	await get_tree().process_frame

	if use_transition and scene_transition_screen and scene_transition_screen.has_method("next_level_finish"):
		await scene_transition_screen.next_level_finish()

	transitioning_worlds = false


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
	var layout_path := _layout_path_for_level(level_id)
	if layout_path.is_empty():
		push_error('RoundManager: unknown level "%s" for instant travel' % level_id)
		return

	_request_layout_load(layout_path)
	transitioning_worlds = true
	reset_level_layout_pan(true)
	player.display_hud()
	gl_PlayerState.dataset["stage"] = 1
	gl_PlayerState.dataset["reroll_unlocked"] = 1
	gl_PlayerState.dataset["round"] = 1
	gl_PlayerState.dataset["level_name"] = level_id
	if gl_PlayerState.has_method("reset_range_banked_cash"):
		gl_PlayerState.reset_range_banked_cash()
	if music_manager and music_manager.has_method("fade_out_title_menu_music"):
		music_manager.fade_out_title_menu_music()
	elif music_manager:
		music_manager.stop_opening_song()

	# Keep transition overlay off-screen (no slide animation).
	if scene_transition_screen and scene_transition_screen.has_method("_reset_next_level"):
		scene_transition_screen._reset_next_level()

	if level_layout.get_child_count() > 0:
		for child in level_layout.get_children():
			child.queue_free()
		await get_tree().process_frame

	var layout_scene := await _await_layout_scene(layout_path)
	if layout_scene == null:
		push_error('RoundManager: failed to load layout for instant "%s"' % level_id)
		transitioning_worlds = false
		return

	rocks_container.show()
	var level_scenery = layout_scene.instantiate()
	var heavy := _detach_heavy_layout_nodes(level_scenery)
	level_layout.add_child(level_scenery)
	level_scenery.name = 'current_level_layout'
	apply_level_environment(level_id, layout_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_reattach_heavy_layout_nodes(heavy)

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
