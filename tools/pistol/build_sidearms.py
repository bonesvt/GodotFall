"""Builds Eco's other sidearms and the pistol attachments in Blender.

    blender --background --python tools/pistol/build_sidearms.py [-- machine_pistol ...]

Writes assets/models/sidearms/*.glb:
  rivet_cannon.glb     Eco's Hand Cannon, a chrome Desert Eagle-style semi-auto
  machine_pistol.glb   a colony machine pistol she took off a grunt (the Brick)
  att_*.glb            attachments the gunsmith bench bolts on

Same conventions as build_pistol.py (whose helpers this reuses): authored in
Godot's frame (x right, y up, -z forward, metres), materials named pistol_*
for pistol_import.gd to swap, and the grip at the smart pistol's position and
angle so Eco's glove (eco_fp_arm.glb) closes round every gun. Names the game
looks up: Muzzle, MagBase, Slide, Vents, HoloGlass, Frame, Barrel (the last
two for the gunsmith bench's part markers).

Attachments are authored in the frame of the point they mount to:
  att_muzzle_*  at the Muzzle, pointing down -z; a Tip empty marks the new muzzle
  att_mag_*     at the bottom of the magazine, in the grip's (tilted) frame
  att_grip_*    at the grip's centre, in the grip's frame
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_pistol as bp  # noqa: E402

OUT = Path(__file__).resolve().parent.parent.parent / "assets" / "models" / "sidearms"
G2B = bp.G2B


def export(name):
	OUT.mkdir(parents=True, exist_ok=True)
	path = str(OUT / f"{name}.glb")
	bpy.ops.export_scene.gltf(
		filepath=path, export_format="GLB", use_selection=False, export_apply=True,
		export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
	)
	tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().loop_triangles) for o in bpy.data.objects if o.type == "MESH")
	print("exported", path, "triangles", tris)


def pivot_group(name, at, objs):
	"""Parents `objs` under an empty at `at`, so the game can turn them about it."""
	pivot = bp.empty(name, at)
	mesh = bp.join(name + "Mesh", objs)
	mesh.parent = pivot
	mesh.matrix_parent_inverse = pivot.matrix_world.inverted()
	return pivot


def in_frame(objs, matrix):
	"""Moves objects authored at the origin into a Godot-frame transform."""
	for o in objs:
		o.data.transform(G2B @ matrix @ G2B.inverted())
	return objs


# --- hand cannon ----------------------------------------------------------------

def _xprism(C, name, x0, x1, sec, mat, bevel=0.0012):
	"""A cross-section (list of concept (y, z)) pushed along the concept's x
	(the barrel axis) from x0 to x1."""
	bm = bmesh.new()
	f = bm.faces.new([bm.verts.new((x0, y, z)) for y, z in sec])
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
	bmesh.ops.translate(bm, vec=Vector((x1 - x0, 0, 0)), verts=moved)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bp.obj_from_bm(name, bm, mat, C.m, bevel)


def _tri_sec(w, z0, zs, zt, wt):
	"""Desert Eagle section: flat sides up to zs, then sloped in to a top flat wt wide."""
	return [(-w / 2, z0), (w / 2, z0), (w / 2, zs), (wt / 2, zt), (-wt / 2, zt), (-w / 2, zs)]


def _inlay(C, name, pts, y, mat, r=0.00065):
	"""A thin raised line (engraving inlay) through concept (x, z) points on the flank at y."""
	o = bp.cable([C.p(x, y, z) for x, z in pts], mat, r, res=4, bevel_res=0)
	o.name = name
	return o


def _scroll(C, cx, cz, r, y, mat, turns=1.3, a0=0, flip=False):
	pts = []
	for i in range(15):
		t = i / 14
		a = math.radians(a0 + 360 * turns * t * (-1 if flip else 1))
		rr = r * (1 - 0.75 * t)
		pts.append((cx + rr * math.cos(a), cz + rr * math.sin(a)))
	return _inlay(C, "Scroll", pts, y, mat)


def _join(name, objs):
	"""Joins parts keeping each one's own bevel (bp.join keeps only the first's)."""
	for o in objs:
		if o.modifiers:
			bpy.ops.object.select_all(action="DESELECT")
			bpy.context.view_layer.objects.active = o
			for m in list(o.modifiers):
				bpy.ops.object.modifier_apply(modifier=m.name)
	return bp.join(name, objs)


def _grip_xf(p):
	return bp.xform(bp.GRIP_POS, bp.GRIP_ROT) @ Vector(p)


def rivet_cannon():
	"""Eco's Hand Cannon (id rivet_cannon; it used to be a heavy revolver):
	the "Swordfish" (concept: weapon-concepts designs/hand_cannon_v3.py, G).
	A big-bore gas-operated semi-auto in the Desert Eagle mould, polished
	chrome: a long fixed barrel with a triangular top and a sight rib, gold
	scroll engraving on its flats and a red ring round the crown; a slide
	riding on rails behind it with a ring hammer; a big squared trigger guard,
	a gold trigger, ebony grip panels with a gold medallion and one red jewel,
	and a fat mag base. The grip is the shared one (position and angle) so
	Eco's glove closes round it; the concept's trigger sits where her finger is."""
	bp.reset()
	# The concept's trigger lands on her trigger finger, its grip top on the shared grip line.
	C = bp.Concept(at=(-0.0144, 0.084), to=(-0.031, 0.056))
	cr, ebony, gold, dark = "pistol_chrome", "pistol_ebony", "pistol_gold", "pistol_dark"
	zb = 0.122  # concept height of the bore
	front = 0.296  # concept muzzle
	ztop = 0.1
	# --- frame: dust cover, squared guard, gold trigger, slide stop, grip
	frame = [C.sym("Frame", [(-0.05, ztop), (0.17, ztop), (0.174, ztop - 0.006), (0.17, ztop - 0.016), (-0.03, ztop - 0.016)],
			0.026, cr, bevel=0.0015)]
	gt, gb = ztop - 0.016, ztop - 0.016 - 0.038
	x0, x1, th = 0.012, 0.082, 0.0055
	guard = [(x0, gt), (x0 - 0.002, gb + 0.008), (x0 + 0.006, gb), (x1 - 0.004, gb), (x1 + 0.002, gb - 0.005),
			(x1 + 0.006, gb - 0.002), (x1 + 0.004, gb + 0.006), (x1, gt),
			(x1 - th, gt), (x1 - th, gb + th), (x0 + 0.007, gb + th), (x0 + th - 0.001, gb + 0.008), (x0 + th, gt)]
	frame.append(C.sym("Guard", guard, 0.016, cr, bevel=0.0007))
	frame.append(C.sym("Trigger", bp.trigger_pts(0.034, gt, curl=0.019), 0.007, gold, bevel=0.0006))
	frame.append(C.prof("SlideStop", [(0.03, 0.089), (0.062, 0.089), (0.064, 0.093), (0.03, 0.094)], -0.0146, -0.013, "pistol_black"))
	# grip (grip frame: (z, y), z back): straight front strap, a hump under the beavertail
	frame.append(bp.grip_prof("Grip", [(-0.027, 0.07), (-0.0262, -0.058), (0.0285, -0.058), (0.031, -0.01), (0.03, 0.03),
			(0.034, 0.058), (0.036, 0.075)], 0.034, cr, bevel=0.003, segments=3))
	# ebony panels: one slab through the grip, proud of both flanks
	frame.append(bp.grip_prof("Panels", [(-0.021, 0.052), (-0.021, -0.05), (0.024, -0.05), (0.0255, 0.0), (0.024, 0.044), (0.014, 0.054)],
			0.0364, ebony, bevel=0.0007))
	# gold medallion with a red jewel on each panel, a gold line along the panel's front
	for s in (-1, 1):
		frame += bp.in_grip([
			bp.cylinder("Medallion", 0.0082, 0.002, (s * 0.0182, -0.006, 0.006), gold, axis="x", segments=24, bevel=0.0004),
			bp.cylinder("Jewel", 0.0041, 0.0028, (s * 0.0186, -0.006, 0.006), "pistol_emitter", axis="x", segments=16),
		])
		frame.append(bp.cable([_grip_xf((s * 0.0183, 0.046, -0.0175)), _grip_xf((s * 0.0183, 0.0, -0.0185)),
				_grip_xf((s * 0.0183, -0.044, -0.0175))], gold, 0.0005, res=4, bevel_res=0))
	_join("Frame", frame)
	# --- the 7-round mag: its body in the grip and the fat base plate under it
	# (joined onto the foot, whose bevel the join keeps)
	mag = [bp.grip_prof("MagFoot", [(-0.029, -0.0575), (0.0335, -0.0575), (0.0345, -0.075), (-0.0275, -0.071)], 0.04, cr,
			bevel=0.002)]
	mag += bp.in_grip([bp.box("MagBody", (0.024, 0.06, 0.03), (0, -0.03, 0.0), dark)])
	_join("MagBase", mag)
	# --- slide: rails, triangular top, serrations, ring hammer, safety, rear sight
	slide = [_xprism(C, "SlideBody", -0.05, 0.098, _tri_sec(0.027, 0.1, 0.123, 0.139, 0.01), cr)]
	for i in range(8):
		x = -0.044 + 0.026 * (i + 0.5) / 8
		slide += C.sides("Serration", [(x - 0.0008, 0.103), (x + 0.0008, 0.103), (x - 0.0012, 0.121), (x - 0.0028, 0.121)], 0.0135, 0.0008, cr)
	for s in (-1, 1):
		slide.append(_inlay(C, "PinLine", [(-0.01, 0.112), (0.04, 0.112), (0.09, 0.112)], s * 0.0139, gold))
		y0 = s * 0.0135
		slide.append(C.prof("Safety", [(-0.042, 0.124), (-0.024, 0.124), (-0.02, 0.129), (-0.04, 0.129)], y0, y0 + s * 0.002, ebony))
	slide.append(C.box("RearSight", (-0.038, 0, 0.142), (0.01, 0.016, 0.007), cr, bevel=0.0008))
	slide.append(C.box("RearNotch", (-0.038, 0, 0.1462), (0.0104, 0.004, 0.0022), "pistol_black"))
	hx, hz = -0.052, 0.118
	slide.append(C.sym("Hammer", [(hx + 0.004, hz - 0.012), (hx + 0.004, hz + 0.006)] + bp.arc(hx - 0.006, hz + 0.004, 0.009, 60, 230, 6)
			+ [(hx - 0.008, hz - 0.012)], 0.008, cr, bevel=0.0007))
	slide.append(C.cyl("HammerRing", (hx - 0.006, -0.0046, hz + 0.004), (hx - 0.006, 0.0046, hz + 0.004), 0.0035, "pistol_black", segments=16))
	_join("Slide", slide)
	# --- barrel: fixed, triangular top, sight rib, crown with a red ring
	barrel = [_xprism(C, "BarrelBody", 0.096, front, _tri_sec(0.025, 0.093, 0.113, 0.137, 0.009), cr)]
	# the chamber hood inside the slide, showing when the slide kicks back
	barrel.append(_xprism(C, "Hood", 0.03, 0.1, _tri_sec(0.02, 0.102, 0.12, 0.132, 0.008), dark, bevel=0.0))
	barrel.append(C.sym("Rib", [(0.096, 0.137), (front, 0.137), (front, 0.1395), (0.096, 0.1395)], 0.006, cr, bevel=0.0004))
	barrel.append(C.sym("FrontSight", [(0.282, 0.139), (0.284, 0.146), (0.292, 0.146), (0.294, 0.139)], 0.004, cr, bevel=0.0004))
	barrel.append(C.box("SightDot", (0.2826, 0, 0.1438), (0.0012, 0.0026, 0.0026), "pistol_emitter"))
	bore = C.p(front, 0, zb)
	barrel.append(bp.cylinder("Bore", 0.0074, 0.0016, bore + Vector((0, 0, -0.0002)), "pistol_screen", axis="z", segments=24))
	barrel.append(bp.torus("CrownRing", 0.0089, 0.0014, bore + Vector((0, 0, -0.0006)), (0, 0, 0), "pistol_red", segments=24, ring=6))
	# gold scroll engraving and script lines on both flats
	for s in (-1, 1):
		y = s * 0.0127
		barrel.append(_scroll(C, 0.12, 0.103, 0.0075, y, gold, 1.3, 30))
		barrel.append(_inlay(C, "Script", [(0.13, 0.11), (0.17, 0.1065), (0.21, 0.108), (0.25, 0.105), (0.282, 0.107)], y, gold))
		barrel.append(_inlay(C, "Script", [(0.13, 0.098), (0.18, 0.0985), (0.24, 0.097)], y, gold))
		barrel.append(_scroll(C, 0.275, 0.1, 0.006, y, gold, 1.2, 200, flip=True))
	_join("Barrel", barrel)
	bp.empty("Muzzle", C.p(front + 0.002, 0, zb))
	export("rivet_cannon")


# --- machine pistol -------------------------------------------------------------

def machine_pistol():
	"""A colony machine pistol, full auto, taken off a grunt who won't need it:
	the "Brick" (concept: weapon-concepts designs/auto_handgun.py, brick). A
	boxy off-white polymer receiver with a rail on top, the 24-round mag in the
	grip with a red base, an integral front grip with a hand stop, a T-handle
	charging handle in a slot on top and a threaded barrel stub. Colony red
	stripe down both flanks; Eco has stuck a heart on the left side, out of
	spite. The grip is the shared one (position and angle), so it rakes back
	where the concept's stands straight."""
	bp.reset()
	# The concept's trigger lines up with the smart pistol's, its grip top with the shared grip.
	C = bp.Concept(at=(-0.021, 0.091), to=(-0.031, 0.056))
	bore = 0.116
	shell, top = "pistol_polymer", "pistol_dark"
	upper = [C.sym("Receiver", [(-0.074, 0.09), (0.04, 0.09), (0.07, 0.088), (0.128, 0.094), (0.134, 0.104), (0.134, 0.128),
			(0.126, 0.134), (-0.068, 0.134), (-0.076, 0.126)], 0.03, shell, bevel=0.003)]
	# top cover, rail and the charging slot
	upper.append(C.sym("TopCover", [(-0.07, 0.1335), (0.124, 0.1335), (0.12, 0.14), (-0.066, 0.14)], 0.024, top, bevel=0.0008))
	upper += [C.box("Rail", (-0.058 + i * 0.0125, 0, 0.142), (0.007, 0.022, 0.004), top, bevel=0.0005) for i in range(14)]
	upper.append(C.box("ChargeSlot", (-0.035, 0, 0.1445), (0.064, 0.005, 0.002), "pistol_screen"))
	# flip sights
	upper.append(C.sym("RearSight", [(-0.05, 0.1455), (-0.048, 0.155), (-0.038, 0.155), (-0.036, 0.1455)], 0.016, top, bevel=0.0006))
	upper.append(C.sym("FrontSight", [(0.104, 0.1455), (0.106, 0.156), (0.112, 0.156), (0.114, 0.1455)], 0.005, top, bevel=0.0005))
	# right side: ejection port with the barrel hood showing
	upper.append(C.prof("Port", [(0.012, 0.108), (0.056, 0.108), (0.056, 0.128), (0.012, 0.128)], -0.0156, -0.0148, "pistol_screen"))
	upper.append(C.prof("BarrelHood", [(0.036, 0.111), (0.054, 0.111), (0.054, 0.125), (0.036, 0.125)], -0.0162, -0.0154, top))
	# colony stripe down both flanks; side panels with the cooling slots
	upper += C.sides("Stripe", [(-0.07, 0.13), (0.13, 0.13), (0.13, 0.1315), (-0.07, 0.1315)], 0.015, 0.0006, "pistol_red")
	upper += C.sides("SidePanel", [(0.066, 0.1), (0.124, 0.1), (0.124, 0.124), (0.066, 0.124)], 0.015, 0.0006, shell)
	vents = []
	for i in range(4):
		x = 0.074 + i * 0.012
		vents += C.sides("Slot", [(x, 0.105), (x + 0.006, 0.105), (x + 0.006, 0.119), (x, 0.119)], 0.0154, 0.0006, "pistol_vent")
	# barrel stub with a hex thread protector
	upper.append(C.cyl("Barrel", (0.132, 0, bore), (0.15, 0, bore), 0.0085, top, segments=16))
	upper.append(C.cyl("ThreadCap", (0.15, 0, bore), (0.166, 0, bore), 0.0095, "pistol_black", segments=6))
	upper.append(C.cyl("Bore", (0.162, 0, bore), (0.1664, 0, bore), 0.005, "pistol_screen", segments=12))
	# rear plate with a sling loop
	upper.append(C.sym("RearPlate", [(-0.08, 0.094), (-0.0735, 0.094), (-0.0735, 0.13), (-0.08, 0.13)], 0.028, top, bevel=0.0008))
	upper.append(bp.torus("SlingLoop", 0.0072, 0.0019, C.p(-0.084, 0, 0.1), (0, 90, 0), top, segments=12, ring=5))
	# guard, trigger and the red mag release
	upper.append(C.sym("Guard", bp.guard_pts(0.004, 0.068, 0.0915, 0.0305, 0.005), 0.016, shell, bevel=0.0008))
	upper.append(C.sym("Trigger", bp.trigger_pts(0.022, 0.09), 0.006, top, bevel=0.0006))
	upper.append(C.box("MagRelease", (0.004, 0.0165, 0.07), (0.006, 0.002, 0.008), "pistol_red", bevel=0.0006))
	# integral front grip with a hand stop at the bottom
	upper.append(C.sym("FrontGrip", [(0.074, 0.092), (0.104, 0.092), (0.1, 0.03), (0.108, 0.022), (0.106, 0.014), (0.07, 0.014), (0.072, 0.03)],
			0.028, shell, bevel=0.003))
	for i in range(4):
		x = 0.076 + 0.022 * (i + 0.5) / 4
		upper += C.sides("Groove", [(x - 0.0015, 0.034), (x + 0.0015, 0.034), (x + 0.0015 - 0.0026, 0.084), (x - 0.0015 - 0.0026, 0.084)], 0.014, 0.0007, top)
	upper.append(C.sym("HandStop", [(0.068, 0.006), (0.11, 0.006), (0.11, 0.0145), (0.068, 0.0145)], 0.03, top, bevel=0.0015))
	# the pistol grip, on the shared grip line, with rubber panels
	upper.append(bp.grip_prof("Grip", [(-0.025, 0.066), (-0.0235, -0.059), (0.0245, -0.059), (0.0265, 0.02), (0.029, 0.066)], 0.038, shell, bevel=0.003, segments=3))
	upper += bp.in_grip([bp.box("GripPanel", (0.0014, 0.084, 0.036), (s * 0.0191, -0.008, 0.001), top, bevel=0.0005) for s in (-1, 1)])
	# Her heart sticker on the left, two lobes and a point.
	heart_at = C.p(-0.03, 0, 0.11)
	heart = [
		bp.box("HeartL", (0.0012, 0.008, 0.008), heart_at + Vector((-0.0187, 0.0025, -0.004)), "pistol_stripe", rot=(45, 0, 0)),
		bp.box("HeartR", (0.0012, 0.008, 0.008), heart_at + Vector((-0.0187, 0.0025, 0.004)), "pistol_stripe", rot=(45, 0, 0)),
		bp.box("HeartTip", (0.0012, 0.0098, 0.0098), heart_at + Vector((-0.0187, -0.0015, 0.0)), "pistol_stripe", rot=(45, 0, 0)),
	]
	bp.join("Upper", upper + heart)
	bp.join("Vents", vents)
	# The 24-round mag out of the bottom of the grip, red base plate.
	mag = [bp.box("Mag", (0.026, 0.05, 0.036), (0, -0.074, -0.001), "pistol_dark", bevel=0.0012)]
	mag.append(bp.box("MagFoot", (0.031, 0.011, 0.046), (0, -0.1045, 0.0), "pistol_red", bevel=0.0015))
	bp.join("MagBase", bp.in_grip(mag))
	# T-handle charging handle: the bit that cycles back on each shot.
	handle = [C.cyl("Stem", (-0.06, 0, 0.139), (-0.06, 0, 0.152), 0.0035, top, segments=10),
			C.cyl("TBar", (-0.06, -0.016, 0.152), (-0.06, 0.016, 0.152), 0.0045, "pistol_red", segments=12)]
	bp.join("Slide", handle)
	bp.empty("Muzzle", C.p(0.168, 0, bore))
	export("machine_pistol")


