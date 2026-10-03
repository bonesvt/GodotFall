"""Builds Eco's other sidearms and the pistol attachments in Blender.

    blender --background --python tools/pistol/build_sidearms.py

Writes assets/models/sidearms/*.glb:
  rivet_cannon.glb     Eco's heavy revolver, built round a titan's rivet driver
  machine_pistol.glb   a militia machine pistol she took off a grunt
  att_*.glb            attachments the gunsmith bench bolts on

Same conventions as build_pistol.py (whose helpers this reuses): authored in
Godot's frame (x right, y up, -z forward, metres), materials named pistol_*
for pistol_import.gd to swap, and the grip at the smart pistol's position and
angle so Eco's glove (eco_fp_arm.glb) closes round every gun. Names the game
looks up: Muzzle, MagBase, Slide, Vents, HoloGlass, Drum (the heavy revolver's
cylinder pivot), Hammer.

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


# --- heavy revolver -------------------------------------------------------------

def rivet_cannon():
	"""Eco's heavy revolver (id rivet_cannon). The cylinder is a six-round feed
	drum off a titan's rivet driver, fat enough to bulge out past the frame,
	the barrel a length of its guide tube on a full underlug, with heat coils
	wound round it. A big spur hammer she thumbs back between shots. Heavy,
	slow, loud, and it hits like a door."""
	bp.reset()
	axis_y = 0.016
	# Frame: a bottom strap under the cylinder, a top strap over it, a recoil
	# shield behind it (rising into the grip) and a short front post.
	bottom = bp.box("BottomStrap", (0.03, 0.02, 0.1), (0, -0.026, -0.006), "pistol_dark", bevel=0.003)
	top = bp.box("TopStrap", (0.03, 0.012, 0.11), (0, axis_y + 0.036, -0.01), "pistol_dark", bevel=0.003)
	shield = bp.box("Shield", (0.034, 0.08, 0.026), (0, 0.004, 0.034), "pistol_dark", bevel=0.004)
	post = bp.box("FrontPost", (0.03, 0.07, 0.014), (0, 0.004, -0.048), "pistol_dark", bevel=0.003)
	plate = bp.box("SidePlate", (0.036, 0.04, 0.022), (0, -0.002, 0.034), "pistol_blue", bevel=0.0015)
	stripe = bp.box("SideStripe", (0.0365, 0.004, 0.02), (0, 0.012, 0.034), "pistol_stripe")
	guard = bp.guard_and_trigger()
	grip_parts, flush = bp.grip()
	bpy.data.objects.remove(flush)  # a revolver has no magazine
	tape = bp.grip_tape()
	bp.join("Frame", [bottom, top, shield, post, plate, stripe] + guard + grip_parts)
	bp.join("Tape", tape)
	# The cylinder: six flutes, six chamber mouths, an orange ring at the back.
	drum_at = Vector((0, axis_y, -0.008))
	body = bp.cylinder("DrumBody", 0.033, 0.058, drum_at, "pistol_shell", axis="z", segments=24, bevel=0.003)
	parts = [body]
	for k in range(6):
		a = 2 * math.pi * k / 6 + math.pi / 6
		pos = drum_at + Vector((math.cos(a) * 0.032, math.sin(a) * 0.032, 0))
		parts.append(bp.box("Flute", (0.01, 0.01, 0.046), pos, "pistol_dark", rot=(0, 0, math.degrees(a))))
		mouth = drum_at + Vector((math.cos(a - math.pi / 6) * 0.019, math.sin(a - math.pi / 6) * 0.019, -0.03))
		parts.append(bp.cylinder("Chamber", 0.0075, 0.004, mouth, "pistol_screen", axis="z", segments=10))
	parts.append(bp.cylinder("DrumRing", 0.0335, 0.005, drum_at + Vector((0, 0, 0.025)), "pistol_stripe", axis="z", segments=24))
	pivot_group("Drum", drum_at, parts)
	# Barrel: octagonal guide tube on a full underlug with the ejector rod,
	# a vent rib on top and a heavy crown.
	length = 0.17
	back = -0.055
	z0 = back - length / 2
	front = back - length
	barrel = bp.prism("Barrel", 0.014, length, (0, axis_y, z0), "pistol_shell", bevel=0.0012)
	rib = bp.box("Rib", (0.01, 0.01, length), (0, axis_y + 0.016, z0), "pistol_dark", bevel=0.0015)
	lug = bp.box("Underlug", (0.024, 0.026, length - 0.01), (0, axis_y - 0.026, z0 + 0.005), "pistol_blue", bevel=0.003)
	lug_stripe = bp.box("LugStripe", (0.0245, 0.004, length - 0.01), (0, axis_y - 0.02, z0 + 0.005), "pistol_stripe")
	rod = bp.cylinder("EjectorRod", 0.0045, 0.06, (0, axis_y - 0.014, back - 0.03), "pistol_shell", axis="z", segments=8)
	crown = bp.prism("Crown", 0.017, 0.014, (0, axis_y, front - 0.003), "pistol_dark", bevel=0.0015)
	bore = bp.cylinder("Bore", 0.0065, 0.016, (0, axis_y, front - 0.005), "pistol_screen", axis="z")
	sight = bp.box("FrontSight", (0.004, 0.016, 0.016), (0, axis_y + 0.026, front + 0.012), "pistol_stripe", bevel=0.001)
	rear = bp.box("RearSight", (0.018, 0.01, 0.008), (0, axis_y + 0.045, 0.03), "pistol_dark", bevel=0.001)
	bp.join("Barrel", [barrel, rib, lug, lug_stripe, rod, crown, bore, sight, rear])
	# Heat coils wound round the barrel: they glow as she fans the hammer.
	coils = []
	for i in range(4):
		z = back - 0.03 - i * 0.022
		coils.append(bp.prism("Coil", 0.0158, 0.006, (0, axis_y, z), "pistol_vent"))
	bp.join("Vents", coils)
	# A big spur hammer at the back of the top strap, pivoting at its base.
	hammer_at = Vector((0, axis_y + 0.03, 0.05))
	body = bp.box("HammerBody", (0.012, 0.03, 0.014), hammer_at + Vector((0, 0.012, 0.0)), "pistol_dark", rot=(-20, 0, 0), bevel=0.002)
	spur = bp.box("HammerSpur", (0.018, 0.008, 0.022), hammer_at + Vector((0, 0.026, 0.012)), "pistol_shell", rot=(-35, 0, 0), bevel=0.002)
	pivot_group("Hammer", hammer_at, [body, spur])
	bp.empty("Muzzle", (0, axis_y, front - 0.012))
	export("rivet_cannon")


# --- machine pistol -------------------------------------------------------------

def machine_pistol():
	"""A militia machine pistol, full auto, taken off a grunt who won't need it.
	Boxy and cheap: a stamped upper, a slotted snout, a red-dot on the rail.
	Eco has taped the mag and stuck a heart on the side, out of spite."""
	bp.reset()
	# Upper: a stamped box with a chamfered nose.
	bm = bp.box_bm((0.036, 0.04, 0.19), (0, 0.018, -0.03))
	for v in bm.verts:
		if v.co.z < -0.1 and v.co.y > 0.03:
			v.co.z += 0.014
	upper = bp.obj_from_bm("Upper", bm, "pistol_shell", bevel=0.002, segments=1)
	port = bp.box("Port", (0.0365, 0.012, 0.035), (0.001, 0.026, 0.01), "pistol_dark")
	band = bp.box("MilitiaBand", (0.0365, 0.008, 0.12), (0, 0.004, -0.04), "pistol_blue")
	rail = [bp.box("Rail%d" % i, (0.022, 0.004, 0.007), (0, 0.04, -0.07 + i * 0.012), "pistol_dark") for i in range(8)]
	# Red-dot: a hooded housing and a glass pane.
	dot_at = Vector((0, 0.052, 0.015))
	hood = bp.box("DotHood", (0.026, 0.02, 0.03), dot_at, "pistol_dark", bevel=0.002)
	glass = bp.box("HoloGlass", (0.018, 0.013, 0.0015), dot_at + Vector((0, 0.001, -0.004)), "pistol_holo")
	emitter = bp.box("Emitter", (0.004, 0.003, 0.004), dot_at + Vector((0, -0.007, 0.012)), "pistol_emitter")
	# Lower frame, guard and grip like every other gun of hers.
	bm = bp.box_bm((0.034, 0.024, 0.15), (0, -0.014, -0.005))
	lower = bp.obj_from_bm("Lower", bm, "pistol_dark", bevel=0.002)
	guard = bp.guard_and_trigger()
	grip_parts, _flush = bp.grip()
	bpy.data.objects.remove(_flush)
	# A stick mag that hangs out of the grip, taped up.
	mag = bp.box("MagBase", (0.03, 0.07, 0.046), (0, -0.075, 0.002), "pistol_dark", bevel=0.002)
	mag_tape = bp.box("MagTape", (0.0315, 0.012, 0.0475), (0, -0.09, 0.002), "pistol_tape", rot=(4, 0, 0), bevel=0.001)
	in_frame([mag, mag_tape], bp.xform(bp.GRIP_POS, bp.GRIP_ROT))
	bp.join("MagBase", [mag, mag_tape])
	# Foregrip knob under the nose, and the slotted snout.
	knob = bp.cylinder("Knob", 0.009, 0.045, (0, -0.045, -0.085), "pistol_dark", axis="y", segments=10, bevel=0.002)
	snout = bp.prism("Snout", 0.0135, 0.05, (0, 0.012, -0.145), "pistol_dark", bevel=0.001)
	bore = bp.cylinder("Bore", 0.0045, 0.012, (0, 0.012, -0.17), "pistol_screen", axis="z")
	slots = []
	for side in (-1, 1):
		for row in range(3):
			slots.append(bp.box("Slot", (0.002, 0.0045, 0.009), (side * 0.0125, 0.014, -0.135 - row * 0.012), "pistol_vent"))
	bp.join("Vents", slots)
	# Her heart sticker, two lobes and a point.
	heart = [
		bp.box("HeartL", (0.0012, 0.009, 0.009), (0.0186, 0.03, -0.055), "pistol_stripe", rot=(45, 0, 0)),
		bp.box("HeartR", (0.0012, 0.009, 0.009), (0.0186, 0.03, -0.064), "pistol_stripe", rot=(45, 0, 0)),
		bp.box("HeartTip", (0.0012, 0.011, 0.011), (0.0186, 0.025, -0.0595), "pistol_stripe", rot=(45, 0, 0)),
	]
	bp.join("Upper", [upper, port, band, hood, emitter, snout, bore, knob, lower] + rail + guard + grip_parts + heart)
	bp.join("HoloGlass", [glass])
	# Charging handle: the bit that cycles back on each shot.
	bp.join("Slide", [bp.box("Charger", (0.016, 0.01, 0.026), (0, 0.042, 0.06), "pistol_shell", bevel=0.002)])
	bp.empty("Muzzle", (0, 0.012, -0.178))
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


rivet_cannon()
machine_pistol()
att_muzzle_long()
att_muzzle_comp()
att_mag_ext()
att_mag_speed()
att_grip_wrap()
att_grip_skeleton()
