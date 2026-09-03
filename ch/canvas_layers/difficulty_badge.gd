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
## First letter at the Title default size (54), remaining letters at 34/54 of that size.
@export var camel_case := true:
	set(value):
		camel_case = value
		_apply_visuals()
## Authored proportion: remaining letters vs default Title size (`[wave]B[font_size=34]EGINNER`).
const CAMEL_CASE_REST_RATIO := 34.0 / 54.0

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
@export var banner3_color := Color(0.22512, 0.28, 0.1428, 1):
	set(value):
		banner3_color = value
		_apply_visuals()
@export var coat_arms_modulate := Color.TRANSPARENT:
	set(value):
		coat_arms_modulate = value
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

@export_group("Scheme")
enum ColorScheme { BEGINNER, ADVANCED, EXPERT }
## Picks the Beginner / Advanced / Expert colour set. Default matches the title difficulty badge.
@export var color_scheme: ColorScheme = ColorScheme.BEGINNER:
	set(value):
		color_scheme = value
		if is_node_ready():
			_apply_scheme_colors()
## Hide the star icons (used by numbered level-select badges).
@export var hide_icons := false:
	set(value):
		hide_icons = value
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
## Header difficulty badge on level select — not a playable level.
@export var is_header := false
## Boss range (`boss-` prefix). Red ring + emblem on top.
@export var is_boss := false
## Hide the "N STAGES" subtitle (numbered level badges).
@export var hide_subtitle := false
## Hide Banner / Banner2 / Banner3 (unlocked numbered level badges).
@export var hide_banners := false:
	set(value):
		hide_banners = value
		_apply_visuals()
## Later bosses get side plates (Circle2 scaled out).
@export var boss_armored := false
## Beginner / Advanced / Expert on the title screen — opens that difficulty's level grid instead of travelling.
@export var selects_difficulty := false
## When locked, stay off the row entirely (Mystery) instead of showing a dulled / flip badge.
@export var hide_when_locked := false
## Level-select numbered badges: locked click blinks the lock icon instead of flipping to copy.
@export var blink_lock_instead_of_flip := false
## Skip the center / blink travel animation and emit `pressed` immediately.
@export var skip_select_animation := false

@export_group("Locked Flip")
@export_multiline var locked_back_text := "[pulse freq=8 color=#FFFFFF90]NOT\nUNLOCKED YET":
	set(value):
		locked_back_text = value
		_apply_back_text()
@export var locked_hold_sec := 3.0
@export var locked_flip_half_time := 0.1
@export var locked_flip_edge_y_scale := 1.12
@export var unlocked_spin_sec := 1.5
@export var locked_spin_return_sec := 0.25

@onready var _circle: Control = $Circle
@onready var _circle2: Control = get_node_or_null("Circle2")
@onready var _circle3: Control = get_node_or_null("Circle3")
@onready var _icon_box: HBoxContainer = get_node_or_null("HBoxContainer")
@onready var _banner: ColorRect = $Banner
@onready var _banner2: ColorRect = get_node_or_null("Banner2")
@onready var _banner3: ColorRect = get_node_or_null("Banner3")
@onready var _coat_arms: Control = get_node_or_null("CoatArms")
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
	if not is_header:
		refresh_unlock_state()
	_apply_visuals()
	_apply_back_text()
	_set_locked_face(false)


func refresh_unlock_state() -> void:
	if unlock_key.strip_edges().is_empty():
		return
	var key := unlock_key.strip_edges().to_lower()
	if key.begins_with("challenge") and gl_DataSet and gl_DataSet.has_method("is_challenge_unlocked"):
		locked = not gl_DataSet.is_challenge_unlocked(key)
	elif gl_DataSet and gl_DataSet.has_method("is_difficulty_unlocked"):
		locked = not gl_DataSet.is_difficulty_unlocked(unlock_key)
	_apply_back_text()
	if hide_when_locked:
		visible = not locked


func _apply_back_text() -> void:
	if _back_label == null:
		return
	var copy := _locked_need_text()
	if copy.is_empty():
		copy = locked_back_text.strip_edges()
	if copy.is_empty():
		copy = "[pulse freq=8 color=#FFFFFF90]NOT\nUNLOCKED YET"
	_back_label.text = "[center]%s" % copy


