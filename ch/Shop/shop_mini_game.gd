extends Control
## Minimalistic 2D arcade overlay that runs inside the shop panel.
## Toggle with Shift+2 while the shop is open.

## Master size for crosshair target radius. Rock sizes are per-type below.
@export_range(0.25, 3.0, 0.05) var size_scale := 1.0

## How small the crosshair can shrink while holding fire (fraction of full size).
const SCOPE_MIN_SCALE := 0.7

@export_group("Scope Expand (Right Click)")
## How large the crosshair can grow while holding right-click (fraction of full size).
@export_range(1.05, 2.5, 0.01) var scope_expand_max_scale := 1.45

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

@export_group("Pillars")
@export_range(0.005, 0.3, 0.001) var pillar_width_ratio := 0.115
@export_range(0.0, 0.35, 0.001) var pillar_inset_ratio := 0.12
@export_range(0.005, 0.3, 0.001) var night_pillar_width_ratio := 0.07
@export_range(0.0, 0.35, 0.001) var night_pillar_inset_ratio := 0.2
@export_range(0.005, 0.3, 0.001) var blue_day_pillar_width_ratio := 0.14
@export_range(0.0, 0.35, 0.001) var blue_day_pillar_inset_ratio := 0.06

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
@export_range(1.0, 4.0, 0.1) var bullet_tick_width := 2.0
@export_range(4.0, 40.0, 0.5) var bullet_tick_gap := 10.0

const CREAM := Color(0.92156863, 0.8784314, 0.84705883, 1.0)
const BORDER_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const INK := Color(0.0824, 0.0941, 0.1098, 1.0)
const CROSSHAIR_RED := Color(0.78039217, 0.003921569, 0.007843138, 1.0)

const WALL_Y_RATIO := 0.88
const CROSSHAIR_RADIUS := 48.0
const PAD := Vector2(0.0, 0.0)
const HEADER_CLEARANCE := 120.0
const MAX_STRIKES := 10
const PILLAR_META := &"shop_mini_pillar"
const RING_POOL_SIZE := 8

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

@export_group("Rock Sizes")
@export_range(4.0, 80.0, 0.5) var basic_rock_size_min := 7.0
@export_range(4.0, 80.0, 0.5) var basic_rock_size_max := 13.0
@export_range(4.0, 80.0, 0.5) var black_rock_size_min := 8.0
@export_range(4.0, 80.0, 0.5) var black_rock_size_max := 14.0
@export_range(4.0, 80.0, 0.5) var red_rock_size_min := 9.0
@export_range(4.0, 80.0, 0.5) var red_rock_size_max := 16.0

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
@export_range(8.0, 40.0, 0.5) var smoke_can_size := 14.0
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

var is_open := false
var _intro_active := false
var _crosshair := Vector2.ZERO
var _wave_phase := 0.0
var _cloud_pan := 0.0
var _wave_timer := 0.0
var _wave_index := 0
var _pulsing := false
var _game_over := false
var _strikes := 0
var _money := 0.0
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
@onready var _strike_label: RichTextLabel = $PlayArea/Content/Overlay/StrikeLabel
@onready var _wave_label: RichTextLabel = $PlayArea/Content/Overlay/WaveAnnounceLabel
@onready var _perfect_label: RichTextLabel = get_node_or_null("PlayArea/Content/Overlay/PerfectLabel") as RichTextLabel
@onready var _multikill_label: RichTextLabel = $PlayArea/Content/Overlay/MultiKillLabel
@onready var _game_over_panel: Control = $PlayArea/Content/Overlay/GameOverPanel
@onready var _game_over_money: RichTextLabel = $PlayArea/Content/Overlay/GameOverPanel/MoneyEarned
@onready var _retry_button: Button = $PlayArea/Content/Overlay/GameOverPanel/RetryButton
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


func _setup_play_area_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = BORDER_WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	_play_area.add_theme_stylebox_override("panel", style)
	_play_area.clip_contents = true


