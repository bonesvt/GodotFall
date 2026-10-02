"""Builds Eco's smart pistol in Blender and exports it for Godot.

    blender --background --python tools/pistol/build_pistol.py -- assets/models/smart_pistol/smart_pistol.glb

Her father's smart pistol, cleaned up: a sleek two-tone slide and frame in
his titan's colours, a sloped ammo screen facing the shooter, a holo sight on
top, and the auto-tracking screen on the left side smashed in.

Everything is authored in Godot's frame (x right, y up, -z forward, metres)
and converted on the way in, so the numbers line up with the viewmodel code.
The grip keeps the old position and angle so Eco's glove (eco_fp_arm.glb)
still closes round it. Object names are what the game looks up: Slide,
MagBase, AmmoReadout, TrackerScreen, TrackerGlass, HoloGlass, Muzzle.
Materials are placeholders named pistol_*; the import script swaps them for
assets/materials/pistol/*.tres.
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "smart_pistol.glb"
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
	return [s, b1, b2] + cuts


def frame():
	bm = box_bm((0.036, 0.026, 0.19), (0, -0.016, -0.028))
	for v in bm.verts:
		if v.co.z < -0.1 and v.co.y < -0.02:
			v.co.z += 0.016  # undercut nose
	f = obj_from_bm("Frame", bm, "pistol_dark", bevel=0.003, segments=2)
	rail = [box("Rail%d" % i, (0.03, 0.004, 0.006), (0, -0.031, -0.095 + i * 0.012), "pistol_dark", bevel=0.001) for i in range(4)]
	barrel = cylinder("Barrel", 0.0085, 0.022, (0, 0.008, -0.132), "pistol_dark", axis="z", bevel=0.001)
	bore = cylinder("Bore", 0.0048, 0.024, (0, 0.008, -0.134), "pistol_screen", axis="z")
	return [f, barrel, bore] + rail


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
	mag = box("MagBase", (0.037, 0.012, 0.054), (0, -0.064, 0.0), "pistol_shell", bevel=0.003)
	mag.data.transform(G2B @ xform(GRIP_POS, GRIP_ROT) @ G2B.inverted())
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
	empty("TrackerImpact", pos + Vector((-0.004, impact.y, -impact.x)))
	return [housing], glass


def holo_sight():
	base = box("HoloBase", (0.026, 0.005, 0.032), (0, 0.0425, 0.035), "pistol_dark", bevel=0.0015)
	posts = [box("HoloPost", (0.0032, 0.03, 0.008), (s * 0.0128, 0.058, 0.028), "pistol_shell", bevel=0.0012) for s in (-1, 1)]
	hood = box("HoloHood", (0.0288, 0.0035, 0.014), (0, 0.0735, 0.03), "pistol_shell", bevel=0.0012)
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
	ammo_housing, ammo_glass, _ = ammo_screen()
	tracker_housing, _ = tracker_screen()
	holo_parts, _, _ = holo_sight()
	join("Slide", body)
	join("Frame", lower + grip_parts)
	join("AmmoScreen", ammo_housing)
	join("HoloSight", holo_parts)
	empty("Muzzle", (0, 0.008, -0.145))
	for ob in bpy.data.objects:
		ob.select_set(ob.type == "MESH" or ob.type == "EMPTY")
	bpy.ops.export_scene.gltf(
		filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
	)
	tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", OUT, "triangles", tris)


build()
