extends Control
## Minimalistic 2D arcade overlay that runs inside the shop panel.
## Toggle with Shift+2 while the shop is open.

## Master size for crosshair target radius. Rock sizes are per-type below.
@export_range(0.25, 3.0, 0.05) var size_scale := 1.0

## How small the crosshair can shrink while holding fire (fraction of full size).
const CROSSHAIR_RADIUS := 68.0
const SCOPE_MIN_SCALE := 0.5
const SCOPE_EXPAND_MAX_SCALE := 2.0

@export_group("Scope Expand (Right Click)")
## How large the crosshair can grow while holding right-click (fraction of full size).

@export_group("Scenery")
@export var cloud_color := Color(1.0, 1.0, 1.0, 0.18)
@export_range(0.0, 120.0, 1.0) var cloud_pan_speed := 28.0
@export var mountain_far_color := Color(0.82, 0.76, 0.70, 0.28)
@export var mountain_near_color := Color(0.74, 0.66, 0.58, 0.42)

@export_group("Day Night Cycle")
@export var day_night_cycle_enabled := true
@export var day_sky_color := Color(0.92156863, 0.8784314, 0.84705883, 1.0)
@export var night_sky_color := Color(0.06, 0.09, 0.22, 1.0)
@export var blue_day_sky_color := Color(0.42, 0.68, 0.92, 1.0)
@export var star_color := Color(1.0, 0.98, 0.9, 0.9)
@export var moon_color := Color(0.92, 0.94, 1.0, 0.95)
@export_range(0.2, 3.0, 0.05) var sky_transition_duration := 1.0
## Wave numbers where the sky / colour scheme advances (phase 0 → 1 → 2…).
@export var environment_change_waves: Array[int] = [10, 20]

@export_group("Moon")
@export_range(0.0, 1.0, 0.01) var moon_x_ratio := 0.5
@export_range(0.0, 1.0, 0.01) var moon_y_ratio := 0.18
@export_range(8.0, 80.0, 0.5) var moon_base_radius := 22.0
@export_range(0.0, 20.0, 0.5) var moon_night_radius_boost := 6.0

@export_group("Colour Schemes")
@export var day_crosshair_color := Color(0.78039217, 0.003921569, 0.007843138, 1.0)
@export var day_money_color := Color(0.78039217, 0.003921569, 0.007843138, 1.0)
@export var day_strike_color := Color(0.78039217, 0.003921569, 0.007843138, 1.0)
@export var night_crosshair_color := Color(0.95, 0.92, 0.75, 1.0)
@export var night_money_color := Color(0.95, 0.92, 0.75, 1.0)
@export var night_strike_color := Color(0.95, 0.92, 0.75, 1.0)
@export var blue_day_crosshair_color := Color(0.12, 0.28, 0.55, 1.0)
@export var blue_day_money_color := Color(0.12, 0.28, 0.55, 1.0)
@export var blue_day_strike_color := Color(0.12, 0.28, 0.55, 1.0)

@export_group("Pillars")
@export var pillar_texture: Texture2D
@export_range(0.005, 0.3, 0.001) var pillar_width_ratio := 0.115
@export_range(0.0, 0.35, 0.001) var pillar_inset_ratio := 0.12
@export_range(0.005, 0.3, 0.001) var night_pillar_width_ratio := 0.07
@export_range(0.0, 0.35, 0.001) var night_pillar_inset_ratio := 0.2
@export_range(0.005, 0.3, 0.001) var blue_day_pillar_width_ratio := 0.14
@export_range(0.0, 0.35, 0.001) var blue_day_pillar_inset_ratio := 0.06
## Fit sprite by slot height while keeping texture aspect (fixes squish).
@export_range(0.5, 2.5, 0.01) var pillar_visual_height_scale := 1.05:
	set(value):
		pillar_visual_height_scale = value
		_pillar_layout_dirty()
## Move the whole pillar down (positive) / up (negative), as a fraction of play height.
@export_range(-0.2, 0.2, 0.001) var pillar_visual_y_offset_ratio := 0.025:
	set(value):
		pillar_visual_y_offset_ratio = value
		_pillar_layout_dirty()
## Extra pixel nudge after the ratio offset (positive = down).
@export var pillar_visual_y_offset_px := 0.0:
	set(value):
		pillar_visual_y_offset_px = value
		_pillar_layout_dirty()
## Collision width vs drawn sprite width (shaft is narrower than the rocky base).
@export_range(0.15, 1.0, 0.01) var pillar_collision_width_ratio := 0.38:
	set(value):
		pillar_collision_width_ratio = value
		_pillar_layout_dirty()
## Collision height vs drawn sprite height (trim antenna / empty padding).
@export_range(0.2, 1.0, 0.01) var pillar_collision_height_ratio := 0.72:
	set(value):
		pillar_collision_height_ratio = value
		_pillar_layout_dirty()
## Shift collision on the art; positive = lower on the sprite (fraction of drawn height).
@export_range(-0.4, 0.4, 0.01) var pillar_collision_y_offset_ratio := 0.06:
	set(value):
		pillar_collision_y_offset_ratio = value
		_pillar_layout_dirty()
## Shift collision horizontally on the art; flips with the right pillar (fraction of drawn width).
@export_range(-0.4, 0.4, 0.01) var pillar_collision_x_offset_ratio := 0.0:
	set(value):
		pillar_collision_x_offset_ratio = value
		_pillar_layout_dirty()

@export_group("Wind Particles")
@export var wind_enabled := true
@export_range(0, 120, 1) var wind_amount := 18
@export var wind_color := Color(1.0, 1.0, 1.0, 0.35)
@export_range(20.0, 400.0, 1.0) var wind_speed := 140.0
## How long / streaky each wind particle trail is.
@export_range(0.05, 2.0, 0.01) var wind_trail_length := 0.45
## Visual thickness of wind streaks.
@export_range(0.5, 12.0, 0.1) var wind_thickness := 3.5

@export_group("Shot Feedback")
@export var shot_crosshair_flash_color := Color(1.0, 0.92, 0.55, 1.0)
@export_range(0.05, 0.6, 0.01) var shot_crosshair_flash_time := 0.12
@export var shot_ring_color := Color(0.78, 0.02, 0.02, 0.85)
@export_range(40.0, 260.0, 1.0) var shot_ring_max_radius := 110.0
@export_range(0.05, 0.8, 0.01) var shot_ring_duration := 0.28

@export_group("Bullets")
@export_range(1, 24, 1) var bullets_per_wave := 12
@export var bullet_tick_color := Color(0.78, 0.02, 0.02, 0.85)
@export_range(2.0, 16.0, 0.5) var bullet_tick_length := 7.0
const bullet_tick_width := 50.0
@export_range(4.0, 40.0, 0.5) var bullet_tick_gap := 10.0

const CREAM := Color(0.92156863, 0.8784314, 0.84705883, 1.0)
const BORDER_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const INK := Color(0.0824, 0.0941, 0.1098, 1.0)
const CROSSHAIR_RED := Color(0.78039217, 0.003921569, 0.007843138, 1.0)

const WALL_Y_RATIO := 0.88

const PAD := Vector2(0.0, 0.0)
const HEADER_CLEARANCE := 120.0
const MAX_STRIKES := 10
const PILLAR_META := &"shop_mini_pillar"
const RING_POOL_SIZE := 8

const LEVEL_FILE_PATH := "res://sc/island-shipper.txt"
const LEVEL_ISLAND_NAME := "shipper"
const GRID_COLUMN_COUNT := 8
const GRID_LABEL_COLOR := Color(0.78, 0.02, 0.02, 0.85)
const GRID_LINE_COLOR := Color(0.78, 0.02, 0.02, 0.35)

@export_group("Aim Grid")
## Draw column/row aim cells in-game so you can tune placement live.
@export var display_grid := false
## Screen X of column 1 as a fraction of play width (3D: col1 is the rightmost board lane).
@export_range(0.0, 1.0, 0.001) var column_1_x_ratio := 0.82
## Distance between columns as a fraction of play width (next column = previous − spacing).
@export_range(0.01, 0.3, 0.001) var column_spacing_ratio := 0.09
## Extra pixel nudge on column 1 X (after ratio).
@export var column_1_x_offset := 0.0
## Extra pixel spacing between columns.
@export var column_spacing_offset := 0.0
## Row A / B / C heights as fractions of play height from the top.
@export_range(0.05, 0.95, 0.001) var row_a_y_ratio := 0.22
@export_range(0.05, 0.95, 0.001) var row_b_y_ratio := 0.40
@export_range(0.05, 0.95, 0.001) var row_c_y_ratio := 0.58
@export var row_a_y_offset := 0.0
@export var row_b_y_offset := 0.0
@export var row_c_y_offset := 0.0
@export_range(0.5, 2.0, 0.01) var aim_impulse_scale := 1.14
@export_range(0.05, 1.0, 0.01) var aim_launch_gravity_scale := 0.35
@export_range(0.0, 2.0, 0.05) var aim_hang_time_sec := 0.0
@export_range(0.0, 40.0, 0.5) var aim_offset_px := 0.0
@export var bias_random_aim_toward_center := true
@export_range(0.0, 1.0, 0.05) var converge_same_lane_chance := 0.5
@export var default_launch_wait_ms := 100

@export_group("Rock Pulse")
@export_range(50.0, 2000.0, 1.0) var launch_impulse := 450.0
@export_range(0.05, 5.0, 0.01) 	var fall_gravity_scale := 0.25
@export_range(0.0, 400.0, 1.0) 	var launch_x_jitter := 55.0
@export_range(0.0, 800.0, 1.0) 	var pulse_torque := 140.0
@export_range(0.0, 1.0, 0.01) 	var aim_together_chance := 0.8
@export_range(1, 10, 1) 		var rocks_per_wave := 4
@export_range(0.0, 1.0, 0.01) 	var pulse_stagger := 0.2
@export_range(0.5, 8.0, 0.05) 	var wave_interval := 2.2
@export_range(0.1, 3.0, 0.05) 	var mouse_sensitivity := 0.4

@export_group("Rock Physics")
@export var rock_physics_material: PhysicsMaterial

@export_group("Rock Types")
@export var basic_outline_color := Color(0.95, 0.82, 0.12, 1.0)
@export_range(0.0, 1.0, 0.01) var black_rock_chance := 0.15
@export_range(0.0, 1.0, 0.01) var red_rock_chance := 0.2
@export var red_hits_to_destroy := 3
@export var red_hit_bounce_force := 280.0
@export var red_hit_torque := 180.0

@export_group("Target Sizes")
@export_range(4.0, 80.0, 0.5) var basic_rock_size_min := 7.0
@export_range(4.0, 80.0, 0.5) var basic_rock_size_max := 13.0
@export_range(4.0, 80.0, 0.5) var black_rock_size_min := 8.0
@export_range(4.0, 80.0, 0.5) var black_rock_size_max := 14.0
@export_range(4.0, 80.0, 0.5) var red_rock_size_min := 9.0
@export_range(4.0, 80.0, 0.5) var red_rock_size_max := 16.0
@export_range(8.0, 40.0, 0.5) var smoke_can_size := 14.0
@export_range(8.0, 90.0, 0.5) var cherry_start_size := 22.0
@export_range(0.25, 3.0, 0.05) var rock_size_scale := 1.0
@export_range(0.25, 3.0, 0.05) var black_rock_size_scale := 1.0
@export_range(0.25, 3.0, 0.05) var smoke_can_size_scale := 1.0
@export_range(0.25, 3.0, 0.05) var cherry_size_scale := 1.0

@export_group("Trail")
@export var trail_enabled := true
@export_range(2, 40, 1) var trail_length := 18
@export_range(0.5, 8.0, 0.1) var trail_width := 3.0
@export var trail_color := Color(1, 0, 0, 0.55)

@export_group("Yellow Rock Particles")
@export var yellow_particles_enabled := true
@export_range(1, 64, 1) var yellow_particle_amount := 10
@export var yellow_particle_color := Color(0.95, 0.78, 0.18, 0.85)
@export_range(0.05, 2.0, 0.01) var yellow_particle_lifetime := 0.45
@export_range(10.0, 200.0, 1.0) var yellow_particle_speed := 55.0
@export_range(0.5, 8.0, 0.1) var yellow_particle_scale := 2.5

@export_group("Pineapples")
@export_range(1, 6, 1) var perfect_pineapple_count := 3
@export var pineapple_texture: Texture2D
@export_range(8.0, 90.0, 0.5) var pineapple_start_size := 32.0
@export_range(100.0, 2000.0, 1.0) var pineapple_launch_speed := 980.0
@export_range(0.1, 3.0, 0.01) var pineapple_shrink_speed := 0.9
@export_range(40.0, 400.0, 1.0) var pineapple_fly_speed := 160.0
@export var pineapple_money := 0.50
## Delay between each pineapple launch in the perfect bonus.
@export_range(0.0, 2.0, 0.05) var pineapple_pulse_stagger := 0.5

@export_group("Oranges")
@export var orange_texture: Texture2D
@export_range(8.0, 90.0, 0.5) var orange_start_size := 26.0
## How fast oranges climb from the wall to their hang point (pixels/sec).
@export_range(100.0, 2500.0, 1.0) var orange_ascent_speed := 1100.0
## Fraction of screen height from the top where oranges stop and hang (0.25 ≈ 3/4 up).
@export_range(0.05, 0.7, 0.01) var orange_apex_y_ratio := 0.25
@export_range(0.1, 3.0, 0.01) var orange_shrink_speed := 1.1
@export_range(40.0, 400.0, 1.0) var orange_fly_speed := 190.0
@export var orange_money := 0.35
@export_range(20.0, 280.0, 1.0) var orange_blast_radius := 90.0
@export_range(0.05, 0.8, 0.01) var orange_blast_duration := 0.28

@export_group("Cherries")
@export var cherry_texture: Texture2D
## Chance a double/multikill bonus fruit is a cherry (rest are oranges).
@export_range(0.0, 1.0, 0.01) var cherry_spawn_chance := 0.4
@export_range(100.0, 2500.0, 1.0) var cherry_launch_speed := 720.0
@export_range(0.05, 2.0, 0.01) var cherry_bounce := 0.85
@export_range(0.05, 2.0, 0.01) var cherry_gravity_scale := 0.55
@export var cherry_money := 0.25
@export_range(10.0, 45.0, 0.5) var cherry_angle_min_deg := 30.0
@export_range(10.0, 45.0, 0.5) var cherry_angle_max_deg := 45.0

@export_group("Balloons")
@export_range(0, 6, 1) var balloons_per_wave_max := 2
@export_range(0.0, 1.0, 0.01) var balloon_spawn_chance := 0.45
@export_range(8.0, 60.0, 0.5) var balloon_size := 22.0
@export var balloon_fill_color := Color(0.86, 0.18, 0.22, 1.0)
## Rest height as a fraction of play area height (lower = closer to wall).
@export_range(0.15, 0.75, 0.01) var balloon_rest_y_ratio := 0.42
@export_range(0.2, 3.0, 0.05) var balloon_approach_duration := 0.85
@export_range(0.0, 80.0, 1.0) var balloon_pan_distance := 18.0
@export_range(0.5, 6.0, 0.05) var balloon_pan_duration := 2.4

@export_group("Smoke Cans")
@export_range(0, 4, 1) var smoke_cans_per_wave_max := 1
@export_range(0.0, 1.0, 0.01) var smoke_can_spawn_chance := 0.35
@export var smoke_can_money := 0.10
@export_range(0.5, 8.0, 0.05) var smoke_cloud_duration := 3.5

@export_group("Money")
@export var money_per_destroy := 0.10
@export var black_rock_penalty := 1.0

@export_group("Screen Shake")
@export_range(0.0, 40.0, 0.1) var fire_shake_strength := 3.5
@export_range(0.0, 2.0, 0.01) var fire_shake_time := 0.08
@export_range(0.0, 40.0, 0.1) var launch_shake_strength := 5.0
@export_range(0.0, 2.0, 0.01) var launch_shake_time := 0.12
@export_range(0.0, 40.0, 0.1) var destroy_shake_strength := 8.0
@export_range(0.0, 2.0, 0.01) var destroy_shake_time := 0.14
@export_range(1.0, 30.0, 0.1) var shake_decay := 12.0
## Vertical-only shake when a missed rock costs a strike.
@export_range(0.0, 40.0, 0.1) var strike_miss_shake_strength := 11.0
@export_range(0.0, 2.0, 0.01) var strike_miss_shake_time := 0.38
@export_range(20.0, 120.0, 1.0) var strike_miss_shake_freq := 52.0

var is_open := false
var _intro_active := false
var _crosshair := Vector2.ZERO
var _aim_velocity := Vector2.ZERO
var _wave_phase := 0.0
var _cloud_pan := 0.0
var _wave_timer := 0.0
var _wave_index := 0
var _pulsing := false
var _game_over := false
var _paused := false
var _pause_label: RichTextLabel
var _pre_pause_body_state: Dictionary = {}
var _strikes := 0
var _money := 0.0
## Cumulative earnings for this open→close Shoot for Cents session (survives retries).
var _session_money := 0.0
var _fullscreen_overlay := true
var _rocks: Array[RigidBody2D] = []
var _fruits: Array[ShopMiniFruit] = []
var _balloons: Array[ShopMiniBalloon] = []
var _smoke_cans: Array[ShopMiniSmokeCan] = []
var _active_smoke: Array[Dictionary] = []
var _shot_flashes: Array[Dictionary] = []
var _shot_rings: Array[Dictionary] = []
var _ring_pool: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _follow_panel: Control
var _header_clearance := HEADER_CLEARANCE
var _stored_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _shake_trauma := 0.0
var _shake_strength := 0.0
var _shake_time := 0.0
var _strike_shake_trauma := 0.0
var _strike_shake_strength := 0.0
var _wave_layer_base_pos := Vector2(8, 8)
var _overlay_base_pos := Vector2(8, 8)
var _last_content_size := Vector2.ZERO
var _multikill_timer := 0.0
var _balloon_layer: Node2D
var _pillar_left: StaticBody2D
var _pillar_right: StaticBody2D
var _wind_particles: GPUParticles2D
var _crosshair_flash_tween: Tween
var _strikes_at_wave_start := 0
var _wave_earned_perfect := false
var _show_perfect_banner := false
var _in_perfect_pineapple_bonus := false
var _blast_rings: Array[Dictionary] = []
var _bullets := 12
var _out_label: RichTextLabel
var _star_seeds: PackedVector2Array = PackedVector2Array()
## Sky phase progress: 0 = cream day, 1 = night, 2 = blue day. Lerped during transitions.
var _sky_from := 0.0
var _sky_to := 0.0
var _sky_blend_t := 1.0

