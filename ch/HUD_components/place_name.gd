extends Control

@onready var place_label: RichTextLabel = $PlaceLabel
@onready var _arrival_name: RichTextLabel = get_node_or_null("%ArrivalName")
@onready var _arrival_time: RichTextLabel = get_node_or_null("%ArrivalTime")

@export var arrival_time_text := "8:02AM"
@export var arrival_fade_in_sec := 0.35
## Seconds the range name / time stay on screen after fade-in, before fade-out and the camera swoop.
@export var arrival_hold_sec := 2.6
@export var arrival_fade_out_sec := 0.55
## Seconds after the camera lands before shop + blur. 0 = open shop while the camera still swoops.
@export var arrival_shop_delay_sec := 0.0


func _ready() -> void:
	_ensure_arrival_labels()
	_hide_arrival_card()
	update_place_name()


func update_place_name() -> void:
	var current_place : String = gl_PlayerState.dataset.level_name
	show()
	if current_place == 'start':
		hide()
		return
	if place_label == null:
		return

	var tween = create_tween()
	tween.tween_property(place_label, 'modulate', Color.TRANSPARENT, 1.0)
	tween.tween_interval(1.0)
	await tween.finished

	place_label.text = gl_DataSet.display_place_name(current_place)

	var tween2 = create_tween()
	tween2.tween_property(place_label, 'modulate', Color.WHITE, 1.0)


func play_arrival_card(place_id: String) -> void:
	_ensure_arrival_labels()
	show()
	if place_label:
		place_label.hide()
	var title := _arrival_title(place_id)
	if _arrival_name:
		_arrival_name.text = "[center][wave]%s" % title
		_arrival_name.modulate.a = 0.0
		_arrival_name.show()
	if _arrival_time:
		_arrival_time.text = "[center][wave]%s" % arrival_time_text
		_arrival_time.modulate.a = 0.0
		_arrival_time.show()

	var fade_in := create_tween()
	fade_in.set_parallel(true)
	if _arrival_name:
		fade_in.tween_property(_arrival_name, "modulate:a", 1.0, arrival_fade_in_sec)
	if _arrival_time:
		fade_in.tween_property(_arrival_time, "modulate:a", 1.0, arrival_fade_in_sec)
	await fade_in.finished
	await get_tree().create_timer(maxf(arrival_hold_sec, 0.05), false).timeout
	if not is_inside_tree():
		return
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	if _arrival_name:
		fade_out.tween_property(_arrival_name, "modulate:a", 0.0, arrival_fade_out_sec)
	if _arrival_time:
		fade_out.tween_property(_arrival_time, "modulate:a", 0.0, arrival_fade_out_sec)
	await fade_out.finished
	_hide_arrival_card()


func _arrival_title(place_id: String) -> String:
	var _name := gl_DataSet.display_place_name(place_id)
	if _name.strip_edges().is_empty():
		_name = String(place_id).strip_edges().to_upper()
	_name = _name.to_upper()
	var n := 0
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("get_script_level_number"):
		n = int(rm.get_script_level_number(place_id))
	if n > 0:
		return "%d\n%s" % [n, _name]
	return _name


func _hide_arrival_card() -> void:
	if _arrival_name:
		_arrival_name.hide()
		_arrival_name.modulate.a = 0.0
	if _arrival_time:
		_arrival_time.hide()
		_arrival_time.modulate.a = 0.0


func _ensure_arrival_labels() -> void:
	if _arrival_name == null:
		_arrival_name = _make_arrival_label("ArrivalName", 132, Vector2(-420, -280), Vector2(420, 80))
	if _arrival_time == null:
		_arrival_time = _make_arrival_label("ArrivalTime", 56, Vector2(-280, 92), Vector2(280, 176))


func _make_arrival_label(node_name: String, font_size: int, top_left: Vector2, bottom_right: Vector2) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.unique_name_in_owner = true
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_contents = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme_type_variation = "WhiteRichText"
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = top_left.x
	label.offset_top = top_left.y
	label.offset_right = bottom_right.x
	label.offset_bottom = bottom_right.y
	add_child(label)
	return label
