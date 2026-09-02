extends Area3D
## Thin gate in Main.tscn ($RockConverter/Area3D).
## Active rocks that pass through flip yellow↔red hazard without changing flight.

@export var flip_cooldown_sec := 0.4
## Thicken detection in world Y so fast rocks don't tunnel the thin visual mesh.
@export var collision_thickness_y := 1.5

var _last_flip_msec: Dictionary = {} # instance_id -> msec


func _ready() -> void:
	monitoring = true
	monitorable = false
	## RockInstance RigidBody lives on physics layer 2.
	collision_layer = 0
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_ensure_thick_shape()


func _ensure_thick_shape() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or col.shape == null:
		return
	if col.shape is BoxShape3D:
		var box := col.shape as BoxShape3D
		if box.size.y < collision_thickness_y:
			box.size.y = collision_thickness_y


func _on_body_entered(body: Node3D) -> void:
	if body == null or not (body is RockInstance):
		return
	var rock := body as RockInstance
	var id := rock.get_instance_id()
	var now := Time.get_ticks_msec()
	if _last_flip_msec.has(id) and now - int(_last_flip_msec[id]) < roundi(flip_cooldown_sec * 1000.0):
		return
	if rock.has_method("flip_converter_alliance") and rock.flip_converter_alliance():
		_last_flip_msec[id] = now
		_prune_flip_cache(now)


func _prune_flip_cache(now_msec: int) -> void:
	var cutoff := now_msec - roundi(maxf(flip_cooldown_sec, 1.0) * 5000.0)
	var stale: Array = []
	for id in _last_flip_msec.keys():
		if int(_last_flip_msec[id]) < cutoff:
			stale.append(id)
	for id in stale:
		_last_flip_msec.erase(id)
