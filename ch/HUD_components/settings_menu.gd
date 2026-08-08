extends Control

## Full Options panel — graphics + mouse. Wired from pause_and_exit_menu.

signal back_pressed
signal open_resolution_confirm

const DROPDOWN_POPUP_FONT_SIZE := 50

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var msaa_option: OptionButton = %MsaaOption
@onready var scale_3d_option: OptionButton = %Scale3DOption
@onready var vsync_option: OptionButton = %VsyncOption
@onready var max_fps_option: OptionButton = %MaxFpsOption
@onready var sens_value_label: RichTextLabel = %SensValueLabel
@onready var sens_down: Button = %SensDown
@onready var sens_up: Button = %SensUp
@onready var master_volume_dial: VolumeDial = %MasterVolumeDial
@onready var music_volume_dial: VolumeDial = %MusicVolumeDial


func _ready() -> void:
	_populate_options()
	_setup_volume_dials()
	_sync_from_settings()
	_make_popups_work_while_paused()
	_wire_focus_neighbors()
	resolution_option.item_selected.connect(_on_resolution_selected)
	msaa_option.item_selected.connect(_on_msaa_selected)
	scale_3d_option.item_selected.connect(_on_scale_3d_selected)
	vsync_option.item_selected.connect(_on_vsync_selected)
	max_fps_option.item_selected.connect(_on_max_fps_selected)
	sens_down.pressed.connect(_on_sens_down)
	sens_up.pressed.connect(_on_sens_up)
	master_volume_dial.value_changed.connect(_on_master_volume_changed)
	music_volume_dial.value_changed.connect(_on_music_volume_changed)
	GameSettings.settings_changed.connect(_sync_from_settings)


func _setup_volume_dials() -> void:
	for dial in [master_volume_dial, music_volume_dial]:
		if dial == null:
			continue
		dial.process_mode = Node.PROCESS_MODE_ALWAYS
		dial.min_value = 0.0
		dial.max_value = 100.0
		dial.step = 1.0
		if not dial.edit_started.is_connected(_on_volume_edit_started):
			dial.edit_started.connect(_on_volume_edit_started)
		if not dial.edit_ended.is_connected(_on_volume_edit_ended):
			dial.edit_ended.connect(_on_volume_edit_ended)


func is_volume_editing() -> bool:
	return (
		(master_volume_dial != null and master_volume_dial.is_editing())
		or (music_volume_dial != null and music_volume_dial.is_editing())
	)


func end_volume_edit() -> void:
	if master_volume_dial and master_volume_dial.is_editing():
		master_volume_dial.end_edit()
	if music_volume_dial and music_volume_dial.is_editing():
		music_volume_dial.end_edit()


func _on_volume_edit_started() -> void:
	# Close the other dial if somehow both try to edit.
	var active := master_volume_dial if master_volume_dial and master_volume_dial.is_editing() else music_volume_dial
	for dial in [master_volume_dial, music_volume_dial]:
		if dial and dial != active and dial.is_editing():
			dial.end_edit()


func _on_volume_edit_ended() -> void:
	pass


func _wire_focus_neighbors() -> void:
	# Left column flows top→bottom, then across to volumes / sensitivity / back.
	var left := [resolution_option, msaa_option, scale_3d_option, vsync_option, max_fps_option]
	for i in left.size():
		var cur: Control = left[i]
		if i > 0:
			cur.focus_neighbor_top = left[i - 1].get_path()
		if i < left.size() - 1:
			cur.focus_neighbor_bottom = left[i + 1].get_path()
		cur.focus_neighbor_right = master_volume_dial.get_path()

	master_volume_dial.focus_neighbor_left = resolution_option.get_path()
	master_volume_dial.focus_neighbor_right = music_volume_dial.get_path()
	master_volume_dial.focus_neighbor_bottom = sens_down.get_path()
	music_volume_dial.focus_neighbor_left = master_volume_dial.get_path()
	music_volume_dial.focus_neighbor_bottom = sens_up.get_path()

	sens_down.focus_neighbor_top = master_volume_dial.get_path()
	sens_down.focus_neighbor_right = sens_up.get_path()
	sens_up.focus_neighbor_top = music_volume_dial.get_path()
	sens_up.focus_neighbor_left = sens_down.get_path()

	max_fps_option.focus_neighbor_bottom = resolution_option.get_path()
	var back := get_node_or_null("Center/Panel/Margin/RootVBox/BackButton") as Control
	if back == null:
		# Path relative to Settings_menu root in pause scene.
		back = find_child("BackButton", true, false) as Control
	if back:
		sens_down.focus_neighbor_bottom = back.get_path()
		sens_up.focus_neighbor_bottom = back.get_path()
		back.focus_neighbor_top = sens_down.get_path()
		back.focus_neighbor_left = max_fps_option.get_path()
		max_fps_option.focus_neighbor_bottom = back.get_path()


func _make_popups_work_while_paused() -> void:
	for option in [resolution_option, msaa_option, scale_3d_option, vsync_option, max_fps_option]:
		if option == null:
			continue
		var popup = option.get_popup()
		popup.process_mode = Node.PROCESS_MODE_ALWAYS
		# Dropdown *list* item size (not the closed OptionButton label).
		popup.add_theme_font_size_override("font_size", DROPDOWN_POPUP_FONT_SIZE)


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
	sens_value_label.text = GameSettings.sensitivity_display_text()
	master_volume_dial.set_value_no_signal(GameSettings.master_volume_percent)
	music_volume_dial.set_value_no_signal(GameSettings.music_volume_percent)

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


func _on_master_volume_changed(value: float) -> void:
	GameSettings.apply_master_volume(value)
	master_volume_dial.set_value_no_signal(GameSettings.master_volume_percent)


func _on_music_volume_changed(value: float) -> void:
	GameSettings.apply_music_volume(value)
	music_volume_dial.set_value_no_signal(GameSettings.music_volume_percent)


func _on_back_pressed() -> void:
	if is_volume_editing():
		end_volume_edit()
		return
	back_pressed.emit()