## Island-shipper script state (same rounds/waves as the 3D game).
var _script_rounds: Array = []
var _script_round_index := 0
var _script_wave_index := 0
var _script_range_id := ""
var _script_wave_spawns: Array = []
var _script_launch_delays: Array = []
var _script_launch_bodies: Array[RigidBody2D] = []
var _use_level_script := false
var _pending_range_announce := false
var _wave_aim_pool: Array[int] = []
var _wave_aim_mid := 0.0
var _wave_aim_center := -1
var _wave_convergence_aim_column := -1
var _wave_aim_converge_same_lane := true
var _range_label: RichTextLabel
var _active_hud_color := Color(0.78039217, 0.003921569, 0.007843138, 1.0)
var _pending_cents_dollars := 0
var _shop_menu: Control

enum ScopeMode { NONE, SHRINK, EXPAND }
var _scope_mode: ScopeMode = ScopeMode.NONE

@onready var _play_area: Panel = $PlayArea
@onready var _content: Control = $PlayArea/Content
@onready var _intro_title: RichTextLabel = get_node_or_null("PlayArea/IntroTitle") as RichTextLabel
@onready var _wave_layer: Control = $PlayArea/Content/WaveLayer
@onready var _physics_root: Node2D = $PlayArea/Content/PhysicsRoot
@onready var _overlay: Control = $PlayArea/Content/Overlay
@onready var _crosshair_node: Control = $PlayArea/Content/Overlay/Crosshair
@onready var _crosshair_texture: TextureRect = $PlayArea/Content/Overlay/Crosshair/CrosshairTexture
@onready var _money_label: RichTextLabel = $PlayArea/Content/Overlay/MoneyLabel
@onready var _session_winnings_label: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/SessionWinningsLabel") as RichTextLabel
@onready var _strike_label: RichTextLabel = $PlayArea/Content/Overlay/StrikeLabel
@onready var _wave_label: RichTextLabel = $PlayArea/Content/Overlay/WaveAnnounceLabel
@onready var _perfect_label: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/PerfectLabel") as RichTextLabel
@onready var _multikill_label: RichTextLabel = $PlayArea/Content/Overlay/MultiKillLabel
@onready var _game_over_panel: Control = $PlayArea/Content/Overlay/GameOverPanel
@onready var _game_over_money: RichTextLabel = $PlayArea/Content/Overlay/GameOverPanel/MoneyEarned
@onready var _game_over_lifetime: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/GameOverPanel/LifetimeEarned") as RichTextLabel
@onready var _retry_button: Button = $PlayArea/Content/Overlay/GameOverPanel/HBoxContainer/RetryButton
@onready var _close_button: Button = $PlayArea/Content/Overlay/GameOverPanel/HBoxContainer/CloseButton

@onready var _aoe: Node2D = $PlayArea/Content/AOE2D
@onready var _fruit_aoe: Node2D = get_node_or_null("PlayArea/Content/FruitAOE2D") as Node2D
@onready var _smoke_can_fx_template: GPUParticles2D = get_node_or_null("PlayArea/Content/SmokeCanFX") as GPUParticles2D
@onready var _sfx_take_damage: AudioStreamPlayer = $SFX/take_damage_sfx
@onready var _sfx_balloon_pop: AudioStreamPlayer = get_node_or_null("SFX/BalloonPop") as AudioStreamPlayer

@onready var _sfx_hit: AudioStreamPlayer = $SFX/hitSound
@onready var _sfx_hit_2: AudioStreamPlayer = $SFX/progress_rock_sound
@onready var _sfx_hit_3: AudioStreamPlayer = $SFX/pitch_shift_rock_sound
@onready var _sfx_hit_4: AudioStreamPlayer = $SFX/Gold_sfx

@onready var _sfx_hit_flicker: AudioStreamPlayer = $SFX/Flicker_sound

@onready var _sfx_explosion: AudioStreamPlayer = $SFX/explosion_sfx
@onready var _sfx_shoot: AudioStreamPlayer = $SFX/Shoot_sfx
@onready var _sfx_miss: AudioStreamPlayer = $SFX/cannot_shoot_sfx
@onready var _sfx_pulse: AudioStreamPlayer = $SFX/EggPulseSfx
@onready var _sfx_splash_01: AudioStreamPlayer = $SFX/splash_sfx_01
@onready var _sfx_splash_02: AudioStreamPlayer = $SFX/splash_sfx_02
@onready var _sfx_scope_shrink: AudioStreamPlayer = $SFX/ScopeShrink
@onready var _sfx_pineapple_launch: AudioStreamPlayer = get_node_or_null("SFX/Pineapple_launch_sound") as AudioStreamPlayer
@onready var _sfx_pineapple_hit: AudioStreamPlayer = get_node_or_null("SFX/Pineapple_sound_hit") as AudioStreamPlayer
@onready var _sfx_pineapple_explode: AudioStreamPlayer = get_node_or_null("SFX/Pineapple_shot_explode") as AudioStreamPlayer
@onready var _sfx_pineapple_destroyed: AudioStreamPlayer = get_node_or_null("SFX/Pineapple_destroyed") as AudioStreamPlayer
@onready var _sfx_multishot: AudioStreamPlayer = get_node_or_null("SFX/MultiShotSFX") as AudioStreamPlayer
@onready var _sfx_smoke_tick: AudioStreamPlayer = get_node_or_null("SFX/SmokeCanTick") as AudioStreamPlayer
@onready var _sfx_smoke_explode: AudioStreamPlayer = get_node_or_null("SFX/SmokeCanExplode") as AudioStreamPlayer
@onready var _sfx_wave_announce: AudioStreamPlayer = get_node_or_null("SFX/WaveAnnounce") as AudioStreamPlayer
@onready var _sfx_title_intro: AudioStreamPlayer = get_node_or_null("SFX/TitleIntro") as AudioStreamPlayer
@onready var _splash_aoe: Node2D = get_node_or_null("PlayArea/Content/SplashAOE2D") as Node2D
@onready var _miss_label: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/MissLabel") as RichTextLabel
@onready var _mouse_sfx: Node = $Mouse_turning_SFX

var _miss_timer := 0.0

# Scope shrink / expand (mirrors player.gd hold-to-shrink; RMB expands).
var _is_holding_shoot := false
var _scope_hold_time := 0.0
var _scope_at_limit := false
var _scope_base_scale := 1.0
var _scope_base_target_radius := 48.0
var _current_target_radius := 48.0
var _current_shrink_duration := 0.5
var _shrink_return_tween: Tween
const SCOPE_SHRINK_DURATION := 0.2
const SCOPE_SHRINK_DELAY := 0.15
const SCOPE_RETURN_DURATION := 0.3
const SCOPE_SHRINK_SFX_MIN_PITCH := 1.0
const SCOPE_SHRINK_SFX_MAX_PITCH := 1.5


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_setup_play_area_style()
	_ensure_default_physics_material()
	_ensure_default_fruit_textures()
	_wave_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_layer.draw.connect(_draw_waves_layer)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_overlay)
	_overlay.resized.connect(_on_overlay_resized)
	_retry_button.pressed.connect(_on_retry_pressed)
	_close_button.pressed.connect(close)
	_game_over_panel.hide()
	_wave_label.modulate.a = 0.0
	_multikill_label.modulate.a = 0.0
	_ensure_perfect_label()
	if _perfect_label:
		_perfect_label.modulate.a = 0.0
	if _miss_label:
		_miss_label.modulate.a = 0.0
	if _sfx_scope_shrink:
		_sfx_scope_shrink.finished.connect(_on_scope_shrink_sfx_finished)
	_reset_scope_visual()
	_refresh_hud()
	_ensure_pillars()
	_ensure_wind_particles()
	_ensure_ring_pool()
	_ensure_out_label()
	_init_star_seeds()
	_bullets = bullets_per_wave
	set_process(false)
	set_process_input(false)


func _ensure_default_physics_material() -> void:
	if rock_physics_material == null:
		rock_physics_material = PhysicsMaterial.new()
		rock_physics_material.bounce = 0.35
		rock_physics_material.friction = 0.4


func _ensure_default_fruit_textures() -> void:
	if pineapple_texture == null:
		pineapple_texture = load("res://unfiled/Decal_placeholders/pineapple_outline.png") as Texture2D
	if orange_texture == null:
		orange_texture = load("res://res/orange_dented_texture.png") as Texture2D
	if cherry_texture == null:
		cherry_texture = load("res://unfiled/Decal_placeholders/Cherry_placeholder_icon.png") as Texture2D


func _setup_play_area_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BORDER_WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	_play_area.add_theme_stylebox_override("panel", style)
	_play_area.clip_contents = true


func attach_to_shop(shop_root: Control, main_panel: Control = null, header_clearance: float = HEADER_CLEARANCE) -> void:
	_shop_menu = shop_root
	_follow_panel = main_panel
	_header_clearance = header_clearance
	# Fullscreen overlay by default; pass a panel only if you want the old inset fit.
	_fullscreen_overlay = main_panel == null
	if shop_root and get_parent() != shop_root:
		reparent(shop_root)
	top_level = true
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_to_panel()


func _sync_to_panel() -> void:
	if _fullscreen_overlay:
		_sync_fullscreen()
		return
	if _follow_panel == null or not is_instance_valid(_follow_panel):
		_sync_fullscreen()
		return
	if not _follow_panel.is_visible_in_tree():
		return
	var panel_rect := _follow_panel.get_global_rect()
	var panel_h := maxf(_follow_panel.size.y, 1.0)
	var header_px := panel_rect.size.y * (_header_clearance / panel_h)
	var pad_x := PAD.x * (panel_rect.size.x / maxf(_follow_panel.size.x, 1.0))
	var pad_y := PAD.y * (panel_rect.size.y / panel_h)
	var top_left := panel_rect.position + Vector2(pad_x, header_px)
	var bottom_right := panel_rect.position + panel_rect.size - Vector2(pad_x, pad_y)
	var next_size := bottom_right - top_left
	if next_size.x < 64.0 or next_size.y < 64.0:
		return
	_apply_layout_rect(top_left, next_size)


func _sync_fullscreen() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var rect := vp.get_visible_rect()
	_apply_layout_rect(rect.position, rect.size)


func _apply_layout_rect(top_left: Vector2, next_size: Vector2) -> void:
	global_position = top_left
	size = next_size
	if _content:
		if _last_content_size != size:
			_content.size = size
			_last_content_size = size
		# Keep Content fixed — never shake the physics parent.
		_content.position = Vector2.ZERO
	_capture_visual_base_positions()
	_apply_shake_to_visuals()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	CommonCode.set_master_bus_retro_fx(true)
	_stored_mouse_mode = Input.mouse_mode
	_session_money = 0.0
	_reset_run()
	_sync_to_panel()
	modulate.a = 0.0
	show()
	# Stay above shop UI as a full-screen overlay.
	if get_parent():
		get_parent().move_child(self, -1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	_sync_to_panel()
	_center_crosshair()
	await _play_open_intro()
	if not is_open:
		return
	_ensure_pillars()
	_sync_pillars()
	_update_wind_particles()
	_wave_layer.queue_redraw()
	_overlay.queue_redraw()
	set_process_input(true)
	_boot_level_script()
	_apply_colour_scheme_for_progress(_sky_visual_progress())
	_begin_next_wave()


func _boot_level_script() -> void:
	_script_range_id = _resolve_start_range_id()
	_load_range_script(_script_range_id)
	# Initial sky follows wave thresholds (environment_change_waves), not range id.
	_begin_sky_transition_for_wave(0)
	_pending_range_announce = true


func _cents_range_order() -> PackedStringArray:
	## First three playable places from dataset (skip start / testing for cents waves).
	var out: PackedStringArray = PackedStringArray()
	var names := gl_DataSet.get_place_names()
	var testing := gl_DataSet.get_testing_place_name()
	var start_name := gl_DataSet.get_start_place_name()
	for n in names:
		if n == start_name or n == "start" or n == testing:
			continue
		out.append(n)
		if out.size() >= 3:
			break
	if out.is_empty():
		out.append(gl_DataSet.get_default_range_name())
	return out


func _resolve_start_range_id() -> String:
	var range_id := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	if range_id == "" or range_id == gl_DataSet.get_start_place_name() or range_id == "start":
		return gl_DataSet.get_default_range_name()
	if gl_DataSet.is_testing_place(range_id):
		return gl_DataSet.get_testing_place_name()
	return range_id


func _sky_progress_for_range(range_id: String) -> float:
	var order := _cents_range_order()
	var idx := order.find(gl_DataSet.resolve_place_name(range_id))
	if idx < 0:
		return 0.0
	return float(mini(idx, 2))


func _advance_to_next_range() -> void:
	var order := _cents_range_order()
	var idx := order.find(_script_range_id)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % order.size()
	_script_range_id = order[idx]
	_load_range_script(_script_range_id)
	_pending_range_announce = true


func _load_range_script(range_id: String) -> void:
	_script_rounds.clear()
	_script_round_index = 0
	_script_wave_index = 0
	_script_wave_spawns.clear()
	_script_launch_delays.clear()
	_script_launch_bodies.clear()
	_use_level_script = false
	if not Parser.loadIslandFile(LEVEL_FILE_PATH):
		push_warning("ShopMiniGame: failed to load %s" % LEVEL_FILE_PATH)
		return
	_script_rounds = Parser.get_rock_sequences(LEVEL_ISLAND_NAME, range_id)
	_use_level_script = not _script_rounds.is_empty()
	if not _use_level_script:
		push_warning("ShopMiniGame: no rounds for range \"%s\"" % range_id)


func _display_range_name(range_id: String) -> String:
	if range_id.is_empty():
		return gl_DataSet.get_default_range_name().capitalize()
	return range_id.substr(0, 1).to_upper() + range_id.substr(1)


func _ensure_range_label() -> void:
	if _range_label and is_instance_valid(_range_label):
		return
	_range_label = RichTextLabel.new()
	_range_label.name = "RangeAnnounceLabel"
	_range_label.bbcode_enabled = true
	_range_label.fit_content = true
	_range_label.scroll_active = false
	_range_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_range_label.add_theme_color_override("default_color", INK)
	_range_label.add_theme_font_size_override("normal_font_size", 70)
	_range_label.add_theme_font_size_override("italics_font_size", 34)
	_range_label.modulate.a = 0.0
	_overlay.add_child(_range_label)
	_range_label.set_anchors_preset(Control.PRESET_CENTER)
	_range_label.offset_left = -280.0
	_range_label.offset_right = 280.0
	_range_label.offset_top = -160.0
	_range_label.offset_bottom = -100.0


func _show_range_announce() -> void:
	_ensure_range_label()
	_range_label.text = "Shooting Range: %s" % _display_range_name(_script_range_id)
	_range_label.modulate.a = 0.0
	_range_label.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_range_label, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_range_label, "scale", Vector2.ONE, 0.25)
	tween.tween_interval(1.1)
	tween.tween_property(_range_label, "modulate:a", 0.0, 0.3)
	await tween.finished


func _current_round_data() -> Dictionary:
	if _script_round_index < 0 or _script_round_index >= _script_rounds.size():
		return {}
	var data = _script_rounds[_script_round_index]
	return data if data is Dictionary else {}


func _current_wave_spawn_list() -> Array:
	var round_data := _current_round_data()
	if round_data.is_empty():
		return []
	var waves := _unique_waves_for_round(round_data)
	if waves.is_empty():
		return []
	if _script_wave_index < 0 or _script_wave_index >= waves.size():
		return []
	return waves[_script_wave_index] as Array


func _unique_waves_for_round(round_data: Dictionary) -> Array:
	## Mini-game skips `repeat` duplicates — each distinct wave body plays once.
	var waves: Array = round_data.get("waves", [])
	if waves.is_empty():
		var spawns: Array = round_data.get("spawns", []) as Array
		return [spawns] if not spawns.is_empty() else []
	var unique: Array = []
	for wave in waves:
		if wave is Array:
			if unique.is_empty() or not _wave_bodies_equal(unique.back() as Array, wave as Array):
				unique.append(wave)
	return unique


func _wave_bodies_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for idx in a.size():
		if str(a[idx]) != str(b[idx]):
			return false
	return true


func _advance_script_cursor() -> void:
	if not _use_level_script:
		return
	var round_data := _current_round_data()
	if round_data.is_empty():
		_advance_to_next_range()
		return
	var waves := _unique_waves_for_round(round_data)
	var wave_count := waves.size()
	if wave_count <= 0:
		wave_count = 1
	_script_wave_index += 1
	if _script_wave_index < wave_count:
		return
	_script_wave_index = 0
	_script_round_index += 1
	if _script_round_index >= _script_rounds.size():
		_advance_to_next_range()
		return


func _is_launchable_spawn_cmd(cmd: String) -> bool:
	return (
		cmd == "rock"
		or cmd == "rock-black"
		or cmd == "rock-pigeon"
		or cmd == "red_rock_error"
		or cmd == "smokecan"
		or cmd == "rock-avoider"
		or cmd == "rock-chaser"
	)


func _column_to_x(column: int) -> float:
	var area := _overlay.size
	var clamped := clampi(column, 1, GRID_COLUMN_COUNT)
	var c1 := column_1_x_ratio * area.x + column_1_x_offset
	var step := column_spacing_ratio * area.x + column_spacing_offset
	return c1 - float(clamped - 1) * step


func _row_to_y(row: int) -> float:
	var area := _overlay.size
	match clampi(row, 1, 3):
		2:
			return row_b_y_ratio * area.y + row_b_y_offset
		3:
			return row_c_y_ratio * area.y + row_c_y_offset
		_:
			return row_a_y_ratio * area.y + row_a_y_offset


func _aim_cell_position(aim_row: int, aim_column: int) -> Vector2:
	var pos := Vector2(_column_to_x(aim_column), _row_to_y(aim_row))
	if aim_offset_px > 0.0:
		var angle := _rng.randf() * TAU
		var radius := aim_offset_px * sqrt(_rng.randf())
		pos += Vector2(cos(angle), sin(angle)) * radius
	return pos


func _resolve_spawn_column(entry) -> int:
	if entry is Dictionary:
		var column: int = int(entry.get("column", -1))
		if column < 1:
			return _rng.randi_range(1, GRID_COLUMN_COUNT)
		return clampi(column, 1, GRID_COLUMN_COUNT)
	return _rng.randi_range(1, GRID_COLUMN_COUNT)


