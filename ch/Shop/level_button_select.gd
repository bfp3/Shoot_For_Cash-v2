extends Button

enum State {
	LOCKED,
	## Never entered — name only, standard colours.
	FRESH,
	## Player has entered — show current round progress.
	IN_PROGRESS,
	COMPLETE,
}

var current_state : State = State.FRESH

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer

var interaction_tween: Tween

@onready var orig_scale := self.scale

@onready var level_name_label: RichTextLabel = $level_name_label
@onready var round_progress_label: RichTextLabel = %RoundProgressLabel
@onready var cash_earned_label: RichTextLabel = get_node_or_null("%CashEarnedLabel") as RichTextLabel
@export var level_name := 'Locked':
	set(value):
		level_name = value
		if is_node_ready():
			_apply_level_preview()
			_apply_font_mode()

@export var level_locked := true
@export var main_control : Control
## Boss / single-round buttons can turn this off.
@export var show_round_count := true

@export_group("Font Mode")
## When true, keep the scene's dark brown font colours. When false, use light_mode_font_modulate.
@export var dark_mode := true:
	set(value):
		dark_mode = value
		if is_node_ready():
			_apply_font_mode()
## Used for level name + round progress when dark_mode is off.
@export var light_mode_font_modulate := Color.WHITE:
	set(value):
		light_mode_font_modulate = value
		if is_node_ready() and not dark_mode:
			_apply_font_mode()

@export_group("Preview Image")
## Desaturate preview textures in-engine (no need to reimport gray PNGs).
@export var preview_grayscale := true:
	set(value):
		preview_grayscale = value
		if is_node_ready():
			_apply_preview_grayscale()
@export_range(0.0, 1.0, 0.01) var preview_grayscale_amount := 1.0:
	set(value):
		preview_grayscale_amount = value
		if is_node_ready():
			_apply_preview_grayscale()

var round_manager : RoundManager = null
var _dark_level_name_modulate := Color(0.36862746, 0.32941177, 0.29411766, 1)
var _dark_round_progress_modulate := Color(0.36862746, 0.32941177, 0.29411766, 1)
var _active_preview: CanvasItem = null
var _grayscale_shader: Shader = preload("res://ch/Shop/level_preview_grayscale.gdshader")

const _PREVIEW_NODE_NAMES := {
	"moss": "MossPreview",
	"redd": "ReddPreview",
	"noir": "NoirPreview",
	"glory": "GloryPreview",
	"vesper": "VesperPreview",
	"jetz": "JetzPreview",
}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)

	if level_name_label:
		_dark_level_name_modulate = level_name_label.modulate
	if round_progress_label:
		_dark_round_progress_modulate = round_progress_label.modulate

	_apply_level_preview()
	_apply_preview_grayscale()
	_apply_font_mode()

	if level_locked:
		set_locked_visuals()
	else:
		refresh_map_progress()
	## Re-apply after unlock refresh so materials stick on map instances.
	call_deferred("_apply_preview_grayscale")

	self.pressed.connect(_on_level_button_pressed)
	round_manager = get_tree().get_first_node_in_group('round_manager')

	if disabled:
		modulate = Color("ababab59")
		if level_name_label:
			level_name_label.modulate = Color("1f1f1fff")


## Right-click: force-complete this place for stamp testing (Godot editor builds only).
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not OS.has_feature("editor"):
			return
		var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())
		if place.is_empty() or place == gl_DataSet.get_start_place_name():
			return
		gl_PlayerState.mark_place_completed(place)
		await mark_completed(true)
		if main_control and main_control.has_method("notify_level_cleared"):
			main_control.notify_level_cleared()
		accept_event()


func set_locked_visuals() -> void:
	current_state = State.LOCKED
	if level_name_label:
		level_name_label.text = ""
	_set_progress_hud_visible(false)
	_hide_completion_stamp()
	_apply_level_preview()


func set_unlocked_visuals() -> void:
	level_locked = false
	disabled = false
	modulate = Color.WHITE
	if level_name_label:
		level_name_label.text = "[wave]" + level_name.to_upper()
	_apply_level_preview()
	_apply_font_mode()
	refresh_map_progress()


