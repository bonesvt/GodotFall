"""Builds the titans and titan weapons in Blender and exports them for Godot.

    blender --background --python tools/titans/build_titans.py -- assets/models/titans [only]

The look is the Jak II / Jak 3 / Jak X garage: chunky rounded hulls in glossy
paint with bold colour blocks and racing stripes, worn and chipped, a roll
cage over the cockpit pod, exposed engines, pistons, gears and hoses, tyre
knees, rivets and bolted plates. Each chassis is a livery and a few parts:

  atlas    sky blue, orange stripes: the all-rounder (twin headlights)
  ogre     mustard yellow and army green, bull bar, armour slabs, quad stacks
  stryder  white and red, raked nose, tail fins and a jet turbine
  scrap    rusty olive tube buggy: open tub, seat, mismatched panels
  enemy    candy crimson and cream, front blades, red eyes
  wreck    Eco's dad's Atlas, blue with an orange stripe, smashed (for the hub)

Node names are the contract with the game and must not change: LegL/LegR and
ArmL/ArmR pivots (legs swing, the hull hides in the cockpit except Arm*),
WeaponMount under ArmR, and the core light named Core (its glow tracks the
core charge). Pivots sit where tools/bake_models.gd put them, so the cockpit
view and collision line up with the old models. Weapons keep their muzzle
tips where scripts/run/titan_gun.gd expects them.

Materials are placeholders: assets/models/titans/titan_import.gd turns each
into a titan_paint ShaderMaterial, choosing gloss/wear from the name prefix
(paint_, stripe_, trim_, metal, chrome, dark, rubber, rust, glass, glow...).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import Model, band, cyl, dent, gear, jitter, merge, rbox, rivets, row, sphere, studs, tire, tube  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "assets/models/titans"
ONLY = args[1:]

SHARED = {
	"metal": (0.5, 0.5, 0.52),
	"chrome": (0.5, 0.52, 0.56),
	"dark": (0.13, 0.13, 0.15),
	"rubber": (0.07, 0.07, 0.075),
	"rust": (0.42, 0.24, 0.13),
	"brass": (0.78, 0.58, 0.28),
	"glass": (0.04, 0.07, 0.09),
	"seat": (0.36, 0.2, 0.12),
	"hose": (0.55, 0.12, 0.08),
	"soot": (0.05, 0.045, 0.04),
	"glow_core": ((0.4, 0.85, 1.0), (0.4, 0.85, 1.0)),
	"glow_lamp": ((1.0, 0.9, 0.65), (1.0, 0.9, 0.65)),
	"glow_red": ((1.0, 0.18, 0.1), (1.0, 0.18, 0.1)),
	"glow_dead": (0.08, 0.1, 0.11),
}

# Chassis: torso w/d/h, leg thickness, shoulder scale, hip height (same as the
# old primitive titans) plus the livery and parts.
TITANS = {
	"atlas": {"w": 2.6, "d": 1.8, "h": 2.0, "leg": 0.8, "sh": 1.0, "hip": 3.0,
		"paint": (0.16, 0.48, 0.86), "stripe": (1.0, 0.38, 0.02), "trim": (0.92, 0.87, 0.74),
		"cage": "trim", "lamps": "twin"},
	"ogre": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "sh": 1.3, "hip": 2.9,
		"paint": (1.0, 0.66, 0.02), "stripe": (0.1, 0.22, 0.12), "trim": (0.16, 0.3, 0.16),
		"cage": "dark", "lamps": "bar", "bullbar": True, "slabs": True, "stacks": 4},
	"stryder": {"w": 2.0, "d": 1.4, "h": 1.6, "leg": 0.55, "sh": 0.8, "hip": 3.4,
		"paint": (0.92, 0.92, 0.9), "stripe": (0.86, 0.1, 0.08), "trim": (0.3, 0.32, 0.36),
		"cage": "chrome", "lamps": "slit", "fins": True, "jet": True, "nose": 0.3},
	"scrap": {"w": 2.5, "d": 1.8, "h": 1.9, "leg": 0.75, "sh": 1.0, "hip": 3.0,
		"paint": (0.3, 0.4, 0.16), "stripe": (1.0, 0.4, 0.05), "trim": (0.6, 0.55, 0.45),
		"cage": "paint", "lamps": "odd", "scrap": True, "stacks": 2},
	"enemy": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "sh": 1.3, "hip": 2.9,
		"paint": (0.66, 0.02, 0.04), "stripe": (0.93, 0.86, 0.68), "trim": (0.18, 0.18, 0.2),
		"cage": "dark", "lamps": "red", "blades": True, "bullbar": True, "stacks": 2},
	"wreck": {"w": 2.6, "d": 1.8, "h": 2.0, "leg": 0.8, "sh": 1.0, "hip": 3.0,
		"paint": (0.1, 0.32, 0.7), "stripe": (1.0, 0.38, 0.04), "trim": (0.85, 0.82, 0.72),
		"cage": "trim", "lamps": "twin", "wreck": True},
}


def livery_materials(id, p):
	pre = "wreck_" if p.get("wreck") else ""
	return {
		"paint": pre + "paint_" + id, "stripe": pre + "stripe_" + id, "trim": pre + "trim_" + id,
	}


# --- chassis parts ---------------------------------------------------------------

def leg(m, P, L, side, pivot):
	lw, hip = P["leg"], P["hip"]
	g = "LegL" if side < 0 else "LegR"
	o = kit.Vector(pivot)

	def at(x, y, z):
		return (o.x + x, o.y + y, o.z + z)

	paint = [L["paint"], L["stripe"]]
	# Hip joint and thigh shell with a stripe down its front.
	m.add(g, cyl(lw * 0.42, lw + 0.12, at(0, 0, 0), "x", 16, bevel=0.06), "dark")
	m.add(g, cyl(lw * 0.24, lw + 0.26, at(0, 0, 0), "x", 12, bevel=0.03), "chrome")
	thigh = rbox((lw * 1.05, hip * 0.42, lw * 1.15), (0, 0, 0), r=lw * 0.28, seg=3,
		shape=lambda v, h: v.__setitem__(0, v.x * (0.86 if v.y < 0 else 1.0)))
	band(thigh, 0, -lw * 0.13, lw * 0.13, 1, lambda c, n: n.z < -0.2 or n.y > 0.5)
	m.add(g, thigh, paint, kit.xform(at(0, -hip * 0.25, -0.02)))
	m.add(g, studs(thigh, row(at(-lw * 0.36, -hip * 0.1, 0), at(-lw * 0.36, -hip * 0.4, 0), 4) +
		row(at(lw * 0.36, -hip * 0.1, 0), at(lw * 0.36, -hip * 0.4, 0), 4), (0, 0, 1)), "metal")
	# Thigh piston behind: dark cylinder, chrome rod.
	m.add(g, tube([at(0, -0.15, lw * 0.6), at(0, -hip * 0.32, lw * 0.66)], 0.13, 10, smooth_path=False), "dark")
	m.add(g, tube([at(0, -hip * 0.3, lw * 0.66), at(0, -hip * 0.5, lw * 0.5)], 0.07, 8, smooth_path=False), "chrome")
	# Knee: a treaded tyre with a chrome hub, like the buggies' wheels.
	ky = -hip * 0.5
	m.add(g, tire(lw * 0.52, lw * 0.62, at(0, ky, 0), "x", 18, tread=lw * 0.05), "rubber")
	for s in (-1, 1):
		m.add(g, cyl(lw * 0.3, 0.08, at(s * lw * 0.33, ky, 0), "x", 14, bevel=0.025), "chrome")
		m.add(g, rivets([at(s * lw * 0.38, ky + math.sin(a) * lw * 0.18, math.cos(a) * lw * 0.18) for a in [i * math.tau / 5 for i in range(5)]], 0.03, (s, 0, 0)), "dark")
	m.add(g, rbox((lw * 0.8, lw * 0.62, 0.22), (0, 0, 0), r=0.09, seg=2), L["trim"], kit.xform(at(0, ky + 0.05, -lw * 0.6), (-12, 0, 0)))
	# Shin: flared shell, stripe, piston and hose behind.
	shin = rbox((lw * 1.1, hip * 0.4, lw * 1.3), (0, 0, 0), r=lw * 0.3, seg=3,
		shape=lambda v, h: (v.__setitem__(0, v.x * (0.85 if v.y > 0 else 1.08)), v.__setitem__(2, v.z * (0.85 if v.y > 0 else 1.05))))
	band(shin, 0, -lw * 0.13, lw * 0.13, 1, lambda c, n: n.z < -0.2)
	m.add(g, shin, paint, kit.xform(at(0, -hip * 0.72, 0.02)))
	for s in (-1, 1):
		m.add(g, studs(shin, row(at(0, -hip * 0.6, -lw * 0.3), at(0, -hip * 0.6, lw * 0.3), 3) +
			row(at(0, -hip * 0.84, -lw * 0.3), at(0, -hip * 0.84, lw * 0.3), 3), (-s, 0, 0)), "metal")
	m.add(g, tube([at(0, ky - 0.2, lw * 0.62), at(0, -hip * 0.86, lw * 0.75)], 0.06, 8, smooth_path=False), "chrome")
	m.add(g, tube([at(lw * 0.3 * side, ky, lw * 0.4), at(lw * 0.5 * side, -hip * 0.66, lw * 0.75), at(lw * 0.3 * side, -hip * 0.9, lw * 0.5)], 0.05, 8), "hose")
	# Foot: a rounded skid, rubber toe bumper and a painted toe cap.
	fy = -hip * 0.945
	m.add(g, cyl(lw * 0.3, lw * 0.9, at(0, fy + 0.18, 0), "x", 12, bevel=0.03), "dark")
	foot = rbox((lw + 0.35, hip * 0.13, lw + 1.0), (0, 0, 0), r=0.12, seg=2)
	m.add(g, foot, "dark", kit.xform(at(0, fy, -0.25)))
	cap = rbox((lw + 0.25, hip * 0.12, (lw + 1.0) * 0.55), (0, 0, 0), r=0.12, seg=3,
		shape=lambda v, h: v.__setitem__(1, v.y - (0.12 if v.z < 0 and v.y > 0 else 0.0)))
	m.add(g, cap, L["paint"], kit.xform(at(0, fy + hip * 0.1, -0.25 - (lw + 1.0) * 0.18)))
	m.add(g, cyl(0.18, lw + 0.38, at(0, fy - 0.03, -0.25 - (lw + 1.0) * 0.5 - 0.05), "x", 12, bevel=0.06), "rubber")
	m.add(g, rbox((lw + 0.3, 0.1, 0.5), (0, 0, 0), r=0.04, seg=2), "rubber", kit.xform(at(0, fy - hip * 0.06, 0.2)))


def arm(m, P, L, side, pivot):
	sh = P["sh"]
	g = "ArmL" if side < 0 else "ArmR"
	o = kit.Vector(pivot)

	def at(x, y, z):
		return (o.x + x, o.y + y, o.z + z)

	wreck = P.get("wreck")
	m.add(g, sphere(0.42 * sh, at(0, 0, 0)), "dark")
	# Shoulder fender: a wheel-arch shaped pad with a stripe over the top.
	if not (P.get("scrap") and side < 0) and not (wreck and side < 0):
		pad = rbox((1.0, 0.8, 1.3), (0, 0, 0), r=0.3, seg=3,
			shape=lambda v, h: (v.__setitem__(0, v.x * (0.8 if v.y < 0 else 1.0)), v.__setitem__(1, v.y + (0.1 if abs(v.z) < 0.1 else 0.0))))
		band(pad, 2, -0.12, 0.12, 1, lambda c, n: n.y > -0.2)
		pm = [L["paint"] if side < 0 or P.get("cage") != "trim" else L["paint"], L["stripe"]]
		m.add(g, pad, pm, kit.xform(at(side * 0.1 * sh, 0.12 * sh, 0), (0, 0, side * -10), (sh, sh, sh)))
		m.add(g, studs(pad, row(at(side * 0.2 * sh, -0.12 * sh, -0.45 * sh), at(side * 0.2 * sh, -0.12 * sh, 0.45 * sh), 5), (-side, 0, 0), 0.035 * sh), "metal")
		if P.get("slabs"):
			slab = rbox((0.9, 0.18, 1.1), (0, 0, 0), r=0.07, seg=2)
			m.add(g, slab, L["trim"], kit.xform(at(side * 0.12 * sh, 0.62 * sh, 0), (0, 0, side * -12), (sh, sh, sh)))
			m.add(g, studs(slab, [at(side * (0.12 + x) * sh, 0.3, z * sh) for x in (-0.3, 0.3) for z in (-0.4, 0.4)], (0, -1, 0), 0.045 * sh), "metal")
		if P.get("fins"):
			fin = rbox((0.08, 0.7, 0.9), (0, 0, 0), r=0.03, seg=2,
				shape=lambda v, h: v.__setitem__(2, v.z + (0.35 if v.y > 0 else 0.0)))
			band(fin, 1, 0.15, 0.4, 1)
			m.add(g, fin, [L["paint"], L["stripe"]], kit.xform(at(side * 0.42 * sh, 0.6 * sh, 0.2), (0, 0, side * -18), (sh, sh, sh)))
	# Upper arm: dark frame with a chrome piston up the front.
	m.add(g, rbox((0.5 * sh, 1.1, 0.5 * sh), (0, 0, 0), r=0.08, seg=2), "dark", kit.xform(at(0, -0.75, 0)))
	m.add(g, tube([at(0, -0.3, -0.34 * sh), at(0, -1.2, -0.34 * sh)], 0.06 * sh, 8, smooth_path=False), "chrome")
	m.add(g, tube([at(0, -0.25, -0.34 * sh), at(0, -0.8, -0.34 * sh)], 0.1 * sh, 10, smooth_path=False), "metal")
	m.add(g, tube([at(side * 0.3 * sh, -0.1, 0.2), at(side * 0.4 * sh, -0.8, 0.35), at(side * 0.3 * sh, -1.35, 0.2)], 0.05, 8), "hose")
	# Elbow hub.
	m.add(g, cyl(0.32 * sh, 0.62 * sh, at(0, -1.4, 0), "x", 14, bevel=0.05), "dark")
	m.add(g, cyl(0.2 * sh, 0.7 * sh, at(0, -1.4, 0), "x", 12, bevel=0.03), "chrome")
	if wreck and side < 0:
		# Torn off below the elbow: frayed cables and a ragged stump.
		stump = jitter(rbox((0.7 * sh, 0.7 * sh, 0.6 * sh), (0, 0, 0), r=0.15, seg=2), 0.05, 4)
		m.add(g, stump, L["paint"], kit.xform(at(0, -1.45, -0.25)))
		for i in range(5):
			a = i * 1.3
			m.add(g, tube([at(0, -1.45, -0.5), at(math.cos(a) * 0.15, -1.5 + math.sin(a) * 0.1, -0.85), at(math.cos(a) * 0.3, -1.75 - i * 0.08, -1.0)], 0.03, 6), "hose" if i % 2 else "dark")
		return
	# Forearm shell: painted, stripe on top, cooling slats on the outside.
	fore = rbox((0.72, 0.72, 1.5), (0, 0, 0), r=0.22, seg=3,
		shape=lambda v, h: (v.__setitem__(0, v.x * (0.88 if v.z > 0 else 1.0)), v.__setitem__(1, v.y * (0.88 if v.z > 0 else 1.0))))
	band(fore, 0, -0.1, 0.1, 1, lambda c, n: n.y > 0.3)
	m.add(g, fore, [L["paint"], L["stripe"]], kit.xform(at(0, -1.45, -0.55 * sh), (0, 0, 0), (sh, sh, sh)))
	for i in range(3):
		m.add(g, rbox((0.06, 0.08, 0.6), (0, 0, 0), r=0.025, seg=1), "dark", kit.xform(at(side * 0.37 * sh, -1.45 - 0.12 * (i - 1) * sh, -0.55 * sh)))
	if side < 0:
		# Fist: rubber knuckle roll and four blunt fingers.
		m.add(g, rbox((0.58, 0.58, 0.45), (0, 0, 0), r=0.14, seg=2), "dark", kit.xform(at(0, -1.45, -1.45 * sh), (0, 0, 0), (sh, sh, sh)))
		m.add(g, cyl(0.13, 0.6, at(0, -1.38, -1.62 * sh), "x", 12, bevel=0.04), "rubber")
		for i in range(4):
			x = (-0.21 + i * 0.14) * sh
			m.add(g, rbox((0.12, 0.3, 0.24), (0, 0, 0), r=0.05, seg=2), "dark", kit.xform(at(x, -1.62 * sh, -1.62 * sh), (25, 0, 0), (sh, sh, sh)))
		m.add(g, rbox((0.14, 0.24, 0.35), (0, 0, 0), r=0.05, seg=2), "dark", kit.xform(at(0.33 * sh, -1.5, -1.42 * sh), (0, 0, -20), (sh, sh, sh)))
	else:
		m.add(g, cyl(0.32 * sh, 0.2, at(0, -1.45, -1.2 * sh + 0.05), "z", 14, bevel=0.04), "chrome")


def torso(m, P, L, ty):
	w, d, h = P["w"], P["d"], P["h"]
	nose = P.get("nose", 0.18)
	scrap = P.get("scrap")
	wreck = P.get("wreck")
	top = ty + h * 0.5

	# Hull pod: rounded, the front top raked back into a hood. The scrap
	# buggy is an open tub with only the lower half of the hull.
	hh = h * 0.58 if scrap else h
	hy = ty - h * 0.21 if scrap else ty

	def shape(v, half):
		if v.y > 0 and v.z < 0:
			v.z += d * nose
		if v.y < 0:
			v.x *= 0.86
			v.z *= 0.9

	hull = rbox((w, hh, d), (0, 0, 0), r=min(w, hh, d) * 0.36, seg=4, shape=shape)
	if wreck:
		dent(hull, (w * 0.3, hh * 0.3, -d * 0.4), 0.7, 0.25, 1)
		dent(hull, (-w * 0.45, -hh * 0.1, 0.0), 0.6, 0.2, 2)
		dent(hull, (0.1, hh * 0.5, 0.3), 0.5, 0.15, 3)
	# Twin racing stripes over the top and down the front and back.
	for s in (-1, 1):
		band(hull, 0, min(s * w * 0.09, s * w * 0.2), max(s * w * 0.09, s * w * 0.2), 1, lambda c, n: n.y > 0.2 or abs(n.z) > 0.5)
	if scrap:
		band(hull, 0, w * 0.15, w * 0.5, 2, lambda c, n: n.x > 0.5 or (n.z < -0.5 and c.x > w * 0.2))
	m.add("Torso", hull, [L["paint"], L["stripe"], "metal" if scrap else L["paint"]], kit.xform((0, hy, 0)))
	m.add("Torso", rbox((w * 0.9, 0.5, d * 0.85), (0, 0, 0), r=0.18, seg=2), "dark", kit.xform((0, ty - h * 0.5 - 0.15, 0)))

	front = -d * 0.5
	if not scrap:
		# Canopy: tinted glass in a trim frame, set into the raked front.
		gy = ty + h * 0.2
		slope = math.degrees(math.atan2(d * nose, h * 0.5))
		m.add("Torso", rbox((w * 0.66, h * 0.36, 0.16), (0, 0, 0), r=0.07, seg=2), L["trim"], kit.xform((0, gy, front + d * nose * 0.6), (-slope, 0, 0)))
		glass = rbox((w * 0.56, h * 0.27, 0.12), (0, 0, 0), r=0.05, seg=2)
		if wreck:
			glass = jitter(glass, 0.04, 9)
		m.add("Torso", glass, "glass", kit.xform((0, gy, front + d * nose * 0.6 - 0.05), (-slope, 0, 0)))
		if wreck:
			# A shell punched through the glass.
			m.add("Torso", sphere(0.22, (w * 0.1, gy + 0.05, front + d * nose * 0.6 - 0.08), (1, 1, 0.3), 10, 6), "soot")

	# Hood: a lower nose pushed out in front of the pod like a buggy's bonnet,
	# sloping down to the grille. Carries the stripes, grille and headlights.
	hood_d = d * 0.5
	hood_h = h * 0.5
	hood_y = ty - h * 0.2
	hood_z = front - hood_d * 0.22

	def hood_shape(v, half):
		if v.y > 0 and v.z < 0:
			v.y -= half.y * 0.6
		if v.y < 0:
			v.x *= 0.9

	hood = rbox((w * 0.84, hood_h, hood_d), (0, 0, 0), r=min(hood_h, hood_d) * 0.42, seg=3, shape=hood_shape)
	for s in (-1, 1):
		band(hood, 0, min(s * w * 0.09, s * w * 0.2), max(s * w * 0.09, s * w * 0.2), 1, lambda c, n: n.y > 0.2 or n.z < -0.5)
	if wreck:
		dent(hood, (-w * 0.25, hood_h * 0.3, -hood_d * 0.4), 0.45, 0.2, 5)
	hood_mats = ["metal", L["stripe"]] if scrap else [L["paint"], L["stripe"]]
	m.add("Torso", hood, hood_mats, kit.xform((0, hood_y, hood_z)))
	nose_z = hood_z - hood_d * 0.5

	# Grille mouth on the nose: trim surround, dark recess, chrome slats.
	my = hood_y - hood_h * 0.12
	surround = m.add("Torso", rbox((w * 0.5, hood_h * 0.5, 0.18), (0, 0, 0), r=0.07, seg=2), L["trim"], kit.xform((0, my, nose_z + 0.06)))
	m.add("Torso", rbox((w * 0.42, hood_h * 0.36, 0.1), (0, 0, 0), r=0.035, seg=1), "dark", kit.xform((0, my, nose_z - 0.02)))
	for i in range(5):
		m.add("Torso", cyl(0.032, hood_h * 0.34, ((i - 2) * w * 0.08, my, nose_z - 0.05), "y", 6), "chrome")
	m.add("Torso", studs(surround, [(sx * w * 0.22, my + sy * hood_h * 0.19, 0) for sx in (-1, 1) for sy in (-1, 1)], (0, 0, 1), 0.035), "metal")

	# Lamps: snapped onto the hood (or the roof), bezel and lens.
	lamp_mat = "glow_dead" if wreck else ("glow_red" if P["lamps"] == "red" else "glow_lamp")
	hy = hood_y + hood_h * 0.05
	spots = {
		"twin": [(-w * 0.33, hy, 0.17, "front"), (w * 0.33, hy, 0.17, "front")],
		"bar": [(-w * 0.22, 0, 0.13, "roof"), (0, 0, 0.13, "roof"), (w * 0.22, 0, 0.13, "roof")],
		"slit": [(-w * 0.32, hy, 0.09, "front"), (w * 0.32, hy, 0.09, "front")],
		"odd": [(-w * 0.32, hy, 0.19, "front"), (w * 0.33, hy + 0.12, 0.11, "front")],
		"red": [(-w * 0.27, hy, 0.11, "front"), (-w * 0.35, hy + 0.2, 0.08, "front"), (w * 0.27, hy, 0.11, "front"), (w * 0.35, hy + 0.2, 0.08, "front")],
	}[P["lamps"]]
	for x, y, r, where in spots:
		if where == "front":
			loc, n = kit.hit(hood, (x, y, 0), (0, 0, 1))
			loc = loc + kit.Vector((0, 0, -0.02))
			m.add("Torso", cyl(r + 0.05, 0.14, tuple(loc), "z", 16, bevel=0.03), "chrome")
			m.add("Eye", sphere(r, tuple(loc + kit.Vector((0, 0, -0.07))), (1, 1, 0.5), 14, 8), lamp_mat)
		else:
			loc, n = kit.hit(hull, (x, top + 1.0, front + d * 0.45), (0, -1, 0))
			m.add("Torso", cyl(r + 0.05, 0.22, tuple(loc + kit.Vector((0, 0.1, 0))), "z", 16, bevel=0.03), "chrome")
			m.add("Eye", sphere(r, tuple(loc + kit.Vector((0, 0.1, -0.1))), (1, 1, 0.5), 14, 8), lamp_mat)
	if P["lamps"] == "slit":
		m.add("Eye", rbox((w * 0.5, 0.09, 0.08), (0, 0, 0), r=0.03, seg=1), "glow_red", kit.xform((0, ty + h * 0.02, front + d * nose * 0.25 - 0.06), (-15, 0, 0)))

	# Side skirts along the lower body, and bolted plates with rivets.
	for s in (-1, 1):
		m.add("Torso", rbox((0.16, h * 0.15, d * 1.2), (0, 0, 0), r=0.06, seg=2), L["trim"] if not scrap else "rust", kit.xform((s * w * 0.48, ty - h * 0.36, -hood_d * 0.25)))
		if scrap and s > 0:
			continue
		plate = m.add("Torso", rbox((0.1, h * 0.38, d * 0.5), (0, 0, 0), r=0.035, seg=1), L["trim"], kit.xform((s * w * 0.49, ty + h * 0.02, 0.1)))
		m.add("Torso", studs(plate, [(0, ty + h * 0.02 + sy * h * 0.15, 0.1 + sz * d * 0.2) for sy in (-1, 1) for sz in (-1, 1)], (-s, 0, 0), 0.04), "metal")

	# Roll cage over the pod.
	cage_mat = {"trim": L["trim"], "dark": "dark", "chrome": "chrome", "paint": L["paint"]}[P["cage"]]
	cy = top + 0.18 if not scrap else top + 0.35
	cx = w * 0.4
	rnd = random.Random(5)
	for s in (-1, 1):
		pts = [(s * cx, ty, front + 0.15), (s * cx, cy, front + d * 0.3), (s * cx, cy + 0.05, d * 0.25), (s * cx, ty + h * 0.1, d * 0.5 + 0.1)]
		if wreck and s > 0:
			pts = [(x + rnd.uniform(-0.15, 0.15), y + rnd.uniform(-0.25, 0.05), z) for x, y, z in pts]
		m.add("Cage", tube(pts, 0.07, 8), cage_mat)
	for z in (front + d * 0.3, d * 0.25):
		m.add("Cage", tube([(-cx, cy + (0.05 if z > 0 else 0), z), (cx, cy + (0.05 if z > 0 else 0), z)], 0.065, 8, smooth_path=False), cage_mat)
	if scrap:
		# Open tub: a seat, a dash and side bars, all on show.
		seat_y = ty - h * 0.08
		m.add("Cage", rbox((w * 0.4, 0.2, d * 0.45), (0, 0, 0), r=0.08, seg=2), "seat", kit.xform((0, seat_y, 0.1)))
		m.add("Cage", rbox((w * 0.4, h * 0.45, 0.2), (0, 0, 0), r=0.08, seg=2), "seat", kit.xform((0, seat_y + h * 0.24, d * 0.32), (-10, 0, 0)))
		m.add("Cage", rbox((w * 0.7, 0.25, 0.3), (0, 0, 0), r=0.08, seg=2), "dark", kit.xform((0, ty + h * 0.12, front + 0.25)))
		m.add("Cage", cyl(0.18, 0.06, (0, ty + h * 0.2, front + 0.5), "z", 14), "dark")
		for s in (-1, 1):
			m.add("Cage", tube([(s * w * 0.5, ty - h * 0.2, front + 0.1), (s * w * 0.52, ty + h * 0.15, 0), (s * w * 0.5, ty - h * 0.2, d * 0.45)], 0.06, 8), cage_mat)
		# Mismatched patch panel in another titan's colour.
		patch = m.add("Torso", rbox((0.08, h * 0.32, d * 0.4), (0, 0, 0), r=0.03, seg=1), L["stripe"], kit.xform((-w * 0.47, ty - h * 0.08, -0.1), (0, 0, 6)))
		m.add("Torso", studs(patch, [(0, ty - h * 0.08 + sy * h * 0.12, -0.1 + sz * d * 0.15) for sy in (-1, 1) for sz in (-1, 0, 1)], (1, 0, 0), 0.035), "metal")
	if P.get("bullbar"):
		by = hood_y
		bz = nose_z - 0.3
		front = nose_z + 0.15
		m.add("Cage", tube([(-w * 0.45, by - h * 0.25, front), (-w * 0.42, by - h * 0.2, bz), (w * 0.42, by - h * 0.2, bz), (w * 0.45, by - h * 0.25, front)], 0.08, 8), cage_mat)
		m.add("Cage", tube([(-w * 0.42, by + h * 0.2, front), (-w * 0.38, by + h * 0.15, bz), (w * 0.38, by + h * 0.15, bz), (w * 0.42, by + h * 0.2, front)], 0.07, 8), cage_mat)
		for x in (-w * 0.2, w * 0.2):
			m.add("Cage", tube([(x, by - h * 0.2, bz), (x, by + h * 0.15, bz)], 0.06, 8, smooth_path=False), cage_mat)
	if P.get("blades"):
		for s in (-1, 1):
			blade = rbox((0.14, 0.3, 1.6), (0, 0, 0), r=0.05, seg=2,
				shape=lambda v, h: (v.__setitem__(1, v.y * (0.2 if v.z < 0 else 1.0)), v.__setitem__(0, v.x * (0.4 if v.z < 0 else 1.0))))
			band(blade, 2, -0.8, -0.35, 1)
			m.add("Torso", blade, [L["paint"], L["stripe"]], kit.xform((s * w * 0.42, hood_y - hood_h * 0.2, nose_z - 0.4), (8, s * 6, s * -10)))

	# Back: engine block with chrome heads and exhaust stacks, or a jet.
	back = d * 0.5
	ey = ty - 0.05
	if P.get("jet"):
		m.add("Engine", cyl(h * 0.36, 0.9, (0, ey, back + 0.35), "z", 20, bevel=0.08), "chrome")
		m.add("Engine", cyl(h * 0.4, 0.25, (0, ey, back + 0.75), "z", 20, bevel=0.06), L["paint"])
		m.add("Engine", cyl(h * 0.3, 0.1, (0, ey, back + 0.86), "z", 20), "dark")
		m.add("Core", cyl(h * 0.2, 0.06, (0, ey, back + 0.9), "z", 16), "glow_core")
		for i in range(8):
			a = i * 45
			m.add("Engine", rbox((0.05, h * 0.26, 0.04), (0, 0, 0), r=0.0), "dark", kit.xform((0, ey, back + 0.93), (0, 0, a + 20)))
		for s in (-1, 1):
			fin = rbox((0.09, 1.1, 1.0), (0, 0, 0), r=0.04, seg=2, shape=lambda v, hh: v.__setitem__(2, v.z + (0.45 if v.y > 0 else 0.0)))
			band(fin, 1, 0.25, 0.55, 1)
			m.add("Engine", fin, [L["paint"], L["stripe"]], kit.xform((s * w * 0.3, top + 0.3, back), (0, 0, s * -14)))
	else:
		m.add("Engine", rbox((w * 0.68, h * 0.62, 0.8), (0, 0, 0), r=0.14, seg=2), "dark", kit.xform((0, ey, back + 0.32)))
		# V-twin rows of chrome cylinder heads with cooling rings.
		for s in (-1, 1):
			for i in range(3):
				z = back + 0.15 + i * 0.25
				c = (s * w * 0.2, ey + h * 0.36, z)
				m.add("Engine", cyl(0.12, 0.42, c, "y", 12, bevel=0.03, rot=(0, 0, s * -30)), "chrome")
				for k in range(3):
					m.add("Engine", cyl(0.155, 0.035, (c[0] + s * 0.06 * (k - 1) * 0.6, c[1] + 0.1 * (k - 1), z), "y", 12, rot=(0, 0, s * -30)), "metal")
		# Core: the glowing intake in the middle of the block, behind a fan.
		m.add("Engine", cyl(0.42, 0.12, (0, ey - h * 0.05, back + 0.75), "z", 18, bevel=0.03), "chrome")
		core_mat = "glow_dead" if wreck else "glow_core"
		m.add("Core", cyl(0.34, 0.05, (0, ey - h * 0.05, back + 0.8), "z", 18), core_mat)
		for i in range(6):
			m.add("Engine", rbox((0.06, 0.3, 0.03), (0, 0, 0), r=0.0), "dark", kit.xform((0, ey - h * 0.05, back + 0.83), (0, 0, i * 60 + 15)))
		m.add("Engine", gear(0.3, 0.1, 12, (-w * 0.32, ey - h * 0.18, back + 0.55), "x"), "brass")
		# Exhaust stacks curling up over the shoulders.
		n = P.get("stacks", 2)
		for i in range(n):
			x = (-1 + 2 * i / max(1, n - 1)) * w * 0.26 if n > 1 else 0.0
			pts = [(x, ey + h * 0.15, back + 0.55), (x * 1.05, top + 0.1, back + 0.75), (x * 1.1, top + 0.65, back + 0.6)]
			if wreck and i == 1:
				pts[-1] = (x + 0.4, top + 0.2, back + 1.0)
			m.add("Engine", tube(pts, 0.11, 10), "chrome")
			m.add("Engine", cyl(0.14, 0.18, pts[-1], "y", 12, bevel=0.03), "soot" if wreck else "dark")
	# Hoses from the block to the shoulders; whip antenna on the back corner.
	for s in (-1, 1):
		m.add("Engine", tube([(s * w * 0.3, ey + h * 0.1, back + 0.2), (s * w * 0.42, top + 0.05, back), (s * w * 0.48, ty + h * 0.32, d * 0.1)], 0.07, 8), "hose")
	ant = [(-w * 0.42, top - 0.1, back), (-w * 0.44, top + 1.4, back + 0.15)]
	m.add("Engine", tube(ant, 0.02, 6, smooth_path=False), "dark")
	m.add("Engine", sphere(0.06, ant[1]), "glow_red" if not wreck else "dark")
	if wreck:
		# Scorch plates and bullet holes along the left side.
		m.add("Torso", rbox((0.06, h * 0.4, d * 0.5), (0, 0, 0), r=0.02, seg=1), "soot", kit.xform((-w * 0.47, ty + h * 0.15, -0.1), (0, 0, -8)))
		rnd = random.Random(12)
		for i in range(9):
			p, _ = kit.hit(hull, (w * rnd.uniform(-0.4, 0.4), ty + h * rnd.uniform(0.0, 0.35), 0), (0, 0, 1))
			m.add("Torso", sphere(0.06, tuple(p), (1, 1, 0.3), 8, 4), "soot")
		for i in range(4):
			a = i * 0.9
			m.add("Engine", tube([(w * 0.2, ty + h * 0.1, front + 0.2), (w * 0.3 + math.cos(a) * 0.2, ty - h * 0.3, front - 0.1), (w * 0.35 + math.cos(a) * 0.3, ty - h * 0.65 - i * 0.05, front - 0.25)], 0.025, 6), "hose" if i % 2 else "dark")


def pelvis(m, P, L):
	w, d, hip = P["w"], P["d"], P["hip"]
	h = P["h"]
	m.add("Pelvis", rbox((w * 0.58, 0.6, d * 0.55), (0, 0, 0), r=0.15, seg=2), "dark", kit.xform((0, hip, 0)))
	m.add("Pelvis", rbox((w * 0.45, 0.4, 0.2), (0, 0, 0), r=0.1, seg=2), L["trim"], kit.xform((0, hip + 0.05, -d * 0.28)))
	m.add("Pelvis", gear(0.32, 0.12, 12, (0, hip, d * 0.3), "z"), "brass")
	m.add("Pelvis", cyl(0.1, 0.3, (0, hip, d * 0.3), "z", 10), "chrome")
	# Waist: bellows rings between hip and torso.
	for i in range(4):
		m.add("Pelvis", cyl(w * (0.2 if i % 2 else 0.24), 0.16, (0, hip + 0.32 + i * 0.13, 0), "y", 16, bevel=0.04), "rubber" if i % 2 else "dark")
	for s in (-1, 1):
		m.add("Pelvis", tube([(s * w * 0.22, hip - 0.1, -d * 0.2), (s * w * 0.2, hip + 0.75, -d * 0.25)], 0.06, 8, smooth_path=False), "chrome")


def titan(id, P):
	L = livery_materials(id, P)
	mats = dict(SHARED)
	mats[L["paint"]] = P["paint"]
	mats[L["stripe"]] = P["stripe"]
	mats[L["trim"]] = P["trim"]
	kit.reset(mats)
	m = Model()
	w, h, hip, sh, lw = P["w"], P["h"], P["hip"], P["sh"], P["leg"]
	ty = hip + 0.75 + h * 0.5
	legs = {s: (s * (w * 0.29 + lw * 0.45), hip, 0.0) for s in (-1, 1)}
	arms = {s: (s * (w * 0.5 + 0.35 * sh), ty + h * 0.3, 0.0) for s in (-1, 1)}
	pelvis(m, P, L)
	torso(m, P, L, ty)
	for s in (-1, 1):
		leg(m, P, L, s, legs[s])
		arm(m, P, L, s, arms[s])
	objs = m.build()
	for name in ("LegL", "LegR", "ArmL", "ArmR"):
		objs[name].name = name + "Mesh"
	for s in (-1, 1):
		lp = kit.empty("LegL" if s < 0 else "LegR", legs[s])
		kit.set_parent(objs["LegL" if s < 0 else "LegR"], lp)
		ap = kit.empty("ArmL" if s < 0 else "ArmR", arms[s])
		kit.set_parent(objs["ArmL" if s < 0 else "ArmR"], ap)
		if s > 0:
			kit.empty("WeaponMount", (arms[s][0], arms[s][1] - 1.45, -1.2 * sh), ap)
	kit.export(os.path.join(OUT, "titan_%s.glb" % id))


# --- weapons ---------------------------------------------------------------------

WEAPONS = {
	"xo16": {"paint": (0.15, 0.16, 0.18), "stripe": (1.0, 0.72, 0.02)},
	"tracker": {"paint": (0.22, 0.32, 0.17), "stripe": (1.0, 0.4, 0.02)},
	"splitter": {"paint": (0.9, 0.9, 0.88), "stripe": (0.2, 0.75, 0.95)},
	"scrap": {"paint": (0.62, 0.3, 0.12), "stripe": (0.3, 0.5, 0.75)},
}


def weapon(id, P):
	paint, stripe = "paint_gun_" + id, "stripe_gun_" + id
	mats = dict(SHARED)
	mats[paint] = P["paint"]
	mats[stripe] = P["stripe"]
	kit.reset(mats)
	m = Model()
	if id == "xo16":
		body = rbox((0.7, 0.8, 1.4), (0, 0, 0), r=0.2, seg=3)
		band(body, 2, -0.35, -0.15, 1, lambda c, n: abs(n.z) < 0.9)
		m.add("Body", body, [paint, stripe], kit.xform((0, 0, -0.5)))
		drum = cyl(0.45, 0.5, (0, 0, 0), "x", 18, bevel=0.08)
		band(drum, 0, -0.08, 0.08, 1)
		m.add("Body", drum, [stripe, "dark"], kit.xform((0.58, -0.08, -0.35)))
		m.add("Body", studs(drum, [(0.6, -0.08 + math.sin(a) * 0.3, -0.35 + math.cos(a) * 0.3) for a in [i * math.tau / 8 for i in range(8)]], (-1, 0, 0)), "metal")
		m.add("Body", tube([(0.4, 0.2, -0.3), (0.25, 0.45, -0.6), (0.0, 0.42, -1.0)], 0.06, 8), "dark")
		m.add("Body", tube([(0, 0.42, -0.1), (0, 0.65, -0.35), (0, 0.65, -0.75), (0, 0.42, -0.95)], 0.05, 8), "chrome")
		m.add("Body", cyl(0.36, 0.25, (0, 0, -1.25), "z", 16, bevel=0.05), "dark")
		m.add("Body", cyl(0.34, 0.12, (0, 0, -2.0), "z", 16, bevel=0.03), "dark")
		barrels = cyl(0.33, 0.2, (0, 0, -2.75), "z", 16, bevel=0.04)
		for i in range(6):
			a = math.tau * i / 6
			merge(barrels, cyl(0.075, 1.7, (math.cos(a) * 0.2, math.sin(a) * 0.2, -2.0), "z", 8))
		m.add("Barrels", barrels, "chrome")
		m.add("Barrels", cyl(0.08, 1.7, (0, 0, -2.0), "z", 8), "dark")
	elif id == "tracker":
		body = rbox((0.8, 0.9, 1.9), (0, 0, 0), r=0.22, seg=3, shape=lambda v, h: v.__setitem__(1, v.y - (0.12 if v.z < 0 and v.y > 0 else 0)))
		band(body, 0, -0.12, 0.12, 1, lambda c, n: n.y > 0.3)
		m.add("Body", body, [paint, stripe], kit.xform((0, 0.05, -0.7)))
		m.add("Body", studs(body, row((0, 0.28, -0.1), (0, 0.28, -1.3), 5) + row((0, -0.2, -0.1), (0, -0.2, -1.3), 5), (-1, 0, 0)), "metal")
		m.add("Body", cyl(0.24, 1.7, (0, 0.1, -2.3), "z", 16, bevel=0.03), "dark")
		for z in (-1.8, -2.4):
			m.add("Body", cyl(0.3, 0.12, (0, 0.1, z), "z", 16, bevel=0.03), "metal")
		brake = rbox((0.66, 0.4, 0.5), (0, 0, 0), r=0.1, seg=2)
		m.add("Body", brake, "dark", kit.xform((0, 0.1, -3.2)))
		for s in (-1, 1):
			for i in range(3):
				m.add("Body", rbox((0.06, 0.24, 0.07), (0, 0, 0), r=0.0), "rubber", kit.xform((s * 0.33, 0.1, -3.05 - i * 0.13)))
		m.add("Body", rbox((0.42, 0.62, 0.55), (0, 0, 0), r=0.1, seg=2), "dark", kit.xform((0, -0.6, -0.5)))
		m.add("Body", cyl(0.12, 0.9, (0, 0.62, -0.9), "z", 12, bevel=0.03), "dark")
		m.add("Body", cyl(0.15, 0.12, (0, 0.62, -1.38), "z", 12), "chrome")
		m.add("Glow", cyl(0.1, 0.03, (0, 0.62, -1.45), "z", 12), "glow_red")
		for z in (-0.6, -1.2):
			m.add("Body", rbox((0.1, 0.18, 0.1), (0, 0, 0), r=0.02), "dark", kit.xform((0, 0.5, z)))
		m.add("Body", cyl(0.18, 0.8, (-0.48, -0.1, -0.7), "z", 12, bevel=0.04), "brass")
	elif id == "splitter":
		body = rbox((0.55, 0.68, 2.6), (0, 0, 0), r=0.24, seg=3,
			shape=lambda v, h: (v.__setitem__(1, v.y * (0.65 if v.z < 0 else 1.0)), v.__setitem__(0, v.x * (0.8 if v.z < 0 else 1.0))))
		band(body, 2, 0.5, 0.75, 1)
		m.add("Body", body, [paint, stripe], kit.xform((0, 0, -1.1)))
		m.add("Glow", rbox((0.16, 0.06, 1.8), (0, 0, 0), r=0.03, seg=1), "glow_core", kit.xform((0, 0.25, -1.1)))
		for i in range(3):
			z = -1.6 - i * 0.28
			m.add("Body", cyl(0.33, 0.08, (0, 0, z), "z", 16, bevel=0.02), "chrome")
			m.add("Glow", cyl(0.29, 0.1, (0, 0, z), "z", 16), "glow_core")
		for s in (-1, 1):
			prong = rbox((0.12, 0.2, 1.05), (0, 0, 0), r=0.05, seg=2, shape=lambda v, h: v.__setitem__(1, v.y * (0.5 if v.z < 0 else 1.0)))
			m.add("Body", prong, "dark", kit.xform((s * 0.17, 0, -2.55)))
			m.add("Glow", sphere(0.06, (s * 0.17, 0, -3.02)), "glow_core")
		m.add("Body", rbox((0.38, 0.48, 0.65), (0, 0, 0), r=0.1, seg=2), "dark", kit.xform((0, -0.45, -0.4)))
		m.add("Glow", rbox((0.4, 0.1, 0.4), (0, 0, 0), r=0.02), "glow_core", kit.xform((0, -0.45, -0.4)))
	else:
		# Scrap rifle: a pipe on an engine cylinder, clamps, tape and a patch.
		recv = cyl(0.32, 1.2, (0, 0, 0), "z", 14, bevel=0.05)
		m.add("Body", recv, "rust", kit.xform((0, 0, -0.5), (0, 0, 4)))
		for i in range(5):
			m.add("Body", cyl(0.4, 0.06, (0, 0, -0.1 - i * 0.18), "z", 14), "metal")
		plate = m.add("Body", rbox((0.08, 0.5, 0.7), (0, 0, 0), r=0.03, seg=1), paint, kit.xform((0.38, 0.05, -0.55), (0, 0, 6)))
		m.add("Body", studs(plate, [(0.2, 0.05 + y, -0.55 + z) for y in (-0.18, 0.18) for z in (-0.26, 0.26)], (-1, 0, 0)), "metal")
		m.add("Body", cyl(0.14, 1.6, (0.03, 0.05, -1.85), "z", 10), "metal")
		for z in (-1.3, -2.0, -2.5):
			m.add("Body", cyl(0.18, 0.08, (0.03, 0.05, z), "z", 10), "chrome")
		m.add("Body", cyl(0.2, 0.25, (0.03, 0.05, -2.5), "z", 10, bevel=0.03), "dark")
		for z in (-0.25, -0.85):
			m.add("Body", cyl(0.345, 0.1, (0, 0, z), "z", 14), "rubber")
		m.add("Body", tube([(0, 0.35, -0.2), (0.0, 0.6, -0.5), (0.1, 0.45, -0.95)], 0.05, 8), "hose")
		m.add("Body", cyl(0.07, 0.5, (0.12, 0.45, -0.8), "z", 10, rot=(0, 0, -12)), "dark")
		m.add("Body", cyl(0.07, 0.5, (0.27, 0.45, -0.8), "z", 10), stripe)
		m.add("Body", rbox((0.3, 0.55, 0.35), (0, 0, 0), r=0.08, seg=2), "dark", kit.xform((0, -0.45, -0.6), (10, 0, 0)))
	m.build()
	kit.export(os.path.join(OUT, "titan_weapon_%s.glb" % id))


def main():
	os.makedirs(OUT, exist_ok=True)
	for id, P in TITANS.items():
		if not ONLY or id in ONLY:
			titan(id, P)
	for id, P in WEAPONS.items():
		if not ONLY or ("gun_" + id) in ONLY:
			weapon(id, P)


main()
