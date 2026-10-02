"""Builds Eco's smart pistol in Blender and exports it for Godot.

    blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol.glb
    blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol_t3.glb --tier 3

Her father's smart pistol, cleaned up: a sleek two-tone slide and frame in
his titan's colours, a sloped ammo screen facing the shooter, a holo sight on
top, and the auto-tracking screen on the left side smashed in.

Eco has kept building on it since: an integrated suppressor shroud with
glowing vent ports, a strip of LEDs along the top of the slide, hex bolts
she machined herself, tape wrapped round the grip, a cable she rerouted to
the ammo screen, and her father's dog tag hanging off the rail.

`--tier N` (1-5) builds the upgrades, each on top of the one before:
  0  Dad's pistol: tracker smashed, short suppressor (the default).
  1  Patched: a riveted scrap plate over the smashed tracker, a mag bumper,
     more tape, an extra row of vents.
  2  Tuned: a longer shroud with a ported muzzle brake whose ports glow too,
     and a second stripe down the slide.
  3  Scrapforged: armour plates cut from a titan bolted to the slide, an
     extended mag, a wider holo hood.
  4  Rewired: the tracker rebuilt with a working screen, copper coils round
     the shroud, cables down both sides.
  5  Legacy: the smart pistol restored and then some: gold trim, a glowing
     emitter ring at the muzzle, a power cell under the frame, and the lock
     reticle back on the tracker screen.

Everything is authored in Godot's frame (x right, y up, -z forward, metres)
and converted on the way in, so the numbers line up with the viewmodel code.
The grip keeps the old position and angle so Eco's glove (eco_fp_arm.glb)
still closes round it. Object names are what the game looks up: Slide,
MagBase, AmmoReadout, TrackerScreen, TrackerGlass, HoloGlass, Muzzle, Vents,
Led0..Led5, Charm (the dog tag's pivot).
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


# --- parts ------------------------------------------------------------------

GRIP_POS = Vector((0, -0.088, 0.072))
GRIP_ROT = (-16, 0, 0)


def slide():
	# Long, low slide with a raked nose: the front top edge drops toward the muzzle.
	bm = box_bm((0.040, 0.044, 0.245), (0, 0.018, -0.008))
	for v in bm.verts:
		if v.co.z < -0.1 and v.co.y > 0.03:
			v.co.y -= 0.013
			v.co.z += 0.012
		if v.co.z > 0.1 and v.co.y > 0.03:
			v.co.z -= 0.006
	s = obj_from_bm("Slide", bm, "pistol_shell", bevel=0.0035, segments=3)
	# The slide's accent lines, in his titan's blue and orange.
	b1 = box("SlideBlue", (0.0425, 0.010, 0.15), (0, 0.003, 0.02), "pistol_blue", bevel=0.0015)
	b2 = box("SlideStripe", (0.0428, 0.0028, 0.15), (0, 0.0095, 0.02), "pistol_stripe")
	# rear grip cuts
	cuts = [box("Cut%d" % i, (0.0418, 0.022, 0.0025), (0, 0.022, 0.078 + i * 0.0065), "pistol_dark") for i in range(4)]
	extra = []
	if TIER >= 2:
		extra.append(box("SlideStripe2", (0.0428, 0.0016, 0.12), (0, 0.0135, 0.035), "pistol_stripe"))
	if TIER >= 3:
		# Armour cut from a titan's plating, bolted over the slide's flanks.
		for side in (-1, 1):
			extra.append(box("ArmorPlate", (0.0022, 0.02, 0.052), (side * 0.0212, 0.025, 0.045), "pistol_armor", bevel=0.0008))
			for z in (0.024, 0.066):
				bm = bmesh.new()
				bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0016, radius2=0.0016, depth=0.0012)
				extra.append(obj_from_bm("PlateBolt", bm, "pistol_shell", xform((side * 0.0226, 0.031, z), (0, 90, 0)), smooth=False))
	if TIER >= 5:
		# Gold trim along both top edges of the slide.
		slope = math.degrees(math.atan(0.013 / 0.227))
		for side in (-1, 1):
			extra.append(box("Trim", (0.0016, 0.0016, 0.19), (side * 0.0195, slide_top(0.0) - 0.0005, 0.0), "pistol_gold", rot=(-slope, 0, 0)))
	return [s, b1, b2] + cuts + extra


def frame():
	bm = box_bm((0.036, 0.026, 0.19), (0, -0.016, -0.028))
	for v in bm.verts:
		if v.co.z < -0.1 and v.co.y < -0.02:
			v.co.z += 0.016  # undercut nose
	f = obj_from_bm("Frame", bm, "pistol_dark", bevel=0.003, segments=2)
	rail = [box("Rail%d" % i, (0.03, 0.004, 0.006), (0, -0.031, -0.095 + i * 0.012), "pistol_dark", bevel=0.001) for i in range(4)]
	return [f] + rail


SHROUD_Y = 0.01
SHROUD_R = 0.0165
# The shroud grows with the upgrades; the back always meets the slide's nose.
SHROUD_LENGTH = 0.088 + (0.02 if TIER >= 2 else 0.0) + (0.012 if TIER >= 4 else 0.0)
SHROUD_FRONT = -0.117 - SHROUD_LENGTH
VENT_ROWS = 4 + min(TIER, 2)


def suppressor():
	"""Integrated suppressor: an octagonal shroud out of the slide's nose, an end
	cap with an orange band, and vent ports that glow when the gun runs hot."""
	length = SHROUD_LENGTH
	z0 = SHROUD_FRONT + length / 2
	shroud = prism("Shroud", SHROUD_R, length, (0, SHROUD_Y, z0), "pistol_dark", bevel=0.0012)
	cap = prism("ShroudCap", SHROUD_R * 1.04, 0.009, (0, SHROUD_Y, SHROUD_FRONT - 0.0035), "pistol_gold" if TIER >= 5 else "pistol_shell", bevel=0.0015)
	band = prism("ShroudBand", SHROUD_R * 1.03, 0.003, (0, SHROUD_Y, SHROUD_FRONT + 0.008), "pistol_stripe")
	bore = cylinder("Bore", 0.0045, 0.012, (0, SHROUD_Y, SHROUD_FRONT - 0.004), "pistol_screen", axis="z")
	# Ports on the three upper faces, four rows down the shroud.
	apothem = SHROUD_R * math.cos(math.pi / 8)
	vents = []
	for face in (-45, 0, 45):
		a = math.radians(face)
		for row in range(VENT_ROWS):
			z = SHROUD_FRONT + 0.02 + row * 0.014
			pos = (math.sin(a) * apothem, SHROUD_Y + math.cos(a) * apothem, z)
			vents.append(box("Vent", (0.0034, 0.0012, 0.0095), pos, "pistol_vent", rot=(0, 0, -face)))
	parts = [shroud, cap, band, bore]
	if TIER >= 2:
		# Ported muzzle brake: a collar with two slots a side, glowing like the vents.
		brake_z = SHROUD_FRONT + 0.008
		parts.append(prism("Brake", SHROUD_R * 1.12, 0.014, (0, SHROUD_Y, brake_z), "pistol_shell", bevel=0.0012))
		for side in (-1, 1):
			for k in range(2):
				vents.append(box("Port", (0.0012, 0.006, 0.0035), (side * SHROUD_R * 1.12, SHROUD_Y, brake_z - 0.0035 + k * 0.007), "pistol_vent"))
	if TIER >= 4:
		# Copper coils wound round the shroud.
		for k in range(3):
			z = SHROUD_FRONT + 0.03 + k * 0.022
			parts.append(prism("Coil", SHROUD_R * 1.07, 0.0035, (0, SHROUD_Y, z), "pistol_copper", segments=8))
	if TIER >= 5:
		# Emitter ring round the muzzle.
		parts.append(prism("EmitterRing", SHROUD_R * 0.7, 0.002, (0, SHROUD_Y, SHROUD_FRONT - 0.0085), "pistol_live", segments=8))
	return parts, join("Vents", vents)


def slide_top(z):
	"""Height of the slide's top at z: it slopes down toward the raked nose."""
	return 0.027 + 0.013 * (z + 0.1185) / 0.227


