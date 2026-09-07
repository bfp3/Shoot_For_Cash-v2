extends RigidBody3D
## Falling cash from a popped yellow-rock balloon. Banks only if a collector catches it.
## A miss is just a miss — no cash, no strike.

class_name CashCrateDrop

const LAYER := 32
const MISS_Y := -8.0
const AIM_PLANE_Z := 23.0

var payout := 0
var _collected := false
var _plane_z := AIM_PLANE_Z

@onready var _value_label: Label3D = get_node_or_null("Label3D") as Label3D


func _ready() -> void:
	add_to_group("cash_crate_drop")
	collision_layer = LAYER
	collision_mask = 0
	gravity_scale = 1.6
	can_sleep = false
	continuous_cd = true
	contact_monitor = false
	axis_lock_linear_z = true
	freeze = false
	_refresh_label()


func setup(amount: int, world_xform: Transform3D, plane_z: float = AIM_PLANE_Z) -> void:
	payout = amount
	_plane_z = plane_z
	global_position = world_xform.origin
	global_rotation = world_xform.basis.get_euler()
	global_position.z = _plane_z
	linear_velocity = Vector3(0.0, -1.2, 0.0)
	angular_velocity = Vector3(
		randf_range(-2.4, 2.4),
		randf_range(-3.0, 3.0),
		randf_range(-2.4, 2.4)
	)
	_refresh_label()


func _physics_process(_delta: float) -> void:
	if _collected:
		return
	if absf(global_position.z - _plane_z) > 0.001:
		global_position.z = _plane_z
	linear_velocity.z = 0.0
	if global_position.y <= MISS_Y:
		_miss()


func try_collect(_collector: Node = null) -> bool:
	if _collected:
		return false
	_collected = true
	collision_layer = 0
	collision_mask = 0
	freeze = true
	if payout != 0:
		gl_PlayerState.add_to_cash_pool(payout, global_position)
	queue_free()
	return true


func dismiss() -> void:
	if _collected:
		return
	_collected = true
	queue_free()


func _miss() -> void:
	dismiss()


func _refresh_label() -> void:
	if _value_label == null:
		_value_label = get_node_or_null("Label3D") as Label3D
	if _value_label == null:
		return
	var amount := payout
	_value_label.text = CommonCode.format_money(amount)
	var positive := Color(0.96, 0.83, 0.7, 1)
	var negative := Color(0.63, 0.01, 0.02, 1)
	_value_label.modulate = negative if amount < 0 else positive
	_value_label.show()
