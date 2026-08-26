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
@export var locked := false:
	set(value):
		locked = value
		_apply_visuals()

@onready var _circle: Control = $Circle
@onready var _circle2: Control = get_node_or_null("Circle2")
@onready var _circle3: Control = get_node_or_null("Circle3")
@onready var _icon_box: HBoxContainer = get_node_or_null("HBoxContainer")
@onready var _banner: ColorRect = $Banner
@onready var _title: RichTextLabel = $Title
@onready var _subtitle: RichTextLabel = $Subtitle
@onready var _lock: TextureRect = $LockIcon
@onready var _button: Button = $HitButton

var _wiggle: Tween


func _ready() -> void:
	if _button:
		_button.pressed.connect(_on_hit)
		_button.mouse_entered.connect(_on_hover.bind(true))
		_button.mouse_exited.connect(_on_hover.bind(false))
	_apply_visuals()


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
		_lock.visible = locked
	if _button:
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
	if locked or travel_place.strip_edges().is_empty():
		return
	pressed.emit()


func _on_hover(inside: bool) -> void:
	if locked or not is_inside_tree():
		return
	if _wiggle:
		_wiggle.kill()
	_wiggle = create_tween()
	_wiggle.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := Vector2.ONE * (1.06 if inside else 1.0)
	_wiggle.tween_property(self, "scale", target, 0.12)
