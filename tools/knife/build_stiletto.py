"""Builds Eco's stiletto in Blender and exports it for Godot.

    blender --background --python tools/knife/build_stiletto.py -- assets/models/knife/stiletto.glb

A long, needle-thin diamond blade in cobalt-blue steel with bright honed
edges and a dark fuller down the ridge, a slim swept crossguard with a cyan
inlay (the same light as the pistol's LEDs), a black cord-wrapped grip
between cobalt bands, and a faceted pommel with a glowing cap.

Authored in Godot's frame (x right, y up, -z forward, metres): the blade
points down -z and the origin sits in the middle of the grip, where Eco's
fist closes. Materials are placeholders named knife_*; scripts/knife.gd swaps
them for assets/materials/knife/*.tres.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "stiletto.glb"

# Godot (x, y, z) -> Blender (x, -z, y)
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

COLORS = {
	"knife_cobalt": (0.24, 0.36, 0.62),
	"knife_edge": (0.85, 0.9, 1.0),
	"knife_dark": (0.06, 0.08, 0.14),
	"knife_grip": (0.05, 0.05, 0.06),
	"knife_glow": (0.3, 0.95, 1.0),
}

BLADE_LEN = 0.2
GUARD_Z = -0.052  # front face of the guard
GRIP_LEN = 0.095


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	for name, rgb in COLORS.items():
		m = bpy.data.materials.new(name)
		m.diffuse_color = (*rgb, 1.0)


def obj_from_bm(name, bm, mat, smooth=False):
	bmesh.ops.transform(bm, matrix=G2B, verts=bm.verts)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.collection.objects.link(ob)
	me.materials.append(bpy.data.materials[mat])
	for p in me.polygons:
		p.use_smooth = smooth
	return ob


def lofted(name, sections, mat, smooth=False, cap_back=True, cap_front=True):
	"""Skins a list of (z, [(x, y), ...]) cross-sections (same vertex count) into
	a closed tube. A section with a single point makes a tip."""
	bm = bmesh.new()
	rings = []
	for z, pts in sections:
		rings.append([bm.verts.new((x, y, z)) for x, y in pts])
	for a, b in zip(rings, rings[1:]):
		n = max(len(a), len(b))
		for i in range(n):
			if len(b) == 1:
				bm.faces.new((a[i], a[(i + 1) % len(a)], b[0]))
			elif len(a) == 1:
				bm.faces.new((a[0], b[(i + 1) % len(b)], b[i]))
			else:
				bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
	if cap_back and len(rings[0]) > 2:
		bm.faces.new(list(reversed(rings[0])))
	if cap_front and len(rings[-1]) > 2:
		bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return obj_from_bm(name, bm, mat, smooth)


def diamond(w, t):
	return [(w, 0.0), (0.0, t), (-w, 0.0), (0.0, -t)]


def ngon(r, n, rot=0.0, sx=1.0):
	return [(math.cos(rot + i * math.tau / n) * r * sx, math.sin(rot + i * math.tau / n) * r) for i in range(n)]


def blade():
	"""Cobalt body, a slightly wider but thinner honed edge plate so a bright
	line runs round the outline, and a dark fuller groove on both faces."""
	z0, z1 = GUARD_Z, GUARD_Z - BLADE_LEN
	# Ricasso is square-ish, then the diamond tapers to a needle point.
	body = lofted("Blade", [
		(z0, diamond(0.0085, 0.0034)),
		(z0 - 0.012, diamond(0.0088, 0.0034)),
		(z0 - 0.07, diamond(0.0078, 0.003)),
		(z0 - 0.15, diamond(0.0048, 0.0021)),
		(z1 + 0.012, diamond(0.0012, 0.0008)),
		(z1, [(0.0, 0.0)]),
	], "knife_cobalt")
	edge = lofted("Edge", [
		(z0 - 0.012, diamond(0.0098, 0.0009)),
		(z0 - 0.07, diamond(0.0089, 0.0008)),
		(z0 - 0.15, diamond(0.0058, 0.0006)),
		(z1 + 0.008, diamond(0.0014, 0.0003)),
		(z1 - 0.002, [(0.0, 0.0)]),
	], "knife_edge")
	fullers = []
	for side in (1, -1):
		fullers.append(lofted("Fuller", [
			(z0 - 0.016, [(0.0011, side * 0.0031), (0.0, side * 0.0036), (-0.0011, side * 0.0031)]),
			(z0 - 0.13, [(0.0006, side * 0.0022), (0.0, side * 0.0025), (-0.0006, side * 0.0022)]),
			(z0 - 0.138, [(0.0, side * 0.0022)]),
		], "knife_dark"))
	return [body, edge] + fullers


def guard():
	"""Slim crossguard whose quillons sweep forward at the tips, with a cyan inlay."""
	bm = bmesh.new()
	# Built as a bent bar: centre block plus two arms, each a lofted section along x.
	sections = []
	for i in range(9):
		t = i / 8.0  # 0 at the left tip, 1 at the right tip
		x = (t - 0.5) * 0.046
		sweep = -0.006 * (abs(t - 0.5) * 2.0) ** 2.2  # tips lean toward the blade
		h = 0.0042 - 0.0018 * abs(t - 0.5) * 2.0
		d = 0.0042 - 0.0016 * abs(t - 0.5) * 2.0
		zc = GUARD_Z + 0.0042 + sweep
		sections.append([(x, h, zc - d), (x, h, zc + d), (x, -h, zc + d), (x, -h, zc - d)])
	rings = [[bm.verts.new(v) for v in sec] for sec in sections]
	for a, b in zip(rings, rings[1:]):
		for i in range(4):
			bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
	bm.faces.new(list(reversed(rings[0])))
	bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	bar = obj_from_bm("Guard", bm, "knife_cobalt")
	# Inlay: a thin glowing strip across the back face of the guard (facing Eco).
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, vec=Vector((0.024, 0.0026, 0.0008)), verts=bm.verts)
	bmesh.ops.translate(bm, vec=Vector((0, 0, GUARD_Z + 0.0086)), verts=bm.verts)
	inlay = obj_from_bm("Inlay", bm, "knife_glow")
	return [bar], inlay


def grip():
	"""Octagonal grip, slightly swelled, wrapped in black cord between cobalt bands."""
	z_front = GUARD_Z + 0.009
	z_back = z_front + GRIP_LEN
	core = lofted("Grip", [
		(z_front, ngon(0.0085, 8, math.pi / 8, 0.8)),
		(z_front + GRIP_LEN * 0.45, ngon(0.0098, 8, math.pi / 8, 0.8)),
		(z_back, ngon(0.0088, 8, math.pi / 8, 0.8)),
	], "knife_grip", smooth=True)
	# Cord wrap: raised diagonal ridges.
	wraps = []
	n = 11
	for i in range(n):
		z = z_front + 0.007 + i * (GRIP_LEN - 0.014) / (n - 1)
		r = 0.0101 if 0.2 < i / n < 0.7 else 0.0095
		wraps.append(lofted("Wrap", [
			(z - 0.0018, ngon(r, 8, math.pi / 8, 0.8)),
			(z + 0.0018, ngon(r, 8, math.pi / 8, 0.8)),
		], "knife_grip", smooth=True))
	bands = [
		lofted("Band", [(z_front - 0.001, ngon(0.0094, 8, math.pi / 8, 0.85)), (z_front + 0.004, ngon(0.0094, 8, math.pi / 8, 0.85))], "knife_cobalt"),
		lofted("Band", [(z_back - 0.004, ngon(0.0097, 8, math.pi / 8, 0.85)), (z_back + 0.001, ngon(0.0097, 8, math.pi / 8, 0.85))], "knife_cobalt"),
	]
	return [core] + wraps + bands, z_back


def pommel(z_back):
	"""Faceted teardrop pommel ending in a small glowing cap."""
	z = z_back + 0.001
	body = lofted("Pommel", [
		(z, ngon(0.0082, 6, 0.0, 0.85)),
		(z + 0.007, ngon(0.0112, 6, 0.0, 0.85)),
		(z + 0.016, ngon(0.0072, 6, 0.0, 0.85)),
		(z + 0.019, ngon(0.0035, 6, 0.0, 0.85)),
	], "knife_cobalt")
	cap = lofted("PommelCap", [
		(z + 0.0188, ngon(0.0036, 6, 0.0, 0.85)),
		(z + 0.0215, [(0.0, 0.0)]),
	], "knife_glow")
	return [body], cap


def join(name, objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	objs[0].name = name
	objs[0].data.name = name
	return objs[0]


def build():
	reset()
	steel = blade()
	guard_parts, inlay = guard()
	grip_parts, z_back = grip()
	pommel_parts, cap = pommel(z_back)
	join("Stiletto", steel + guard_parts + grip_parts + pommel_parts + [inlay, cap])
	for ob in bpy.data.objects:
		ob.select_set(ob.type == "MESH")
	bpy.ops.export_scene.gltf(
		filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_normals=True, export_materials="EXPORT",
	)
	tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", OUT, "triangles", tris)


build()
