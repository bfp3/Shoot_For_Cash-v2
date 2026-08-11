extends Node3D

@export var intro_title_screen := false
@export var player : Player

@export var round_manager : RoundManager
@export var start_cam : Camera3D
@export var round_timer : Control
@export var HUD_CRT : TextureRect
@export var splash_screen : CanvasLayer

@export var music_manager : Node
@export var main_game_canvas : CanvasLayer
@export var move_speed := 5.0
var moving_camera := false


func _ready() -> void:
	await get_tree().process_frame
	set_process(false)
	main_game_canvas.hide()

	Parser.loadIslandFile('res://sc/island-shipper.txt')

	# Compatibility / Web: compile shaders & particle pipelines before control.
	#await ShaderWarmup.ensure_warmed()

	var pending_level := RestarterScript.take_pending_fast_travel()
	if pending_level != "":
		await debug_bootstrap_gameplay()
		gl_PlayerState.reset_level()
		gl_PlayerState.round_finished = false
		if round_manager and round_manager.has_method("debug_restart_to_level"):
			await round_manager.debug_restart_to_level(pending_level)
		return

	if intro_title_screen:
		start_intro_process()
	else:
		start_game_quick()

		
func _process(delta: float) -> void:
	if moving_camera:
		move_camera_to_player(delta)
		
func start_game_quick() -> void:
	# Hide (do not free) so Back to Title can reopen Start.
	if is_instance_valid(splash_screen):
		splash_screen.hide()
	main_game_canvas.show()
	if is_instance_valid(start_cam):
		start_cam.queue_free()
		start_cam = null
	HUD_CRT.crt_start_up()
	round_manager.enter_state(round_manager.RoundState.SHOP_START)
	await get_tree().create_timer(0.05).timeout
	music_manager.start_bg_noise()
	await get_tree().create_timer(0.25).timeout
	#music_manager.start_bg_music()
	player.start_player()

	

	
func start_intro_process() -> void:
	splash_screen.start()
	round_manager.enter_state(round_manager.RoundState.INACTIVE)
	start_cam.current = true
	round_timer.hide()
	#HUD_CRT.title_screen()
	player.title_screen_start()

	await get_tree().create_timer(0.25).timeout
	music_manager.start_bg_noise()
	
	await get_tree().create_timer(1.75).timeout

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	

func start_game() -> void:
	player.title_screen_end()

	# Already past the first title camera swoop (e.g. Back to Title → Start again).
	if not is_instance_valid(start_cam):
		moving_camera = false
		set_process(false)
		main_game_canvas.show()
		round_manager.enter_state(round_manager.RoundState.START_START)
		if player and player.has_method("start_player"):
			player.start_player()
		if HUD_CRT and HUD_CRT.has_method("start_game"):
			HUD_CRT.start_game()
		if is_instance_valid(splash_screen):
			splash_screen.hide()
		return

	moving_camera = true
	set_process(true)
	# wait until camera is close enough
	main_game_canvas.show()
	#round_manager.enter_state(round_manager.RoundState.SHOP_START)
	round_manager.enter_state(round_manager.RoundState.START_START)
	while moving_camera:
		await get_tree().process_frame


	#music_manager.start_bg_music()
	#await get_tree().create_timer(0.25).timeout
	player.start_player()
	#round_timer.show()
	#HUD_CRT.start_game()
	#rocks_on_screen_counter.show()
	
	await get_tree().create_timer(0.25).timeout
	# Keep splash around so Back to Title can reopen it without a scene reload.
	if is_instance_valid(splash_screen):
		splash_screen.hide()


## Debug (Shift+M): tear down title/splash so Moss can start immediately.
func debug_bootstrap_gameplay() -> void:
	moving_camera = false
	set_process(false)

	# Hide splash — never free it (Back to Title needs show_title_ready).
	if is_instance_valid(splash_screen):
		splash_screen.hide()

	if main_game_canvas:
		main_game_canvas.show()

	if is_instance_valid(start_cam):
		var player_cam = get_tree().get_first_node_in_group("player_cam")
		if player_cam:
			player_cam.current = true
		start_cam.queue_free()
		start_cam = null

	if HUD_CRT and HUD_CRT.has_method("crt_start_up"):
		HUD_CRT.crt_start_up()
	elif HUD_CRT and HUD_CRT.has_method("start_game"):
		HUD_CRT.start_game()

	if music_manager and music_manager.has_method("start_bg_noise"):
		music_manager.start_bg_noise()

	if player:
		if player.has_method("title_screen_end"):
			player.title_screen_end()
		player.display_hud()

	#if round_timer:
		#round_timer.show()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame


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
	

		
