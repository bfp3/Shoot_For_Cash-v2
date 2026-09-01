extends Node3D
## Crosshair ↔ WallPuzzle solid overlap. Lights + SFX feedback; query via `is_crosshair_overlapping_wall()`.

class_name WallPuzzleSetup

@export var enabled := true
@export var ray_length := 150.0
## When true, sample the full reticle disk (not just the center) so any aim overlap counts.
@export var sample_reticle_circle := true
## Filled-disk density: rays along a grid inside the reticle (higher = fewer edge misses, more cost).
@export_range(2, 10, 1) var reticle_grid_divisions := 5
## Extra concentric rim rings (helps thin edges between grid cells).
@export_range(4, 24, 1) var reticle_rim_samples := 16
## 1 = full hit-radius; raise slightly above 1 if the visual ring feels bigger than the hit radius.
@export_range(0.5, 1.5, 0.05) var reticle_sample_radius_scale := 1.05

@export_group("Strike On Wall Touch")
## When true, first frame the crosshair overlaps solid wall awards a strike.
@export var strike_on_wall_overlap := true

@export_group("Crosshair Knock On Wall Touch")
## When true, first frame the crosshair overlaps solid wall knocks the reticle away (independent of strikes).
@export var knock_crosshair_on_wall_touch := true
## Screen-pixel distance to shove the crosshair away from the touch.
@export_range(20.0, 400.0, 1.0) var knock_crosshair_distance := 140.0
## Seconds to complete the knock shove (higher = slower / smoother).
@export_range(0.02, 1.0, 0.01) var knock_crosshair_duration := 0.15

@export_group("Wall Hit Spawn")
## When true, entering overlap spawns a threat (balloon or rock — pick one flag below).
@export var spawn_on_wall_hit := false
## Spawn a random-cell balloon when the crosshair first hits solid wall.
@export var spawn_balloon_on_hit := false
## Spawn a standard rock when the crosshair first hits solid wall.
@export var spawn_rock_on_hit := false

@onready var wall_puzzle:= $WallPuzzle
@onready var light_touching: OmniLight3D = $TouchingWallWithCrosshair
@onready var light_allgood: OmniLight3D = $Allgood
@onready var sfx_hum: AudioStreamPlayer = $SFX/OverlappingWallHum
@onready var sfx_toggle: AudioStreamPlayer = $SFX/TurningLightOnOrOff

var _overlapping := false


func _ready() -> void:
	add_to_group("wall_puzzle")
	if wall_puzzle:
		## CSG only blocks / ray-hits when collision is generated from the boolean mesh.
		if wall_puzzle is CSGShape3D:
			wall_puzzle.use_collision = true
	_apply_overlap_visuals(false, true)


func _physics_process(_delta: float) -> void:
	if not enabled or wall_puzzle == null:
		return
	var overlapping := _query_crosshair_overlaps_wall()
	if overlapping == _overlapping:
		return
	var entered := overlapping and not _overlapping
	_overlapping = overlapping
	_apply_overlap_visuals(overlapping, false)
	if entered:
		_try_strike_on_wall_hit()
		_try_knock_crosshair_on_wall_hit()
		_try_spawn_on_wall_hit()


func is_crosshair_overlapping_wall() -> bool:
	return _overlapping


func _try_strike_on_wall_hit() -> void:
	if not strike_on_wall_overlap:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and "current_state" in player and "State" in player:
		if player.current_state != player.State.ACTIVE:
			return
	var origin := global_position
	if light_touching:
		origin = light_touching.global_position
	var rocks_container = null
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm != null:
		rocks_container = rm.get("rocks_container")
	if rocks_container == null:
		rocks_container = get_tree().get_first_node_in_group("rocks_container")
	if rocks_container and rocks_container.has_method("set_strike_feedback_origin"):
		rocks_container.set_strike_feedback_origin(origin)
	gl_PlayerState.add_strike()


func _try_knock_crosshair_on_wall_hit() -> void:
	if not knock_crosshair_on_wall_touch:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if "current_state" in player and "State" in player:
		if player.current_state != player.State.ACTIVE:
			return
	_knock_crosshair_away_from_wall(player)


func _try_spawn_on_wall_hit() -> void:
	if not spawn_on_wall_hit:
		return
	var want_balloon := spawn_balloon_on_hit
	var want_rock := spawn_rock_on_hit
	if want_balloon and want_rock:
		push_warning("WallPuzzleSetup: both spawn flags true — spawning rock only.")
		want_balloon = false
	if want_balloon:
		_spawn_wall_hit_balloon()
	elif want_rock:
		_spawn_wall_hit_rock()


func _spawn_wall_hit_balloon() -> void:
	var host := get_tree().get_first_node_in_group("balloon_container")
	if host == null or not host.has_method("spawn_balloon_entry"):
		push_warning("WallPuzzleSetup: no balloon_container to spawn into.")
		return
	host.spawn_balloon_entry({"cmd": "balloon"})


func _spawn_wall_hit_rock() -> void:
	var rocks: RockManager = null
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm != null:
		var container = rm.get("rocks_container")
		if container is RockManager:
			rocks = container
	if rocks == null:
		var scene := get_tree().current_scene
		if scene:
			var node := scene.get_node_or_null("Rocks")
			if node is RockManager:
				rocks = node
	if rocks == null or not rocks.has_method("spawn_threat_rock"):
		push_warning("WallPuzzleSetup: no RockManager.spawn_threat_rock.")
		return
	rocks.spawn_threat_rock("rock")


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

	var space := get_world_3d().direct_space_state
	for offset in _build_reticle_sample_offsets(radius):
		if _ray_hits_wall(cam, space, center + offset):
			return true
	return false


