extends Node

## Persistent graphics + input settings. Applied on boot and from the pause Options menu.

const CONFIG_PATH := "user://game_settings.cfg"
const SECTION := "settings"
const RESOLUTION_CONFIRM_SECONDS := 15.0

## Calibrated so level 1 ≈ old feel at 1080p (0.3 base * relative pixels).
const MOUSE_LOOK_BASE := 324.0
const MOUSE_SENS_MIN_LEVEL := 1
const MOUSE_SENS_MAX_LEVEL := 10

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

const MSAA_LABELS: PackedStringArray = ["Off", "2x", "4x", "8x"]
const SCALE_3D_VALUES: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5]
const SCALE_3D_LABELS: PackedStringArray = ["50%", "75%", "100%", "125%", "150%"]
const MAX_FPS_VALUES: Array[int] = [0, 30, 60, 120, 144, 240]
const MAX_FPS_LABELS: PackedStringArray = ["Unlimited", "30", "60", "120", "144", "240"]

signal settings_changed
signal resolution_confirm_started(seconds_left: float)
signal resolution_confirm_tick(seconds_left: float)
signal resolution_confirm_finished(kept: bool)
## Fired after a sensitivity stage bump (including when already at min/max).
signal sensitivity_bumped(level: int)

var resolution: Vector2i = Vector2i(1920, 1080)
var msaa_level: int = 2 ## Viewport.MSAA_* shared for 2D + 3D
var scaling_3d: float = 1.0
var vsync_enabled: bool = true
var max_fps: int = 0
var mouse_sensitivity_level: int = 1
## 0–100. 100% keeps the project's existing Master bus loudness.
var master_volume_percent: float = 100.0
## 0–100. 100% keeps the project's existing MusicBus loudness.
var music_volume_percent: float = 100.0

var _prev_resolution: Vector2i = Vector2i(1920, 1080)
var _prev_window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var _resolution_pending := false
var _confirm_time_left := 0.0
## Captured from AudioServer so 100% == current project loudness (not 0 dB).
var _master_baseline_db := 0.0
var _music_baseline_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_bus_baselines()
	_load_defaults_from_project()
	var had_save := FileAccess.file_exists(CONFIG_PATH)
	load_from_disk()
	apply_all(false, had_save)
	set_process(false)


func _process(delta: float) -> void:
	if not _resolution_pending:
		set_process(false)
		return
	_confirm_time_left -= delta
	resolution_confirm_tick.emit(maxi(ceili(_confirm_time_left), 0))
	if _confirm_time_left <= 0.0:
		revert_resolution()


func _load_defaults_from_project() -> void:
	resolution = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)
	msaa_level = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 3))
	# Prefer matching both; if project 2D differs, still start from 3D (stricter) then sync both on apply.
	var msaa_2d := int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 2))
	if msaa_2d == msaa_level:
		pass
	else:
		# Use the higher of the two as the combined default so visuals stay close to project.
		msaa_level = maxi(msaa_2d, msaa_level)
	scaling_3d = 1.0
	vsync_enabled = true
	max_fps = 0
	mouse_sensitivity_level = 1
	master_volume_percent = 100.0
	music_volume_percent = 100.0


