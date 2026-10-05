"""Builds Eco's smart pistol in Blender and exports it for Godot.

    blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol.glb
    blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol_t3.glb --tier 3

Her father's smart pistol as Eco rebuilt it: the "Ghost Line". The slide and
an integral suppressor run as one long black line from the hammer to the
muzzle, an orange stripe down its flank and vent slots cut into the can.
The tracker is a flush pod on top of the slide's nose with a lens looking
down the barrel; an LED strip on the frame counts her rounds; the grip is
slanted, grooved, with an orange mag base; her father's dog tag hangs off a
lanyard loop at the butt. A sloped ammo screen and a slim holo sight ride on
the back of the slide. (Concept: weapon-concepts designs/smart_pistol.py,
ghost_line.)

`--tier N` (0-5) builds the look tiers, each on top of the one before:
  0  Dad's pistol: the tracker pod smashed, its glass in shards and the pod
     taped up (the default).
  1  Patched: a riveted scrap plate over the smashed window, a mag bumper,
     tape round the grip.
  2  Tuned: a ported brake on the end of the can whose ports glow with the
     vents, vents on top of the can, a second stripe.
  3  Scrapforged: armour plates cut from a titan bolted to the can, an
     extended mag, a wider holo hood.
  4  Rewired: the tracker rebuilt with a working screen and a live lens,
     copper bands round the can, cables up both sides.
  5  Legacy: gold trim, a gold lens bezel and the lock reticle back on the
     tracker screen, a glowing emitter ring at the muzzle, a power cell
     under the frame.

Everything is authored in Godot's frame (x right, y up, -z forward, metres)
and converted on the way in. The concept's profiles (gun along +X, Z up, Y
across) come in through Concept, scaled 1.2x so the grip keeps the old size.
The grip keeps the old position and angle so Eco's glove (eco_fp_arm.glb)
still closes round it. Object names are what the game looks up: Slide (the
rear of the line, which cycles), MagBase, AmmoReadout, TrackerScreen (the
pod), TrackerGlass, TrackerImpact, HoloGlass, Muzzle, Vents, Led0..Led5,
Charm (the dog tag's pivot), Frame.
Materials are placeholders named pistol_*; the import script swaps them for
assets/materials/pistol/*.tres.
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "smart_pistol.glb"
TIER = int(ARGS[ARGS.index("--tier") + 1]) if "--tier" in ARGS else 0
random.seed(7)

# Godot (x, y, z) -> Blender (x, -z, y)
G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

COLORS = {
	"pistol_shell": (0.82, 0.84, 0.86),
	"pistol_dark": (0.16, 0.17, 0.19),
	"pistol_black": (0.06, 0.06, 0.07),
	"pistol_red": (0.85, 0.16, 0.14),
	"pistol_polymer": (0.84, 0.84, 0.8),
	"pistol_blue": (0.32, 0.45, 0.62),
	"pistol_stripe": (1.0, 0.5, 0.15),
	"pistol_screen": (0.02, 0.03, 0.04),
	"pistol_tracker": (0.05, 0.03, 0.03),
	"pistol_holo": (0.4, 0.95, 1.0),
	"pistol_emitter": (1.0, 0.3, 0.2),
	"pistol_vent": (1.0, 0.45, 0.15),
	"pistol_led": (0.3, 0.95, 1.0),
	"pistol_tape": (0.62, 0.2, 0.16),
	"pistol_tag": (0.9, 0.9, 0.86),
	"pistol_armor": (0.95, 0.55, 0.2),
	"pistol_copper": (0.85, 0.5, 0.3),
	"pistol_gold": (1.0, 0.78, 0.3),
	"pistol_live": (0.3, 0.95, 1.0),
	"pistol_ebony": (0.12, 0.1, 0.1),
	"pistol_chrome": (0.86, 0.88, 0.92),
}


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	for name, rgb in COLORS.items():
		m = bpy.data.materials.new(name)
		m.diffuse_color = (*rgb, 1.0)


def xform(pos=(0, 0, 0), rot_deg=(0, 0, 0)):
	"""A Godot-frame transform (rotation X then Y then Z, in degrees)."""
	r = Matrix.Rotation(math.radians(rot_deg[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot_deg[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot_deg[0]), 4, "X")
	return Matrix.Translation(Vector(pos)) @ r


def obj_from_bm(name, bm, mat, local=None, bevel=0.0, segments=2, smooth=True):
	"""Makes an object whose vertices are in Godot space, converted to Blender."""
	if local is not None:
		bmesh.ops.transform(bm, matrix=local, verts=bm.verts)
	bmesh.ops.transform(bm, matrix=G2B, verts=bm.verts)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.collection.objects.link(ob)
	me.materials.append(bpy.data.materials[mat])
	if bevel > 0.0:
		mod = ob.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel
		mod.segments = segments
		mod.limit_method = "ANGLE"
		mod.angle_limit = math.radians(40)
		mod.harden_normals = True
	if smooth:
		for p in me.polygons:
			p.use_smooth = True
		me.use_auto_smooth = True
		me.auto_smooth_angle = math.radians(35)
	return ob


def box_bm(size, center=(0, 0, 0)):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
	bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
	return bm


def box(name, size, center, mat, rot=(0, 0, 0), bevel=0.0, segments=2, pivot=None):
	"""Box of `size` centred at `center`, rotated about `pivot` (default: its centre)."""
	bm = box_bm(size)
	p = Vector(pivot) if pivot is not None else Vector(center)
	local = Matrix.Translation(p) @ xform((0, 0, 0), rot) @ Matrix.Translation(Vector(center) - p)
	return obj_from_bm(name, bm, mat, local, bevel, segments)


def cylinder(name, radius, depth, center, mat, axis="z", segments=16, bevel=0.0):
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
	rot = {"z": (0, 0, 0), "x": (0, 90, 0), "y": (90, 0, 0)}[axis]
	return obj_from_bm(name, bm, mat, xform(center, rot), bevel)


def prism(name, radius, depth, center, mat, segments=8, bevel=0.0):
	"""A flat-topped prism along z (the barrel axis), like a machined shroud."""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
	bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / segments, 4, "Z"))
	return obj_from_bm(name, bm, mat, xform(center), bevel)


def join(name, objs):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	objs[0].name = name
	objs[0].data.name = name
	return objs[0]


def empty(name, pos, rot=(0, 0, 0)):
	e = bpy.data.objects.new(name, None)
	e.empty_display_size = 0.01
	bpy.context.collection.objects.link(e)
	e.matrix_world = G2B @ xform(pos, rot) @ G2B.inverted()
	return e


# --- the shared grip ----------------------------------------------------------

GRIP_POS = Vector((0, -0.088, 0.072))
GRIP_ROT = (-16, 0, 0)

# The old smart pistol's boxy grip, guard and grip tape (no longer used by any
# gun, kept for reference).


def grip_tape():
	"""Tape wrapped round the bottom of the grip, a little crooked."""
	bands = []
	rows = (-0.044, -0.034, -0.024) if TIER >= 1 else (-0.044, -0.034)
	for i, y in enumerate(rows):
		b = box("Tape", (0.0352, 0.0075, 0.0515), (0, y, 0), "pistol_tape", rot=(random.uniform(-7, 7), 0, random.uniform(-3, 3)), bevel=0.001)
		b.data.transform(G2B @ xform(GRIP_POS, GRIP_ROT) @ G2B.inverted())
		bands.append(b)
	return bands


def guard_and_trigger():
	bm = box_bm((0.012, 0.034, 0.064), (0, -0.046, -0.012))
	inner = box_bm((0.02, 0.024, 0.05), (0, -0.041, -0.010))
	g = obj_from_bm("Guard", bm, "pistol_dark", bevel=0.003, segments=2)
	cut = obj_from_bm("GuardCut", inner, "pistol_dark", smooth=False)
	mod = g.modifiers.new("Hollow", "BOOLEAN")
	mod.object = cut
	mod.operation = "DIFFERENCE"
	g.modifiers.move(len(g.modifiers) - 1, 0)
	bpy.context.view_layer.objects.active = g
	bpy.ops.object.modifier_apply(modifier="Hollow")
	bpy.data.objects.remove(cut)
	t = box("Trigger", (0.007, 0.02, 0.007), (0, -0.041, -0.002), "pistol_shell", rot=(15, 0, 0), bevel=0.002)
	return [g, t]


def grip():
	bm = box_bm((0.034, 0.118, 0.05))
	for v in bm.verts:
		if v.co.y < 0:
			v.co.x *= 0.9  # slight taper toward the base
			v.co.z *= 0.94
	g = obj_from_bm("Grip", bm, "pistol_dark", xform(GRIP_POS, GRIP_ROT), bevel=0.005, segments=3)
	panels = []
	for side in (-1, 1):
		panels.append(box("GripPanel", (0.002, 0.085, 0.034), (side * 0.0172, 0.004, 0.002), "pistol_blue", bevel=0.0008))
	for p in panels:
		p.data.transform(G2B @ xform(GRIP_POS, GRIP_ROT) @ G2B.inverted())
	mag_parts = [box("MagBase", (0.037, 0.012, 0.054), (0, -0.064, 0.0), "pistol_shell", bevel=0.003)]
	if TIER >= 3:
		# Extended mag: a longer body below the grip with grip ribs.
		mag_parts.append(box("MagExt", (0.034, 0.022, 0.048), (0, -0.081, 0.0), "pistol_dark", bevel=0.002))
		for k in range(3):
			mag_parts.append(box("MagRib", (0.0355, 0.0022, 0.0495), (0, -0.074 - k * 0.0065, 0.0), "pistol_blue"))
		mag_parts.append(box("MagFoot", (0.038, 0.008, 0.056), (0, -0.095, 0.0), "pistol_shell", bevel=0.0025))
	elif TIER >= 1:
		mag_parts.append(box("MagBumper", (0.039, 0.006, 0.057), (0, -0.072, 0.0), "pistol_tape", bevel=0.002))
	for m in mag_parts:
		m.data.transform(G2B @ xform(GRIP_POS, GRIP_ROT) @ G2B.inverted())
	mag = join("MagBase", mag_parts)
	return [g] + panels, mag


# --- concept profiles ----------------------------------------------------------

class Concept:
	"""The concept sheets' frame (gun along +X, Z up, Y across, metres) mapped
	into Godot's: the concept point `at` (x, z) lands on Godot `to` (y, z), and
	everything is scaled by `s`. Profiles are polygons in the concept's side view
	(x, z) pushed out across y, like the concept kit's sym()/side()."""

	def __init__(self, at, to, s=1.2):
		cx, cz = at
		gy, gz = to
		self.s = s
		self.m = Matrix(((0, -s, 0, 0), (0, 0, s, gy - s * cz), (-s, 0, 0, gz + s * cx), (0, 0, 0, 1)))

	def p(self, x, y, z):
		"""A concept point in Godot space."""
		return self.m @ Vector((x, y, z))

	def prof(self, name, pts, y0, y1, mat, bevel=0.0, segments=2):
		bm = bmesh.new()
		f = bm.faces.new([bm.verts.new((x, y0, z)) for x, z in pts])
		r = bmesh.ops.extrude_face_region(bm, geom=[f])
		moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
		bmesh.ops.translate(bm, vec=Vector((0, y1 - y0, 0)), verts=moved)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		return obj_from_bm(name, bm, mat, self.m, bevel, segments)

	def sym(self, name, pts, w, mat, bevel=0.0, segments=2):
		"""A profile centred on the gun's midline, w wide."""
		return self.prof(name, pts, -w / 2, w / 2, mat, bevel, segments)

	def sides(self, name, pts, y, w, mat):
		"""A thin plate on both flanks: from y out to y + w, and mirrored."""
		return [self.prof(name, pts, y, y + w, mat), self.prof(name, pts, -y - w, -y, mat)]

	def box(self, name, center, size, mat, bevel=0.0):
		return obj_from_bm(name, box_bm(size, center), mat, self.m, bevel)

	def cyl(self, name, p0, p1, r, mat, segments=16, bevel=0.0):
		p0, p1 = Vector(p0), Vector(p1)
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r, radius2=r, depth=(p1 - p0).length)
		q = Vector((0, 0, 1)).rotation_difference((p1 - p0).normalized())
		local = Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4()
		return obj_from_bm(name, bm, mat, self.m @ local, bevel)


