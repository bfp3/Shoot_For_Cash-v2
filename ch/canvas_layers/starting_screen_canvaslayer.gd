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
	EventBus.instance.open_tally_card.connect(enter_state.bind(State.OPEN_MENU))

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
	
	tween.tween_property(game_name, "scale", Vector2.ONE * 1.0, 0.15)
	tween.tween_interval(1.15)
	tween.tween_property(game_title_background, "modulate:a", 1.0, 0.15)
	await tween.finished
	background_balloons.start = true
	var start_btn := splash_screen_control.get_node_or_null("GameTitleBackground/StartGame") as Control
	UiFocus.grab_in(splash_screen_control, start_btn)
	#tween.tween_interval(2.0)
	#tween.tween_property(copyright, "modulate:a", 1.0, 1.5)
	
		
func opening_sfx() -> void:
	$SplashScreen_v2/SFX/shop_close_sfx_01.play()
	$SplashScreen_v2/SFX/hud_click_1.play()
	$SplashScreen_v2/SFX/hud_click_2.play()
	$SplashScreen_v2/SFX/hud_click_3.play()
	$SplashScreen_v2/SFX/start_sfx.play()
	
func update_inactive() -> void:
	pass


	
func update_open_menu() -> void:
	if menu_in_display:
		return
	
	menu_in_display = true

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

	splash_screen_control.pivot_offset_ratio = Vector2(0.5,1.155)

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(splash_screen_control, "scale", Vector2.ONE / 99, 0.4)
	tween.parallel().tween_property(splash_screen_control, "modulate:a", 1.0, 0.18)
	

	await tween.finished

	# PERFECT RESET AFTER CLOSE
	scale = default_scale
	splash_screen_control.modulate.a = 1.0
	splash_screen_control.position = default_position
	menu_in_display = false
	
	hide()


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