## Show only the preview card that matches this button's level.
func _apply_level_preview() -> void:
	var place := String(level_name).to_lower().strip_edges()
	if gl_DataSet:
		place = gl_DataSet.resolve_place_name(place)
	var target_name := String(_PREVIEW_NODE_NAMES.get(place, ""))
	_active_preview = null

	for child in get_children():
		if not (child is CanvasItem):
			continue
		var child_name := String(child.name)
		if not child_name.ends_with("Preview"):
			continue
		var show_it := (not level_locked) and (child_name == target_name)
		(child as CanvasItem).visible = show_it
		if show_it:
			_active_preview = child as CanvasItem

	_apply_preview_grayscale()


func _apply_preview_grayscale() -> void:
	for child in get_children():
		if not (child is TextureRect):
			continue
		if not String(child.name).ends_with("Preview"):
			continue
		var rect := child as TextureRect
		if not preview_grayscale or preview_grayscale_amount <= 0.0:
			rect.material = null
			continue
		## Always use a unique material instance so parameter edits stick.
		var mat := ShaderMaterial.new()
		mat.shader = _grayscale_shader
		mat.set_shader_parameter("amount", clampf(preview_grayscale_amount, 0.0, 1.0))
		rect.material = mat


func _apply_font_mode() -> void:
	var col := _dark_level_name_modulate if dark_mode else light_mode_font_modulate
	var round_col := _dark_round_progress_modulate if dark_mode else light_mode_font_modulate
	if level_name_label:
		level_name_label.modulate = col
	if round_progress_label:
		round_progress_label.modulate = round_col


## Round counter, cash earned on this island, and completion stamp.
func refresh_map_progress() -> void:
	if level_locked or current_state == State.LOCKED:
		_set_progress_hud_visible(false)
		_hide_completion_stamp()
		_apply_level_preview()
		return

	var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())
	var completed := gl_PlayerState.is_place_completed(place)
	var entry := gl_PlayerState.get_level_progress_entry(place)
	var has_entered := completed or not entry.is_empty() or bool(entry.get("entered", false))
	if level_name_label:
		level_name_label.text = "[wave]" + level_name.to_upper()
	_apply_level_preview()
	_apply_font_mode()

	if completed:
		current_state = State.COMPLETE
		## Finished levels: hide round counter; stamp shows CLEAR!
		_set_progress_hud_visible(false)
		if round_progress_label:
			round_progress_label.visible = false
		_refresh_completion_stamp(false)
		_set_completed_gui()
		return

	_clear_completed_gui()
	if has_entered:
		current_state = State.IN_PROGRESS
		_set_progress_hud_visible(show_round_count)
		_apply_round_progress_text(place, entry)
		_hide_completion_stamp()
		return

	current_state = State.FRESH
	_set_progress_hud_visible(false)
	_hide_completion_stamp()


func _apply_round_progress_text(place: String, entry: Dictionary) -> void:
	if round_progress_label == null or not show_round_count:
		if round_progress_label:
			round_progress_label.visible = false
		return

	var total := _total_rounds_for_place(place)
	var sequence_index := int(entry.get("sequence_index", 0))
	## Round the player is up to (1-based).
	var current_round := clampi(sequence_index + 1, 1, maxi(total, 1))
	round_progress_label.text = "ROUND: %d" % current_round
	round_progress_label.visible = true
	_apply_font_mode()


func _total_rounds_for_place(place: String) -> int:
	place = gl_DataSet.resolve_place_name(place)
	var file_path := "res://sc/island-shipper.txt"
	if Parser.has_method("count_rounds_in_file"):
		var from_file := Parser.count_rounds_in_file(file_path, place)
		if from_file > 0:
			return from_file
	## Fallback if the range isn't in the shipper file yet.
	var total := int(gl_DataSet.get_value("map_rounds_per_island", 0))
	return total if total > 0 else 12


func _set_progress_hud_visible(_is_visible: bool) -> void:
	if round_progress_label:
		round_progress_label.visible = _is_visible and show_round_count
	if cash_earned_label:
		cash_earned_label.visible = _is_visible


func mark_completed(animate: bool = true) -> void:
	current_state = State.COMPLETE
	level_locked = false
	_set_completed_gui()
	await _refresh_completion_stamp(animate)
	if main_control and main_control.has_method("notify_level_cleared"):
		main_control.notify_level_cleared()


## Pre-stamp look after a range clear: keep the unfinished card until the ceremony.
func prepare_clear_ceremony_visuals() -> void:
	level_locked = false
	disabled = true
	current_state = State.IN_PROGRESS
	_clear_completed_gui()
	_hide_completion_stamp()
	_set_progress_hud_visible(show_round_count)
	var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())
	var entry := gl_PlayerState.get_level_progress_entry(place)
	_apply_round_progress_text(place, entry)
	_apply_level_preview()
	_apply_font_mode()