def arc(cx, cz, r, a0, a1, n=5):
	"""Points along an arc (degrees, 0 = +x, 90 = +z) for profiles."""
	return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
			cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def guard_pts(x0, x1, ztop, depth, th, round_r=0.012):
	"""Trigger guard as a U hanging under the frame from x0 to x1 (concept frame)."""
	zb = ztop - depth
	outer = [(x0, ztop), (x0 - 0.002, zb + 0.006), (x0 + 0.006, zb)]
	outer += arc(x1 - round_r, zb + round_r, round_r, -90, 0) + [(x1, ztop)]
	inner = [(x1 - th, ztop)] + arc(x1 - round_r, zb + round_r, round_r - th, 0, -90)
	inner += [(x0 + 0.006, zb + th), (x0 + th - 0.001, zb + 0.006), (x0 + th, ztop)]
	return outer + inner


def trigger_pts(x, ztop, curl=0.016):
	return [(x, ztop), (x + 0.004, ztop), (x + 0.003, ztop - curl * 0.6), (x - 0.001, ztop - curl),
			(x - 0.004, ztop - curl + 0.002), (x - 0.0005, ztop - curl * 0.6)]


def grip_prof(name, pts, w, mat, bevel=0.0, segments=2):
	"""A profile in the grip's own frame ((z, y) points, y up the grip), w wide."""
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((-w / 2, y, z)) for z, y in pts])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
	bmesh.ops.translate(bm, vec=Vector((w, 0, 0)), verts=moved)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return obj_from_bm(name, bm, mat, xform(GRIP_POS, GRIP_ROT), bevel, segments)


