extends CanvasLayer

signal finished

@onready var _root: Control = $Control
@onready var _fade: ColorRect = %FadeRect
@onready var _title: RichTextLabel = %TitleLabel
@onready var _cash: RichTextLabel = %CashLabel
@onready var _done: Button = %DoneButton

var _busy := false
var _waiting_for_done := false


func _ready() -> void:
	add_to_group("stage_complete_screen")
	layer = 90
	hide()
	if _done:
		_done.pressed.connect(_on_done_pressed)
		_done.hide()
		_done.disabled = true
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_visuals()


func play(stage_name: String, cash_amount: int) -> void:
	if _busy:
		return
	_busy = true
	_waiting_for_done = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reset_visuals()
	_set_copy(stage_name, cash_amount)
	show()
	_play_open_sfx()

	await _fade_to_black()
	await get_tree().create_timer(0.35, false).timeout
	await _reveal(_title, 0.45)
	await get_tree().create_timer(0.2, false).timeout
	await _reveal(_cash, 0.4)
	await get_tree().create_timer(0.35, false).timeout
	await _reveal_done()

	while _waiting_for_done and is_inside_tree():
		await get_tree().process_frame

	_busy = false
	finished.emit()


func close_now() -> void:
	_waiting_for_done = false
	_busy = false
	hide()
	_reset_visuals()


func _set_copy(stage_name: String, cash_amount: int) -> void:
	var stage := stage_name.strip_edges().to_upper()
	if stage.is_empty():
		stage = ""
	if _title:
		_title.text = "[center][wave]%s COMPLETE" % stage
	if _cash:
		_cash.text = "[center][wave amp=12 freq=3]%s" % CommonCode.format_money(cash_amount)


func _reset_visuals() -> void:
	if _fade:
		_fade.color = Color(0, 0, 0, 0)
	if _title:
		_title.modulate.a = 0.0
	if _cash:
		_cash.modulate.a = 0.0
	if _done:
		_done.modulate.a = 0.0
		_done.hide()
		_done.disabled = true


func _fade_to_black() -> void:
	if _fade == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", 1.0, 0.85)
	await tween.finished


func _reveal(node: CanvasItem, duration: float) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	await tween.finished


func _reveal_done() -> void:
	if _done == null:
		return
	_done.show()
	_done.disabled = false
	_done.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_done, "modulate:a", 1.0, 0.28)
	await tween.finished
	UiFocus.grab_in(_root, _done)


func _on_done_pressed() -> void:
	if not _waiting_for_done:
		return
	_waiting_for_done = false
	_play_close_sfx()
	if _done:
		_done.disabled = true


func _play_open_sfx() -> void:
	var open_sfx := get_node_or_null("SFX/shop_open_sfx_01") as AudioStreamPlayer
	if open_sfx:
		open_sfx.play(0.3)
	for name in ["hud_click_1", "hud_click_2", "hud_click_3"]:
		var player := get_node_or_null("SFX/%s" % name) as AudioStreamPlayer
		if player:
			player.play()


func _play_close_sfx() -> void:
	var close_sfx := get_node_or_null("SFX/shop_close_sfx_01") as AudioStreamPlayer
	if close_sfx:
		close_sfx.play(0.5)
	var click := get_node_or_null("SFX/hud_click_1") as AudioStreamPlayer
	if click:
		click.play()