def leds():
	"""Six LED pairs along the top of the slide, front of the holo sight."""
	out = []
	slope = math.degrees(math.atan(0.013 / 0.227))
	for i in range(6):
		z = -0.004 - i * 0.0155
		pair = [box("Led", (0.0042, 0.0016, 0.0105), (s * 0.0115, slide_top(z) + 0.0003, z), "pistol_led", rot=(-slope, 0, 0), bevel=0.0005) for s in (-1, 1)]
		out.append(join("Led%d" % i, pair))
	return out


def bolts():
	"""Hex bolts she machined herself, on the frame and the shroud."""
	out = []
	for side in (-1, 1):
		for y, z in ((-0.012, -0.095), (-0.012, -0.03), (-0.012, 0.045)):
			bm = bmesh.new()
			bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0021, radius2=0.0021, depth=0.0014)
			out.append(obj_from_bm("Bolt", bm, "pistol_shell", xform((side * 0.0183, y, z), (0, 90, 0)), smooth=False))
	return out


def cable(side=1):
	"""A cable rerouted from the frame to the ammo screen, in a loose loop."""
	cu = bpy.data.curves.new("Cable", "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = 0.0017
	cu.bevel_resolution = 2
	sp = cu.splines.new("BEZIER")
	pts = [Vector((0.0178 * side, -0.006, 0.056)), Vector((0.029 * side, -0.002, 0.084)), Vector((0.027 * side, 0.022, 0.1)), Vector((0.0155 * side, 0.029, 0.11))]
	sp.bezier_points.add(len(pts) - 1)
	for bp, p in zip(sp.bezier_points, pts):
		bp.co = G2B @ p
		bp.handle_left_type = bp.handle_right_type = "AUTO"
	ob = bpy.data.objects.new("Cable", cu)
	bpy.context.collection.objects.link(ob)
	cu.materials.append(bpy.data.materials["pistol_stripe" if side > 0 else "pistol_blue"])
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.convert(target="MESH")
	return ob


def grip_tape():
	"""Tape wrapped round the bottom of the grip, a little crooked."""
	bands = []
	rows = (-0.044, -0.034, -0.024) if TIER >= 1 else (-0.044, -0.034)
	for i, y in enumerate(rows):
		b = box("Tape", (0.0352, 0.0075, 0.0515), (0, y, 0), "pistol_tape", rot=(random.uniform(-7, 7), 0, random.uniform(-3, 3)), bevel=0.001)
		b.data.transform(G2B @ xform(GRIP_POS, GRIP_ROT) @ G2B.inverted())
		bands.append(b)
	return bands


def charm():
	"""Her father's dog tag on a short chain, hanging from the front of the rail.
	The Charm pivot is what the game swings."""
	loop_at = Vector((0, -0.034, -0.1))
	pivot = empty("Charm", loop_at)
	parts = [
		box("Ring", (0.0014, 0.006, 0.006), (0, -0.003, 0), "pistol_shell", bevel=0.0006),
		box("Link", (0.0014, 0.007, 0.003), (0, -0.009, 0), "pistol_shell", bevel=0.0006),
		box("Tag", (0.0018, 0.028, 0.018), (0, -0.026, 0), "pistol_tag", bevel=0.0025, segments=3),
		box("TagDot", (0.0022, 0.005, 0.005), (0, -0.018, 0), "pistol_stripe", bevel=0.001),
	]
	for p in parts:
		p.data.transform(G2B @ Matrix.Translation(loop_at) @ G2B.inverted())
	tag = join("CharmTag", parts)
	tag.parent = pivot
	tag.matrix_parent_inverse = pivot.matrix_world.inverted()
	return pivot


def power_cell():
	"""Tier 5: a glowing power cell clamped under the frame, on the rail."""
	cell = cylinder("Cell", 0.0055, 0.03, (0, -0.0385, -0.077), "pistol_live", axis="z", segments=8)
	clamps = [cylinder("Clamp", 0.0068, 0.004, (0, -0.0385, z), "pistol_gold", axis="z", segments=8) for z in (-0.09, -0.064)]
	mount = box("CellMount", (0.008, 0.006, 0.03), (0, -0.0335, -0.077), "pistol_dark")
	return [cell, mount] + clamps


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


def ammo_screen():
	# Sloped plate on the back of the slide, tilted up toward the shooter's eye.
	pos = Vector((0, 0.03, 0.116))
	rot = (-38, 0, 0)
	housing = box("AmmoScreen", (0.03, 0.022, 0.007), (0, 0, 0), "pistol_dark", bevel=0.0015)
	glass = box("AmmoGlass", (0.024, 0.016, 0.001), (0, 0, 0.0034), "pistol_screen")
	for o in (housing, glass):
		o.data.transform(G2B @ xform(pos, rot) @ G2B.inverted())
	readout = empty("AmmoReadout", pos + (xform((0, 0, 0), rot).to_3x3() @ Vector((0, 0, 0.0046))), rot)
	return [housing], glass, readout


def tracker_screen():
	# The auto-tracking display on the left of the slide, smashed in: the
	# glass is in shards around an impact point, one piece gone.
	pos = Vector((-0.0222, 0.017, -0.055))
	housing = box("TrackerScreen", (0.006, 0.03, 0.062), pos, "pistol_dark", bevel=0.0015)
	w, h = 0.054, 0.025
	impact = Vector((0.006, 0.003))
	empty("TrackerImpact", pos + Vector((-0.004, impact.y, -impact.x)))
	if TIER >= 4:
		return [housing], tracker_rebuilt(pos, w, h)
	if TIER >= 1:
		return [housing], tracker_patch(pos, w, h)
	corners = [Vector((-w / 2, -h / 2)), Vector((w / 2, -h / 2)), Vector((w / 2, h / 2)), Vector((-w / 2, h / 2))]
	ring = []
	for i in range(4):
		a, b = corners[i], corners[(i + 1) % 4]
		ring.append(a)
		ring.append(a.lerp(b, random.uniform(0.35, 0.65)))
	shards = []
	for i in range(len(ring)):
		if i == 5:
			continue  # this shard fell out
		a, b = ring[i], ring[(i + 1) % len(ring)]
		bm = bmesh.new()
		jitter = Vector((random.uniform(-0.001, 0.001), random.uniform(-0.001, 0.001)))
		pts = [impact + jitter, a, b]
		# shrink each shard toward its middle so the cracks open up
		mid = (pts[0] + pts[1] + pts[2]) / 3.0
		pts = [mid + (p - mid) * 0.86 for p in pts]
		verts = [bm.verts.new((-0.0005, p.y, -p.x)) for p in pts]  # facing -x, z runs back
		bm.faces.new(verts)
		bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.0008)
		# each shard sits a little skewed, like the glass took a hit
		tilt = xform((0, 0, 0), (random.uniform(-6, 6), random.uniform(-8, 8), 0))
		shard = obj_from_bm("Shard%d" % i, bm, "pistol_tracker", xform(pos + Vector((-0.0032, 0, 0))) @ tilt, smooth=False)
		shards.append(shard)
	glass = join("TrackerGlass", shards)
	return [housing], glass


