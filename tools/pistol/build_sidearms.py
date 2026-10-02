"""Builds Eco's other sidearms and the pistol attachments in Blender.

    blender --background --python tools/pistol/build_sidearms.py

Writes assets/models/sidearms/*.glb:
  rivet_cannon.glb     a hand cannon Eco built round a titan's rivet driver
  machine_pistol.glb   a militia machine pistol she took off a grunt
  att_*.glb            attachments the gunsmith bench bolts on

Same conventions as build_pistol.py (whose helpers this reuses): authored in
Godot's frame (x right, y up, -z forward, metres), materials named pistol_*
for pistol_import.gd to swap, and the grip at the smart pistol's position and
angle so Eco's glove (eco_fp_arm.glb) closes round every gun. Names the game
looks up: Muzzle, MagBase, Slide, Vents, HoloGlass, Drum (the rivet cannon's
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


# --- rivet cannon -------------------------------------------------------------

def rivet_cannon():
	"""A five-shot hand cannon. The cylinder is a feed drum off a titan's rivet
	driver, the barrel a length of its guide tube with heat coils wound round
	it. Heavy, slow, loud, and it hits like a door."""
	bp.reset()
	axis_y = 0.014
	# Frame: a chunky block over the grip, with a top strap over the drum.
	bm = bp.box_bm((0.042, 0.054, 0.11), (0, -0.004, 0.03))
	for v in bm.verts:
		if v.co.z > 0.06 and v.co.y > 0.0:
			v.co.z -= 0.012  # sloped back
	frame = bp.obj_from_bm("Frame", bm, "pistol_dark", bevel=0.004, segments=2)
	strap = bp.box("TopStrap", (0.03, 0.01, 0.075), (0, axis_y + 0.03, -0.012), "pistol_dark", bevel=0.002)
	plate = bp.box("SidePlate", (0.044, 0.022, 0.06), (0, 0.004, 0.04), "pistol_blue", bevel=0.0015)
	stripe = bp.box("SideStripe", (0.0445, 0.003, 0.06), (0, 0.013, 0.04), "pistol_stripe")
	guard = bp.guard_and_trigger()
	grip_parts, mag = bp.grip()
	tape = bp.grip_tape()
	bp.join("Frame", [frame, strap, plate, stripe] + guard + grip_parts)
	bp.join("Tape", tape)
	# The drum: five flutes, an orange ring at the back.
	drum_at = Vector((0, axis_y, -0.008))
	body = bp.cylinder("DrumBody", 0.026, 0.052, drum_at, "pistol_shell", axis="z", segments=20, bevel=0.002)
	flutes = []
	for k in range(5):
		a = 2 * math.pi * k / 5
		pos = drum_at + Vector((math.cos(a) * 0.024, math.sin(a) * 0.024, 0))
		flutes.append(bp.box("Flute", (0.008, 0.008, 0.044), pos, "pistol_dark", rot=(0, 0, math.degrees(a))))
	ring = bp.cylinder("DrumRing", 0.0265, 0.004, drum_at + Vector((0, 0, 0.022)), "pistol_stripe", axis="z", segments=20)
	pivot_group("Drum", drum_at, [body, ring] + flutes)
	# Barrel: octagonal guide tube, a coil housing under it, a heavy crown.
	length = 0.15
	z0 = -0.034 - length / 2
	front = -0.034 - length
	barrel = bp.prism("Barrel", 0.0165, length, (0, axis_y, z0), "pistol_shell", bevel=0.0012)
	rib = bp.box("Rib", (0.012, 0.012, length), (0, axis_y + 0.019, z0), "pistol_dark", bevel=0.0015)
	lug = bp.box("Lug", (0.03, 0.022, 0.1), (0, axis_y - 0.026, -0.1), "pistol_blue", bevel=0.003)
	lug_stripe = bp.box("LugStripe", (0.0305, 0.003, 0.1), (0, axis_y - 0.02, -0.1), "pistol_stripe")
	crown = bp.prism("Crown", 0.019, 0.012, (0, axis_y, front - 0.002), "pistol_dark", bevel=0.0015)
	bore = bp.cylinder("Bore", 0.006, 0.014, (0, axis_y, front - 0.004), "pistol_screen", axis="z")
	sight = bp.box("FrontSight", (0.004, 0.012, 0.012), (0, axis_y + 0.03, front + 0.01), "pistol_stripe", bevel=0.001)
	rear = bp.box("RearSight", (0.016, 0.008, 0.006), (0, axis_y + 0.038, 0.016), "pistol_dark", bevel=0.001)
	bp.join("Barrel", [barrel, rib, lug, lug_stripe, crown, bore, sight, rear])
	# Heat coils wound round the barrel: they glow as she fans the trigger.
	coils = []
	for i in range(5):
		z = -0.06 - i * 0.017
		coils.append(bp.prism("Coil", 0.0178, 0.005, (0, axis_y, z), "pistol_vent"))
	bp.join("Vents", coils)
	# Hammer at the back of the strap, pivoting at its base.
	hammer_at = Vector((0, axis_y + 0.026, 0.05))
	spur = bp.box("HammerSpur", (0.01, 0.026, 0.01), hammer_at + Vector((0, 0.012, 0.004)), "pistol_shell", rot=(-25, 0, 0), bevel=0.002)
	pivot_group("Hammer", hammer_at, [spur])
	bp.empty("Muzzle", (0, axis_y, front - 0.01))
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
