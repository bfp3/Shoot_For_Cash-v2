"""
Shoot For Cash — stylized wooden barrel (staves + iron hoops + rivets)

Same wood / metal look as tools/make_crate.py, ~1×1×1 m footprint/height.
Procedural wood is baked to UV textures so glTF → Godot keeps the grain.

HOW TO RUN (Blender UI)
  1. Open Blender (empty scene is fine).
  2. Scripting workspace → Text → Open → this file.
  3. Run Script → object "Barrel" at the origin.

HOW TO EXPORT FOR GODOT
  1. Run this script (waits for wood bake).
  2. Select "Barrel".
  3. File → Export → glTF 2.0 (.glb)  OR use --export path.glb
  4. Suggested: res://unfiled/Blender_custom_assets/barrel_wood.glb

CLI:
  blender --background --python tools/make_barrel.py -- --size 1.0 --export barrel_wood.glb
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector


# ---------------------------------------------------------------------------
# Defaults — matched to crate base size (1 m)
# ---------------------------------------------------------------------------
DEFAULT_SIZE = 1.0
DEFAULT_STAVES = 12
DEFAULT_STAVE_GAP = 0.01
DEFAULT_STAVE_THICK = 0.055
DEFAULT_BULGE = 0.06
DEFAULT_HOOPS = 4
DEFAULT_HOOP_HEIGHT = 0.055
DEFAULT_HOOP_THICK = 0.028
DEFAULT_RIVET = 0.018
DEFAULT_BEVEL = 0.012
DEFAULT_BEVEL_SEGMENTS = 3
OBJECT_NAME = "Barrel"
COLLECTION_NAME = "ShootForCash_Barrels"


def _parse_args(argv: list[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build a stylized wooden barrel.")
	parser.add_argument("--size", type=float, default=DEFAULT_SIZE, help="Height / max diameter in meters.")
	parser.add_argument("--staves", type=int, default=DEFAULT_STAVES, help="Vertical wood planks (8–24).")
	parser.add_argument("--stave-gap", type=float, default=DEFAULT_STAVE_GAP)
	parser.add_argument("--stave-thick", type=float, default=DEFAULT_STAVE_THICK)
	parser.add_argument("--bulge", type=float, default=DEFAULT_BULGE, help="Extra mid-radius for barrel belly.")
	parser.add_argument("--hoops", type=int, default=DEFAULT_HOOPS, help="Iron bands (2–6).")
	parser.add_argument("--hoop-height", type=float, default=DEFAULT_HOOP_HEIGHT)
	parser.add_argument("--hoop-thick", type=float, default=DEFAULT_HOOP_THICK)
	parser.add_argument("--bevel", type=float, default=DEFAULT_BEVEL)
	parser.add_argument("--bevel-segments", type=int, default=DEFAULT_BEVEL_SEGMENTS)
	parser.add_argument("--rivet", type=float, default=DEFAULT_RIVET)
	parser.add_argument("--no-rivets", action="store_true")
	parser.add_argument("--no-lids", action="store_true", help="Skip top/bottom wood lids.")
	parser.add_argument("--gold", action="store_true", help="Gold wood tint.")
	parser.add_argument("--export", type=str, default="")
	parser.add_argument("--no-clear", action="store_true")
	if "--" in argv:
		argv = argv[argv.index("--") + 1 :]
	else:
		argv = []
	ns = parser.parse_args(argv)
	ns.clear = not ns.no_clear
	ns.rivets = not ns.no_rivets
	ns.lids = not ns.no_lids
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
# Materials (same look as make_crate.py)
# ---------------------------------------------------------------------------
def _set_principled(bsdf: bpy.types.Node, *, metallic: float, roughness: float) -> None:
	if "Metallic" in bsdf.inputs:
		bsdf.inputs["Metallic"].default_value = metallic
	if "Roughness" in bsdf.inputs:
		bsdf.inputs["Roughness"].default_value = roughness
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
	## Vertical grain along barrel height (Z).
	mapping.inputs["Scale"].default_value = (0.55, 0.55, 2.4)
	links.new(tex_coord.outputs["Object"], mapping.inputs["Vector"])

	wave = nodes.new("ShaderNodeTexWave")
	wave.location = (-480, 120)
	wave.wave_type = "BANDS"
	wave.bands_direction = "Z"
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
	_make_export_principled(
		mat,
		albedo=None,
		roughness=0.42,
		metallic=0.85,
		color=(0.12, 0.12, 0.13, 1.0),
	)


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------
def _barrel_radius_at_height(t: float, r_end: float, r_mid: float) -> float:
	"""t in [0,1] bottom→top. Sin bulge peaking at mid-height."""
	w = math.sin(t * math.pi)
	return r_end + (r_mid - r_end) * w


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


def _build_wood_barrel_bmesh(
	size: float,
	staves: int,
	stave_gap: float,
	stave_thick: float,
	bulge: float,
	with_lids: bool,
) -> bmesh.types.BMesh:
	bm = bmesh.new()
	height = size
	r_mid = size * 0.5
	r_end = max(r_mid - bulge, r_mid * 0.72)
	staves = max(8, min(24, staves))

	# Chord width for each stave at mid radius, minus gap.
	arc = (math.tau / staves) - (stave_gap / max(r_mid, 0.01))
	stave_width = max(0.04, r_mid * arc * 0.95)

	for i in range(staves):
		angle = (i / float(staves)) * math.tau
		# Approximate curved stave as a few stacked boxes following the silhouette.
		stacks = 6
		for s in range(stacks):
			t0 = s / float(stacks)
			t1 = (s + 1) / float(stacks)
			t = (t0 + t1) * 0.5
			z = -height * 0.5 + height * t
			seg_h = height / float(stacks) * 1.02
			r = _barrel_radius_at_height(t, r_end, r_mid)
			radial = r - stave_thick * 0.5
			c = math.cos(angle)
			s_ = math.sin(angle)
			center = Vector((c * radial, s_ * radial, z))
			# Orient local +Y outward, +Z up, +X tangent.
			x_axis = Vector((-s_, c, 0.0))
			y_axis = Vector((c, s_, 0.0))
			z_axis = Vector((0.0, 0.0, 1.0))
			rot = Matrix((x_axis, y_axis, z_axis)).transposed()
			mat = Matrix.Translation(center) @ rot.to_4x4()
			_add_box(bm, Vector((0, 0, 0)), Vector((stave_width, stave_thick, seg_h)), mat)

	if with_lids:
		# Top / bottom lids — flat wood discs approximated as cylinders via many wedges,
		# or a simple thick disc using create_circle extruded. Use flat boxes as planks.
		for z_sign in (-1.0, 1.0):
			z = z_sign * (height * 0.5 - stave_thick * 0.35)
			lid_r = r_end - stave_thick * 0.15
			lid_planks = max(4, staves // 2)
			plank_w = (lid_r * 2.0) / float(lid_planks) * 0.92
			for p in range(lid_planks):
				x = -lid_r + plank_w * 0.5 + p * (lid_r * 2.0 / float(lid_planks))
				# Clip length by circle: chord length at this x.
				half_chord = math.sqrt(max(lid_r * lid_r - x * x, 0.0))
				if half_chord < 0.02:
					continue
				_add_box(
					bm,
					Vector((x, 0.0, z)),
					Vector((plank_w * 0.95, half_chord * 2.0, stave_thick * 0.7)),
				)

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _build_hoop_bmesh(
	size: float,
	hoop_count: int,
	hoop_height: float,
	hoop_thick: float,
	bulge: float,
	stave_thick: float,
	rivet_r: float,
	with_rivets: bool,
) -> bmesh.types.BMesh:
	bm = bmesh.new()
	height = size
	r_mid = size * 0.5
	r_end = max(r_mid - bulge, r_mid * 0.72)
	hoop_count = max(2, min(6, hoop_count))

	# Evenly spaced along height, inset from ends.
	for h in range(hoop_count):
		t = 0.12 + 0.76 * (h / float(max(hoop_count - 1, 1)))
		z = -height * 0.5 + height * t
		r = _barrel_radius_at_height(t, r_end, r_mid) + hoop_thick * 0.15
		# Torus-like band via create_cone / circle extrude — use tube of boxes as segments.
		segs = 32
		for i in range(segs):
			a0 = (i / float(segs)) * math.tau
			a1 = ((i + 1) / float(segs)) * math.tau
			amid = (a0 + a1) * 0.5
			c = math.cos(amid)
			s = math.sin(amid)
			center = Vector((c * r, s * r, z))
			chord = 2.0 * r * math.sin(math.pi / segs) * 1.05
			x_axis = Vector((-s, c, 0.0))
			y_axis = Vector((c, s, 0.0))
			z_axis = Vector((0.0, 0.0, 1.0))
			rot = Matrix((x_axis, y_axis, z_axis)).transposed()
			mat = Matrix.Translation(center) @ rot.to_4x4()
			_add_box(bm, Vector((0, 0, 0)), Vector((chord, hoop_thick, hoop_height)), mat)

			if with_rivets and i % 4 == 0:
				# Rivet on outer face of hoop.
				pos = Vector((c * (r + hoop_thick * 0.55), s * (r + hoop_thick * 0.55), z))
				_add_rivet(bm, pos, Vector((c, s, 0.0)), rivet_r)

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _add_rivet(bm: bmesh.types.BMesh, pos: Vector, outward: Vector, rivet_r: float) -> None:
	geo = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=rivet_r)
	verts = geo["verts"]
	out = outward.normalized()
	tmp = Vector((0, 0, 1)) if abs(out.z) < 0.9 else Vector((1, 0, 0))
	x_axis = out.cross(tmp).normalized()
	y_axis = out.cross(x_axis).normalized()
	sx, sy, sz = 1.0, 1.0, 0.55
	for v in verts:
		local = v.co.copy()
		v.co = x_axis * (local.x * sx) + y_axis * (local.y * sy) + out * (local.z * sz) + pos


def _mesh_from_bmesh(name: str, bm: bmesh.types.BMesh) -> bpy.types.Mesh:
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.update()
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


def _shade_smooth(obj: bpy.types.Object, angle_deg: float = 40.0) -> None:
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
	if not obj.data.uv_layers:
		_smart_uv(obj)


def _bake_wood_to_textures(obj: bpy.types.Object, mat: bpy.types.Material, res: int = 1024) -> None:
	_ensure_uv_map(obj)
	scene = bpy.context.scene
	prev_engine = scene.render.engine
	scene.render.engine = "CYCLES"
	try:
		scene.cycles.device = "CPU"
	except Exception:
		pass
	scene.cycles.samples = 16

	albedo = bpy.data.images.get("BarrelWoodAlbedo")
	if albedo is None:
		albedo = bpy.data.images.new("BarrelWoodAlbedo", width=res, height=res, alpha=False)
	else:
		albedo.scale(res, res)

	nt = mat.node_tree
	nodes = nt.nodes
	img_node = nodes.new("ShaderNodeTexImage")
	img_node.location = (400, 300)
	img_node.image = albedo
	nodes.active = img_node
	for n in nodes:
		n.select = n == img_node

	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	obj.data.materials.clear()
	obj.data.materials.append(mat)

	try:
		bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=4, use_clear=True)
	except TypeError:
		try:
			bpy.ops.object.bake(type="DIFFUSE", margin=4, use_clear=True)
		except Exception as exc:
			print(f"[make_barrel] Bake failed ({exc}); solid color fallback.")
			scene.render.engine = prev_engine
			_make_export_principled(mat, albedo=None, roughness=0.78, metallic=0.0)
			return
	except Exception as exc:
		print(f"[make_barrel] Bake failed ({exc}); solid color fallback.")
		scene.render.engine = prev_engine
		_make_export_principled(mat, albedo=None, roughness=0.78, metallic=0.0)
		return

	_make_export_principled(mat, albedo=albedo, roughness=0.78, metallic=0.0)
	scene.render.engine = prev_engine
	print("[make_barrel] Baked wood albedo for glTF export.")


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


def build_barrel(args: argparse.Namespace) -> bpy.types.Object:
	collection = _ensure_collection(COLLECTION_NAME)
	if args.clear:
		_clear_previous(OBJECT_NAME, collection)

	wood_mat = _make_wood_material("BarrelWoodGoldMat" if args.gold else "BarrelWoodMat", gold=args.gold)
	metal_mat = _make_metal_material("BarrelIronMat")

	wood_bm = _build_wood_barrel_bmesh(
		size=args.size,
		staves=args.staves,
		stave_gap=args.stave_gap,
		stave_thick=args.stave_thick,
		bulge=args.bulge,
		with_lids=args.lids,
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
	_bake_wood_to_textures(wood_obj, wood_mat)
	_prepare_metal_for_export(metal_mat)

	parts: list[bpy.types.Object] = []
	hoop_bm = _build_hoop_bmesh(
		size=args.size,
		hoop_count=args.hoops,
		hoop_height=args.hoop_height,
		hoop_thick=args.hoop_thick,
		bulge=args.bulge,
		stave_thick=args.stave_thick,
		rivet_r=args.rivet * (args.size / DEFAULT_SIZE),
		with_rivets=args.rivets,
	)
	hoop_mesh = _mesh_from_bmesh(OBJECT_NAME + "Hoops", hoop_bm)
	hoop_obj = bpy.data.objects.new(OBJECT_NAME + "_hoops", hoop_mesh)
	collection.objects.link(hoop_obj)
	hoop_mesh.materials.append(metal_mat)
	bpy.ops.object.select_all(action="DESELECT")
	hoop_obj.select_set(True)
	bpy.context.view_layer.objects.active = hoop_obj
	_fix_normals(hoop_obj)
	_shade_smooth(hoop_obj, 50.0)
	parts.append(hoop_obj)

	barrel = _join_objects(wood_obj, parts)
	barrel.name = OBJECT_NAME
	_fix_normals(barrel)
	_shade_smooth(barrel)

	bpy.ops.object.select_all(action="DESELECT")
	barrel.select_set(True)
	bpy.context.view_layer.objects.active = barrel
	return barrel


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

	for img in bpy.data.images:
		if img.name.startswith("BarrelWood"):
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
	try:
		bpy.ops.export_scene.gltf(**kwargs, export_image_format="AUTO")
	except TypeError:
		bpy.ops.export_scene.gltf(**kwargs)
	print(f"[make_barrel] Exported: {out}")


def main() -> None:
	args = _parse_args(sys.argv)
	obj = build_barrel(args)
	print(
		f"[make_barrel] Built '{obj.name}' size={args.size} staves={args.staves} "
		f"hoops={args.hoops} rivets={args.rivets} gold={args.gold} "
		f"verts={len(obj.data.vertices)}"
	)
	if args.export:
		export_glb(obj, args.export)


if __name__ == "__main__":
	main()