# --- attachments ----------------------------------------------------------------

def att_muzzle_long():
	"""Barrel extension: more reach, more weight up front."""
	bp.reset()
	tube = bp.prism("Tube", 0.0135, 0.075, (0, 0, -0.0375), "pistol_dark", bevel=0.001)
	band = bp.prism("Band", 0.0142, 0.004, (0, 0, -0.012), "pistol_stripe")
	cap = bp.prism("Cap", 0.0148, 0.008, (0, 0, -0.072), "pistol_shell", bevel=0.0012)
	bore = bp.cylinder("Bore", 0.0045, 0.01, (0, 0, -0.077), "pistol_screen", axis="z")
	bp.join("MuzzleLong", [tube, band, cap, bore])
	bp.empty("Tip", (0, 0, -0.079))
	export("att_muzzle_long")


def att_muzzle_comp():
	"""Compensator: ports on top push the muzzle down against the kick."""
	bp.reset()
	body = bp.box("Comp", (0.03, 0.028, 0.04), (0, 0.002, -0.02), "pistol_shell", bevel=0.003)
	slots = [bp.box("Port", (0.018, 0.0016, 0.005), (0, 0.016, -0.008 - i * 0.011), "pistol_vent") for i in range(3)]
	side = [bp.box("SidePort", (0.0016, 0.012, 0.006), (s * 0.0152, 0.002, -0.02), "pistol_vent") for s in (-1, 1)]
	stripe = bp.box("Stripe", (0.0305, 0.004, 0.006), (0, -0.008, -0.036), "pistol_stripe")
	bp.join("MuzzleComp", [body, stripe])
	bp.join("Vents", slots + side)
	bp.empty("Tip", (0, 0, -0.042))
	export("att_muzzle_comp")