def in_grip(objs):
	"""Moves objects authored in the grip's frame onto the grip."""
	return moved(objs, xform(GRIP_POS, GRIP_ROT))


def moved(objs, matrix):
	"""Applies a Godot-frame transform to objects' meshes."""
	for o in objs:
		o.data.transform(G2B @ matrix @ G2B.inverted())
	return objs


def torus(name, major, minor, pos, rot, mat, segments=12, ring=6):
	"""A ring round the local z axis, placed at pos/rot (Godot frame)."""
	bm = bmesh.new()
	rows = []
	for i in range(segments):
		a = 2 * math.pi * i / segments
		row = []
		for j in range(ring):
			b = 2 * math.pi * j / ring
			d = major + minor * math.cos(b)
			row.append(bm.verts.new((d * math.cos(a), d * math.sin(a), minor * math.sin(b))))
		rows.append(row)
	for i in range(segments):
		for j in range(ring):
			a, b = rows[i], rows[(i + 1) % segments]
			bm.faces.new((a[j], b[j], b[(j + 1) % ring], a[(j + 1) % ring]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return obj_from_bm(name, bm, mat, xform(pos, rot))


def bead(name, pos, r, mat):
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=r)
	return obj_from_bm(name, bm, mat, xform(pos))


def cable(points, mat, r=0.0016, res=12, bevel_res=2):
	"""A cable through Godot-frame points (`res` steps per span, `bevel_res`
	rounds the section)."""
	cu = bpy.data.curves.new("Cable", "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = r
	cu.bevel_resolution = bevel_res
	cu.resolution_u = res
	sp = cu.splines.new("BEZIER")
	sp.bezier_points.add(len(points) - 1)
	for bp_, p in zip(sp.bezier_points, points):
		bp_.co = G2B @ Vector(p)
		bp_.handle_left_type = bp_.handle_right_type = "AUTO"
	ob = bpy.data.objects.new("Cable", cu)
	bpy.context.collection.objects.link(ob)
	cu.materials.append(bpy.data.materials[mat])
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.convert(target="MESH")
	return ob


def parent_to(child, parent):
	child.parent = parent
	child.matrix_parent_inverse = parent.matrix_world.inverted()


# --- the Ghost Line ----------------------------------------------------------------

# The concept's trigger guard top and grip line up with the old grip.
C = Concept(at=(-0.0136, 0.085), to=(-0.03, 0.056))
BORE_Z = 0.115  # concept height of the bore
CAN_FRONT = 0.262 if TIER < 2 else 0.279  # the brake adds to the line from tier 2


def gl_slide():
	"""The back of the line: the part that cycles. The ammo screen (in the rear
	sight block) and the holo sight ride on it."""
	parts = [C.sym("SlideBody", [(-0.04, 0.099), (0.0278, 0.099), (0.0278, 0.1338), (-0.032, 0.133), (-0.042, 0.124)],
			0.026, "pistol_black", bevel=0.0018)]
	parts += C.sides("SlideStripe", [(-0.03, 0.127), (0.0275, 0.12795), (0.0275, 0.13095), (-0.03, 0.13)], 0.013, 0.0006, "pistol_stripe")
	for i in range(6):
		x = -0.03 + 0.022 * (i + 0.5) / 6
		parts += C.sides("Serration", [(x - 0.0008, 0.103), (x + 0.0008, 0.103), (x + 0.0038, 0.1255), (x + 0.0022, 0.1255)], 0.013, 0.0006, "pistol_dark")
	# Rear sight block; its sloped back is the ammo screen, facing her eye.
	parts.append(C.sym("RearBlock", [(-0.033, 0.1325), (-0.011, 0.1325), (-0.013, 0.143), (-0.022, 0.146)], 0.02, "pistol_black", bevel=0.001))
	p0, p1 = C.p(-0.033, 0, 0.1325), C.p(-0.022, 0, 0.146)
	along = (p1 - p0).normalized()
	normal = Vector((0, -along.z, along.y))
	tilt = (-math.degrees(math.atan2(normal.y, normal.z)), 0, 0)
	mid = (p0 + p1) / 2
	parts.append(box("AmmoGlass", (0.0195, (p1 - p0).length * 0.8, 0.001), mid + normal * 0.0003, "pistol_screen", rot=tilt))
	readout = empty("AmmoReadout", mid + normal * 0.0011, tilt)
	parts.append(box("SightDot", (0.003, 0.0024, 0.003), C.p(-0.0175, 0, 0.1452), "pistol_led"))
	# Slim holo sight on the slide, in front of the screen: two raked cheeks
	# and a hood round the pane.
	parts.append(C.sym("HoloBase", [(-0.009, 0.1328), (0.024, 0.1328), (0.022, 0.138), (-0.007, 0.138)], 0.02, "pistol_black", bevel=0.001))
	parts += C.sides("HoloCheek", [(-0.003, 0.1375), (0.015, 0.1375), (0.0105, 0.1515), (0.0012, 0.1515)], 0.0085, 0.0022, "pistol_dark")
	hood_mat = "pistol_gold" if TIER >= 5 else ("pistol_armor" if TIER >= 3 else "pistol_dark")
	if TIER >= 3:
		parts.append(C.box("HoloHood", (0.006, 0, 0.1528), (0.015, 0.025, 0.003), hood_mat, bevel=0.001))
		parts += C.sides("HoloWing", [(-0.001, 0.1385), (0.013, 0.1385), (0.0095, 0.151), (0.002, 0.151)], 0.0107, 0.0016, "pistol_dark")
	else:
		parts.append(C.box("HoloHood", (0.0058, 0, 0.1525), (0.0115, 0.0213, 0.0025), hood_mat, bevel=0.0008))
	pane_w, pane_h = 0.0198, 0.0156
	pane_y = C.p(0, 0, 0.138).y + pane_h / 2 + 0.0002
	pane_z = C.p(0.0062, 0, 0).z
	parts.append(C.box("HoloEmitter", (0.019, 0, 0.1388), (0.004, 0.005, 0.0022), "pistol_emitter"))
	if TIER >= 5:
		parts += [C.box("Trim", (-0.0015, s * 0.0125, 0.1335), (0.057, 0.0016, 0.0016), "pistol_gold") for s in (-1, 1)]
	bpy.ops.mesh.primitive_plane_add(size=1.0)
	pane = bpy.context.active_object
	pane.name = pane.data.name = "HoloGlass"
	pane.data.transform(Matrix.Diagonal((pane_w, pane_h, 1.0, 1.0)))
	pane.data.transform(Matrix.Rotation(math.radians(90), 4, "X"))  # faces Godot +z, the shooter
	pane.data.transform(G2B @ Matrix.Translation(Vector((0, pane_y, pane_z))) @ G2B.inverted())
	pane.data.materials.append(bpy.data.materials["pistol_holo"])
	slide = join("Slide", parts)
	parent_to(readout, slide)
	parent_to(pane, slide)
	return slide


def gl_can():
	"""The front of the line: the integral can, static. Returns the can and its vents."""
	parts = [C.sym("Can", [(0.0285, 0.099), (0.105, 0.099), (0.105, 0.096), (0.255, 0.097), (0.262, 0.104), (0.262, 0.126),
			(0.252, 0.134), (0.06, 0.134), (0.0285, 0.1338)], 0.026, "pistol_black", bevel=0.0018)]
	parts += C.sides("CanStripe", [(0.0292, 0.12796), (0.25, 0.128), (0.25, 0.131), (0.0292, 0.13096)], 0.013, 0.0006, "pistol_stripe")
	# the barrel shows in the gap when the slide runs back
	parts.append(C.cyl("Barrel", (-0.004, 0, BORE_Z + 0.001), (0.03, 0, BORE_Z + 0.001), 0.0052, "pistol_dark", segments=12))
	parts.append(C.box("FrontSight", (0.24, 0, 0.1372), (0.006, 0.004, 0.008), "pistol_dark", bevel=0.0006))
	vents = []
	for i in range(6):
		x = 0.15 + i * 0.017
		vents += C.sides("Vent", [(x, 0.104), (x + 0.008, 0.104), (x + 0.011, 0.126), (x + 0.003, 0.126)], 0.013, 0.0007, "pistol_vent")
	if TIER >= 2:
		parts += C.sides("CanStripe2", [(0.11, 0.1006), (0.25, 0.1009), (0.25, 0.1024), (0.11, 0.1021)], 0.013, 0.0006, "pistol_stripe")
		vents += [C.box("TopVent", (0.158 + i * 0.018, 0, 0.1343), (0.009, 0.011, 0.0012), "pistol_vent") for i in range(5)]
		# Ported brake on the end of the can; its ports glow with the vents.
		parts.append(C.sym("Brake", [(0.2615, 0.1), (0.276, 0.1), (0.279, 0.104), (0.279, 0.127), (0.275, 0.131), (0.2615, 0.131)],
				0.029, "pistol_gold" if TIER >= 5 else "pistol_shell", bevel=0.001))
		for x in (0.2645, 0.2705):
			vents += C.sides("Port", [(x, 0.107), (x + 0.0035, 0.107), (x + 0.0035, 0.124), (x, 0.124)], 0.0145, 0.0006, "pistol_vent")
		vents.append(C.box("TopPort", (0.2695, 0, 0.1312), (0.009, 0.014, 0.0012), "pistol_vent"))
	if TIER >= 4:
		# copper bands round the can, either side of the vents
		for x in (0.1455, 0.2495):
			parts.append(C.sym("Band", [(x - 0.0018, 0.0955), (x + 0.0018, 0.0955), (x + 0.0018, 0.1352), (x - 0.0018, 0.1352)], 0.0286, "pistol_copper"))
	if TIER >= 5:
		parts += [C.box("Trim", (0.155, s * 0.0125, 0.1338), (0.19, 0.0016, 0.0016), "pistol_gold") for s in (-1, 1)]
		parts.append(C.cyl("EmitterRing", (CAN_FRONT - 0.0005, 0, BORE_Z), (CAN_FRONT + 0.001, 0, BORE_Z), 0.0075, "pistol_live", segments=16))
	parts.append(C.cyl("Bore", (CAN_FRONT - 0.004, 0, BORE_Z), (CAN_FRONT + 0.0004, 0, BORE_Z), 0.0045, "pistol_screen"))
	return join("Shroud", parts), join("Vents", vents)


def gl_frame():
	"""Frame, guard, trigger, beavertail and the slanted grooved grip."""
	parts = [C.sym("FrameBody", [(-0.045, 0.0995), (0.11, 0.0995), (0.11, 0.086), (0.06, 0.082), (-0.03, 0.084)], 0.024, "pistol_dark", bevel=0.0015)]
	parts.append(C.sym("Guard", guard_pts(0.012, 0.062, 0.0865, 0.0345, 0.005), 0.016, "pistol_dark", bevel=0.0008))
	parts.append(C.sym("Trigger", trigger_pts(0.03, 0.084), 0.006, "pistol_shell", bevel=0.0006))
	parts.append(C.sym("Beavertail", [(-0.03, 0.083), (-0.03, 0.1), (-0.046, 0.1), (-0.058, 0.108), (-0.06, 0.103), (-0.036, 0.083)],
			0.03, "pistol_black", bevel=0.0018))
	parts.append(grip_prof("Grip", [(-0.026, 0.066), (-0.0235, -0.059), (0.0245, -0.059), (0.026, 0.066)], 0.036, "pistol_black", bevel=0.003, segments=3))
	grooves = [box("Groove", (0.0012, 0.088, 0.0016), (s * 0.0181, -0.008, -0.018 + i * 0.006), "pistol_dark") for s in (-1, 1) for i in range(7)]
	loop = [torus("Loop", 0.0042, 0.0012, (0, -0.0535, 0.0282), (0, 90, 0), "pistol_shell", segments=10, ring=5)]
	parts += in_grip(grooves + loop)
	return join("Frame", parts)


def gl_mag():
	"""The mag's base plate, orange; from tier 3 an extended mag 3 cm longer."""
	if TIER >= 3:
		parts = [box("MagBody", (0.033, 0.032, 0.046), (0, -0.0745, 0), "pistol_black", bevel=0.0015)]
		parts += [box("MagRib", (0.0336, 0.002, 0.0466), (0, -0.068 - k * 0.0075, 0), "pistol_dark") for k in range(3)]
		parts.append(box("MagFoot", (0.038, 0.011, 0.054), (0, -0.0945, 0.0005), "pistol_armor", bevel=0.002))
	else:
		parts = [box("MagPlate", (0.038, 0.011, 0.054), (0, -0.0645, 0.0005), "pistol_armor", bevel=0.002)]
		if TIER >= 1:
			parts.append(box("MagBumper", (0.0392, 0.0045, 0.0552), (0, -0.0612, 0.0005), "pistol_tape", bevel=0.001))
	return join("MagBase", in_grip(parts))


def gl_leds():
	"""Six LED pairs along the frame, back to front: the ammo strip."""
	out = []
	for i in range(6):
		x = 0.052 + i * 0.008
		out.append(join("Led%d" % i, [C.box("Led", (x, s * 0.0124, 0.0905), (0.005, 0.001, 0.0038), "pistol_led") for s in (-1, 1)]))
	return out


def gl_tracker():
	"""The tracker pod on the slide's nose: a window on top and a lens looking
	down the barrel. Tier 0 smashed and taped, 1-3 patched, 4-5 rebuilt."""
	pod = C.sym("TrackerScreen", [(0.03, 0.1335), (0.035, 0.143), (0.095, 0.145), (0.104, 0.1335)], 0.018, "pistol_black", bevel=0.0012)
	win = xform(C.p(0.065, 0, 0.1442) + Vector((0, 0.0002, 0)), (math.degrees(math.atan(0.002 / 0.06)), 0, 0))
	w, h = 0.052, 0.0142  # window length (z) and width (x)
	empty("TrackerImpact", win @ Vector((0.002, 0.001, 0.007)))
	lens_at = (0.1032, 0, 0.139), (0.1062, 0, 0.139)
	extra = []
	if TIER >= 4:
		parts = [box("Screen", (h, 0.0008, w), (0, 0.0003, 0), "pistol_live")]
		parts += [box("Bezel", (0.0016, 0.0016, w + 0.002), (s * (h / 2 + 0.0004), 0.0005, 0), "pistol_gold" if TIER >= 5 else "pistol_shell") for s in (-1, 1)]
		if TIER >= 5:
			# corner brackets of the lock reticle, standing proud of the glass
			for sx in (-1, 1):
				for sz in (-1, 1):
					cx, cz = sx * h * 0.28, sz * w * 0.2
					parts.append(box("Bracket", (0.0012, 0.0012, 0.006), (cx, 0.001, cz - sz * 0.0024), "pistol_gold"))
					parts.append(box("Bracket", (0.0045, 0.0012, 0.0012), (cx - sx * 0.0017, 0.001, cz), "pistol_gold"))
		parts = moved(parts, win)
		parts.append(C.cyl("Lens", *lens_at, 0.0045, "pistol_live"))
		if TIER >= 5:
			extra.append(C.cyl("LensBezel", (0.1028, 0, 0.139), (0.1055, 0, 0.139), 0.0058, "pistol_gold"))
	elif TIER >= 1:
		# the shards pried out and a scrap plate riveted over the hole, a stripe painted on by hand
		parts = [box("Patch", (h + 0.0015, 0.0012, w + 0.002), (0, 0.0004, 0), "pistol_blue", bevel=0.0004)]
		parts.append(box("PatchStripe", (0.004, 0.0014, w * 0.8), (0.003, 0.0006, 0), "pistol_stripe", rot=(0, 3, 0)))
		for sx in (-1, 1):
			for sz in (-1, 1):
				bm = bmesh.new()
				bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0011, radius2=0.0011, depth=0.001)
				parts.append(obj_from_bm("Rivet", bm, "pistol_dark", xform((sx * (h / 2 - 0.002), 0.0011, sz * (w / 2 - 0.0025)), (90, 0, 0)), smooth=False))
		parts = moved(parts, win)
		parts.append(C.cyl("Lens", *lens_at, 0.0045, "pistol_screen"))
	else:
		# smashed: the window in shards round an impact point, one piece gone
		impact = Vector((0.007, 0.002))  # (along, across)
		corners = [Vector((-w / 2, -h / 2)), Vector((w / 2, -h / 2)), Vector((w / 2, h / 2)), Vector((-w / 2, h / 2))]
		ring = []
		for i in range(4):
			a, b = corners[i], corners[(i + 1) % 4]
			ring.append(a)
			ring.append(a.lerp(b, random.uniform(0.35, 0.65)))
		parts = []
		for i in range(len(ring)):
			if i == 5:
				continue  # this shard fell out
			a, b = ring[i], ring[(i + 1) % len(ring)]
			jitter = Vector((random.uniform(-0.001, 0.001), random.uniform(-0.001, 0.001)))
			pts = [impact + jitter, a, b]
			mid = (pts[0] + pts[1] + pts[2]) / 3.0
			pts = [mid + (p - mid) * 0.86 for p in pts]
			bm = bmesh.new()
			bm.faces.new([bm.verts.new((p.y, 0.0, p.x)) for p in pts])
			bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
			bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.0008)
			tilt = xform((0, 0.0004, 0), (random.uniform(-5, 5), 0, random.uniform(-7, 7)))
			parts.append(obj_from_bm("Shard%d" % i, bm, "pistol_tracker", win @ tilt, smooth=False))
		lens = C.cyl("Lens", *lens_at, 0.0045, "pistol_tracker")
		moved([lens], Matrix.Translation(C.p(0.105, 0, 0.139)) @ xform((0, 0, 0), (4, 3, 0)) @ Matrix.Translation(-C.p(0.105, 0, 0.139)))
		parts.append(lens)
		# and Eco's tape round the pod to hold it together
		extra.append(box("PodTape", (0.0236, 0.0146, 0.0085), C.p(0.047, 0, 0.1385), "pistol_tape", rot=(0, 5, 0), bevel=0.0008))
		extra += moved([box("PodTape", (0.0075, 0.0012, 0.03), (0, 0.0012, 0.004), "pistol_tape", rot=(0, 28, 0))], win)
	return pod, join("TrackerGlass", parts), extra


