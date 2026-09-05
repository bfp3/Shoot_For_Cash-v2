"""
Shoot For Cash — low-poly hot air balloon (envelope + metal collar/struts)

Matches the faceted red/cream envelope, dark metal neck ring, and four
inward-angled holder struts. No crate / basket.

HOW TO RUN (Blender UI)
  1. Open Blender (empty scene is fine).
  2. Scripting workspace → Text → Open → this file.
  3. Run Script → "HotAirBalloon" appears at the origin (strut bottoms on Z=0).

HOW TO EXPORT FOR GODOT
  1. Run this script.
  2. Select the "HotAirBalloon" empty (or Envelope + Holder).
  3. File → Export → glTF 2.0 (.glb)  OR use --export path.glb

CLI example:
  blender --background --python tools/make_hot_air_balloon.py -- --export hot_air_balloon.glb
  blender --background --python tools/make_hot_air_balloon.py -- --save hot_air_balloon.blend --render preview.png
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


# ---------------------------------------------------------------------------
# Defaults — envelope height in meters; strut bottoms sit on Z=0
# ---------------------------------------------------------------------------
DEFAULT_SIZE = 2.0
DEFAULT_SEGMENTS = 16
DEFAULT_RINGS = 12
DEFAULT_STRIPES = 8
DEFAULT_STRUT_RADIUS = 0.016
OBJECT_NAME = "HotAirBalloon"
COLLECTION_NAME = "ShootForCash_Balloons"

# Classic bulbous envelope: t=0 neck → t=1 pole. Radius as a fraction of max_r.
# Fat apple body, short pinched neck, rounded cap.
_PROFILE = [
	(0.00, 0.22),
	(0.05, 0.28),
	(0.12, 0.50),
	(0.20, 0.74),
	(0.30, 0.91),
	(0.42, 0.99),
	(0.54, 1.00),
	(0.66, 0.97),
	(0.76, 0.88),
	(0.85, 0.70),
	(0.92, 0.48),
	(0.97, 0.22),
	(1.00, 0.00),
]


def _parse_args(argv: list[str]) -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build a low-poly hot air balloon.")
	parser.add_argument("--size", type=float, default=DEFAULT_SIZE, help="Envelope height in meters.")
	parser.add_argument("--segments", type=int, default=DEFAULT_SEGMENTS, help="Vertical gores (even, 8–32).")
	parser.add_argument("--rings", type=int, default=DEFAULT_RINGS, help="Horizontal loops on the envelope (6–24).")
	parser.add_argument("--stripes", type=int, default=DEFAULT_STRIPES, help="Red/cream color panels around (even).")
	parser.add_argument("--strut-radius", type=float, default=DEFAULT_STRUT_RADIUS)
	parser.add_argument("--export", type=str, default="")
	parser.add_argument("--save", type=str, default="", help="Write a .blend file.")
	parser.add_argument("--render", type=str, default="", help="Write a preview PNG.")
	parser.add_argument("--no-clear", action="store_true")
	if "--" in argv:
		argv = argv[argv.index("--") + 1 :]
	else:
		argv = []
	ns = parser.parse_args(argv)
	ns.clear = not ns.no_clear
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
	for obj in list(bpy.data.objects):
		if obj.name.startswith(name):
			bpy.data.objects.remove(obj, do_unlink=True)
	cube = bpy.data.objects.get("Cube")
	if cube is not None:
		bpy.data.objects.remove(cube, do_unlink=True)


# ---------------------------------------------------------------------------
# Materials — matte fabric + dark iron (glTF-friendly Principled)
# ---------------------------------------------------------------------------
def _set_principled(bsdf: bpy.types.Node, *, metallic: float, roughness: float, specular: float = 0.35) -> None:
	if "Metallic" in bsdf.inputs:
		bsdf.inputs["Metallic"].default_value = metallic
	if "Roughness" in bsdf.inputs:
		bsdf.inputs["Roughness"].default_value = roughness
	for key, val in (("Specular", specular), ("Specular IOR Level", specular)):
		if key in bsdf.inputs:
			bsdf.inputs[key].default_value = val
			break


def _make_solid_material(
	name: str,
	color: tuple[float, float, float, float],
	*,
	metallic: float,
	roughness: float,
	specular: float = 0.35,
) -> bpy.types.Material:
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
	bsdf.inputs["Base Color"].default_value = color
	_set_principled(bsdf, metallic=metallic, roughness=roughness, specular=specular)

	mat.diffuse_color = color
	if hasattr(mat, "metallic"):
		mat.metallic = metallic
	if hasattr(mat, "roughness"):
		mat.roughness = roughness
	return mat


def _make_balloon_red() -> bpy.types.Material:
	# Bright balloon red, matte cloth.
	return _make_solid_material(
		"BalloonFabricRed",
		(0.74, 0.035, 0.04, 1.0),
		metallic=0.0,
		roughness=0.88,
		specular=0.18,
	)


def _make_balloon_cream() -> bpy.types.Material:
	# Warm off-white / cream from the reference.
	return _make_solid_material(
		"BalloonFabricCream",
		(0.93, 0.88, 0.78, 1.0),
		metallic=0.0,
		roughness=0.88,
		specular=0.18,
	)


def _make_holder_metal() -> bpy.types.Material:
	# Dark charcoal iron for the neck band + struts.
	return _make_solid_material(
		"BalloonHolderMetal",
		(0.08, 0.075, 0.07, 1.0),
		metallic=0.88,
		roughness=0.38,
		specular=0.45,
	)


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
def _interp_profile(t: float, keys: list[tuple[float, float]]) -> float:
	t = max(0.0, min(1.0, t))
	for i in range(len(keys) - 1):
		t0, r0 = keys[i]
		t1, r1 = keys[i + 1]
		if t0 <= t <= t1:
			u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
			u = 0.5 - 0.5 * math.cos(u * math.pi)
			return r0 + (r1 - r0) * u
	return keys[-1][1]


def _add_cylinder(bm: bmesh.types.BMesh, a: Vector, b: Vector, radius: float, segments: int) -> None:
	direction = b - a
	length = direction.length
	if length < 1e-8:
		return
	z_axis = direction.normalized()
	tmp = Vector((0.0, 0.0, 1.0)) if abs(z_axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
	x_axis = z_axis.cross(tmp).normalized()
	y_axis = z_axis.cross(x_axis).normalized()

	rings: list[list[bmesh.types.BMVert]] = []
	for pos in (a, b):
		ring: list[bmesh.types.BMVert] = []
		for i in range(segments):
			ang = (i / float(segments)) * math.tau
			offset = x_axis * (math.cos(ang) * radius) + y_axis * (math.sin(ang) * radius)
			ring.append(bm.verts.new(pos + offset))
		rings.append(ring)
	bm.verts.ensure_lookup_table()
	for i in range(segments):
		j = (i + 1) % segments
		bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
	try:
		bm.faces.new(list(reversed(rings[0])))
	except ValueError:
		pass
	try:
		bm.faces.new(rings[1])
	except ValueError:
		pass


def _build_envelope_bmesh(
	envelope_h: float,
	max_r: float,
	neck_r: float,
	z0: float,
	n_segs: int,
	n_rings: int,
	n_stripes: int,
) -> bmesh.types.BMesh:
	bm = bmesh.new()
	n_segs = max(8, min(32, n_segs))
	n_rings = max(6, min(24, n_rings))
	n_stripes = max(2, min(n_segs, n_stripes))
	if n_segs % n_stripes != 0:
		# Snap stripe count down so each gore is a whole number of faces.
		while n_stripes > 2 and n_segs % n_stripes != 0:
			n_stripes -= 1
	faces_per_stripe = n_segs // n_stripes

	rings: list[list[bmesh.types.BMVert]] = []
	for i in range(n_rings):
		t = i / float(n_rings)
		r = _interp_profile(t, _PROFILE) * max_r
		# Keep the opening at the true neck radius (collar sits here).
		if i == 0:
			r = neck_r
		z = z0 + t * envelope_h
		ring: list[bmesh.types.BMVert] = []
		for s in range(n_segs):
			ang = (s / float(n_segs)) * math.tau
			ring.append(bm.verts.new(Vector((math.cos(ang) * r, math.sin(ang) * r, z))))
		rings.append(ring)

	pole_t = 1.0
	pole = bm.verts.new(Vector((0.0, 0.0, z0 + pole_t * envelope_h)))
	bm.verts.ensure_lookup_table()

	uv_layer = bm.loops.layers.uv.new("UVMap")

	def _assign_uv(face: bmesh.types.BMFace, verts_uv: list[tuple[float, float]]) -> None:
		for loop, uv in zip(face.loops, verts_uv):
			loop[uv_layer].uv = Vector((uv[0], uv[1]))

	# Side quads.
	for i in range(n_rings - 1):
		v0 = i / float(n_rings)
		v1 = (i + 1) / float(n_rings)
		for s in range(n_segs):
			s2 = (s + 1) % n_segs
			face = bm.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
			stripe = (s // faces_per_stripe) % 2
			face.material_index = stripe
			u0 = s / float(n_segs)
			u1 = (s + 1) / float(n_segs)
			_assign_uv(face, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])

	# Triangle fan to the pole.
	v0 = (n_rings - 1) / float(n_rings)
	v1 = 1.0
	for s in range(n_segs):
		s2 = (s + 1) % n_segs
		face = bm.faces.new((rings[-1][s], rings[-1][s2], pole))
		stripe = (s // faces_per_stripe) % 2
		face.material_index = stripe
		u0 = s / float(n_segs)
		u1 = (s + 1) / float(n_segs)
		um = 0.5 * (u0 + u1)
		_assign_uv(face, [(u0, v0), (u1, v0), (um, v1)])

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _build_holder_bmesh(
	neck_r: float,
	ring_z: float,
	ring_h: float,
	ring_thick: float,
	n_segs: int,
	strut_radius: float,
	strut_bottom_half: float,
) -> bmesh.types.BMesh:
	bm = bmesh.new()
	outer_r = neck_r + ring_thick * 0.55
	inner_r = max(neck_r - ring_thick * 0.65, neck_r * 0.62)
	z1 = ring_z + ring_h * 0.5
	z0 = ring_z - ring_h * 0.5

	outer_bot: list[bmesh.types.BMVert] = []
	outer_top: list[bmesh.types.BMVert] = []
	inner_bot: list[bmesh.types.BMVert] = []
	inner_top: list[bmesh.types.BMVert] = []
	for s in range(n_segs):
		ang = (s / float(n_segs)) * math.tau
		c, si = math.cos(ang), math.sin(ang)
		outer_bot.append(bm.verts.new(Vector((c * outer_r, si * outer_r, z0))))
		outer_top.append(bm.verts.new(Vector((c * outer_r, si * outer_r, z1))))
		inner_bot.append(bm.verts.new(Vector((c * inner_r, si * inner_r, z0))))
		inner_top.append(bm.verts.new(Vector((c * inner_r, si * inner_r, z1))))
	bm.verts.ensure_lookup_table()

	for s in range(n_segs):
		s2 = (s + 1) % n_segs
		# Outer wall
		bm.faces.new((outer_bot[s], outer_bot[s2], outer_top[s2], outer_top[s]))
		# Inner wall (reversed so it faces inward)
		bm.faces.new((inner_bot[s2], inner_bot[s], inner_top[s], inner_top[s2]))
		# Top
		bm.faces.new((outer_top[s], outer_top[s2], inner_top[s2], inner_top[s]))
		# Bottom
		bm.faces.new((outer_bot[s2], outer_bot[s], inner_bot[s], inner_bot[s2]))

	# Four struts: neck ring → inward square corners on Z=0.
	attach_r = (outer_r + inner_r) * 0.5
	strut_segs = 6
	for sx, sy in ((1.0, 1.0), (1.0, -1.0), (-1.0, 1.0), (-1.0, -1.0)):
		ang = math.atan2(sy, sx)
		top = Vector((math.cos(ang) * attach_r, math.sin(ang) * attach_r, z0 + ring_h * 0.15))
		bot = Vector((sx * strut_bottom_half, sy * strut_bottom_half, 0.0))
		_add_cylinder(bm, top, bot, strut_radius, strut_segs)

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return bm


def _mesh_from_bmesh(name: str, bm: bmesh.types.BMesh) -> bpy.types.Mesh:
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.update()
	return mesh


def _shade_flat(obj: bpy.types.Object) -> None:
	mesh = obj.data
	for poly in mesh.polygons:
		poly.use_smooth = False
	if hasattr(mesh, "use_auto_smooth"):
		mesh.use_auto_smooth = False
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	try:
		bpy.ops.object.shade_flat()
	except Exception:
		pass


def _fix_normals(obj: bpy.types.Object) -> None:
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.normals_make_consistent(inside=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	try:
		bpy.ops.mesh.customdata_custom_splitnormals_clear()
	except Exception:
		pass


def _link(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
	if obj.name not in collection.objects:
		collection.objects.link(obj)
	# Keep it out of the scene collection duplicate if Blender auto-linked.
	scene_col = bpy.context.scene.collection
	if obj.name in scene_col.objects and collection != scene_col:
		scene_col.objects.unlink(obj)


def build_balloon(args: argparse.Namespace) -> bpy.types.Object:
	collection = _ensure_collection(COLLECTION_NAME)
	if args.clear:
		_clear_previous(OBJECT_NAME, collection)

	envelope_h = max(0.25, args.size)
	max_r = envelope_h * 0.48
	neck_r = max_r * 0.24
	strut_len = envelope_h * 0.32
	ring_h = envelope_h * 0.07
	ring_thick = envelope_h * 0.045
	ring_z = strut_len
	z0 = ring_z + ring_h * 0.12
	strut_bottom_half = neck_r * 0.40
	n_segs = max(8, args.segments)
	if n_segs % 2 != 0:
		n_segs += 1

	red = _make_balloon_red()
	cream = _make_balloon_cream()
	metal = _make_holder_metal()

	env_bm = _build_envelope_bmesh(
		envelope_h=envelope_h,
		max_r=max_r,
		neck_r=neck_r,
		z0=z0,
		n_segs=n_segs,
		n_rings=max(6, args.rings),
		n_stripes=max(2, args.stripes),
	)
	env_mesh = _mesh_from_bmesh(OBJECT_NAME + "Envelope", env_bm)
	env_obj = bpy.data.objects.new(OBJECT_NAME + "_Envelope", env_mesh)
	_link(env_obj, collection)
	env_mesh.materials.append(red)
	env_mesh.materials.append(cream)

	hold_bm = _build_holder_bmesh(
		neck_r=neck_r,
		ring_z=ring_z,
		ring_h=ring_h,
		ring_thick=ring_thick,
		n_segs=n_segs,
		strut_radius=args.strut_radius * (envelope_h / DEFAULT_SIZE),
		strut_bottom_half=strut_bottom_half,
	)
	hold_mesh = _mesh_from_bmesh(OBJECT_NAME + "Holder", hold_bm)
	hold_obj = bpy.data.objects.new(OBJECT_NAME + "_Holder", hold_mesh)
	_link(hold_obj, collection)
	hold_mesh.materials.append(metal)

	root = bpy.data.objects.new(OBJECT_NAME, None)
	root.empty_display_type = "PLAIN_AXES"
	root.empty_display_size = 0.25
	_link(root, collection)

	for obj in (env_obj, hold_obj):
		obj.parent = root
		bpy.ops.object.select_all(action="DESELECT")
		_fix_normals(obj)
		_shade_flat(obj)

	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	env_obj.select_set(True)
	hold_obj.select_set(True)
	bpy.context.view_layer.objects.active = root
	return root


def _resolve_out(path: str) -> Path:
	out = Path(path)
	if not out.is_absolute():
		try:
			script_dir = Path(__file__).resolve().parent
		except NameError:
			script_dir = Path.cwd()
		out = script_dir / out
	out.parent.mkdir(parents=True, exist_ok=True)
	return out


def export_glb(root: bpy.types.Object, path: str) -> None:
	out = _resolve_out(path)
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	for child in root.children:
		child.select_set(True)
	bpy.context.view_layer.objects.active = root

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
	print(f"[make_hot_air_balloon] Exported: {out}")


def save_blend(path: str) -> None:
	out = _resolve_out(path)
	bpy.ops.wm.save_as_mainfile(filepath=str(out))
	print(f"[make_hot_air_balloon] Saved: {out}")


def render_preview(root: bpy.types.Object, path: str) -> None:
	out = _resolve_out(path)
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 900
	scene.render.resolution_y = 1100
	scene.render.filepath = str(out)
	scene.render.image_settings.file_format = "PNG"
	scene.render.film_transparent = False
	if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
		scene.eevee.taa_render_samples = 16
	world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
	scene.world = world
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background")
	if bg:
		bg.inputs[0].default_value = (0.95, 0.95, 0.95, 1.0)
		bg.inputs[1].default_value = 1.0

	# Camera: 3/4 view similar to the reference photo.
	cam_data = bpy.data.cameras.new("BalloonPreviewCam")
	cam_data.lens = 50
	cam = bpy.data.objects.new("BalloonPreviewCam", cam_data)
	scene.collection.objects.link(cam)
	cam.location = (3.4, -4.4, 2.35)
	direction = Vector((0.0, 0.0, 1.35)) - cam.location
	cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	scene.camera = cam

	sun_data = bpy.data.lights.new("BalloonPreviewSun", "SUN")
	sun_data.energy = 3.2
	sun_data.angle = math.radians(18.0)
	sun = bpy.data.objects.new("BalloonPreviewSun", sun_data)
	scene.collection.objects.link(sun)
	sun.rotation_euler = (math.radians(48.0), math.radians(-12.0), math.radians(35.0))

	fill_data = bpy.data.lights.new("BalloonPreviewFill", "SUN")
	fill_data.energy = 0.7
	fill = bpy.data.objects.new("BalloonPreviewFill", fill_data)
	scene.collection.objects.link(fill)
	fill.rotation_euler = (math.radians(20.0), math.radians(40.0), math.radians(-120.0))

	scene.view_settings.view_transform = "Standard"
	bpy.ops.render.render(write_still=True)
	print(f"[make_hot_air_balloon] Rendered: {out}")


def main() -> None:
	args = _parse_args(sys.argv)
	root = build_balloon(args)
	env = next((c for c in root.children if c.name.endswith("_Envelope")), None)
	hold = next((c for c in root.children if c.name.endswith("_Holder")), None)
	env_verts = len(env.data.vertices) if env else 0
	hold_verts = len(hold.data.vertices) if hold else 0
	print(
		f"[make_hot_air_balloon] Built '{root.name}' size={args.size} "
		f"segs={args.segments} rings={args.rings} stripes={args.stripes} "
		f"envelope_verts={env_verts} holder_verts={hold_verts}"
	)
	if args.export:
		export_glb(root, args.export)
	if args.save:
		save_blend(args.save)
	if args.render:
		render_preview(root, args.render)


if __name__ == "__main__":
	main()
