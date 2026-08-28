extends Control
class_name DifficultyBadge

signal pressed

@export_group("Copy")
@export var title := "[wave]BEGINNER":
	set(value):
		title = value
		_apply_visuals()
@export var subtitle := "3 STAGES":
	set(value):
		subtitle = value
		_apply_visuals()

@export_group("Art")
@export var icon: Texture2D:
	set(value):
		icon = value
		_apply_visuals()
@export_range(0, 3, 1) var icon_count := 1:
	set(value):
		icon_count = value
		_apply_visuals()
@export var lock_icon: Texture2D:
	set(value):
		lock_icon = value
		_apply_visuals()
@export var circle_texture: Texture2D:
	set(value):
		circle_texture = value
		_apply_visuals()

@export_group("Colors")
@export var circle_self_modulate := Color("94010A"):
	set(value):
		circle_self_modulate = value
		_apply_visuals()
@export var circle2_self_modulate := Color("5E544B"):
	set(value):
		circle2_self_modulate = value
		_apply_visuals()
@export var circle3_modulate := Color("5E544B"):
	set(value):
		circle3_modulate = value
		_apply_visuals()
@export var top_color := Color("C5D4A4"):
	set(value):
		top_color = value
		_apply_visuals()
@export var banner_color := Color("3E6A32"):
	set(value):
		banner_color = value
		_apply_visuals()
@export var icon_modulate := Color("2F4F28"):
	set(value):
		icon_modulate = value
		_apply_visuals()
@export var title_color := Color.WHITE:
	set(value):
		title_color = value
		_apply_visuals()
@export var subtitle_color := Color.WHITE:
	set(value):
		subtitle_color = value
		_apply_visuals()

@export_group("Play")
## Empty = this badge does nothing when clicked.
@export var travel_place := ""
## "advanced" / "expert" / "mystery" — empty means always playable (Beginner).
@export var unlock_key := ""
@export var locked := false:
	set(value):
		locked = value
		_apply_visuals()

@export_group("Locked Flip")
@export_multiline var locked_back_text := "[pulse freq=8 color=#FFFFFF90]NOT\nUNLOCKED YET":
	set(value):
		locked_back_text = value
		_apply_back_text()
@export var locked_hold_sec := 3.0
@export var locked_flip_half_time := 0.1
@export var locked_flip_edge_y_scale := 1.12
@export var unlocked_spin_sec := 1.5

@onready var _circle: Control = $Circle
@onready var _circle2: Control = get_node_or_null("Circle2")
@onready var _circle3: Control = get_node_or_null("Circle3")
@onready var _icon_box: HBoxContainer = get_node_or_null("HBoxContainer")
@onready var _banner: ColorRect = $Banner
@onready var _banner2: ColorRect = get_node_or_null("Banner2")
@onready var _title: RichTextLabel = $Title
@onready var _subtitle: RichTextLabel = $Subtitle
@onready var _lock: TextureRect = $LockIcon
@onready var _button: Button = $HitButton
@onready var _back_label: RichTextLabel = get_node_or_null("BackLabel")
@onready var _particles: CanvasItem = get_node_or_null("BackgroundParticles")
@onready var _focus_enter_sfx: AudioStreamPlayer = get_node_or_null("SFX/focus_enter_sfx")
@onready var _focus_exit_sfx: AudioStreamPlayer = get_node_or_null("SFX/focus_exit")
@onready var _flip_sfx: AudioStreamPlayer = get_node_or_null("SFX/flip_sfx")
@onready var _shing_sfx: AudioStreamPlayer = get_node_or_null("SFX/shing_sfx")
@onready var _travel_sfx: AudioStreamPlayer = get_node_or_null("SFX/travel_sfx")

var _wiggle: Tween
var _flip_tween: Tween
var _flip_token := 0
var _showing_back := false
var _flipping := false
var _selecting := false


func _ready() -> void:
	add_to_group("difficulty_badge")
	if _button:
		_button.pressed.connect(_on_hit)
		_button.mouse_entered.connect(_on_hover.bind(true))
		_button.mouse_exited.connect(_on_hover.bind(false))
		_button.focus_entered.connect(_on_hover.bind(true))
		_button.focus_exited.connect(_on_hover.bind(false))
	refresh_unlock_state()
	_apply_visuals()
	_apply_back_text()
	_set_locked_face(false)


func refresh_unlock_state() -> void:
	if unlock_key.strip_edges().is_empty():
		return
	if gl_DataSet and gl_DataSet.has_method("is_difficulty_unlocked"):
		locked = not gl_DataSet.is_difficulty_unlocked(unlock_key)


func _apply_back_text() -> void:
	if _back_label == null:
		return
	var copy := locked_back_text.strip_edges()
	if copy.is_empty():
		copy = "[pulse freq=8 color=#FFFFFF90]NOT\nUNLOCKED YET"
	_back_label.text = "[center]%s" % copy


func _apply_visuals() -> void:
	if not is_node_ready():
		return
	if _circle:
		if _circle is TextureRect and circle_texture:
			(_circle as TextureRect).texture = circle_texture
		_circle.self_modulate = circle_self_modulate
	if _circle2:
		_circle2.self_modulate = circle2_self_modulate
	if _circle3:
		_circle3.modulate = circle3_modulate
	_apply_icons()
	if _banner:
		_banner.color = banner_color
	if _title:
		_title.text = "[wave]" + title
		_title.add_theme_color_override("default_color", title_color)
	if _subtitle:
		#_subtitle.text = "[pulse]" + subtitle + "[font_size=28] STAGES"
		_subtitle.text = "[pulse freq=8 color=#FFFFFF90]" + subtitle + "[font_size=28] STAGES[/font_size][/pulse]"
		_subtitle.add_theme_color_override("default_color", subtitle_color)
	if _lock:
		if lock_icon:
			_lock.texture = lock_icon
		_lock.visible = locked and not _showing_back
	if _button:
		## Locked Advanced/Expert/Mystery stay clickable so they can flip.
		if not unlock_key.strip_edges().is_empty():
			_button.disabled = false
		else:
			_button.disabled = locked or travel_place.strip_edges().is_empty()
	#modulate.a = 0.62 if locked else 1.0
	modulate.a = 1.0


