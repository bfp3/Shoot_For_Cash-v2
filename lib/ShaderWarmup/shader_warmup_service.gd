extends Node
## Centralized shader / pipeline warm-up for Compatibility + Web (HTML5).
##
## Godot's ubershader pipeline precompilation and shader baker do NOT work on
## the Compatibility renderer (used by this project and required for Web).
## The only reliable fix is to actually draw every material / particle /
## environment variant for at least one frame before gameplay.
##
## This service auto-discovers resources under gameplay folders so new content
## is included without maintaining a hand-written list.

signal progress(done: int, total: int, label: String)
signal finished

const SCAN_ROOTS: PackedStringArray = [
	"res://res/",
	"res://ch/",
	"res://lib/",
]

## Environments / materials only — do NOT instantiate these huge level scenes.
const LIGHT_SCAN_ROOTS: PackedStringArray = [
	"res://sc/All_level_layouts/",
]

## Only these folders auto-instantiate particle scenes (keeps Web boot reasonable).
const PARTICLE_SCENE_ROOTS: PackedStringArray = [
	"res://res/Particles/",
	"res://res/Explosion_paid_patreon/",
]

## Folders skipped while walking (examples, editor junk, unused prototypes).
const SKIP_DIR_NAMES: PackedStringArray = [
	"addons",
	"example",
	"spare_parts_removed_to_optimise",
	".godot",
	"unfiled",
]

## Skip obvious unused duplicates when auto-adding particle scenes.
const SKIP_NAME_FRAGMENTS: PackedStringArray = [
	"backup",
	"_ORIG",
	"_original",
	"_old",
]

## Always warm these gameplay scenes even if particle text-scan misses them.
const PRIORITY_SCENES: PackedStringArray = [
	"res://ch/Rocks/Rock_Instance.tscn",
	"res://ch/Rocks/Balloon.tscn",
	"res://ch/Rocks/Orange.tscn",
	"res://ch/Rocks/Pineapple.tscn",
	"res://ch/Rocks/PlayerBalloon.tscn",
	"res://ch/Rocks/Rock_Instance_balloon_carrier.tscn",
	"res://ch/bullets_all/Bullet_visual_1.tscn",
	"res://ch/bullets_all/Bullet_stage_1.tscn",
	"res://ch/Egg/Egg_cage.tscn",
	"res://res/Particles/Smoke_particles/SmokeQuick.tscn",
	"res://res/Particles/Smoke_particles/Smoke_lingering.tscn",
	"res://res/Particles/sparks_01.tscn",
	"res://res/Particles/FireExplosion.tscn",
	"res://res/Particles/Explosion.tscn",
	"res://res/Particles/Explosion_red.tscn",
	"res://res/Particles/Explosion_small_impact_shot.tscn",
	"res://res/Particles/MuzzleParticles.tscn",
	"res://ch/weapons/bullet-glow.tscn",
	"res://res/Explosion_paid_patreon/mini_mech_explosion.tscn",
	"res://res/Explosion_paid_patreon/smoke_cloud.tscn",
]

## How many discovered items to draw per yield (Web needs frequent yields).
@export var items_per_batch: int = 3
## Extra frames to leave each batch on-screen so GL compiles the draw.
@export var settle_frames: int = 2

var is_complete: bool = false
var is_warming: bool = false

var _booth_root: Node
var _world: Node3D
var _camera: Camera3D
var _world_env: WorldEnvironment
var _mesh_box: MeshInstance3D
var _mesh_sphere: MeshInstance3D
var _mesh_quad: MeshInstance3D
var _canvas_layer: CanvasLayer
var _canvas_rect: ColorRect
var _overlay: CanvasLayer
var _overlay_label: Label
var _overlay_bar: ProgressBar
var _light: DirectionalLight3D


func _ready() -> void:
	# Desktop can batch more aggressively; Web needs frequent yields.
	if OS.get_name() != "Web":
		items_per_batch = 8
		settle_frames = 1


func ensure_warmed() -> void:
	if is_complete:
		return
	if is_warming:
		await finished
		return
	await _run_warmup()


## Warm a single PackedScene during a level transition fade (optional hook).
func warm_packed_scene(scene: PackedScene, label: String = "level assets") -> void:
	if scene == null:
		return
	_ensure_booth()
	_overlay_set_visible(true)
	_overlay_update(0, 1, "Compiling %s..." % label)
	_warm_scene_instance(scene, label)
	await _settle()
	_teardown_booth_contents()
	if _camera:
		_camera.current = false
	_overlay_set_visible(false)
	if _booth_root:
		_booth_root.visible = false