func _locked_need_text() -> String:
	if gl_DataSet == null or not gl_DataSet.has_method("get_unlock_net_worth"):
		return ""
	var amount := int(gl_DataSet.get_unlock_net_worth(unlock_key))
	if amount <= 0:
		return ""
	var money := "$" + str(amount)
	if CommonCode and CommonCode.has_method("format_money"):
		money = String(CommonCode.format_money(amount))
	return "[pulse freq=8 color=#FFFFFF90]NEED\n%s" % money


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
	if _banner3:
		_banner3.color = banner3_color
	_apply_banner_tilt()
	if _coat_arms:
		_coat_arms.modulate = coat_arms_modulate
		_coat_arms.visible = not is_boss and coat_arms_modulate.a > 0.01 and not _showing_back
	if _title:
		_title.text = _formatted_title_bbcode(title)
		_title.add_theme_color_override("default_color", title_color)
		_title.visible = not _showing_back and not _hide_number_for_lock()
	if _subtitle:
		_subtitle.visible = not hide_subtitle and not _showing_back
		#_subtitle.text = "[pulse]" + subtitle + "[font_size=28] STAGES"
		_subtitle.text = "[pulse freq=8 color=#FFFFFF90]" + subtitle + "[font_size=28] STAGES[/font_size][/pulse]"
		_subtitle.add_theme_color_override("default_color", subtitle_color)
	if _lock:
		if lock_icon:
			_lock.texture = lock_icon
		if blink_lock_instead_of_flip:
			if locked and not is_header and not _showing_back:
				_show_lock_in_place()
			else:
				_lock.visible = false
				_lock.scale = _lock_rest_scale()
		else:
			_lock.visible = locked and not _showing_back and not is_header
	if _button:
		if is_header:
			_button.disabled = true
			_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			## Locked badges stay clickable so they can flip.
			_button.disabled = travel_place.strip_edges().is_empty() and not locked and not selects_difficulty
	if locked and not is_header:
		modulate = Color(0.52, 0.52, 0.55)
	else:
		modulate = Color.WHITE
	if hide_when_locked:
		visible = not locked
	if _circle2:
		_circle2.scale = Vector2(0.855, 0.855)


func _icon_rects() -> Array[TextureRect]:
	var rects: Array[TextureRect] = []
	if _icon_box == null:
		return rects
	for child in _icon_box.get_children():
		if child is TextureRect:
			rects.append(child)
	return rects


func _plain_title_text(raw: String) -> String:
	var text := raw.strip_edges()
	var out := ""
	var i := 0
	while i < text.length():
		if text[i] == "[":
			var close := text.find("]", i)
			if close < 0:
				out += text.substr(i)
				break
			i = close + 1
			continue
		out += text[i]
		i += 1
	return out.strip_edges()


func _formatted_title_bbcode(raw: String) -> String:
	if not camel_case:
		return "[wave]" + raw
	var plain := _plain_title_text(raw)
	if plain.is_empty():
		return ""
	if plain.length() <= 1:
		return "[wave]%s" % plain
	var default_size := 54
	if _title:
		default_size = _title.get_theme_font_size("normal_font_size")
	if default_size <= 0:
		default_size = 54
	var small := maxi(1, int(round(float(default_size) * CAMEL_CASE_REST_RATIO)))
	return "[wave]%s[font_size=%d]%s[/font_size]" % [plain.substr(0, 1), small, plain.substr(1)]


func _apply_icons() -> void:
	var rects := _icon_rects()
	var show_n := 0 if hide_icons or icon == null else clampi(icon_count, 0, rects.size())
	if _icon_box:
		_icon_box.visible = show_n > 0
	for i in rects.size():
		rects[i].texture = icon
		rects[i].modulate = icon_modulate
		rects[i].visible = i < show_n


func apply_color_scheme(stage: String) -> void:
	match stage.strip_edges().to_upper():
		"ADVANCED":
			color_scheme = ColorScheme.ADVANCED
		"EXPERT":
			color_scheme = ColorScheme.EXPERT
		_:
			color_scheme = ColorScheme.BEGINNER


func _apply_scheme_colors() -> void:
	match color_scheme:
		ColorScheme.ADVANCED:
			icon_count = 2
			circle_self_modulate = Color(0.8117647, 0.61960787, 0.35686275, 1)
			circle2_self_modulate = Color("5E544B")
			circle3_modulate = Color(0.8117647, 0.61960787, 0.35686275, 1)
			top_color = Color(0.8117647, 0.61960787, 0.35686275, 1)
			banner_color = Color(0.8117647, 0.61960787, 0.35686275, 1)
			banner3_color = Color(0.59, 0.4523333, 0.2596, 1)
			icon_modulate = Color(0.36862746, 0.32941177, 0.29411766, 1)
			title_color = Color.WHITE
		ColorScheme.EXPERT:
			icon_count = 3
			circle_self_modulate = Color(0.5803922, 0.003921569, 0.015686275, 1)
			circle2_self_modulate = Color(0.81, 0.543375, 0.1701, 1)
			circle3_modulate = Color(0.5803922, 0.003921569, 0.015686275, 1)
			top_color = Color(0.81, 0.543375, 0.1701, 1)
			banner_color = Color(0.5803922, 0.003921569, 0.015686275, 1)
			banner3_color = Color(0.4, 0.004, 0.0106, 1)
			icon_modulate = Color(0.36862746, 0.32941177, 0.29411766, 1)
			title_color = Color(0.92156863, 0.8784314, 0.84705883, 1)
		_:
			icon_count = 1
			circle_self_modulate = Color(0.76862746, 0.65882355, 0.56078434, 1)
			circle2_self_modulate = Color("5E544B")
			circle3_modulate = Color(0.8039216, 0.69803923, 0.5803922, 1)
			top_color = Color(0.5921569, 0.09019608, 0.09411765, 1)
			banner_color = Color(0.36862746, 0.32941177, 0.29411766, 1)
			banner3_color = Color(0.25, 0.22333333, 0.2, 1)
			icon_modulate = Color(0.37, 0.33053333, 0.296, 1)
			title_color = Color.WHITE


