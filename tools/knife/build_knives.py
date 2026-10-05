"""Builds Eco's three knives in Blender and exports them for Godot.

    blender --background --python tools/knife/build_knives.py -- assets/models/knife

Writes <dir>/needle.glb, kunai.glb and butterfly.glb (pass knife ids after the
directory to build only some). She carries the one picked at the knife case in
the hub (armory.gd KNIVES, scripts/knife.gd):

  needle     The stiletto refined: a long needle-thin diamond blade in cobalt
             steel with bright honed edges and a dark fuller, a swept
             crossguard with a cyan inlay (the light of the pistol's LEDs),
             a black criss-cross cord grip between cobalt ferrules and a ring
             pommel to spin it on a finger, lined in cyan.
  kunai      Cut from salvaged colony armour plate: a white tanto blade with
             the paint ground off along the edge, stencil chevrons, the
             plate's old power trace still glowing and its bushed bolt hole;
             a steel tang wrapped in cobalt paracord, wire collars and a
             finger ring.
  butterfly  A balisong, held open: a cobalt clip-point blade with a bright
             edge and a dark swedge line, and the two skeleton channel
             handles closed together round the tang as the grip, cyan inlays
             and slots down both faces, chrome pivot pins and the latch
             clasped over the butt. The handles are their own nodes
             (SafeHandle, BiteHandle), origins on their pivot pins, so the
             game can flip the bite handle open (it swings about local Y).

Modelled in the concept sheet's frame (blade along +X, edge down -Z, Y the
thickness, metres; /weapon-concepts/scripts/designs/stiletto.py) and exported
in Godot's frame (x right, y up, -z forward): the blade points down -z, the
edge faces -x, the flats face +-y, and the origin sits in the middle of the
grip, where Eco's fist closes. Details the concept only put on its camera
side are mirrored onto both faces. Materials are placeholders named knife_*;
scripts/knife.gd swaps them for assets/materials/knife/*.tres.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGS[0] if ARGS else "."
ONLY = ARGS[1:]

COBALT = (0.24, 0.36, 0.62)
EDGE = (0.85, 0.9, 1.0)
DARK = (0.06, 0.08, 0.14)
GRIP = (0.07, 0.07, 0.08)
CYAN = (0.3, 0.95, 1.0)
STEEL = (0.62, 0.64, 0.68)
ARMOR = (0.86, 0.87, 0.88)
PARA = (0.2, 0.32, 0.58)
GUN = (0.14, 0.14, 0.17)

## Concept colour -> the game material it becomes (assets/materials/knife/).
MATERIALS = {
	COBALT: "knife_cobalt",
	EDGE: "knife_edge",
	DARK: "knife_dark",
	GRIP: "knife_grip",
	CYAN: "knife_glow",
	STEEL: "knife_steel",
	ARMOR: "knife_armor",
	PARA: "knife_para",
	GUN: "knife_gunmetal",
}


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	for rgb, name in MATERIALS.items():
		m = bpy.data.materials.new(name)
		m.diffuse_color = (*rgb, 1.0)


# --- parts, in the concept frame --------------------------------------------------

def _obj(bm, color, name="part", bevel=0.0, segs=2, smooth=False, angle=35):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	me.materials.append(bpy.data.materials[MATERIALS[color]])
	if bevel:
		md = o.modifiers.new("bev", "BEVEL")
		md.width = bevel
		md.segments = segs
		md.limit_method = "ANGLE"
		md.angle_limit = math.radians(angle)
	for p in me.polygons:
		p.use_smooth = smooth
	return o


def loft(secs, color, smooth=False):
	"""Skins (x, [(y, z), ...]) sections into a closed tube; a 1-point section is a tip."""
	bm = bmesh.new()
	rings = [[bm.verts.new((x, y, z)) for y, z in pts] for x, pts in secs]
	for a, b in zip(rings, rings[1:]):
		n = max(len(a), len(b))
		for i in range(n):
			if len(b) == 1:
				bm.faces.new((a[i], a[(i + 1) % len(a)], b[0]))
			elif len(a) == 1:
				bm.faces.new((a[0], b[(i + 1) % len(b)], b[i]))
			else:
				bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
	if len(rings[0]) > 2:
		bm.faces.new(list(reversed(rings[0])))
	if len(rings[-1]) > 2:
		bm.faces.new(rings[-1])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return _obj(bm, color, "loft", smooth=smooth)


def prof(pts, y0, y1, color, bevel=0.0015, segs=2):
	"""Side profile: polygon of (x, z) points extruded across Y from y0 to y1."""
	bm = bmesh.new()
	vs = [bm.verts.new((x, y0, z)) for x, z in pts]
	f = bm.faces.new(vs)
	bmesh.ops.recalc_face_normals(bm, faces=[f])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
	bmesh.ops.translate(bm, vec=Vector((0, y1 - y0, 0)), verts=nv)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return _obj(bm, color, "prof", bevel, segs)


def sym(pts, w, color, bevel=0.0015):
	"""Profile centred on the midline, w thick."""
	return prof(pts, -w / 2, w / 2, color, bevel)


def sides(pts, w, y, color, bevel=0.0):
	"""A thin plate on both faces, |y| out from the midline, w thick."""
	y = abs(y)
	return [prof(pts, -y, -y - w, color, bevel, 1), prof(pts, y, y + w, color, bevel, 1)]


def box(c, s, color, bevel=0.0015):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co = Vector((v.co.x * s[0] + c[0], v.co.y * s[1] + c[1], v.co.z * s[2] + c[2]))
	return _obj(bm, color, "box", bevel)


def _orient(bm, p0, p1):
	p0, p1 = Vector(p0), Vector(p1)
	q = Vector((0, 0, 1)).rotation_difference((p1 - p0).normalized())
	bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=q.to_matrix())
	bmesh.ops.translate(bm, vec=(p0 + p1) / 2, verts=bm.verts)


def cyl(p0, p1, r, color, r1=None, segs=16, bevel=0.0008, smooth=True):
	"""Cylinder (or cone when r1 given) from p0 to p1."""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
			radius1=r, radius2=r if r1 is None else r1, depth=(Vector(p1) - Vector(p0)).length)
	_orient(bm, p0, p1)
	return _obj(bm, color, "cyl", bevel, 1, smooth=smooth, angle=50)


def torus(c, axis, R, r, color, major=24, minor=6):
	bm = bmesh.new()
	rings = []
	for i in range(major):
		a = i * math.tau / major
		ring = []
		for j in range(minor):
			b = j * math.tau / minor
			rr = R + r * math.cos(b)
			ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
		rings.append(ring)
	for i in range(major):
		a, b = rings[i], rings[(i + 1) % major]
		for j in range(minor):
			bm.faces.new((a[j], b[j], b[(j + 1) % minor], a[(j + 1) % minor]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
	bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=q.to_matrix())
	bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
	return _obj(bm, color, "torus", smooth=True)


def rot(o, deg, axis="Y", pivot=(0, 0, 0)):
	M = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-Vector(pivot))
	o.data.transform(M)
	return o


def arc(cx, cz, r, a0, a1, n=8):
	return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
			cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def dia(h, t):
	return [(0.0, h), (-t, 0.0), (0.0, -h), (t, 0.0)]


def cord_wrap(x0, x1, r, color, step=0.0062, tilt=0.22):
	"""Cord wraps: tilted rings, alternating lean so they read as a criss-cross."""
	n = int((x1 - x0) / step)
	return [torus((x0 + i * step, 0, 0), (1, 0, tilt if i % 2 == 0 else -tilt), r, r * 0.19, color)
			for i in range(n + 1)]


# --- the knives (concept frame) ----------------------------------------------------

def needle():
	"""Refined needle: diamond blade, swept guard, cord grip, ring pommel."""
	parts = []
	L = 0.205
	parts.append(loft([(-0.004, dia(0.0085, 0.0034)), (0.012, dia(0.0088, 0.0034)), (0.075, dia(0.0076, 0.003)),
			(0.155, dia(0.0045, 0.002)), (L - 0.012, dia(0.0012, 0.0008)), (L, [(0.0, 0.0)])], COBALT))
	parts.append(loft([(0.012, dia(0.0095, 0.0009)), (0.075, dia(0.0083, 0.0008)), (0.155, dia(0.0051, 0.0006)),
			(L - 0.008, dia(0.0014, 0.0003)), (L + 0.002, [(0.0, 0.0)])], EDGE))
	# Dark fuller standing just proud of the ridge, on both faces.
	for s in (1, -1):
		secs = []
		for x, h, t in ((0.016, 0.0088, 0.0034), (0.075, 0.0076, 0.003), (0.13, 0.0055, 0.0023)):
			f = 0.0011 if x < 0.1 else 0.0006
			yy = -t * (1 - f / h) - 0.00025
			secs.append((x, [(s * yy, f), (s * (-t - 0.0003), 0.0), (s * yy, -f)]))
		secs.append((0.142, [(s * -0.0021, 0.0)]))
		parts.append(loft(secs, DARK))
	# Swept crossguard: the quillon tips lean toward the blade.
	front, back = [], []
	n = 12
	for i in range(n + 1):
		z = -0.03 + 0.06 * i / n
		a = abs(z) / 0.03
		xc = -0.004 + 0.009 * a ** 2.2
		d = 0.0042 - 0.0019 * a
		front.append((xc + d, z))
		back.append((xc - d, z))
	parts.append(sym(front + back[::-1], 0.009, COBALT, bevel=0.0009))
	parts += sides([(-0.0052, -0.016), (-0.0029, -0.016), (-0.0029, 0.016), (-0.0052, 0.016)], 0.0006, 0.0045, CYAN)
	# Grip: black core, criss-cross cord, cobalt ferrules.
	parts.append(cyl((-0.096, 0, 0), (-0.006, 0, 0), 0.0082, GRIP, segs=12))
	parts += cord_wrap(-0.084, -0.019, 0.0086, GRIP)
	for x0, x1 in ((-0.016, -0.006), (-0.098, -0.088)):
		parts.append(cyl((x0, 0, 0), (x1, 0, 0), 0.0098, COBALT, segs=8))
	# Ring pommel with a cyan line round the inside, on both faces.
	parts.append(cyl((-0.106, 0, 0), (-0.097, 0, 0), 0.0058, COBALT, r1=0.0085, segs=8))
	parts.append(torus((-0.121, 0, 0), (0, 1, 0), 0.0135, 0.0034, COBALT, 28, 8))
	for s in (1, -1):
		parts.append(torus((-0.121, s * 0.0022, 0), (0, 1, 0), 0.0135, 0.0017, CYAN, 28, 6))
	return {"Needle": parts}, -0.051, 0.0


def plate_kunai():
	"""Tanto-tipped kunai cut from colony armour plate, paracord wrap, finger ring."""
	parts = []
	blade = [(-0.004, 0.010), (0.165, 0.011), (0.19, 0.0085), (0.163, -0.0135), (0.012, -0.0152), (-0.004, -0.0125)]
	parts.append(sym(blade, 0.004, ARMOR, bevel=0.0006))
	# Ground edge: the paint is ground off and raw steel shows along the bevel.
	parts += sides([(0.012, -0.0152), (0.163, -0.0135), (0.19, 0.0085), (0.177, 0.0074), (0.156, -0.0082), (0.014, -0.0092)],
			0.0005, 0.002, EDGE)
	# Colony markings: stencil chevrons and the plate's old power trace, still lit.
	for i in range(3):
		x = 0.1 + i * 0.012
		parts += sides([(x, -0.006), (x + 0.005, -0.006), (x + 0.009, 0.006), (x + 0.004, 0.006)], 0.0004, 0.002, GUN)
	parts += sides([(0.02, 0.0068), (0.15, 0.0072), (0.15, 0.0085), (0.02, 0.0083)], 0.0004, 0.002, CYAN)
	for s in (1, -1):
		parts.append(cyl((0.02, s * 0.0019, 0.0075), (0.02, s * 0.0024, 0.0075), 0.0022, CYAN, bevel=0))
	# The armour's old bolt hole, steel bushed.
	parts.append(cyl((0.045, -0.0026, -0.002), (0.045, 0.0026, -0.002), 0.0042, DARK, bevel=0))
	for s in (1, -1):
		parts.append(torus((0.045, s * 0.0022, -0.002), (0, 1, 0), 0.0045, 0.0009, STEEL, 16, 4))
	# Tang wrapped in cobalt paracord, wire collars, finger ring.
	parts.append(box((-0.056, 0, -0.001), (0.104, 0.0035, 0.012), STEEL, 0.0006))
	parts.append(cyl((-0.096, 0, -0.001), (-0.008, 0, -0.001), 0.0088, PARA, segs=12))
	for i in range(14):
		x = -0.092 + i * 0.0062
		parts.append(torus((x, 0, -0.001), (1, 0, 0.3 if i % 2 else -0.3), 0.0092, 0.0019, PARA, 20, 5))
	for x in (-0.006, -0.0085):
		parts.append(torus((x, 0, -0.001), (1, 0, 0), 0.009, 0.0011, STEEL, 20, 4))
	parts.append(torus((-0.119, 0, -0.001), (0, 1, 0), 0.0125, 0.0029, STEEL, 28, 8))
	parts.append(torus((-0.098, 0, -0.001), (1, 0, 0), 0.0072, 0.0013, STEEL, 16, 4))
	return {"Kunai": parts}, -0.052, -0.001


def _handle(top):
	"""One channel handle, open (pointing -X), pin at (0, +-0.006)."""
	s = 1 if top else -1
	pts = [(-0.118, 0.0005), (0.0, 0.0005)] + arc(0.0, 0.006, 0.0058, -90, 90, 8)[1:] + \
			[(-0.04, 0.0122), (-0.085, 0.0128), (-0.11, 0.0118), (-0.12, 0.0085)]
	pts = [(x, s * z) for x, z in pts]
	if not top:
		pts = pts[::-1]
	parts = [sym(pts, 0.013, GUN, bevel=0.0009)]
	# Cyan inlay, skeleton slots and screws on both faces.
	parts += sides([(-0.1, s * 0.0055), (-0.02, s * 0.0055), (-0.02, s * 0.0072), (-0.1, s * 0.0072)], 0.0005, 0.0065, CYAN)
	for x in (-0.09, -0.07, -0.05):
		parts += sides([(x, s * 0.0085), (x + 0.013, s * 0.0085), (x + 0.013, s * 0.0105), (x, s * 0.0105)], 0.0004, 0.0065, DARK)
	for x in (-0.112, -0.012):
		for side in (1, -1):
			parts.append(cyl((x, side * 0.0072, s * 0.0035), (x, side * 0.0062, s * 0.0035), 0.0016, STEEL, bevel=0, segs=10))
	parts.append(cyl((0.0, -0.0078, s * 0.006), (0.0, 0.0078, s * 0.006), 0.0024, STEEL, segs=16))
	return parts


def butterfly():
	"""Balisong held open: both handles closed round the tang as the grip."""
	parts = []
	belly = [(0.138, -0.0008), (0.13, -0.0062), (0.118, -0.0098), (0.1, -0.0118), (0.075, -0.0124), (0.02, -0.0122)]
	blade = [(-0.006, 0.0085), (0.075, 0.0092), (0.1, 0.0062), (0.128, 0.0012)] + belly + \
			[(0.008, -0.0118), (0.006, -0.008), (0.002, -0.0078), (-0.006, -0.0085)]
	parts.append(sym(blade, 0.0034, COBALT, bevel=0.0005))
	inner = [(0.02, -0.0078), (0.075, -0.0082), (0.1, -0.0074), (0.116, -0.0056), (0.127, -0.0026)]
	parts += sides(belly + inner, 0.0004, 0.0017, EDGE)
	parts += sides([(0.075, 0.0092), (0.1, 0.0062), (0.128, 0.0012), (0.138, -0.0008), (0.126, -0.0002), (0.098, 0.0042),
			(0.076, 0.0068)], 0.0004, 0.0017, EDGE)
	parts += sides([(0.02, 0.0032), (0.07, 0.0042), (0.07, 0.0056), (0.02, 0.0048)], 0.0004, 0.0017, DARK)
	safe = _handle(True)
	bite = _handle(False)
	# The latch, swung down and clasped over the butt so the handles stay shut.
	safe.append(sym([(-0.1236, 0.0045), (-0.1204, 0.0045), (-0.1204, -0.0098), (-0.1222, -0.0112), (-0.1236, -0.0098)],
			0.005, STEEL, bevel=0.0004))
	safe.append(cyl((-0.1216, -0.0034, 0.0035), (-0.1216, 0.0034, 0.0035), 0.0011, STEEL, segs=10, bevel=0))
	return {"Butterfly": parts, "SafeHandle": safe, "BiteHandle": bite}, -0.06, 0.0, \
			{"SafeHandle": (0.0, 0.0, 0.006), "BiteHandle": (0.0, 0.0, -0.006)}


KNIVES = {"needle": needle, "kunai": plate_kunai, "butterfly": butterfly}


# --- export ------------------------------------------------------------------------

def _concept_to_blender(xc, zc):
	"""Concept (X along the blade, Y thickness, Z up) -> Godot (x = Z, y = Y,
	z = -X, grip centred on the origin) -> Blender (x, -z, y)."""
	return Matrix(((0, 0, 1, -zc), (1, 0, 0, -xc), (0, 1, 0, 0), (0, 0, 0, 1)))


def _bake(o):
	"""Applies the object's modifiers into its mesh."""
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
	old = o.data
	o.modifiers.clear()
	o.data = me
	bpy.data.meshes.remove(old)


def join(name, objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1:
		bpy.ops.object.join()
	objs[0].name = name
	objs[0].data.name = name
	return objs[0]


def build(knife_id):
	reset()
	made = KNIVES[knife_id]()
	groups, xc, zc = made[:3]
	pivots = made[3] if len(made) > 3 else {}
	M = _concept_to_blender(xc, zc)
	tris = 0
	for name, objs in groups.items():
		for o in objs:
			_bake(o)
			o.data.transform(M)
		ob = join(name, objs)
		if name in pivots:
			# Origin on the pivot pin, so the node turns about it.
			p = M @ Vector(pivots[name])
			ob.data.transform(Matrix.Translation(-p))
			ob.location = p
		tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
	path = os.path.join(OUT_DIR, knife_id + ".glb")
	bpy.ops.export_scene.gltf(
		filepath=path, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_normals=True, export_materials="EXPORT",
	)
	print("exported", path, "triangles", tris)


for knife in (ONLY or list(KNIVES)):
	build(knife)