func _run_warmup() -> void:
	is_warming = true
	_ensure_booth()
	_overlay_set_visible(true)
	_overlay_update(0, 1, "Scanning graphics...")

	var jobs: Array[Dictionary] = []
	_collect_jobs(jobs)

	var total := jobs.size()
	if total == 0:
		_finish_warmup()
		return

	var done := 0
	_overlay_update(done, total, "Compiling shaders...")

	var batch_count := 0
	for job in jobs:
		_execute_job(job)
		done += 1
		batch_count += 1
		progress.emit(done, total, str(job.get("label", "")))
		_overlay_update(done, total, str(job.get("label", "Compiling shaders...")))

		if batch_count >= items_per_batch:
			batch_count = 0
			await _settle()
			_teardown_booth_contents()

	await _settle()
	_teardown_booth_contents()
	await _warm_render_features()
	_finish_warmup()


func _warm_render_features() -> void:
	# Exercise common Compatibility pipeline feature toggles once.
	_overlay_update(1, 1, "Finalizing pipelines...")
	_mesh_box.visible = true
	_mesh_sphere.visible = true
	_mesh_quad.visible = true
	var dummy := StandardMaterial3D.new()
	dummy.albedo_color = Color(0.7, 0.7, 0.7)
	_mesh_box.material_override = dummy
	_mesh_sphere.material_override = dummy
	_mesh_quad.material_override = dummy

	_light.shadow_enabled = true
	await _settle()
	_light.shadow_enabled = false
	await _settle()
	_light.shadow_enabled = true

	var omni := OmniLight3D.new()
	omni.position = Vector3(0, 1.5, -1)
	omni.light_energy = 2.0
	omni.shadow_enabled = true
	_world.add_child(omni)
	await _settle()
	omni.queue_free()

	var unshaded := StandardMaterial3D.new()
	unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	unshaded.albedo_color = Color(1, 1, 1, 0.4)
	unshaded.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mesh_quad.material_override = unshaded
	await _settle()

	# Particle-sheet style (common in this project for smoke/sparks).
	var particle_mat := StandardMaterial3D.new()
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particle_mat.particles_anim_h_frames = 2
	particle_mat.particles_anim_v_frames = 2
	_mesh_quad.material_override = particle_mat
	await _settle()

	var additive := particle_mat.duplicate() as StandardMaterial3D
	additive.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mesh_quad.material_override = additive
	await _settle()


func _finish_warmup() -> void:
	_teardown_booth_contents()
	_overlay_set_visible(false)
	if _camera:
		_camera.current = false
	# Keep booth nodes for optional mid-game warm calls, but hide them.
	if _booth_root:
		_booth_root.queue_free()
	is_warming = false
	is_complete = true
	finished.emit()


# -----------------------------------------------------------------------------
# Discovery
# -----------------------------------------------------------------------------

func _collect_jobs(jobs: Array[Dictionary]) -> void:
	var seen_paths: Dictionary = {}

	for path in PRIORITY_SCENES:
		_add_scene_job(jobs, seen_paths, path, "priority scene")

	# Materials / shaders / environments across gameplay folders.
	for root in SCAN_ROOTS:
		_walk_directory(root, jobs, seen_paths, false)
	for root in LIGHT_SCAN_ROOTS:
		_walk_directory(root, jobs, seen_paths, false)
	# Particle VFX scenes only from dedicated folders (+ priority list above).
	for root in PARTICLE_SCENE_ROOTS:
		_walk_directory(root, jobs, seen_paths, true)


func _path_is_skipped(path: String) -> bool:
	var lower := path.to_lower()
	for frag in SKIP_NAME_FRAGMENTS:
		if lower.contains(frag.to_lower()):
			return true
	return false


func _walk_directory(path: String, jobs: Array[Dictionary], seen: Dictionary, include_scenes: bool) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full := path.path_join(entry)
		if dir.current_is_dir():
			if entry in SKIP_DIR_NAMES:
				entry = dir.get_next()
				continue
			_walk_directory(full + "/", jobs, seen, include_scenes)
		else:
			_classify_file(full, jobs, seen, include_scenes)
		entry = dir.get_next()
	dir.list_dir_end()


func _classify_file(path: String, jobs: Array[Dictionary], seen: Dictionary, include_scenes: bool) -> void:
	if _path_is_skipped(path):
		return
	var ext := path.get_extension().to_lower()
	match ext:
		"gdshader":
			_add_shader_job(jobs, seen, path)
		"tres", "res":
			_add_resource_job(jobs, seen, path)
		"tscn":
			if include_scenes and _tscn_looks_like_vfx(path):
				_add_scene_job(jobs, seen, path, "particle scene")
		_:
			pass


