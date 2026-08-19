extends CanvasLayer

@export var round_manager : RoundManager

enum State {
	START,
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}


var current_state : State = State.INACTIVE
var menu_in_display := false

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO


@onready var splash_screen_control: Control = $SplashScreen_v2
@onready var wormfood_logo: Control = $SplashScreen_v2/WormfoodLogo
@onready var background_balloons: Control = $SplashScreen_v2/BackgroundBalloons
@onready var game_title_background: Control = $SplashScreen_v2/GameTitleBackground
@onready var game_name: Control = $SplashScreen_v2/GameName
@onready var copyright: RichTextLabel = %CopyrightText

@export var music_control : Node

func _ready() -> void:
	# Title/splash is only for the opening screen — do not open it when a tally card appears.
	# (open_tally_card used to incorrectly trigger the start menu mid-run.)

	# STORE DEFAULT TRANSFORMS
	splash_screen_control.default_scale = splash_screen_control.scale
	default_position = splash_screen_control.position

	# BOTTOM RIGHT PIVOT
	splash_screen_control.default_pivot_offset = Vector2(0.5,1.15)
	splash_screen_control.pivot_offset_ratio = default_pivot_offset

	hide()
	
func start() -> void:
	#splash_screen_control.enter_state(splash_screen_control.State.START)
	enter_state(State.START)
	
func enter_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.START:
			update_start()
		
		State.INACTIVE:
			update_inactive()
		
		State.OPEN_MENU:
			update_open_menu()
		
		State.IN_MENU:
			update_in_menu()
		
		State.CLOSE_MENU:
			update_close_menu()
		_:
			print("No State Exists - Skill Menu Script")


