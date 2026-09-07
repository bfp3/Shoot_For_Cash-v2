extends ThreatSmokeMine
## Script helper (`collector …`). Patrols like a threat but never alarms on the reticle.
## Banks any nearby cash crate — still hanging on a balloon, or already falling.

class_name TheCollector

const CATCH_RADIUS := 1.05

var _catch_area: Area3D


func _ready() -> void:
	super._ready()
	if is_in_group("threat_smoke_mine"):
		remove_from_group("threat_smoke_mine")
	add_to_group("collector")
	_ensure_catch_area()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_poll_catch()


func _overlaps_crosshair() -> bool:
	return false


func _check_crosshair_alarm() -> void:
	pass


func _update_core_reveal() -> void:
	_apply_core_xray(Vector2.ZERO, 0.0, false)


func _on_body_entered(body: Node) -> void:
	if body != null and (body.is_in_group("cash_crate_drop") or body.is_in_group("cash_balloon")):
		_try_collect_cash(body)
		return
	if body is RockInstance:
		_play_rock_ding()


func play_collect_sfx() -> void:
	_play_rock_ding()


func _ensure_catch_area() -> void:
	_catch_area = get_node_or_null("CatchArea") as Area3D
	if _catch_area == null:
		_catch_area = Area3D.new()
		_catch_area.name = "CatchArea"
		add_child(_catch_area)
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = CATCH_RADIUS
		col.shape = sphere
		_catch_area.add_child(col)
	_catch_area.collision_layer = 0
	_catch_area.collision_mask = CashCrateDrop.LAYER
	_catch_area.monitorable = false
	_catch_area.monitoring = true
	if not _catch_area.body_entered.is_connected(_on_catch_body_entered):
		_catch_area.body_entered.connect(_on_catch_body_entered)


func _on_catch_body_entered(body: Node) -> void:
	_try_collect_cash(body)


func _poll_catch() -> void:
	if not visible or _exiting:
		return
	if _catch_area != null:
		for body in _catch_area.get_overlapping_bodies():
			_try_collect_cash(body)
	_poll_hanging_cash_crates()


func _poll_hanging_cash_crates() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("cash_balloon"):
		if node == null or not is_instance_valid(node):
			continue
		if not _is_near_crate(_cash_crate_world_pos(node)):
			continue
		_try_collect_cash(node)


func _cash_crate_world_pos(balloon: Node) -> Vector3:
	var crate := balloon.get_node_or_null("Crate") as Node3D
	if crate != null and crate.visible:
		return crate.global_position
	return balloon.global_position


func _is_near_crate(crate_pos: Vector3) -> bool:
	var delta := crate_pos - global_position
	delta.z = 0.0
	return delta.length_squared() <= CATCH_RADIUS * CATCH_RADIUS


func _try_collect_cash(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not visible or _exiting:
		return
	if body.is_in_group("cash_balloon") and body.has_method("try_collect_by_collector"):
		if bool(body.try_collect_by_collector(self)):
			_play_rock_ding()
		return
	if not body.is_in_group("cash_crate_drop"):
		return
	if not body.has_method("try_collect"):
		return
	if bool(body.try_collect(self)):
		_play_rock_ding()