func _tscn_looks_like_vfx(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	# Bound read — particle scenes are small; huge levels still match early.
	var text := f.get_buffer(mini(f.get_length(), 256000)).get_string_from_utf8()
	f.close()
	return (
		text.contains('type="GPUParticles3D"')
		or text.contains('type="CPUParticles3D"')
		or text.contains('type="GPUParticles2D"')
		or text.contains('type="CPUParticles2D"')
	)


func _add_scene_job(jobs: Array[Dictionary], seen: Dictionary, path: String, kind: String) -> void:
	if seen.has(path):
		return
	if not ResourceLoader.exists(path):
		return
	seen[path] = true
	jobs.append({
		"type": "scene",
		"path": path,
		"label": "%s: %s" % [kind, path.get_file()],
	})


func _add_shader_job(jobs: Array[Dictionary], seen: Dictionary, path: String) -> void:
	if seen.has(path):
		return
	seen[path] = true
	jobs.append({
		"type": "shader",
		"path": path,
		"label": "shader: %s" % path.get_file(),
	})


func _add_resource_job(jobs: Array[Dictionary], seen: Dictionary, path: String) -> void:
	if seen.has(path):
		return
	# Cheap header sniff before a full load.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var header := f.get_buffer(mini(f.get_length(), 512)).get_string_from_utf8()
	f.close()
	# ParticleProcessMaterial is warmed via particle scenes, not mesh samples.
	var is_material := header.contains('type="StandardMaterial3D"') \
		or header.contains('type="ShaderMaterial"') \
		or header.contains('type="ORMMaterial3D"') \
		or header.contains('type="BaseMaterial3D"') \
		or header.contains('type="CanvasItemMaterial"')
	var is_env := header.contains('type="Environment"')
	if not is_material and not is_env:
		return
	seen[path] = true
	jobs.append({
		"type": "environment" if is_env else "material",
		"path": path,
		"label": ("%s: %s") % ["environment" if is_env else "material", path.get_file()],
	})


# -----------------------------------------------------------------------------
# Execution
# -----------------------------------------------------------------------------

func _execute_job(job: Dictionary) -> void:
	var path: String = job.get("path", "")
	match str(job.get("type", "")):
		"scene":
			var packed := load(path) as PackedScene
			if packed:
				_warm_scene_instance(packed, path.get_file())
		"material":
			var mat := load(path)
			if mat is Material:
				_apply_material_variants(mat as Material)
		"environment":
			var env := load(path)
			if env is Environment:
				_world_env.environment = env
		"shader":
			_warm_shader_file(path)
		_:
			pass


func _warm_shader_file(path: String) -> void:
	var shader := load(path) as Shader
	if shader == null:
		return
	var code := shader.code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if code.contains("shader_type canvas_item") or code.contains("shader_type canvas_item;"):
		_canvas_rect.material = mat
		_canvas_rect.visible = true
	elif code.contains("shader_type sky"):
		var sky := Sky.new()
		sky.sky_material = mat
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		_world_env.environment = env
	else:
		# spatial / particles — draw on mesh samples
		_apply_material_variants(mat)


func _apply_material_variants(mat: Material) -> void:
	if mat is CanvasItemMaterial or (mat is ShaderMaterial and _shader_is_canvas(mat as ShaderMaterial)):
		_canvas_rect.material = mat
		_canvas_rect.visible = true
		return

	# Multiple mesh shapes catch billboard / particle / opaque path differences.
	_mesh_box.material_override = mat
	_mesh_box.visible = true
	_mesh_sphere.material_override = mat
	_mesh_sphere.visible = true
	_mesh_quad.material_override = mat
	_mesh_quad.visible = true

	# Transparent materials often compile a second pipeline when alpha is used.
	if mat is BaseMaterial3D:
		var base := mat as BaseMaterial3D
		if base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			# Briefly exercise alpha blend path without permanently mutating shared resources.
			var clone := base.duplicate() as BaseMaterial3D
			clone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			clone.albedo_color.a = 0.5
			_mesh_quad.material_override = clone


func _shader_is_canvas(mat: ShaderMaterial) -> bool:
	if mat.shader == null:
		return false
	return mat.shader.code.contains("shader_type canvas_item")


func _warm_scene_instance(packed: PackedScene, _label: String) -> void:
	var inst := packed.instantiate()
	if inst == null:
		return
	_sanitize_for_warmup(inst)
	_world.add_child(inst)
	if inst is Node3D:
		(inst as Node3D).global_position = Vector3(0, 0, -4)
	_force_draw_tree(inst)


func _force_draw_tree(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node is Node3D:
		(node as Node3D).visible = true
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.visible = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		p.visible = true
		p.emitting = true
		p.one_shot = false
		p.restart()
		# Keep amount modest so Web warm-up stays responsive.
		if p.amount > 32:
			p.amount = 32
	if node is CPUParticles3D:
		var cp := node as CPUParticles3D
		cp.visible = true
		cp.emitting = true
		cp.restart()
	if node is GPUParticles2D:
		var p2 := node as GPUParticles2D
		p2.visible = true
		p2.emitting = true
		p2.restart()
	if node is CPUParticles2D:
		var cp2 := node as CPUParticles2D
		cp2.visible = true
		cp2.emitting = true
		cp2.restart()
	if node is Decal:
		(node as Decal).visible = true
	for child in node.get_children():
		_force_draw_tree(child)


func _sanitize_for_warmup(node: Node) -> void:
	# Prevent gameplay scripts from hiding meshes, playing SFX, or freeing nodes.
	node.set_script(null)
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is AnimationPlayer:
		(node as AnimationPlayer).active = false
	if node is AnimationTree:
		(node as AnimationTree).active = false
	if node is AudioStreamPlayer:
		var a := node as AudioStreamPlayer
		a.autoplay = false
		a.volume_db = -80.0
		a.stop()
	elif node is AudioStreamPlayer2D:
		var a2 := node as AudioStreamPlayer2D
		a2.autoplay = false
		a2.volume_db = -80.0
		a2.stop()
	elif node is AudioStreamPlayer3D:
		var a3 := node as AudioStreamPlayer3D
		a3.autoplay = false
		a3.volume_db = -80.0
		a3.stop()
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_sanitize_for_warmup(child)


func _settle() -> void:
	# Compatibility/Web: shaders compile when the GPU actually draws a frame.
	for i in settle_frames:
		await get_tree().process_frame


func _teardown_booth_contents() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		if child == _camera or child == _light or child == _world_env \
				or child == _mesh_box or child == _mesh_sphere or child == _mesh_quad:
			continue
		child.queue_free()
	_mesh_box.material_override = null
	_mesh_sphere.material_override = null
	_mesh_quad.material_override = null
	_mesh_box.visible = false
	_mesh_sphere.visible = false
	_mesh_quad.visible = false
	_canvas_rect.material = null
	_canvas_rect.visible = false


# -----------------------------------------------------------------------------
# Booth / overlay construction
# -----------------------------------------------------------------------------

func _ensure_booth() -> void:
	if _booth_root != null and is_instance_valid(_booth_root):
		_booth_root.visible = true
		_camera.current = true
		return

	_booth_root = Node.new()
	_booth_root.name = "ShaderWarmupBooth"
	add_child(_booth_root)

	# Fullscreen black overlay hides the warm-up draws from the player.
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	_booth_root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_overlay_label = Label.new()
	_overlay_label.text = "Preparing graphics..."
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_overlay_label)

	_overlay_bar = ProgressBar.new()
	_overlay_bar.custom_minimum_size = Vector2(420, 18)
	_overlay_bar.max_value = 1.0
	_overlay_bar.value = 0.0
	_overlay_bar.show_percentage = true
	vbox.add_child(_overlay_bar)

	# Tiny on-screen 3D booth. Overlay covers it, but it still draws into the
	# default viewport — required for Compatibility/WebGL shader compile.
	_world = Node3D.new()
	_world.name = "WarmupWorld"
	_booth_root.add_child(_world)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.position = Vector3(0, 0, 3)
	_world.add_child(_camera)

	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-45, 35, 0)
	_light.shadow_enabled = true
	_world.add_child(_light)

	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	_world_env.environment = env
	_world.add_child(_world_env)

	_mesh_box = MeshInstance3D.new()
	_mesh_box.mesh = BoxMesh.new()
	_mesh_box.position = Vector3(-0.8, 0, -2)
	_mesh_box.visible = false
	_world.add_child(_mesh_box)

	_mesh_sphere = MeshInstance3D.new()
	_mesh_sphere.mesh = SphereMesh.new()
	_mesh_sphere.position = Vector3(0.0, 0, -2)
	_mesh_sphere.visible = false
	_world.add_child(_mesh_sphere)

	_mesh_quad = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	_mesh_quad.mesh = quad
	_mesh_quad.position = Vector3(0.8, 0, -2)
	_mesh_quad.visible = false
	_world.add_child(_mesh_quad)

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 127
	_booth_root.add_child(_canvas_layer)
	_canvas_rect = ColorRect.new()
	_canvas_rect.size = Vector2(64, 64)
	_canvas_rect.position = Vector2(8, 8)
	_canvas_rect.visible = false
	_canvas_layer.add_child(_canvas_rect)


func _overlay_set_visible(v: bool) -> void:
	if _overlay:
		_overlay.visible = v


func _overlay_update(done: int, total: int, label: String) -> void:
	if _overlay_label:
		_overlay_label.text = label if label != "" else "Preparing graphics..."
	if _overlay_bar:
		_overlay_bar.max_value = maxi(total, 1)
		_overlay_bar.value = done