func attach_to_shop(shop_root: Control, main_panel: Control, header_clearance: float = HEADER_CLEARANCE) -> void:
	_follow_panel = main_panel
	_header_clearance = header_clearance
	if get_parent() != shop_root:
		reparent(shop_root)
	top_level = true
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_to_panel()


func _sync_to_panel() -> void:
	if _follow_panel == null or not is_instance_valid(_follow_panel):
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
	_reset_run()
	_sync_to_panel()
	modulate.a = 0.0
	show()
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
	_begin_next_wave()


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
	_intro_title.text = "[i]Shoot for CENTS"
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
	_intro_title.text = "[i]Shoot for CENTS"
	_intro_title.modulate.a = 0.0
	_intro_title.show()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(_intro_title, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.0)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_intro_title, "modulate:a", 0.0, 0.4)
	tween.tween_interval(0.5)
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
	_perfect_label.text = "[i]PERFECT"
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
	_strikes = 0
	_money = 0.0
	_shake_trauma = 0.0
	_shake_strength = 0.0
	_shake_time = 0.0
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
	_game_over_panel.hide()
	_wave_label.modulate.a = 0.0
	_multikill_label.modulate.a = 0.0
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
	_begin_next_wave()


func _clear_rocks(clear_oranges: bool = false) -> void:
	for rock in _rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	_rocks.clear()
	for balloon in _balloons:
		if is_instance_valid(balloon):
			balloon.queue_free()
	_balloons.clear()
	for can in _smoke_cans:
		if is_instance_valid(can):
			can.queue_free()
	_smoke_cans.clear()
	var kept_oranges: Array[ShopMiniFruit] = []
	for fruit in _fruits:
		if not is_instance_valid(fruit):
			continue
		if fruit.kind == ShopMiniFruit.FruitKind.ORANGE and not clear_oranges and not fruit.hit:
			kept_oranges.append(fruit)
			continue
		fruit.queue_free()
	_fruits = kept_oranges
	if _physics_root:
		for child in _physics_root.get_children():
			if child.get_meta(PILLAR_META, false):
				continue
			if child in kept_oranges:
				continue
			child.queue_free()


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
	_wave_phase += delta * 2.2
	_cloud_pan += delta * cloud_pan_speed
	_update_sky_transition(delta)
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
	
	if not is_open or _game_over:
		return
	if event is InputEventMouseMotion:
		_crosshair += (event as InputEventMouseMotion).relative * mouse_sensitivity
		_crosshair.x = clampf(_crosshair.x, 0.0, _overlay.size.x)
		_crosshair.y = clampf(_crosshair.y, 0.0, _overlay.size.y)
		_update_crosshair_node()
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_scope_hold(ScopeMode.SHRINK)
			else:
				_release_scope_and_shoot(ScopeMode.SHRINK)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_begin_scope_hold(ScopeMode.EXPAND)
			else:
				_release_scope_and_shoot(ScopeMode.EXPAND)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_3:
			_debug_launch_orange()
			get_viewport().set_input_as_handled()


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
		target_radius = _scope_base_target_radius * scope_expand_max_scale
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
	_clear_rocks()
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
	# Kick off sky/pillar phase transition for wave 10 / 20 (1s blend).
	_begin_sky_transition_for_wave(wave)
	_wave_label.text = "[i]%s" % _wave_display_name(wave)
	_wave_label.modulate.a = 0.0
	_wave_label.scale = Vector2(0.85, 0.85)
	if _perfect_label:
		_perfect_label.modulate.a = 0.0
		_perfect_label.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if show_perfect and _perfect_label:
		_perfect_label.text = "[i]PERFECT"
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
	_clear_rocks()
	_ensure_pillars()
	_sync_pillars()
	var area := _overlay.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var wall_y := area.y * WALL_Y_RATIO
	var count := randi_range(2, 8) # rocks_per_wave
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
		can.setup(smoke_can_size * size_scale, rock_physics_material)
		var raw_x := area.x * _rng.randf_range(0.2, 0.8)
		can.position = Vector2(
			_clamp_spawn_x(raw_x, can.radius),
			wall_y + can.radius + _rng.randf_range(8.0, 20.0)
		)
		can.smoked.connect(_on_smoke_can_smoked)
		can.destroyed.connect(_on_smoke_can_destroyed)
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
			return _rng.randf_range(minf(black_rock_size_min, black_rock_size_max), maxf(black_rock_size_min, black_rock_size_max)) * size_scale
		ShopMiniRock.RockKind.RED:
			return _rng.randf_range(minf(red_rock_size_min, red_rock_size_max), maxf(red_rock_size_min, red_rock_size_max)) * size_scale
		_:
			return _rng.randf_range(minf(basic_rock_size_min, basic_rock_size_max), maxf(basic_rock_size_min, basic_rock_size_max)) * size_scale


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
	fruit.setup(kind, start_size * 0.5 * size_scale, texture, rock_physics_material)
	if kind == ShopMiniFruit.FruitKind.PINEAPPLE:
		fruit.shrink_speed = pineapple_shrink_speed
		fruit.fly_speed = pineapple_fly_speed
	else:
		fruit.shrink_speed = orange_shrink_speed
		fruit.fly_speed = orange_fly_speed
		fruit.hang_apex_y = _overlay.size.y * orange_apex_y_ratio
		fruit.ascent_speed = orange_ascent_speed
	fruit.flyaway_finished.connect(_on_fruit_flyaway_finished)
	fruit.orange_exploded.connect(_on_orange_exploded)
	return fruit


