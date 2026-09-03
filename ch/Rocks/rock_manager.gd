class_name RockManager
extends Node3D

enum State {
	INACTIVE,
	PREPARE_ROCKS,
	PULSE_ROCKS,
	ROUND_END,
}

var current_state : State = State.INACTIVE
const pulse_magnitude := 1.1
## When true, waves after wave 1 randomise rock columns (existing behaviour).
@export var randomize_later_waves := true
## When true, `launch_next_command` skips waits and fires the next script line. Off by default so Ctrl can be used for gun swap.
@export var launch_next_command_enabled := false
## Depth launch strength for `rock-pigeon` (into the distance). Raise to send them further back.
const pigeon_depth_impulse := 35.0 #70.0
const rock_pigeon_upward_force := 2.0
## Half-angle of the pigeon fan in degrees. Column 1 = +this, column 8 = -this.
## Matches the editor reference: origin → rotate Y by this → push out.
const pigeon_fan_half_angle_deg := 17.0
## How far from world origin the fan aim reference points sit (meters along each ray).
## Separate from impulse strength — move/tweak via `PigeonAimMarkers` children if present.
const pigeon_aim_reference_depth := 45.0
## Optional: Node3D with 8 Marker3D children named "1"…"8" (or in column order).
## When set, those world positions override the computed 17° fan points.
@export var pigeon_aim_markers: Node3D

var rocks_limit := 0
const ROCK_INSTANCE_SCENE := preload("res://ch/Rocks/Rock_Instance.tscn")
const CHECKPOINT_SCENE := preload("res://ch/Rocks/Checkpoint.tscn")
const LADDER_BALLOON_SCRIPT := preload("res://ch/Rocks/ladder_choice_balloon.gd")
const AMMO_BALLOON_SCENE := preload("res://ch/Rocks/AmmoBalloon.tscn")
## Extra pool rocks added once when entering the boss layout (batched across frames).
var _boss_extra_rocks_added := false

# --- Rock X-axis placement tuning ---------------------------------------
const X_MAX := 10.0          # left-most bound
const X_MIN := -10.0         # right-most bound
const MIN_ROCK_SPACING := 0.0 # 0.5    # no two rocks closer than this
const CLUSTER_MIN_DIST := 0.0 #0.5    # the clustered pair's minimum gap
const CLUSTER_MAX_DIST := 0.0 #1.5    # the clustered pair's maximum gap
@export var angle_bias := 10.0 # 0.1 # how hard rocks get angled back toward the opposite side

var convergence_x := 0.0
# --------------------------------------------------------------------------


# Columns run left to right along the X-axis: column 1 = 7, column 2 = 5... column 8 = -7
# (step of -2 per column).
var manual_rock_sequence : Array = [4]
## Seconds to wait BEFORE launching each rock (index 0 is usually 0).
var _launch_delays_sec : Array = []
## Balloons that appear after a `wait` — spawned mid-pulse at these absolute times.
## Also holds `pineapple` launches (any time, including t=0).
## Items: { "kind": "balloon"|"pineapple", "entry": Dictionary, "time_sec": float }
var _timed_event_schedule : Array = []
var _timed_event_epoch := 0
var _timed_events_running := false
## Bumped to cancel in-flight staggered launches (bounce_rocks awaits).
var _launch_epoch := 0

const COLUMN_1_X := 7.0 #18.0 
const COLUMN_STEP := 2.0 #4.0
const COLUMN_COUNT := 8
## Default stagger between rocks in a rock-gap / rock-red-gap fan.
const GAP_FAN_STAGGER_MS := 100
const SAME_COLUMN_OFFSET := 0.0  # spread applied to duplicate rocks sharing a column
## Extra meters added to the spacing between every neighbouring column.
## 0 = default step 2 → (7, 5, 3, 1, -1, -3, -5, -7).
## 1 = step 3 → (10.5, 7.5, 4.5, 1.5, -1.5, -4.5, -7.5, -10.5).
@export var broaden_columns := 0.0:
	set(value):
		broaden_columns = value
		if is_node_ready():
			sync_telegraph_column_positions()
			sync_debug_visualiser()
@export var DEFAULT_LAUNCH_WAIT_MS := 100
## Telegraph markers — defaults to $Columns2 under Rocks.
@export var telegraph_columns: Node3D
## Aim-grid debug overlays (Column1–8 / RowA–C). Defaults to $DebugVisualiser.
@export var debug_visualiser: Node3D
## Blink the column mesh just before each rock launches (not a full-wave preview).
@export var telegraph_before_launch := true
## How far ahead of launch the column blink starts (seconds). Capped at 1.0.
@export_range(0.0, 1.0, 0.01) var telegraph_lead_sec := 0.35
@export var telegraph_blink_color := Color(1.0, 0.92, 0.2, 1.0)
@export_range(0.05, 0.8, 0.01) var telegraph_blink_on_sec := 0.12
@export_range(0.05, 0.8, 0.01) var telegraph_blink_off_sec := 0.1
## Legacy wave-preview gap (unused when using telegraph_before_launch).
@export_range(0.0, 1.0, 0.01) var telegraph_gap_between_rocks_sec := 0.06
@export var telegraph_sfx: AudioStream = preload("res://sfx/ninja_flicker.ogg")
@export_range(-40.0, 6.0, 0.5) var telegraph_sfx_volume_db := -12.0
## Pitch rises with column index (1→low, 8→high). 0 = fixed pitch.
@export_range(0.0, 0.2, 0.01) var telegraph_sfx_pitch_step := 0.06
## Legacy full-wave path preview — kept for tooling, disabled by default.
@export var path_telegraph_enabled := false
## Total time budget for the full preview sequence (all rocks).
@export_range(0.5, 5.0, 0.1) var path_telegraph_duration_sec := 2.0
@export var path_telegraph_color := Color(1.0, 0.92, 0.25, 0.75)
@export var path_telegraph_aim_color := Color(0.35, 1.0, 0.55, 0.85)
## Deprecated: use telegraph_before_launch. Kept so old scenes still load.
@export var telegraph_enabled := false
var _telegraph_sfx_player: AudioStreamPlayer
## Resolved spawn columns for the current wave (launch order). Built in assign_manual_rock_positions.
var _wave_spawn_columns: Array[int] = []
var _telegraph_token := 0
## MeshInstance3D per column index 1..COLUMN_COUNT
var _telegraph_meshes: Array[MeshInstance3D] = []
## Base albedo per mesh instance id — restored after blinks
var _telegraph_base_albedo: Dictionary = {}
## Cached spawn→aim plan so telegraph preview matches the real launch.
## Items: { spawn: Vector3, aim: Vector3, column: int, is_pigeon: bool }
var _wave_telegraph_plan: Array = []
var _path_telegraph_root: Node3D
var _path_ghost_mat: StandardMaterial3D
var _path_aim_mat: StandardMaterial3D
var _path_trail_mat: StandardMaterial3D
var _path_telegraph_tween: Tween
## Aim apex heights — same Y bands balloons use (A/B/C → 1/2/3).
const AIM_LANE_Y := {
	1: 6.5, # 7.0
	2: 3.5,
	3: 0.5,
}
## World Z of the aim grid (balloon board is at Z ≈ 22.5; A8 ≈ Vector3(-7, 6.5, 22.5)).
const AIM_PLANE_Z := 23.0
## Side-lane script columns: 0 sits outside 1, 9 outside 8. Spawns start just off-camera.
const SIDE_LANE_OUTSIDE_1 := 0
const SIDE_LANE_OUTSIDE_8 := 9
## Lateral fly-across (e.g. `rock A0 A8`): no arc, constant speed.
const LATERAL_LAUNCH_GRAVITY := 0.0
const LATERAL_FLIGHT_SPEED := 12.0
const OFFSCREEN_SPAWN_PAD_M := 0.85
## Multiplier on computed aimed-launch impulse. 1.0 = exact ballistic solve; raise if rocks land short.
@export_range(0.5, 2.0, 0.01) var aim_impulse_scale := 1.08
## Gravity during the aimed arc (higher = faster launch, sharper slowdown at apex). Must match impulse math.
@export_range(0.05, 4.0, 0.01) var aim_launch_gravity_scale := 0.5
var _base_aim_launch_gravity_scale := 0.5
## Script `pace-*` → aim_launch_gravity_scale.
const PACE_GRAVITY := {
	"slowest": 0.25,
	"slow": 0.5,
	"normal": 1.0,
	"fast": 1.5,
	"fastest": 2.25,
	"impossible": 3.0,
}
## Linear damp applied once the rock passes the apex and starts falling.
@export_range(0.0, 2.0, 0.05) var aim_descent_linear_damp := 0.5
## Extra seconds added to the ascent before passing the aim cell (0 = tight apex; try ~0.5 for old hang).
@export_range(0.0, 2.0, 0.05) var aim_hang_time_sec := 0.0
## When true, unspecified aims converge on the midpoint of this wave's leftmost/rightmost spawns
## (center column ± 1). Explicit aims (e.g. `rock 1 A3`) are unchanged. Pigeons are not affected.
@export var bias_random_aim_toward_center := true
## Chance (0–1) that unspecified aims all meet on the same column. Remainder uses adjacent-lane split.
@export_range(0.0, 1.0, 0.05) var converge_same_lane_chance := 0.5
## World-space jitter around the aim cell. 0 = exact; higher = random point within this radius (X/Y).
@export_range(0.0, 5.0, 0.05) var aim_offset := 0.0
## Shared same-lane aim column for this pulse (-1 if unused).
var _wave_convergence_aim_column := -1
## True = all unspecified rocks share one column; false = left/right adjacent split.
var _wave_aim_converge_same_lane := true
## Midpoint / pool used for split aiming this pulse.
var _wave_aim_mid := 0.0
var _wave_aim_center := -1
var _wave_aim_pool: Array[int] = []
# --------------------------------------------------------------------------

# --- Out-of-bounds monitoring (during PULSE_ROCKS only) -------------------
# Misses when an activated rock leaves the camera view on the left, right, or
# bottom (top is allowed — rocks arc above and fall back). Margins are in
# screen pixels beyond the viewport edge. Rocks that spawn off-screen only
# count after they have entered the viewport at least once.
@onready var splash_zone: Area3D = %Splash_zone
const BOUNDS_CHECK_INTERVAL := 0.1  # how often (seconds) to scan active rocks
@export var oob_margin_left_px := 64.0
@export var oob_margin_right_px := 64.0
@export var oob_margin_bottom_px := 64.0
## Optional override; if unset, uses the active Camera3D / `player_cam`.
@export var bounds_camera: Camera3D
## Particle burst + side-biased camera shake when a rock escapes the screen (strike miss).
## Toggle on the Rocks / RockManager node in Main.tscn.
@export var oob_miss_feedback_enabled := true
@export_range(0.0, 0.5, 0.005) var oob_miss_shake_amount := 0.16
@export_range(0.02, 0.5, 0.01) var oob_miss_shake_duration := 0.1
## When false, yellow / must-hit rocks (`rock_type_1`) no longer award a strike
## for splash-zone hits or out-of-bounds exits (they still despawn / count as cleared).
@export var rock_yellows_give_strikes := true
## After launch delay, airborne rocks collide and bounce off each other.
## Off while dormant / preparing / during the pulse itself (see delay below).
## Toggle on the Rocks / RockManager node in Main.tscn.
@export var rock_rock_collisions_enabled := true
## PhysicsMaterial bounce (0 = dead stop on contact, 1 = max restitution) once airborne.
@export_range(0.0, 1.0, 0.05) var rock_rock_bounce := 0.35
## Seconds after each rock's launch impulse before rock–rock collision turns on.
## Keeps stacked / nearby launches from shoving each other during the pulse.
@export_range(0.0, 2.0, 0.05) var rock_rock_collision_delay_sec := 0.4
var _bounds_check_active := false
var _bounds_check_accum := 0.0

## Intra-wave script cursor: `wait` (until clear) / `balloon-check` / `clear`.
var _full_wave_sequence: Array = []
var _sequence_cursor := 0
## Active scriptor `sfx-play` instances, keyed by file stem (e.g. Windmill_YokoKanno).
var _script_sfx_players: Dictionary = {}
var _script_sfx_fade_tokens: Dictionary = {}
var _script_sfx_pitch_tweens: Dictionary = {}
var _script_sfx_pitch_target: Dictionary = {}
## Fade used when the round ends or the player returns to shop.
const SCRIPT_SFX_LEAVE_FADE_SEC := 3.0
const SCRIPT_SFX_PITCH_STEP := 0.05
const SCRIPT_SFX_PITCH_RAMP_SEC := 3.0
var _sequence_active := false
var _paused_for_continue := false
var _waiting_until_clear := false
var _checkpoint_hold := false
var _ladder_hold := false
var _auto_pulse_next_beat := false
var _force_mid_round_balloons := false
var _advancing_sequence := false
var _active_checkpoint: Node = null
var _stream_launches_remaining := 0
var _consumed_sequence_barrier := false
## Shop / legacy pineapple_mode round (not the script `pineapples` keyword).
var _pineapple_round_playing := false
var _launched_rocks_this_sequence := false
var _launched_scripted_pineapple := false
## Trailing `pineapple` (+ waits) after a `pineapples` keyword — fanfare finale.
var _hold_out_pineapple_finale: Array = []
var _hold_out_finale_active := false
var _hold_out_finale_token := 0
## True while the finale coroutine is still launching the pattern (waits / pineapples).
var _hold_out_finale_spawning := false
var _pending_ammo_entries: Array = []
## True while a timed `wait N` is sleeping so sky-clear does not skip it.
var _sequence_delay_active := false
## `wait` after the last rock in a beat — applied before the next command.
var _pending_sequence_delay_sec := 0.0
## Bumped to cancel an in-flight wait timer (debug `launch_next_command`).
var _sequence_delay_token := 0
## Skip waits / wait-until-clear and launch one script command.
var _force_next_command := false
## Fast-path pulse: no 0.4s gap, no column telegraph.
var _instant_sequence_pulse := false

enum OobSide { NONE, LEFT, RIGHT, BOTTOM, BEHIND }

const _OOB_MISS_SMOKE := preload("res://res/Particles/Smoke_particles/SmokeQuick.tscn")
const _OOB_MISS_SPARKS = preload("uid://fsbgvpv0703x")
# --------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("rocks_container")
	_base_aim_launch_gravity_scale = aim_launch_gravity_scale
	if telegraph_columns == null:
		if has_node("Columns2"):
			telegraph_columns = $Columns2
		elif has_node("Columns"):
			telegraph_columns = $Columns
	if debug_visualiser == null and has_node("DebugVisualiser"):
		debug_visualiser = $DebugVisualiser
	_ensure_telegraph_sfx_player()
	_cache_telegraph_meshes()
	# Defer until a Camera3D is current so perspective sync can run.
	call_deferred("sync_telegraph_column_positions")
	call_deferred("sync_debug_visualiser")
	EventBus.instance.egg_pulsed.connect(enter_state.bind(State.PULSE_ROCKS))
	#EventBus.instance.all_rocks_destroyed.connect(all_rocks_destroyed)
	EventBus.instance.detonate_sky_mines.connect(detonate_sky_mines)
	## Same camera/particles sting as an OOB miss — play on every strike.
	EventBus.instance.add_strike.connect(play_strike_feedback)
	EventBus.instance.has_hit_three_strikes.connect(play_strike_feedback)
	enter_state(current_state)


func set_difficulty_gravity(difficulty: String) -> void:
	match String(difficulty).to_lower():
		"easy":
			set_pace_gravity("slow")
		"normal":
			set_pace_gravity("normal")
		"hard":
			set_pace_gravity("fast")
		"expert":
			set_pace_gravity("fastest")
		_:
			aim_launch_gravity_scale = _base_aim_launch_gravity_scale


func set_pace_gravity(pace: String) -> void:
	var key := String(pace).strip_edges().to_lower()
	if key.begins_with("pace-"):
		key = key.substr(5)
	if PACE_GRAVITY.has(key):
		aim_launch_gravity_scale = float(PACE_GRAVITY[key])


func _is_pace_cmd(cmd: String) -> bool:
	return cmd == "pace" or cmd.begins_with("pace-")


func _is_gun_cmd(cmd: String) -> bool:
	return cmd == "gun" or cmd == "gun1" or cmd == "gun2" or cmd == "gun3" or cmd == "gun4" or cmd == "gun5"


func _is_light_cmd(cmd: String) -> bool:
	return cmd == "light-dim" or cmd == "light-bright"


func _is_avoider_kill_cmd(cmd: String) -> bool:
	return cmd == "rock-avoider-kill"


func _apply_light_entry(entry) -> void:
	var cmd := ""
	if entry is Dictionary:
		cmd = String(entry.get("cmd", "")).to_lower()
	var delta := 0.0
	if cmd == "light-dim":
		delta = -0.25
	elif cmd == "light-bright":
		delta = 0.25
	else:
		return
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("apply_script_light_shift"):
		round_manager.apply_script_light_shift(delta)


func _apply_pace_entry(entry) -> void:
	if entry is Dictionary:
		set_pace_gravity(String(entry.get("cmd", "")))


func _apply_gun_entry(entry) -> void:
	var cmd := "gun1"
	if entry is Dictionary:
		cmd = String(entry.get("cmd", "gun1")).to_lower()
	if cmd == "gun":
		cmd = "gun1"
	var gun_id := 1
	if cmd == "gun2":
		gun_id = 2
	elif cmd == "gun3":
		gun_id = 3
	elif cmd == "gun4":
		gun_id = 4
	elif cmd == "gun5":
		gun_id = 5
	var player = get_tree().get_first_node_in_group("Player") if get_tree() else null
	if player and player.has_method("switch_gun_loadout"):
		player.switch_gun_loadout(gun_id)

func _process(delta: float) -> void:
	if _waiting_until_clear and not _checkpoint_hold and not _ladder_hold and not _advancing_sequence and not _pineapple_round_playing and not _sequence_delay_active:
		if current_state != State.INACTIVE and current_state != State.ROUND_END:
			if _sky_is_clear_for_sequence():
				if not try_continue_sequence():
					_finish_round_if_sequence_idle()

	if not _bounds_check_active:
		return
	
	_bounds_check_accum += delta
	if _bounds_check_accum < BOUNDS_CHECK_INTERVAL:
		return
	_bounds_check_accum = 0.0
	
	check_rocks_out_of_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if not launch_next_command_enabled:
		return
	if not InputMap.has_action("launch_next_command"):
		return
	if not event.is_action_pressed("launch_next_command", false):
		return
	force_launch_next_command()
	get_viewport().set_input_as_handled()