func _resolve_aim_cell(entry, apply_center_bias: bool = false, spawn_column: int = -1) -> Vector2i:
	var aim_row := 0
	var aim_column := 0
	if entry is Dictionary:
		aim_row = int(entry.get("aim_row", -1))
		aim_column = int(entry.get("aim_column", -1))
	if aim_row < 1:
		aim_row = 1
	if aim_column < 1:
		if apply_center_bias and bias_random_aim_toward_center and not _wave_aim_pool.is_empty():
			aim_column = _pick_wave_aim_column(spawn_column)
		else:
			aim_column = _rng.randi_range(1, GRID_COLUMN_COUNT)
	return Vector2i(aim_row, clampi(aim_column, 1, GRID_COLUMN_COUNT))


func _pick_wave_aim_column(spawn_column: int) -> int:
	if _wave_aim_converge_same_lane and _wave_convergence_aim_column >= 1:
		return _wave_convergence_aim_column
	var side_pool: Array[int] = []
	if spawn_column < 1 or _wave_aim_center < 1:
		side_pool = _wave_aim_pool.duplicate()
	elif float(spawn_column) < _wave_aim_mid:
		for col in _wave_aim_pool:
			if col >= _wave_aim_center:
				side_pool.append(col)
	elif float(spawn_column) > _wave_aim_mid:
		for col in _wave_aim_pool:
			if col <= _wave_aim_center:
				side_pool.append(col)
	else:
		side_pool = _wave_aim_pool.duplicate()
	if side_pool.is_empty():
		side_pool = _wave_aim_pool.duplicate()
	if side_pool.is_empty():
		return _rng.randi_range(1, GRID_COLUMN_COUNT)
	return side_pool[_rng.randi() % side_pool.size()]


func _rebuild_wave_aim_convergence(spawn_columns: Array[int]) -> void:
	_wave_convergence_aim_column = -1
	_wave_aim_converge_same_lane = true
	_wave_aim_mid = 0.0
	_wave_aim_center = -1
	_wave_aim_pool.clear()
	if spawn_columns.is_empty():
		return
	var leftmost := spawn_columns[0]
	var rightmost := spawn_columns[0]
	for col in spawn_columns:
		leftmost = mini(leftmost, col)
		rightmost = maxi(rightmost, col)
	var mid := (float(leftmost) + float(rightmost)) * 0.5
	var center := clampi(roundi(mid), 1, GRID_COLUMN_COUNT)
	var pool: Array[int] = []
	for col in range(center - 1, center + 2):
		if col >= 1 and col <= GRID_COLUMN_COUNT:
			pool.append(col)
	_wave_aim_pool = pool
	_wave_aim_mid = mid
	_wave_aim_center = center
	_wave_aim_converge_same_lane = _rng.randf() < converge_same_lane_chance
	if _wave_aim_converge_same_lane and not _wave_aim_pool.is_empty():
		_wave_convergence_aim_column = _wave_aim_pool[_rng.randi() % _wave_aim_pool.size()]


func _kind_from_spawn_cmd(cmd: String) -> ShopMiniRock.RockKind:
	match cmd:
		"rock-black":
			return ShopMiniRock.RockKind.BLACK
		"red_rock_error":
			return ShopMiniRock.RockKind.RED
		"rock-avoider":
			return ShopMiniRock.RockKind.AVOIDER
		"rock-chaser":
			return ShopMiniRock.RockKind.CHASER
		_:
			return ShopMiniRock.RockKind.BASIC


func _parse_wave_launchables(sequence: Array) -> void:
	_script_wave_spawns.clear()
	_script_launch_delays.clear()
	var pending_wait_ms = null
	var is_first := true
	for entry in sequence:
		if not (entry is Dictionary):
			continue
		var cmd := String(entry.get("cmd", "")).to_lower()
		if cmd == "wait":
			pending_wait_ms = int(entry.get("ms", default_launch_wait_ms))
			continue
		if not _is_launchable_spawn_cmd(cmd):
			continue
		if is_first:
			_script_launch_delays.append(0.0)
			is_first = false
		else:
			var wait_ms: int = default_launch_wait_ms if pending_wait_ms == null else int(pending_wait_ms)
			_script_launch_delays.append(float(wait_ms) / 1000.0)
		pending_wait_ms = null
		_script_wave_spawns.append(entry)


func _spawn_script_balloons(sequence: Array, _wall_y: float) -> void:
	_ensure_balloon_layer()
	var area := _overlay.size
	for entry in sequence:
		if not (entry is Dictionary):
			continue
		if String(entry.get("cmd", "")).to_lower() != "balloon":
			continue
		var row := int(entry.get("row", -1))
		var col := int(entry.get("column", -1))
		if row < 1:
			row = _rng.randi_range(1, 3)
		if col < 1:
			col = _rng.randi_range(1, GRID_COLUMN_COUNT)
		var balloon := ShopMiniBalloon.new()
		_balloon_layer.add_child(balloon)
		balloon.fill_color = balloon_fill_color
		balloon.approach_duration = balloon_approach_duration
		balloon.pan_distance = balloon_pan_distance
		balloon.pan_duration = balloon_pan_duration
		balloon.setup(balloon_size * size_scale)
		var rest := Vector2(_column_to_x(col), _row_to_y(row))
		rest.x = _clamp_spawn_x(rest.x, balloon.radius)
		var from := Vector2(rest.x + _rng.randf_range(-12.0, 12.0), area.y + balloon.radius + 40.0)
		balloon.begin_approach(from, rest)
		balloon.popped.connect(_on_balloon_popped)
		_balloons.append(balloon)


func _make_script_rock(entry: Dictionary, spawn_column: int, delay_sec: float, wall_y: float) -> ShopMiniRock:
	var cmd := String(entry.get("cmd", "")).to_lower()
	var kind := _kind_from_spawn_cmd(cmd)
	var radius := _radius_for_kind(kind)
	var rock := ShopMiniRock.new()
	_physics_root.add_child(rock)
	rock.outline_color = basic_outline_color
	rock.red_hits_to_destroy = red_hits_to_destroy
	rock.red_hit_bounce_force = red_hit_bounce_force
	rock.red_hit_torque = red_hit_torque
	rock.trail_enabled = trail_enabled
	rock.trail_length = trail_length
	rock.trail_width = trail_width
	rock.trail_color = trail_color
	rock.physics_material = rock_physics_material
	rock.yellow_particles_enabled = yellow_particles_enabled
	rock.yellow_particle_amount = yellow_particle_amount
	rock.yellow_particle_color = yellow_particle_color
	rock.yellow_particle_lifetime = yellow_particle_lifetime
	rock.yellow_particle_speed = yellow_particle_speed
	rock.yellow_particle_scale = yellow_particle_scale
	rock.host = self
	rock.setup(radius, _make_rock_outline(radius), kind)
	rock.spawn_column = spawn_column
	rock.spawn_entry = entry
	rock.launch_delay_sec = delay_sec
	rock.position = Vector2(
		_clamp_spawn_x(_column_to_x(spawn_column), radius),
		wall_y + radius + _rng.randf_range(6.0, 16.0) * size_scale
	)
	rock.rotation = _rng.randf_range(-0.25, 0.25)
	_rocks.append(rock)
	return rock


func _make_script_smoke_can(entry: Dictionary, spawn_column: int, delay_sec: float, wall_y: float) -> ShopMiniSmokeCan:
	var can := ShopMiniSmokeCan.new()
	_physics_root.add_child(can)
	can.setup(smoke_can_size * size_scale * smoke_can_size_scale, rock_physics_material)
	can.spawn_column = spawn_column
	can.spawn_entry = entry
	can.launch_delay_sec = delay_sec
	can.position = Vector2(
		_clamp_spawn_x(_column_to_x(spawn_column), can.radius),
		wall_y + can.radius + _rng.randf_range(6.0, 16.0)
	)
	can.smoked.connect(_on_smoke_can_smoked)
	can.destroyed.connect(_on_smoke_can_destroyed)
	can.exploded.connect(_on_smoke_can_exploded)
	can.apex_tick.connect(_on_smoke_can_apex_tick)
	_smoke_cans.append(can)
	return can


func _prepare_script_wave() -> void:
	_release_wave_balloons()
	_clear_rocks(false, false)
	_ensure_pillars()
	_sync_pillars()
	_script_launch_bodies.clear()
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var sequence := _current_wave_spawn_list()
	if bool(_current_round_data().get("shuffle", false)) and _script_wave_index > 0:
		sequence = sequence.duplicate(true)
		_shuffle_wave_columns(sequence)
	_parse_wave_launchables(sequence)
	_spawn_script_balloons(sequence, wall_y)

	var spawn_cols: Array[int] = []
	for i in _script_wave_spawns.size():
		var entry: Dictionary = _script_wave_spawns[i]
		var col := _resolve_spawn_column(entry)
		var delay := float(_script_launch_delays[i]) if i < _script_launch_delays.size() else 0.0
		var cmd := String(entry.get("cmd", "")).to_lower()
		if cmd == "smokecan":
			var can := _make_script_smoke_can(entry, col, delay, wall_y)
			_script_launch_bodies.append(can)
		else:
			var rock := _make_script_rock(entry, col, delay, wall_y)
			_script_launch_bodies.append(rock)
			spawn_cols.append(col)
	_rebuild_wave_aim_convergence(spawn_cols)


func _shuffle_wave_columns(sequence: Array) -> void:
	for entry in sequence:
		if not (entry is Dictionary):
			continue
		var cmd := String(entry.get("cmd", "")).to_lower()
		if cmd == "wait":
			continue
		if not _is_launchable_spawn_cmd(cmd):
			continue
		entry.column = _rng.randi_range(1, GRID_COLUMN_COUNT)


func _ensure_intro_title() -> void:
	if _intro_title and is_instance_valid(_intro_title):
		return
	_intro_title = RichTextLabel.new()
	_intro_title.name = "IntroTitle"
	_intro_title.bbcode_enabled = true
	_intro_title.fit_content = true
	_intro_title.scroll_active = false
	_intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_title.add_theme_color_override("default_color", INK)
	_intro_title.add_theme_font_size_override("normal_font_size", 42)
	_intro_title.add_theme_font_size_override("italics_font_size", 42)
	#_intro_title.text = "[i]Shoot for CENTS"
	_play_area.add_child(_intro_title)
	_intro_title.set_anchors_preset(Control.PRESET_CENTER)
	_intro_title.offset_left = -280.0
	_intro_title.offset_right = 280.0
	_intro_title.offset_top = -40.0
	_intro_title.offset_bottom = 40.0
	_intro_title.z_index = 20


