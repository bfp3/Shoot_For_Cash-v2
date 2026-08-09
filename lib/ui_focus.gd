extends Node

## Makes menus keyboard/controller navigable.
## When the mouse is free (or the tree is paused) and nothing has GUI focus,
## directional / accept input focuses the first usable control. Menus should
## also call grab_in() on open for an immediate highlight.
##
## A floating cursor marks focus inside shop / map / start menus.

const NAV_ACTIONS := [
	"ui_up", "ui_down", "ui_left", "ui_right",
	"ui_accept", "ui_focus_next", "ui_focus_prev",
]

## Menus that show the on-screen focus cursor.
const INDICATOR_GROUPS := ["shop_main_menu", "map_menu", "start_menu_ui", "pause_menu"]

var _was_mouse_captured := false
var _indicator: Control
var _indicator_pulse := 0.0
var _indicator_pos := Vector2.ZERO
var _indicator_has_pos := false
var _indicator_suppressed := false
const INDICATOR_SIZE := Vector2(56, 56)
const INDICATOR_LERP_SPEED := 14.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui_input_map()
	_setup_focus_indicator()


func _process(delta: float) -> void:
	# Drop GUI focus when returning to aiming so WASD/stick don't fight the crosshair.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if captured and not _was_mouse_captured:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	_was_mouse_captured = captured

	# Drop focus if the owner became hidden or process-disabled; hop to a neighbor if possible.
	var owner_focus := get_viewport().gui_get_focus_owner() as Control
	if owner_focus and not _can_focus(owner_focus):
		var fallback := _find_valid_neighbor(owner_focus)
		owner_focus.release_focus()
		if fallback:
			fallback.grab_focus()

	_update_focus_indicator(delta)


func _input(event: InputEvent) -> void:
	if not _should_offer_focus():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not _is_nav_event(event):
		return
	if _has_valid_focus():
		return
	var target := find_first_focusable()
	if target:
		target.grab_focus()


func grab_in(root: Node, preferred: Control = null) -> void:
	if not is_instance_valid(root):
		return
	# Wait a frame so show()/visibility and layout settle.
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	if preferred and _can_focus(preferred):
		preferred.grab_focus()
		return
	var first := find_first_focusable(root)
	if first:
		first.grab_focus()


