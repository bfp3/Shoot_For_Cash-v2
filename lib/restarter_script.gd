extends Node

## Debug-only Moss skip (Shift+M). Never runs in exported builds.
var _level_jump_busy := false

## Set by Main-lofi before loading Main.tscn — consumed once on boot.
var pending_fast_travel_level := ""


func clear_pending_fast_travel() -> void:
	pending_fast_travel_level = ""


func request_fast_travel(level_id: String) -> void:
	pending_fast_travel_level = gl_DataSet.resolve_place_name(level_id)
	get_tree().change_scene_to_file("res://sc/Main.tscn")


func take_pending_fast_travel() -> String:
	var level := pending_fast_travel_level
	pending_fast_travel_level = ""
	return level


func _input(event) -> void:
	if event.is_action_pressed("restart"):
		get_tree().call_group("restartable", "restart")
		gl_PlayerState.reset_all()
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame
		get_tree().reload_current_scene()
		return

	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed and event.keycode == KEY_M:
			debug_jump_to_level(gl_DataSet.get_default_range_name())
			return

	# Prefer the event itself — is_action_just_pressed() is unreliable inside _input.
	if not RoundManager.is_level_editor_available():
		return
	var toggle_editor = (
		event.is_action_pressed("toggle_key_editor")
		or event.is_action_pressed("toggle_level_editor")
	)
	if toggle_editor and not event.is_echo():
		if debug_open_level_editor():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_round_editor") and not event.is_echo():
		if debug_open_round_editor():
			get_viewport().set_input_as_handled()


## Instant range jump: land on the open shop menu — do not start the round.
func debug_jump_to_moss() -> void:
	await debug_jump_to_level(gl_DataSet.get_default_range_name())


func debug_jump_to_level(level_id: String) -> void:
	level_id = gl_DataSet.resolve_place_name(level_id)
	if _level_jump_busy:
		return

	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		push_warning("DEBUG fast travel: round_manager not found")
		return
	if round_manager.transitioning_worlds:
		return
	if not round_manager.has_method("debug_restart_to_level"):
		push_warning("DEBUG fast travel: round_manager missing debug_restart_to_level")
		return

	_level_jump_busy = true
	print("DEBUG: fast travel → instant %s (shop)" % level_id)

	if get_tree().paused:
		get_tree().paused = false

	var scene := get_tree().current_scene
	if scene != null and scene.has_method("debug_bootstrap_gameplay"):
		await scene.debug_bootstrap_gameplay()

	gl_PlayerState.reset_level()
	gl_PlayerState.round_finished = false

	# Reset other systems. Skip:
	# - round_manager (instant level path)
	# - player balloon (instant path adds it; restart has long awaits)
	# - shop menus (their restart() calls CLOSE_MENU → SHOP_END → starts the round)
	for node in get_tree().get_nodes_in_group("restartable"):
		if node == round_manager:
			continue
		if node.is_in_group("player_balloon_container"):
			continue
		if node.is_in_group("shop_main_menu"):
			_soft_reset_shop_main(node)
			continue
		if node.has_method("restart") and _is_start_menu_shop(node):
			_soft_reset_start_menu(node)
			continue
		if node.has_method("restart"):
			node.restart()

	await round_manager.debug_restart_to_level(level_id)
	_level_jump_busy = false


## Debug: open level editor from the shop / start menu (closes menu UI, does not start a round).
## Returns true only when the editor actually opened (so the toggle key can be consumed).
func debug_open_level_editor() -> bool:

	if not RoundManager.is_level_editor_available():
		return false
	var round_manager : RoundManager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		push_warning("DEBUG level editor: round_manager not found")
		return false
	
	if round_manager.has_method("open_level_editor_from_shop"):
		return bool(round_manager.open_level_editor_from_shop())
	return false


func debug_open_round_editor() -> bool:
	if not RoundManager.is_level_editor_available():
		return false
	var round_manager: RoundManager = get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		push_warning("DEBUG round editor: round_manager not found")
		return false
	if round_manager.has_method("open_round_editor_from_shop"):
		return bool(round_manager.open_round_editor_from_shop())
	return false


func _is_start_menu_shop(node: Node) -> bool:
	# Start menu clone also CLOSE_MENU → SHOP_END; detect by script path.
	var script: Script = node.get_script()
	if script == null:
		return false
	return String(script.resource_path).ends_with("start_menu_shop_clone.gd")


func _soft_reset_shop_main(shop: Node) -> void:
	# Same cleanup as shop.restart(), but do NOT enter CLOSE_MENU (that starts the round).
	shop.current_state = shop.SkillState.INACTIVE
	shop.current_round = 0
	shop.player_cash = gl_PlayerState.dataset.cash
	shop.price_reroll = 0
	shop.reroll_unlocked = true
	shop.reroll_index = 0
	shop.is_rerolling = false
	if shop.has_method("clear_available_skills"):
		shop.clear_available_skills()
	shop.hide()
	shop.modulate.a = 1.0
	shop.scale = shop.default_scale
	shop.position = shop.default_position
	shop.pivot_offset = shop.default_pivot_offset
	if shop.get("cash_label"):
		shop.cash_label.text = "$0"
	if shop.get("all_skills"):
		for skill in shop.all_skills:
			skill.new_round = true
			if skill.has_method("reset_buttons_settings"):
				skill.reset_buttons_settings()
	if shop.has_method("update_shop"):
		shop.update_shop()
	if shop.has_method("update_shop_labels"):
		shop.update_shop_labels()
	if shop.has_method("update_cost_label"):
		shop.update_cost_label()


func _soft_reset_start_menu(menu: Node) -> void:
	menu.current_state = menu.State.INACTIVE
	menu.hide()
	menu.modulate.a = 1.0
	menu.scale = menu.default_scale
	menu.position = menu.default_position
	menu.pivot_offset = menu.default_pivot_offset
