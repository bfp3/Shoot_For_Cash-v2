extends Node3D
## Shared one-shot VFX pool. Warm up gradually after start; overflow instances free after play.
## Group: `vfx_pool`. Call: VfxPool.play("rock_destroy", global_pos)

class_name VfxPoolManager

const DEFAULT_LIFETIME := 5.0

@export_group("Pool Sizes")
@export var pool_rocks := 8
@export var pool_crate := 2
@export var pool_crate_for_cash := 2
@export var pool_hazard := 2
@export var pool_smokecan := 2
@export var pool_rock_hit := 4
@export var pool_balloon := 2
@export var pool_oranges := 4
@export var pool_orange_hit := 2
@export var pool_pineapples := 1

@export_group("Warmup")
## Instances created per idle frame while filling pools.
@export_range(1, 8, 1) var warmup_per_frame := 1
## Frames to wait after tree ready before warm-up begins.
@export_range(0, 120, 1) var warmup_delay_frames := 30

@export_group("Templates")
@export var scene_rock_destroy: PackedScene
@export var scene_crate_destroy: PackedScene
@export var scene_crate_for_cash_destroy: PackedScene
@export var scene_hazard_destroy: PackedScene
@export var scene_smokecan_destroy: PackedScene
@export var scene_rock_hit: PackedScene
@export var scene_balloon_destroy: PackedScene
@export var scene_orange_destroy: PackedScene
@export var scene_orange_hit: PackedScene
@export var scene_pineapple_destroy: PackedScene

var _idle: Dictionary = {} ## StringName -> Array[Node3D]
var _busy: Dictionary = {} ## StringName -> Array[Node3D]
var _targets: Dictionary = {} ## StringName -> int
var _scenes: Dictionary = {} ## StringName -> PackedScene
var _warmup_queue: Array[StringName] = []
var _warming := false


func _ready() -> void:
	add_to_group("vfx_pool")
	_scenes = {
		&"rock_destroy": scene_rock_destroy,
		&"crate_destroy": scene_crate_destroy,
		&"crate_for_cash_destroy": scene_crate_for_cash_destroy,
		&"hazard_destroy": scene_hazard_destroy,
		&"smokecan_destroy": scene_smokecan_destroy,
		&"rock_hit": scene_rock_hit,
		&"balloon_destroy": scene_balloon_destroy,
		&"orange_destroy": scene_orange_destroy,
		&"orange_hit": scene_orange_hit,
		&"pineapple_destroy": scene_pineapple_destroy,
	}
	_targets = {
		&"rock_destroy": pool_rocks,
		&"crate_destroy": pool_crate,
		&"crate_for_cash_destroy": pool_crate_for_cash,
		&"hazard_destroy": pool_hazard,
		&"smokecan_destroy": pool_smokecan,
		&"rock_hit": pool_rock_hit,
		&"balloon_destroy": pool_balloon,
		&"orange_destroy": pool_oranges,
		&"orange_hit": pool_orange_hit,
		&"pineapple_destroy": pool_pineapples,
	}
	for key in _scenes.keys():
		_idle[key] = []
		_busy[key] = []
	call_deferred("_begin_warmup")


func _begin_warmup() -> void:
	for _i in warmup_delay_frames:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	for key in _targets.keys():
		var need: int = int(_targets[key])
		for _n in need:
			_warmup_queue.append(key)
	_warming = true


func _process(_delta: float) -> void:
	if not _warming:
		return
	var made := 0
	while made < warmup_per_frame and not _warmup_queue.is_empty():
		var key: StringName = _warmup_queue.pop_front()
		var inst := _spawn_instance(key, false)
		if inst:
			_idle[key].append(inst)
		made += 1
	if _warmup_queue.is_empty():
		_warming = false
		set_process(false)


## Play a pooled cue at a world position. Returns the instance (or null).
func play(cue: StringName, at: Vector3, lifetime: float = DEFAULT_LIFETIME) -> Node3D:
	var key := cue
	if not _scenes.has(key):
		push_warning("VfxPool: unknown cue '%s'" % String(key))
		return null
	var inst: Node3D = null
	var idle: Array = _idle.get(key, [])
	if not idle.is_empty():
		inst = idle.pop_back()
	else:
		## Overflow — temporary instance, freed after play.
		inst = _spawn_instance(key, true)
	if inst == null:
		return null
	_busy[key].append(inst)
	inst.visible = true
	inst.global_position = at
	_play_aoe(inst)
	_schedule_release(key, inst, lifetime)
	return inst


func play_rock_destroy(at: Vector3) -> Node3D:
	return play(&"rock_destroy", at)


func play_crate_destroy(at: Vector3) -> Node3D:
	return play(&"crate_destroy", at)


func play_crate_for_cash_destroy(at: Vector3) -> Node3D:
	return play(&"crate_for_cash_destroy", at)


func play_hazard_destroy(at: Vector3) -> Node3D:
	return play(&"hazard_destroy", at)


func play_smokecan_destroy(at: Vector3) -> Node3D:
	return play(&"smokecan_destroy", at)


func play_rock_hit(at: Vector3) -> Node3D:
	return play(&"rock_hit", at)


func play_balloon_destroy(at: Vector3) -> Node3D:
	return play(&"balloon_destroy", at)


func play_orange_destroy(at: Vector3) -> Node3D:
	return play(&"orange_destroy", at)


func play_orange_hit(at: Vector3) -> Node3D:
	return play(&"orange_hit", at)


func play_pineapple_destroy(at: Vector3) -> Node3D:
	return play(&"pineapple_destroy", at)


static func get_pool(tree: SceneTree) -> VfxPoolManager:
	if tree == null:
		return null
	return tree.get_first_node_in_group("vfx_pool") as VfxPoolManager


func _spawn_instance(key: StringName, overflow: bool) -> Node3D:
	var packed: PackedScene = _scenes.get(key)
	if packed == null:
		push_warning("VfxPool: missing PackedScene for '%s'" % String(key))
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.visible = false
	node.set_meta("vfx_overflow", overflow)
	node.set_meta("vfx_cue", key)
	add_child(node)
	if node is Node3D:
		node.top_level = true
	return node


func _play_aoe(inst: Node) -> void:
	if inst == null:
		return
	if "play_particles" in inst:
		inst.set("play_particles", true)
		return
	## Fallback: restart any GPUParticles3D children.
	for child in inst.get_children():
		if child is GPUParticles3D:
			var gp := child as GPUParticles3D
			gp.emitting = false
			gp.restart()
			gp.emitting = true


func _schedule_release(key: StringName, inst: Node3D, lifetime: float) -> void:
	var token := inst.get_instance_id()
	get_tree().create_timer(maxf(lifetime, 0.5), true, false, true).timeout.connect(
		func () -> void:
			if not is_instance_valid(inst) or inst.get_instance_id() != token:
				return
			_release(key, inst),
		CONNECT_ONE_SHOT
	)


func _release(key: StringName, inst: Node3D) -> void:
	if not is_instance_valid(inst):
		return
	var busy: Array = _busy.get(key, [])
	busy.erase(inst)
	_busy[key] = busy
	_stop_emitters(inst)
	inst.visible = false
	inst.global_position = Vector3(0, -9999, 0)
	if bool(inst.get_meta("vfx_overflow", false)):
		inst.queue_free()
		return
	var idle: Array = _idle.get(key, [])
	var cap: int = int(_targets.get(key, 0))
	if idle.size() >= cap:
		inst.queue_free()
		return
	idle.append(inst)
	_idle[key] = idle


func _stop_emitters(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	for child in node.get_children():
		_stop_emitters(child)