func update_start() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	copyright.modulate.a = 0.0
	game_name.modulate.a = 0.0

	game_title_background.modulate.a = 0.0
	await wormfood_logo.start()
	
	
	var tween = create_tween()
	tween.tween_callback(music_control.start_opening_song)
	tween.tween_interval(1.5)
	
	tween.tween_interval(1.0)
	tween.tween_property(game_name, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(game_name, "scale", Vector2.ONE * 1.25, 0.15)
	tween.parallel().tween_callback(opening_sfx)
	tween.tween_callback(CommonCode.apply_transition_blur)
	tween.tween_property(game_name, "scale", Vector2.ONE * 1.0, 0.15)
	tween.tween_interval(1.15)
	tween.tween_property(game_title_background, "modulate:a", 1.0, 0.15)
	await tween.finished
	_resume_title_children()
	var start_btn := splash_screen_control.get_node_or_null("GameTitleBackground/StartGame") as Control
	UiFocus.grab_in(splash_screen_control, start_btn)

func opening_sfx() -> void:
	$SplashScreen_v2/SFX/shop_close_sfx_01.play()
	$SplashScreen_v2/SFX/hud_click_1.play()
	$SplashScreen_v2/SFX/hud_click_2.play()
	$SplashScreen_v2/SFX/hud_click_3.play()
	$SplashScreen_v2/SFX/start_sfx.play()
	
func update_inactive() -> void:
	pass


## Return from gameplay without replaying the Wormfood / title intro.
func show_title_ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	menu_in_display = true
	current_state = State.IN_MENU

	if wormfood_logo:
		wormfood_logo.hide()
	copyright.modulate.a = 0.0
	game_name.modulate.a = 1.0
	game_name.scale = Vector2.ONE
	game_title_background.modulate.a = 1.0
	splash_screen_control.modulate.a = 1.0
	if splash_screen_control.get("default_scale") != null:
		splash_screen_control.scale = splash_screen_control.default_scale
	else:
		splash_screen_control.scale = Vector2.ONE
	splash_screen_control.position = default_position
	splash_screen_control.pivot_offset_ratio = default_pivot_offset
	_resume_title_children()

	if music_control and music_control.has_method("start_opening_song"):
		music_control.start_opening_song()

	var start_btn := splash_screen_control.get_node_or_null("GameTitleBackground/StartGame") as Control
	UiFocus.grab_in(splash_screen_control, start_btn)

	
func update_open_menu() -> void:
	if menu_in_display:
		return
	
	menu_in_display = true
	process_mode = Node.PROCESS_MODE_INHERIT

	splash_screen_control.modulate.a = 0.0
	splash_screen_control.scale = Vector2.ONE * 0.01
	splash_screen_control.position = default_position
	splash_screen_control.pivot_offset_ratio = default_pivot_offset

	show()

	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(splash_screen_control, "scale", default_scale, 0.4)
	tween.parallel().tween_property(splash_screen_control, "modulate:a", 1.0, 0.18)
	
	await tween.finished
	
	enter_state(State.IN_MENU)
	

func update_close_menu() -> void:
	$'..'.start_game()

	## Expand + fade out (instead of shrinking to the bottom corner).
	splash_screen_control.pivot_offset_ratio = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(splash_screen_control, "scale", Vector2.ONE * 1.65, 0.4)
	tween.parallel().tween_property(splash_screen_control, "modulate:a", 0.0, 0.4)

	await tween.finished

	## Reset so the next visit opens cleanly.
	var restore_scale: Vector2 = Vector2.ONE
	if splash_screen_control.get("default_scale") != null:
		restore_scale = splash_screen_control.default_scale
	splash_screen_control.scale = restore_scale
	splash_screen_control.modulate.a = 1.0
	splash_screen_control.position = default_position
	splash_screen_control.pivot_offset_ratio = default_pivot_offset
	game_name.scale = Vector2.ONE
	game_name.modulate.a = 1.0
	game_title_background.modulate.a = 1.0
	menu_in_display = false

	_stop_title_children()
	hide()
	## Stop this canvas + inherited children (balloons, particles, anims) until title returns.
	process_mode = Node.PROCESS_MODE_DISABLED


func _stop_title_children() -> void:
	if background_balloons:
		background_balloons.start = false
		background_balloons.set_process(false)
		background_balloons.process_mode = Node.PROCESS_MODE_DISABLED
	var particles := splash_screen_control.get_node_or_null("BackgroundParticles") as Node
	if particles:
		if particles is GPUParticles2D:
			(particles as GPUParticles2D).emitting = false
		particles.process_mode = Node.PROCESS_MODE_DISABLED
	_pause_animation_players(splash_screen_control, true)


func _resume_title_children() -> void:
	if background_balloons:
		background_balloons.process_mode = Node.PROCESS_MODE_INHERIT
		background_balloons.set_process(true)
		background_balloons.start = true
	var particles := splash_screen_control.get_node_or_null("BackgroundParticles") as Node
	if particles:
		particles.process_mode = Node.PROCESS_MODE_INHERIT
		if particles is GPUParticles2D:
			(particles as GPUParticles2D).emitting = true
	_pause_animation_players(splash_screen_control, false)


func _pause_animation_players(root: Node, paused: bool) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is AnimationPlayer:
			var ap := child as AnimationPlayer
			if paused:
				ap.pause()
			elif not ap.is_playing():
				pass
		_pause_animation_players(child, paused)


func notify_round_manager() -> void:
	if !round_manager:
		var _round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
		if _round_manager:
			_round_manager.enter_state(_round_manager.RoundState.TALLY_END)
			
	else:
		round_manager.enter_state(round_manager.RoundState.TALLY_END)


func update_in_menu() -> void:
	pass


func _on_start_game_pressed() -> void:
	var prog_bar : ProgressBar = %Start_button_progressBar
	
	var tween = create_tween()

	tween.tween_property(prog_bar, "value", 100.0, 0.3)
	await get_tree().create_timer(0.29).timeout
	prog_bar.value = 0.0
	
	music_control._on_start_button_pressed()
	
	$SplashScreen_v2/SFX/hud_click_1.play()
	$SplashScreen_v2/SFX/shop_close_sfx_01.play()
	$SplashScreen_v2/SFX/hud_click_1.play()
	$SplashScreen_v2/SFX/hud_click_2.play()
	$SplashScreen_v2/SFX/hud_click_3.play()
	$SplashScreen_v2/SFX/start_sfx.play()
	enter_state(State.CLOSE_MENU)