func configure_as_level(number: int, place: String, unlocked: bool, boss: bool, armored: bool = false, stage: String = "BEGINNER") -> void:
	is_header = false
	is_boss = boss
	boss_armored = armored
	hide_subtitle = true
	hide_banners = true
	hide_icons = true
	title = str(number)
	subtitle = ""
	travel_place = place
	unlock_key = ""
	locked = not unlocked
	blink_lock_instead_of_flip = true
	apply_color_scheme(stage)
	coat_arms_modulate = Color(1, 1, 1, 0)
	_apply_visuals()


func copy_look_from(other: DifficultyBadge) -> void:
	if other == null:
		return
	title = other.title
	subtitle = other.subtitle
	camel_case = other.camel_case
	icon_count = other.icon_count
	circle_self_modulate = other.circle_self_modulate
	circle2_self_modulate = other.circle2_self_modulate
	circle3_modulate = other.circle3_modulate
	top_color = other.top_color
	banner_color = other.banner_color
	banner3_color = other.banner3_color
	coat_arms_modulate = other.coat_arms_modulate
	icon_modulate = other.icon_modulate
	title_color = other.title_color
	subtitle_color = other.subtitle_color
	_apply_visuals()


func _on_hit() -> void:
	if is_header or _selecting:
		return
	if _is_content_locked():
		play_locked_flip()
		return
	if selects_difficulty:
		pressed.emit()
		return
	if travel_place.strip_edges().is_empty():
		return
	get_tree().call_group("difficulty_badge", "lock_out_selection")
	if skip_select_animation:
		pressed.emit()
		return
	await play_unlocked_spin()


func reset_selection_state() -> void:
	_selecting = false
	_abort_locked_flip()
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	_set_face(false)
	if hide_when_locked and locked:
		hide()
		modulate = Color(0.52, 0.52, 0.55)
		scale = Vector2.ONE
		rotation_degrees = 0.0
		top_level = false
		z_index = 0
		if _button:
			_button.disabled = true
			_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	visible = true
	show()
	modulate = Color.WHITE if not (locked and not is_header) else Color(0.52, 0.52, 0.55)
	scale = Vector2.ONE
	rotation_degrees = 0.0
	top_level = false
	z_index = 0
	if _button:
		_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if is_header:
			_button.disabled = true
			_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_button.disabled = travel_place.strip_edges().is_empty() and not locked and not selects_difficulty


func lock_out_selection() -> void:
	if is_header or not is_visible_in_tree():
		return
	_selecting = true
	_abort_locked_flip()
	if _button:
		_button.disabled = true


func fade_away_for_selection(selected: Node) -> void:
	if is_header or selected == self or not is_visible_in_tree():
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
	## Challenge row: move the whole row up first (badge still a child), then center.
	var challenge_row := get_parent()
	if challenge_row and challenge_row.has_method("animate_align_to_difficulty_row"):
		await challenge_row.animate_align_to_difficulty_row(0.22)
		if not is_inside_tree():
			return
	await _center_horizontally()
	if not is_inside_tree():
		return
	await _blink_visible(maxf(unlocked_spin_sec, 0.05))
	if not is_inside_tree():
		return
	_play_sfx(_travel_sfx)
	await _fade_out_selected()
	if not is_inside_tree():
		return
	pressed.emit()


func _abort_locked_flip() -> void:
	_flip_token += 1
	_flipping = false
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = null


