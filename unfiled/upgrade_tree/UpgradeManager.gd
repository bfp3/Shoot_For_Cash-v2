extends Control
#
#class_name UpgradeManager
#
#signal upgrade_menu_closed
#signal upgrade_purchased(upgrade_id: StringName, effect_text: String)
#
#@export var current_money := 0
#
#@onready var money_label: Label = %MoneyLabel
#@onready var continue_button: Button = %ContinueButton
#@onready var tree_canvas: Control = %TreeCanvas
#@onready var connections_root: Node = %Connections
#@onready var node_root: UpgradeNode = %NodeRoot
#@onready var node_speed: UpgradeNode = %NodeBulletSpeed
#@onready var node_bullets: UpgradeNode = %NodeBulletsPerShot
#@onready var node_safe_scope: UpgradeNode = %NodeSafeScope
#
#var _upgrade_data := {
	## Root in the center.
	#"shot_radius": {
		#"id": "shot_radius",
		#"name": "Shot Radius Increase",
		#"description": "Wider spread control.",
		#"effect": "+10%",
		#"cost": 10,
		#"prerequisites": []
	#},
	## Left branch.
	#"bullet_speed": {
		#"id": "bullet_speed",
		#"name": "Bullet Speed",
		#"description": "Projectiles travel faster.",
		#"effect": "+15%",
		#"cost": 6,
		#"prerequisites": ["shot_radius"]
	#},
	## Bottom branch.
	#"bullets_per_shot": {
		#"id": "bullets_per_shot",
		#"name": "Bullets Spawned Per Shot",
		#"description": "More projectiles per trigger.",
		#"effect": "+1 bullet",
		#"cost": 4,
		#"prerequisites": ["shot_radius"]
	#},
	## Top branch.
	#"safe_scope": {
		#"id": "safe_scope",
		#"name": "Safe Scope",
		#"description": "Unlocks a special utility.",
		#"effect": "New Ability",
		#"cost": 100000,
		#"prerequisites": ["shot_radius"]
	#}
#}
#
#var _upgrade_nodes: Dictionary
#var _purchased: Dictionary = {}
#var _connection_pairs: Array[Array] = []
#var _is_closing := false
#var _interaction_enabled := true
#
#
#func _ready() -> void:
	#
	#EventBus.instance.open_shop.connect(open_menu)
	#_upgrade_nodes = {
		#"shot_radius": node_root,
		#"bullet_speed": node_speed,
		#"bullets_per_shot": node_bullets,
		#"safe_scope": node_safe_scope
	#}
#
	#for upgrade_id: String in _upgrade_nodes.keys():
		#_purchased[upgrade_id] = false
		#var node: UpgradeNode = _upgrade_nodes[upgrade_id]
		#node.configure(_upgrade_data[upgrade_id])
		#node.purchase_requested.connect(_on_node_purchase_requested)
		#node.upgrade_applied.connect(_on_upgrade_applied)
#
	#continue_button.pressed.connect(_on_continue_pressed)
	#tree_canvas.resized.connect(_update_connection_lines)
	#_setup_focus_navigation()
	#_build_connections()
	#_refresh_money_label()
	#_refresh_all_nodes()
	##open_menu()
#
#
#func open_menu() -> void:
	#print('Opening Menu')
	#Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	#visible = true
	#modulate.a = 0.0
	#_is_closing = false
#
	#_set_all_interactable(true)
	#var tween := create_tween()
	#tween.tween_property(self, "modulate:a", 1.0, 0.25)
#
#
#func close_menu() -> void:
	#if _is_closing:
		#return
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#_is_closing = true
	#_set_all_interactable(false)
	#var tween := create_tween()
	#tween.tween_property(self, "modulate:a", 0.0, 0.25)
	#tween.finished.connect(_on_fade_out_finished)
	#EventBus.instance.close_shop.emit()
#
#func set_player_money(new_money: int) -> void:
	#current_money = max(new_money, 0)
	#_refresh_money_label()
	#_refresh_all_nodes()
#
#
#func add_player_money(amount: int) -> void:
	#set_player_money(current_money + amount)
	#print("updated money ")
#
#func _on_node_purchase_requested(upgrade_id: StringName, cost: int) -> void:
	#var id := String(upgrade_id)
	#if not _upgrade_data.has(id):
		#return
	#if not _is_upgrade_unlocked(id):
		#return
	#if _purchased.get(id, false):
		#return
	#if current_money < cost:
		#return
#
	#current_money -= cost
	#_purchased[id] = true
	#_refresh_money_label()
	#_refresh_all_nodes()
#
	#var node: UpgradeNode = _upgrade_nodes[id]
	#node.apply_upgrade()
#
#
#func _on_upgrade_applied(upgrade_id: StringName, effect_text: String) -> void:
	## Connect this signal from your player/gameplay manager to apply effects outside UI.
	#upgrade_purchased.emit(upgrade_id, effect_text)