## Input `launch_next_command`: skip waits and fire the next script line now.
func force_launch_next_command() -> void:
	if not launch_next_command_enabled:
		return
	if _paused_for_continue:
		return
	if current_state == State.ROUND_END:
		return
	if not _script_has_more_commands() and not _sequence_delay_active and not _waiting_until_clear:
		return
	_sequence_delay_token += 1
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_waiting_until_clear = false
	_checkpoint_hold = false
	_ladder_hold = false
	_pineapple_round_playing = false
	_advancing_sequence = false
	if not _script_has_more_commands():
		_sequence_active = false
		return
	_sequence_active = true
	_force_next_command = true
	_instant_sequence_pulse = true
	_auto_pulse_next_beat = true
	_launch_next_sequence_beat()

func enter_state(new_state : State) -> void:
	if _paused_for_continue and new_state == State.PULSE_ROCKS:
		return
	current_state = new_state
	
	match current_state:
		State.INACTIVE:
			update_inactive()
			
		State.PREPARE_ROCKS:
			update_prepare_rocks()
			
		State.PULSE_ROCKS:
			update_pulse_rocks()
			
		State.ROUND_END:
			update_round_end()
			
func update_inactive() -> void:
	_bounds_check_active = false
	_cancel_sequence()
	_cancel_wave_telegraph()
	_cancel_pending_launches()
	_wave_telegraph_plan.clear()
	for i in $Container_1.get_children():
		if i is RockInstance:
			i.enter_state(i.State.INACTIVE)
	clear_cardinal_bursts()
	

# This is the start of arranging the rocks.
func start_manual_rock_round(sequence: Array, resume_index: int = 0) -> void:
	if _paused_for_continue:
		return
	_hold_out_finale_token += 1
	_hold_out_finale_active = false
	_hold_out_finale_spawning = false
	_hold_out_pineapple_finale.clear()
	_full_wave_sequence = sequence.duplicate(true)
	_sequence_cursor = clampi(resume_index, 0, _full_wave_sequence.size())
	## Fresh script pass — reset mid-round pace so retries don't inherit the last pace-* line.
	aim_launch_gravity_scale = _base_aim_launch_gravity_scale
	_sequence_active = true
	_waiting_until_clear = false
	_checkpoint_hold = false
	_ladder_hold = false
	_auto_pulse_next_beat = false
	_force_mid_round_balloons = resume_index > 0
	_timed_events_running = false
	_stream_launches_remaining = 0
	_consumed_sequence_barrier = resume_index > 0
	_pineapple_round_playing = false
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_launched_rocks_this_sequence = false
	_launched_scripted_pineapple = false
	_pending_ammo_entries.clear()
	_reset_pineapple_spawn_bookkeeping()
	_launch_next_sequence_beat()


func _round_manager_is_hold_out() -> bool:
	var rm = get_tree().get_first_node_in_group("round_manager") if is_inside_tree() else null
	return rm != null and rm.has_method("is_hold_out_round") and bool(rm.is_hold_out_round())


func _sequence_cmd_at(index: int) -> String:
	if index < 0 or index >= _full_wave_sequence.size():
		return ""
	var entry = _full_wave_sequence[index]
	if entry is Dictionary:
		return String(entry.get("cmd", "")).to_lower()
	return ""


func _is_balloon_check_cmd(cmd: String) -> bool:
	return cmd == "balloon-check" or cmd == "checkpoint"


func _is_ladder_balloon_cmd(cmd: String) -> bool:
	return cmd == "balloon-mult" or cmd == "balloon-multiply" or cmd == "balloon-bank" or cmd == "ladder"


func _is_clear_cmd(cmd: String) -> bool:
	return cmd == "clear" or cmd == "clear-balloon" or cmd == "clear-ammo"


func _is_sequence_barrier_cmd(cmd: String) -> bool:
	return cmd == "wait-until-clear" or _is_balloon_check_cmd(cmd) or _is_ladder_balloon_cmd(cmd)


func _is_script_sfx_cmd(cmd: String) -> bool:
	return cmd.begins_with("sfx-")


func _is_pineapple_finale_filler(cmd: String) -> bool:
	return (
		cmd == "wait"
		or cmd == "wait-until-clear"
		or _is_clear_cmd(cmd)
		or _is_pace_cmd(cmd)
		or _is_gun_cmd(cmd)
		or _is_script_sfx_cmd(cmd)
		or _is_light_cmd(cmd)
		or _is_avoider_kill_cmd(cmd)
	)


func has_trailing_pineapples() -> bool:
	return not _hold_out_pineapple_finale.is_empty()


func is_hold_out_pineapple_finale_active() -> bool:
	return _hold_out_finale_active


func should_end_hold_out_on_pineapples() -> bool:
	if not _launched_scripted_pineapple:
		return false
	if _hold_out_finale_spawning:
		return false
	if _any_airborne_pineapples():
		return false
	if _hold_out_finale_active:
		return true
	return false


## `pineapples` keyword: collect remaining pineapple/wait lines, then fanfare + launch.
func start_scripted_pineapple_finale_from_cursor() -> bool:
	if _hold_out_finale_active:
		return true
	var finale: Array = []
	while _sequence_cursor < _full_wave_sequence.size():
		var entry = _full_wave_sequence[_sequence_cursor]
		_sequence_cursor += 1
		var cmd := ""
		if entry is Dictionary:
			cmd = String(entry.get("cmd", "")).to_lower()
		if cmd == "pineapple" or cmd == "wait":
			finale.append(entry)
			continue
		if _is_pineapple_finale_filler(cmd) or cmd.is_empty():
			continue
		_sequence_cursor -= 1
		break
	if finale.is_empty():
		push_warning("RockManager: pineapples keyword with no following pineapple lines")
		return false
	_hold_out_pineapple_finale = finale
	return start_hold_out_pineapple_finale()


## Timer hit 0 before the script reached `pineapples`: jump straight to that finale block.
func jump_to_pineapple_finale_from_script() -> bool:
	if _hold_out_finale_active:
		return true
	var keyword_idx := -1
	for i in _full_wave_sequence.size():
		if _sequence_cmd_at(i) == "pineapples":
			keyword_idx = i
			break
	if keyword_idx < 0:
		return false
	_sequence_cursor = keyword_idx + 1
	_sequence_delay_token += 1
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_waiting_until_clear = false
	_sequence_active = false
	return start_scripted_pineapple_finale_from_cursor()


## Stop rocks, then launch the collected pineapple pattern with fanfare.
func start_hold_out_pineapple_finale() -> bool:
	if _hold_out_finale_active:
		return true
	if _hold_out_pineapple_finale.is_empty():
		return false
	_hold_out_finale_active = true
	_hold_out_finale_spawning = true
	_hold_out_finale_token += 1
	var token := _hold_out_finale_token
	_sequence_active = false
	_waiting_until_clear = false
	_sequence_delay_token += 1
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_advancing_sequence = false
	_timed_event_epoch += 1
	_timed_events_running = false
	_stream_launches_remaining = 0
	var round_manager = get_tree().get_first_node_in_group("round_manager") if is_inside_tree() else null
	if round_manager != null and round_manager.has_method("begin_pineapple_finale_from_script"):
		round_manager.begin_pineapple_finale_from_script()
	## Leave midair rocks playable (overtime); only stop feeding new sequence beats.
	_halt_sequence_for_pineapple_overtime()
	_run_hold_out_pineapple_finale(token)
	return true


## Stop new launches / waits, but leave live rocks in play for overtime shooting.
func _halt_sequence_for_pineapple_overtime() -> void:
	_timed_event_epoch += 1
	_timed_events_running = false
	_stream_launches_remaining = 0
	_cancel_pending_launches()
	_cancel_wave_telegraph()


func _run_hold_out_pineapple_finale(token: int) -> void:
	_launched_scripted_pineapple = false
	for entry in _hold_out_pineapple_finale:
		if token != _hold_out_finale_token or not is_inside_tree():
			_hold_out_finale_spawning = false
			return
		if _round_is_closing():
			_hold_out_finale_spawning = false
			return
		if not (entry is Dictionary):
			continue
		var cmd := String(entry.get("cmd", "")).to_lower()
		if cmd == "wait":
			var wait_ms := maxi(int(entry.get("ms", 0)), 0)
			if wait_ms > 0:
				await get_tree().create_timer(float(wait_ms) / 1000.0, false).timeout
			continue
		if cmd != "pineapple":
			continue
		var launcher := _resolve_pineapple_launcher()
		if launcher == null:
			push_warning("RockManager: hold-out pineapple finale missing PineappleLauncher")
			continue
		_launched_scripted_pineapple = true
		await launcher.launch_from_spawn_entry(entry)

	if token != _hold_out_finale_token:
		return
	_hold_out_finale_spawning = false
	if not is_inside_tree():
		return
	## Fanfare / spawn may need a frame before airborne bookkeeping catches up.
	await get_tree().process_frame
	if token != _hold_out_finale_token:
		return
	if _any_airborne_pineapples():
		return
	## Nothing stayed in play — end now (same path as last-pineapple clear).
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("finish_round_after_last_pineapple"):
		round_manager.finish_round_after_last_pineapple()

func _resolve_pineapple_launcher() -> Node:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("pineapple_container"):
		if node != null and node.has_method("launch_from_spawn_entry"):
			return node
	return null


func _launch_next_sequence_beat() -> void:
	var force := _force_next_command
	if _paused_for_continue or not _sequence_active or _round_is_closing():
		_force_next_command = false
		if _round_is_closing():
			_sequence_active = false
			_waiting_until_clear = false
		return

	if force:
		_pending_sequence_delay_sec = 0.0

	if _pending_sequence_delay_sec > 0.0:
		var delay_sec := _pending_sequence_delay_sec
		_pending_sequence_delay_sec = 0.0
		if not await _sleep_sequence_delay(delay_sec):
			_force_next_command = false
			return

	while _sequence_cursor < _full_wave_sequence.size():
		var cmd := _sequence_cmd_at(_sequence_cursor)
		if cmd == "wait":
			var wait_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			if force:
				continue
			var wait_ms := 0
			if wait_entry is Dictionary:
				wait_ms = maxi(int(wait_entry.get("ms", 0)), 0)
			if wait_ms > 0:
				if not await _sleep_sequence_delay(float(wait_ms) / 1000.0):
					_force_next_command = false
					return
			continue
		if cmd == "wait-until-clear":
			_sequence_cursor += 1
			_consumed_sequence_barrier = true
			if force:
				continue
			if not _sky_is_clear_for_sequence():
				_waiting_until_clear = true
				_force_next_command = false
				return
			continue
		if cmd == "pineapples":
			_sequence_cursor += 1
			_waiting_until_clear = true
			_force_next_command = false
			start_scripted_pineapple_finale_from_cursor()
			return
		if _is_script_sfx_cmd(cmd):
			var sfx_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_handle_sfx_command(sfx_entry)
			continue
		if _is_pace_cmd(cmd):
			var pace_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_apply_pace_entry(pace_entry)
			continue
		if _is_gun_cmd(cmd):
			var gun_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_apply_gun_entry(gun_entry)
			continue
		if _is_light_cmd(cmd):
			var light_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_apply_light_entry(light_entry)
			continue
		if _is_avoider_kill_cmd(cmd):
			_sequence_cursor += 1
			_handle_avoider_kill_command()
			continue
		if cmd == "ammo":
			var ammo_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_spawn_or_queue_ammo_balloon(ammo_entry)
			if force:
				_waiting_until_clear = true
				_force_next_command = false
				return
			continue
		if _is_clear_cmd(cmd):
			var clear_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_consumed_sequence_barrier = true
			_handle_clear_command(clear_entry)
			if force:
				_waiting_until_clear = true
				_force_next_command = false
				return
			continue
		if _is_ladder_balloon_cmd(cmd):
			var ladder_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_spawn_ladder_balloon(ladder_entry)
			if force:
				_waiting_until_clear = true
				_force_next_command = false
				return
			continue
		if _is_balloon_check_cmd(cmd):
			flush_pending_ammo()
			if not _sequence_active:
				_force_next_command = false
				return
			var round_manager = get_tree().get_first_node_in_group("round_manager")
			if round_manager != null:
				if bool(round_manager.get("wave_ending")) or bool(round_manager.get("player_failed")) or bool(round_manager.get("game_over_triggered")):
					_sequence_active = false
					_waiting_until_clear = false
					_force_next_command = false
					return
			var check_entry = _full_wave_sequence[_sequence_cursor]
			_sequence_cursor += 1
			_consumed_sequence_barrier = true
			_spawn_checkpoint_balloon(check_entry)
			_waiting_until_clear = true
			_force_next_command = false
			return

		var beat := _collect_next_beat()
		if not _beat_has_work(beat):
			var wait_sec := 0.0 if force else _beat_standalone_wait_sec(beat)
			if wait_sec > 0.0:
				if not await _sleep_sequence_delay(wait_sec):
					_force_next_command = false
					return
			continue
		if _round_is_closing():
			_sequence_active = false
			_waiting_until_clear = false
			_force_next_command = false
			return
		_begin_beat(beat)
		_pending_sequence_delay_sec = 0.0 if force else _beat_trailing_wait_sec(beat)
		_waiting_until_clear = true
		_force_next_command = false
		return

	_sequence_active = false
	_force_next_command = false
	if not _sky_is_clear_for_sequence():
		_waiting_until_clear = true
	else:
		_waiting_until_clear = false


func _sleep_sequence_delay(delay_sec: float) -> bool:
	if delay_sec <= 0.0:
		return true
	_sequence_delay_active = true
	_waiting_until_clear = true
	var token := _sequence_delay_token
	await get_tree().create_timer(delay_sec, false).timeout
	if token != _sequence_delay_token:
		return false
	_sequence_delay_active = false
	return _sequence_active and not _round_is_closing()


func _collect_next_beat() -> Array:
	var beat: Array = []
	while _sequence_cursor < _full_wave_sequence.size():
		var cmd := _sequence_cmd_at(_sequence_cursor)
		if cmd == "pineapples":
			## Leave cursor on keyword so `_launch_next_sequence_beat` starts the finale.
			break
		if cmd == "wait" and _force_next_command:
			_sequence_cursor += 1
			continue
		if _is_script_sfx_cmd(cmd):
			_handle_sfx_command(_full_wave_sequence[_sequence_cursor])
			_sequence_cursor += 1
			continue
		if _is_pace_cmd(cmd):
			_apply_pace_entry(_full_wave_sequence[_sequence_cursor])
			_sequence_cursor += 1
			continue
		if _is_gun_cmd(cmd):
			_apply_gun_entry(_full_wave_sequence[_sequence_cursor])
			_sequence_cursor += 1
			continue
		if _is_light_cmd(cmd):
			_apply_light_entry(_full_wave_sequence[_sequence_cursor])
			_sequence_cursor += 1
			continue
		if cmd == "ammo" or _is_sequence_barrier_cmd(cmd) or _is_clear_cmd(cmd) or _is_avoider_kill_cmd(cmd):
			break
		beat.append(_full_wave_sequence[_sequence_cursor])
		_sequence_cursor += 1
		if _force_next_command and _beat_entry_is_work(beat[beat.size() - 1]):
			break
	return beat


func _beat_has_work(beat: Array) -> bool:
	for entry in beat:
		if entry is Dictionary:
			var cmd := String(entry.get("cmd", "")).to_lower()
			if _is_launchable_spawn_cmd(cmd) or cmd == "balloon" or cmd == "pineapple":
				return true
			continue
		if typeof(entry) == TYPE_INT and int(entry) < 300:
			return true
	return false


func _beat_standalone_wait_sec(beat: Array) -> float:
	var total := 0.0
	for entry in beat:
		if entry is Dictionary and String(entry.get("cmd", "")).to_lower() == "wait":
			total += float(maxi(int(entry.get("ms", 0)), 0)) / 1000.0
	return total


func _beat_trailing_wait_sec(beat: Array) -> float:
	var last_work := -1
	for i in beat.size():
		if _beat_entry_is_work(beat[i]):
			last_work = i
	if last_work < 0:
		return 0.0
	var total := 0.0
	for i in range(last_work + 1, beat.size()):
		var entry = beat[i]
		if entry is Dictionary and String(entry.get("cmd", "")).to_lower() == "wait":
			total += float(maxi(int(entry.get("ms", 0)), 0)) / 1000.0
	return total


func _beat_entry_is_work(entry) -> bool:
	if entry is Dictionary:
		var cmd := String(entry.get("cmd", "")).to_lower()
		return _is_launchable_spawn_cmd(cmd) or cmd == "balloon" or cmd == "pineapple"
	return typeof(entry) == TYPE_INT and int(entry) < 300


func _begin_beat(sequence: Array) -> void:
	var rocks: Array = []
	var delays_sec: Array = []
	var pending_wait_ms = null
	var is_first_rock := true

	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait':
				pending_wait_ms = int(entry.get('ms', DEFAULT_LAUNCH_WAIT_MS))
				continue
			if _is_pace_cmd(cmd):
				_apply_pace_entry(entry)
				continue
			if _is_gun_cmd(cmd):
				_apply_gun_entry(entry)
				continue
			if _is_light_cmd(cmd):
				_apply_light_entry(entry)
				continue
			if cmd == 'rock-gap' or cmd == 'rock-red-gap':
				var gap_entries := _expand_rock_gap_entry(entry)
				for gap_i in gap_entries.size():
					var gap_entry: Dictionary = gap_entries[gap_i]
					if is_first_rock:
						if pending_wait_ms == null:
							delays_sec.append(0.0)
						else:
							delays_sec.append(float(int(pending_wait_ms)) / 1000.0)
						is_first_rock = false
					elif gap_i == 0:
						var gap_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
						delays_sec.append(float(gap_wait_ms) / 1000.0)
					else:
						## Fan stagger between columns in one gap command.
						delays_sec.append(float(GAP_FAN_STAGGER_MS) / 1000.0)
					pending_wait_ms = null
					var stamped_gap: Dictionary = gap_entry.duplicate()
					stamped_gap["gravity_scale"] = aim_launch_gravity_scale
					rocks.append(stamped_gap)
				continue
			if not _is_launchable_spawn_cmd(cmd):
				continue

			if is_first_rock:
				if pending_wait_ms == null:
					delays_sec.append(0.0)
				else:
					delays_sec.append(float(int(pending_wait_ms)) / 1000.0)
				is_first_rock = false
			else:
				var wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				delays_sec.append(float(wait_ms) / 1000.0)
			pending_wait_ms = null
			var stamped: Dictionary = entry.duplicate(true)
			stamped["gravity_scale"] = aim_launch_gravity_scale
			rocks.append(stamped)
			continue

		# Legacy integer format support while migrating.
		if typeof(entry) == TYPE_INT:
			if entry >= 300:
				continue
			if is_first_rock:
				if pending_wait_ms == null:
					delays_sec.append(0.0)
				else:
					delays_sec.append(float(int(pending_wait_ms)) / 1000.0)
				is_first_rock = false
			else:
				var legacy_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				delays_sec.append(float(legacy_wait_ms) / 1000.0)
			pending_wait_ms = null
			rocks.append(entry)

	manual_rock_sequence = rocks
	if not rocks.is_empty():
		_launched_rocks_this_sequence = true
	if _force_next_command:
		for i in delays_sec.size():
			delays_sec[i] = 0.0
	_launch_delays_sec = delays_sec
	_timed_event_schedule = _build_timed_event_schedule(sequence)
	enter_state(State.PREPARE_ROCKS)