func _debug_launch_orange() -> void:
	if orange_texture == null:
		return
	_spawn_oranges_from_multikill(2, _crosshair.x)


func _spawn_oranges_from_multikill(count: int, origin_x: float) -> void:
	# Double = 1 orange, triple = 2, etc. (same as multi_shot_bonus.start_oranges)
	var orange_count := maxi(count - 1, 0)
	if orange_count <= 0 or orange_texture == null:
		return
	var area := _overlay.size
	var wall_y := area.y * WALL_Y_RATIO
	for i in orange_count:
		var fruit := _make_fruit(ShopMiniFruit.FruitKind.ORANGE, orange_start_size, orange_texture)
		var raw_x := origin_x + _rng.randf_range(-40.0, 40.0)
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
		if i < orange_count - 1:
			await get_tree().create_timer(0.45, false).timeout


func _roll_rock_kind() -> ShopMiniRock.RockKind:
	var roll := _rng.randf()
	if roll < black_rock_chance:
		return ShopMiniRock.RockKind.BLACK
	if roll < black_rock_chance + red_rock_chance:
		return ShopMiniRock.RockKind.RED
	return ShopMiniRock.RockKind.BASIC


func _pulse_rocks() -> void:
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

	var aim_together := _rng.randf() < aim_together_chance and to_pulse.size() >= 2
	var center := Vector2.ZERO
	if aim_together:
		for body in to_pulse:
			center += body.position
		center /= float(to_pulse.size())

	if _sfx_pulse:
		_sfx_pulse.play()
	
	_add_shake(launch_shake_strength, launch_shake_time)

	for body in to_pulse:
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
		body.pulse(impulse, x_impulse, grav, torque)
		if pulse_stagger > 0.0:
			await get_tree().create_timer(pulse_stagger).timeout


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
		if is_instance_valid(rock) and not rock.hit:
			count += 1
	return count


