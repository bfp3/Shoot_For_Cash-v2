"""
Shoot For Cash — stylized wooden crate (frame + slats + X-braces + rivets)

Matches the chunky game-crate look: thick edge frame, recessed face planks,
diagonal X braces, dark iron rivets, and a painterly wood / metal shader.

HOW TO RUN (Blender UI)
  1. Open Blender (empty scene is fine).
  2. Scripting workspace → Text → Open → this file.
  3. Run Script → object "Crate" appears at the origin (~1×1×1 m).

HOW TO EXPORT FOR GODOT
  1. Run this script (materials are baked to UV textures for glTF).
  2. Select "Crate".
  3. File → Export → glTF 2.0 (.glb)  OR use --export path.glb
  4. In Godot: reimport; if anything still looks inside-out, set material Cull Mode = Disabled.

WHY MATERIALS LOOKED WRONG BEFORE
  Procedural Blender nodes (Noise/Wave/Object coords) do NOT travel through glTF.
  This script now bakes albedo (+ roughness) to images so Godot gets real textures.

WHY FACES LOOKED FLIPPED
  Transformed braces / rivets can invert winding; overlapping remove_doubles
  also mangled normals. The script now skips merge-welds and recalcs normals.

CLI example:
  blender --background --python tools/make_crate.py -- --size 1.0 --export crate_wood.glb
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector


# ---------------------------------------------------------------------------
# Defaults tuned to the reference crate
# ---------------------------------------------------------------------------
DEFAULT_SIZE = 1.0
DEFAULT_PLANKS = 1
DEFAULT_PLANK_GAP = 0.118
DEFAULT_FRAME = 0.195
DEFAULT_SHELL = 0.138
DEFAULT_BRACE_THICK = 0.155
DEFAULT_BRACE_DEPTH = 0.142
DEFAULT_RIVET = 0.028
DEFAULT_BEVEL = 0.014
DEFAULT_BEVEL_SEGMENTS = 5
OBJECT_NAME = "Crate"
COLLECTION_NAME = "ShootForCash_Crates"


def _parse_args(argv: list[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build a stylized wooden crate.")
	parser.add_argument("--size", type=float, default=DEFAULT_SIZE)
	parser.add_argument("--planks", type=int, default=DEFAULT_PLANKS, help="Slats per face (1–7).")
	parser.add_argument("--plank-gap", type=float, default=DEFAULT_PLANK_GAP)
	parser.add_argument("--frame", type=float, default=DEFAULT_FRAME)
	parser.add_argument("--shell", type=float, default=DEFAULT_SHELL)
	parser.add_argument("--brace", type=float, default=DEFAULT_BRACE_THICK, help="X-brace plank width.")
	parser.add_argument("--bevel", type=float, default=DEFAULT_BEVEL)
	parser.add_argument("--bevel-segments", type=int, default=DEFAULT_BEVEL_SEGMENTS)
	parser.add_argument("--rivet", type=float, default=DEFAULT_RIVET, help="Rivet radius.")
	parser.add_argument("--no-rivets", action="store_true")
	parser.add_argument("--no-braces", action="store_true")
	parser.add_argument("--gold", action="store_true", help="Gold wood tint (cash crate).")
	parser.add_argument("--export", type=str, default="")
	parser.add_argument("--no-clear", action="store_true")
	if "--" in argv:
		argv = argv[argv.index("--") + 1 :]
	else:
		argv = []
	ns = parser.parse_args(argv)
	ns.clear = not ns.no_clear
	ns.rivets = not ns.no_rivets
	ns.braces = not ns.no_braces
	return ns


def _ensure_collection(name: str) -> bpy.types.Collection:
	col = bpy.data.collections.get(name)
	if col is None:
		col = bpy.data.collections.new(name)
		bpy.context.scene.collection.children.link(col)
	return col


def _clear_previous(name: str, collection: bpy.types.Collection) -> None:
	for obj in list(collection.objects):
		if obj.name.startswith(name):
			bpy.data.objects.remove(obj, do_unlink=True)
	obj = bpy.data.objects.get(name)
	if obj is not None:
		bpy.data.objects.remove(obj, do_unlink=True)


# ---------------------------------------------------------------------------
# Materials — stylized wood grain + dark iron rivets
# ---------------------------------------------------------------------------
def _set_principled(bsdf: bpy.types.Node, *, metallic: float, roughness: float) -> None:
	if "Metallic" in bsdf.inputs:
		bsdf.inputs["Metallic"].default_value = metallic
	if "Roughness" in bsdf.inputs:
		bsdf.inputs["Roughness"].default_value = roughness
	# Blender 4 renamed Specular → Specular IOR Level on some builds; ignore if absent.
	for key, val in (("Specular", 0.35), ("Specular IOR Level", 0.35)):
		if key in bsdf.inputs:
			bsdf.inputs[key].default_value = val
			break


def _make_wood_material(name: str, gold: bool) -> bpy.types.Material:
	mat = bpy.data.materials.get(name)
	if mat is None:
		mat = bpy.data.materials.new(name=name)
	mat.use_nodes = True
	nt = mat.node_tree
	nodes = nt.nodes
	links = nt.links
	nodes.clear()

	out = nodes.new("ShaderNodeOutputMaterial")
	out.location = (900, 0)
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")
	bsdf.location = (650, 0)
	links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	_set_principled(bsdf, metallic=0.0, roughness=0.78)

	tex_coord = nodes.new("ShaderNodeTexCoord")
	tex_coord.location = (-900, 0)
	mapping = nodes.new("ShaderNodeMapping")
	mapping.location = (-700, 0)
	mapping.inputs["Scale"].default_value = (2.2, 0.55, 2.2)
	links.new(tex_coord.outputs["Object"], mapping.inputs["Vector"])

	# Long grain streaks (wave along X in object space after mapping).
	wave = nodes.new("ShaderNodeTexWave")
	wave.location = (-480, 120)
	wave.wave_type = "BANDS"
	wave.bands_direction = "X"
	wave.inputs["Scale"].default_value = 4.5
	wave.inputs["Distortion"].default_value = 2.8
	wave.inputs["Detail"].default_value = 3.0
	if "Detail Scale" in wave.inputs:
		wave.inputs["Detail Scale"].default_value = 1.4
	links.new(mapping.outputs["Vector"], wave.inputs["Vector"])

	noise = nodes.new("ShaderNodeTexNoise")
	noise.location = (-480, -140)
	noise.inputs["Scale"].default_value = 7.0
	noise.inputs["Detail"].default_value = 8.0
	noise.inputs["Roughness"].default_value = 0.55
	links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

	# Compatible with Blender 3.6 + 4.x (avoid ShaderNodeMix FLOAT API differences).
	add = nodes.new("ShaderNodeMath")
	add.location = (-260, 40)
	add.operation = "ADD"
	links.new(wave.outputs["Fac"], add.inputs[0])
	links.new(noise.outputs["Fac"], add.inputs[1])
	mul = nodes.new("ShaderNodeMath")
	mul.location = (-80, 40)
	mul.operation = "MULTIPLY"
	mul.inputs[1].default_value = 0.55
	links.new(add.outputs["Value"], mul.inputs[0])

	ramp = nodes.new("ShaderNodeValToRGB")
	ramp.location = (120, 40)
	links.new(mul.outputs["Value"], ramp.inputs["Fac"])

	# Warm medium-brown with darker grain + lighter edge wear tones.
	if gold:
		ramp.color_ramp.elements[0].position = 0.18
		ramp.color_ramp.elements[0].color = (0.35, 0.22, 0.05, 1.0)
		ramp.color_ramp.elements[1].position = 0.85
		ramp.color_ramp.elements[1].color = (0.95, 0.78, 0.28, 1.0)
		mid = ramp.color_ramp.elements.new(0.5)
		mid.color = (0.82, 0.62, 0.18, 1.0)
	else:
		ramp.color_ramp.elements[0].position = 0.15
		ramp.color_ramp.elements[0].color = (0.12, 0.07, 0.04, 1.0)
		ramp.color_ramp.elements[1].position = 0.88
		ramp.color_ramp.elements[1].color = (0.62, 0.42, 0.24, 1.0)
		mid = ramp.color_ramp.elements.new(0.48)
		mid.color = (0.42, 0.27, 0.15, 1.0)
		hi = ramp.color_ramp.elements.new(0.72)
		hi.color = (0.55, 0.38, 0.22, 1.0)

	links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])

	# Subtle bump from the same grain.
	bump = nodes.new("ShaderNodeBump")
	bump.location = (400, -200)
	bump.inputs["Strength"].default_value = 0.35
	bump.inputs["Distance"].default_value = 0.08
	links.new(mul.outputs["Value"], bump.inputs["Height"])
	links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

	return mat


def _make_metal_material(name: str) -> bpy.types.Material:
	mat = bpy.data.materials.get(name)
	if mat is None:
		mat = bpy.data.materials.new(name=name)
	mat.use_nodes = True
	nt = mat.node_tree
	nodes = nt.nodes
	links = nt.links
	nodes.clear()

	out = nodes.new("ShaderNodeOutputMaterial")
	out.location = (400, 0)
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")
	bsdf.location = (150, 0)
	links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

	# Dark charcoal / dull iron from the reference.
	bsdf.inputs["Base Color"].default_value = (0.12, 0.12, 0.13, 1.0)
	_set_principled(bsdf, metallic=0.85, roughness=0.42)

	noise = nodes.new("ShaderNodeTexNoise")
	noise.location = (-200, -80)
	noise.inputs["Scale"].default_value = 18.0
	noise.inputs["Detail"].default_value = 4.0
	bump = nodes.new("ShaderNodeBump")
	bump.location = (-20, -80)
	bump.inputs["Strength"].default_value = 0.15
	links.new(noise.outputs["Fac"], bump.inputs["Height"])
	links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return mat


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
def _add_box(bm: bmesh.types.BMesh, center: Vector, size: Vector, matrix: Matrix | None = None) -> None:
	hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
	coords = [
		Vector((-hx, -hy, -hz)),
		Vector((hx, -hy, -hz)),
		Vector((hx, hy, -hz)),
		Vector((-hx, hy, -hz)),
		Vector((-hx, -hy, hz)),
		Vector((hx, -hy, hz)),
		Vector((hx, hy, hz)),
		Vector((-hx, hy, hz)),
	]
	flip = False
	if matrix is not None:
		coords = [matrix @ c for c in coords]
		# Negative-scale / reflection flips winding → inside-out faces in Godot.
		if matrix.to_3x3().determinant() < 0.0:
			flip = True
	else:
		coords = [c + center for c in coords]
	verts = [bm.verts.new(c) for c in coords]
	bm.verts.ensure_lookup_table()
	faces = [
		(0, 1, 2, 3),
		(4, 7, 6, 5),
		(0, 4, 5, 1),
		(1, 5, 6, 2),
		(2, 6, 7, 3),
		(3, 7, 4, 0),
	]
	for idxs in faces:
		order = tuple(reversed(idxs)) if flip else idxs
		bm.faces.new([verts[i] for i in order])


def _plank_layout(inner: float, plank_count: int, gap: float) -> list[tuple[float, float]]:
	usable = inner - gap * (plank_count - 1)
	width = usable / float(plank_count)
	start = -inner * 0.5 + width * 0.5
	return [(start + i * (width + gap), width) for i in range(plank_count)]


def _face_basis(axis: str, sign: float) -> tuple[Vector, Vector, Vector]:
	"""Return (outward normal, u tangent, v tangent) for a cube face."""
	if axis == "x":
		n = Vector((sign, 0, 0))
		u = Vector((0, 1, 0))
		v = Vector((0, 0, 1))
	elif axis == "y":
		n = Vector((0, sign, 0))
		u = Vector((1, 0, 0))
		v = Vector((0, 0, 1))
	else:
		n = Vector((0, 0, sign))
		u = Vector((1, 0, 0))
		v = Vector((0, 1, 0))
	return n, u, v


def _build_wood_bmesh(
	size: float,
	planks: int,
	plank_gap: float,
	frame: float,
	shell: float,
	brace_w: float,
	brace_depth: float,
	with_braces: bool,
) -> bmesh.types.BMesh:
	bm = bmesh.new()
	half = size * 0.5
	inner = size - 2.0 * frame
	planks = max(1, min(7, planks))
	layout = _plank_layout(inner, planks, plank_gap)

	# --- 12-edge frame (chunky beams) ---
	for y_sign in (-1.0, 1.0):
		for z_sign in (-1.0, 1.0):
			_add_box(
				bm,
				Vector((0.0, y_sign * (half - frame * 0.5), z_sign * (half - frame * 0.5))),
				Vector((size, frame, frame)),
			)
	for x_sign in (-1.0, 1.0):
		for z_sign in (-1.0, 1.0):
			_add_box(
				bm,
				Vector((x_sign * (half - frame * 0.5), 0.0, z_sign * (half - frame * 0.5))),
				Vector((frame, size - 2.0 * frame, frame)),
			)
	for x_sign in (-1.0, 1.0):
		for y_sign in (-1.0, 1.0):
			_add_box(
				bm,
				Vector((x_sign * (half - frame * 0.5), y_sign * (half - frame * 0.5), 0.0)),
				Vector((frame, frame, size - 2.0 * frame)),
			)

	# --- Recessed face slats ---
	# ±Z: planks run along X (horizontal grain on top/bottom-facing… wait ±Z is top/bottom in Blender Z-up)
	# Reference: top has horizontal slats; sides have vertical slats.
	# Blender Z-up: +Z top → slats along X (vary Y). Sides ±X/±Y → vertical slats (vary along face tangent).

	# Top / bottom (±Z): horizontal planks (vary along Y, extend along X)
	for z_sign in (-1.0, 1.0):
		z = z_sign * (half - shell * 0.5 - 0.004)
		for center_y, width_y in layout:
			_add_box(bm, Vector((0.0, center_y, z)), Vector((inner, width_y, shell)))

	# Front / back (±Y): vertical planks (vary along X, extend along Z)
	for y_sign in (-1.0, 1.0):
		y = y_sign * (half - shell * 0.5 - 0.008)
		for center_x, width_x in layout:
			_add_box(bm, Vector((center_x, y, 0.0)), Vector((width_x, shell, inner)))

	# Left / right (±X): vertical planks (vary along Y, extend along Z)
	for x_sign in (-1.0, 1.0):
		x = x_sign * (half - shell * 0.5 - 0.008)
		for center_y, width_y in layout:
			_add_box(bm, Vector((x, center_y, 0.0)), Vector((shell, width_y, inner)))

	# --- X braces on the four vertical faces ---
	if with_braces:
		brace_len = inner * 1.12
		for axis, sign in (("x", 1.0), ("x", -1.0), ("y", 1.0), ("y", -1.0)):
			n, u, v = _face_basis(axis, sign)
			face_center = n * (half - brace_depth * 0.5 - 0.002)
			# Orient local +Z along face outward; then spin 45° / -45° around that axis.
			base_q = n.to_track_quat("Z", "Y")
			for angle_deg in (45.0, -45.0):
				q = base_q @ Quaternion(Vector((0, 0, 1)), math.radians(angle_deg))
				mat = Matrix.Translation(face_center) @ q.to_matrix().to_4x4()
				_add_box(bm, Vector((0.0, 0.0, 0.0)), Vector((brace_len, brace_w, brace_depth)), mat)

	# Do NOT remove_doubles — welding overlapping plank corners flips / collapses faces.
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _build_rivet_bmesh(size: float, frame: float, rivet_r: float) -> bmesh.types.BMesh:
	"""Domed rivets at frame corners (all faces) + X-brace centers on vertical faces."""
	bm = bmesh.new()
	half = size * 0.5
	# Slightly proud of the outer frame face.
	proud = 0.006
	inner_edge = half - frame * 0.5

	# Helper: icosphere-ish via bmesh ops create_uvsphere then transform.
	def add_rivet(pos: Vector, outward: Vector) -> None:
		# Flattened dome: sphere scaled on outward axis.
		geo = bmesh.ops.create_uvsphere(
			bm,
			u_segments=10,
			v_segments=8,
			radius=rivet_r,
		)
		verts = geo["verts"]
		# Squash slightly along outward so it reads as a bolt head.
		out = outward.normalized()
		# Build orthonormal basis with out as Z.
		tmp = Vector((0, 0, 1)) if abs(out.z) < 0.9 else Vector((1, 0, 0))
		x_axis = out.cross(tmp).normalized()
		y_axis = out.cross(x_axis).normalized()
		# Scale: flatter along out.
		sx, sy, sz = 1.0, 1.0, 0.55
		for v in verts:
			local = v.co.copy()
			# local is already in sphere space; remap axes then translate.
			world = (
				x_axis * (local.x * sx)
				+ y_axis * (local.y * sy)
				+ out * (local.z * sz)
				+ pos
			)
			v.co = world

	# Corner rivets: three on each cube corner (one per adjacent face) — matches reference density.
	for x_sign in (-1.0, 1.0):
		for y_sign in (-1.0, 1.0):
			for z_sign in (-1.0, 1.0):
				# On +X face near this corner
				add_rivet(
					Vector((x_sign * (half + proud), y_sign * inner_edge, z_sign * inner_edge)),
					Vector((x_sign, 0, 0)),
				)
				add_rivet(
					Vector((x_sign * inner_edge, y_sign * (half + proud), z_sign * inner_edge)),
					Vector((0, y_sign, 0)),
				)
				add_rivet(
					Vector((x_sign * inner_edge, y_sign * inner_edge, z_sign * (half + proud))),
					Vector((0, 0, z_sign)),
				)

	# Center rivet on each vertical face (X brace crossing).
	for axis, sign in (("x", 1.0), ("x", -1.0), ("y", 1.0), ("y", -1.0)):
		n, _u, _v = _face_basis(axis, sign)
		add_rivet(n * (half + proud), n)

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _mesh_from_bmesh(name: str, bm: bmesh.types.BMesh) -> bpy.types.Mesh:
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.update()
	if hasattr(mesh, "calc_normals"):
		try:
			mesh.calc_normals()
		except Exception:
			pass
	return mesh


def _fix_normals(obj: bpy.types.Object) -> None:
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.normals_make_consistent(inside=False)
	try:
		bpy.ops.mesh.set_normals_from_faces()
	except Exception:
		pass
	bpy.ops.object.mode_set(mode="OBJECT")
	# Clear custom split normals that confuse glTF / Godot.
	try:
		bpy.ops.mesh.customdata_custom_splitnormals_clear()
	except Exception:
		pass


def _apply_bevel(obj: bpy.types.Object, width: float, segments: int) -> None:
	if width <= 0.0:
		return
	mod = obj.modifiers.new(name="Bevel", type="BEVEL")
	mod.width = width
	mod.segments = max(1, segments)
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(28.0)
	mod.miter_outer = "MITER_ARC"
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.modifier_apply(modifier=mod.name)


def _smart_uv(obj: bpy.types.Object) -> None:
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	try:
		bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
	except TypeError:
		try:
			bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
		except Exception:
			bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.02)
	bpy.ops.object.mode_set(mode="OBJECT")


def _shade_smooth(obj: bpy.types.Object, angle_deg: float = 35.0) -> None:
	mesh = obj.data
	for poly in mesh.polygons:
		poly.use_smooth = True
	if hasattr(mesh, "use_auto_smooth"):
		mesh.use_auto_smooth = True
		mesh.auto_smooth_angle = math.radians(angle_deg)
	else:
		try:
			bpy.ops.object.shade_smooth()
		except Exception:
			pass


def _ensure_uv_map(obj: bpy.types.Object) -> None:
	mesh = obj.data
	if mesh.uv_layers:
		return
	_smart_uv(obj)


def _bake_wood_to_textures(obj: bpy.types.Object, mat: bpy.types.Material, res: int = 1024) -> None:
	"""Bake procedural wood into UV textures so glTF/Godot keep the look."""
	_ensure_uv_map(obj)
	# Cycles required for bake.
	scene = bpy.context.scene
	prev_engine = scene.render.engine
	scene.render.engine = "CYCLES"
	if hasattr(scene.cycles, "device"):
		# Prefer CPU for headless reliability.
		try:
			scene.cycles.device = "CPU"
		except Exception:
			pass
	scene.cycles.samples = 16

	albedo = bpy.data.images.get("CrateWoodAlbedo")
	if albedo is None:
		albedo = bpy.data.images.new("CrateWoodAlbedo", width=res, height=res, alpha=False)
	else:
		albedo.scale(res, res)

	nt = mat.node_tree
	nodes = nt.nodes
	links = nt.links

	# Active image node required as bake target.
	img_node = nodes.new("ShaderNodeTexImage")
	img_node.location = (400, 300)
	img_node.image = albedo
	nodes.active = img_node
	for n in nodes:
		n.select = n == img_node

	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	# Assign only this material during bake.
	obj.data.materials.clear()
	obj.data.materials.append(mat)

	try:
		bpy.ops.object.bake(
			type="DIFFUSE",
			pass_filter={"COLOR"},
			margin=4,
			use_clear=True,
		)
	except TypeError:
		# Older Blender bake signature.
		bpy.ops.object.bake(type="DIFFUSE", margin=4, use_clear=True)
	except Exception as exc:
		print(f"[make_crate] Bake failed ({exc}); falling back to solid Principled colors.")
		scene.render.engine = prev_engine
		_make_export_principled(mat, albedo=None, roughness=0.78, metallic=0.0, color=(0.45, 0.30, 0.17, 1.0))
		return

	# Rebuild a glTF-friendly Principled using the baked albedo.
	_make_export_principled(mat, albedo=albedo, roughness=0.78, metallic=0.0)
	scene.render.engine = prev_engine
	print("[make_crate] Baked wood albedo for glTF export.")


def _make_export_principled(
	mat: bpy.types.Material,
	*,
	albedo: bpy.types.Image | None,
	roughness: float,
	metallic: float,
	color: tuple[float, float, float, float] = (0.45, 0.30, 0.17, 1.0),
) -> None:
	mat.use_nodes = True
	nt = mat.node_tree
	nodes = nt.nodes
	links = nt.links
	nodes.clear()
	out = nodes.new("ShaderNodeOutputMaterial")
	out.location = (400, 0)
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")
	bsdf.location = (150, 0)
	links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	_set_principled(bsdf, metallic=metallic, roughness=roughness)
	if albedo is not None:
		tex = nodes.new("ShaderNodeTexImage")
		tex.location = (-200, 0)
		tex.image = albedo
		links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	else:
		bsdf.inputs["Base Color"].default_value = color


def _prepare_metal_for_export(mat: bpy.types.Material) -> None:
	## Solid Principled exports cleanly (no procedural dependency).
	_make_export_principled(
		mat,
		albedo=None,
		roughness=0.42,
		metallic=0.85,
		color=(0.12, 0.12, 0.13, 1.0),
	)


def _join_objects(target: bpy.types.Object, others: list[bpy.types.Object]) -> bpy.types.Object:
	bpy.ops.object.select_all(action="DESELECT")
	target.select_set(True)
	bpy.context.view_layer.objects.active = target
	for o in others:
		if o is None or o == target:
			continue
		o.select_set(True)
	if len(bpy.context.selected_objects) > 1:
		bpy.ops.object.join()
	return bpy.context.view_layer.objects.active


def build_crate(args: argparse.Namespace) -> bpy.types.Object:
	collection = _ensure_collection(COLLECTION_NAME)
	if args.clear:
		_clear_previous(OBJECT_NAME, collection)

	wood_mat = _make_wood_material("CrateWoodGoldMat" if args.gold else "CrateWoodMat", gold=args.gold)
	metal_mat = _make_metal_material("CrateIronMat")

	wood_bm = _build_wood_bmesh(
		size=args.size,
		planks=args.planks,
		plank_gap=args.plank_gap,
		frame=args.frame,
		shell=args.shell,
		brace_w=args.brace,
		brace_depth=DEFAULT_BRACE_DEPTH * (args.size / DEFAULT_SIZE),
		with_braces=args.braces,
	)
	wood_mesh = _mesh_from_bmesh(OBJECT_NAME + "Wood", wood_bm)
	wood_obj = bpy.data.objects.new(OBJECT_NAME + "_wood", wood_mesh)
	collection.objects.link(wood_obj)
	wood_mesh.materials.append(wood_mat)

	bpy.ops.object.select_all(action="DESELECT")
	wood_obj.select_set(True)
	bpy.context.view_layer.objects.active = wood_obj
	_apply_bevel(wood_obj, args.bevel, args.bevel_segments)
	_smart_uv(wood_obj)
	_fix_normals(wood_obj)
	_shade_smooth(wood_obj)

	## Bake procedural wood → image BEFORE joining (cleaner bake target).
	_bake_wood_to_textures(wood_obj, wood_mat)
	_prepare_metal_for_export(metal_mat)

	parts: list[bpy.types.Object] = []
	if args.rivets:
		rivet_bm = _build_rivet_bmesh(args.size, args.frame, args.rivet * (args.size / DEFAULT_SIZE))
		rivet_mesh = _mesh_from_bmesh(OBJECT_NAME + "Rivets", rivet_bm)
		rivet_obj = bpy.data.objects.new(OBJECT_NAME + "_rivets", rivet_mesh)
		collection.objects.link(rivet_obj)
		rivet_mesh.materials.append(metal_mat)
		bpy.ops.object.select_all(action="DESELECT")
		rivet_obj.select_set(True)
		bpy.context.view_layer.objects.active = rivet_obj
		_fix_normals(rivet_obj)
		_shade_smooth(rivet_obj, 60.0)
		parts.append(rivet_obj)

	crate = _join_objects(wood_obj, parts)
	crate.name = OBJECT_NAME
	_fix_normals(crate)
	_shade_smooth(crate)

	bpy.ops.object.select_all(action="DESELECT")
	crate.select_set(True)
	bpy.context.view_layer.objects.active = crate
	return crate


def export_glb(obj: bpy.types.Object, path: str) -> None:
	out = Path(path)
	if not out.is_absolute():
		try:
			script_dir = Path(__file__).resolve().parent
		except NameError:
			script_dir = Path.cwd()
		out = script_dir / out
	out.parent.mkdir(parents=True, exist_ok=True)

	for o in bpy.context.selected_objects:
		o.select_set(False)
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj

	# Pack images so the .glb is self-contained for Godot.
	for img in bpy.data.images:
		if img.name.startswith("CrateWood"):
			try:
				img.pack()
			except Exception:
				pass

	kwargs = dict(
		filepath=str(out),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_texcoords=True,
		export_normals=True,
		export_materials="EXPORT",
		export_yup=True,
	)
	# Blender 4 uses export_image_format; 3.6 may differ — try both.
	try:
		bpy.ops.export_scene.gltf(**kwargs, export_image_format="AUTO")
	except TypeError:
		bpy.ops.export_scene.gltf(**kwargs)
	print(f"[make_crate] Exported: {out}")


def main() -> None:
	args = _parse_args(sys.argv)
	obj = build_crate(args)
	print(
		f"[make_crate] Built '{obj.name}' size={args.size} planks={args.planks} "
		f"braces={args.braces} rivets={args.rivets} gold={args.gold} "
		f"verts={len(obj.data.vertices)}"
	)
	if args.export:
		export_glb(obj, args.export)


if __name__ == "__main__":
	main()
