extends Control

## Full Options panel — graphics + mouse. Wired from pause_and_exit_menu.

signal back_pressed
signal open_resolution_confirm

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var msaa_option: OptionButton = %MsaaOption
@onready var scale_3d_option: OptionButton = %Scale3DOption
@onready var vsync_option: OptionButton = %VsyncOption
@onready var max_fps_option: OptionButton = %MaxFpsOption
@onready var sens_value_label: Label = %SensValueLabel
@onready var sens_down: Button = %SensDown
@onready var sens_up: Button = %SensUp


func _ready() -> void:
	_populate_options()
	_sync_from_settings()
	_make_popups_work_while_paused()
	resolution_option.item_selected.connect(_on_resolution_selected)
	msaa_option.item_selected.connect(_on_msaa_selected)
	scale_3d_option.item_selected.connect(_on_scale_3d_selected)
	vsync_option.item_selected.connect(_on_vsync_selected)
	max_fps_option.item_selected.connect(_on_max_fps_selected)
	sens_down.pressed.connect(_on_sens_down)
	sens_up.pressed.connect(_on_sens_up)
	GameSettings.settings_changed.connect(_sync_from_settings)


func _make_popups_work_while_paused() -> void:
	for option in [resolution_option, msaa_option, scale_3d_option, vsync_option, max_fps_option]:
		if option:
			option.get_popup().process_mode = Node.PROCESS_MODE_ALWAYS


func refresh() -> void:
	_sync_from_settings()


func _populate_options() -> void:
	resolution_option.clear()
	for res in GameSettings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])

	msaa_option.clear()
	for label in GameSettings.MSAA_LABELS:
		msaa_option.add_item(label)

	scale_3d_option.clear()
	for label in GameSettings.SCALE_3D_LABELS:
		scale_3d_option.add_item(label)

	vsync_option.clear()
	vsync_option.add_item("Off")
	vsync_option.add_item("On")

	max_fps_option.clear()
	for label in GameSettings.MAX_FPS_LABELS:
		max_fps_option.add_item(label)


func _sync_from_settings() -> void:
	resolution_option.set_block_signals(true)
	msaa_option.set_block_signals(true)
	scale_3d_option.set_block_signals(true)
	vsync_option.set_block_signals(true)
	max_fps_option.set_block_signals(true)

	resolution_option.select(GameSettings.resolution_index())
	msaa_option.select(GameSettings.msaa_index())
	scale_3d_option.select(GameSettings.scale_3d_index())
	vsync_option.select(1 if GameSettings.vsync_enabled else 0)
	max_fps_option.select(GameSettings.max_fps_index())
	sens_value_label.text = str(GameSettings.mouse_sensitivity_level)

	resolution_option.set_block_signals(false)
	msaa_option.set_block_signals(false)
	scale_3d_option.set_block_signals(false)
	vsync_option.set_block_signals(false)
	max_fps_option.set_block_signals(false)


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= GameSettings.RESOLUTIONS.size():
		return
	GameSettings.try_resolution(GameSettings.RESOLUTIONS[index])
	if GameSettings.is_resolution_pending():
		open_resolution_confirm.emit()


func _on_msaa_selected(index: int) -> void:
	GameSettings.apply_msaa(index)


func _on_scale_3d_selected(index: int) -> void:
	if index < 0 or index >= GameSettings.SCALE_3D_VALUES.size():
		return
	GameSettings.apply_scaling_3d(GameSettings.SCALE_3D_VALUES[index])


func _on_vsync_selected(index: int) -> void:
	GameSettings.apply_vsync(index == 1)


func _on_max_fps_selected(index: int) -> void:
	if index < 0 or index >= GameSettings.MAX_FPS_VALUES.size():
		return
	GameSettings.apply_max_fps(GameSettings.MAX_FPS_VALUES[index])


func _on_sens_down() -> void:
	GameSettings.bump_mouse_sensitivity(-1)


func _on_sens_up() -> void:
	GameSettings.bump_mouse_sensitivity(1)


func _on_back_pressed() -> void:
	back_pressed.emit()