func _alive_target_count() -> int:
	# Oranges carry across rounds and do not gate the next wave.
	# Balloons are obstacles — they do not gate wave clear.
	var count := _alive_rock_count()
	for fruit in _fruits:
		if is_instance_valid(fruit) and not fruit.hit and fruit.kind != ShopMiniFruit.FruitKind.ORANGE:
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
			var mini := rock as ShopMiniRock
			var kind: ShopMiniRock.RockKind = mini.kind if mini else ShopMiniRock.RockKind.BASIC
			_play_splash(fall_pos)
			# Black rocks are hazards to avoid — letting them fall is success (no strike).
			if kind != ShopMiniRock.RockKind.BLACK:
				_add_strike()
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
		if can.pulsed and can.position.y > wall_y + can.radius + 40.0 and can.linear_velocity.y > 0.0:
			can.trigger_smoke()
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


func _try_shoot() -> void:
	if _game_over:
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
	if not balloon_blocked:
		for i in range(_fruits.size() - 1, -1, -1):
			var fruit := _fruits[i]
			if fruit == null or not is_instance_valid(fruit) or fruit.hit or fruit.flying_away:
				continue
			if fruit.position.y > wall_y and not fruit.hanging:
				continue
			if fruit.position.distance_to(_crosshair) > _current_target_radius + fruit.radius * 0.25:
				continue
			hit_any = true
			var center := Vector2(_overlay.size.x * 0.5, _overlay.size.y * 0.42)
			if fruit.apply_shot(center):
				_play_fruit_hit_sfx(fruit)
				if fruit.kind != ShopMiniFruit.FruitKind.PINEAPPLE:
					multikill_count += 1
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
		_miss_label.text = "[i]MISS"
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
		_out_label.add_theme_color_override("default_color", CROSSHAIR_RED)
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
	else:
		_add_money(money_per_destroy)
	if is_instance_valid(rock):
		rock.queue_free()


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
		balloon.apply_shot()

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


func _on_balloon_popped(balloon: ShopMiniBalloon, pos: Vector2) -> void:
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
	# Obstacle balloon — shooting it is a strike.
	_add_strike()
	if is_instance_valid(balloon):
		balloon.queue_free()


func _on_smoke_can_smoked(can: ShopMiniSmokeCan, pos: Vector2) -> void:
	_spawn_smoke_cloud(pos)


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
	_multikill_label.text = "[i][wave]%s" % text
	_multikill_label.modulate.a = 1.0
	_multikill_timer = 1.1
	if _sfx_multishot:
		_sfx_multishot.play()
	# Oranges spawn from multi-shot only (double → 1, triple → 2, …).
	_spawn_oranges_from_multikill(count, _crosshair.x)


func _add_money(amount: float) -> void:
	_money = maxf(0.0, _money + amount)
	_refresh_hud()


func _add_strike() -> void:
	if _game_over:
		return
	_strikes = mini(_strikes + 1, MAX_STRIKES)
	_refresh_hud()
	if _strikes >= MAX_STRIKES:
		_trigger_game_over()


func _trigger_game_over() -> void:
	_game_over = true
	_pulsing = false
	_clear_rocks(true)
	_game_over_money.text = "[center]You earned\n[color=#c70102]$%.2f[/color]" % _money
	_game_over_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mouse_sfx and _mouse_sfx.has_method("set_active"):
		_mouse_sfx.set_active(false)


func _refresh_hud() -> void:
	if _money_label:
		_money_label.text = "[right]$%.2f" % _money
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
		_pillar_left = _make_pillar_body("PillarLeft")
	if _pillar_right == null or not is_instance_valid(_pillar_right):
		_pillar_right = _make_pillar_body("PillarRight")
	_sync_pillars()


func _make_pillar_body(p_name: String) -> StaticBody2D:
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
	rect.size = Vector2(w, h)
	body.position = Vector2(x + w * 0.5, y + h * 0.5)


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
	if _shake_trauma <= 0.0 or _shake_strength <= 0.0:
		return Vector2.ZERO
	# Soft sine shake — applied only to visual layers, never PhysicsRoot.
	var falloff := clampf(_shake_trauma / maxf(destroy_shake_time, 0.05), 0.0, 1.0)
	falloff = falloff * falloff
	var mag := _shake_strength * falloff
	return Vector2(sin(_shake_time * 58.0), cos(_shake_time * 43.0)) * mag


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
	if not day_night_cycle_enabled or wave < 10:
		return 0.0
	if wave < 20:
		return 1.0
	return 2.0


