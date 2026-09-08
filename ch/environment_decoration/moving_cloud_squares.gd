extends Node3D
## Moves every child cloud along world Z: spawn at `spawn_z`, travel to `end_z`, then loop back.
## Attach to a Node3D that already has cloud meshes as children (e.g. Clouds_Squares).

@export var enabled := true
@export var spawn_z := 500.0
@export var end_z := -10.0
## Units per second toward `end_z`. Even-indexed children use this.
@export var speed_a := 12.0
## Odd-indexed children use this when `alternate_speeds` is on.
@export var speed_b := 22.0
@export var alternate_speeds := true
## Odd-indexed children travel the opposite way (end → spawn).
@export var alternate_direction := false
## -1 = spawn_z → end_z (500 toward -10). +1 = the other way.
@export_range(-1.0, 1.0) var travel_sign := -1.0
@export var face_camera := true
## Spread children along the path on start so they are not stacked at spawn_z.
@export var stagger_on_start := true

var _tracks: Array[Dictionary] = []


func _ready() -> void:
	_tracks.clear()
	if not enabled:
		set_process(false)
		return
	var far_z := spawn_z
	var near_z := end_z
	var span := far_z - near_z
	if absf(span) < 0.001:
		span = 1.0
	var sign := -1.0 if travel_sign < 0.0 else 1.0
	var kids := _cloud_children()
	var count := kids.size()
	for i in count:
		var node := kids[i]
		var speed := speed_a
		if alternate_speeds and (i % 2) == 1:
			speed = speed_b
		var dir := sign
		if alternate_direction and (i % 2) == 1:
			dir = -sign
		var home_xy := Vector2(node.global_position.x, node.global_position.y)
		if stagger_on_start and count > 1:
			var t := float(i) / float(count)
			if dir < 0.0:
				node.global_position.z = far_z - t * span
			else:
				node.global_position.z = near_z + t * span
		else:
			node.global_position.z = far_z if dir < 0.0 else near_z
		node.global_position.x = home_xy.x
		node.global_position.y = home_xy.y
		_tracks.append({
			"node": node,
			"speed": maxf(speed, 0.0),
			"dir": dir,
			"home_xy": home_xy,
			"scale": node.scale,
		})
		if face_camera:
			_face_cloud(node, node.scale)


func _process(delta: float) -> void:
	if not enabled:
		return
	var far_z := spawn_z
	var near_z := end_z
	for track in _tracks:
		var node: Node3D = track["node"]
		if node == null or not is_instance_valid(node):
			continue
		var dir: float = track["dir"]
		var home_xy: Vector2 = track["home_xy"]
		var p := node.global_position
		p.x = home_xy.x
		p.y = home_xy.y
		p.z += dir * float(track["speed"]) * delta
		if dir < 0.0 and p.z <= near_z:
			p.z = far_z
		elif dir > 0.0 and p.z >= far_z:
			p.z = near_z
		node.global_position = p
		if face_camera:
			_face_cloud(node, track["scale"])


func _cloud_children() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in get_children():
		if child is Node3D:
			out.append(child)
	return out


func _face_cloud(node: Node3D, kept_scale: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	## QuadMesh faces +Z; look_at aims -Z, so aim at a point opposite the camera.
	var away: Vector3 = node.global_position * 2.0 - cam.global_position
	if node.global_position.is_equal_approx(away):
		return
	node.look_at(away, Vector3.UP)
	node.scale = kept_scale