## Gap columns from a parsed rock-gap entry. Default single gap at 8.
func _gap_columns_from_entry(entry: Dictionary) -> Array:
	var gaps: Array = []
	var raw = entry.get("gap_columns", [])
	if raw is Array and not raw.is_empty():
		for g in raw:
			var c := int(g)
			if c >= 1 and c <= COLUMN_COUNT and not gaps.has(c):
				gaps.append(c)
	if gaps.is_empty():
		var gap_col := int(entry.get("column", 8))
		if gap_col < 1 or gap_col > COLUMN_COUNT:
			gap_col = 8
		gaps = [gap_col]
	return gaps


## `rock-red-gap [gapCols…] [aim]` → rocks in columns 1–8 except the gaps.
## Default gap = 8. Aim row defaults to A; each rock aims its own column.
func _expand_rock_gap_entry(entry: Dictionary) -> Array:
	var gaps := _gap_columns_from_entry(entry)
	var aim_row := int(entry.get("aim_row", -1))
	if aim_row < 1 or aim_row > 3:
		aim_row = 1
	var out: Array = []
	for col in range(1, COLUMN_COUNT + 1):
		if gaps.has(col):
			continue
		out.append({
			"cmd": "rock-gap",
			"column": col,
			"spawn_row": -1,
			"aim_row": aim_row,
			"aim_column": col,
			"param": "",
		})
	return out


func _script_has_more_commands() -> bool:
	return _sequence_cursor < _full_wave_sequence.size()


func _round_is_closing() -> bool:
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return false
	return bool(round_manager.get("wave_ending")) or bool(round_manager.get("player_failed")) or bool(round_manager.get("game_over_triggered"))


## Called when remaining rocks hit 0. Returns true if the wave must stay open.
func try_continue_sequence() -> bool:
	if _pineapple_round_playing or _sequence_delay_active or _hold_out_finale_active:
		return true
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager != null:
		if bool(round_manager.get("pineapple_mode")):
			return true
		if _round_is_closing():
			_sequence_active = false
			_waiting_until_clear = false
			return false
	if _script_has_more_commands():
		_sequence_active = true
	if current_state == State.INACTIVE or current_state == State.ROUND_END:
		if not _script_has_more_commands() and not _waiting_until_clear and not _checkpoint_hold and not _has_live_ladder_balloons():
			_sequence_active = false
			_waiting_until_clear = false
			return false
	if _checkpoint_hold:
		return true
	if _ladder_hold:
		return true
	if _has_live_ladder_balloons() and not _script_has_more_commands():
		_waiting_until_clear = true
		return true
	if _advancing_sequence:
		return _sequence_active or _waiting_until_clear or _checkpoint_hold or _script_has_more_commands()
	if not _sky_is_clear_for_sequence():
		_waiting_until_clear = true
		return true

	if not _sequence_active and not _waiting_until_clear:
		return _has_live_checkpoint() or _script_has_more_commands()

	if not _sequence_active:
		_waiting_until_clear = false
		return _script_has_more_commands()

	_waiting_until_clear = false
	_auto_pulse_next_beat = true
	_advancing_sequence = true
	_launch_next_sequence_beat()
	_advancing_sequence = false
	if _hold_out_finale_active:
		return true
	if _sequence_active or _waiting_until_clear or _checkpoint_hold or _ladder_hold or _has_live_checkpoint() or _script_has_more_commands():
		return true
	if not _sky_is_clear_for_sequence():
		return true
	return false


func _sky_is_clear_for_sequence() -> bool:
	if _checkpoint_hold:
		return false
	if _ladder_hold:
		return false
	if _pineapple_round_playing:
		return false
	if _hold_out_finale_active:
		return false
	if _sequence_delay_active:
		return false
	if _has_live_checkpoint():
		return false
	if _has_live_ladder_balloons():
		return false
	## Pineapple / balloon-only beats have no PREPARE_ROCK bodies. Without this,
	## `_process` treats the sky as clear and skips the pulse, so they never spawn.
	if current_state == State.PREPARE_ROCKS:
		return false
	if _timed_events_running:
		return false
	if _stream_launches_remaining > 0:
		return false
	if _any_live_round_rocks():
		return false
	if _any_live_pineapples():
		return false
	if _any_live_bonus_targets():
		return false
	return true


func is_holding_wave() -> bool:
	if _quiz_hold:
		return true
	if _pineapple_round_playing:
		return true
	if _hold_out_finale_active:
		return true
	if _script_has_more_commands():
		return true
	if _sequence_active or _waiting_until_clear or _checkpoint_hold or _ladder_hold:
		return true
	if _has_live_checkpoint():
		return true
	if _has_live_ladder_balloons():
		return true
	return not _sky_is_clear_for_sequence()


func get_sequence_cursor() -> int:
	return _sequence_cursor


func pause_sequence_for_continue() -> void:
	_paused_for_continue = true
	_sequence_active = false
	_sequence_delay_active = false
	_advancing_sequence = false
	_auto_pulse_next_beat = false
	_waiting_until_clear = true
	_timed_events_running = false
	_stream_launches_remaining = 0
	_cancel_pending_launches()
	_timed_event_epoch += 1
	_cancel_wave_telegraph()
	freeze_live_rocks(true)


func freeze_live_rocks(frozen: bool) -> void:
	if not has_node("Container_1"):
		return
	_freeze_rigid_children($Container_1, frozen)
	var burst_host := get_node_or_null("CardinalBurstHost")
	if burst_host:
		_freeze_rigid_children(burst_host, frozen)


func _freeze_rigid_children(host: Node, frozen: bool) -> void:
	for body in host.get_children():
		if body is RigidBody3D:
			(body as RigidBody3D).freeze = frozen
			if frozen:
				(body as RigidBody3D).sleeping = true
			else:
				(body as RigidBody3D).sleeping = false


func get_cardinal_burst_host() -> Node3D:
	var host := get_node_or_null("CardinalBurstHost") as Node3D
	if host == null:
		host = Node3D.new()
		host.name = "CardinalBurstHost"
		add_child(host)
	return host


func clear_cardinal_bursts() -> void:
	var host := get_node_or_null("CardinalBurstHost")
	if host == null:
		return
	for child in host.get_children():
		if child.has_method("dismiss"):
			child.dismiss()
		elif is_instance_valid(child):
			child.queue_free()


## Unfreeze / restart after continue. Always begins the script from spawn 0.
func resume_from_continue() -> bool:
	_paused_for_continue = false
	freeze_live_rocks(false)
	var seq: Array = _full_wave_sequence.duplicate(true)
	if seq.is_empty():
		return false
	start_manual_rock_round(seq, 0)
	return true


func _has_live_checkpoint() -> bool:
	if _active_checkpoint != null and is_instance_valid(_active_checkpoint):
		if _active_checkpoint.has_method("is_blocking_sky"):
			return bool(_active_checkpoint.is_blocking_sky())
		return true
	return false


func _spawn_checkpoint_balloon(entry = null) -> void:
	if _active_checkpoint != null and is_instance_valid(_active_checkpoint):
		if bool(_active_checkpoint.get("transition_locked")):
			return
	_dismiss_checkpoint()
	var host := get_tree().get_first_node_in_group("checkpoint_container")
	if host == null:
		host = get_tree().current_scene
	if host == null:
		host = self
	var checkpoint: Node = CHECKPOINT_SCENE.instantiate()
	host.add_child(checkpoint)
	_active_checkpoint = checkpoint
	_checkpoint_hold = true
	var rest := _checkpoint_rest_from_entry(entry)
	if checkpoint.has_method("arrive_from_below"):
		if rest.is_finite():
			checkpoint.arrive_from_below(rest)
		else:
			checkpoint.arrive_from_below()
	_latch_round_timer_for_checkpoint()


func _spawn_ladder_balloon(entry = null) -> void:
	var cmd := ""
	if entry is Dictionary:
		cmd = String(entry.get("cmd", "")).to_lower()
	var kinds: PackedStringArray = []
	if cmd == "ladder":
		kinds = PackedStringArray(["bank", "multiply"])
	elif cmd == "balloon-bank":
		kinds = PackedStringArray(["bank"])
	else:
		kinds = PackedStringArray(["multiply"])

	var host := get_tree().get_first_node_in_group("checkpoint_container")
	if host == null:
		host = get_tree().current_scene
	if host == null:
		host = self

	for kind in kinds:
		if _has_live_ladder_kind(kind):
			continue
		var balloon: Node = CHECKPOINT_SCENE.instantiate()
		balloon.set_script(LADDER_BALLOON_SCRIPT)
		balloon.set("choice_kind", kind)
		host.add_child(balloon)
		var rest := Vector3.INF
		if balloon.has_method("default_rest_pos"):
			rest = balloon.default_rest_pos()
		if balloon.has_method("arrive_from_below"):
			balloon.arrive_from_below(rest)


func _has_live_ladder_kind(kind: String) -> bool:
	for node in get_tree().get_nodes_in_group("ladder_choice"):
		if not is_instance_valid(node):
			continue
		if String(node.get("choice_kind")) != kind:
			continue
		if bool(node.get("_consumed")):
			continue
		return true
	return false


func _has_live_ladder_balloons() -> bool:
	for node in get_tree().get_nodes_in_group("ladder_choice"):
		if not is_instance_valid(node):
			continue
		if bool(node.get("_consumed")):
			continue
		if node.has_method("is_blocking_sky") and not bool(node.is_blocking_sky()):
			continue
		return true
	return false


func _checkpoint_rest_from_entry(entry) -> Vector3:
	if not (entry is Dictionary):
		return Vector3.INF
	var row := int(entry.get("row", -1))
	var column := int(entry.get("column", -1))
	if row < 1 or column < 1:
		return Vector3.INF
	var balloons := get_tree().get_first_node_in_group("balloon_container")
	if balloons and balloons.has_method("balloon_cell_world_position"):
		return balloons.balloon_cell_world_position(row, column)
	var x := 7.0 + float(column - 1) * -2.0
	var y := 6.5
	match row:
		2:
			y = 3.5
		3:
			y = 0.5
	return Vector3(x, y, 22.5)


func _dismiss_checkpoint() -> void:
	_unlatch_round_timer_for_checkpoint()
	if _active_checkpoint != null and is_instance_valid(_active_checkpoint):
		if _active_checkpoint.has_method("dismiss_without_shot"):
			_active_checkpoint.dismiss_without_shot()
		elif is_instance_valid(_active_checkpoint):
			_active_checkpoint.queue_free()
	_active_checkpoint = null


func _latch_round_timer_for_checkpoint() -> void:
	var timer := _round_timer_node()
	if timer and timer.has_method("latch_timer"):
		timer.latch_timer()


func _unlatch_round_timer_for_checkpoint() -> void:
	var timer := _round_timer_node()
	if timer and timer.has_method("unlatch_timer"):
		timer.unlatch_timer()


func _round_timer_node() -> Node:
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm:
		var timer = rm.get("round_timer")
		if timer:
			return timer
	return get_tree().get_first_node_in_group("round_timer")


func _dismiss_ladder_balloons() -> void:
	_ladder_hold = false
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("ladder_choice"):
		if not is_instance_valid(node):
			continue
		if node.has_method("dismiss_without_shot"):
			node.dismiss_without_shot()
		else:
			node.queue_free()


func _spawn_or_queue_ammo_balloon(entry = null) -> void:
	if _should_defer_ammo_spawn():
		_pending_ammo_entries.append(entry)
		return
	_spawn_ammo_balloon(entry)


func _should_defer_ammo_spawn() -> bool:
	if _pineapple_round_playing or _hold_out_finale_active:
		return true
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return false
	if bool(round_manager.get("pineapple_mode")):
		return true
	if round_manager.has_method("is_checkpoint_ceremony") and bool(round_manager.is_checkpoint_ceremony()):
		return true
	if bool(round_manager.get("_checkpoint_advancing")):
		return true
	return false


func flush_pending_ammo() -> void:
	if _pending_ammo_entries.is_empty():
		return
	var pending: Array = _pending_ammo_entries.duplicate()
	_pending_ammo_entries.clear()
	for entry in pending:
		_spawn_ammo_balloon(entry)


func _spawn_ammo_balloon(entry = null) -> void:
	var row := 3
	var column := 6
	if entry is Dictionary:
		row = int(entry.get("row", 3))
		column = int(entry.get("column", 6))
		if row < 1:
			row = 3
		if column < 1:
			column = 6
	for node in get_tree().get_nodes_in_group("ammo_balloon"):
		if node == null or not is_instance_valid(node):
			continue
		if int(node.get("occupy_row")) != row or int(node.get("occupy_column")) != column:
			continue
		return
	var host := get_tree().get_first_node_in_group("checkpoint_container")
	if host == null:
		host = get_tree().current_scene
	if host == null:
		host = self
	var ammo_balloon: Node = AMMO_BALLOON_SCENE.instantiate()
	host.add_child(ammo_balloon)
	if ammo_balloon.has_method("configure_from_entry") and entry is Dictionary:
		ammo_balloon.configure_from_entry(entry)
	var rest := _checkpoint_rest_from_entry(entry)
	if not rest.is_finite():
		rest = _checkpoint_rest_from_entry({
			'row': 3,
			'column': 6,
		})
	if ammo_balloon.has_method("arrive_from_below"):
		ammo_balloon.arrive_from_below(rest)


func _clear_ammo_balloons() -> void:
	for node in get_tree().get_nodes_in_group("ammo_balloon"):
		if node != null and is_instance_valid(node) and node.has_method("pop_without_reward"):
			node.pop_without_reward()