def gl_charm():
	"""Her father's dog tag on a bead chain from the loop at the butt. The Charm
	pivot is what the game swings."""
	at = xform(GRIP_POS, GRIP_ROT) @ Vector((0, -0.0575, 0.031))
	pivot = empty("Charm", at)
	parts = [bead("Bead", at + Vector((0, -0.003 - i * 0.0048, 0)), 0.0021, "pistol_shell") for i in range(7)]
	r, half = 0.0072, 0.0098  # a stamped pill: round ends, straight sides
	outline = arc(0, half, r, 0, 180, 6) + arc(0, -half, r, 180, 360, 6)
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((-0.0008, y, z)) for z, y in outline])
	ext = bmesh.ops.extrude_face_region(bm, geom=[f])
	bmesh.ops.translate(bm, vec=Vector((0.0016, 0, 0)), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	parts.append(obj_from_bm("Tag", bm, "pistol_tag", Matrix.Translation(at + Vector((0, -0.0545, 0))), bevel=0.0004))
	tag = join("CharmTag", parts)
	parent_to(tag, pivot)
	return pivot


def gl_details():
	"""Tape, plates, cables and the cell: everything bolted on that doesn't move."""
	out = []
	if TIER >= 1:
		bands = (-0.044, -0.032) if TIER >= 3 else (-0.044,)
		out += in_grip([box("Tape", (0.0372, 0.0075, 0.0515), (0, y, 0), "pistol_tape", rot=(random.uniform(-7, 7), 0, random.uniform(-3, 3)), bevel=0.001) for y in bands])
	if TIER >= 3:
		# armour cut from a titan's plating, bolted over the can's flanks
		out += C.sides("ArmorPlate", [(0.036, 0.104), (0.14, 0.104), (0.14, 0.1235), (0.036, 0.1235)], 0.013, 0.0018, "pistol_armor")
		for s in (-1, 1):
			for x in (0.042, 0.134):
				out.append(C.cyl("PlateBolt", (x, s * 0.0147, 0.1138), (x, s * 0.0163, 0.1138), 0.0016, "pistol_shell", segments=6))
	if TIER >= 4:
		for s, mat in ((1, "pistol_stripe"), (-1, "pistol_blue")):
			pts = [C.p(0.098, 0, 0.092), C.p(0.104, 0, 0.112), C.p(0.1, 0, 0.132), C.p(0.092, 0, 0.1392)]
			for p, x in zip(pts, (0.0148, 0.0185, 0.0175, 0.0112)):
				p.x = s * x
			out.append(cable(pts, mat))
	if TIER >= 5:
		# a power cell clamped under the dust cover
		out.append(C.cyl("Cell", (0.066, 0, 0.0755), (0.104, 0, 0.0755), 0.0042, "pistol_live", segments=8))
		out.append(C.box("CellMount", (0.085, 0, 0.0805), (0.03, 0.006, 0.005), "pistol_dark"))
		out += [C.cyl("Clamp", (x - 0.0015, 0, 0.0755), (x + 0.0015, 0, 0.0755), 0.0052, "pistol_gold", segments=8) for x in (0.07, 0.1)]
	return out


# --- build -------------------------------------------------------------------

def build():
	reset()
	gl_slide()
	gl_can()
	gl_frame()
	gl_mag()
	gl_leds()
	pod, _glass, extra = gl_tracker()
	gl_charm()
	details = gl_details() + extra
	if details:
		join("Details", details)
	empty("Muzzle", C.p(CAN_FRONT + 0.002, 0, BORE_Z))
	bpy.ops.export_scene.gltf(
		filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
	)
	tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", OUT, "triangles", tris)


if __name__ == "__main__":
	build()