func _center_horizontally() -> void:
	_apply_center_pivot()
	var gp := global_position
	top_level = true
	global_position = gp
	var dest := _selection_center() - pivot_offset
	## Selected badge still sat too far right of the panel centre; shift left by half its width.
	dest.x -= size.x * 0.5
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.set_parallel(true)
	_flip_tween.tween_property(self, "global_position", dest, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _flip_tween.finished


func _apply_center_pivot() -> void:
	if size.x < 1.0 or size.y < 1.0:
		size = custom_minimum_size
	pivot_offset_ratio = Vector2(0.5, 0.5)
	pivot_offset = size * 0.5


func _fade_out_selected() -> void:
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "modulate:a", 0.0, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _flip_tween.finished
	hide()


func _selection_center() -> Vector2:
	var overlay := get_tree().get_first_node_in_group("level_select") as Control
	if overlay == null or not overlay.visible:
		overlay = get_tree().get_first_node_in_group("difficulty_select") as Control
	if overlay:
		var panel := overlay.get_node_or_null("MainPanel") as Control
		if panel:
			return panel.get_global_rect().get_center()
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
	if is_header:
		return false
	if locked:
		return true
	if unlock_key.strip_edges().is_empty():
		return false
	var key := unlock_key.strip_edges().to_lower()
	if key.begins_with("challenge") and gl_DataSet and gl_DataSet.has_method("is_challenge_unlocked"):
		return not gl_DataSet.is_challenge_unlocked(key)
	if gl_DataSet and gl_DataSet.has_method("is_difficulty_unlocked"):
		return not gl_DataSet.is_difficulty_unlocked(unlock_key)
	return locked


func play_locked_flip() -> void:
	if blink_lock_instead_of_flip:
		await play_locked_icon_blink()
		return
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


func play_locked_icon_blink() -> void:
	_flip_token += 1
	var token := _flip_token
	_flipping = true
	if _wiggle:
		_wiggle.kill()
		_wiggle = null
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_apply_center_pivot()
	scale = Vector2.ONE
	rotation_degrees = 0.0
	_show_lock_in_place()
	_play_sfx(_shing_sfx)
	z_index = 24
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _flip_tween.finished
	if token != _flip_token:
		return
	await _blink_visible(0.24)
	if token != _flip_token:
		return
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.set_parallel(true)
	_flip_tween.tween_property(self, "scale", Vector2.ONE, maxf(locked_spin_return_sec, 0.05))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(self, "rotation_degrees", 0.0, maxf(locked_spin_return_sec, 0.05))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _flip_tween.finished
	if token != _flip_token:
		return
	scale = Vector2.ONE
	rotation_degrees = 0.0
	z_index = 0
	_show_lock_in_place()
	_flipping = false
	if _button and _button.is_hovered():
		_on_hover(true)


func _hide_number_for_lock() -> bool:
	return blink_lock_instead_of_flip and locked and not is_header


func _apply_banner_tilt() -> void:
	var rot := 15.0 if is_boss else 0.0
	var show_banners := not hide_banners and not is_boss and not _showing_back
	for banner in [_banner, _banner2, _banner3]:
		if banner == null:
			continue
		banner.rotation_degrees = rot
		banner.visible = show_banners


func _lock_rest_scale() -> Vector2:
	return Vector2(0.598, 0.598)


func _lock_number_scale() -> Vector2:
	return _lock_rest_scale() * 0.2


func _show_lock_in_place() -> void:
	if _lock == null:
		return
	_lock.visible = true
	_lock.self_modulate = Color.WHITE
	_lock.modulate = Color.WHITE
	_lock.scale = _lock_number_scale()


func _prepare_lock_on_back() -> void:
	_show_lock_in_place()


func _blink_lock_on_back(token: int) -> void:
	if _lock == null:
		await get_tree().create_timer(maxf(locked_hold_sec, 0.05), true).timeout
		return
	_show_lock_in_place()
	var blink := create_tween()
	_flip_tween = blink
	blink.set_loops(8)
	blink.tween_property(_lock, "modulate:a", 0.08, 0.09)
	blink.tween_property(_lock, "modulate:a", 1.0, 0.09)
	await blink.finished
	if token != _flip_token:
		return
	if _lock:
		_lock.modulate.a = 1.0


func _set_face(back: bool, blank_back: bool = false) -> void:
	_showing_back = back
	if _back_label:
		_back_label.visible = back and not blank_back
		if _back_label.visible:
			_apply_back_text()
	if _particles:
		_particles.visible = not back
	if back:
		for node in [_banner, _banner2, _banner3, _coat_arms, _title, _subtitle, _icon_box]:
			if node:
				node.visible = false
		if blink_lock_instead_of_flip:
			_show_lock_in_place()
		elif _lock:
			_lock.visible = false
		return
	if _subtitle:
		_subtitle.visible = not hide_subtitle
	if _coat_arms:
		_coat_arms.visible = not is_boss
	if _title:
		_title.visible = not _hide_number_for_lock()
	_apply_visuals()


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
