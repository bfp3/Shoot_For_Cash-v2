extends Control

signal confirmed
signal cancelled

@onready var _yes: Button = %YesButton
@onready var _no: Button = %NoButton
@onready var _panel: Control = %PromptPanel
@onready var _dim: CanvasItem = get_node_or_null("Dim") as CanvasItem
@onready var _title: RichTextLabel = $Center/PromptPanel/VBox/Title as RichTextLabel

var _busy := false
var _closing := false
var _panel_rest_scale := Vector2.ONE
var _default_title := ""


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _title:
		_default_title = _title.text
	if _panel:
		_panel.pivot_offset_ratio = Vector2(0.5, 0.5)
		_panel_rest_scale = _panel.scale if _panel.scale != Vector2.ZERO else Vector2.ONE
	if _yes:
		_yes.pressed.connect(_on_yes)
	if _no:
		_no.pressed.connect(_on_no)


func open_prompt(title_bbcode: String = "") -> void:
	if _busy or _closing:
		return
	if visible:
		return
	if _title:
		_title.text = title_bbcode if not title_bbcode.is_empty() else _default_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _dim:
		_dim.modulate.a = 0.0
	if _panel:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2.ONE * 0.01
	modulate.a = 1.0
	show()
	_play_open_sfx()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	if _dim:
		tween.parallel().tween_property(_dim, "modulate:a", 1.0, 0.18)
	if _panel:
		tween.parallel().tween_property(_panel, "scale", _panel_rest_scale, 0.03)
		tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.18)
	else:
		tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await tween.finished
	UiFocus.grab_in(self, _no)


func close_prompt() -> void:
	if _closing:
		while _closing and is_inside_tree():
			await get_tree().process_frame
		return
	if not visible:
		_busy = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_close_sfx()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	if _dim:
		tween.parallel().tween_property(_dim, "modulate:a", 0.0, 0.16)
	if _panel:
		tween.parallel().tween_property(_panel, "scale", Vector2.ONE * 0.01, 0.4)
		tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.16)
	else:
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	await tween.finished
	if _panel:
		_panel.scale = _panel_rest_scale
		_panel.modulate.a = 1.0
	if _dim:
		_dim.modulate.a = 1.0
	modulate.a = 1.0
	hide()
	_busy = false
	_closing = false


func _on_no() -> void:
	if _busy or _closing:
		return
	await close_prompt()
	cancelled.emit()


func _on_yes() -> void:
	if _busy or _closing:
		return
	_busy = true
	await close_prompt()
	confirmed.emit()


func _play_open_sfx() -> void:
	var open_sfx := get_node_or_null("SFX/shop_open_sfx_01") as AudioStreamPlayer
	if open_sfx:
		open_sfx.play(0.3)
	for name in ["hud_click_1", "hud_click_2", "hud_click_3"]:
		var player := get_node_or_null("SFX/%s" % name) as AudioStreamPlayer
		if player:
			player.play()
	var hum := get_node_or_null("SFX/low_humming") as AudioStreamPlayer
	if hum:
		hum.play()


func _play_close_sfx() -> void:
	var close_sfx := get_node_or_null("SFX/shop_close_sfx_01") as AudioStreamPlayer
	if close_sfx:
		close_sfx.play(0.5)
	for name in ["hud_click_1", "hud_click_2", "hud_click_3"]:
		var player := get_node_or_null("SFX/%s" % name) as AudioStreamPlayer
		if player:
			player.play()
	var hum := get_node_or_null("SFX/low_humming") as AudioStreamPlayer
	if hum:
		hum.stop()