func _begin_sky_transition_for_wave(wave: int) -> void:
	if not day_night_cycle_enabled:
		_sky_from = 0.0
		_sky_to = 0.0
		_sky_blend_t = 1.0
		_sync_pillars()
		return
	var target := _target_sky_progress_for_wave(wave)
	var current := _sky_visual_progress()
	if is_equal_approx(current, target) and _sky_blend_t >= 1.0:
		return
	_sky_from = current
	_sky_to = target
	_sky_blend_t = 0.0


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
	var pos := Vector2(area.x * 0.78, wall_y * 0.22)
	var radius := 18.0 + 6.0 * night
	var glow := moon_color
	glow.a *= night * 0.25
	_wave_layer.draw_circle(pos, radius * 1.8, glow)
	var body := moon_color
	body.a *= night
	_wave_layer.draw_circle(pos, radius, body)
	# Soft crescent cut for a bit of character.
	var cut := night_sky_color
	cut.a *= night * 0.85
	_wave_layer.draw_circle(pos + Vector2(radius * 0.35, -radius * 0.1), radius * 0.85, cut)


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
	var wrap := area.x + 160.0
	for cloud in clouds:
		var c: Vector2 = cloud["c"]
		var rx: float = cloud["rx"]
		var ry: float = cloud["ry"]
		c.x = fposmod(c.x + _cloud_pan + sin(_wave_phase * 0.12 + rx * 0.01) * 4.0, wrap) - 80.0
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
	_draw_flashes()
	_draw_active_shot_rings()
	_draw_blast_rings()
	_draw_bullet_ticks()
	# Fallback crosshair if no custom texture assigned.
	if _crosshair_texture == null or _crosshair_texture.texture == null:
		_draw_crosshair(_crosshair)
	# Subtle aim circle matching current shrink radius.
	_overlay.draw_arc(_crosshair, _current_target_radius, 0.0, TAU, 48, Color(CROSSHAIR_RED.r, CROSSHAIR_RED.g, CROSSHAIR_RED.b, 0.25), 1.25, true)


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
		var color := Color(CROSSHAIR_RED.r, CROSSHAIR_RED.g, CROSSHAIR_RED.b, alpha)
		if flash.get("burst", false):
			var r := (0.22 - t) * 90.0
			_overlay.draw_arc(pos, maxf(r, CROSSHAIR_RADIUS - 5.0), 0.0, TAU, 18, color, 1.5, true)
		#else:
			#_overlay.draw_circle(pos, 3.0, color)


func _draw_crosshair(pos: Vector2) -> void:
	return
	#var r := CROSSHAIR_RADIUS
	#_overlay.draw_arc(pos, r, 0.0, TAU, 48, CROSSHAIR_RED, 2.0, true)
	#_overlay.draw_circle(pos, 12.2, Color("ff000028"))
	#var tick := 30.0
	#_overlay.draw_line(pos + Vector2(0, -r - tick), pos + Vector2(0, -r), CROSSHAIR_RED, 2.0, true)
	#_overlay.draw_line(pos + Vector2(0, r), pos + Vector2(0, r + tick), CROSSHAIR_RED, 2.0, true)
	#_overlay.draw_line(pos + Vector2(-r - tick, 0), pos + Vector2(-r, 0), CROSSHAIR_RED, 2.0, true)
	#_overlay.draw_line(pos + Vector2(r, 0), pos + Vector2(r + tick, 0), CROSSHAIR_RED, 2.0, true)


func crosshair_blink() -> void:
	_play_shot_feedback()