def att_mag_ext():
	"""Extended magazine: a sleeve and a fat base plate under the grip."""
	bp.reset()
	sleeve = bp.box("Sleeve", (0.035, 0.034, 0.05), (0, -0.017, 0), "pistol_shell", bevel=0.002)
	stripe = bp.box("Stripe", (0.0355, 0.004, 0.0505), (0, -0.012, 0), "pistol_stripe")
	plate = bp.box("Plate", (0.04, 0.008, 0.056), (0, -0.036, 0), "pistol_dark", bevel=0.002)
	bp.join("MagExt", [sleeve, stripe, plate])
	export("att_mag_ext")


def att_mag_speed():
	"""Speed base: a flared plate and a pull loop, for yanking the mag fast."""
	bp.reset()
	bm = bp.box_bm((0.042, 0.01, 0.06), (0, -0.005, 0))
	for v in bm.verts:
		if v.co.y < -0.005:
			v.co.x *= 1.15
			v.co.z *= 1.12
	plate = bp.obj_from_bm("Flare", bm, "pistol_dark", bevel=0.002)
	loop = [
		bp.box("LoopL", (0.003, 0.016, 0.003), (-0.006, -0.018, 0.026), "pistol_tape"),
		bp.box("LoopR", (0.003, 0.016, 0.003), (0.006, -0.018, 0.026), "pistol_tape"),
		bp.box("LoopB", (0.015, 0.003, 0.003), (0, -0.026, 0.026), "pistol_tape"),
	]
	bp.join("MagSpeed", [plate] + loop)
	export("att_mag_speed")