def tracker_patch(pos, w, h):
	"""Tiers 1-3: the smashed glass pried out and a scrap plate riveted over
	the hole, with a stripe Eco painted on it by hand."""
	x = pos.x - 0.0036
	parts = [box("Patch", (0.0012, h + 0.002, w + 0.002), (x, pos.y, pos.z), "pistol_blue", rot=(1.5, 0, 0), bevel=0.0005)]
	parts.append(box("PatchStripe", (0.0014, 0.005, w * 0.8), (x - 0.0002, pos.y + 0.004, pos.z), "pistol_stripe", rot=(-4, 0, 0)))
	for dy in (-h / 2 + 0.003, h / 2 - 0.003):
		for dz in (-w / 2 + 0.003, w / 2 - 0.003):
			bm = bmesh.new()
			bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0013, radius2=0.0013, depth=0.001)
			parts.append(obj_from_bm("Rivet", bm, "pistol_dark", xform((x - 0.0008, pos.y + dy, pos.z + dz), (0, 90, 0)), smooth=False))
	return join("TrackerGlass", parts)


def tracker_rebuilt(pos, w, h):
	"""Tiers 4-5: a new tracker screen, lit. Tier 5 brings the lock reticle back."""
	x = pos.x - 0.0034
	parts = [box("Screen", (0.0008, h, w), (x, pos.y, pos.z), "pistol_live")]
	if TIER >= 5:
		# corner brackets of the lock reticle, standing proud of the glass
		for sy in (-1, 1):
			for sz in (-1, 1):
				cy, cz = pos.y + sy * h * 0.28, pos.z + sz * h * 0.42
				parts.append(box("Bracket", (0.0012, 0.0012, 0.006), (x - 0.0006, cy, cz - sz * 0.0024), "pistol_gold"))
				parts.append(box("Bracket", (0.0012, 0.006, 0.0012), (x - 0.0006, cy - sy * 0.0024, cz), "pistol_gold"))
	bezel = [box("Bezel", (0.0016, 0.002, w + 0.003), (x - 0.0002, pos.y + s * (h / 2 + 0.0005), pos.z), "pistol_shell") for s in (-1, 1)]
	return join("TrackerGlass", parts + bezel)


