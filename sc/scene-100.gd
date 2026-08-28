extends Node3D

@export var intro_title_screen := false
@export var player : Player

@export var round_manager : RoundManager
@export var round_timer : Control
@export var HUD_CRT : TextureRect
@export var splash_screen : CanvasLayer

@export var music_manager : Node
@export var main_game_canvas : CanvasLayer
@export var move_speed := 5.0

## Former Main.tscn title Camera3D world transform — player cam starts here, then eases to gameplay rest.
## GDScript has no 12-float Transform3D ctor (that's .tscn only); use axis Vector3s.
var TITLE_CAMERA_TRANSFORM := Transform3D(
	Vector3(-1.0, 0.0, -8.742278e-08),
	Vector3(6.859112e-09, 0.99691725, -0.07845909),
	Vector3(8.7153275e-08, -0.07845909, -0.99691725),
	Vector3(0.0, 0.0, 17.224)
)

var moving_camera := false
var _player_cam_rest_global := Transform3D.IDENTITY
var _has_cam_rest := false
## First Start from cold boot does the title→gameplay swoop; later Starts keep the cam.
var _title_camera_swoop_done := false


func _ready() -> void:
	await get_tree().process_frame
	set_process(false)
	main_game_canvas.hide()
	_capture_player_cam_rest()

	Parser.loadIslandFile('res://sc/island-shipper.txt')

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


func _get_player_cam() -> Camera3D:
	return get_tree().get_first_node_in_group("player_cam") as Camera3D


func _capture_player_cam_rest() -> void:
	var cam := _get_player_cam()
	if cam == null:
		return
	_player_cam_rest_global = cam.global_transform
	_has_cam_rest = true


## Put the player camera at the old title Camera3D pose (no separate Main camera).
func apply_title_camera_pose() -> void:
	var cam := _get_player_cam()
	if cam == null:
		return
	if not _has_cam_rest:
		_capture_player_cam_rest()
	cam.global_transform = TITLE_CAMERA_TRANSFORM
	cam.current = true


func hold_at_title_camera() -> void:
	moving_camera = false
	set_process(false)
	apply_title_camera_pose()


func begin_swoop_to_gameplay_camera() -> void:
	if not _has_cam_rest:
		_capture_player_cam_rest()
	var cam := _get_player_cam()
	if cam:
		cam.current = true
	moving_camera = true
	set_process(true)


func await_camera_swoop() -> void:
	while moving_camera and is_inside_tree():
		await get_tree().process_frame


func snap_player_camera_to_rest() -> void:
	var cam := _get_player_cam()
	if cam == null:
		return
	if not _has_cam_rest:
		_capture_player_cam_rest()
	cam.global_transform = _player_cam_rest_global
	cam.current = true
	moving_camera = false
	set_process(false)


func start_game_quick() -> void:
	# Hide (do not free) so Back to Title can reopen Start.
	if is_instance_valid(splash_screen):
		splash_screen.hide()
	main_game_canvas.show()
	snap_player_camera_to_rest()
	if HUD_CRT and HUD_CRT.has_method("crt_start_up"):
		HUD_CRT.crt_start_up()
	round_manager.enter_state(round_manager.RoundState.SHOP_START)
	await get_tree().create_timer(0.05, false).timeout
	music_manager.start_bg_noise()
	await get_tree().create_timer(0.25, false).timeout
	player.start_player()


func start_intro_process() -> void:
	splash_screen.start()
	round_manager.enter_state(round_manager.RoundState.INACTIVE)
	apply_title_camera_pose()
	if round_timer:
		round_timer.hide()
	player.title_screen_start()

	await get_tree().create_timer(0.25, false).timeout
	music_manager.start_bg_noise()

	await get_tree().create_timer(1.75, false).timeout

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func start_game() -> void:
	player.title_screen_end()

	## After Back to Title, keep whatever camera pose we already have.
	if _title_camera_swoop_done:
		moving_camera = false
		set_process(false)
		main_game_canvas.show()
		round_manager.enter_state(round_manager.RoundState.START_START)
		if is_instance_valid(splash_screen):
			splash_screen.hide()
		return

	## First boot: ease player cam from title pose → gameplay rest.
	if not _has_cam_rest:
		_capture_player_cam_rest()
	var cam := _get_player_cam()
	if cam:
		cam.global_transform = TITLE_CAMERA_TRANSFORM
		cam.current = true

	moving_camera = true
	set_process(true)
	main_game_canvas.show()
	round_manager.enter_state(round_manager.RoundState.START_START)
	while moving_camera:
		await get_tree().process_frame

	_title_camera_swoop_done = true
	await get_tree().create_timer(0.25, false).timeout
	# Keep splash around so Back to Title can reopen it without a scene reload.
	if is_instance_valid(splash_screen):
		splash_screen.hide()


## Debug (Shift+M): tear down title/splash so Moss can start immediately.
func debug_bootstrap_gameplay() -> void:
	moving_camera = false
	set_process(false)

	if is_instance_valid(splash_screen):
		splash_screen.hide()

	if main_game_canvas:
		main_game_canvas.show()

	snap_player_camera_to_rest()

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

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame


func move_camera_to_player(delta: float) -> void:
	var player_cam := _get_player_cam()
	if player_cam == null:
		moving_camera = false
		set_process(false)
		return

	if not _has_cam_rest:
		_capture_player_cam_rest()

	player_cam.global_transform = player_cam.global_transform.interpolate_with(
		_player_cam_rest_global,
		move_speed * delta
	)

	if player_cam.global_position.distance_to(_player_cam_rest_global.origin) < 0.05:
		player_cam.global_transform = _player_cam_rest_global
		player_cam.current = true
		set_process(false)
		moving_camera = false