def att_grip_wrap():
	"""Paracord wrap: soaks up the kick, a little bulky."""
	bp.reset()
	turns = []
	for i in range(8):
		y = -0.04 + i * 0.0105
		mat = "pistol_tape" if i % 3 else "pistol_stripe"
		turns.append(bp.box("Turn", (0.037, 0.0062, 0.053), (0, y, 0), mat, rot=(0, 0, (i % 2) * 4 - 2), bevel=0.0012))
	bp.join("GripWrap", turns)
	export("att_grip_wrap")


def att_grip_skeleton():
	"""Skeleton panels: drilled-out side plates and a beavertail. Light in the air,
	snappy in the hand."""
	bp.reset()
	plates = []
	holes = []
	for s in (-1, 1):
		plates.append(bp.box("Plate", (0.0024, 0.09, 0.044), (s * 0.0185, 0.0, 0.0), "pistol_shell", bevel=0.0008))
		for k in range(3):
			holes.append(bp.box("Hole", (0.0028, 0.016, 0.01), (s * 0.0186, -0.028 + k * 0.026, 0.004), "pistol_dark", bevel=0.001))
	tail = bp.box("Beavertail", (0.03, 0.008, 0.024), (0, 0.05, 0.024), "pistol_shell", rot=(30, 0, 0), bevel=0.002)
	bp.join("GripSkeleton", plates + [tail])
	bp.join("Holes", holes)
	export("att_grip_skeleton")



BUILDS = [rivet_cannon, machine_pistol, att_muzzle_long, att_muzzle_comp, att_mag_ext, att_mag_speed, att_grip_wrap, att_grip_skeleton]
# Names after "--" rebuild only those, e.g. `-- machine_pistol`; none builds everything.
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for build in BUILDS:
	if not ONLY or build.__name__ in ONLY:
		build()