#
#
#func _on_continue_pressed() -> void:
	#close_menu()
#
#
#func _on_fade_out_finished() -> void:
	#visible = false
	#upgrade_menu_closed.emit()
#
#
#func _refresh_money_label() -> void:
	#money_label.text = "Money: %d" % current_money
#
#
#func _refresh_all_nodes() -> void:
	#for upgrade_id: String in _upgrade_nodes.keys():
		#var node: UpgradeNode = _upgrade_nodes[upgrade_id]
		#var purchased := bool(_purchased.get(upgrade_id, false))
		#var unlocked := _is_upgrade_unlocked(upgrade_id)
		#var affordable := current_money >= int(_upgrade_data[upgrade_id]["cost"])
#
		#if purchased:
			#node.set_state(UpgradeNode.UpgradeState.PURCHASED, true)
		#elif unlocked:
			#node.set_state(UpgradeNode.UpgradeState.UNLOCKED, affordable)
		#else:
			#node.set_state(UpgradeNode.UpgradeState.LOCKED, false)
#
		#if not _interaction_enabled:
			#node.disabled = true
#
	#_update_connection_lines()
#
#
#func _is_upgrade_unlocked(upgrade_id: String) -> bool:
	#var prerequisites: Array = _upgrade_data[upgrade_id].get("prerequisites", [])
	#for prerequisite in prerequisites:
		#if not bool(_purchased.get(String(prerequisite), false)):
			#return false
	#return true
#
#
#func _set_all_interactable(enabled: bool) -> void:
	#_interaction_enabled = enabled
	#continue_button.disabled = not enabled
	#_refresh_all_nodes()
#
#
#func _setup_focus_navigation() -> void:
	#node_root.focus_neighbor_left = node_speed.get_path()
	#node_root.focus_neighbor_right = node_bullets.get_path()
	#node_root.focus_neighbor_top = node_safe_scope.get_path()
	#node_root.focus_neighbor_bottom = node_bullets.get_path()
#
	#node_speed.focus_neighbor_right = node_root.get_path()
	#node_speed.focus_neighbor_top = node_safe_scope.get_path()
	#node_speed.focus_neighbor_bottom = node_bullets.get_path()
#
	#node_bullets.focus_neighbor_left = node_root.get_path()
	#node_bullets.focus_neighbor_top = node_root.get_path()
	#node_bullets.focus_neighbor_right = continue_button.get_path()
#
	#node_safe_scope.focus_neighbor_bottom = node_root.get_path()
	#node_safe_scope.focus_neighbor_left = node_speed.get_path()
	#node_safe_scope.focus_neighbor_right = continue_button.get_path()
#
	#continue_button.focus_neighbor_left = node_bullets.get_path()
	#continue_button.focus_neighbor_top = node_safe_scope.get_path()
#
	#node_root.grab_focus()
#
#
#func _build_connections() -> void:
	## Each pair creates one visual line between two upgrades.
	#_connection_pairs = [
		#["shot_radius", "bullet_speed"],
		#["shot_radius", "bullets_per_shot"],
		#["shot_radius", "safe_scope"]
	#]
#
	#for child in connections_root.get_children():
		#child.queue_free()
#
	#for pair in _connection_pairs:
		#var line := Line2D.new()
		#line.width = 4.0
		#line.default_color = Color(0.45, 0.50, 0.60, 0.95)
		#line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		#line.end_cap_mode = Line2D.LINE_CAP_ROUND
		#line.antialiased = true
		#connections_root.add_child(line)
#
	#call_deferred("_update_connection_lines")
#
#
#func _update_connection_lines() -> void:
	#if not is_inside_tree():
		#return
#
	#var index := 0
	#for pair in _connection_pairs:
		#var from_node: Control = _upgrade_nodes[pair[0]]
		#var to_node: Control = _upgrade_nodes[pair[1]]
		#var line := connections_root.get_child(index) as Line2D
		#if line == null:
			#continue
		#line.default_color = _line_color_for_pair(pair[0], pair[1])
		#line.points = PackedVector2Array([
			#_tree_local_center(from_node),
			#_tree_local_center(to_node)
		#])
		#index += 1
#
#
#func _line_color_for_pair(from_id: String, to_id: String) -> Color:
	#var from_purchased := bool(_purchased.get(from_id, false))
	#var to_purchased := bool(_purchased.get(to_id, false))
	#if from_purchased and to_purchased:
		#return Color(0.42, 0.92, 0.60, 0.95)
	#if from_purchased or to_purchased:
		#return Color(0.58, 0.70, 0.95, 0.95)
	#return Color(0.45, 0.50, 0.60, 0.90)
#
#
#func _tree_local_center(node: Control) -> Vector2:
	#return tree_canvas.get_global_transform().affine_inverse() * node.get_global_rect().get_center()