func _hide_completion_stamp() -> void:
	var stamp_root := get_node_or_null("100_percent") as Control
	if stamp_root:
		stamp_root.visible = false
		stamp_root.modulate.a = 0.0


func _refresh_completion_stamp(animate: bool) -> void:
	var stamp_root := get_node_or_null("100_percent") as Control
	if stamp_root == null:
		return
	var stamp_label := stamp_root.get_node_or_null("RichTextLabel") as Control
	var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())
	var completed := gl_PlayerState.is_place_completed(place) or current_state == State.COMPLETE
	if not completed:
		_hide_completion_stamp()
		return

	current_state = State.COMPLETE
	_set_completed_gui()
	stamp_root.visible = true
	if stamp_label is RichTextLabel:
		(stamp_label as RichTextLabel).text = "[wave]CLEAR"
	if not animate:
		stamp_root.modulate.a = 1.0
		if stamp_label:
			stamp_label.scale = Vector2.ONE
		return

	stamp_root.modulate.a = 0.0
	if stamp_label:
		stamp_label.scale = Vector2.ONE * 3.0
	var stamp_sfx := $purchase as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, 0.2)
	if stamp_label:
		tween.parallel().tween_property(stamp_label, "scale", Vector2.ONE, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	tween.tween_interval(0.35)
	await tween.finished


func _on_level_button_pressed() -> void:
	if level_locked or current_state == State.LOCKED:
		return

	var progress_bar := $TextureProgressBar as Range
	if progress_bar:
		progress_bar.value = 0.0

	var level_name_lower_case: String = level_name.to_lower()
	if main_control and main_control.has_method('select_level'):
		await main_control.select_level(level_name_lower_case, progress_bar)
	elif round_manager:
		var place := gl_DataSet.resolve_place_name(level_name_lower_case)
		if gl_DataSet.has_place(place) and place != gl_DataSet.get_start_place_name():
			await round_manager.travel_to_level(place, true, progress_bar)
		else:
			print('other button pressed: ', level_name_lower_case)

	if progress_bar:
		progress_bar.value = 0.0


func _on_pressed() -> void:
	if pressed_sfx:
		pressed_sfx.play()

	if interaction_tween:
		interaction_tween.kill()

	var original_scale := scale
	interaction_tween = create_tween()
	interaction_tween.set_trans(Tween.TRANS_SINE)
	interaction_tween.set_ease(Tween.EASE_OUT)
	interaction_tween.tween_property(self, "scale", original_scale * 0.85, 0.06)
	interaction_tween.tween_property(self, "scale", original_scale, 0.08)
	await interaction_tween.finished


func fill_progress_bar() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property($TextureProgressBar, "value", 100.0, 0.15)
	await tween.finished


func _on_focus_entered() -> void:
	if current_state == State.LOCKED:
		return
	if focus_enter_sfx:
		focus_enter_sfx.play()
	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 10))


func _on_focus_exited() -> void:
	if current_state == State.LOCKED:
		return
	if focus_exit_sfx:
		focus_exit_sfx.play()
	z_index = 0
	_play_wiggle(orig_scale.x)


func _play_wiggle(target_scale: float) -> void:
	if interaction_tween:
		interaction_tween.kill()
	interaction_tween = create_tween()
	interaction_tween.set_trans(Tween.TRANS_SINE)
	interaction_tween.set_ease(Tween.EASE_IN_OUT)
	interaction_tween.tween_property(
		self,
		"scale",
		Vector2(target_scale, target_scale),
		0.08
	)


func _preview_overlay_panels() -> Array[Control]:
	var out: Array[Control] = []
	var root: Node = _active_preview if _active_preview else self
	for child in root.get_children():
		if child is Panel:
			out.append(child as Control)
	## Legacy root panels (if any remain).
	for _name in ["Panel", "Panel2"]:
		var n := get_node_or_null(_name) as Control
		if n and not out.has(n):
			out.append(n)
	return out


func _set_completed_gui() -> void:
	for panel in _preview_overlay_panels():
		panel.modulate = Color.WHITE
		panel.theme_type_variation = "RedPanel"


func _clear_completed_gui() -> void:
	for panel in _preview_overlay_panels():
		panel.theme_type_variation = &""
