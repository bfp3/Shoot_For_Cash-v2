extends Node3D

@export var intro_title_screen := false
@export var player : Player

@export var round_manager : RoundManager
@export var start_cam : Camera3D
@export var round_timer : Control
@export var HUD_CRT : TextureRect
@export var splash_screen : Control
@export var music_manager : Node
@export var main_game_canvas : CanvasLayer
@export var move_speed := 5.0
var moving_camera := false

func _ready() -> void:
	
	set_process(false)
	main_game_canvas.hide()
	if intro_title_screen:
		start_intro_process()
		
	else:
		start_game_quick()

		
func _process(delta: float) -> void:
	if moving_camera:
		move_camera_to_player(delta)
		
func start_game_quick() -> void:
	splash_screen.queue_free()
	main_game_canvas.show()
	start_cam.queue_free()
	HUD_CRT.crt_start_up()
	round_manager.enter_state(round_manager.RoundState.FIRST_ROUND)
	await get_tree().create_timer(0.05).timeout
	music_manager.start_bg_noise()
	await get_tree().create_timer(0.25).timeout
	#music_manager.start_bg_music()
	player.start_player()

	

	
func start_intro_process() -> void:

	splash_screen.enter_state(splash_screen.State.START)
	round_manager.enter_state(round_manager.RoundState.INACTIVE)
	start_cam.current = true
	round_timer.hide()
	HUD_CRT.title_screen()
	player.title_screen_start()

	await get_tree().create_timer(0.25).timeout
	music_manager.start_bg_noise()
	
	await get_tree().create_timer(1.75).timeout

	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	

func start_game() -> void:
	player.title_screen_end()
	
	moving_camera = true
	set_process(true)
	# wait until camera is close enough
	main_game_canvas.show()
	round_manager.enter_state(round_manager.RoundState.FIRST_ROUND)
	
	while moving_camera:
		await get_tree().process_frame


	#music_manager.start_bg_music()
	#await get_tree().create_timer(0.25).timeout
	player.start_player()
	round_timer.show()
	HUD_CRT.start_game()
	#rocks_on_screen_counter.show()

	await get_tree().create_timer(0.25).timeout
	splash_screen.queue_free()


func move_camera_to_player(delta: float) -> void:
	var player_cam = get_tree().get_first_node_in_group("player_cam")

	if player_cam == null:
		return

	# smooth follow
	start_cam.global_transform = start_cam.global_transform.interpolate_with(
		player_cam.global_transform,
		move_speed * delta
	)

	# stop when close enough
	if start_cam.global_position.distance_to(player_cam.global_position) < 0.05:
		start_cam.global_transform = player_cam.global_transform
		player_cam.current = true
		set_process(false)
		start_cam.queue_free()
		moving_camera = false
	
