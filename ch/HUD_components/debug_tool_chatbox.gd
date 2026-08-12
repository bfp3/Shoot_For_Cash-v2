extends CanvasLayer

## Debug-only command chat (OS.is_debug_build). Hold toggle_tool_chatbox to open.

const HOLD_OPEN_SEC := 0.22
const COMMAND_HELP := """[b]Commands[/b]
no-lives
lives
no-ammo
ammo
add-cash(number)
no-cash
slow(number)
level(number)

[b]level[/b]
1 moss  2 redd  3 glory
4 boss  5 jetz  6 noir
7 vesper"""

@export var anim_duration := 0.25

@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Panel
@onready var line_edit: LineEdit = %CommandLine
@onready var output: RichTextLabel = %OutputLog
@onready var help_label: RichTextLabel = %HelpList

var _open := false
var _animating := false
var _hold_time := 0.0
var _stored_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

## Used by middle-mouse release so slow(n) persists until MMB resets/restores.
var base_time_scale := 1.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("debug_tool_chatbox")
	hide()
	dim.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.01
	panel.pivot_offset = Vector2(0, panel.size.y) # bottom-left; refreshed on open
	if help_label:
		help_label.bbcode_enabled = true
		help_label.text = COMMAND_HELP
	if line_edit:
		line_edit.text_submitted.connect(_on_command_submitted)
	_log("Debug chat ready. Hold Shift+Space to open.")


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	if _open or _animating:
		_hold_time = 0.0
		return
	if Input.is_action_pressed("toggle_tool_chatbox"):
		_hold_time += delta
		if _hold_time >= HOLD_OPEN_SEC:
			_hold_time = 0.0
			open_chat()
	else:
		_hold_time = 0.0


func _input(event: InputEvent) -> void:
	if not _open or _animating:
		return
	if event.is_action_pressed("escape") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_chat()
		get_viewport().set_input_as_handled()


func open_chat() -> void:
	if _open or _animating:
		return
	var pause_menu := get_tree().get_first_node_in_group("pause_menu") as CanvasItem
	if pause_menu and pause_menu.visible:
		return
	_animating = true
	_open = true
	_stored_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	show()
	await get_tree().process_frame
	panel.pivot_offset = Vector2(0.0, panel.size.y)
	panel.scale = Vector2.ONE * 0.01
	dim.modulate.a = 0.0
	CommonCode.apply_ui_overlay_blur()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, anim_duration)
	tween.parallel().tween_property(dim, "modulate:a", 1.0, anim_duration)
	await tween.finished

	_animating = false
	if line_edit:
		line_edit.grab_focus()
		line_edit.clear()


func close_chat() -> void:
	if not _open or _animating:
		return
	_animating = true
	if line_edit:
		line_edit.release_focus()

	panel.pivot_offset = Vector2(0.0, panel.size.y)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2.ONE * 0.01, anim_duration)
	tween.parallel().tween_property(dim, "modulate:a", 0.0, anim_duration)
	await tween.finished

	hide()
	var pause_menu := get_tree().get_first_node_in_group("pause_menu") as CanvasItem
	if pause_menu == null or not pause_menu.visible:
		get_tree().paused = false
	Input.mouse_mode = _stored_mouse
	_open = false
	_animating = false
	_restore_blur_after_close()


func _restore_blur_after_close() -> void:
	var shop := get_tree().get_first_node_in_group("shop_main_menu") as CanvasItem
	var map_menu := get_tree().get_first_node_in_group("map_menu") as CanvasItem
	var tally := get_tree().get_first_node_in_group("tally_card_menu") as CanvasItem
	if (shop and shop.visible) or (map_menu and map_menu.visible) or (tally and tally.visible):
		CommonCode.apply_ui_overlay_blur()
		return
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("_is_actively_playing_round") and rm._is_actively_playing_round():
		CommonCode.apply_gameplay_blur()
	else:
		CommonCode.apply_ui_overlay_blur()


func _on_command_submitted(text: String) -> void:
	var raw := text.strip_edges()
	if line_edit:
		line_edit.clear()
	if raw.is_empty():
		return
	_log("> " + raw)
	_execute(raw)


func _log(msg: String) -> void:
	if output == null:
		print("[debug_chat] ", msg)
		return
	output.append_text(msg + "\n")


func _execute(raw: String) -> void:
	var lower := raw.to_lower().strip_edges()
	if lower == "no-lives":
		_set_debug_no_lives(true)
		_log("Invincible: strikes ignored.")
	elif lower == "lives":
		_set_debug_no_lives(false)
		_log("Lives restored (normal strikes).")
	elif lower == "no-ammo":
		_set_debug_infinite_ammo(true)
		_log("Infinite ammo on.")
	elif lower == "ammo":
		_set_debug_infinite_ammo(false)
		_log("Ammo consumption restored.")
	elif lower == "no-cash":
		gl_PlayerState.dataset.cash = 0
		_log("Cash set to $0.")
	elif lower.begins_with("add-cash"):
		var amount := int(round(_extract_number(raw)))
		gl_PlayerState.add_cash(amount)
		_log("Added $%s (now $%s)." % [amount, gl_PlayerState.dataset.cash])
	elif lower.begins_with("slow"):
		var time_scale_value := _extract_number(raw)
		if time_scale_value <= 0.0:
			_log("Usage: slow(0.5)")
			return
		base_time_scale = time_scale_value
		Engine.time_scale = time_scale_value
		_log("Time scale → %s (MMB still boosts; release restores this)." % time_scale_value)
	elif lower.begins_with("level"):
		var n := int(round(_extract_number(raw)))
		_goto_level(n)
	else:
		_log("Unknown command. See list on the right.")


func _extract_number(s: String) -> float:
	var a := s.find("(")
	var b := s.find(")", a + 1)
	if a >= 0 and b > a:
		return float(s.substr(a + 1, b - a - 1).strip_edges())
	var parts := s.strip_edges().split(" ", false)
	if parts.size() >= 2:
		return float(parts[1])
	return 0.0


func _set_debug_no_lives(on: bool) -> void:
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm:
		rm.set("debug_no_lives", on)


func _set_debug_infinite_ammo(on: bool) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.set("debug_infinite_ammo", on)


func _goto_level(n: int) -> void:
	## 1 moss, 2 redd, 3 glory, 4 boss, 5 jetz, 6 noir, 7 vesper
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm == null:
		_log("No round_manager.")
		return
	await close_chat()
	if n == 4:
		_log("Travelling to boss…")
		if rm.has_method("travel_to_boss"):
			await rm.travel_to_boss(0)
		return
	var places := ["moss", "redd", "glory", "jetz", "noir", "vesper"]
	var idx := -1
	if n >= 1 and n <= 3:
		idx = n - 1
	elif n >= 5 and n <= 7:
		idx = n - 2
	if idx < 0 or idx >= places.size():
		_log("Usage: level(1..7) — 4 = boss")
		return
	var place: String = places[idx]
	_log("Travelling to %s…" % place)
	if rm.has_method("travel_to_level"):
		await rm.travel_to_level(place)
	elif rm.has_method("move_to_new_range"):
		await rm.move_to_new_range(place)