def holo_sight():
	base = box("HoloBase", (0.026, 0.012, 0.032), (0, 0.039, 0.035), "pistol_dark", bevel=0.0015)
	posts = [box("HoloPost", (0.0032, 0.03, 0.008), (s * 0.0128, 0.058, 0.028), "pistol_shell", bevel=0.0012) for s in (-1, 1)]
	hood = box("HoloHood", (0.0288, 0.0035, 0.014), (0, 0.0735, 0.03), "pistol_shell", bevel=0.0012)
	if TIER >= 3:
		# a wider hood with side wings that shade the pane
		hood = box("HoloHood", (0.034, 0.004, 0.018), (0, 0.0738, 0.03), "pistol_armor" if TIER < 5 else "pistol_gold", bevel=0.0014)
		posts += [box("HoloWing", (0.0024, 0.024, 0.016), (s * 0.016, 0.062, 0.03), "pistol_shell", rot=(0, 0, s * -8), bevel=0.001) for s in (-1, 1)]
	emitter = box("HoloEmitter", (0.006, 0.004, 0.005), (0, 0.047, 0.047), "pistol_emitter", bevel=0.001)
	# The projection pane: a UV'd quad the holo shader draws the reticle on.
	bpy.ops.mesh.primitive_plane_add(size=1.0)
	pane = bpy.context.active_object
	pane.name = "HoloGlass"
	pane.data.name = "HoloGlass"
	# plane is XY in Blender (normal +Z); in Godot terms make it face +z (the shooter)
	pane.data.transform(Matrix.Diagonal((0.0225, 0.0245, 1.0, 1.0)))
	pane.data.transform(Matrix.Rotation(math.radians(90), 4, "X"))  # normal now Blender -Y = Godot +z
	pane.data.transform(G2B @ Matrix.Translation(Vector((0, 0.0575, 0.028))) @ G2B.inverted())
	pane.data.materials.append(bpy.data.materials["pistol_holo"])
	return [base, hood] + posts, emitter, pane


# --- build -------------------------------------------------------------------

def build():
	reset()
	body = slide()
	lower = frame() + guard_and_trigger()
	grip_parts, mag = grip()
	shroud_parts, _ = suppressor()
	leds()
	charm()
	ammo_housing, ammo_glass, _ = ammo_screen()
	tracker_housing, _ = tracker_screen()
	holo_parts, _, _ = holo_sight()
	join("Slide", body)
	join("Frame", lower + grip_parts)
	join("Shroud", shroud_parts)
	details = bolts() + grip_tape() + [cable()]
	if TIER >= 4:
		details.append(cable(-1))
	if TIER >= 5:
		details += power_cell()
	join("Details", details)
	join("AmmoScreen", ammo_housing)
	join("HoloSight", holo_parts)
	empty("Muzzle", (0, SHROUD_Y, SHROUD_FRONT - 0.009))
	for ob in bpy.data.objects:
		ob.select_set(ob.type == "MESH" or ob.type == "EMPTY")
	bpy.ops.export_scene.gltf(
		filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
	)
	tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", OUT, "triangles", tris)


if __name__ == "__main__":
	build()
