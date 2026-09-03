class_name TriggerBlastWave
extends Area3D
## Upward-moving cylindrical blast. Destroys overlapping targets and keeps rising until max Y.

@export var radius := 0.5
@export var height := 1.0
@export var speed := 8.0
@export var max_y := 10.0

@onready var _col: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _hit_ids: Dictionary = {}
var _active := false


func _ready() -> void:
	add_to_group("trigger_blast_wave")
	monitoring = true
	monitorable = false
	## Broad mask so rocks, balloons, pineapples, oranges, crates all register.
	collision_layer = 0
	collision_mask = 0x7FFFFFFF
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_apply_shape()
	_active = true
	set_physics_process(true)


func configure(p_radius: float, p_height: float, p_speed: float, p_max_y: float) -> void:
	radius = maxf(p_radius, 0.05)
	height = maxf(p_height, 0.05)
	speed = maxf(p_speed, 0.01)
	max_y = p_max_y
	_apply_shape()


func start_wave(p_radius: float, p_height: float, p_speed: float, p_max_y: float) -> void:
	configure(p_radius, p_height, p_speed, p_max_y)


func _apply_shape() -> void:
	if _col and _col.shape is CylinderShape3D:
		var cyl := _col.shape as CylinderShape3D
		cyl.radius = radius
		cyl.height = height
	elif _col:
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		_col.shape = cyl

	if _mesh and _mesh.mesh is CylinderMesh:
		var mesh := _mesh.mesh as CylinderMesh
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position.y += speed * delta
	## Keep pinned to the blast plane in case anything nudges Z.
	# (Z is set by the trigger on spawn; leave X alone.)
	if global_position.y >= max_y:
		_dissipate()


func _dissipate() -> void:
	_active = false
	set_physics_process(false)
	monitoring = false
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	_try_destroy(body)


func _on_area_entered(area: Area3D) -> void:
	## Some setups put the shootable script on a parent of an Area3D.
	_try_destroy(area)
	if area.get_parent() is Node3D:
		_try_destroy(area.get_parent() as Node3D)


func _try_destroy(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node == self:
		return

	var victim := _resolve_destroyable(node)
	if victim == null:
		return
	if victim.is_in_group("trigger_point"):
		return

	var id := victim.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true

	if victim.has_method("start_destroyed_process"):
		victim.start_destroyed_process()
	elif victim.has_method("hit_by_player"):
		victim.hit_by_player(999, Vector2.ZERO)


func _resolve_destroyable(node: Node) -> Node:
	var cur: Node = node
	## Walk up a few parents so we hit RockInstance / Balloon / Pineapple roots.
	for _i in 6:
		if cur == null:
			return null
		if cur.is_in_group("trigger_point") or cur.is_in_group("trigger_blast_wave"):
			return null
		if cur.has_method("start_destroyed_process") or cur.has_method("hit_by_player"):
			return cur
		if cur.is_in_group("Target"):
			return cur
		cur = cur.get_parent()
	return null