func _icon_rects() -> Array[TextureRect]:
	var rects: Array[TextureRect] = []
	if _icon_box == null:
		return rects
	for child in _icon_box.get_children():
		if child is TextureRect:
			rects.append(child)
	return rects


func _apply_icons() -> void:
	var rects := _icon_rects()
	var show_n := 0 if icon == null else clampi(icon_count, 0, rects.size())
	if _icon_box:
		_icon_box.visible = show_n > 0
	for i in rects.size():
		rects[i].texture = icon
		rects[i].modulate = icon_modulate
		rects[i].visible = i < show_n

func _on_hit() -> void:
	if _selecting:
		return
	if _is_content_locked():
		play_locked_flip()
		return
	if travel_place.strip_edges().is_empty():
		return
	get_tree().call_group("difficulty_badge", "lock_out_selection")
	await play_unlocked_spin()


func lock_out_selection() -> void:
	_selecting = true
	_abort_locked_flip()
	if _button:
		_button.disabled = true


func fade_away_for_selection(selected: Node) -> void:
	if selected == self:
		return
	_abort_locked_flip()
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	if _button:
		_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale = Vector2.ONE
	hide()
	modulate.a = 0.0


func play_unlocked_spin() -> void:
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	z_index = 24
	rotation_degrees = 0.0
	scale = Vector2.ONE
	_set_face(false)
	_play_sfx(_shing_sfx)
	get_tree().call_group("difficulty_badge", "fade_away_for_selection", self)
	await _center_horizontally()
	if not is_inside_tree():
		return
	await _blink_visible(maxf(unlocked_spin_sec, 0.05))
	if not is_inside_tree():
		return
	visible = true
	show()
	_play_sfx(_travel_sfx)
	pressed.emit()


func _abort_locked_flip() -> void:
	_flip_token += 1
	_flipping = false
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = null


func _center_horizontally() -> void:
	var gp := global_position
	top_level = true
	global_position = gp
	var dest := gp
	dest.x += _selection_center().x - get_global_rect().get_center().x
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.set_parallel(true)
	_flip_tween.tween_property(self, "global_position", dest, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _flip_tween.finished


func _selection_center() -> Vector2:
	var overlay := get_tree().get_first_node_in_group("difficulty_select") as Control
	if overlay:
		return overlay.get_global_rect().get_center()
	return get_viewport().get_visible_rect().get_center()


func _blink_visible(duration: float) -> void:
	var elapsed := 0.0
	var shown := true
	while elapsed < duration and is_inside_tree():
		shown = not shown
		visible = shown
		var step := 0.08
		await get_tree().create_timer(step, true).timeout
		elapsed += step
	if is_inside_tree():
		visible = true
		show()


func _is_content_locked() -> bool:
	if unlock_key.strip_edges().is_empty():
		return false
	if gl_DataSet and gl_DataSet.has_method("is_difficulty_unlocked"):
		return not gl_DataSet.is_difficulty_unlocked(unlock_key)
	return locked


func play_locked_flip() -> void:
	_flip_token += 1
	var token := _flip_token
	_flipping = true
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	scale = Vector2.ONE
	if _showing_back:
		_set_locked_face(false)
	await _animate_face_flip(true)
	if token != _flip_token:
		return
	await get_tree().create_timer(maxf(locked_hold_sec, 0.05), true).timeout
	if token != _flip_token:
		return
	await _animate_face_flip(false)
	if token != _flip_token:
		return
	_flipping = false
	if _button and _button.is_hovered():
		_on_hover(true)


func _animate_face_flip(to_back: bool, play_flip_sfx: bool = true, blank_back: bool = false) -> void:
	var rest := Vector2.ONE
	var edge := Vector2(0.001, rest.y * locked_flip_edge_y_scale)
	var half := maxf(locked_flip_half_time, 0.01)
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	if play_flip_sfx:
		_play_sfx(_flip_sfx)
	_flip_tween = create_tween()
	var tween := _flip_tween
	tween.tween_property(self, "scale", edge, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_set_face.bind(to_back, blank_back))
	tween.tween_property(self, "scale", rest, half)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	while tween.is_valid() and tween.is_running() and is_inside_tree():
		await get_tree().process_frame


func _set_locked_face(back: bool) -> void:
	_set_face(back, false)


func _set_face(back: bool, blank_back: bool = false) -> void:
	_showing_back = back
	if _back_label:
		_back_label.visible = back and not blank_back
		if _back_label.visible:
			_apply_back_text()
	if _particles:
		_particles.visible = not back
	if back:
		for node in [_banner, _banner2, _title, _subtitle, _icon_box, _lock]:
			if node:
				node.visible = false
		return
	for node in [_banner, _banner2, _title, _subtitle]:
		if node:
			node.visible = true
	_apply_visuals()


func _on_hover(inside: bool) -> void:
	if _flipping or _selecting or not is_inside_tree():
		return
	if inside:
		_play_sfx(_focus_enter_sfx)
	else:
		_play_sfx(_focus_exit_sfx)
	if _wiggle:
		_wiggle.kill()
	_wiggle = create_tween()
	_wiggle.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := Vector2.ONE * (1.06 if inside else 1.0)
	_wiggle.tween_property(self, "scale", target, 0.12)


func _play_sfx(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.play()