func _capture_bus_baselines() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("MusicBus")
	if master_idx >= 0:
		_master_baseline_db = AudioServer.get_bus_volume_db(master_idx)
	if music_idx >= 0:
		_music_baseline_db = AudioServer.get_bus_volume_db(music_idx)


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution = Vector2i(
		int(cfg.get_value(SECTION, "resolution_x", resolution.x)),
		int(cfg.get_value(SECTION, "resolution_y", resolution.y))
	)
	msaa_level = clampi(int(cfg.get_value(SECTION, "msaa_level", msaa_level)), 0, 3)
	scaling_3d = float(cfg.get_value(SECTION, "scaling_3d", scaling_3d))
	vsync_enabled = bool(cfg.get_value(SECTION, "vsync_enabled", vsync_enabled))
	max_fps = int(cfg.get_value(SECTION, "max_fps", max_fps))
	mouse_sensitivity_level = clampi(
		int(cfg.get_value(SECTION, "mouse_sensitivity_level", mouse_sensitivity_level)),
		MOUSE_SENS_MIN_LEVEL,
		MOUSE_SENS_MAX_LEVEL
	)
	master_volume_percent = clampf(float(cfg.get_value(SECTION, "master_volume_percent", master_volume_percent)), 0.0, 100.0)
	music_volume_percent = clampf(float(cfg.get_value(SECTION, "music_volume_percent", music_volume_percent)), 0.0, 100.0)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH) # ok if missing
	cfg.set_value(SECTION, "resolution_x", resolution.x)
	cfg.set_value(SECTION, "resolution_y", resolution.y)
	cfg.set_value(SECTION, "msaa_level", msaa_level)
	cfg.set_value(SECTION, "scaling_3d", scaling_3d)
	cfg.set_value(SECTION, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION, "max_fps", max_fps)
	cfg.set_value(SECTION, "mouse_sensitivity_level", mouse_sensitivity_level)
	cfg.set_value(SECTION, "master_volume_percent", master_volume_percent)
	cfg.set_value(SECTION, "music_volume_percent", music_volume_percent)
	cfg.save(CONFIG_PATH)


func apply_all(persist: bool = true, apply_window: bool = true) -> void:
	if apply_window:
		_apply_window_resolution(resolution, true)
	_apply_msaa()
	_apply_scaling_3d()
	_apply_vsync()
	_apply_max_fps()
	_apply_mouse_sensitivity()
	_apply_master_volume()
	_apply_music_volume()
	if persist:
		save_to_disk()
	settings_changed.emit()


func apply_msaa(level: int) -> void:
	msaa_level = clampi(level, 0, 3)
	_apply_msaa()
	save_to_disk()
	settings_changed.emit()


func apply_scaling_3d(scale: float) -> void:
	scaling_3d = clampf(scale, 0.25, 2.0)
	_apply_scaling_3d()
	save_to_disk()
	settings_changed.emit()


func apply_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_vsync()
	save_to_disk()
	settings_changed.emit()


func apply_max_fps(fps: int) -> void:
	max_fps = maxi(fps, 0)
	_apply_max_fps()
	save_to_disk()
	settings_changed.emit()


func apply_mouse_sensitivity_level(level: int) -> void:
	mouse_sensitivity_level = clampi(level, MOUSE_SENS_MIN_LEVEL, MOUSE_SENS_MAX_LEVEL)
	_apply_mouse_sensitivity()
	save_to_disk()
	settings_changed.emit()


func bump_mouse_sensitivity(delta_levels: int) -> void:
	apply_mouse_sensitivity_level(mouse_sensitivity_level + delta_levels)
	sensitivity_bumped.emit(mouse_sensitivity_level)


func apply_master_volume(percent: float) -> void:
	master_volume_percent = clampf(percent, 0.0, 100.0)
	_apply_master_volume()
	save_to_disk()
	settings_changed.emit()


func apply_music_volume(percent: float) -> void:
	music_volume_percent = clampf(percent, 0.0, 100.0)
	_apply_music_volume()
	save_to_disk()
	settings_changed.emit()


## Shared display string for Settings + in-game popup ("1 / 10").
func sensitivity_display_text(level: int = -1) -> String:
	var stage := mouse_sensitivity_level if level < 0 else clampi(level, MOUSE_SENS_MIN_LEVEL, MOUSE_SENS_MAX_LEVEL)
	return "%d[color=800000][font_size=50]/%d" % [stage, MOUSE_SENS_MAX_LEVEL]


## Multiplier for keyboard / controller crosshair speed (stage 1 == 1.0).
func crosshair_speed_multiplier() -> float:
	return float(mouse_sensitivity_level)