## Filled disk: center + inner grid + outer rim. Catches crescent overlaps at solid edges.
func _build_reticle_sample_offsets(radius: float) -> Array[Vector2]:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if not sample_reticle_circle or radius <= 0.5:
		return offsets

	var r := radius * reticle_sample_radius_scale
	var r2 := r * r

	## Square grid clipped to the circle — covers crescents that rim-only samples miss.
	var divs := maxi(reticle_grid_divisions, 2)
	var step := (r * 2.0) / float(divs)
	for ix in range(divs + 1):
		for iy in range(divs + 1):
			var p := Vector2(-r + step * float(ix), -r + step * float(iy))
			if p.length_squared() <= r2 + 0.01:
				offsets.append(p)

	## Dense rim ring (slightly inside max radius so rays don't skim past thin faces).
	var rim_r := r * 0.98
	for i in reticle_rim_samples:
		var angle := TAU * float(i) / float(reticle_rim_samples)
		offsets.append(Vector2(cos(angle), sin(angle)) * rim_r)

	## Mid ring for thin bars sitting between grid cells.
	var mid_r := r * 0.55
	var mid_count := maxi(reticle_rim_samples / 2, 6)
	for i in mid_count:
		var angle := TAU * float(i) / float(mid_count) + 0.15
		offsets.append(Vector2(cos(angle), sin(angle)) * mid_r)

	return offsets


func _knock_crosshair_away_from_wall(player: Node) -> void:
	var cam: Camera3D = null
	if "camera_3d" in player and player.camera_3d is Camera3D:
		cam = player.camera_3d
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return

	var crosshair: Control = player.get("crosshair") as Control
	if crosshair == null or not is_instance_valid(crosshair):
		return

	var center: Vector2 = crosshair.global_position + Vector2(20.0, 20.0)
	if "CROSSHAIR_CENTER_OFFSET" in player:
		center = crosshair.global_position + player.CROSSHAIR_CENTER_OFFSET

	var radius := 40.0
	if player.has_method("get_current_crosshair_hit_radius"):
		radius = float(player.get_current_crosshair_hit_radius())

	var space := get_world_3d().direct_space_state
	var hit_offset_sum := Vector2.ZERO
	var hit_count := 0
	var miss_offset_sum := Vector2.ZERO
	var miss_count := 0
	## Quadrant hit counts: 0=up(-Y), 1=right(+X), 2=down(+Y), 3=left(-X)
	var quad_hits := [0, 0, 0, 0]
	var nearest_normal_screen := Vector2.ZERO
	var nearest_dist := INF

	for offset in _build_reticle_sample_offsets(radius):
		var hit := _ray_wall_hit(cam, space, center + offset)
		if hit.is_empty():
			miss_offset_sum += offset
			miss_count += 1
			continue
		hit_offset_sum += offset
		hit_count += 1
		if offset.y < -0.01:
			quad_hits[0] += 1
		elif offset.y > 0.01:
			quad_hits[2] += 1
		if offset.x > 0.01:
			quad_hits[1] += 1
		elif offset.x < -0.01:
			quad_hits[3] += 1
		var dist := offset.length_squared()
		if dist < nearest_dist:
			nearest_dist = dist
			var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
			var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
			if hit_normal.length_squared() > 0.0001:
				var a := cam.unproject_position(hit_pos)
				var b := cam.unproject_position(hit_pos + hit_normal.normalized())
				nearest_normal_screen = b - a

	var push := Vector2.ZERO
	## Prefer free reticle space: if the wall only covers the bottom, misses average upward.
	if miss_count > 0 and miss_offset_sum.length_squared() > 0.25:
		push = miss_offset_sum.normalized()
	elif hit_count > 0 and hit_offset_sum.length_squared() > 0.25:
		push = -hit_offset_sum.normalized()
	else:
		## Wall covers most of the disk — shove toward the least-covered quadrant.
		var best_q := 0
		var best_hits := 999999
		for q in 4:
			if int(quad_hits[q]) < best_hits:
				best_hits = int(quad_hits[q])
				best_q = q
		match best_q:
			0:
				push = Vector2(0, -1) ## screen up
			1:
				push = Vector2(1, 0)
			2:
				push = Vector2(0, 1) ## screen down
			_:
				push = Vector2(-1, 0)
		if nearest_normal_screen.length_squared() > 0.01:
			## Blend in surface normal if it has a clear screen component.
			var n2 := nearest_normal_screen.normalized()
			if absf(n2.dot(push)) > 0.15:
				push = (push + n2).normalized()

	if push.length_squared() < 0.01:
		push = Vector2(0, -1)

	var delta := push * knock_crosshair_distance
	if player.has_method("knock_crosshair_by"):
		player.knock_crosshair_by(delta, knock_crosshair_duration)
	elif "target_crosshair_position" in player:
		player.target_crosshair_position += delta


func _ray_wall_hit(cam: Camera3D, space: PhysicsDirectSpaceState3D, screen_pos: Vector2) -> Dictionary:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * ray_length)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	if not _collider_is_wall_puzzle(hit.get("collider")):
		return {}
	return hit


func _ray_hits_wall(cam: Camera3D, space: PhysicsDirectSpaceState3D, screen_pos: Vector2) -> bool:
	return not _ray_wall_hit(cam, space, screen_pos).is_empty()


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
