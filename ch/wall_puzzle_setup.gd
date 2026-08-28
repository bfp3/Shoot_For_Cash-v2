extends Node3D
## Crosshair ↔ WallPuzzle solid overlap. Lights + SFX feedback; query via `is_crosshair_overlapping_wall()`.

class_name WallPuzzleSetup

@export var enabled := true
@export var ray_length := 150.0
## When true, sample the reticle circle (not just the center) so any aim overlap counts.
@export var sample_reticle_circle := true
## How many points around the reticle rim to raycast (plus center).
@export_range(4, 16, 1) var reticle_sample_count := 8
## 1 = full hit-radius; lower = tighter sample ring inside the reticle.
@export_range(0.1, 1.0, 0.05) var reticle_sample_radius_scale := 1.0

@onready var wall_puzzle: CSGShape3D = $WallPuzzle
@onready var light_touching: OmniLight3D = $TouchingWallWithCrosshair
@onready var light_allgood: OmniLight3D = $Allgood
@onready var sfx_hum: AudioStreamPlayer = $SFX/OverlappingWallHum
@onready var sfx_toggle: AudioStreamPlayer = $SFX/TurningLightOnOrOff

var _overlapping := false


func _ready() -> void:
	add_to_group("wall_puzzle")
	if wall_puzzle:
		## CSG only blocks / ray-hits when collision is generated from the boolean mesh.
		wall_puzzle.use_collision = true
	_apply_overlap_visuals(false, true)


func _physics_process(_delta: float) -> void:
	if not enabled or wall_puzzle == null:
		return
	var overlapping := _query_crosshair_overlaps_wall()
	if overlapping == _overlapping:
		return
	_overlapping = overlapping
	_apply_overlap_visuals(overlapping, false)


func is_crosshair_overlapping_wall() -> bool:
	return _overlapping


func _apply_overlap_visuals(overlapping: bool, silent: bool) -> void:
	if light_touching:
		light_touching.visible = overlapping
	if light_allgood:
		light_allgood.visible = not overlapping

	if sfx_hum:
		if overlapping:
			if not sfx_hum.playing:
				sfx_hum.play()
		elif sfx_hum.playing:
			sfx_hum.stop()

	if not silent and sfx_toggle:
		sfx_toggle.play()


func _query_crosshair_overlaps_wall() -> bool:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return false
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return false

	var crosshair: Control = player.get("crosshair") as Control
	if crosshair == null or not is_instance_valid(crosshair):
		return false

	var center: Vector2 = crosshair.global_position + Vector2(20.0, 20.0)
	if "CROSSHAIR_CENTER_OFFSET" in player:
		center = crosshair.global_position + player.CROSSHAIR_CENTER_OFFSET

	var radius := 40.0
	if player.has_method("get_current_crosshair_hit_radius"):
		radius = float(player.get_current_crosshair_hit_radius())

	var offsets: Array[Vector2] = [Vector2.ZERO]
	if sample_reticle_circle and radius > 0.5:
		var rim := radius * reticle_sample_radius_scale
		for i in reticle_sample_count:
			var angle := TAU * float(i) / float(reticle_sample_count)
			offsets.append(Vector2(cos(angle), sin(angle)) * rim)

	var space := get_world_3d().direct_space_state
	for offset in offsets:
		if _ray_hits_wall(cam, space, center + offset):
			return true
	return false


func _ray_hits_wall(cam: Camera3D, space: PhysicsDirectSpaceState3D, screen_pos: Vector2) -> bool:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * ray_length)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return _collider_is_wall_puzzle(hit.get("collider"))


func _collider_is_wall_puzzle(collider: Object) -> bool:
	if collider == null:
		return false
	if collider == wall_puzzle:
		return true
	if collider is Node:
		var node := collider as Node
		if wall_puzzle.is_ancestor_of(node) or node == wall_puzzle:
			return true
		## CSG collision may report a transient body parented under the CSG shape.
		var walk: Node = node
		while walk != null:
			if walk == wall_puzzle:
				return true
			if String(walk.name) == "WallPuzzle":
				return true
			walk = walk.get_parent()
	return false