## Absolute Master bus dB for the current Master Volume setting (for systems like retro FX).
func effective_master_volume_db() -> float:
	return _percent_to_db(master_volume_percent, _master_baseline_db)


## Try a new resolution. Shows confirm UI via signals; auto-reverts after 15s.
func try_resolution(new_resolution: Vector2i) -> void:
	if _resolution_pending:
		return
	if new_resolution == DisplayServer.window_get_size() \
			and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN \
			and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		resolution = new_resolution
		save_to_disk()
		return

	_prev_resolution = DisplayServer.window_get_size()
	_prev_window_mode = DisplayServer.window_get_mode()
	# If we were fullscreen, remember the last saved resolution as revert target.
	if _prev_window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or _prev_window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		_prev_resolution = resolution

	_apply_window_resolution(new_resolution, true)
	resolution = new_resolution
	_resolution_pending = true
	_confirm_time_left = RESOLUTION_CONFIRM_SECONDS
	set_process(true)
	resolution_confirm_started.emit(_confirm_time_left)
	resolution_confirm_tick.emit(ceili(_confirm_time_left))


func keep_resolution() -> void:
	if not _resolution_pending:
		return
	_resolution_pending = false
	set_process(false)
	save_to_disk()
	resolution_confirm_finished.emit(true)
	settings_changed.emit()


func revert_resolution() -> void:
	if not _resolution_pending:
		return
	_resolution_pending = false
	set_process(false)
	resolution = _prev_resolution
	DisplayServer.window_set_mode(_prev_window_mode)
	if _prev_window_mode == DisplayServer.WINDOW_MODE_WINDOWED \
			or _prev_window_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_size(_prev_resolution)
		_center_window(_prev_resolution)
	resolution_confirm_finished.emit(false)
	settings_changed.emit()


func is_resolution_pending() -> bool:
	return _resolution_pending


func confirm_seconds_left() -> float:
	return _confirm_time_left


func resolution_index() -> int:
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == resolution:
			return i
	return 3 # 1080p fallback index


func msaa_index() -> int:
	return clampi(msaa_level, 0, 3)


func scale_3d_index() -> int:
	for i in SCALE_3D_VALUES.size():
		if is_equal_approx(SCALE_3D_VALUES[i], scaling_3d):
			return i
	return 2


func max_fps_index() -> int:
	for i in MAX_FPS_VALUES.size():
		if MAX_FPS_VALUES[i] == max_fps:
			return i
	return 0


## Screen-space look delta: same feel at any resolution / monitor size.
func mouse_look_delta(relative: Vector2) -> Vector2:
	var viewport := get_viewport()
	var height := 1080.0
	if viewport:
		height = maxf(viewport.get_visible_rect().size.y, 1.0)
	var sens := float(mouse_sensitivity_level)
	return relative / height * MOUSE_LOOK_BASE * sens


func _apply_window_resolution(size: Vector2i, force_windowed: bool) -> void:
	var mode := DisplayServer.window_get_mode()
	if force_windowed or mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	_center_window(size)


func _center_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var pos := screen_pos + ((screen_size - size) / 2)
	DisplayServer.window_set_position(pos)


func _apply_msaa() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.msaa_2d = msaa_level as Viewport.MSAA
	vp.msaa_3d = msaa_level as Viewport.MSAA


func _apply_scaling_3d() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.scaling_3d_scale = scaling_3d


func _apply_vsync() -> void:
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _apply_max_fps() -> void:
	Engine.max_fps = max_fps


func _apply_mouse_sensitivity() -> void:
	gl_PlayerState.mouse_sensitivity = float(mouse_sensitivity_level)


func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, _percent_to_db(master_volume_percent, _master_baseline_db))


func _apply_music_volume() -> void:
	var idx := AudioServer.get_bus_index("MusicBus")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, _percent_to_db(music_volume_percent, _music_baseline_db))


func _percent_to_db(percent: float, baseline_db: float) -> float:
	if percent <= 0.0:
		return -80.0
	return baseline_db + linear_to_db(percent / 100.0)