func find_first_focusable(root: Node = null) -> Control:
	if root != null:
		return _find_first_under(root)

	# Prefer higher CanvasLayers (menus sit above gameplay HUD).
	var layers: Array[CanvasLayer] = []
	for node in get_tree().get_nodes_in_group("pause_menu"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			layers.append(node as CanvasLayer)
	for node in get_tree().get_nodes_in_group("map_menu"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			layers.append(node as CanvasLayer)

	var tree_root := get_tree().root
	_collect_canvas_layers(tree_root, layers)
	layers.sort_custom(func(a: CanvasLayer, b: CanvasLayer) -> bool: return a.layer > b.layer)

	for layer in layers:
		if not layer.visible:
			continue
		var found := _find_first_under(layer)
		if found:
			return found

	return _find_first_under(tree_root)


func wire_vertical(controls: Array, _wrap := true) -> void:
	var usable: Array[Control] = []
	for item in controls:
		if item is Control and _can_focus(item as Control):
			usable.append(item as Control)
	var n := usable.size()
	if n < 2:
		return
	for i in n:
		var prev_i := (i - 1 + n) % n if _wrap else maxi(i - 1, 0)
		var next_i := (i + 1) % n if _wrap else mini(i + 1, n - 1)
		usable[i].focus_neighbor_top = usable[prev_i].get_path()
		usable[i].focus_neighbor_bottom = usable[next_i].get_path()
		usable[i].focus_previous = usable[prev_i].get_path()
		usable[i].focus_next = usable[next_i].get_path()


func wire_horizontal(controls: Array, _wrap := true) -> void:
	var usable: Array[Control] = []
	for item in controls:
		if item is Control and _can_focus(item as Control):
			usable.append(item as Control)
	var n := usable.size()
	if n < 2:
		return
	for i in n:
		var prev_i := (i - 1 + n) % n if _wrap else maxi(i - 1, 0)
		var next_i := (i + 1) % n if _wrap else mini(i + 1, n - 1)
		usable[i].focus_neighbor_left = usable[prev_i].get_path()
		usable[i].focus_neighbor_right = usable[next_i].get_path()
		usable[i].focus_previous = usable[prev_i].get_path()
		usable[i].focus_next = usable[next_i].get_path()


func _should_offer_focus() -> bool:
	if get_tree().paused:
		return true
	var mode := Input.mouse_mode
	return mode == Input.MOUSE_MODE_VISIBLE or mode == Input.MOUSE_MODE_CONFINED


func _has_valid_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and is_instance_valid(focused) and _can_focus(focused)


func _is_nav_event(event: InputEvent) -> bool:
	for action in NAV_ACTIONS:
		if event.is_action(action):
			return true
	return false


func can_focus(control: Control) -> bool:
	return _can_focus(control)


func _can_focus(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree():
		return false
	if not _is_process_enabled_in_tree(control):
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE and not (control is Range):
		# Most ignore-mouse controls aren't meant for focus; dials/sliders are fine.
		if not (control is Slider or control.get_script() != null and control.has_method("set_value_no_signal")):
			return false
	return true


func _is_process_enabled_in_tree(node: Node) -> bool:
	var current := node
	while current:
		if current.process_mode == Node.PROCESS_MODE_DISABLED:
			return false
		current = current.get_parent()
	return true


func _find_first_under(root: Node) -> Control:
	if root is Control and _can_focus(root as Control):
		# Prefer interactive widgets over generic Containers that happen to be focusable.
		if root is BaseButton or root is OptionButton or root is Slider or root is SpinBox \
				or root is LineEdit or root is TextEdit \
				or (root as Control).has_method("set_value_no_signal"):
			return root as Control
	for child in root.get_children():
		var found := _find_first_under(child)
		if found:
			return found
	return null


func _collect_canvas_layers(node: Node, out: Array[CanvasLayer]) -> void:
	if node is CanvasLayer and not out.has(node):
		out.append(node as CanvasLayer)
	for child in node.get_children():
		_collect_canvas_layers(child, out)


func _find_valid_neighbor(from: Control) -> Control:
	if from == null:
		return null
	for path in [
		from.focus_neighbor_bottom,
		from.focus_neighbor_top,
		from.focus_neighbor_left,
		from.focus_neighbor_right,
		from.focus_next,
		from.focus_previous,
	]:
		if path.is_empty():
			continue
		var node := from.get_node_or_null(path)
		if node is Control and _can_focus(node as Control):
			return node as Control
	var next := from.find_next_valid_focus()
	if next and _can_focus(next):
		return next
	return null


func _setup_focus_indicator() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UiFocusIndicatorLayer"
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_indicator = Control.new()
	_indicator.name = "FocusCursor"
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.z_index = 100
	_indicator.custom_minimum_size = INDICATOR_SIZE
	_indicator.size = INDICATOR_SIZE
	_indicator.visible = false
	_indicator.draw.connect(_draw_focus_indicator)
	layer.add_child(_indicator)


func set_indicator_suppressed(suppressed: bool) -> void:
	_indicator_suppressed = suppressed
	if suppressed and _indicator:
		_indicator.visible = false
		_indicator_has_pos = false


func _update_focus_indicator(delta: float) -> void:
	if _indicator == null:
		return
	_indicator_pulse += delta * 6.0

	if _indicator_suppressed:
		_indicator.visible = false
		_indicator_has_pos = false
		return

	var focused := get_viewport().gui_get_focus_owner() as Control
	if focused == null or not _can_focus(focused) or not _is_under_indicator_menu(focused):
		_indicator.visible = false
		_indicator_has_pos = false
		return

	var rect := focused.get_global_rect()
	var bob := sin(_indicator_pulse) * 6.0
	var target := Vector2(
		rect.position.x - INDICATOR_SIZE.x - 6.0 + bob,
		rect.position.y + rect.size.y * 0.5 - INDICATOR_SIZE.y * 0.5
	)
	if not _indicator_has_pos:
		_indicator_pos = target
		_indicator_has_pos = true
	else:
		_indicator_pos = _indicator_pos.lerp(target, clampf(INDICATOR_LERP_SPEED * delta, 0.0, 1.0))
	_indicator.global_position = _indicator_pos
	_indicator.visible = true
	_indicator.queue_redraw()


func _is_under_indicator_menu(control: Control) -> bool:
	var node: Node = control
	while node:
		for group in INDICATOR_GROUPS:
			if node.is_in_group(group):
				return (node as CanvasItem).is_visible_in_tree() if node is CanvasItem else true
		node = node.get_parent()
	return false


func _draw_focus_indicator() -> void:
	if _indicator == null:
		return
	var cream := Color(0.92, 0.88, 0.85, 1.0)
	var red := Color(0.78, 0.004, 0.008, 1.0)
	var center := _indicator.size * 0.5
	# Pointing-right chevron so it sits just left of the focused control.
	var tip := Vector2(center.x + 20.0, center.y)
	var top := Vector2(center.x - 16.0, center.y - 22.0)
	var bot := Vector2(center.x - 16.0, center.y + 22.0)
	_indicator.draw_colored_polygon(PackedVector2Array([tip, top, bot]), red)
	_indicator.draw_polyline(PackedVector2Array([tip, top, bot, tip]), cream, 3.5, true)
	_indicator.draw_circle(center + Vector2(-2.0, 0.0), 6.0, cream)


func _ensure_ui_input_map() -> void:
	# Built-in ui_* usually exist; reinforce joypad so menus work on controller.
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)


func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, axis_value):
				return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)


func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