func _dismiss_ammo_balloons() -> void:
	for node in get_tree().get_nodes_in_group("ammo_balloon"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("dismiss_without_shot"):
			node.dismiss_without_shot()
		else:
			node.queue_free()


func _handle_clear_command(entry) -> void:
	if entry is Dictionary and String(entry.get("cmd", "")).to_lower() == "clear-ammo":
		_clear_ammo_balloons()
		return
	if entry is Dictionary and String(entry.get("cmd", "")).to_lower() == "clear-balloon":
		var row := int(entry.get("row", -1))
		var column := int(entry.get("column", -1))
		if row >= 1 and column >= 1:
			_clear_balloon_at(row, column)
		return
	_clear_live_balloons()


func _handle_avoider_kill_command() -> void:
	if not has_node("Container_1"):
		return
	var live: Array = []
	for body in $Container_1.get_children():
		if not (body is RockInstance):
			continue
		if body.rock_type != RockInstance.RockSize.AVOIDER:
			continue
		live.append(body)
	for body in live:
		if is_instance_valid(body) and body.has_method("kill_avoider_from_script"):
			body.kill_avoider_from_script()


func _handle_sfx_command(entry) -> void:
	if entry == null or not (entry is Dictionary):
		return
	var cmd := String(entry.get("cmd", "")).to_lower()
	var sfx_name := String(entry.get("name", "")).strip_edges()
	if sfx_name.is_empty():
		push_warning("RockManager: %s needs a file name under res://sfx/ (e.g. Windmill_YokoKanno)" % cmd)
		return
	if cmd == "sfx-play":
		_script_sfx_play(sfx_name, float(entry.get("volume_db", -20.0)))
		return
	if cmd == "sfx-stop":
		_script_sfx_stop(sfx_name, float(entry.get("fade_sec", SCRIPT_SFX_LEAVE_FADE_SEC)))
		return
	if cmd == "sfx-faster":
		_script_sfx_nudge_pitch(sfx_name, SCRIPT_SFX_PITCH_STEP)
		return
	if cmd == "sfx-slower":
		_script_sfx_nudge_pitch(sfx_name, -SCRIPT_SFX_PITCH_STEP)


func _script_sfx_play(sfx_name: String, volume_db: float) -> void:
	var key := sfx_name.get_file().get_basename()
	# Restart if the same cue is already playing.
	if _script_sfx_players.has(key):
		var existing = _script_sfx_players[key]
		if is_instance_valid(existing):
			existing.stop()
			existing.queue_free()
		_script_sfx_players.erase(key)
	_script_sfx_clear_pitch(key)
	_script_sfx_fade_tokens[key] = int(_script_sfx_fade_tokens.get(key, 0)) + 1

	var stream := _load_sfx_stream(sfx_name)
	if stream == null:
		push_warning("RockManager: could not load sfx '%s' from res://sfx/" % sfx_name)
		return

	var player := AudioStreamPlayer.new()
	player.name = "ScriptSfx_%s" % key
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.bus = &"MusicBus"
	add_child(player)
	_script_sfx_players[key] = player
	_script_sfx_pitch_target[key] = 1.0
	player.finished.connect(func() -> void:
		if _script_sfx_players.get(key) == player:
			_script_sfx_players.erase(key)
		_script_sfx_clear_pitch(key)
		if is_instance_valid(player):
			player.queue_free()
	)
	player.play()


func _script_sfx_nudge_pitch(sfx_name: String, delta: float) -> void:
	var key := sfx_name.get_file().get_basename()
	if not _script_sfx_players.has(key):
		push_warning("RockManager: %s — no playing sfx named '%s'" % ["sfx-faster" if delta > 0.0 else "sfx-slower", sfx_name])
		return
	var player: AudioStreamPlayer = _script_sfx_players[key]
	if not is_instance_valid(player):
		_script_sfx_players.erase(key)
		_script_sfx_clear_pitch(key)
		return
	var from := float(_script_sfx_pitch_target.get(key, player.pitch_scale))
	var target := maxf(from + delta, 0.01)
	_script_sfx_pitch_target[key] = target
	if _script_sfx_pitch_tweens.has(key):
		var old = _script_sfx_pitch_tweens[key]
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		_script_sfx_pitch_tweens.erase(key)
	var tween := create_tween()
	tween.tween_property(player, "pitch_scale", target, SCRIPT_SFX_PITCH_RAMP_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_script_sfx_pitch_tweens[key] = tween


func _script_sfx_clear_pitch(key: String) -> void:
	if _script_sfx_pitch_tweens.has(key):
		var old = _script_sfx_pitch_tweens[key]
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		_script_sfx_pitch_tweens.erase(key)
	_script_sfx_pitch_target.erase(key)


func _script_sfx_stop(sfx_name: String, fade_sec: float) -> void:
	var key := sfx_name.get_file().get_basename()
	if not _script_sfx_players.has(key):
		_script_sfx_clear_pitch(key)
		return
	var player: AudioStreamPlayer = _script_sfx_players[key]
	if not is_instance_valid(player):
		_script_sfx_players.erase(key)
		_script_sfx_clear_pitch(key)
		return

	var token := int(_script_sfx_fade_tokens.get(key, 0)) + 1
	_script_sfx_fade_tokens[key] = token
	_script_sfx_clear_pitch(key)
	var dur := maxf(fade_sec, 0.0)
	if dur <= 0.001:
		_script_sfx_players.erase(key)
		player.stop()
		player.queue_free()
		return

	var tween := create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(player, "volume_db", -80.0, dur)
	await tween.finished
	if int(_script_sfx_fade_tokens.get(key, 0)) != token:
		return
	if _script_sfx_players.get(key) == player:
		_script_sfx_players.erase(key)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()


func _script_sfx_stop_all(fade_sec: float = SCRIPT_SFX_LEAVE_FADE_SEC) -> void:
	var keys: Array = _script_sfx_players.keys()
	for key in keys:
		_script_sfx_stop(String(key), fade_sec)


func stop_script_sfx_immediate() -> void:
	_script_sfx_stop_all(0.0)


func _load_sfx_stream(sfx_name: String) -> AudioStream:
	var stem := String(sfx_name).strip_edges()
	if stem.is_empty():
		return null
	# Allow `Windmill_YokoKanno`, `Windmill_YokoKanno.ogg`, or a subpath under sfx/.
	var candidates: PackedStringArray = []
	if stem.begins_with("res://"):
		candidates.append(stem)
	else:
		var base := stem
		if base.begins_with("sfx/"):
			base = base.substr(4)
		var has_ext := base.contains(".")
		if has_ext:
			candidates.append("res://sfx/%s" % base)
		else:
			for ext in [".ogg", ".wav", ".mp3"]:
				candidates.append("res://sfx/%s%s" % [base, ext])
			for ext in [".ogg", ".wav", ".mp3"]:
				candidates.append("res://sfx/spare_songs/%s%s" % [base, ext])

	for path in candidates:
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				return res
	return null


func _clear_balloon_at(row: int, column: int) -> void:
	var host := get_tree().get_first_node_in_group("balloon_container")
	if host != null and host.has_method("clear_balloon_at"):
		host.clear_balloon_at(row, column)
		return
	if host == null:
		return
	for child in host.get_children():
		if not (child is StaticBody3D):
			continue
		if bool(child.get("behind_player")):
			continue
		if not bool(child.get("rock_activated")):
			continue
		if int(child.get("occupy_row")) != row or int(child.get("occupy_column")) != column:
			continue
		gl_PlayerState.add_to_cash_pool(10, child.global_position)
		if child.has_method("drift_away_for_checkpoint"):
			child.drift_away_for_checkpoint()
		return


func _clear_live_balloons() -> void:
	var host := get_tree().get_first_node_in_group("balloon_container")
	if host != null and host.has_method("clear_live_balloons"):
		host.clear_live_balloons()
		return
	if host == null:
		return
	for child in host.get_children():
		if not (child is StaticBody3D):
			continue
		if bool(child.get("behind_player")):
			continue
		if not bool(child.get("rock_activated")):
			continue
		gl_PlayerState.add_to_cash_pool(10, child.global_position)
		if child.has_method("drift_away_for_checkpoint"):
			child.drift_away_for_checkpoint()


func _cancel_sequence() -> void:
	_paused_for_continue = false
	_sequence_active = false
	_waiting_until_clear = false
	_checkpoint_hold = false
	_ladder_hold = false
	_auto_pulse_next_beat = false
	_advancing_sequence = false
	_timed_events_running = false
	_stream_launches_remaining = 0
	_pineapple_round_playing = false
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_sequence_delay_token += 1
	_force_next_command = false
	_instant_sequence_pulse = false
	_launched_rocks_this_sequence = false
	_launched_scripted_pineapple = false
	## Abort / replay must never resume mid-script (especially a peeled pineapple block).
	_sequence_cursor = 0
	_hold_out_finale_token += 1
	_hold_out_finale_active = false
	_hold_out_finale_spawning = false
	_hold_out_pineapple_finale.clear()
	_dismiss_checkpoint()
	_dismiss_ladder_balloons()
	_dismiss_ammo_balloons()
	_pending_ammo_entries.clear()
	_script_sfx_stop_all()
	_reset_pineapple_spawn_bookkeeping()


func _reset_pineapple_spawn_bookkeeping() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("pineapple_container"):
		if node != null and node.has_method("clear_spawn_bookkeeping"):
			node.clear_spawn_bookkeeping()


func begin_checkpoint_hold() -> void:
	_checkpoint_hold = true
	_waiting_until_clear = true


func notify_clearable_destroyed() -> void:
	if _advancing_sequence or _sequence_delay_active:
		return
	if not _waiting_until_clear and not _checkpoint_hold:
		return
	try_continue_sequence()


## Scripted pineapple left play. If it was the last one and nothing else remains, end the round.
func notify_pineapple_left_play() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _round_is_closing() or _pineapple_round_playing:
		return
	if not _launched_scripted_pineapple:
		return
	if _hold_out_finale_spawning:
		return
	## Dual launches share a fanfare; don't treat leftover pending/fanfare as a live pineapple.
	if _any_airborne_pineapples():
		return
	if _sequence_has_more_play_work():
		return
	_sequence_delay_token += 1
	_sequence_delay_active = false
	_pending_sequence_delay_sec = 0.0
	_sequence_active = false
	_waiting_until_clear = false
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("finish_round_after_last_pineapple"):
		round_manager.finish_round_after_last_pineapple()


## Sequence finished and the sky is empty — tally even if remaining-rocks already hit 0.
func _finish_round_if_sequence_idle() -> void:
	if _script_has_more_commands() or _checkpoint_hold or _ladder_hold or _pineapple_round_playing:
		return
	if _hold_out_finale_spawning:
		return
	if _any_airborne_pineapples() or _any_live_round_rocks() or _timed_events_running:
		return
	if _round_is_closing():
		return
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return
	if _launched_scripted_pineapple and round_manager.has_method("finish_round_after_last_pineapple"):
		round_manager.finish_round_after_last_pineapple()
		return
	if round_manager.has_method("check_if_rocks_still_in_air"):
		round_manager.check_if_rocks_still_in_air()


func _sequence_has_more_play_work() -> bool:
	for i in range(_sequence_cursor, _full_wave_sequence.size()):
		var entry = _full_wave_sequence[i]
		if typeof(entry) == TYPE_INT:
			if int(entry) < 300:
				return true
			continue
		if not (entry is Dictionary):
			continue
		var cmd := String(entry.get("cmd", "")).to_lower()
		if cmd == "wait" or cmd == "wait-until-clear" or _is_clear_cmd(cmd) or _is_pace_cmd(cmd) or _is_gun_cmd(cmd) or _is_script_sfx_cmd(cmd) or _is_light_cmd(cmd):
			continue
		if cmd == "pineapples" or _is_launchable_spawn_cmd(cmd) or cmd == "balloon" or cmd == "pineapple" or cmd == "ammo" or _is_balloon_check_cmd(cmd) or _is_ladder_balloon_cmd(cmd) or cmd == "bonus-target" or _is_avoider_kill_cmd(cmd):
			return true
		## Markers / unknown lines must not keep the round open forever.
		continue
	return false


## Checkpoint was shot — stop treating it as a live hold. Sequence continues via end_checkpoint_hold.
func finish_checkpoint_round() -> void:
	_checkpoint_hold = false
	_ladder_hold = false
	_sequence_active = false
	_waiting_until_clear = false
	_auto_pulse_next_beat = false
	_advancing_sequence = false
	_active_checkpoint = null


func end_checkpoint_hold() -> void:
	_unlatch_round_timer_for_checkpoint()
	_checkpoint_hold = false
	_ladder_hold = false
	_active_checkpoint = null
	if _script_has_more_commands():
		_sequence_active = true
		_waiting_until_clear = true
		if try_continue_sequence():
			return
	_sequence_active = false
	_waiting_until_clear = false
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("check_if_rocks_still_in_air"):
		round_manager.check_if_rocks_still_in_air()


## Mid-round balloons (after a `wait`) and pineapples share the rock absolute timeline.
## Pending waits are NOT consumed by balloons/pineapples (rock stagger stays unchanged).
func _build_timed_event_schedule(sequence: Array) -> Array:
	var schedule: Array = []
	var abs_t := 0.0
	var pending_wait_ms = null
	var is_first_rock := true
	var seen_wait := false

	for entry in sequence:
		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			if cmd == 'wait' or cmd == 'wait-until-clear':
				seen_wait = true
				if cmd == 'wait':
					pending_wait_ms = int(entry.get('ms', DEFAULT_LAUNCH_WAIT_MS))
				continue

			if cmd == 'balloon':
				# Shop already spawned balloons that appear before the first wait.
				# Continuation / post-wait beats must still fly them in.
				if seen_wait or _auto_pulse_next_beat or _force_mid_round_balloons:
					var balloon_extra := 0.0
					if pending_wait_ms != null:
						balloon_extra = float(pending_wait_ms) / 1000.0
					schedule.append({
						'kind': 'balloon',
						'entry': entry,
						'time_sec': abs_t + balloon_extra,
					})
				continue

			if cmd == 'pineapple':
				var pineapple_extra := 0.0
				if pending_wait_ms != null:
					pineapple_extra = float(pending_wait_ms) / 1000.0
				schedule.append({
					'kind': 'pineapple',
					'entry': entry,
					'time_sec': abs_t + pineapple_extra,
				})
				continue

			if cmd == 'rock-gap' or cmd == 'rock-red-gap':
				var gap_n := _expand_rock_gap_entry(entry).size()
				if gap_n <= 0:
					continue
				if is_first_rock:
					is_first_rock = false
					if pending_wait_ms != null:
						abs_t += float(int(pending_wait_ms)) / 1000.0
				else:
					var gap_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
					abs_t += float(gap_wait_ms) / 1000.0
				pending_wait_ms = null
				if gap_n > 1:
					abs_t += float(GAP_FAN_STAGGER_MS) / 1000.0 * float(gap_n - 1)
				continue

			if not _is_launchable_spawn_cmd(cmd):
				continue

			if is_first_rock:
				is_first_rock = false
				if pending_wait_ms != null:
					abs_t += float(int(pending_wait_ms)) / 1000.0
			else:
				var wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				abs_t += float(wait_ms) / 1000.0
			pending_wait_ms = null
			continue

		if typeof(entry) == TYPE_INT:
			var code: int = entry
			# Legacy balloon codes after a wait → mid-round.
			if code == 399 or (code > 300 and code <= 400):
				if seen_wait:
					var legacy_extra := 0.0
					if pending_wait_ms != null:
						legacy_extra = float(pending_wait_ms) / 1000.0
					var legacy_entry: Dictionary
					if code == 399:
						legacy_entry = {'cmd': 'balloon', 'all': true}
					else:
						legacy_entry = {
							'cmd': 'balloon',
							'row': int((code - 300) / 10),
							'column': (code - 300) % 10,
						}
					schedule.append({
						'kind': 'balloon',
						'entry': legacy_entry,
						'time_sec': abs_t + legacy_extra,
					})
				continue
			if code >= 300:
				continue
			if is_first_rock:
				is_first_rock = false
				if pending_wait_ms != null:
					abs_t += float(int(pending_wait_ms)) / 1000.0
			else:
				var legacy_wait_ms: int = DEFAULT_LAUNCH_WAIT_MS if pending_wait_ms == null else int(pending_wait_ms)
				abs_t += float(legacy_wait_ms) / 1000.0
			pending_wait_ms = null

	return schedule
	
func update_prepare_rocks() -> void:
	var temp_rock_array : Array = manual_rock_sequence
	splash_zone.reset_detected_bodies()

	var container_children := $Container_1.get_children()
	var available_bodies : Array = []

	# Leave in-flight / dying rocks alone so the 36-slot pool can recycle them later.
	for i in container_children:
		if _rock_slot_busy(i):
			continue
		available_bodies.append(i)

	# Telegraph / first-pulse preview uses whatever is free now.
	# bounce_rocks streams the rest of the beat as slots open.
	var preview_count := mini(temp_rock_array.size(), available_bodies.size())
	rocks_limit = preview_count

	var active_bodies : Array = []
	for i in available_bodies.size():
		var body = available_bodies[i]
		if i < preview_count:
			active_bodies.append(body)
		else:
			body.enter_state(body.State.INACTIVE)

	assign_manual_rock_positions(active_bodies)

	for pointer in preview_count:
		if pointer >= active_bodies.size():
			break
		active_bodies[pointer].rock_type = _spawn_entry_to_rock_type(temp_rock_array[pointer])
		active_bodies[pointer].enter_state(active_bodies[pointer].State.PREPARE_ROCK)

	_build_wave_telegraph_plan(active_bodies)
	## No full-wave telegraph — blinks happen per rock just before launch.
	if _auto_pulse_next_beat:
		_auto_pulse_next_beat = false
		_pulse_continuation_beat()


func _pulse_continuation_beat() -> void:
	if not _instant_sequence_pulse:
		await get_tree().create_timer(0.4, false).timeout
	if _paused_for_continue or not _sequence_active or _round_is_closing():
		return
	if current_state == State.PREPARE_ROCKS:
		enter_state(State.PULSE_ROCKS)


## Slots still mid-flight or dying must not be reclaimed for the next beat.
func _rock_slot_busy(body) -> bool:
	if not (body is RockInstance):
		return true
	return body.current_state != body.State.INACTIVE


func _spawn_entry_to_rock_type(entry) -> int:
	if entry is Dictionary:
		match String(entry.get('cmd', '')).to_lower():
			'rock-invisible':
				return RockInstance.RockSize.INVISIBLE
			'rock-black':
				return RockInstance.RockSize.HAZARD
			'rock-fake':
				return RockInstance.RockSize.FAKE
			'rock-pigeon':
				return RockInstance.RockSize.SMALL_2
			'red_rock_error':
				return RockInstance.RockSize.RED_ROCK_ERROR
			'smokecan':
				return RockInstance.RockSize.SMOKECAN
			'rock-avoider':
				return RockInstance.RockSize.AVOIDER
			'rock-red-attacker', 'red-attacker':
				return RockInstance.RockSize.RED_ATTACKER
			'rock-gap', 'rock-red-gap':
				return RockInstance.RockSize.GAP
			'rock-chaser':
				return RockInstance.RockSize.CHASER
			'rock-juggle':
				return RockInstance.RockSize.JUGGLE
			'rock-grey':
				return RockInstance.RockSize.GREY
			'rock-stay', 'rock-still':
				return RockInstance.RockSize.STAY
			'rock-stay-black':
				return RockInstance.RockSize.STAY_BLACK
			'rock-cardinal':
				return RockInstance.RockSize.CARDINAL
			'mothership':
				return RockInstance.RockSize.MOTHERSHIP
			'crate':
				return RockInstance.RockSize.CRATE
			_:
				return RockInstance.RockSize.SMALL

	# Legacy integer encoding: type = value / 10 (1-8 → SMALL, 41-48 → HAZARD)
	if typeof(entry) == TYPE_INT:
		return int(entry / 10)

	return RockInstance.RockSize.SMALL


func _is_launchable_spawn_cmd(cmd: String) -> bool:
	return (
		cmd == 'rock'
		or cmd == 'rock-invisible'
		or cmd == 'rock-black'
		or cmd == 'rock-fake'
		or cmd == 'rock-pigeon'
		or cmd == 'red_rock_error'
		or cmd == 'smokecan'
		or cmd == 'rock-avoider'
		or cmd == 'rock-red-attacker'
		or cmd == 'red-attacker'
		or cmd == 'rock-gap'
		or cmd == 'rock-red-gap'
		or cmd == 'rock-chaser'
		or cmd == 'rock-juggle'
		or cmd == 'rock-grey'
		or cmd == 'rock-stay'
		or cmd == 'rock-stay-black'
		or cmd == 'rock-cardinal'
		or cmd == 'rock-still'
		or cmd == 'mothership'
		or cmd == 'crate'
	)


func update_pulse_rocks() -> void:
	_cancel_wave_telegraph()
	splash_zone.activate_splash_zone()

	pick_convergence_point()

	_bounds_check_accum = 0.0
	_bounds_check_active = true
	
	_run_timed_event_spawns()
	bounce_rocks()


func _run_timed_event_spawns() -> void:
	if _timed_event_schedule.is_empty():
		_timed_events_running = false
		return

	var balloon_container := get_tree().get_first_node_in_group('balloon_container')
	var pineapple_launcher: Node = null
	for node in get_tree().get_nodes_in_group('pineapple_container'):
		if node.has_method('launch_from_spawn_entry'):
			pineapple_launcher = node
			break

	_timed_event_epoch += 1
	var epoch := _timed_event_epoch
	_timed_events_running = true
	var schedule: Array = _timed_event_schedule.duplicate(true)
	var elapsed := 0.0

	for item in schedule:
		if _paused_for_continue or epoch != _timed_event_epoch or _round_is_closing():
			_timed_events_running = false
			return
		if current_state != State.PULSE_ROCKS:
			_timed_events_running = false
			return

		var time_sec: float = float(item.get('time_sec', 0.0))
		var wait_for: float = time_sec - elapsed
		if wait_for > 0.0:
			await get_tree().create_timer(wait_for, false).timeout
			elapsed += wait_for

		if _paused_for_continue or epoch != _timed_event_epoch or _round_is_closing():
			_timed_events_running = false
			return
		if current_state != State.PULSE_ROCKS:
			_timed_events_running = false
			return

		var kind: String = String(item.get('kind', ''))
		var entry = item.get('entry', {})
		if not (entry is Dictionary):
			continue

		match kind:
			'balloon':
				if balloon_container and balloon_container.has_method('spawn_balloon_entry'):
					await balloon_container.spawn_balloon_entry(entry)
			'pineapple':
				if pineapple_launcher and pineapple_launcher.has_method('launch_from_spawn_entry'):
					_launched_scripted_pineapple = true
					await pineapple_launcher.launch_from_spawn_entry(entry)

	if epoch == _timed_event_epoch:
		_timed_events_running = false


func check_rocks_out_of_bounds() -> void:
	var camera := _get_bounds_camera()
	if camera == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	for body in $Container_1.get_children():
		if !(body is RockInstance):
			continue
		# Same eligibility as splash_zone: only live round rocks can miss.
		if body.current_state != body.State.ACTIVE:
			continue
		if body.rock_activated == false:
			continue
		# Explicit opt-out (e.g. smokecan fly-off) — not a camera miss.
		if body.ignores_x_out_of_bounds:
			continue
		if body.rock_type == RockInstance.RockSize.AVOIDER and not body.avoider_destroys_on_out_of_bounds:
			continue
		## Red-attacker always uses camera OOB cull (no strike — see _oob_miss_causes_strike).

		var world_pos : Vector3 = body.global_position
		if _is_inside_camera_viewport(camera, world_pos, viewport_size):
			body.has_entered_camera_view = true
			continue

		# Spawned off-screen and still entering play — wait until they've been seen.
		if not body.has_entered_camera_view:
			continue

		if _is_outside_camera_miss_bounds(camera, world_pos, viewport_size):
			var side := _get_camera_miss_side(camera, world_pos, viewport_size)
			deactivate_out_of_bounds_rock(body, side)


func _get_bounds_camera() -> Camera3D:
	if bounds_camera != null and is_instance_valid(bounds_camera):
		return bounds_camera
	var active := get_viewport().get_camera_3d()
	if active != null:
		return active
	return get_tree().get_first_node_in_group('player_cam') as Camera3D


## True when the rock is currently inside the visible viewport rectangle (no margin).
func _is_inside_camera_viewport(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> bool:
	if camera.is_position_behind(world_pos):
		return false
	var screen := camera.unproject_position(world_pos)
	return (
		screen.x >= 0.0
		and screen.x <= viewport_size.x
		and screen.y >= 0.0
		and screen.y <= viewport_size.y
	)


## Left / right / bottom past the viewport + margin. Top is never a miss.
## Behind the camera counts as out once the rock has already been on-screen.
func _is_outside_camera_miss_bounds(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> bool:
	return _get_camera_miss_side(camera, world_pos, viewport_size) != OobSide.NONE


func _get_camera_miss_side(camera: Camera3D, world_pos: Vector3, viewport_size: Vector2) -> OobSide:
	if camera.is_position_behind(world_pos):
		return OobSide.BEHIND

	var screen := camera.unproject_position(world_pos)
	if screen.x < -oob_margin_left_px:
		return OobSide.LEFT
	if screen.x > viewport_size.x + oob_margin_right_px:
		return OobSide.RIGHT
	if screen.y > viewport_size.y + oob_margin_bottom_px:
		return OobSide.BOTTOM
	# screen.y < 0 (above the camera) is allowed
	return OobSide.NONE


## Pending world position for the next strike spark/shake (rock location).
var _pending_strike_feedback_pos := Vector3.ZERO
var _has_pending_strike_feedback_pos := false
var _suppress_next_strike_particles := false


func deactivate_out_of_bounds_rock(body: RockInstance, side: OobSide = OobSide.NONE) -> void:
	if body.current_state != RockInstance.State.ACTIVE:
		return
	if body.rock_activated == false:
		return

	# Capture before MISSED → reset_stats() clears rock_type_name.
	var missed_rock_type_name: String = body.rock_type_name
	var miss_pos: Vector3 = body.global_position
	body.rock_activated = false
	## Strike-worthy only — black rocks leave quietly (no OOB hit sting).
	if _oob_miss_should_show_feedback(missed_rock_type_name) and body.has_method('out_of_bounds'):
		body.out_of_bounds()
	body.enter_state(body.State.MISSED)
	if _oob_miss_causes_strike(missed_rock_type_name):
		set_strike_feedback_origin(miss_pos)
	gl_PlayerState.log_rock_missed(missed_rock_type_name)

	# Non-clearable exits (black / smokecan / avoider / red-attacker) can leave remaining at 0 forever.
	if not _oob_miss_should_show_feedback(missed_rock_type_name) \
			or missed_rock_type_name.contains("hazard") \
			or missed_rock_type_name.contains("red_attacker"):
		call_deferred("check_wave_clear_if_no_live_rocks")

	# Strike / miss feedback. Must-hit OOB strikes get this via EventBus.add_strike instead
	# (avoids doubling the shake/particles). Red-attacker: feedback yes, strike no.
	if oob_miss_feedback_enabled and _oob_miss_should_show_feedback(missed_rock_type_name) \
			and not _oob_miss_causes_strike(missed_rock_type_name):
		_play_oob_miss_feedback(miss_pos, side)


func _oob_miss_causes_strike(rock_type_name: String) -> bool:
	## Must-hit basic (yellow) rocks only. Grey / avoider / red-attacker / hazards never strike on OOB.
	if rock_type_name.contains("red_attacker"):
		return false
	if not rock_yellows_give_strikes:
		return false
	return rock_type_name.contains("rock_type_1")


func set_strike_feedback_origin(world_pos: Vector3) -> void:
	_pending_strike_feedback_pos = world_pos
	_has_pending_strike_feedback_pos = true


## Balloon pops still award a strike, but skip the rock-OOB smoke/sparks.
func suppress_next_strike_feedback() -> void:
	_suppress_next_strike_particles = true


## Universal strike sting (same as a must-hit rock leaving play).
func play_strike_feedback(_a = null, _b = null) -> void:
	if _suppress_next_strike_particles:
		_suppress_next_strike_particles = false
		_has_pending_strike_feedback_pos = false
		return
	if not oob_miss_feedback_enabled:
		return
	var pos := _default_strike_feedback_world_pos()
	if _has_pending_strike_feedback_pos:
		pos = _pending_strike_feedback_pos
		_has_pending_strike_feedback_pos = false
	_play_oob_miss_feedback(pos, OobSide.NONE)


func _default_strike_feedback_world_pos() -> Vector3:
	var cam := _get_bounds_camera()
	if cam:
		return cam.global_position + (-cam.global_transform.basis.z) * 18.0
	return Vector3.ZERO


## After black-only (etc.) leave play: if nothing clearable is left in the air, advance.
func check_wave_clear_if_no_live_rocks() -> void:
	if gl_PlayerState.dataset.total_rocks_in_round_remaining > 0:
		return
	if _any_live_round_rocks():
		return
	gl_PlayerState.check_all_rocks_cleared()


func _any_live_round_rocks() -> bool:
	for body in $Container_1.get_children():
		if not (body is RockInstance):
			continue
		## Juggle rocks run independently — never block wait / wait-until-clear.
		if body.rock_type == RockInstance.RockSize.JUGGLE:
			continue
		if body.rock_type == RockInstance.RockSize.MOTHERSHIP:
			continue
		## Avoiders are not remaining-rocks; `rock-avoider-kill` pops leftovers after wait.
		if body.rock_type == RockInstance.RockSize.AVOIDER:
			continue
		## Still waiting to launch this wave.
		if body.current_state == body.State.PREPARE_ROCK:
			return true
		if body.rock_activated and body.current_state == body.State.ACTIVE:
			return true
	return false


func _any_live_balloons() -> bool:
	var host := get_tree().get_first_node_in_group("balloon_container")
	if host == null:
		return false
	for child in host.get_children():
		if not (child is StaticBody3D):
			continue
		if bool(child.get("behind_player")):
			continue
		if bool(child.get("rock_activated")):
			return true
	return false


func _any_airborne_pineapples() -> bool:
	for node in get_tree().get_nodes_in_group("pineapple_container"):
		if node == null:
			continue
		if not node.has_method("launch_from_spawn_entry"):
			continue
		for child in node.get_children():
			if child is RigidBody3D and bool(child.get("rock_activated")):
				return true
	return false


func _any_live_pineapples() -> bool:
	for node in get_tree().get_nodes_in_group("pineapple_container"):
		if node != null and node.has_method("is_pineapple_in_play") and bool(node.is_pineapple_in_play()):
			return true
	return _any_airborne_pineapples()


func any_live_pineapples() -> bool:
	return _any_live_pineapples()


func _any_live_oranges() -> bool:
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager != null and int(round_manager.get("orange_active")) > 0:
		return true
	for container in get_tree().get_nodes_in_group("orange_container"):
		for child in container.get_children():
			if child != null and is_instance_valid(child) and bool(child.get("rock_activated")):
				return true
	return false


func _any_live_bonus_targets() -> bool:
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return false
	var bonus = round_manager.get("bonus_target_manager")
	if bonus != null and bonus.has_method("is_active") and bool(bonus.is_active()):
		return true
	return false


func _oob_miss_should_show_feedback(rock_type_name: String) -> bool:
	if rock_type_name.contains("hazard"):
		return false
	if rock_type_name.contains("rock_type_8") or rock_type_name.contains("smokecan"):
		return false
	if rock_type_name.contains("rock_type_avoider") or rock_type_name.contains("avoider"):
		return false
	return true


func _play_oob_miss_feedback(world_pos: Vector3, side: OobSide) -> void:
	_spawn_oob_miss_particles(world_pos)
	var side_sign := _oob_side_to_camera_x_sign(side, world_pos)
	var cam := get_tree().get_first_node_in_group("player_cam")
	if cam and cam.has_method("shake_camera_oob_miss"):
		cam.shake_camera_oob_miss(side_sign, oob_miss_shake_amount, oob_miss_shake_duration)


## -1 = punch camera left, +1 = punch camera right (camera local X).
func _oob_side_to_camera_x_sign(side: OobSide, world_pos: Vector3) -> float:
	match side:
		OobSide.LEFT:
			return -1.0
		OobSide.RIGHT:
			return 1.0
		_:
			# Bottom / behind — bias by which half of the screen the rock was on.
			var cam := _get_bounds_camera()
			if cam == null:
				return signf(world_pos.x) if not is_zero_approx(world_pos.x) else 1.0
			if cam.is_position_behind(world_pos):
				return signf(world_pos.x) if not is_zero_approx(world_pos.x) else 1.0
			var screen := cam.unproject_position(world_pos)
			var mid := get_viewport().get_visible_rect().size.x * 0.5
			return -1.0 if screen.x < mid else 1.0


func _spawn_oob_miss_particles(world_pos: Vector3) -> void:
	var host := get_tree().current_scene
	if host == null:
		host = self

	var smoke: Node = _OOB_MISS_SMOKE.instantiate()
	host.add_child(smoke)
	if smoke is Node3D:
		(smoke as Node3D).global_position = world_pos
	if smoke is GPUParticles3D:
		var gp := smoke as GPUParticles3D
		gp.one_shot = true
		gp.emitting = true
		gp.finished.connect(smoke.queue_free, CONNECT_ONE_SHOT)
	else:
		smoke.queue_free.call_deferred()

	var sparks: Node = _OOB_MISS_SPARKS.instantiate()
	host.add_child(sparks)
	if sparks is Node3D:
		(sparks as Node3D).global_position = world_pos
	if sparks is GPUParticles3D:
		var sp := sparks as GPUParticles3D
		sp.one_shot = true
		sp.emitting = true
		sp.finished.connect(sparks.queue_free, CONNECT_ONE_SHOT)
	else:
		# Fallback free if scene root isn't a GPUParticles3D.
		get_tree().create_timer(1.2).timeout.connect(sparks.queue_free, CONNECT_ONE_SHOT)


func assign_rock_positions(bodies: Array) -> void:

	if bodies.is_empty():
		return
	
	var positions : Array[float] = []
	
	# 1. Pick the cluster anchor + partner first so there's always room for them.
	var cluster_anchor := randf_range(X_MIN, X_MAX)
	var cluster_offset := randf_range(CLUSTER_MIN_DIST, CLUSTER_MAX_DIST)
	if randf() < 0.5:
		cluster_offset = -cluster_offset
	
	var cluster_partner := cluster_anchor + cluster_offset
	if cluster_partner > X_MAX or cluster_partner < X_MIN:
		# Went off the edge — try the opposite direction instead.
		cluster_partner = cluster_anchor - cluster_offset
	cluster_partner = clamp(cluster_partner, X_MIN, X_MAX)
	
	positions.append(cluster_anchor)
	if bodies.size() > 1:
		positions.append(cluster_partner)
	
	# 2. Fill remaining rocks via rejection sampling, keeping MIN_ROCK_SPACING
	#    away from every position already chosen.
	var max_attempts := 50
	for i in range(positions.size(), bodies.size()):
		var placed := false
		for attempt in range(max_attempts):
			var candidate := randf_range(X_MIN, X_MAX)
			if _is_far_enough(candidate, positions):
				positions.append(candidate)
				placed = true
				break
		if not placed:
			# Range is crowded — fall back to whatever spot has the largest
			# gap to its nearest neighbor, so we never leave a rock unplaced.
			positions.append(_best_effort_position(positions))
	
	# 3. Shuffle so the "cluster pair" isn't always assigned to the first two
	#    rocks in the container (keeps which physical rocks cluster random too).
	positions.shuffle()
	
	for idx in range(bodies.size()):
		var body = bodies[idx]
		body.target_x_position = positions[idx]


func column_to_x(column: int) -> float:
	# Column 1 is rightmost (+), column 8 leftmost (-). Spacing is equal across all columns.
	# broaden_columns adds to COLUMN_STEP so the whole fan widens uniformly from center.
	column = column % 10

	var clamped_column := clampi(column, 1, COLUMN_COUNT)
	if clamped_column != column:
		push_warning("RockManager: column %d out of range [1, %d], clamped to %d." % [column, COLUMN_COUNT, clamped_column])
	return _column_to_x_unclamped(clamped_column)


## Aim / crosshair X. Supports side lanes: column 0 (outside 1) and 9 (outside 8).
func column_to_x_for_aim(column: int) -> float:
	return _column_to_x_unclamped(column)


func _is_side_lane_column(column: int) -> bool:
	return column == SIDE_LANE_OUTSIDE_1 or column == SIDE_LANE_OUTSIDE_8


## True for `rock A0 A8` / `rock 0 A8` — spawn at the aim-plane side and fly across.
func _is_lateral_launch(entry) -> bool:
	if not (entry is Dictionary):
		return false
	if int(entry.get("spawn_row", -1)) >= 1:
		return true
	return _is_side_lane_column(int(entry.get("column", -1)))


func _spawn_x_for_entry(entry, column: int) -> float:
	if _is_lateral_launch(entry):
		return _lateral_spawn_world(entry, column).x
	return column_to_x(column)


func _lateral_spawn_row(entry, column: int) -> int:
	if entry is Dictionary:
		var row := int(entry.get("spawn_row", -1))
		if row >= 1:
			return row
	var aim := _resolve_aim_cell(entry, false, column)
	return aim.x if aim.x >= 1 else 1


func _lateral_spawn_world(entry, column: int) -> Vector3:
	var row := _lateral_spawn_row(entry, column)
	var x := offscreen_spawn_x(column) if _is_side_lane_column(column) else column_to_x_for_aim(column)
	return Vector3(x, float(AIM_LANE_Y.get(row, AIM_LANE_Y[1])), AIM_PLANE_Z)


func _lateral_aim_world(aim: Vector2i) -> Vector3:
	var pos := _aim_cell_world_position(aim.x, aim.y, false)
	if _is_side_lane_column(aim.y):
		pos.x = offscreen_spawn_x(aim.y)
	return pos


## World X just outside the camera at the aim plane, on the same side as this lane.
func offscreen_spawn_x(column: int) -> float:
	var fallback := column_to_x_for_aim(column)
	if not _is_side_lane_column(column):
		return fallback
	var col1 := _column_to_x_unclamped(1)
	var col8 := _column_to_x_unclamped(COLUMN_COUNT)
	var side := signf(col1 - col8) if column == SIDE_LANE_OUTSIDE_1 else signf(col8 - col1)
	if side == 0.0:
		side = 1.0 if column == SIDE_LANE_OUTSIDE_1 else -1.0
	var edge := _camera_world_x_at_aim_plane(side)
	if not is_finite(edge):
		return fallback
	return edge + side * OFFSCREEN_SPAWN_PAD_M


func _camera_world_x_at_aim_plane(side_sign: float) -> float:
	var camera := _get_bounds_camera()
	if camera == null:
		return NAN
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return NAN
	var x_left := _unproject_x_at_z(camera, 0.0, viewport_size.y * 0.5, AIM_PLANE_Z)
	var x_right := _unproject_x_at_z(camera, viewport_size.x, viewport_size.y * 0.5, AIM_PLANE_Z)
	if not is_finite(x_left) or not is_finite(x_right):
		return NAN
	if side_sign > 0.0:
		return maxf(x_left, x_right)
	return minf(x_left, x_right)


func _unproject_x_at_z(camera: Camera3D, screen_x: float, screen_y: float, world_z: float) -> float:
	var origin := camera.project_ray_origin(Vector2(screen_x, screen_y))
	var dir := camera.project_ray_normal(Vector2(screen_x, screen_y))
	if absf(dir.z) < 0.0001:
		return NAN
	var t := (world_z - origin.z) / dir.z
	if t <= 0.0:
		return NAN
	return origin.x + dir.x * t


func _column_to_x_unclamped(column: int) -> float:
	var step := COLUMN_STEP + broaden_columns
	var half_span := float(COLUMN_COUNT - 1) * 0.5 * step
	if column < 1:
		return half_span + step * float(1 - column)
	if column > COLUMN_COUNT:
		return -half_span - step * float(column - COLUMN_COUNT)
	return half_span - float(column - 1) * step


# --- Column telegraph -------------------------------------------------------

func _cache_telegraph_meshes() -> void:
	_telegraph_meshes.clear()
	_telegraph_meshes.resize(COLUMN_COUNT + 1)
	_telegraph_base_albedo.clear()
	if telegraph_columns == null:
		return

	# Prefer Column1…Column8 (root Columns / clean naming).
	var numbered := 0
	for col in range(1, COLUMN_COUNT + 1):
		var node := telegraph_columns.get_node_or_null("Column%d" % col)
		if node is MeshInstance3D:
			_telegraph_meshes[col] = node
			numbered += 1

	# Legacy Rocks/$Columns naming: Column (=1), Column1 (=2), … Column7 (=8).
	if numbered < COLUMN_COUNT:
		for col in range(1, COLUMN_COUNT + 1):
			if _telegraph_meshes[col] != null:
				continue
			var legacy_name := "Column" if col == 1 else ("Column%d" % (col - 1))
			var legacy := telegraph_columns.get_node_or_null(legacy_name)
			if legacy is MeshInstance3D:
				_telegraph_meshes[col] = legacy

	# Last resort: MeshInstance3D children in tree order.
	if numbered < COLUMN_COUNT:
		var idx := 1
		for child in telegraph_columns.get_children():
			if idx > COLUMN_COUNT:
				break
			if child is MeshInstance3D:
				if _telegraph_meshes[idx] == null:
					_telegraph_meshes[idx] = child
				idx += 1

	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _telegraph_meshes[col]
		if mesh == null:
			continue
		_ensure_telegraph_material(mesh)


func _ensure_telegraph_material(mesh: MeshInstance3D) -> void:
	var mat: Material = mesh.material_override
	if mat == null:
		var active := mesh.get_active_material(0)
		if active != null:
			mat = active.duplicate()
		else:
			var std := StandardMaterial3D.new()
			std.albedo_color = Color(0.55, 0.55, 0.55, 1.0)
			mat = std
	else:
		mat = mat.duplicate()
	mesh.material_override = mat
	if mat is BaseMaterial3D:
		_telegraph_base_albedo[mesh.get_instance_id()] = (mat as BaseMaterial3D).albedo_color


func _resolve_telegraph_columns_node() -> Node3D:
	if telegraph_columns != null and is_instance_valid(telegraph_columns):
		return telegraph_columns
	if has_node("Columns2"):
		telegraph_columns = $Columns2
		return telegraph_columns
	if has_node("Columns"):
		telegraph_columns = $Columns
		return telegraph_columns
	return null


func _ensure_telegraph_sfx_player() -> void:
	if _telegraph_sfx_player != null and is_instance_valid(_telegraph_sfx_player):
		return
	var existing := get_node_or_null("TelegraphSFX")
	if existing is AudioStreamPlayer:
		_telegraph_sfx_player = existing
	else:
		_telegraph_sfx_player = AudioStreamPlayer.new()
		_telegraph_sfx_player.name = "TelegraphSFX"
		_telegraph_sfx_player.max_polyphony = 4
		add_child(_telegraph_sfx_player)
	if telegraph_sfx != null:
		_telegraph_sfx_player.stream = telegraph_sfx
	_telegraph_sfx_player.volume_db = telegraph_sfx_volume_db


func _play_telegraph_sfx(column: int) -> void:
	_ensure_telegraph_sfx_player()
	if _telegraph_sfx_player == null or telegraph_sfx == null:
		return
	if _telegraph_sfx_player.stream != telegraph_sfx:
		_telegraph_sfx_player.stream = telegraph_sfx
	_telegraph_sfx_player.volume_db = telegraph_sfx_volume_db
	var base_pitch := 0.82
	_telegraph_sfx_player.pitch_scale = base_pitch + float(clampi(column, 1, COLUMN_COUNT) - 1) * telegraph_sfx_pitch_step
	_telegraph_sfx_player.play()


## Keep telegraph markers visually aligned with rock columns from the camera.
## Markers sit closer on Z than the spawn plane (~AIM_PLANE_Z), so matching world X
## looks wrong on the sides. We match each rock column's screen-X onto the marker's
## existing Y/Z (your perspective layout), and still follow broaden_columns / column_to_x.
func sync_telegraph_column_positions() -> void:
	if _resolve_telegraph_columns_node() == null:
		return
	if _telegraph_meshes.size() <= 1 or _telegraph_meshes[1] == null:
		_cache_telegraph_meshes()

	var camera := _get_bounds_camera()
	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _get_telegraph_mesh(col)
		if mesh == null:
			continue
		var pos := mesh.global_position
		var rock_x := column_to_x(col)
		if camera != null:
			var rock_world := Vector3(rock_x, global_position.y, AIM_PLANE_Z)
			pos.x = _perspective_match_screen_x(camera, rock_world, pos, rock_x)
		# If no camera yet, leave the hand-tuned X alone.
		mesh.global_position = pos


## Find marker X so it shares the rock's screen-X while keeping marker Y/Z.
func _perspective_match_screen_x(
	camera: Camera3D,
	rock_world: Vector3,
	marker_pos: Vector3,
	fallback_x: float
) -> float:
	if camera.is_position_behind(rock_world):
		return fallback_x
	var rock_screen := camera.unproject_position(rock_world)
	var marker_screen := camera.unproject_position(marker_pos)
	# Same horizontal as the rock column, same vertical as the existing marker.
	var screen := Vector2(rock_screen.x, marker_screen.y)
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.z) < 0.00001:
		return fallback_x
	var t := (marker_pos.z - origin.z) / dir.z
	if t < 0.0:
		return fallback_x
	return origin.x + dir.x * t


## Keep $DebugVisualiser columns/rows aligned with column_to_x() and AIM_LANE_Y.
## This overlay sits on the aim plane (Z≈23), so world X/Y match is correct (no perspective remap).
func sync_debug_visualiser() -> void:
	if debug_visualiser == null or not is_instance_valid(debug_visualiser):
		if has_node("DebugVisualiser"):
			debug_visualiser = $DebugVisualiser
		else:
			return

	for col in range(1, COLUMN_COUNT + 1):
		var col_node := debug_visualiser.get_node_or_null("Column%d" % col)
		if col_node is Node3D:
			var pos := (col_node as Node3D).global_position
			pos.x = column_to_x(col)
			(col_node as Node3D).global_position = pos

	# RowA / RowA2 / RowA3 → aim rows 1/2/3 (A/B/C). Also accept RowB / RowC aliases.
	var row_node_names := {
		1: ["RowA", "Row1", "RowB1"],
		2: ["RowA2", "RowB", "Row2"],
		3: ["RowA3", "RowC", "Row3"],
	}
	for row in AIM_LANE_Y.keys():
		var names: Array = row_node_names.get(int(row), [])
		var lane_y: float = float(AIM_LANE_Y[row])
		for node_name in names:
			var row_node := debug_visualiser.get_node_or_null(str(node_name))
			if row_node is Node3D:
				var pos := (row_node as Node3D).global_position
				pos.y = lane_y
				(row_node as Node3D).global_position = pos
				break


func start_wave_telegraph() -> void:
	## Full-wave preview disabled — use telegraph_before_launch per rock instead.
	## Kept as a no-op so older call sites / editor tools do not break.
	if path_telegraph_enabled or telegraph_enabled:
		_cancel_wave_telegraph()
		if _resolve_telegraph_columns_node() != null:
			sync_telegraph_column_positions()
			telegraph_columns.visible = true
		_telegraph_token += 1
		var token := _telegraph_token
		if path_telegraph_enabled:
			_run_path_telegraph(token)
		elif telegraph_enabled:
			_run_column_telegraph(token)
	return


func start_column_telegraph() -> void:
	# Back-compat alias.
	start_wave_telegraph()


func _cancel_wave_telegraph() -> void:
	_telegraph_token += 1
	if _path_telegraph_tween != null:
		_path_telegraph_tween.kill()
		_path_telegraph_tween = null
	_restore_all_telegraph_colors()
	_clear_path_telegraph_visuals()


func _cancel_column_telegraph() -> void:
	_cancel_wave_telegraph()


func _build_wave_telegraph_plan(bodies: Array) -> void:
	_wave_telegraph_plan.clear()
	if bodies.is_empty() or rocks_limit <= 0:
		return

	_rebuild_wave_convergence_aim_columns(bodies)

	for i in mini(rocks_limit, bodies.size()):
		var body = bodies[i]
		var entry = null
		if i < manual_rock_sequence.size():
			entry = manual_rock_sequence[i]

		var spawn_column := 1
		if i < _wave_spawn_columns.size():
			spawn_column = _wave_spawn_columns[i]
		else:
			spawn_column = _x_to_nearest_column(body.target_x_position)

		var spawn := Vector3(
			body.target_x_position,
			body.global_position.y,
			body.global_position.z
		)
		if _is_lateral_launch(entry):
			spawn = _lateral_spawn_world(entry, spawn_column)

		var is_pigeon = body.rock_type == RockInstance.RockSize.SMALL_2
		var aim_world: Vector3
		if is_pigeon:
			var aim := _resolve_aim_cell(entry)
			aim_world = _pigeon_aim_world_point(aim.y, aim.x, spawn.y)
		else:
			var aim := _resolve_aim_cell(entry, true, spawn_column)
			# Bake jitter once so preview and launch share the same target.
			if _is_lateral_launch(entry):
				aim_world = _lateral_aim_world(aim)
			else:
				aim_world = _aim_cell_world_position(aim.x, aim.y, true)

		_wave_telegraph_plan.append({
			'spawn': spawn,
			'aim': aim_world,
			'column': spawn_column,
			'is_pigeon': is_pigeon,
			'gravity_scale': LATERAL_LAUNCH_GRAVITY if _is_lateral_launch(entry) else _aim_launch_gravity_for(body, entry),
		})


func _ensure_path_telegraph_root() -> Node3D:
	if _path_telegraph_root != null and is_instance_valid(_path_telegraph_root):
		return _path_telegraph_root
	_path_telegraph_root = Node3D.new()
	_path_telegraph_root.name = "PathTelegraph"
	add_child(_path_telegraph_root)
	return _path_telegraph_root


func _ensure_path_telegraph_materials() -> void:
	if _path_ghost_mat == null:
		_path_ghost_mat = _make_path_preview_material(path_telegraph_color, 2.5)
	else:
		_path_ghost_mat.albedo_color = path_telegraph_color
		_path_ghost_mat.emission = path_telegraph_color
	if _path_aim_mat == null:
		_path_aim_mat = _make_path_preview_material(path_telegraph_aim_color, 3.5)
	else:
		_path_aim_mat.albedo_color = path_telegraph_aim_color
		_path_aim_mat.emission = path_telegraph_aim_color
	if _path_trail_mat == null:
		var trail_col := path_telegraph_color
		trail_col.a = 0.35
		_path_trail_mat = _make_path_preview_material(trail_col, 1.2)


func _make_path_preview_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = emission_energy
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	return mat


func _clear_path_telegraph_visuals() -> void:
	if _path_telegraph_root == null or not is_instance_valid(_path_telegraph_root):
		return
	for child in _path_telegraph_root.get_children():
		child.queue_free()


func _make_path_sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Visual only — never shootable / never a physics target.
	return mesh_inst


func _run_path_telegraph(token: int) -> void:
	if _wave_telegraph_plan.is_empty():
		if telegraph_enabled:
			await _run_column_telegraph(token)
		return

	_ensure_path_telegraph_materials()
	var root := _ensure_path_telegraph_root()
	_clear_path_telegraph_visuals()

	var count := _wave_telegraph_plan.size()
	var budget := maxf(path_telegraph_duration_sec, 0.2)
	var per_rock := budget / float(count)
	# Leave a little gap between rocks so order is readable.
	var move_sec := clampf(per_rock * 0.72, 0.08, 0.55)
	var hold_sec := clampf(per_rock * 0.18, 0.04, 0.2)
	var gap_sec := maxf(0.0, per_rock - move_sec - hold_sec)

	for i in count:
		if token != _telegraph_token:
			return
		_clear_path_telegraph_visuals()

		var item: Dictionary = _wave_telegraph_plan[i]
		var spawn: Vector3 = item.spawn
		var aim: Vector3 = item.aim
		var column: int = int(item.column)
		var is_pigeon: bool = bool(item.is_pigeon)

		if telegraph_enabled:
			_blink_column_once_fire_and_forget(column, token)
		_play_telegraph_sfx(column)

		var ghost := _make_path_sphere(0.28, _path_ghost_mat)
		root.add_child(ghost)
		ghost.global_position = spawn

		var aim_marker := _make_path_sphere(0.22, _path_aim_mat)
		root.add_child(aim_marker)
		aim_marker.global_position = aim
		aim_marker.visible = true

		var path_pts := _sample_telegraph_path(
			spawn, aim, is_pigeon, 10, float(item.get("gravity_scale", aim_launch_gravity_scale))
		)
		_spawn_path_trail_dots(root, path_pts)

		if _path_telegraph_tween != null:
			_path_telegraph_tween.kill()
		_path_telegraph_tween = create_tween()
		var tween := _path_telegraph_tween
		tween.set_parallel(false)
		for p in range(1, path_pts.size()):
			var seg_t := move_sec / float(maxi(path_pts.size() - 1, 1))
			tween.tween_property(ghost, "global_position", path_pts[p], seg_t)
		tween.tween_interval(hold_sec)
		await tween.finished
		if _path_telegraph_tween == tween:
			_path_telegraph_tween = null

		if token != _telegraph_token:
			return
		if gap_sec > 0.0:
			await get_tree().create_timer(gap_sec, false).timeout

	if token == _telegraph_token:
		_clear_path_telegraph_visuals()


func _blink_column_once_fire_and_forget(column: int, token: int) -> void:
	var mesh := _get_telegraph_mesh(column)
	if mesh == null:
		return
	var mat := mesh.material_override as BaseMaterial3D
	if mat == null:
		_ensure_telegraph_material(mesh)
		mat = mesh.material_override as BaseMaterial3D
	if mat == null:
		return
	var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
	mat.albedo_color = telegraph_blink_color
	get_tree().create_timer(telegraph_blink_on_sec).timeout.connect(
		func () -> void:
			if token != _telegraph_token:
				return
			if is_instance_valid(mesh) and mat:
				mat.albedo_color = base,
		CONNECT_ONE_SHOT
	)


func _sample_telegraph_path(
	from: Vector3, to: Vector3, is_pigeon: bool, samples: int, gravity_scale: float = -1.0
) -> PackedVector3Array:
	samples = maxi(samples, 2)
	var pts := PackedVector3Array()
	if is_pigeon:
		for i in samples:
			var u := float(i) / float(samples - 1)
			pts.append(from.lerp(to, u))
		return pts

	var g_scale := aim_launch_gravity_scale if gravity_scale < 0.0 else gravity_scale
	## Zero / near-zero gravity = straight flight (rock-stay, etc.).
	if g_scale <= 0.01:
		for i in samples:
			var u := float(i) / float(samples - 1)
			pts.append(from.lerp(to, u))
		return pts

	var vel := BallisticAim.velocity_to_point(
		from, to, -1.0, g_scale, aim_hang_time_sec
	)
	var g := BallisticAim.gravity_accel(g_scale)
	var dy := to.y - from.y
	var hang := maxf(aim_hang_time_sec, 0.0)
	var flight_t: float
	if dy > 0.01:
		flight_t = sqrt(2.0 * dy / g) + hang
	else:
		var dist := from.distance_to(to)
		flight_t = maxf(0.35, dist / 15.0) + hang
	flight_t = maxf(flight_t, 0.001)

	for i in samples:
		var u := float(i) / float(samples - 1)
		var ti := flight_t * u
		pts.append(from + vel * ti + Vector3(0.0, -0.5 * g * ti * ti, 0.0))
	# Snap end to exact aim so the ghost lands cleanly.
	if pts.size() > 0:
		pts[pts.size() - 1] = to
	return pts


func _spawn_path_trail_dots(root: Node3D, path_pts: PackedVector3Array) -> void:
	# Skip first/last — ghost + aim marker cover those.
	for i in range(1, path_pts.size() - 1):
		var dot := _make_path_sphere(0.08, _path_trail_mat)
		root.add_child(dot)
		dot.global_position = path_pts[i]


func _run_column_telegraph(token: int) -> void:
	var order: Array[int] = []
	var limit := mini(rocks_limit, _wave_spawn_columns.size())
	for i in limit:
		order.append(_wave_spawn_columns[i])

	for column in order:
		if token != _telegraph_token:
			return
		await _blink_column_twice(column, token)
		if token != _telegraph_token:
			return
		if telegraph_gap_between_rocks_sec > 0.0:
			await get_tree().create_timer(telegraph_gap_between_rocks_sec, false).timeout


func _blink_column_twice(column: int, token: int) -> void:
	var mesh := _get_telegraph_mesh(column)
	if mesh == null:
		return
	var mat := mesh.material_override as BaseMaterial3D
	if mat == null:
		_ensure_telegraph_material(mesh)
		mat = mesh.material_override as BaseMaterial3D
	if mat == null:
		return

	var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
	for _i in 1:
		if token != _telegraph_token:
			mat.albedo_color = base
			return
		mat.albedo_color = telegraph_blink_color
		_play_telegraph_sfx(column)
		await get_tree().create_timer(telegraph_blink_on_sec, false).timeout
		if token != _telegraph_token:
			mat.albedo_color = base
			return
		mat.albedo_color = base
		await get_tree().create_timer(telegraph_blink_off_sec, false).timeout


func _get_telegraph_mesh(column: int) -> MeshInstance3D:
	if column < 1 or column >= _telegraph_meshes.size():
		return null
	var mesh := _telegraph_meshes[column]
	if mesh == null or not is_instance_valid(mesh):
		return null
	return mesh


func _restore_all_telegraph_colors() -> void:
	for col in range(1, COLUMN_COUNT + 1):
		var mesh := _get_telegraph_mesh(col)
		if mesh == null:
			continue
		var mat := mesh.material_override as BaseMaterial3D
		if mat == null:
			continue
		var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
		mat.albedo_color = base


func assign_manual_rock_positions(bodies: Array) -> void:
	if bodies.is_empty():
		return
	
	var column_counts := {}
	var positions : Array[float] = []
	_wave_spawn_columns.clear()
	
	for entry in manual_rock_sequence:
		var column := _resolve_spawn_column(entry)
		_wave_spawn_columns.append(column)
		var base_x := _spawn_x_for_entry(entry, column)
		var occurrence : int = column_counts.get(column, 0)
		column_counts[column] = occurrence + 1
		
		var offset := 0.0
		if occurrence > 0 and not _is_side_lane_column(column):
			var direction := 1.0 if occurrence % 2 == 1 else -1.0
			var step := ceili(occurrence / 2.0)
			offset = direction * step * SAME_COLUMN_OFFSET

		
		positions.append(base_x + offset)
	
	for idx in range(bodies.size()):
		var body = bodies[idx]
		body.target_x_position = positions[idx]


## Resolves a spawn entry to column 0–9. Missing/negative column → random 1-8.
## 0 and 9 are off-camera side lanes (outside 1 and 8).
func _resolve_spawn_column(entry) -> int:
	if entry is Dictionary:
		var column: int = int(entry.get('column', -1))
		if _is_side_lane_column(column):
			return column
		if column < 1:
			return randi_range(1, COLUMN_COUNT)
		return clampi(column, 1, COLUMN_COUNT)

	if typeof(entry) == TYPE_INT:
		var value: int = entry
		if _is_side_lane_column(value):
			return value
		if value < 10:
			return clampi(value, 1, COLUMN_COUNT)
		return clampi(value % 10, 1, COLUMN_COUNT)

	return randi_range(1, COLUMN_COUNT)


## Resolves aim cell. Missing row → row A (1). Missing column (< 0) → wave converge / split pool.
## Column 0 / 9 are valid side-lane aims. Pass apply_center_bias + spawn_column for random aims.
func _resolve_aim_cell(entry, apply_center_bias: bool = false, spawn_column: int = -1) -> Vector2i:
	var aim_row := 0
	var aim_column := -1
	if entry is Dictionary:
		aim_row = int(entry.get('aim_row', -1))
		aim_column = int(entry.get('aim_column', -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 0:
		if apply_center_bias and bias_random_aim_toward_center and not _wave_aim_pool.is_empty():
			aim_column = _pick_wave_aim_column(spawn_column)
		else:
			aim_column = randi_range(1, COLUMN_COUNT)
	return Vector2i(aim_row, aim_column)


## Same-lane: shared column. Split: left spawn → center/right of pool; right spawn → left/center.
func _pick_wave_aim_column(spawn_column: int) -> int:
	if _wave_aim_converge_same_lane and _wave_convergence_aim_column >= 1:
		return _wave_convergence_aim_column

	var side_pool: Array[int] = []
	if spawn_column < 1 or _wave_aim_center < 1:
		side_pool = _wave_aim_pool.duplicate()
	elif float(spawn_column) < _wave_aim_mid:
		# Left side → aim center or one lane toward the right (e.g. A4 / A5).
		for col in _wave_aim_pool:
			if col >= _wave_aim_center:
				side_pool.append(col)
	elif float(spawn_column) > _wave_aim_mid:
		# Right side → aim center or one lane toward the left (e.g. A3 / A4).
		for col in _wave_aim_pool:
			if col <= _wave_aim_center:
				side_pool.append(col)
	else:
		side_pool = _wave_aim_pool.duplicate()

	if side_pool.is_empty():
		side_pool = _wave_aim_pool.duplicate()
	if side_pool.is_empty():
		return randi_range(1, COLUMN_COUNT)
	return side_pool[randi() % side_pool.size()]


## Midpoint of furthest-left / furthest-right spawn columns, then center ± 1 (clamped to 1–8).
## e.g. spawns 1+8 → A3/A4/A5; spawns 1+2 → A1/A2/A3; spawns 2+4 → A2/A3/A4.
func _convergence_aim_columns_from_spawns(spawn_columns: Array[int]) -> Dictionary:
	var empty := {'pool': [] as Array[int], 'mid': 0.0, 'center': -1}
	if spawn_columns.is_empty():
		return empty

	var leftmost := spawn_columns[0]
	var rightmost := spawn_columns[0]
	for col in spawn_columns:
		leftmost = mini(leftmost, col)
		rightmost = maxi(rightmost, col)

	var mid := (float(leftmost) + float(rightmost)) * 0.5
	var center := clampi(roundi(mid), 1, COLUMN_COUNT)
	var pool: Array[int] = []
	for col in range(center - 1, center + 2):
		if col >= 1 and col <= COLUMN_COUNT:
			pool.append(col)
	return {'pool': pool, 'mid': mid, 'center': center}


## Collect non-pigeon spawn columns, build aim pool, then roll same-lane vs adjacent-split.
func _rebuild_wave_convergence_aim_columns(bodies: Array) -> void:
	_wave_convergence_aim_column = -1
	_wave_aim_converge_same_lane = true
	_wave_aim_mid = 0.0
	_wave_aim_center = -1
	_wave_aim_pool.clear()

	var spawn_cols: Array[int] = []
	var counter := 0
	for body in bodies:
		if body.current_state != body.State.PREPARE_ROCK and body.current_state != body.State.ACTIVE:
			continue
		if counter >= rocks_limit:
			break
		if body.rock_type != RockInstance.RockSize.SMALL_2:
			spawn_cols.append(_x_to_nearest_column(body.target_x_position))
		counter += 1

	var info := _convergence_aim_columns_from_spawns(spawn_cols)
	_wave_aim_pool = info.pool
	_wave_aim_mid = float(info.mid)
	_wave_aim_center = int(info.center)
	if _wave_aim_pool.is_empty():
		return

	_wave_aim_converge_same_lane = randf() < converge_same_lane_chance
	if _wave_aim_converge_same_lane:
		_wave_convergence_aim_column = _wave_aim_pool[randi() % _wave_aim_pool.size()]
	else:
		_wave_convergence_aim_column = -1


func _is_far_enough(candidate: float, positions: Array[float]) -> bool:
	for p in positions:
		if abs(candidate - p) < MIN_ROCK_SPACING:
			return false
	return true


func _best_effort_position(positions: Array[float]) -> float:
	var best_x := X_MIN
	var best_gap := -1.0
	var x := X_MIN
	
	while x <= X_MAX:
		var nearest_gap := INF
		for p in positions:
			nearest_gap = min(nearest_gap, abs(x - p))
		if nearest_gap > best_gap:
			best_gap = nearest_gap
			best_x = x
		x += 0.25

	return best_x


func _get_position_angle_bias(x_position: float) -> float:
	# Rocks get angled toward convergence_x instead of the exact center.
	
	
	var half_range := (X_MAX - X_MIN) * 0.5
	var normalized = clamp((x_position - convergence_x) / half_range, -1.0, 1.0)
	
	
	return -normalized * angle_bias


func pick_convergence_point() -> void:
	var column := randi_range(1, COLUMN_COUNT - 2)
	convergence_x = column_to_x(column)

func update_round_end() -> void:
	_bounds_check_active = false
	_timed_event_epoch += 1
	_cancel_sequence()
	_cancel_pending_launches()
	$pitch_shift_rock_sound.pitch_scale = 0.85
	#$pitch_shift_rock_sound.volume_db = -9.0
	update_gravity(1.0)
	for body in $Container_1.get_children():
		if body is RockInstance:
			body.round_end_check_rock_status()
	clear_cardinal_bursts()


## Stop staggered `wait` launches mid-sequence (lose / abort / round end).
func _cancel_pending_launches() -> void:
	_launch_epoch += 1


func detonate_sky_mines() -> void:
	var bodies = $Container_1.get_children()
	var counter := 0
	for body in bodies:
		if counter >= bodies.size():
			break
		if not (body is RockInstance):
			continue
		if body.player_has_marked_rock == true && body.rock_activated:
			body.detonate_rock()
			
func get_rock_limit() -> int:
	var rocks_cap = gl_PlayerState.dataset.rock_limit
	rocks_cap = clamp(rocks_cap, 0, $Container_1.get_children().size())
	gl_PlayerState.dataset.rock_limit = rocks_cap
	return rocks_cap


func get_angle_bias() -> float:
	
	if !randomize_later_waves:
		return 0.0
	
	var probability = randi_range(1,10)
	if probability > 8:
		return 0.0
	
	return 10.0
	
func bounce_rocks() -> void:
	if _paused_for_continue:
		return
	angle_bias = get_angle_bias()
	# Prefer the prepare-time plan so launch matches the cached aim points.
	if _wave_telegraph_plan.is_empty():
		var prepared: Array = []
		for body in $Container_1.get_children():
			if not (body is RockInstance):
				continue
			if body.current_state == body.State.PREPARE_ROCK:
				prepared.append(body)
		_rebuild_wave_convergence_aim_columns(prepared)

	_launch_epoch += 1
	var epoch := _launch_epoch
	var prepared_queue: Array = []
	for body in $Container_1.get_children():
		if not (body is RockInstance):
			continue
		if body.current_state == body.State.PREPARE_ROCK:
			prepared_queue.append(body)

	_stream_launches_remaining = manual_rock_sequence.size()
	var launched: Array = []

	if telegraph_before_launch and not _instant_sequence_pulse and _resolve_telegraph_columns_node() != null:
		sync_telegraph_column_positions()
		telegraph_columns.visible = true

	for index in manual_rock_sequence.size():
		if _paused_for_continue or epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
			_stream_launches_remaining = 0
			return

		if index < _launch_delays_sec.size():
			var delay_sec: float = float(_launch_delays_sec[index])
			if delay_sec > 0.0:
				await get_tree().create_timer(delay_sec, false).timeout
				if _paused_for_continue or epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
					_stream_launches_remaining = 0
					return

		var entry = null
		if index < manual_rock_sequence.size():
			entry = manual_rock_sequence[index]

		if telegraph_before_launch and not _instant_sequence_pulse:
			var column := _spawn_column_for_launch_index(index, entry)
			await _telegraph_column_before_launch(column, epoch)
			if _paused_for_continue or epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
				_stream_launches_remaining = 0
				return

		var body = null
		if index < prepared_queue.size():
			var preview = prepared_queue[index]
			if preview != null and is_instance_valid(preview) and preview.current_state == preview.State.PREPARE_ROCK:
				body = preview
		if body == null:
			body = await _acquire_pool_rock(epoch)
		if body == null:
			_stream_launches_remaining = maxi(_stream_launches_remaining - 1, 0)
			continue

		if body.current_state != body.State.PREPARE_ROCK:
			_configure_stream_rock(body, index)

		_launch_stream_rock(body, index)
		launched.append(body)
		_stream_launches_remaining = maxi(_stream_launches_remaining - 1, 0)

	if epoch == _launch_epoch and current_state == State.PULSE_ROCKS:
		spin_rocks(launched)
	_instant_sequence_pulse = false


func _spawn_column_for_launch_index(index: int, entry) -> int:
	if index >= 0 and index < _wave_spawn_columns.size():
		return clampi(_wave_spawn_columns[index], 1, COLUMN_COUNT)
	return clampi(_resolve_spawn_column(entry), 1, COLUMN_COUNT)


## Blink the column mesh, then wait `telegraph_lead_sec` before the rock launches.
func _telegraph_column_before_launch(column: int, epoch: int) -> void:
	if not telegraph_before_launch:
		return
	if epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
		return
	_blink_column_once_always_restore(column)
	_play_telegraph_sfx(column)
	var lead := clampf(telegraph_lead_sec, 0.0, 1.0)
	if lead <= 0.0:
		return
	await get_tree().create_timer(lead, false).timeout


## Single blink that always restores base color (safe for overlapping per-launch telegraphs).
func _blink_column_once_always_restore(column: int) -> void:
	var mesh := _get_telegraph_mesh(column)
	if mesh == null:
		return
	var mat := mesh.material_override as BaseMaterial3D
	if mat == null:
		_ensure_telegraph_material(mesh)
		mat = mesh.material_override as BaseMaterial3D
	if mat == null:
		return
	var base: Color = _telegraph_base_albedo.get(mesh.get_instance_id(), mat.albedo_color)
	mat.albedo_color = telegraph_blink_color
	get_tree().create_timer(telegraph_blink_on_sec).timeout.connect(
		func () -> void:
			if is_instance_valid(mesh) and mat:
				mat.albedo_color = base,
		CONNECT_ONE_SHOT
	)


func _acquire_pool_rock(epoch: int):
	while true:
		if epoch != _launch_epoch or current_state != State.PULSE_ROCKS:
			return null
		var slot = _find_free_pool_rock()
		if slot != null:
			return slot
		await get_tree().process_frame


func _find_free_pool_rock():
	var fallback = null
	for body in $Container_1.get_children():
		if not (body is RockInstance):
			continue
		if body.current_state == body.State.INACTIVE:
			return body
		# Parked leftovers from a previous wave — safe to recycle if nothing inactive is left.
		if fallback == null and body.current_state == body.State.DISABLED:
			fallback = body
	return fallback


## Ad-hoc single rock (wall-puzzle threat, etc.). Does not advance the script sequence.
func spawn_threat_rock(cmd: String = "rock") -> void:
	var body = _find_free_pool_rock()
	if body == null:
		return
	var entry := {"cmd": String(cmd).to_lower(), "column": -1}
	var column := _resolve_spawn_column(entry)
	var spawn_x := _spawn_x_for_entry(entry, column)
	if body.has_method("setup_for_pool_launch"):
		body.setup_for_pool_launch(_spawn_entry_to_rock_type(entry), spawn_x)
	else:
		body.rock_type = _spawn_entry_to_rock_type(entry)
		body.target_x_position = spawn_x
		body.enter_state(body.State.PREPARE_ROCK)
	await get_tree().create_timer(0.35, false).timeout
	if not is_instance_valid(body) or body.current_state != body.State.PREPARE_ROCK:
		return
	body.enter_state(body.State.ACTIVE)
	var upward_force := 10.0
	if body.has_method("is_stay_flight") and body.is_stay_flight():
		var aim := _resolve_aim_cell(entry, true, column)
		var aim_pos := _aim_cell_world_position(aim.x, aim.y, true)
		if body.has_method("begin_rock_stay_flight"):
			body.begin_rock_stay_flight(aim_pos)
		if rock_rock_collisions_enabled and body.has_method("schedule_airborne_rock_collisions"):
			body.schedule_airborne_rock_collisions(rock_rock_collision_delay_sec, rock_rock_bounce)
		return
	var launch_g := _aim_launch_gravity_for(body, entry)
	BallisticAim.configure_body_for_ballistic_launch(body, launch_g)
	if body.has_method("begin_ballistic_aim_feel"):
		body.begin_ballistic_aim_feel(aim_descent_linear_damp)
	var impulse := _build_launch_impulse(body, -1, upward_force, 0.0, launch_g)
	body.apply_central_impulse(impulse)
	if rock_rock_collisions_enabled and body.has_method("schedule_airborne_rock_collisions"):
		body.schedule_airborne_rock_collisions(rock_rock_collision_delay_sec, rock_rock_bounce)


func _configure_stream_rock(body, rock_index: int) -> void:
	var entry = null
	if rock_index >= 0 and rock_index < manual_rock_sequence.size():
		entry = manual_rock_sequence[rock_index]
	var column := _resolve_spawn_column(entry)
	var spawn_x := _spawn_x_for_entry(entry, column)
	var spawn_y := -INF
	var spawn_z := -INF
	if rock_index < _wave_spawn_columns.size():
		column = _wave_spawn_columns[rock_index]
		spawn_x = _spawn_x_for_entry(entry, column)
	if _is_lateral_launch(entry):
		var spawn := _lateral_spawn_world(entry, column)
		spawn_x = spawn.x
		spawn_y = spawn.y
		spawn_z = spawn.z
	if body.has_method("setup_for_pool_launch"):
		body.setup_for_pool_launch(_spawn_entry_to_rock_type(entry), spawn_x, spawn_y, spawn_z)
	else:
		body.rock_type = _spawn_entry_to_rock_type(entry)
		body.target_x_position = spawn_x
		body.enter_state(body.State.PREPARE_ROCK)


func _launch_stream_rock(body, counter: int) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.enter_state(body.State.ACTIVE)

	var upward_force = 10.0
	var impulse: Vector3
	var entry = null
	var counter_idx := counter
	if counter_idx >= 0 and counter_idx < manual_rock_sequence.size():
		entry = manual_rock_sequence[counter_idx]
	_apply_red_attacker_script_dash(body, entry)
	if _is_lateral_launch(entry):
		body.constant_force = Vector3.ZERO
		BallisticAim.configure_body_for_ballistic_launch(body, LATERAL_LAUNCH_GRAVITY)
		impulse = _lateral_launch_impulse(body, entry)
		body.apply_central_impulse(impulse)
	elif body.rock_type == RockInstance.RockSize.SMALL_2:
		body.bounce_rocks()
		upward_force = upward_force * rock_pigeon_upward_force
		impulse = _pigeon_launch_impulse(body, counter, upward_force)
		body.apply_central_impulse(impulse)
	elif body.has_method("is_stay_flight") and body.is_stay_flight():
		## Prefer a fresh parse from the original script line so path_cells cannot be lost in copies.
		if entry is Dictionary:
			var raw_line := str(entry.get("raw", "")).strip_edges()
			if raw_line.is_empty() and Parser and Parser.has_method("_spawn_entry_to_line"):
				raw_line = str(Parser._spawn_entry_to_line(entry)).strip_edges()
			if not raw_line.is_empty() and Parser and Parser.has_method("parse_spawn_command"):
				var reparsed: Dictionary = Parser.parse_spawn_command(raw_line)
				if not reparsed.is_empty() and String(reparsed.get("cmd", "")).begins_with("rock-stay"):
					entry = reparsed
					if counter_idx >= 0 and counter_idx < manual_rock_sequence.size():
						manual_rock_sequence[counter_idx] = reparsed
		var aim_pos := _stay_aim_world(body, counter, entry)
		var path_world := _stay_path_worlds(entry, counter)
		var exit_splash := bool(entry.get("path_exit_splash", false)) if entry is Dictionary else false
		var splash_from := aim_pos
		if path_world.size() > 0:
			splash_from = path_world[path_world.size() - 1]
			## First path cell is the authoritative aim (ignore telegraph jitter).
			aim_pos = path_world[0]
		var splash_pos := _stay_splash_exit_world(splash_from)
		var cell_count := 0
		if entry is Dictionary:
			cell_count = int(entry.get("path_cells", []).size())
		print(
			"RockManager: rock-stay launch path_cells=%d path_world=%d exit=%s raw=%s"
			% [cell_count, path_world.size(), str(exit_splash), str(entry.get("raw", "") if entry is Dictionary else "")]
		)
		if body.has_method("begin_rock_stay_flight"):
			body.begin_rock_stay_flight(aim_pos, path_world, exit_splash, splash_pos)
		else:
			BallisticAim.configure_body_for_ballistic_launch(body, 0.0)
			impulse = _aimed_launch_impulse_to_world(body, aim_pos, 0.0)
			body.apply_central_impulse(impulse)
	else:
		var launch_g := _aim_launch_gravity_for(body, entry)
		BallisticAim.configure_body_for_ballistic_launch(body, launch_g)
		body.begin_ballistic_aim_feel(aim_descent_linear_damp)
		impulse = _build_launch_impulse(body, counter, upward_force, 0.0, launch_g)
		body.apply_central_impulse(impulse)

	if rock_rock_collisions_enabled:
		body.schedule_airborne_rock_collisions(rock_rock_collision_delay_sec, rock_rock_bounce)


## `rock-red-attacker 1 a1 a8`: dash toward A8 instead of the live crosshair.
func _apply_red_attacker_script_dash(body, entry) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.rock_type != RockInstance.RockSize.RED_ATTACKER:
		return
	if not (entry is Dictionary):
		return
	var end_row := int(entry.get("end_row", -1))
	var end_column := int(entry.get("end_column", -1))
	if end_row < 1 or end_column < 0:
		return
	var world := _aim_cell_world_position(end_row, end_column, false)
	if body.has_method("set_red_attacker_dash_aim"):
		body.set_red_attacker_dash_aim(world)


func _stay_aim_world(body, rock_index: int, entry) -> Vector3:
	if rock_index >= 0 and rock_index < _wave_telegraph_plan.size():
		return _wave_telegraph_plan[rock_index].aim
	var spawn_column := _x_to_nearest_column(body.target_x_position)
	var aim := _resolve_aim_cell(entry, true, spawn_column)
	return _aim_cell_world_position(aim.x, aim.y, true)


## Resolve `path_cells` from a rock-stay script entry into world points (no jitter).
func _stay_path_worlds(entry, rock_index: int = -1) -> Array:
	var out: Array = []
	if not (entry is Dictionary):
		return out
	var cells: Array = entry.get("path_cells", [])
	if cells.is_empty():
		## Fallback: single aim cell from classic stay fields.
		var ar := int(entry.get("aim_row", -1))
		var ac := int(entry.get("aim_column", -1))
		if ar >= 1 and ac >= 0:
			out.append(_aim_cell_world_position(ar, ac, false))
		return out
	var spawn_column := int(entry.get("column", -1))
	for cell in cells:
		var row := -1
		var col := -1
		if cell is Vector2i:
			row = int(cell.x)
			col = int(cell.y)
		elif cell is Dictionary:
			row = int(cell.get("row", -1))
			col = int(cell.get("column", -1))
		else:
			continue
		if row < 1 and col < 0:
			var resolved := _resolve_aim_cell({
				"aim_row": row,
				"aim_column": col,
				"column": spawn_column,
			}, true, spawn_column)
			row = int(resolved.x)
			col = int(resolved.y)
		elif row < 1 or col < 0:
			var resolved2 := _resolve_aim_cell({
				"aim_row": row if row >= 1 else -1,
				"aim_column": col if col >= 0 else -1,
				"column": spawn_column,
			}, true, spawn_column)
			row = int(resolved2.x)
			col = int(resolved2.y)
		out.append(_aim_cell_world_position(row, col, false))
	return out


func _stay_splash_exit_world(from_aim: Vector3) -> Vector3:
	## Aim below the play grid into water so exit velocity is downward (splash miss requires vy ≤ 0).
	if splash_zone and is_instance_valid(splash_zone):
		var p: Vector3 = splash_zone.global_position
		p.y = minf(p.y, from_aim.y - 8.0)
		return p
	return Vector3(from_aim.x, from_aim.y - 16.0, from_aim.z)


## Pigeons fly into the distance along the column fan (17° half-angle from world origin).
## `rock-pigeon 1` → spawn col 1, random aim cell on the fan.
## `rock-pigeon 1 A8` → spawn col 1, aim at col 8's distant point (row A height).
func _pigeon_launch_impulse(body, rock_index: int, upward_force: float) -> Vector3:
	var aim_point: Vector3
	if rock_index >= 0 and rock_index < _wave_telegraph_plan.size():
		aim_point = _wave_telegraph_plan[rock_index].aim
	else:
		var entry = null
		if rock_index >= 0 and rock_index < manual_rock_sequence.size():
			entry = manual_rock_sequence[rock_index]
		var aim := _resolve_aim_cell(entry)
		aim_point = _pigeon_aim_world_point(aim.y, aim.x, body.global_position.y)

	var y_force: float = upward_force
	var dx: float = aim_point.x - body.global_position.x
	var dz: float = aim_point.z - body.global_position.z

	var x_impulse := 0.0
	if absf(dz) > 0.001:
		# Keep depth impulse fixed; steer X so the path lines up with the aim point.
		x_impulse = pigeon_depth_impulse * (dx / dz)
	elif absf(dx) > 0.001:
		x_impulse = dx

	return Vector3(x_impulse, y_force, pigeon_depth_impulse) * pulse_magnitude


## Distant aim point for a column on the pigeon fan (optionally at an A/B/C height).
func _pigeon_aim_world_point(column: int, aim_row: int, fallback_y: float) -> Vector3:
	var clamped := clampi(column, 1, COLUMN_COUNT)
	var y: float = fallback_y
	if aim_row > 0:
		y = float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1]))

	var marker := _get_pigeon_aim_marker(clamped)
	if marker:
		return Vector3(marker.global_position.x, y, marker.global_position.z)

	# Reference construction: Vector3.ZERO → rotate Y by fan angle → push out.
	var angle := _pigeon_column_fan_angle(clamped)
	var offset := Vector3(sin(angle), 0.0, cos(angle)) * pigeon_aim_reference_depth
	return Vector3(offset.x, y, offset.z)


## Column 1 → +17°, column 8 → -17°, linear in between.
func _pigeon_column_fan_angle(column: int) -> float:
	var clamped := clampi(column, 1, COLUMN_COUNT)
	var t := float(clamped - 1) / float(COLUMN_COUNT - 1)
	return deg_to_rad(lerpf(pigeon_fan_half_angle_deg, -pigeon_fan_half_angle_deg, t))


func _get_pigeon_aim_marker(column: int) -> Marker3D:
	if pigeon_aim_markers == null:
		pigeon_aim_markers = get_node_or_null('../PigeonAimMarkers') as Node3D
	if pigeon_aim_markers == null:
		return null

	var by_name: Node = pigeon_aim_markers.get_node_or_null(str(column))
	if by_name is Marker3D:
		return by_name

	var markers: Array[Marker3D] = []
	for child in pigeon_aim_markers.get_children():
		if child is Marker3D:
			markers.append(child)
	if column >= 1 and column <= markers.size():
		return markers[column - 1]
	return null


func _x_to_nearest_column(x: float) -> int:
	var best := 1
	var best_dist := absf(x - column_to_x(1))
	for col in range(2, COLUMN_COUNT + 1):
		var dist := absf(x - column_to_x(col))
		if dist < best_dist:
			best_dist = dist
			best = col
	return best


## World X of the aim-grid column nearest to `x`.
func nearest_column_x(x: float) -> float:
	return column_to_x(_x_to_nearest_column(x))


## Ballistic launch through the aim cell world point (e.g. A8 = (-7, 6.5, 23)).
func _build_launch_impulse(body, rock_index: int, _upward_force: float, _z_variation: float, gravity_scale: float = -1.0) -> Vector3:
	var aim_pos: Vector3
	if rock_index >= 0 and rock_index < _wave_telegraph_plan.size():
		aim_pos = _wave_telegraph_plan[rock_index].aim
		if gravity_scale < 0.0:
			gravity_scale = float(_wave_telegraph_plan[rock_index].get("gravity_scale", aim_launch_gravity_scale))
	else:
		var entry = null
		if rock_index >= 0 and rock_index < manual_rock_sequence.size():
			entry = manual_rock_sequence[rock_index]
		var spawn_column := _x_to_nearest_column(body.target_x_position)
		var aim := _resolve_aim_cell(entry, true, spawn_column)
		aim_pos = _aim_cell_world_position(aim.x, aim.y, true)
		if gravity_scale < 0.0:
			gravity_scale = _aim_launch_gravity_for(body, entry)
	return _aimed_launch_impulse_to_world(body, aim_pos, gravity_scale)


func _lateral_launch_impulse(body, entry) -> Vector3:
	var column := _resolve_spawn_column(entry)
	var spawn :Vector3= body.global_position
	var aim := _resolve_aim_cell(entry, false, column)
	var aim_pos := _lateral_aim_world(aim)
	var dist := spawn.distance_to(aim_pos)
	var flight_t := clampf(dist / LATERAL_FLIGHT_SPEED, 0.45, 1.75)
	return BallisticAim.impulse_to_point(
		body, spawn, aim_pos, flight_t, LATERAL_LAUNCH_GRAVITY, 1.0, 0.0
	)


func _aim_cell_world_position(aim_row: int, aim_column: int, apply_jitter: bool = true) -> Vector3:
	var pos := Vector3(
		column_to_x_for_aim(aim_column),
		float(AIM_LANE_Y.get(aim_row, AIM_LANE_Y[1])),
		AIM_PLANE_Z
	)
	if apply_jitter and aim_offset > 0.0:
		# Uniform disk in the aim plane (X/Y); Z stays on the board depth.
		var angle := randf() * TAU
		var radius := aim_offset * sqrt(randf())
		pos.x += cos(angle) * radius
		pos.y += sin(angle) * radius
	return pos


## Exact aim-grid world point (A1–C8, plus optional side lanes 0 / 9). No jitter.
func aim_cell_world_position(aim_row: int, aim_column: int) -> Vector3:
	return _aim_cell_world_position(aim_row, aim_column, false)


## Quiz mode: keep the wave open while the questionnaire runs.
var _quiz_hold := false


func set_quiz_hold(active: bool) -> void:
	_quiz_hold = active
	if active:
		_waiting_until_clear = true
		_sequence_active = true
	else:
		_waiting_until_clear = false
		_sequence_active = false


## Launch a rock-stay for quiz answer selection. `answer_index` is stored as meta.
func spawn_quiz_answer_rock(aim_row: int, aim_column: int, answer_index: int):
	var body = _find_free_pool_rock()
	if body == null:
		push_warning("RockManager: no free pool rock for quiz answer")
		return null
	var entry := {
		"cmd": "rock-stay",
		"column": aim_column,
		"spawn_row": -1,
		"aim_row": aim_row,
		"aim_column": aim_column,
		"param": "",
	}
	var column := _resolve_spawn_column(entry)
	var spawn_x := _spawn_x_for_entry(entry, column)
	if body.has_method("setup_for_pool_launch"):
		body.setup_for_pool_launch(_spawn_entry_to_rock_type(entry), spawn_x)
	else:
		body.rock_type = _spawn_entry_to_rock_type(entry)
		body.target_x_position = spawn_x
		body.enter_state(body.State.PREPARE_ROCK)
	body.set_meta("quiz_answer_index", answer_index)
	body.set_meta("quiz_aim_row", aim_row)
	body.set_meta("quiz_aim_column", aim_column)
	body.cash_value = 0
	if "rock_stay_self_destruct" in body:
		body.rock_stay_self_destruct = false
	if "rock_stay_expire_gives_strike" in body:
		body.rock_stay_expire_gives_strike = false
	await get_tree().create_timer(0.2, false).timeout
	if not is_instance_valid(body) or body.current_state != body.State.PREPARE_ROCK:
		return null
	body.cash_value = 0
	if "rock_stay_self_destruct" in body:
		body.rock_stay_self_destruct = false
	body.enter_state(body.State.ACTIVE)
	var aim_pos := _aim_cell_world_position(aim_row, aim_column, false)
	if body.has_method("begin_rock_stay_flight"):
		body.begin_rock_stay_flight(aim_pos)
	## Lifetime may restart on begin_rock_stay_flight — disable again.
	if "rock_stay_self_destruct" in body:
		body.rock_stay_self_destruct = false
	if body.has_method("_start_rock_stay_lifetime"):
		## Cancel any just-started lifetime by bumping the token.
		if "_stay_life_token" in body:
			body._stay_life_token += 1
	return body


## Fire-and-forget red-attacker for quiz dodge swarms (cols 1/2/7/8, rows A/B).
func spawn_quiz_swarm_attacker(aim_row: int, aim_column: int) -> void:
	_spawn_quiz_swarm_attacker_async(aim_row, aim_column)


func _spawn_quiz_swarm_attacker_async(aim_row: int, aim_column: int) -> void:
	var body = _find_free_pool_rock()
	if body == null:
		return
	aim_row = clampi(aim_row, 1, 2)
	aim_column = clampi(aim_column, 1, 8)
	if aim_column > 2 and aim_column < 7:
		aim_column = 1 if randf() < 0.5 else 8
	var entry := {
		"cmd": "rock-red-attacker",
		"column": aim_column,
		"spawn_row": -1,
		"aim_row": aim_row,
		"aim_column": aim_column,
		"param": "",
	}
	var column := _resolve_spawn_column(entry)
	var spawn_x := _spawn_x_for_entry(entry, column)
	if body.has_method("setup_for_pool_launch"):
		body.setup_for_pool_launch(_spawn_entry_to_rock_type(entry), spawn_x)
	else:
		body.rock_type = _spawn_entry_to_rock_type(entry)
		body.target_x_position = spawn_x
		body.enter_state(body.State.PREPARE_ROCK)
	body.set_meta("quiz_swarm", true)
	await get_tree().create_timer(0.08, false).timeout
	if not is_instance_valid(body) or body.current_state != body.State.PREPARE_ROCK:
		return
	body.enter_state(body.State.ACTIVE)
	var launch_g := _aim_launch_gravity_for(body, entry)
	BallisticAim.configure_body_for_ballistic_launch(body, launch_g)
	if body.has_method("begin_ballistic_aim_feel"):
		body.begin_ballistic_aim_feel(aim_descent_linear_damp)
	var aim_pos := _aim_cell_world_position(aim_row, aim_column, true)
	var impulse := _aimed_launch_impulse_to_world(body, aim_pos, launch_g)
	body.apply_central_impulse(impulse)
	if rock_rock_collisions_enabled and body.has_method("schedule_airborne_rock_collisions"):
		body.schedule_airborne_rock_collisions(rock_rock_collision_delay_sec, rock_rock_bounce)


func aim_grid_row_count() -> int:
	return AIM_LANE_Y.size()


func aim_grid_column_count() -> int:
	return COLUMN_COUNT


## Inclusive min/max column indices for crosshair grid (adds 0 and 9 when side lanes on).
func aim_grid_column_bounds(include_side_lanes: bool) -> Vector2i:
	if include_side_lanes:
		return Vector2i(0, COLUMN_COUNT + 1)
	return Vector2i(1, COLUMN_COUNT)


## Launch position: column X is assigned in prepare; Y/Z come from the rock instance.
func _launch_world_position(body) -> Vector3:
	return Vector3(body.target_x_position, body.global_position.y, body.global_position.z)


## Reverse-engineered impulse so every lane passes through the same aim world point.
func _aimed_launch_impulse(body, aim_row: int, aim_column: int) -> Vector3:
	return _aimed_launch_impulse_to_world(body, _aim_cell_world_position(aim_row, aim_column, true))


func _aimed_launch_impulse_to_world(body, aim_pos: Vector3, gravity_scale: float = -1.0) -> Vector3:
	var start_pos := _launch_world_position(body)
	var g_scale := _aim_launch_gravity_for(body) if gravity_scale < 0.0 else gravity_scale
	return BallisticAim.impulse_to_point(
		body, start_pos, aim_pos, -1.0, g_scale, aim_impulse_scale, aim_hang_time_sec
	)


## Red-avoiders / red-attackers always launch at gravity 1.0, ignoring pace / difficulty.
## rock-stay / rock-stay-black / rock-cardinal ignore pace entirely (custom straight flight + hang).
func _aim_launch_gravity_for(body, entry = null) -> float:
	if body != null and is_instance_valid(body) and body.rock_type == RockInstance.RockSize.AVOIDER:
		return 1.0
	if body != null and is_instance_valid(body) and body.rock_type == RockInstance.RockSize.RED_ATTACKER:
		return 1.0
	if body != null and is_instance_valid(body) and body.has_method("is_stay_flight") and body.is_stay_flight():
		return 0.0
	if entry is Dictionary and entry.has("gravity_scale"):
		return float(entry.get("gravity_scale"))
	return aim_launch_gravity_scale


func spin_rocks(bodies: Array = []) -> void:
	if bodies.is_empty():
		bodies = $Container_1.get_children()

	var counter := 0
	for body in bodies:
		if counter >= rocks_limit:
			break
		if not (body is RockInstance):
			continue

		body.apply_torque_impulse(Vector3.LEFT * 3000.0)
		counter += 1
		
func update_gravity(_gravity_scale : float) -> void:
	#var counter := 0
	var bodies = $Container_1.get_children()
	for body in bodies:
		if not (body is RockInstance):
			continue
		body.update_gravity(_gravity_scale)
		#counter += 1

		#await get_tree().create_timer(0.01).timeout

func reset_all_rocks() -> void:
	_cancel_sequence()
	clear_cardinal_bursts()
	var bodies = $Container_1.get_children()

	for body in bodies:
		if body is RockInstance:
			body.enter_state(body.State.INACTIVE)


## Instantiates extra inactive rocks into Container_1 across frames to avoid hitching.
func ensure_extra_rocks(count: int = 80, per_frame: int = 4) -> void:
	if count <= 0:
		return
	if _boss_extra_rocks_added:
		return
	_boss_extra_rocks_added = true

	var container: Node3D = $Container_1
	var remaining := count
	while remaining > 0:
		var batch := mini(per_frame, remaining)
		for _i in batch:
			var rock: Node = ROCK_INSTANCE_SCENE.instantiate()
			container.add_child(rock)
			if rock.has_method("enter_state"):
				rock.enter_state(rock.State.INACTIVE)
			if rock is Node3D:
				(rock as Node3D).global_position = Vector3(0.0, -100.0, 0.0)
		remaining -= batch
		await get_tree().process_frame

		
func end_of_round() -> void:
	enter_state(State.ROUND_END)
			
func XXreset_rock_back_on() -> void:
	var bodies = $Container_1.get_children()
	var counter := 0

	for body in bodies:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.enter_state(body.State.INACTIVE)
		counter += 1
		if counter >= rocks_limit:
			break
		await get_tree().create_timer(0.2, false).timeout
	
	await get_tree().create_timer(0.2, false).timeout
	splash_zone.reset_detected_bodies()
	

func shuffle_current_sequence(_sequence: Array) -> void:
	if not randomize_later_waves:
		start_manual_rock_round(_sequence)
		return

	for idx in range(_sequence.size() - 1, -1, -1):
		var entry = _sequence[idx]

		if entry is Dictionary:
			var cmd: String = String(entry.get('cmd', '')).to_lower()
			# Keep wait / sequence barriers in place so launch stagger, balloon-checks, and clear survive shuffles.
			if cmd == 'wait' or cmd == 'wait-until-clear' or _is_balloon_check_cmd(cmd) or _is_ladder_balloon_cmd(cmd) or _is_clear_cmd(cmd) or cmd == 'pineapples' or cmd == 'ammo' or _is_script_sfx_cmd(cmd) or _is_pace_cmd(cmd) or _is_gun_cmd(cmd) or _is_light_cmd(cmd) or _is_avoider_kill_cmd(cmd):
				continue
			if cmd == 'balloon' or cmd == 'pineapple':
				continue
			if not _is_launchable_spawn_cmd(cmd):
				_sequence.remove_at(idx)
				continue
			if _is_lateral_launch(entry):
				_sequence[idx] = entry
				continue
			# Waves 2+: randomise column exactly like the old int shuffle.
			entry.column = randi_range(1, COLUMN_COUNT)
			_sequence[idx] = entry
			continue

		if typeof(entry) != TYPE_INT:
			_sequence.remove_at(idx)
			continue

		var value: int = entry
		if value >= 300:
			_sequence.remove_at(idx)
			continue

		if value < 10:
			_sequence[idx] = randi_range(1, 8)
		else:
			_sequence[idx] = (value / 10) * 10 + randi_range(1, 8)

	manual_rock_sequence = _sequence
	start_manual_rock_round(_sequence)