func _play_open_intro() -> void:
	_ensure_intro_title()
	_intro_active = true
	# Blank cream panel only — hide the playfield until the title fades out.
	if _content:
		_content.visible = false
	if _wind_particles:
		_wind_particles.emitting = false
		_wind_particles.hide()
	#_intro_title.text = "[i]Shoot for CENTS"
	_intro_title.modulate.a = 0.0
	_intro_title.show()
	_intro_title.scale = Vector2.ONE / 99
	if _sfx_title_intro:
		_sfx_title_intro.pitch_scale = 1.0
		_sfx_title_intro.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(_intro_title, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(_intro_title, "scale", Vector2.ONE * 1.25, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_property(_intro_title, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_intro_title, "modulate:a", 0.0, 0.4)
	tween.tween_interval(0.1)
	await tween.finished
	if is_instance_valid(_intro_title):
		_intro_title.hide()
		_intro_title.modulate.a = 0.0
	if _content:
		_content.visible = true
	_intro_active = false


func close() -> void:
	if not is_open:
		return
	is_open = false
	_intro_active = false
	if _paused:
		_set_paused(false)
	CommonCode.set_master_bus_retro_fx(false)
	_pulsing = false
	_game_over = false
	_reset_scope_visual()
	set_process(false)
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(false)
	if _intro_title:
		_intro_title.hide()
		_intro_title.modulate.a = 0.0
	if _content:
		_content.visible = true
	_pending_cents_dollars = maxi(int(floor(_session_money)), 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	if not is_open:
		hide()
		_clear_rocks(true)
		_shot_flashes.clear()
		_shot_rings.clear()
		_update_wind_particles()
		_payout_cents_to_shop()


func _payout_cents_to_shop() -> void:
	var dollars := _pending_cents_dollars
	_pending_cents_dollars = 0
	_money = 0.0
	_session_money = 0.0
	if dollars <= 0:
		return
	if _shop_menu and _shop_menu.has_method("receive_cents_winnings"):
		_shop_menu.receive_cents_winnings(dollars)
	else:
		gl_PlayerState.add_cash(dollars)
		if EventBus.instance:
			EventBus.instance.update_money.emit()


func _ensure_perfect_label() -> void:
	if _perfect_label and is_instance_valid(_perfect_label):
		return
	_perfect_label = RichTextLabel.new()
	_perfect_label.name = "PerfectLabel"
	_perfect_label.bbcode_enabled = true
	_perfect_label.fit_content = true
	_perfect_label.scroll_active = false
	_perfect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_perfect_label.add_theme_color_override("default_color", Color(0.92, 0.62, 0.18, 1.0))
	_perfect_label.add_theme_font_size_override("normal_font_size", 36)
	_perfect_label.add_theme_font_size_override("italics_font_size", 36)
	_perfect_label.text = "PERFECT"
	_perfect_label.modulate.a = 0.0
	_overlay.add_child(_perfect_label)
	_perfect_label.set_anchors_preset(Control.PRESET_CENTER)
	_perfect_label.offset_left = -180.0
	_perfect_label.offset_right = 180.0
	_perfect_label.offset_top = -120.0
	_perfect_label.offset_bottom = -60.0


func _reset_run() -> void:
	_clear_rocks(true)
	_clear_active_smoke()
	_shot_flashes.clear()
	_shot_rings.clear()
	_blast_rings.clear()
	_wave_timer = 0.0
	_wave_phase = 0.0
	_cloud_pan = 0.0
	_wave_index = 0
	_pulsing = false
	_game_over = false
	_paused = false
	_pre_pause_body_state.clear()
	if _pause_label:
		_pause_label.hide()
		_pause_label.modulate.a = 0.0
	_strikes = 0
	_money = 0.0
	_aim_velocity = Vector2.ZERO
	_shake_trauma = 0.0
	_shake_strength = 0.0
	_shake_time = 0.0
	_strike_shake_trauma = 0.0
	_strike_shake_strength = 0.0
	_multikill_timer = 0.0
	_miss_timer = 0.0
	_strikes_at_wave_start = 0
	_wave_earned_perfect = false
	_show_perfect_banner = false
	_in_perfect_pineapple_bonus = false
	_bullets = bullets_per_wave
	_sky_from = 0.0
	_sky_to = 0.0
	_sky_blend_t = 1.0
	_script_rounds.clear()
	_script_round_index = 0
	_script_wave_index = 0
	_script_wave_spawns.clear()
	_script_launch_delays.clear()
	_script_launch_bodies.clear()
	_use_level_script = false
	_pending_range_announce = false
	_wave_aim_pool.clear()
	_wave_convergence_aim_column = -1
	_game_over_panel.hide()
	if _game_over_lifetime:
		_game_over_lifetime.hide()
	_wave_label.modulate.a = 0.0
	_multikill_label.modulate.a = 0.0
	if _range_label:
		_range_label.modulate.a = 0.0
	if _perfect_label:
		_perfect_label.modulate.a = 0.0
	if _miss_label:
		_miss_label.modulate.a = 0.0
	if _crosshair_node:
		_crosshair_node.modulate = Color.WHITE
	_capture_visual_base_positions()
	_apply_shake_to_visuals()
	_refresh_hud()
	_center_crosshair()
	_sync_pillars()
	_update_wind_particles()


func _on_retry_pressed() -> void:
	_reset_run()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(true)
	_boot_level_script()
	_apply_colour_scheme_for_progress(_sky_visual_progress())
	_begin_next_wave()


func _clear_rocks(clear_oranges: bool = false, clear_balloons: bool = true) -> void:
	for rock in _rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	_rocks.clear()
	if clear_balloons:
		for balloon in _balloons:
			if is_instance_valid(balloon):
				balloon.queue_free()
		_balloons.clear()
	for can in _smoke_cans:
		if is_instance_valid(can):
			can.queue_free()
	_smoke_cans.clear()
	var kept_fruits: Array[ShopMiniFruit] = []
	for fruit in _fruits:
		if not is_instance_valid(fruit):
			continue
		var keep := (
			not clear_oranges
			and not fruit.hit
			and (
				fruit.kind == ShopMiniFruit.FruitKind.ORANGE
				or fruit.kind == ShopMiniFruit.FruitKind.CHERRY
			)
		)
		if keep:
			kept_fruits.append(fruit)
			continue
		fruit.queue_free()
	_fruits = kept_fruits
	if _physics_root:
		for child in _physics_root.get_children():
			if child.get_meta(PILLAR_META, false):
				continue
			if child in kept_fruits:
				continue
			child.queue_free()


## End-of-wave: balloons stay until this, then float up and leave.
func _release_wave_balloons() -> void:
	var leaving: Array[ShopMiniBalloon] = _balloons.duplicate()
	_balloons.clear()
	for balloon in leaving:
		if not is_instance_valid(balloon) or balloon.hit:
			if is_instance_valid(balloon):
				balloon.queue_free()
			continue
		if not balloon.drifted_away.is_connected(_on_balloon_drifted_away):
			balloon.drifted_away.connect(_on_balloon_drifted_away, CONNECT_ONE_SHOT)
		balloon.begin_drift_away(-90.0)


func _on_balloon_drifted_away(balloon: ShopMiniBalloon) -> void:
	if is_instance_valid(balloon):
		balloon.queue_free()


func _center_crosshair() -> void:
	var area := _overlay.size
	if area.x <= 1.0 or area.y <= 1.0:
		return
	_crosshair = area * 0.5
	_reset_scope_visual()
	_update_crosshair_node()


func _base_target_radius() -> float:
	return CROSSHAIR_RADIUS * size_scale


## True once the scope has shrunk enough to destroy red rocks.
## Expanded (right-click) shots never count as charged.
func _scope_is_charged() -> bool:
	if _scope_mode == ScopeMode.EXPAND:
		return false
	var min_radius := _base_target_radius() * SCOPE_MIN_SCALE
	return _current_target_radius <= min_radius * 1.05


func _reset_scope_visual() -> void:
	_is_holding_shoot = false
	_scope_mode = ScopeMode.NONE
	_scope_at_limit = false
	_scope_hold_time = 0.0
	_scope_base_scale = 1.0
	_scope_base_target_radius = _base_target_radius()
	_current_target_radius = _scope_base_target_radius
	if _shrink_return_tween:
		_shrink_return_tween.kill()
		_shrink_return_tween = null
	if _sfx_scope_shrink:
		_sfx_scope_shrink.stop()
		_sfx_scope_shrink.pitch_scale = SCOPE_SHRINK_SFX_MIN_PITCH
	if _crosshair_node:
		_crosshair_node.pivot_offset = _crosshair_node.size * 0.5
		_crosshair_node.scale = Vector2.ONE * _scope_base_scale


func _update_crosshair_node() -> void:
	if _crosshair_node:
		_crosshair_node.pivot_offset = _crosshair_node.size * 0.5
		_crosshair_node.position = _crosshair - _crosshair_node.size * 0.5


func _on_overlay_resized() -> void:
	if is_open:
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_update_crosshair_node()
		_sync_pillars()
		_update_wind_particles()
		_overlay.queue_redraw()
		_wave_layer.queue_redraw()


func _process(delta: float) -> void:
	if not is_open:
		return
	_sync_to_panel()
	if _intro_active:
		return
	if _paused:
		_wave_layer.queue_redraw()
		_overlay.queue_redraw()
		return
	_wave_phase += delta * 2.2
	_cloud_pan += delta * cloud_pan_speed
	_update_sky_transition(delta)
	if not _game_over:
		_handle_keyboard_and_controller_aim(delta)
		_handle_shoot_actions()
		_handle_scope_adjust(delta)
	_update_flashes(delta)
	_update_shot_rings(delta)
	_update_blast_rings(delta)
	_update_active_smoke(delta)
	_update_shake(delta)
	_cleanup_fallen_rocks()

	if _multikill_timer > 0.0:
		_multikill_timer -= delta
		if _multikill_timer <= 0.0:
			_multikill_label.modulate.a = 0.0

	if _miss_timer > 0.0:
		_miss_timer -= delta
		if _miss_timer <= 0.0 and _miss_label:
			_miss_label.modulate.a = 0.0

	if not _game_over and not _pulsing and _alive_target_count() == 0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_on_wave_targets_cleared()

	_wave_layer.queue_redraw()
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or _intro_active:
		return

	if event.is_action_pressed("escape") and not event.is_echo():
		if _game_over:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if _paused or _game_over:
		return

	if Input.is_action_just_pressed("increase_scope_speed"):
		GameSettings.bump_mouse_sensitivity(1)
		get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed("decrease_scope_speed"):
		GameSettings.bump_mouse_sensitivity(-1)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		# Same resolution-independent look curve as the main 3D game.
		_crosshair += GameSettings.mouse_look_delta((event as InputEventMouseMotion).relative)
		_clamp_crosshair()
		_update_crosshair_node()
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_3:
			_debug_launch_orange()
			get_viewport().set_input_as_handled()


## WASD + left stick aim — mirrors Player.handle_keyboard_and_controller_input.
func _handle_keyboard_and_controller_aim(delta: float) -> void:
	# Raw stick axes keep full 360° aim (InputMap deadzones snap diagonals to cardinals).
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	const STICK_DEADZONE := 0.12
	var raw: Vector2
	if stick.length() > STICK_DEADZONE:
		raw = stick
	else:
		raw = Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("forward", "backward")
		)
	# Stick tilt scales speed (partial push = slower). Keys read as ±1 so stay full speed.
	var magnitude := clampf(raw.length(), 0.0, 1.0)
	var has_input := magnitude > STICK_DEADZONE

	const keyboard_crosshair_speed := 1300.0
	var speed := keyboard_crosshair_speed * GameSettings.crosshair_speed_multiplier()
	if Input.is_action_pressed("sprint"):
		speed *= 0.5

	var target_velocity := Vector2.ZERO
	if has_input:
		var strength := pow(magnitude, 1.35)
		target_velocity = raw.normalized() * speed * strength

	const ACCEL := 60.0
	const DECEL := 18.0
	var lerp_speed := ACCEL if has_input else DECEL
	_aim_velocity = _aim_velocity.lerp(target_velocity, lerp_speed * delta)

	if _aim_velocity.length_squared() < 0.01 and not has_input:
		_aim_velocity = Vector2.ZERO
		return

	_crosshair += _aim_velocity * delta
	_clamp_crosshair()
	_update_crosshair_node()


## Fire / scope via the same InputMap actions as the main game (mouse, Space, A, X, etc.).
func _handle_shoot_actions() -> void:
	if Input.is_action_just_pressed("shootWeapon"):
		_begin_scope_hold(ScopeMode.SHRINK)
	elif Input.is_action_just_released("shootWeapon"):
		_release_scope_and_shoot(ScopeMode.SHRINK)

	if Input.is_action_just_pressed("shoot_weapon_2"):
		_begin_scope_hold(ScopeMode.EXPAND)
	elif Input.is_action_just_released("shoot_weapon_2"):
		_release_scope_and_shoot(ScopeMode.EXPAND)


func _clamp_crosshair() -> void:
	_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
	_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)


func _begin_scope_hold(mode: ScopeMode) -> void:
	_is_holding_shoot = true
	_scope_mode = mode
	_scope_hold_time = 0.0
	_scope_at_limit = false
	_scope_base_target_radius = _base_target_radius()
	_current_target_radius = _scope_base_target_radius
	if _shrink_return_tween:
		_shrink_return_tween.kill()
		_shrink_return_tween = null
	_current_shrink_duration = SCOPE_SHRINK_DURATION


func _release_scope_and_shoot(mode: ScopeMode) -> void:
	if not _is_holding_shoot or _scope_mode != mode:
		return
	_is_holding_shoot = false
	_scope_at_limit = false
	if _sfx_scope_shrink:
		_sfx_scope_shrink.stop()
		_sfx_scope_shrink.pitch_scale = SCOPE_SHRINK_SFX_MIN_PITCH
	_try_shoot()
	_scope_mode = ScopeMode.NONE
	_tween_scope_back_to_base()


func _handle_scope_adjust(delta: float) -> void:
	if not _is_holding_shoot or _scope_mode == ScopeMode.NONE:
		return

	_scope_hold_time += delta
	if _scope_hold_time < SCOPE_SHRINK_DELAY:
		return
	if _scope_at_limit:
		return

	if _sfx_scope_shrink and not _sfx_scope_shrink.playing and _scope_hold_time < (SCOPE_SHRINK_DELAY + 0.2):
		_sfx_scope_shrink.play()

	var t := clampf((_scope_hold_time - SCOPE_SHRINK_DELAY) / maxf(_current_shrink_duration, 0.001), 0.0, 1.0)
	var target_radius := _scope_base_target_radius
	if _scope_mode == ScopeMode.SHRINK:
		target_radius = _scope_base_target_radius * SCOPE_MIN_SCALE
	else:
		target_radius = _scope_base_target_radius * SCOPE_EXPAND_MAX_SCALE
	_current_target_radius = lerpf(_scope_base_target_radius, target_radius, t)
	var scale_ratio := _current_target_radius / maxf(_scope_base_target_radius, 0.001)

	if _sfx_scope_shrink:
		_sfx_scope_shrink.pitch_scale += lerpf(
			SCOPE_SHRINK_SFX_MIN_PITCH,
			SCOPE_SHRINK_SFX_MAX_PITCH,
			0.005
		)

	if _crosshair_node:
		_crosshair_node.scale = Vector2.ONE * (_scope_base_scale * scale_ratio)

	if t >= 1.0:
		_scope_at_limit = true


func _on_scope_shrink_sfx_finished() -> void:
	if _scope_at_limit:
		return
	if _is_holding_shoot and _scope_hold_time >= SCOPE_SHRINK_DELAY:
		if _sfx_scope_shrink:
			_sfx_scope_shrink.play()


func _tween_scope_back_to_base() -> void:
	if _shrink_return_tween:
		_shrink_return_tween.kill()
	if _crosshair_node == null:
		_current_target_radius = _base_target_radius()
		return
	_shrink_return_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_shrink_return_tween.tween_interval(0.1)
	_shrink_return_tween.tween_property(_crosshair_node, "scale", Vector2.ONE * _scope_base_scale, SCOPE_RETURN_DURATION)
	var start_radius := _current_target_radius
	var end_radius := _base_target_radius()
	_shrink_return_tween.parallel().tween_method(
		func(v: float) -> void: _current_target_radius = v,
		start_radius,
		end_radius,
		SCOPE_RETURN_DURATION
	)


func _begin_next_wave() -> void:
	if _pulsing or _game_over:
		return
	_pulsing = true
	_wave_index += 1
	if _use_level_script and _wave_index > 1:
		_advance_script_cursor()
	await _show_wave_announce(_wave_index, _show_perfect_banner)
	_show_perfect_banner = false
	if not is_open or _game_over:
		_pulsing = false
		return
	_strikes_at_wave_start = _strikes
	_wave_earned_perfect = false
	_in_perfect_pineapple_bonus = false
	_prepare_rocks()
	await _pulse_rocks()
	_pulsing = false
	_wave_timer = wave_interval


func _on_wave_targets_cleared() -> void:
	if _pulsing or _game_over:
		return
	# Lock immediately so the process loop cannot re-enter while we await.
	_pulsing = true

	if _in_perfect_pineapple_bonus:
		_in_perfect_pineapple_bonus = false
		_show_perfect_banner = true
		_pulsing = false
		_begin_next_wave()
		return

	var perfect := _strikes == _strikes_at_wave_start and _wave_index > 0
	if perfect:
		_wave_earned_perfect = true
		await _run_perfect_pineapple_bonus()
		return

	_pulsing = false
	_begin_next_wave()


func _run_perfect_pineapple_bonus() -> void:
	if _game_over:
		_pulsing = false
		return
	_in_perfect_pineapple_bonus = true
	_release_wave_balloons()
	_clear_rocks(false, false)
	_ensure_pillars()
	_sync_pillars()
	_spawn_perfect_pineapples()
	await _pulse_rocks()
	_pulsing = false
	_wave_timer = wave_interval * 0.5


func _show_wave_announce(wave: int, show_perfect: bool = false) -> void:
	_ensure_perfect_label()
	# Reload ammo as soon as the wave banner appears.
	_bullets = bullets_per_wave
	# Colour scheme / sky always follows wave count (environment_change_waves).
	_begin_sky_transition_for_wave(wave)
	if _pending_range_announce:
		_pending_range_announce = false
		await _show_range_announce()
		if not is_open or _game_over:
			return
	_wave_label.text = "[i]%s" % _wave_display_name(wave)
	_wave_label.modulate.a = 0.0
	_wave_label.scale = Vector2(0.85, 0.85)
	if _perfect_label:
		_perfect_label.modulate.a = 0.0
		_perfect_label.scale = Vector2(0.85, 0.85)
	if _sfx_wave_announce:
		_sfx_wave_announce.pitch_scale = _rng.randf_range(0.95, 1.08)
		_sfx_wave_announce.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if show_perfect and _perfect_label:
		_perfect_label.text = "PERFECT"
		tween.tween_property(_perfect_label, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(_perfect_label, "scale", Vector2.ONE, 0.2)
		tween.tween_interval(0.15)
	tween.tween_property(_wave_label, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_wave_label, "scale", Vector2.ONE, 0.25)
	tween.tween_interval(0.7)
	tween.tween_property(_wave_label, "modulate:a", 0.0, 0.25)
	if show_perfect and _perfect_label:
		tween.parallel().tween_property(_perfect_label, "modulate:a", 0.0, 0.25)
	await tween.finished


func _wave_display_name(wave: int) -> String:
	const ORDINALS := ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth"]
	if wave >= 1 and wave <= ORDINALS.size():
		return "%s Wave" % ORDINALS[wave - 1]
	return "Wave %d" % wave


func _prepare_rocks() -> void:
	if _use_level_script:
		_prepare_script_wave()
		return
	_release_wave_balloons()
	_clear_rocks(false, false)
	_ensure_pillars()
	_sync_pillars()
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var count := randi_range(2, 4) # rocks_per_wave
	for i in count:
		var column_t := float(i + 1) / float(count + 1)
		var kind := _roll_rock_kind()
		var radius := _radius_for_kind(kind)
		var rock := ShopMiniRock.new()
		_physics_root.add_child(rock)
		rock.outline_color = basic_outline_color
		rock.red_hits_to_destroy = red_hits_to_destroy
		rock.red_hit_bounce_force = red_hit_bounce_force
		rock.red_hit_torque = red_hit_torque
		rock.trail_enabled = trail_enabled
		rock.trail_length = trail_length
		rock.trail_width = trail_width
		rock.trail_color = trail_color
		rock.physics_material = rock_physics_material
		rock.yellow_particles_enabled = yellow_particles_enabled
		rock.yellow_particle_amount = yellow_particle_amount
		rock.yellow_particle_color = yellow_particle_color
		rock.yellow_particle_lifetime = yellow_particle_lifetime
		rock.yellow_particle_speed = yellow_particle_speed
		rock.yellow_particle_scale = yellow_particle_scale
		rock.host = self
		rock.setup(radius, _make_rock_outline(radius), kind)
		var raw_x := area.x * column_t + _rng.randf_range(-18.0, 18.0)
		rock.position = Vector2(
			_clamp_spawn_x(raw_x, radius),
			wall_y + radius + _rng.randf_range(8.0, 22.0) * size_scale
		)
		rock.rotation = _rng.randf_range(-0.25, 0.25)
		_rocks.append(rock)
	_spawn_wave_balloons(wall_y)
	_spawn_wave_smoke_cans(wall_y)


func _spawn_wave_balloons(_wall_y: float) -> void:
	if balloons_per_wave_max <= 0 or _rng.randf() > balloon_spawn_chance:
		return
	_ensure_balloon_layer()
	var count := _rng.randi_range(1, balloons_per_wave_max)
	var area := _overlay.size
	var rest_y := area.y * balloon_rest_y_ratio
	for i in count:
		var balloon := ShopMiniBalloon.new()
		_balloon_layer.add_child(balloon)
		balloon.fill_color = balloon_fill_color
		balloon.approach_duration = balloon_approach_duration
		balloon.pan_distance = balloon_pan_distance
		balloon.pan_duration = balloon_pan_duration
		balloon.setup(balloon_size * size_scale)
		var column_t := float(i + 1) / float(count + 1)
		var rest_x := area.x * lerpf(0.22, 0.78, column_t) + _rng.randf_range(-20.0, 20.0)
		rest_x = _clamp_spawn_x(rest_x, balloon.radius)
		var rest := Vector2(rest_x, rest_y + _rng.randf_range(-18.0, 18.0))
		var from := Vector2(rest.x + _rng.randf_range(-12.0, 12.0), area.y + balloon.radius + 40.0)
		balloon.begin_approach(from, rest)
		balloon.popped.connect(_on_balloon_popped)
		_balloons.append(balloon)


func _ensure_balloon_layer() -> void:
	if _balloon_layer and is_instance_valid(_balloon_layer):
		return
	_balloon_layer = _content.get_node_or_null("BalloonLayer") as Node2D
	if _balloon_layer == null:
		_balloon_layer = Node2D.new()
		_balloon_layer.name = "BalloonLayer"
		_content.add_child(_balloon_layer)
		# Sit with PhysicsRoot so coords match rocks, but draw above them.
		if _physics_root:
			_balloon_layer.position = _physics_root.position
			_content.move_child(_balloon_layer, _physics_root.get_index() + 1)
	_balloon_layer.z_index = 50


func _spawn_wave_smoke_cans(wall_y: float) -> void:
	if smoke_cans_per_wave_max <= 0 or _rng.randf() > smoke_can_spawn_chance:
		return
	var count := _rng.randi_range(1, smoke_cans_per_wave_max)
	var area := _overlay.size
	for i in count:
		var can := ShopMiniSmokeCan.new()
		_physics_root.add_child(can)
		can.setup(smoke_can_size * size_scale * smoke_can_size_scale, rock_physics_material)
		var raw_x := area.x * _rng.randf_range(0.2, 0.8)
		can.position = Vector2(
			_clamp_spawn_x(raw_x, can.radius),
			wall_y + can.radius + _rng.randf_range(8.0, 20.0)
		)
		can.smoked.connect(_on_smoke_can_smoked)
		can.destroyed.connect(_on_smoke_can_destroyed)
		can.exploded.connect(_on_smoke_can_exploded)
		can.apex_tick.connect(_on_smoke_can_apex_tick)
		_smoke_cans.append(can)


## Playable X range. Wave 20+ allows spawning outside the pillars.
func _spawn_x_bounds(margin: float) -> Vector2:
	var area := _overlay.size
	if _wave_index >= 20:
		var edge := maxf(margin + 4.0, 8.0)
		return Vector2(edge, area.x - edge)
	var ratios := _current_pillar_ratios()
	var pillar_w := maxf(area.x * ratios.x, 8.0)
	var inset := area.x * ratios.y
	var left := inset + pillar_w + margin
	var right := area.x - inset - pillar_w - margin
	if right <= left:
		return Vector2(area.x * 0.35, area.x * 0.65)
	return Vector2(left, right)


func _clamp_spawn_x(x: float, radius: float) -> float:
	var bounds := _spawn_x_bounds(radius + 6.0)
	return clampf(x, bounds.x, bounds.y)


func _radius_for_kind(kind: ShopMiniRock.RockKind) -> float:
	match kind:
		ShopMiniRock.RockKind.BLACK:
			return _rng.randf_range(minf(black_rock_size_min, black_rock_size_max), maxf(black_rock_size_min, black_rock_size_max)) * size_scale * black_rock_size_scale
		ShopMiniRock.RockKind.RED:
			return _rng.randf_range(minf(red_rock_size_min, red_rock_size_max), maxf(red_rock_size_min, red_rock_size_max)) * size_scale * rock_size_scale
		ShopMiniRock.RockKind.AVOIDER, ShopMiniRock.RockKind.CHASER:
			return _rng.randf_range(minf(basic_rock_size_min, basic_rock_size_max), maxf(basic_rock_size_min, basic_rock_size_max)) * size_scale * rock_size_scale * 1.15
		_:
			return _rng.randf_range(minf(basic_rock_size_min, basic_rock_size_max), maxf(basic_rock_size_min, basic_rock_size_max)) * size_scale * rock_size_scale


func _spawn_perfect_pineapples() -> void:
	if pineapple_texture == null:
		return
	var area := _overlay.size
	var wall_y := area.y * WALL_Y_RATIO
	var count := perfect_pineapple_count
	for i in count:
		var column_t := float(i + 1) / float(count + 1)
		var fruit := _make_fruit(ShopMiniFruit.FruitKind.PINEAPPLE, pineapple_start_size, pineapple_texture)
		var raw_x := area.x * column_t + _rng.randf_range(-22.0, 22.0)
		fruit.position = Vector2(
			_clamp_spawn_x(raw_x, fruit.radius),
			wall_y + fruit.radius + _rng.randf_range(8.0, 24.0)
		)
		fruit.rotation = _rng.randf_range(-0.3, 0.3)
		_fruits.append(fruit)


func _make_fruit(kind: ShopMiniFruit.FruitKind, start_size: float, texture: Texture2D) -> ShopMiniFruit:
	var fruit := ShopMiniFruit.new()
	_physics_root.add_child(fruit)
	var mat := rock_physics_material
	if kind == ShopMiniFruit.FruitKind.CHERRY:
		mat = PhysicsMaterial.new()
		mat.bounce = cherry_bounce
		mat.friction = 0.15
	var radius := start_size * 0.5 * size_scale
	if kind == ShopMiniFruit.FruitKind.CHERRY:
		radius *= cherry_size_scale
	fruit.setup(kind, radius, texture, mat)
	match kind:
		ShopMiniFruit.FruitKind.PINEAPPLE:
			fruit.shrink_speed = pineapple_shrink_speed
			fruit.fly_speed = pineapple_fly_speed
		ShopMiniFruit.FruitKind.ORANGE:
			fruit.shrink_speed = orange_shrink_speed
			fruit.fly_speed = orange_fly_speed
			fruit.hang_apex_y = _overlay.size.y * orange_apex_y_ratio
			fruit.ascent_speed = orange_ascent_speed
		ShopMiniFruit.FruitKind.CHERRY:
			fruit.shrink_speed = orange_shrink_speed
			fruit.fly_speed = orange_fly_speed
	fruit.flyaway_finished.connect(_on_fruit_flyaway_finished)
	fruit.orange_exploded.connect(_on_orange_exploded)
	return fruit


func _debug_launch_orange() -> void:
	if orange_texture == null and cherry_texture == null:
		return
	_spawn_bonus_fruit_from_multikill(2, _crosshair.x)


func _spawn_bonus_fruit_from_multikill(count: int, _origin_x: float) -> void:
	# Double = 1 fruit, triple = 2, etc.
	var fruit_count := maxi(count - 1, 0)
	if fruit_count <= 0:
		return
	var area := _overlay.size
	var wall_y := area.y * WALL_Y_RATIO
	for i in fruit_count:
		var use_cherry := _rng.randf() < cherry_spawn_chance and cherry_texture != null
		if use_cherry:
			_spawn_cherry_from_center(wall_y)
		else:
			if orange_texture == null:
				continue
			var fruit := _make_fruit(ShopMiniFruit.FruitKind.ORANGE, orange_start_size, orange_texture)
			var raw_x := area.x * 0.5 + _rng.randf_range(-40.0, 40.0)
			fruit.position = Vector2(
				_clamp_spawn_x(raw_x, fruit.radius),
				wall_y + fruit.radius + _rng.randf_range(6.0, 18.0)
			)
			fruit.rotation = _rng.randf_range(-0.4, 0.4)
			_fruits.append(fruit)
			var torque := _rng.randf_range(-pulse_torque, pulse_torque)
			fruit.pulse(orange_ascent_speed, _rng.randf_range(-launch_x_jitter * 0.35, launch_x_jitter * 0.35), 0.0, torque)
		if _sfx_pineapple_launch:
			_sfx_pineapple_launch.pitch_scale = _rng.randf_range(1.05, 1.2)
			_sfx_pineapple_launch.play()
		if i < fruit_count - 1:
			await get_tree().create_timer(0.45, false).timeout


func _spawn_cherry_from_center(wall_y: float) -> void:
	if cherry_texture == null:
		return
	var area := _overlay.size
	var fruit := _make_fruit(ShopMiniFruit.FruitKind.CHERRY, cherry_start_size, cherry_texture)
	fruit.position = Vector2(
		_clamp_spawn_x(area.x * 0.5, fruit.radius),
		wall_y + fruit.radius + _rng.randf_range(4.0, 12.0)
	)
	fruit.rotation = _rng.randf_range(-0.5, 0.5)
	_fruits.append(fruit)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var angle := _rng.randf_range(
		minf(cherry_angle_min_deg, cherry_angle_max_deg),
		maxf(cherry_angle_min_deg, cherry_angle_max_deg)
	) * side
	var torque := _rng.randf_range(-pulse_torque * 1.4, pulse_torque * 1.4)
	fruit.pulse_angled(cherry_launch_speed, angle, cherry_gravity_scale, torque)


## Legacy name kept for any external callers.
func _spawn_oranges_from_multikill(count: int, origin_x: float) -> void:
	await _spawn_bonus_fruit_from_multikill(count, origin_x)


func _roll_rock_kind() -> ShopMiniRock.RockKind:
	var roll := _rng.randf()
	if roll < black_rock_chance:
		return ShopMiniRock.RockKind.BLACK
	if roll < black_rock_chance + red_rock_chance:
		return ShopMiniRock.RockKind.RED
	return ShopMiniRock.RockKind.BASIC


func _pulse_rocks() -> void:
	if _use_level_script and not _in_perfect_pineapple_bonus:
		if _sfx_pulse:
			_sfx_pulse.play()
		_add_shake(launch_shake_strength, launch_shake_time)
		await _pulse_scripted_bodies()
		return

	var to_pulse: Array[RigidBody2D] = []
	for rock in _rocks:
		if is_instance_valid(rock) and not rock.hit:
			to_pulse.append(rock)
	for fruit in _fruits:
		# Oranges already in the air carry over — don't re-pulse them.
		if is_instance_valid(fruit) and not fruit.hit and not fruit.flying_away and not fruit.pulsed:
			to_pulse.append(fruit)
	for can in _smoke_cans:
		if is_instance_valid(can) and not can.hit and not can.pulsed:
			to_pulse.append(can)
	if to_pulse.is_empty():
		return

	if _sfx_pulse:
		_sfx_pulse.play()

	_add_shake(launch_shake_strength, launch_shake_time)

	var aim_together := _rng.randf() < aim_together_chance and to_pulse.size() >= 2
	var center := Vector2.ZERO
	if aim_together:
		for body in to_pulse:
			center += body.position
		center /= float(to_pulse.size())

	for body in to_pulse:
		await _await_while_paused()
		if not is_open or _game_over:
			return
		if not is_instance_valid(body) or body.get("hit") == true:
			continue
		var impulse := launch_impulse
		var fruit := body as ShopMiniFruit
		if fruit:
			if fruit.kind == ShopMiniFruit.FruitKind.PINEAPPLE:
				impulse = pineapple_launch_speed
			else:
				impulse = orange_ascent_speed
				fruit.hang_apex_y = _overlay.size.y * orange_apex_y_ratio
				fruit.ascent_speed = orange_ascent_speed
			if _sfx_pineapple_launch:
				_sfx_pineapple_launch.pitch_scale = _rng.randf_range(0.92, 1.08)
				_sfx_pineapple_launch.play()
		var x_impulse := _rng.randf_range(-launch_x_jitter, launch_x_jitter)
		if fruit and fruit.kind == ShopMiniFruit.FruitKind.ORANGE:
			x_impulse = _rng.randf_range(-launch_x_jitter * 0.35, launch_x_jitter * 0.35)
		elif aim_together:
			var toward := center.x - body.position.x
			x_impulse = clampf(toward * 0.85, -impulse * 0.55, impulse * 0.55)
			x_impulse += _rng.randf_range(-launch_x_jitter * 0.25, launch_x_jitter * 0.25)
		var torque := _rng.randf_range(-pulse_torque, pulse_torque)
		if absf(torque) < pulse_torque * 0.35:
			torque = pulse_torque * (1.0 if _rng.randf() > 0.5 else -1.0)
		var grav := 0.0 if (fruit and fruit.kind == ShopMiniFruit.FruitKind.ORANGE) else fall_gravity_scale
		if fruit and fruit.kind == ShopMiniFruit.FruitKind.CHERRY:
			grav = cherry_gravity_scale
		body.pulse(impulse, x_impulse, grav, torque)
		var wait := pulse_stagger
		if fruit and fruit.kind == ShopMiniFruit.FruitKind.PINEAPPLE:
			wait = pineapple_pulse_stagger
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			await _await_while_paused()


func _pulse_scripted_bodies() -> void:
	for body in _script_launch_bodies:
		await _await_while_paused()
		if not is_open or _game_over:
			return
		if not is_instance_valid(body) or body.get("hit") == true:
			continue

		var delay := 0.0
		var entry: Dictionary = {}
		var spawn_col := 1
		var rock := body as ShopMiniRock
		var can := body as ShopMiniSmokeCan
		if rock:
			delay = rock.launch_delay_sec
			entry = rock.spawn_entry
			spawn_col = rock.spawn_column
		elif can:
			delay = can.launch_delay_sec
			entry = can.spawn_entry
			spawn_col = can.spawn_column

		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
			await _await_while_paused()
			if not is_open or _game_over:
				return
			if not is_instance_valid(body) or body.get("hit") == true:
				continue

		var aim := _resolve_aim_cell(entry, true, spawn_col)
		var aim_pos := _aim_cell_position(aim.x, aim.y)
		var velocity = BallisticAim2D.velocity_to_point(
			body.position,
			aim_pos,
			-1.0,
			aim_launch_gravity_scale,
			aim_hang_time_sec
		) * aim_impulse_scale
		var torque := _rng.randf_range(-pulse_torque, pulse_torque)
		if absf(torque) < pulse_torque * 0.35:
			torque = pulse_torque * (1.0 if _rng.randf() > 0.5 else -1.0)
		if rock:
			rock.pulse_ballistic(velocity, aim_launch_gravity_scale, torque)
		elif can:
			can.pulse_ballistic(velocity, aim_launch_gravity_scale, torque)


func _make_rock_outline(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := _rng.randi_range(7, 11)
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var bump := _rng.randf_range(0.62, 1.12)
		var jag := 1.0 + 0.08 * sin(angle * 3.0 + _rng.randf() * 2.0)
		pts.append(Vector2(cos(angle), sin(angle)) * radius * bump * jag)
	if pts.is_empty():
		# Safe fallback so we never index an empty outline.
		pts.append(Vector2(radius, 0.0))
		pts.append(Vector2(0.0, radius))
		pts.append(Vector2(-radius, 0.0))
		pts.append(Vector2(0.0, -radius))
	pts.append(pts[0])
	return pts


func _alive_rock_count() -> int:
	var count := 0
	for rock in _rocks:
		if not is_instance_valid(rock) or rock.hit:
			continue
		var mini := rock as ShopMiniRock
		if mini and not mini.is_clearable_target():
			continue
		count += 1
	return count


func _alive_target_count() -> int:
	# Oranges / cherries carry across rounds and do not gate the next wave.
	# Balloons are obstacles — they do not gate wave clear.
	var count := _alive_rock_count()
	for fruit in _fruits:
		if not is_instance_valid(fruit) or fruit.hit:
			continue
		if fruit.kind == ShopMiniFruit.FruitKind.ORANGE or fruit.kind == ShopMiniFruit.FruitKind.CHERRY:
			continue
		count += 1
	for can in _smoke_cans:
		if is_instance_valid(can) and not can.hit:
			count += 1
	return count


func _cleanup_fallen_rocks() -> void:
	if _game_over:
		return
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	var remaining: Array[RigidBody2D] = []
	for rock in _rocks:
		if not is_instance_valid(rock):
			continue
		if rock.hit:
			rock.queue_free()
			continue
		if rock.pulsed and rock.position.y > wall_y + rock.radius + 40.0 and rock.linear_velocity.y > 0.0:
			var fall_pos := rock.position
			var mini_rock := rock as ShopMiniRock
			var kind: ShopMiniRock.RockKind = mini_rock.kind if mini_rock else ShopMiniRock.RockKind.BASIC
			_play_splash(fall_pos)
			# Black / avoider falling away is fine — no strike. Chaser & basics miss = strike.
			if mini_rock == null or mini_rock.counts_as_fall_strike():
				_add_strike(true)
			rock.queue_free()
			continue
		if rock.position.y < -80.0 or rock.position.x < -80.0 or rock.position.x > _overlay.size.x + 80.0:
			rock.queue_free()
			continue
		remaining.append(rock)
	_rocks = remaining

	var remaining_fruits: Array[ShopMiniFruit] = []
	for fruit in _fruits:
		if not is_instance_valid(fruit):
			continue
		if fruit.hit:
			fruit.queue_free()
			continue
		if fruit.flying_away or fruit.hanging:
			remaining_fruits.append(fruit)
			continue
		if fruit.pulsed and fruit.kind == ShopMiniFruit.FruitKind.ORANGE:
			# Oranges hang — never count as fallen strikes.
			remaining_fruits.append(fruit)
			continue
		if fruit.pulsed and fruit.position.y > wall_y + fruit.radius + 40.0 and fruit.linear_velocity.y > 0.0:
			_play_splash(fruit.position)
			# Cherries are bonus toys — falling off is fine. Pineapples miss = strike.
			if fruit.kind != ShopMiniFruit.FruitKind.CHERRY:
				_add_strike()
			fruit.queue_free()
			continue
		if fruit.position.y < -80.0 or fruit.position.x < -80.0 or fruit.position.x > _overlay.size.x + 80.0:
			fruit.queue_free()
			continue
		remaining_fruits.append(fruit)
	_fruits = remaining_fruits

	var remaining_balloons: Array[ShopMiniBalloon] = []
	for balloon in _balloons:
		if not is_instance_valid(balloon):
			continue
		if balloon.hit:
			balloon.queue_free()
			continue
		remaining_balloons.append(balloon)
	_balloons = remaining_balloons

	var remaining_cans: Array[ShopMiniSmokeCan] = []
	for can in _smoke_cans:
		if not is_instance_valid(can):
			continue
		if can.hit:
			can.queue_free()
			continue
		# Apex flash / explode handles smoke — don't treat wall fall as the boom.
		if can.pulsed and can.position.y > wall_y + can.radius + 40.0 and can.linear_velocity.y > 0.0:
			_play_splash(can.position)
			can.queue_free()
			continue
		if can.position.y < -80.0 or can.position.x < -80.0 or can.position.x > _overlay.size.x + 80.0:
			can.queue_free()
			continue
		remaining_cans.append(can)
	_smoke_cans = remaining_cans


func _update_flashes(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for flash in _shot_flashes:
		flash["t"] = float(flash["t"]) - delta
		if float(flash["t"]) > 0.0:
			remaining.append(flash)
	_shot_flashes = remaining


func _await_while_paused() -> void:
	while _paused and is_open and not _game_over:
		await get_tree().process_frame


func _toggle_pause() -> void:
	if not is_open or _game_over or _intro_active:
		return
	if _paused:
		_set_paused(false)
	else:
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	_paused = paused
	if paused:
		_freeze_playfield_for_pause()
		_ensure_pause_label()
		_pause_label.text = "[wave][pulse]Pause"
		_pause_label.modulate.a = 1.0
		_pause_label.show()
		_reset_scope_visual()
		if _mouse_sfx and _mouse_sfx.has_method("set_active"):
			_mouse_sfx.set_active(false)
	else:
		_restore_playfield_after_pause()
		if _pause_label:
			_pause_label.modulate.a = 0.0
			_pause_label.hide()
		if is_open and not _game_over and _mouse_sfx and _mouse_sfx.has_method("set_active"):
			_mouse_sfx.set_active(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ensure_pause_label() -> void:
	if _pause_label and is_instance_valid(_pause_label):
		return
	_pause_label = RichTextLabel.new()
	_pause_label.name = "PauseLabel"
	_pause_label.bbcode_enabled = true
	_pause_label.fit_content = true
	_pause_label.scroll_active = false
	_pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.add_theme_color_override("default_color", INK)
	_pause_label.add_theme_font_size_override("normal_font_size", 56)
	_pause_label.add_theme_font_size_override("italics_font_size", 56)
	_pause_label.text = "[wave][pulse]Pause"
	_pause_label.modulate.a = 0.0
	_overlay.add_child(_pause_label)
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.offset_left = -200.0
	_pause_label.offset_right = 200.0
	_pause_label.offset_top = -40.0
	_pause_label.offset_bottom = 40.0
	_pause_label.z_index = 40


func _freeze_playfield_for_pause() -> void:
	_pre_pause_body_state.clear()
	var bodies: Array = []
	bodies.append_array(_rocks)
	bodies.append_array(_fruits)
	bodies.append_array(_smoke_cans)
	for body in bodies:
		if not is_instance_valid(body) or not (body is RigidBody2D):
			continue
		var rb := body as RigidBody2D
		var id := rb.get_instance_id()
		_pre_pause_body_state[id] = {
			"freeze": rb.freeze,
			"vel": rb.linear_velocity,
			"ang": rb.angular_velocity,
			"process_mode": rb.process_mode,
		}
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
		rb.freeze = true
		rb.process_mode = Node.PROCESS_MODE_DISABLED
	if _balloon_layer:
		_balloon_layer.process_mode = Node.PROCESS_MODE_DISABLED
	for balloon in _balloons:
		if is_instance_valid(balloon):
			balloon.process_mode = Node.PROCESS_MODE_DISABLED


func _restore_playfield_after_pause() -> void:
	var bodies: Array = []
	bodies.append_array(_rocks)
	bodies.append_array(_fruits)
	bodies.append_array(_smoke_cans)
	for body in bodies:
		if not is_instance_valid(body) or not (body is RigidBody2D):
			continue
		var rb := body as RigidBody2D
		var id := rb.get_instance_id()
		if not _pre_pause_body_state.has(id):
			rb.process_mode = Node.PROCESS_MODE_INHERIT
			continue
		var state: Dictionary = _pre_pause_body_state[id]
		rb.process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT))
		rb.freeze = bool(state.get("freeze", false))
		rb.linear_velocity = state.get("vel", Vector2.ZERO)
		rb.angular_velocity = float(state.get("ang", 0.0))
	_pre_pause_body_state.clear()
	if _balloon_layer:
		_balloon_layer.process_mode = Node.PROCESS_MODE_INHERIT
	for balloon in _balloons:
		if is_instance_valid(balloon):
			balloon.process_mode = Node.PROCESS_MODE_INHERIT


func _try_shoot() -> void:
	if _game_over or _paused:
		return
	var bullet_cost := 2 if _scope_mode == ScopeMode.EXPAND else 1
	if _bullets < bullet_cost:
		if _bullets <= 0:
			_show_out_of_ammo()
			return
		# Not enough for expanded shot — still fire if at least 1 remains? Prefer block.
		_show_out_of_ammo()
		return

	_bullets -= bullet_cost
	_play_shot_feedback()
	_play_fire_sfx()
	_add_shake(fire_shake_strength, fire_shake_time)
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	_shot_flashes.append({"pos": _crosshair, "t": 0.12})
	var multikill_count := 0
	var hit_any := false
	var balloon_blocked := false
	# Capture charged state before mode is cleared by the caller.
	var charged_shot := _scope_is_charged()

	# Balloons sit in front and block a clear shot — resolve them first.
	for i in range(_balloons.size() - 1, -1, -1):
		if i < 0 or i >= _balloons.size():
			continue
		var balloon := _balloons[i]
		if balloon == null or not is_instance_valid(balloon) or balloon.hit:
			continue
		if balloon.position.distance_to(_crosshair) > _current_target_radius + balloon.radius * 0.2:
			continue
		hit_any = true
		balloon_blocked = true
		if balloon.apply_shot():
			_balloons.remove_at(i)

	# Fruits: pineapple flyaway / orange explode+blast.
	# Pineapples never contribute to multi-shot / oranges.
	# Collect hits first — apply_shot can erase from _fruits during the stagger await.
	if not balloon_blocked:
		var hit_fruits: Array[ShopMiniFruit] = []
		for i in range(_fruits.size() - 1, -1, -1):
			if i < 0 or i >= _fruits.size():
				continue
			var fruit := _fruits[i]
			if fruit == null or not is_instance_valid(fruit) or fruit.hit or fruit.flying_away:
				continue
			if fruit.position.y > wall_y and not fruit.hanging:
				continue
			if fruit.position.distance_to(_crosshair) > _current_target_radius + fruit.radius * 0.25:
				continue
			hit_fruits.append(fruit)
		var center := Vector2(_overlay.size.x * 0.5, _overlay.size.y * 0.42)
		for fruit_i in hit_fruits.size():
			var fruit := hit_fruits[fruit_i]
			if fruit == null or not is_instance_valid(fruit) or fruit.hit or fruit.flying_away:
				continue
			hit_any = true
			if fruit.apply_shot(center):
				_play_fruit_hit_sfx(fruit)
				if fruit.kind != ShopMiniFruit.FruitKind.PINEAPPLE:
					multikill_count += 1
			if fruit_i < hit_fruits.size() - 1:
				await get_tree().create_timer(0.05, false).timeout

	for i in range(_smoke_cans.size() - 1, -1, -1):
		if balloon_blocked:
			break
		if i < 0 or i >= _smoke_cans.size():
			continue
		var can := _smoke_cans[i]
		if can == null or not is_instance_valid(can) or can.hit:
			continue
		if can.position.y > wall_y:
			continue
		if can.position.distance_to(_crosshair) > _current_target_radius + can.radius * 0.2:
			continue
		hit_any = true
		if can.apply_shot():
			_smoke_cans.remove_at(i)

	# Hit every rock under the crosshair this frame (multi-kill).
	if not balloon_blocked:
		for i in range(_rocks.size() - 1, -1, -1):
			if i < 0 or i >= _rocks.size():
				continue
			var rock := _rocks[i] as ShopMiniRock
			if rock == null or not is_instance_valid(rock) or rock.hit:
				continue
			if rock.position.y > wall_y:
				continue
			if rock.position.distance_to(_crosshair) > _current_target_radius:
				continue
			# Avoider: reticle overlap detonates with a strike (even on a shot).
			if rock.kind == ShopMiniRock.RockKind.AVOIDER:
				hit_any = true
				on_shop_avoider_finished(rock, true)
				_rocks.remove_at(i)
				continue
			# Chaser: ignore shots until fully locked.
			if rock.kind == ShopMiniRock.RockKind.CHASER and not rock._chaser_locked:
				continue
			hit_any = true
			var hit_pos := rock.position
			var kind: ShopMiniRock.RockKind = rock.kind
			var away_from_crosshair := rock.position - _crosshair
			var destroyed: bool = rock.apply_shot(away_from_crosshair, _crosshair_node.position, charged_shot)
			
			if not destroyed:
				_play_hit_sfx()
				_shot_flashes.append({"pos": hit_pos, "t": 0.18, "burst": true})
				continue
			multikill_count += 1
			_rocks.remove_at(i)
			_on_rock_destroyed(rock, hit_pos, kind)
			await get_tree().create_timer(0.1, false).timeout

	if multikill_count >= 2:
		_show_multikill(multikill_count)
	elif not hit_any:
		_on_shot_missed()


func _on_shot_missed() -> void:

	if _sfx_miss:
		_sfx_miss.play(0.91)
	if _miss_label:
		_miss_label.text = "MISS"
		_miss_label.modulate.a = 1.0
		_miss_timer = 0.45
	_shot_flashes.append({"pos": _crosshair, "t": 0.16, "burst": true})


func _ensure_out_label() -> void:
	if _out_label and is_instance_valid(_out_label):
		return
	if _crosshair_node == null:
		return
	_out_label = _crosshair_node.get_node_or_null("OutOfAmmoLabel") as RichTextLabel
	if _out_label == null:
		_out_label = RichTextLabel.new()
		_out_label.name = "OutOfAmmoLabel"
		_out_label.bbcode_enabled = true
		_out_label.fit_content = true
		_out_label.scroll_active = false
		_out_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_out_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_out_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_out_label.add_theme_font_size_override("normal_font_size", 42)
		_out_label.add_theme_color_override("default_color", _active_hud_color)
		_out_label.text = "OUT"
		_crosshair_node.add_child(_out_label)
		_out_label.set_anchors_preset(Control.PRESET_CENTER)
		_out_label.offset_left = -40.0
		_out_label.offset_right = 40.0
		_out_label.offset_top = -28.0
		_out_label.offset_bottom = 28.0
	_out_label.modulate.a = 0.0


func _show_out_of_ammo() -> void:
	_ensure_out_label()
	if _out_label == null:
		return
	if _sfx_miss:
		_sfx_miss.play(0.91)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_out_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(_out_label, "modulate:a", 0.2, 0.1)
	tween.tween_property(_out_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(_out_label, "modulate:a", 0.2, 0.1)
	tween.tween_property(_out_label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.2)
	tween.tween_property(_out_label, "modulate:a", 0.0, 0.1)


func _on_rock_destroyed(rock: RigidBody2D, hit_pos: Vector2, kind: ShopMiniRock.RockKind) -> void:
	if _sfx_hit_flicker:
		_sfx_hit_flicker.play()
	_play_destroy_sfx()
	_play_aoe(hit_pos)
	_add_shake(destroy_shake_strength, destroy_shake_time)
	_shot_flashes.append({"pos": hit_pos, "t": 0.22, "burst": true})
	if kind == ShopMiniRock.RockKind.BLACK:
		# Shooting a black rock is a hazard — money penalty + strike.
		_add_money(-black_rock_penalty)
		_add_strike()
	elif kind == ShopMiniRock.RockKind.AVOIDER:
		pass
	else:
		_add_money(money_per_destroy)
	if is_instance_valid(rock):
		rock.queue_free()


func get_aim_crosshair() -> Vector2:
	return _crosshair


func get_aim_radius() -> float:
	return _current_target_radius


## Column 1–8 / row A–C play rectangle (above the wall) for rock-chasers.
func get_chaser_play_bounds() -> Rect2:
	var x1 := _column_to_x(1)
	var x8 := _column_to_x(8)
	var y_a := _row_to_y(1)
	var y_c := _row_to_y(3)
	var min_x := minf(x1, x8)
	var max_x := maxf(x1, x8)
	var min_y := minf(y_a, y_c)
	var max_y := maxf(y_a, y_c)
	# Keep a little room above the wall so they don't splash while dodging.
	var wall_y := _overlay.size.y * WALL_Y_RATIO
	max_y = minf(max_y, wall_y - 36.0)
	return Rect2(Vector2(min_x, min_y), Vector2(maxf(max_x - min_x, 40.0), maxf(max_y - min_y, 40.0)))


## Avoider finished: crosshair contact = strike + big shake; lifetime expire = quiet pop.
func on_shop_avoider_finished(rock: ShopMiniRock, from_crosshair: bool) -> void:
	if rock == null or not is_instance_valid(rock):
		return
	var hit_pos := rock.position
	_rocks.erase(rock)
	_play_destroy_sfx()
	_play_aoe(hit_pos)
	_shot_flashes.append({"pos": hit_pos, "t": 0.22, "burst": true})
	if from_crosshair:
		_add_shake(destroy_shake_strength * 2.4, destroy_shake_time * 1.6)
		_add_vertical_strike_shake(strike_miss_shake_strength * 1.5, strike_miss_shake_time * 1.25)
		_add_strike()
	else:
		_add_shake(destroy_shake_strength * 0.7, destroy_shake_time * 0.8)
	rock.queue_free()


## Avoider blew up another rock on contact — treat as a normal destroy (money).
func on_shop_avoider_destroyed_rock(other: ShopMiniRock) -> void:
	if other == null or not is_instance_valid(other) or other.hit:
		return
	var hit_pos := other.position
	var kind := other.kind
	other.mark_destroyed()
	_rocks.erase(other)
	_on_rock_destroyed(other, hit_pos, kind)


func _on_fruit_flyaway_finished(fruit: ShopMiniFruit, destroyed: bool) -> void:
	if not is_instance_valid(fruit):
		return
	var pos := fruit.position
	var kind := fruit.kind
	_fruits.erase(fruit)
	if destroyed and not _game_over:
		_play_fruit_destroy_sfx()
		_play_fruit_aoe(pos)
		_add_shake(destroy_shake_strength, destroy_shake_time)
		if kind == ShopMiniFruit.FruitKind.PINEAPPLE:
			_add_money(pineapple_money)
		elif kind == ShopMiniFruit.FruitKind.CHERRY:
			_add_money(cherry_money)
		else:
			_add_money(orange_money)
		_shot_flashes.append({"pos": pos, "t": 0.22, "burst": true})
	fruit.queue_free()


func _on_orange_exploded(fruit: ShopMiniFruit, pos: Vector2) -> void:
	if not is_instance_valid(fruit):
		return
	_fruits.erase(fruit)
	if _game_over:
		fruit.queue_free()
		return
	_play_fruit_destroy_sfx()
	_play_fruit_aoe(pos)
	_add_shake(destroy_shake_strength, destroy_shake_time)
	_add_money(orange_money)
	_shot_flashes.append({"pos": pos, "t": 0.22, "burst": true})
	_spawn_blast_ring(pos)
	fruit.queue_free()


func _spawn_blast_ring(pos: Vector2) -> void:
	_blast_rings.append({
		"pos": pos,
		"t": orange_blast_duration,
		"max_t": orange_blast_duration,
		"max_r": orange_blast_radius,
		"hit_ids": {},
	})


func _update_blast_rings(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for entry in _blast_rings:
		entry["t"] = float(entry["t"]) - delta
		var t: float = float(entry["t"])
		var max_t: float = maxf(float(entry["max_t"]), 0.001)
		var progress := 1.0 - clampf(t / max_t, 0.0, 1.0)
		var radius := lerpf(12.0, float(entry["max_r"]), progress)
		entry["current_r"] = radius
		_blast_intercept(entry)
		if t > 0.0:
			remaining.append(entry)
	_blast_rings = remaining


## Destroy rocks / blow pineapples only as the expanding ring reaches them.
func _blast_intercept(entry: Dictionary) -> void:
	var origin: Vector2 = entry["pos"]
	var radius: float = float(entry.get("current_r", 0.0))
	var hit_ids: Dictionary = entry["hit_ids"]
	var center := Vector2(_overlay.size.x * 0.5, _overlay.size.y * 0.42)

	for i in range(_fruits.size() - 1, -1, -1):
		if i < 0 or i >= _fruits.size():
			continue
		var other := _fruits[i]
		if other == null or not is_instance_valid(other) or other.hit or other.flying_away:
			continue
		if other.kind != ShopMiniFruit.FruitKind.PINEAPPLE:
			continue
		var fid := other.get_instance_id()
		if hit_ids.has(fid):
			continue
		# Ring touches the fruit when distance - radius reaches the expanding edge.
		if other.position.distance_to(origin) - other.radius > radius:
			continue
		hit_ids[fid] = true
		if other.begin_flyaway(center):
			_play_fruit_hit_sfx(other)

	for i in range(_rocks.size() - 1, -1, -1):
		if i < 0 or i >= _rocks.size():
			continue
		var rock := _rocks[i] as ShopMiniRock
		if rock == null or not is_instance_valid(rock):
			_rocks.remove_at(i)
			continue
		if rock.hit:
			continue
		var rid := rock.get_instance_id()
		if hit_ids.has(rid):
			continue
		if rock.position.distance_to(origin) - rock.radius > radius:
			continue
		hit_ids[rid] = true
		var hit_pos := rock.position
		var kind := rock.kind
		if kind == ShopMiniRock.RockKind.AVOIDER:
			rock.mark_destroyed()
			_rocks.remove_at(i)
			_play_destroy_sfx()
			_play_aoe(hit_pos)
			continue
		if kind == ShopMiniRock.RockKind.CHASER and not rock._chaser_locked:
			continue
		rock.mark_destroyed()
		_rocks.remove_at(i)
		_on_rock_destroyed_by_blast(rock, hit_pos, kind)

	for i in range(_balloons.size() - 1, -1, -1):
		if i < 0 or i >= _balloons.size():
			continue
		var balloon := _balloons[i]
		if balloon == null or not is_instance_valid(balloon) or balloon.hit:
			continue
		var bid := balloon.get_instance_id()
		if hit_ids.has(bid):
			continue
		if balloon.position.distance_to(origin) - balloon.radius > radius:
			continue
		hit_ids[bid] = true
		_balloons.remove_at(i)
		balloon.apply_shot(false)

	for i in range(_smoke_cans.size() - 1, -1, -1):
		if i < 0 or i >= _smoke_cans.size():
			continue
		var can := _smoke_cans[i]
		if can == null or not is_instance_valid(can) or can.hit:
			continue
		var cid := can.get_instance_id()
		if hit_ids.has(cid):
			continue
		if can.position.distance_to(origin) - can.radius > radius:
			continue
		hit_ids[cid] = true
		_smoke_cans.remove_at(i)
		can.apply_shot()


func _on_rock_destroyed_by_blast(rock: RigidBody2D, hit_pos: Vector2, kind: ShopMiniRock.RockKind) -> void:
	# Same destroy FX / SFX as a direct shot — black rocks still skip strike/penalty.
	if _sfx_hit_flicker:
		_sfx_hit_flicker.play()
	_play_destroy_sfx()
	_play_aoe(hit_pos)
	_add_shake(destroy_shake_strength, destroy_shake_time)
	_shot_flashes.append({"pos": hit_pos, "t": 0.22, "burst": true})
	if kind != ShopMiniRock.RockKind.BLACK:
		_add_money(money_per_destroy)
	if is_instance_valid(rock):
		rock.queue_free()


func _on_balloon_popped(balloon: ShopMiniBalloon, pos: Vector2, counts_as_strike: bool = true) -> void:
	_balloons.erase(balloon)
	if _game_over:
		if is_instance_valid(balloon):
			balloon.queue_free()
		return
	if _sfx_balloon_pop:
		_sfx_balloon_pop.pitch_scale = _rng.randf_range(0.9, 1.15)
		_sfx_balloon_pop.play()
	_play_aoe(pos)
	_add_shake(destroy_shake_strength * 0.55, destroy_shake_time * 0.7)
	_shot_flashes.append({"pos": pos, "t": 0.2, "burst": true})
	# Obstacle balloon — direct shots strike; orange blasts do not.
	if counts_as_strike:
		_add_strike()
	if is_instance_valid(balloon):
		balloon.queue_free()


func _on_smoke_can_smoked(can: ShopMiniSmokeCan, pos: Vector2) -> void:
	_spawn_smoke_cloud(pos)


func _on_smoke_can_apex_tick(_can: ShopMiniSmokeCan) -> void:
	if _sfx_smoke_tick:
		_sfx_smoke_tick.pitch_scale = _rng.randf_range(0.92, 1.12)
		_sfx_smoke_tick.play()


func _on_smoke_can_exploded(can: ShopMiniSmokeCan, pos: Vector2) -> void:
	_smoke_cans.erase(can)
	if _game_over:
		if is_instance_valid(can):
			can.queue_free()
		return
	if _sfx_smoke_explode:
		_sfx_smoke_explode.pitch_scale = _rng.randf_range(0.9, 1.1)
		_sfx_smoke_explode.play()
	elif _sfx_explosion:
		_sfx_explosion.play()
	_play_aoe(pos)
	_add_shake(destroy_shake_strength * 0.7, destroy_shake_time * 0.85)
	_shot_flashes.append({"pos": pos, "t": 0.22, "burst": true})
	if is_instance_valid(can):
		can.queue_free()


func _on_smoke_can_destroyed(can: ShopMiniSmokeCan, pos: Vector2) -> void:
	_smoke_cans.erase(can)
	if _game_over:
		if is_instance_valid(can):
			can.queue_free()
		return
	_play_hit_sfx()
	_play_aoe(pos)
	_add_shake(destroy_shake_strength * 0.8, destroy_shake_time)
	_add_money(smoke_can_money)
	_shot_flashes.append({"pos": pos, "t": 0.2, "burst": true})
	if is_instance_valid(can):
		can.queue_free()


func _spawn_smoke_cloud(pos: Vector2) -> void:
	if _content == null:
		return
	var fx: GPUParticles2D
	if _smoke_can_fx_template and is_instance_valid(_smoke_can_fx_template):
		fx = _smoke_can_fx_template.duplicate() as GPUParticles2D
	else:
		fx = _make_fallback_smoke_particles()
	fx.name = "SmokeCloud"
	fx.emitting = false
	_content.add_child(fx)
	fx.position = _physics_root.position + pos
	fx.z_index = 30
	fx.show()
	fx.restart()
	fx.emitting = true
	_active_smoke.append({"node": fx, "t": smoke_cloud_duration})


func _make_fallback_smoke_particles() -> GPUParticles2D:
	var fx := GPUParticles2D.new()
	var tex := load("res://res/Particle_sprite_sheet/particle_sprite_smoke.webp") as Texture2D
	fx.texture = tex
	fx.amount = 36
	fx.lifetime = 2.2
	fx.one_shot = false
	fx.explosiveness = 0.15
	fx.local_coords = false
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.particles_animation = true
	canvas_mat.particles_anim_h_frames = 8
	canvas_mat.particles_anim_v_frames = 8
	canvas_mat.particles_anim_loop = false
	fx.material = canvas_mat
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 28.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = Color(0.55, 0.55, 0.58, 0.75)
	mat.anim_speed_min = 0.8
	mat.anim_speed_max = 1.2
	fx.process_material = mat
	return fx


func _update_active_smoke(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for entry in _active_smoke:
		entry["t"] = float(entry["t"]) - delta
		var node: GPUParticles2D = entry.get("node") as GPUParticles2D
		if float(entry["t"]) <= 0.0:
			if is_instance_valid(node):
				node.emitting = false
				node.queue_free()
			continue
		if is_instance_valid(node):
			remaining.append(entry)
	_active_smoke = remaining


func _clear_active_smoke() -> void:
	for entry in _active_smoke:
		var node: GPUParticles2D = entry.get("node") as GPUParticles2D
		if is_instance_valid(node):
			node.queue_free()
	_active_smoke.clear()
	if _smoke_can_fx_template:
		_smoke_can_fx_template.emitting = false
		_smoke_can_fx_template.hide()


func _play_fruit_hit_sfx(fruit: ShopMiniFruit) -> void:
	if _sfx_pineapple_hit:
		_sfx_pineapple_hit.pitch_scale = _rng.randf_range(0.9, 1.15)
		_sfx_pineapple_hit.play()
	if _sfx_pineapple_explode and fruit.kind == ShopMiniFruit.FruitKind.PINEAPPLE:
		_sfx_pineapple_explode.play()
	_play_hit_sfx()


func _play_fruit_destroy_sfx() -> void:
	if _sfx_pineapple_destroyed:
		_sfx_pineapple_destroyed.play()
	if _sfx_explosion:
		_sfx_explosion.play()

func _show_multikill(count: int) -> void:
	var text := "DOUBLE SHOT"
	if count == 3:
		text = "TRIPLE SHOT"
	elif count == 4:
		text = "QUAD SHOT"
	elif count > 4:
		text = "%dX SHOT" % count
	_multikill_label.text = "[wave]%s" % text
	_multikill_label.modulate.a = 1.0
	_multikill_timer = 1.1
	if _sfx_multishot:
		_sfx_multishot.play()
	# Oranges spawn from multi-shot only (double → 1, triple → 2, …).
	_spawn_bonus_fruit_from_multikill(count, _crosshair.x)


func _add_money(amount: float) -> void:
	var before := _money
	_money = maxf(0.0, _money + amount)
	var delta := _money - before
	_session_money = maxf(0.0, _session_money + delta)
	if delta > 0.0:
		gl_PlayerState.add_cents_total_earned(delta)
	_refresh_hud()


func _add_strike(from_rock_miss: bool = false) -> void:
	if _game_over:
		return
	_strikes = mini(_strikes + 1, MAX_STRIKES)
	_refresh_hud()
	if from_rock_miss:
		_add_vertical_strike_shake(strike_miss_shake_strength, strike_miss_shake_time)
	if _strikes >= MAX_STRIKES:
		_trigger_game_over()


func _add_vertical_strike_shake(strength: float, time: float) -> void:
	_strike_shake_strength = maxf(_strike_shake_strength, strength)
	_strike_shake_trauma = maxf(_strike_shake_trauma, time)


func _ensure_game_over_lifetime_label() -> void:
	if _game_over_lifetime and is_instance_valid(_game_over_lifetime):
		return
	_game_over_lifetime = RichTextLabel.new()
	_game_over_lifetime.name = "LifetimeEarned"
	_game_over_lifetime.bbcode_enabled = true
	_game_over_lifetime.fit_content = true
	_game_over_lifetime.scroll_active = false
	_game_over_lifetime.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_lifetime.add_theme_color_override("default_color", Color(0.0824, 0.0941, 0.1098, 1))
	_game_over_lifetime.add_theme_font_size_override("normal_font_size", 28)
	_game_over_panel.add_child(_game_over_lifetime)
	_game_over_lifetime.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_lifetime.offset_left = -160.0
	_game_over_lifetime.offset_right = 160.0
	_game_over_lifetime.offset_top = 28.0
	_game_over_lifetime.offset_bottom = 68.0


func _ensure_session_winnings_label() -> void:
	if _session_winnings_label and is_instance_valid(_session_winnings_label):
		return
	_session_winnings_label = RichTextLabel.new()
	_session_winnings_label.name = "SessionWinningsLabel"
	_session_winnings_label.bbcode_enabled = true
	_session_winnings_label.fit_content = true
	_session_winnings_label.scroll_active = false
	_session_winnings_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_session_winnings_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_session_winnings_label.add_theme_font_size_override("normal_font_size", 36)
	_overlay.add_child(_session_winnings_label)
	_session_winnings_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_session_winnings_label.offset_left = 12.0
	_session_winnings_label.offset_top = 8.0
	_session_winnings_label.offset_right = 280.0
	_session_winnings_label.offset_bottom = 48.0


func _trigger_game_over() -> void:
	if _paused:
		_set_paused(false)
	_game_over = true
	_pulsing = false
	_clear_rocks(true)
	_ensure_game_over_lifetime_label()
	_game_over_money.text = "[center]You earned\n[color=#c70102]$%.2f[/color]" % _money
	var lifetime = gl_PlayerState.get_cents_total_earned()
	_game_over_lifetime.text = "[center]All-time\n[color=#c70102]$%.2f[/color]" % lifetime
	_game_over_lifetime.show()
	# Make room for the lifetime line.
	_game_over_panel.offset_top = -150.0
	_game_over_panel.offset_bottom = 150.0
	_game_over_money.offset_top = -55.0
	_game_over_money.offset_bottom = 5.0
	_game_over_lifetime.offset_top = 10.0
	_game_over_lifetime.offset_bottom = 58.0
	if _game_over_panel.get_node_or_null("HBoxContainer") is Control:
		var buttons := _game_over_panel.get_node("HBoxContainer") as Control
		buttons.offset_top = 75.0
		buttons.offset_bottom = 127.0
	_game_over_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(false)
	UiFocus.wire_vertical([_retry_button, _close_button])
	UiFocus.grab_in(_game_over_panel, _retry_button)


func _refresh_hud() -> void:
	if _money_label:
		_money_label.text = "[right]$%.2f" % _money
	_ensure_session_winnings_label()
	if _session_winnings_label:
		_session_winnings_label.text = "Total $%.2f" % _session_money
		_session_winnings_label.show()
	if _strike_label:
		var marks := ""
		for i in MAX_STRIKES:
			marks += "X" if i < _strikes else "·"
			if i < MAX_STRIKES - 1:
				marks += " "
		_strike_label.text = "[center]%s" % marks


func _play_fire_sfx() -> void:
	if _sfx_shoot == null:
		return
	_sfx_shoot.pitch_scale = _rng.randf_range(0.95, 1.08)
	_sfx_shoot.play()


func _play_hit_sfx() -> void:
	if _sfx_take_damage == null:
		return
	_sfx_take_damage.volume_db = _rng.randf_range(-25.0, -20.0)
	_sfx_take_damage.pitch_scale = _rng.randf_range(0.9, 1.2)
	_sfx_take_damage.play(0.01)


func _play_destroy_sfx() -> void:
	# Non-blocking — never await here (avoids hitching when destroying).
	if _sfx_take_damage:
		_sfx_take_damage.volume_db = _rng.randf_range(-25.0, -20.0)
		_sfx_take_damage.pitch_scale = _rng.randf_range(0.9, 1.2)
		_sfx_take_damage.play(0.02)
	if _sfx_hit:
		_sfx_hit.play()
	if _sfx_hit_2:
		_sfx_hit_2.play()
	if _sfx_explosion:
		_sfx_explosion.play()
	if _sfx_hit_4:
		_sfx_hit_4.play()
	if _sfx_hit_3:
		get_tree().create_timer(0.1, false).timeout.connect(func() -> void: if is_instance_valid(_sfx_hit_3): _sfx_hit_3.play(), CONNECT_ONE_SHOT)


func _play_splash(local_pos: Vector2) -> void:
	var splash := _sfx_splash_01
	if _rng.randf() > 0.5 and _sfx_splash_02:
		splash = _sfx_splash_02
	if splash:
		splash.pitch_scale = _rng.randf_range(0.9, 1.0)
		splash.play()
	if _splash_aoe:
		_splash_aoe.position = _physics_root.position + Vector2(local_pos.x, _overlay.size.y * WALL_Y_RATIO)
		if _splash_aoe.has_method("play_at"):
			_splash_aoe.play_at(_splash_aoe.global_position)


func _play_aoe(local_pos: Vector2) -> void:
	if _aoe == null:
		return
	# Rock positions are PhysicsRoot-local; AOE is a Content sibling.
	_aoe.position = _physics_root.position + local_pos
	if _aoe.has_method("play_at"):
		_aoe.play_at(_aoe.global_position)


func _play_fruit_aoe(local_pos: Vector2) -> void:
	var aoe := _fruit_aoe if _fruit_aoe else _aoe
	if aoe == null:
		return
	aoe.position = _physics_root.position + local_pos
	if aoe.has_method("play_at"):
		aoe.play_at(aoe.global_position)


func _ensure_pillars() -> void:
	if _physics_root == null:
		return
	if _pillar_left == null or not is_instance_valid(_pillar_left):
		_pillar_left = _make_pillar_body("PillarLeft", false)
	if _pillar_right == null or not is_instance_valid(_pillar_right):
		_pillar_right = _make_pillar_body("PillarRight", true)
	_sync_pillars()


func _pillar_layout_dirty() -> void:
	if not is_node_ready():
		return
	if _pillar_left == null or _pillar_right == null:
		return
	_sync_pillars()


func _make_pillar_body(p_name: String, flip_h: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = p_name
	body.set_meta(PILLAR_META, true)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	shape_node.shape = rect
	body.add_child(shape_node)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = true
	sprite.flip_h = flip_h
	if pillar_texture == null:
		pillar_texture = load("res://res/ShootForCents/Pillar_single.png") as Texture2D
	sprite.texture = pillar_texture
	body.add_child(sprite)
	if rock_physics_material:
		body.physics_material_override = rock_physics_material
	_physics_root.add_child(body)
	return body


func _sync_pillars() -> void:
	if _overlay == null or _physics_root == null:
		return
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	if _pillar_left == null or _pillar_right == null:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var ratios := _current_pillar_ratios()
	var pillar_w := maxf(area.x * ratios.x, 8.0)
	var inset := area.x * ratios.y
	var top := area.y * 0.18
	var height := maxf(wall_y - top, 8.0)
	_set_pillar_rect(_pillar_left, inset, top, pillar_w, height)
	_set_pillar_rect(_pillar_right, area.x - inset - pillar_w, top, pillar_w, height)


func _set_pillar_rect(body: StaticBody2D, x: float, y: float, w: float, h: float) -> void:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect

	var sprite := body.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture == null and pillar_texture != null:
		sprite.texture = pillar_texture

	var slot_cx := x + w * 0.5
	var area_h := _overlay.size.y if _overlay else h
	var y_nudge := area_h * pillar_visual_y_offset_ratio + pillar_visual_y_offset_px
	var slot_cy := y + h * 0.5 + y_nudge

	# No texture: keep old stretched collision box so gameplay still works.
	if sprite == null or sprite.texture == null:
		if sprite:
			sprite.visible = false
		rect.size = Vector2(w, h)
		shape_node.position = Vector2.ZERO
		body.position = Vector2(slot_cx, slot_cy)
		return

	sprite.visible = true
	var tex_size := sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	# Uniform scale from slot height — preserves pillar proportions (no squish).
	var fit_scale := (h * pillar_visual_height_scale) / tex_size.y
	sprite.scale = Vector2(fit_scale, fit_scale)

	var drawn_w := tex_size.x * fit_scale
	var drawn_h := tex_size.y * fit_scale
	var col_w := maxf(drawn_w * pillar_collision_width_ratio, 4.0)
	var col_h := maxf(drawn_h * pillar_collision_height_ratio, 4.0)
	rect.size = Vector2(col_w, col_h)

	var col_x := drawn_w * pillar_collision_x_offset_ratio
	if sprite.flip_h:
		col_x = -col_x
	var col_y := drawn_h * pillar_collision_y_offset_ratio

	# Body sits on the collision center; sprite is offset so the art stays where intended.
	var sprite_center := Vector2(slot_cx, slot_cy)
	var col_offset := Vector2(col_x, col_y)
	body.position = sprite_center + col_offset
	shape_node.position = Vector2.ZERO
	sprite.position = -col_offset


func _ensure_wind_particles() -> void:
	if _content == null:
		return
	_wind_particles = _content.get_node_or_null("WindParticles") as GPUParticles2D
	if _wind_particles == null:
		_wind_particles = GPUParticles2D.new()
		_wind_particles.name = "WindParticles"
		_wind_particles.z_index = 1
		_content.add_child(_wind_particles)
		# Sit between scenery and rocks so wind doesn't cover the HUD/crosshair.
		if _wave_layer:
			_content.move_child(_wind_particles, _wave_layer.get_index() + 1)
	_update_wind_particles()


func _update_wind_particles() -> void:
	if _wind_particles == null:
		return
	var area := _overlay.size if _overlay else Vector2(800, 600)
	var mat := _wind_particles.process_material as ParticleProcessMaterial
	if mat == null:
		mat = ParticleProcessMaterial.new()
		_wind_particles.process_material = mat
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area.x * 0.55, area.y * 0.35, 1.0)
	mat.direction = Vector3(1, 0.05, 0)
	mat.spread = 12.0
	mat.initial_velocity_min = wind_speed * 0.7
	mat.initial_velocity_max = wind_speed
	mat.gravity = Vector3.ZERO
	mat.scale_min = wind_thickness * 0.85
	mat.scale_max = wind_thickness
	mat.color = wind_color
	# Hard pop in / pop out — no smooth fade curves.
	var pop_scale := Curve.new()
	pop_scale.add_point(Vector2(0.0, 0.0))
	pop_scale.add_point(Vector2(0.02, 1.0))
	pop_scale.add_point(Vector2(0.85, 1.0))
	pop_scale.add_point(Vector2(0.87, 0.0))
	pop_scale.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = pop_scale
	mat.scale_curve = scale_tex
	var pop_alpha := Curve.new()
	pop_alpha.add_point(Vector2(0.0, 0.0))
	pop_alpha.add_point(Vector2(0.02, 1.0))
	pop_alpha.add_point(Vector2(0.85, 1.0))
	pop_alpha.add_point(Vector2(0.87, 0.0))
	pop_alpha.add_point(Vector2(1.0, 0.0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = pop_alpha
	mat.alpha_curve = alpha_tex
	_wind_particles.amount = maxi(wind_amount, 1)
	_wind_particles.lifetime = 2.8
	_wind_particles.preprocess = 1.2
	_wind_particles.trail_enabled = true
	_wind_particles.trail_lifetime = wind_trail_length
	_wind_particles.position = Vector2(area.x * 0.5, area.y * 0.35) + _physics_root.position
	_wind_particles.emitting = wind_enabled and is_open and not _game_over
	_wind_particles.visible = wind_enabled


func _ensure_ring_pool() -> void:
	_shot_rings.clear()
	_ring_pool.clear()


func _play_shot_feedback() -> void:
	_flash_crosshair_color()
	_spawn_shot_ring()


func _flash_crosshair_color() -> void:
	if _crosshair_node == null:
		return
	if _crosshair_flash_tween:
		_crosshair_flash_tween.kill()
	_crosshair_node.modulate = shot_crosshair_flash_color
	_crosshair_flash_tween = create_tween()
	_crosshair_flash_tween.tween_property(_crosshair_node, "modulate", Color.WHITE, shot_crosshair_flash_time)


func _spawn_shot_ring() -> void:
	while _shot_rings.size() >= RING_POOL_SIZE:
		_shot_rings.pop_front()
	_shot_rings.append({
		"pos": _crosshair,
		"t": shot_ring_duration,
		"max_t": shot_ring_duration,
	})


func _update_shot_rings(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for entry in _shot_rings:
		entry["t"] = float(entry["t"]) - delta
		if float(entry["t"]) > 0.0:
			remaining.append(entry)
	_shot_rings = remaining


func _add_shake(strength: float, time: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_trauma = maxf(_shake_trauma, time)


func _shake_offset() -> Vector2:
	var off := Vector2.ZERO
	if _shake_trauma > 0.0 and _shake_strength > 0.0:
		# Soft sine shake — applied only to visual layers, never PhysicsRoot.
		var falloff := clampf(_shake_trauma / maxf(destroy_shake_time, 0.05), 0.0, 1.0)
		falloff = falloff * falloff
		var mag := _shake_strength * falloff
		off += Vector2(sin(_shake_time * 58.0), cos(_shake_time * 43.0)) * mag
	if _strike_shake_trauma > 0.0 and _strike_shake_strength > 0.0:
		var s_fall := clampf(_strike_shake_trauma / maxf(strike_miss_shake_time, 0.05), 0.0, 1.0)
		s_fall = s_fall * s_fall
		# Pure vertical bob — no horizontal drift.
		off.y += sin(_shake_time * strike_miss_shake_freq) * (_strike_shake_strength * s_fall)
	return off


func _capture_visual_base_positions() -> void:
	# Layout insets match the scene (WaveLayer / Overlay offset 8).
	if _physics_root:
		_wave_layer_base_pos = _physics_root.position
		_overlay_base_pos = _physics_root.position
	else:
		_wave_layer_base_pos = Vector2(8, 8)
		_overlay_base_pos = Vector2(8, 8)


func _apply_shake_to_visuals() -> void:
	var off := _shake_offset()
	# Never move Content / PhysicsRoot — that hitch + boosted rock launches.
	if _wave_layer:
		_wave_layer.offset_left = _wave_layer_base_pos.x + off.x
		_wave_layer.offset_top = _wave_layer_base_pos.y + off.y
		_wave_layer.offset_right = -_wave_layer_base_pos.x + off.x
		_wave_layer.offset_bottom = -_wave_layer_base_pos.y + off.y
	if _overlay:
		_overlay.offset_left = _overlay_base_pos.x + off.x
		_overlay.offset_top = _overlay_base_pos.y + off.y
		_overlay.offset_right = -_overlay_base_pos.x + off.x
		_overlay.offset_bottom = -_overlay_base_pos.y + off.y
	if _balloon_layer and is_instance_valid(_balloon_layer) and _physics_root:
		_balloon_layer.position = _physics_root.position + off


func _update_shake(delta: float) -> void:
	_shake_time += delta
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - delta)
		if _shake_trauma <= 0.0:
			_shake_strength = 0.0
	if _strike_shake_trauma > 0.0:
		_strike_shake_trauma = maxf(0.0, _strike_shake_trauma - delta)
		if _strike_shake_trauma <= 0.0:
			_strike_shake_strength = 0.0
	_apply_shake_to_visuals()


func _draw_waves_layer() -> void:
	var area := _wave_layer.size
	if area.x < 4.0 or area.y < 4.0:
		return
	_draw_distant_scenery(area)


func _init_star_seeds() -> void:
	_star_seeds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 48:
		_star_seeds.append(Vector2(rng.randf(), rng.randf()))


func _update_sky_transition(delta: float) -> void:
	if _sky_blend_t >= 1.0:
		return
	_sky_blend_t = minf(1.0, _sky_blend_t + delta / maxf(sky_transition_duration, 0.05))
	_sync_pillars()


func _sky_visual_progress() -> float:
	return lerpf(_sky_from, _sky_to, _sky_blend_t)


func _target_sky_progress_for_wave(wave: int) -> float:
	if not day_night_cycle_enabled:
		return 0.0
	var thresholds := environment_change_waves.duplicate()
	thresholds.sort()
	var phase := 0
	for threshold in thresholds:
		if wave >= int(threshold):
			phase += 1
		else:
			break
	return float(mini(phase, 2))


func _begin_sky_transition_for_wave(wave: int) -> void:
	if not day_night_cycle_enabled:
		_sky_from = 0.0
		_sky_to = 0.0
		_sky_blend_t = 1.0
		_sync_pillars()
		_apply_colour_scheme_for_progress(0.0)
		return
	var target := _target_sky_progress_for_wave(wave)
	var current := _sky_visual_progress()
	if is_equal_approx(current, target) and _sky_blend_t >= 1.0:
		_apply_colour_scheme_for_progress(target)
		return
	_sky_from = current
	_sky_to = target
	_sky_blend_t = 0.0
	_apply_colour_scheme_for_progress(target)


func _begin_sky_transition_for_range(range_id: String, instant: bool = false) -> void:
	if not day_night_cycle_enabled:
		_sky_from = 0.0
		_sky_to = 0.0
		_sky_blend_t = 1.0
		_sync_pillars()
		_apply_colour_scheme_for_progress(0.0)
		return
	var target := _sky_progress_for_range(range_id)
	if instant:
		_sky_from = target
		_sky_to = target
		_sky_blend_t = 1.0
		_sync_pillars()
		_apply_colour_scheme_for_progress(target)
		return
	var current := _sky_visual_progress()
	if is_equal_approx(current, target) and _sky_blend_t >= 1.0:
		_apply_colour_scheme_for_progress(target)
		return
	_sky_from = current
	_sky_to = target
	_sky_blend_t = 0.0
	_apply_colour_scheme_for_progress(target)


func _colour_scheme_for_progress(progress: float) -> Dictionary:
	if progress < 0.5:
		return {
			"crosshair": day_crosshair_color,
			"money": day_money_color,
			"strike": day_strike_color,
		}
	if progress < 1.5:
		return {
			"crosshair": night_crosshair_color,
			"money": night_money_color,
			"strike": night_strike_color,
		}
	return {
		"crosshair": blue_day_crosshair_color,
		"money": blue_day_money_color,
		"strike": blue_day_strike_color,
	}


func _apply_colour_scheme_for_progress(progress: float) -> void:
	var scheme := _colour_scheme_for_progress(progress)
	_active_hud_color = scheme.crosshair
	if _money_label:
		_money_label.add_theme_color_override("default_color", scheme.money)
	if _session_winnings_label:
		_session_winnings_label.add_theme_color_override("default_color", scheme.money)
	if _strike_label:
		_strike_label.add_theme_color_override("default_color", scheme.strike)
	if _crosshair_node:
		_crosshair_node.modulate = Color(scheme.crosshair.r, scheme.crosshair.g, scheme.crosshair.b, _crosshair_node.modulate.a)
	if _out_label:
		_out_label.add_theme_color_override("default_color", scheme.crosshair)
	if _crosshair_texture:
		_crosshair_texture.modulate = Color(scheme.crosshair.r, scheme.crosshair.g, scheme.crosshair.b, _crosshair_texture.modulate.a)


## Returns Vector2(width_ratio, inset_ratio) for a sky progress value (0/1/2).
func _pillar_ratios_at_progress(progress: float) -> Vector2:
	if progress < 0.5:
		return Vector2(pillar_width_ratio, pillar_inset_ratio)
	if progress < 1.5:
		return Vector2(night_pillar_width_ratio, night_pillar_inset_ratio)
	return Vector2(blue_day_pillar_width_ratio, blue_day_pillar_inset_ratio)


func _current_pillar_ratios() -> Vector2:
	var from_r := _pillar_ratios_at_progress(_sky_from)
	var to_r := _pillar_ratios_at_progress(_sky_to)
	return from_r.lerp(to_r, _sky_blend_t)


func _sky_color_for_progress(progress: float) -> Color:
	if progress <= 1.0:
		return day_sky_color.lerp(night_sky_color, progress)
	return night_sky_color.lerp(blue_day_sky_color, progress - 1.0)


func _night_amount(progress: float) -> float:
	if progress <= 1.0:
		return progress
	return maxf(0.0, 1.0 - (progress - 1.0))


func _draw_distant_scenery(area: Vector2) -> void:
	var wall_y := area.y * WALL_Y_RATIO
	var progress := _sky_visual_progress()
	var sky := _sky_color_for_progress(progress)
	_wave_layer.draw_rect(Rect2(0.0, 0.0, area.x, wall_y), sky, true)
	var night := _night_amount(progress)
	if night > 0.05:
		_draw_stars(area, wall_y, night)
		_draw_moon(area, wall_y, night)
	var cloud_c := cloud_color
	var far_c := mountain_far_color
	var near_c := mountain_near_color
	if day_night_cycle_enabled and progress > 0.0:
		if progress <= 1.0:
			cloud_c = cloud_color.lerp(Color(0.55, 0.62, 0.85, 0.22), progress)
			far_c = mountain_far_color.lerp(Color(0.12, 0.16, 0.28, 0.55), progress)
			near_c = mountain_near_color.lerp(Color(0.08, 0.11, 0.2, 0.7), progress)
		else:
			var t := progress - 1.0
			cloud_c = Color(0.55, 0.62, 0.85, 0.22).lerp(Color(1.0, 1.0, 1.0, 0.35), t)
			far_c = Color(0.12, 0.16, 0.28, 0.55).lerp(Color(0.35, 0.55, 0.42, 0.4), t)
			near_c = Color(0.08, 0.11, 0.2, 0.7).lerp(Color(0.25, 0.48, 0.32, 0.55), t)
	_draw_clouds_colored(area, wall_y, cloud_c)
	_draw_mountains_colored(area, wall_y, far_c, near_c)


func _draw_stars(area: Vector2, wall_y: float, night: float) -> void:
	if _star_seeds.is_empty():
		_init_star_seeds()
	for i in _star_seeds.size():
		var s := _star_seeds[i]
		var pos := Vector2(s.x * area.x, s.y * wall_y * 0.85)
		var twinkle := 0.55 + 0.45 * sin(_wave_phase * 1.7 + float(i) * 0.9)
		var c := star_color
		c.a *= night * twinkle
		var r := 0.8 + float(i % 3) * 0.45
		_wave_layer.draw_circle(pos, r, c)


func _draw_moon(area: Vector2, wall_y: float, night: float) -> void:
	var pos := Vector2(area.x * moon_x_ratio, wall_y * moon_y_ratio)
	var radius := moon_base_radius + moon_night_radius_boost * night
	var glow := moon_color
	glow.a *= night * 0.25
	_wave_layer.draw_circle(pos, radius * 1.8, glow)
	var body := moon_color
	body.a *= night
	_wave_layer.draw_circle(pos, radius, body)
	# Soft crescent cut (sky-coloured bite so pillars don't hide a solid disc).
	var sky := _sky_color_for_progress(_sky_visual_progress())
	sky.a = 1.0
	_wave_layer.draw_circle(pos + Vector2(radius * 0.45, -radius * 0.1), radius * 0.88, sky)


func _draw_clouds_colored(area: Vector2, wall_y: float, color: Color) -> void:
	var clouds := [
		{"c": Vector2(area.x * 0.18, wall_y * 0.22), "rx": 52.0, "ry": 16.0},
		{"c": Vector2(area.x * 0.42, wall_y * 0.14), "rx": 70.0, "ry": 18.0},
		{"c": Vector2(area.x * 0.68, wall_y * 0.20), "rx": 48.0, "ry": 14.0},
		{"c": Vector2(area.x * 0.86, wall_y * 0.12), "rx": 58.0, "ry": 15.0},
		{"c": Vector2(area.x * 0.30, wall_y * 0.32), "rx": 40.0, "ry": 12.0},
		{"c": Vector2(area.x * 1.12, wall_y * 0.18), "rx": 60.0, "ry": 15.0},
		{"c": Vector2(area.x * -0.12, wall_y * 0.26), "rx": 44.0, "ry": 13.0},
	]
	var _wrap :float= area.x + 160.0
	for cloud in clouds:
		var c: Vector2 = cloud["c"]
		var rx: float = cloud["rx"]
		var ry: float = cloud["ry"]
		c.x = fposmod(c.x + _cloud_pan + sin(_wave_phase * 0.12 + rx * 0.01) * 4.0, _wrap) - 80.0
		_draw_soft_ellipse(c, rx, ry, color)
		_draw_soft_ellipse(c + Vector2(rx * 0.35, ry * 0.15), rx * 0.55, ry * 0.75, color)
		_draw_soft_ellipse(c + Vector2(-rx * 0.4, ry * 0.1), rx * 0.45, ry * 0.7, color)


func _draw_mountains_colored(area: Vector2, wall_y: float, far_color: Color, near_color: Color) -> void:
	var far := PackedVector2Array([
		Vector2(0.0, wall_y),
		Vector2(0.0, wall_y * 0.72),
		Vector2(area.x * 0.12, wall_y * 0.48),
		Vector2(area.x * 0.28, wall_y * 0.62),
		Vector2(area.x * 0.45, wall_y * 0.38),
		Vector2(area.x * 0.62, wall_y * 0.58),
		Vector2(area.x * 0.78, wall_y * 0.42),
		Vector2(area.x * 0.95, wall_y * 0.55),
		Vector2(area.x, wall_y * 0.68),
		Vector2(area.x, wall_y),
	])
	_wave_layer.draw_colored_polygon(far, far_color)
	var near := PackedVector2Array([
		Vector2(0.0, wall_y),
		Vector2(0.0, wall_y * 0.85),
		Vector2(area.x * 0.08, wall_y * 0.70),
		Vector2(area.x * 0.22, wall_y * 0.52),
		Vector2(area.x * 0.36, wall_y * 0.74),
		Vector2(area.x * 0.55, wall_y * 0.46),
		Vector2(area.x * 0.70, wall_y * 0.68),
		Vector2(area.x * 0.88, wall_y * 0.50),
		Vector2(area.x, wall_y * 0.78),
		Vector2(area.x, wall_y),
	])
	_wave_layer.draw_colored_polygon(near, near_color)


func _draw_soft_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	if pts.size() >= 3:
		_wave_layer.draw_colored_polygon(pts, color)


func _draw_overlay() -> void:
	var area := _overlay.size
	if area.x < 4.0 or area.y < 4.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	_overlay.draw_rect(Rect2(0.0, wall_y, area.x, area.y - wall_y + 2.0), CREAM, true)
	_draw_pillars(area, wall_y)
	_draw_wall(area, wall_y)
	if display_grid:
		_draw_aim_grid(area)
	_draw_flashes()
	_draw_active_shot_rings()
	_draw_blast_rings()
	_draw_bullet_ticks()
	# Fallback crosshair if no custom texture assigned.
	if _crosshair_texture == null or _crosshair_texture.texture == null:
		_draw_crosshair(_crosshair)
	# Subtle aim circle matching current shrink radius.
	var aim_c := _active_hud_color
	_overlay.draw_arc(_crosshair, _current_target_radius, 0.0, TAU, 48, Color(aim_c.r, aim_c.g, aim_c.b, 0.25), 5.25, true)


func _draw_aim_grid(area: Vector2) -> void:
	var row_letters := ["A", "B", "C"]
	var row_ys := [_row_to_y(1), _row_to_y(2), _row_to_y(3)]
	for col in range(1, GRID_COLUMN_COUNT + 1):
		var x := _column_to_x(col)
		_overlay.draw_line(Vector2(x, 0.0), Vector2(x, area.y * WALL_Y_RATIO), GRID_LINE_COLOR, 1.0, true)
		for row_i in 3:
			var y: float = row_ys[row_i]
			var cell := Vector2(x, y)
			_overlay.draw_circle(cell, 5.0, GRID_LABEL_COLOR)
			_overlay.draw_arc(cell, 10.0, 0.0, TAU, 20, GRID_LINE_COLOR, 1.25, true)
			var label := "%s%d" % [row_letters[row_i], col]
			_overlay.draw_string(
				ThemeDB.fallback_font,
				cell + Vector2(8.0, -6.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14,
				GRID_LABEL_COLOR
			)
	for y in row_ys:
		_overlay.draw_line(Vector2(0.0, y), Vector2(area.x, y), GRID_LINE_COLOR, 1.0, true)


func _draw_bullet_ticks() -> void:
	var max_b := maxi(bullets_per_wave, 1)
	var remaining := clampi(_bullets, 0, max_b)
	# Ticks sit just outside the current aim circle, like hour marks.
	var ring_r := _current_target_radius + bullet_tick_gap
	# Index 0 = 1 o'clock. First spent bullet hides the 1 o'clock tick.
	var spent := max_b - remaining
	for i in max_b:
		if i < spent:
			continue
		# 12 o'clock = -PI/2; each step is TAU/max_b clockwise.
		var hour := i + 1 # 1..12
		var angle := -PI * 0.5 + (TAU * float(hour) / float(max_b))
		var dir := Vector2(cos(angle), sin(angle))
		var inner := _crosshair + dir * ring_r
		var outer := _crosshair + dir * (ring_r + bullet_tick_length)
		_overlay.draw_line(inner, outer, bullet_tick_color, bullet_tick_width, true)


func _draw_active_shot_rings() -> void:
	for entry in _shot_rings:
		var t: float = float(entry["t"])
		var max_t: float = maxf(float(entry["max_t"]), 0.001)
		var progress := 1.0 - (t / max_t)
		var radius := lerpf(8.0, shot_ring_max_radius, progress)
		var color := shot_ring_color
		color.a *= (1.0 - progress)
		var pos: Vector2 = entry["pos"]
		_overlay.draw_arc(pos, radius, 0.0, TAU, 36, color, 2.0, true)


func _draw_blast_rings() -> void:
	for entry in _blast_rings:
		var t: float = float(entry["t"])
		var max_t: float = maxf(float(entry["max_t"]), 0.001)
		var progress := 1.0 - clampf(t / max_t, 0.0, 1.0)
		var radius: float = float(entry.get("current_r", lerpf(12.0, float(entry["max_r"]), progress)))
		var color := Color(1.0, 0.55, 0.08, 0.85 * (1.0 - progress))
		var pos: Vector2 = entry["pos"]
		_overlay.draw_arc(pos, radius, 0.0, TAU, 40, color, 3.0, true)
		_overlay.draw_arc(pos, radius * 0.72, 0.0, TAU, 28, Color(1.0, 0.85, 0.2, color.a * 0.55), 1.5, true)


func _draw_pillars(area: Vector2, wall_y: float) -> void:
	# Visuals come from Sprite2D on the physics pillars (Pillar_single.png).
	# Keep the old line art only as a fallback when the texture is missing.
	if pillar_texture != null:
		return
	var ratios := _current_pillar_ratios()
	var pillar_w := area.x * ratios.x
	var inset := area.x * ratios.y
	var top := area.y * 0.18
	var height := wall_y - top
	_draw_pillar_body(inset, top, pillar_w, height)
	_draw_pillar_body(area.x - inset - pillar_w, top, pillar_w, height)


func _draw_pillar_body(x: float, y: float, w: float, h: float) -> void:
	_overlay.draw_rect(Rect2(x, y, w, h), CREAM, true)
	var pts := PackedVector2Array([
		Vector2(x, y + h),
		Vector2(x, y),
		Vector2(x + w, y),
		Vector2(x + w, y + h),
		Vector2(x, y + h),
	])
	_overlay.draw_polyline(pts, INK, 2.0, true)
	var mid_x := x + w * 0.55
	_overlay.draw_line(Vector2(mid_x, y), Vector2(mid_x, y + h), INK, 1.25, true)
	_overlay.draw_line(Vector2(x - 3.0, y), Vector2(x + w + 3.0, y), INK, 2.0, true)


func _draw_wall(area: Vector2, wall_y: float) -> void:
	_overlay.draw_line(Vector2(0.0, wall_y), Vector2(area.x, wall_y), INK, 2.5, true)


func _draw_flashes() -> void:
	
	for flash in _shot_flashes:
		var pos: Vector2 = flash["pos"]
		var t := float(flash["t"])
		var alpha := clampf(t / 0.12, 0.0, 1.0)
		var color := Color(_active_hud_color.r, _active_hud_color.g, _active_hud_color.b, alpha)
		if flash.get("burst", false):
			var r := (0.22 - t) * 90.0
			_overlay.draw_arc(pos, maxf(r, CROSSHAIR_RADIUS - 5.0), 0.0, TAU, 18, color, 5.5, true)
		#else:
			#_overlay.draw_circle(pos, 3.0, color)


func _draw_crosshair(pos: Vector2) -> void:
	#return
	var r := CROSSHAIR_RADIUS
	var tick_colour := Color("ffffff30")
	#_overlay.draw_arc(pos, r, 0.0, TAU, 48, CROSSHAIR_RED, 2.0, true)
	#_overlay.draw_circle(pos, 12.2, Color("ff000028"))
	var tick := 300.0
	_overlay.draw_line(pos + Vector2(0, -r - tick), pos + Vector2(0, -r - 70), tick_colour, 2.0, true)
	_overlay.draw_line(pos + Vector2(0, r + 70), pos + Vector2(0, r + tick), tick_colour, 2.0, true)
	_overlay.draw_line(pos + Vector2(-r - tick, 0), pos + Vector2(-r - 70, 0), tick_colour, 2.0, true)
	_overlay.draw_line(pos + Vector2(r + 70, 0), pos + Vector2(r + tick, 0), tick_colour, 2.0, true)


func crosshair_blink() -> void:
	_play_shot_feedback()
