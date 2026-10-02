"""Builds the titans and titan weapons in Blender and exports them for Godot.

    blender --background --python tools/titans/build_titans.py -- assets/models/titans [only]

The look is the Jak 3 / Jak X garage, sleek: every panel is a subdivision
fairing with flowing curves in glossy candy paint and racing stripes, a
bubble canopy over the pilot, almond headlights on a swept nose, chrome
pinstripes and chrome joints. Eco keeps them polished. Each chassis:

  atlas    sky blue, orange stripes: the all-rounder
  ogre     mustard yellow and army green, broad armoured fenders, stacks
  stryder  white and red, long nose, tail fins and a jet turbine
  scrap    rusty olive open-tub buggy: roll cage, seat, tyre knees
  enemy    candy crimson and cream, front blades, red eyes
  wreck    Eco's dad's Atlas, blue with an orange stripe, smashed (for the hub)

A Cockpit group (canopy rim, dash, Dad's photo) frames her view while she
pilots; it's hidden otherwise.

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
from kit import Model, band, cyl, dent, gear, jitter, merge, rbox, rivets, row, smooth, sphere, studs, tire, tube  # noqa: E402

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
	"glass": (0.02, 0.07, 0.13),
	"seat": (0.36, 0.2, 0.12),
	"hose": (0.55, 0.12, 0.08),
	"soot": (0.05, 0.045, 0.04),
	"photo": (0.78, 0.7, 0.55),
	"sticker_pink": (1.0, 0.42, 0.68),
	"sticker_yellow": (1.0, 0.84, 0.18),
	"sticker_mint": (0.42, 0.95, 0.78),
	"sticker_white": (0.97, 0.95, 0.92),
	"plush_lilac": (0.74, 0.62, 0.95),
	"plush_pink": (1.0, 0.6, 0.78),
	"tape": (0.85, 0.82, 0.7),
	"glow_core": ((0.4, 0.85, 1.0), (0.4, 0.85, 1.0)),
	"glow_lamp": ((1.0, 0.9, 0.65), (1.0, 0.9, 0.65)),
	"glow_red": ((1.0, 0.18, 0.1), (1.0, 0.18, 0.1)),
	"glow_dead": (0.08, 0.1, 0.11),
}

# Chassis: torso w/d/h, leg thickness, shoulder scale, hip height (same as the
# old primitive titans) plus the livery and parts.
TITANS = {
	"atlas": {"w": 2.2, "d": 1.6, "h": 1.85, "leg": 0.68, "sh": 0.88, "hip": 3.1,
		"paint": (0.16, 0.48, 0.86), "stripe": (1.0, 0.38, 0.02), "trim": (0.92, 0.87, 0.74),
		"lamps": "twin"},
	"ogre": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "sh": 1.3, "hip": 2.9,
		"paint": (1.0, 0.66, 0.02), "stripe": (0.1, 0.22, 0.12), "trim": (0.16, 0.3, 0.16),
		"lamps": "twin", "slabs": True, "stacks": 2, "nose": 0.28},
	"stryder": {"w": 1.45, "d": 1.05, "h": 1.25, "leg": 0.42, "sh": 0.6, "hip": 3.55,
		"paint": (0.92, 0.92, 0.9), "stripe": (0.86, 0.1, 0.08), "trim": (0.3, 0.32, 0.36),
		"lamps": "twin", "fins": True, "jet": True, "nose": 0.55, "open": True},
	"scrap": {"w": 2.5, "d": 1.8, "h": 1.9, "leg": 0.75, "sh": 1.0, "hip": 3.0,
		"paint": (0.3, 0.4, 0.16), "stripe": (1.0, 0.4, 0.05), "trim": (0.6, 0.55, 0.45),
		"lamps": "twin", "scrap": True, "stacks": 2},
	"enemy": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "sh": 1.3, "hip": 2.9,
		"paint": (0.66, 0.02, 0.04), "stripe": (0.93, 0.86, 0.68), "trim": (0.18, 0.18, 0.2),
		"lamps": "red", "blades": True, "stacks": 2, "nose": 0.4},
	"wreck": {"w": 2.2, "d": 1.6, "h": 1.85, "leg": 0.68, "sh": 0.88, "hip": 3.1,
		"paint": (0.1, 0.32, 0.7), "stripe": (1.0, 0.38, 0.04), "trim": (0.85, 0.82, 0.72),
		"lamps": "twin", "wreck": True},
}


def livery_materials(id, p):
	pre = "wreck_" if p.get("wreck") else ""
	return {
		"paint": pre + "paint_" + id, "stripe": pre + "stripe_" + id, "trim": pre + "trim_" + id,
	}


# --- chassis parts ---------------------------------------------------------------
# Everything visible is a subdivision-surface fairing (kit.smooth): swept,
# flowing, glossy, like the Jak 3 / Jak X cars and the zoomers. Mechanical bits
# show only in the joints, in chrome. The scrap chassis keeps its tyre knees
# and roll cage, because it's scrap.

def nz(co, half):
	"""Normalised cage coords: u across, v up, t front(-1) to back(+1)."""
	return co.x / half.x, co.y / half.y, co.z / half.z


def stripe_band(bm, width, gap, index=1, where=None):
	"""Twin racing stripes either side of the centre line."""
	where = where or (lambda c, n: n.y > 0.15 or n.z < -0.4)
	for s in (-1, 1):
		lo, hi = sorted((s * gap, s * (gap + width)))
		band(bm, 0, lo, hi, index, where)
	return bm


def leg(m, P, L, side, pivot):
	lw, hip = P["leg"], P["hip"]
	g = "LegL" if side < 0 else "LegR"
	o = kit.Vector(pivot)

	def at(x, y, z):
		return (o.x + x, o.y + y, o.z + z)

	paint = [L["paint"], L["stripe"]]
	m.add(g, cyl(lw * 0.4, lw + 0.1, at(0, 0, 0), "x", 20, bevel=0.1), "dark")
	m.add(g, cyl(lw * 0.22, lw + 0.24, at(0, 0, 0), "x", 16, bevel=0.06), "chrome")

	# Thigh fairing: full at the hip, tucking in to the knee, a little bulge forward.
	def thigh_shape(co, half):
		u, v, t = nz(co, half)
		if v < 0:
			co.x *= 0.8
			co.z *= 0.82
		if t < 0 and v > -0.5:
			co.z -= lw * 0.08

	thigh = smooth((lw * 1.08, hip * 0.46, lw * 1.2), (0, 0, 0), thigh_shape)
	band(thigh, 0, -lw * 0.09, lw * 0.09, 1, lambda c, n: n.z < -0.3)
	m.add(g, thigh, paint, kit.xform(at(0, -hip * 0.25, -0.02)))
	# Chrome thigh ram behind.
	m.add(g, tube([at(0, -0.2, lw * 0.55), at(0, -hip * 0.32, lw * 0.6)], 0.11, 12, smooth_path=False), "dark")
	m.add(g, tube([at(0, -hip * 0.3, lw * 0.6), at(0, -hip * 0.5, lw * 0.45)], 0.06, 12, smooth_path=False), "chrome")

	ky = -hip * 0.5
	if P.get("scrap"):
		m.add(g, tire(lw * 0.52, lw * 0.62, at(0, ky, 0), "x", 18, tread=lw * 0.05), "rubber")
		for s in (-1, 1):
			m.add(g, cyl(lw * 0.28, 0.08, at(s * lw * 0.33, ky, 0), "x", 14, bevel=0.025), "chrome")
	else:
		# Chrome knee hub and a glossy knee cap.
		m.add(g, cyl(lw * 0.36, lw * 0.72, at(0, ky, 0), "x", 24, bevel=0.1), "chrome")
		m.add(g, cyl(lw * 0.2, lw * 0.8, at(0, ky, 0), "x", 16, bevel=0.05), "dark")

		def cap_shape(co, half):
			u, v, t = nz(co, half)
			if t > 0:
				co.x *= 0.7
				co.y *= 0.7

		cap = smooth((lw * 0.78, lw * 0.75, lw * 0.4), (0, 0, 0), cap_shape)
		band(cap, 0, -lw * 0.09, lw * 0.09, 1)
		m.add(g, cap, paint, kit.xform(at(0, ky + 0.05, -lw * 0.45), (-14, 0, 0)))

	# Shin fairing: calf flares out behind, tapers to a slim ankle.
	def shin_shape(co, half):
		u, v, t = nz(co, half)
		if v < 0:
			co.x *= 0.78
			co.z *= 0.8
		if t > 0 and v > -0.4:
			co.z += lw * 0.16
		if t < 0:
			co.z -= lw * 0.04

	shin = smooth((lw * 1.12, hip * 0.44, lw * 1.3), (0, 0, 0), shin_shape)
	band(shin, 0, -lw * 0.09, lw * 0.09, 1, lambda c, n: n.z < -0.3)
	m.add(g, shin, paint, kit.xform(at(0, -hip * 0.72, 0.04)))
	m.add(g, tube([at(0, ky - 0.25, lw * 0.75), at(0, -hip * 0.88, lw * 0.6)], 0.05, 10, smooth_path=False), "chrome")

	# Shoe: a sleek wedge with a pointed toe on a dark sole.
	fy = -hip * 0.93
	m.add(g, cyl(lw * 0.26, lw * 0.85, at(0, fy + 0.14, 0), "x", 16, bevel=0.06), "chrome")

	def shoe_shape(co, half):
		u, v, t = nz(co, half)
		f = max(0.0, -t)
		co.x *= 1.0 - 0.3 * f
		if v > 0:
			co.y -= half.y * 0.9 * f
		if t > 0.5 and v > 0:
			co.y += half.y * 0.2

	shoe = smooth((lw + 0.3, hip * 0.17, lw + 1.15), (0, 0, 0), shoe_shape)
	band(shoe, 0, -lw * 0.09, lw * 0.09, 1, lambda c, n: n.y > 0.2)
	m.add(g, shoe, paint, kit.xform(at(0, fy + 0.02, -0.28)))
	sole = smooth((lw + 0.4, 0.14, lw + 1.25), (0, 0, 0), lambda co, h: co.__setitem__(0, co.x * (1.0 - 0.3 * max(0.0, -co.z / h.z))), cuts=1)
	m.add(g, sole, "dark", kit.xform(at(0, fy - hip * 0.06, -0.28)))


def arm(m, P, L, side, pivot):
	sh = P["sh"]
	g = "ArmL" if side < 0 else "ArmR"
	o = kit.Vector(pivot)

	def at(x, y, z):
		return (o.x + x, o.y + y, o.z + z)

	wreck = P.get("wreck")
	paint = [L["paint"], L["stripe"]]
	m.add(g, sphere(0.42 * sh, at(0, 0, 0), seg=20, rings=12), "chrome")
	# Shoulder fender: a swept wheel-arch shell, stripe running front to back.
	if not (P.get("scrap") and side < 0) and not (wreck and side < 0):
		def fender(co, half):
			u, v, t = nz(co, half)
			if v < 0:
				co.x *= 0.72
			if t > 0:
				co.y -= half.y * 0.45 * t
				co.x *= 1.0 - 0.15 * t
			if t < 0 and v > 0:
				co.y += half.y * 0.2
				co.z -= half.z * 0.1

		pad = smooth((1.1, 0.78, 1.45), (0, 0, 0), fender)
		band(pad, 0, -0.08, 0.08, 1, lambda c, n: n.y > -0.2)
		m.add(g, pad, paint, kit.xform(at(side * 0.12 * sh, 0.14 * sh, 0), (0, 0, side * -12), (sh, sh, sh)))
		if P.get("slabs"):
			slab = smooth((0.85, 0.24, 1.15), (0, 0, 0), lambda co, h: co.__setitem__(0, co.x * (0.85 if co.y < 0 else 1.0)), cuts=1)
			m.add(g, slab, L["trim"], kit.xform(at(side * 0.16 * sh, 0.6 * sh, 0.05), (0, 0, side * -14), (sh, sh, sh)))
		if P.get("fins"):
			fin = smooth((0.1, 0.7, 0.9), (0, 0, 0), lambda co, h: co.__setitem__(2, co.z + (0.4 if co.y > 0 else 0.0)), cuts=1)
			band(fin, 1, 0.12, 0.45, 1)
			m.add(g, fin, paint, kit.xform(at(side * 0.42 * sh, 0.62 * sh, 0.25), (0, 0, side * -18), (sh, sh, sh)))
	# Upper arm: dark sleeve, chrome ram up the front.
	m.add(g, smooth((0.5 * sh, 1.1, 0.5 * sh), (0, 0, 0), cuts=1), "dark", kit.xform(at(0, -0.75, 0)))
	m.add(g, tube([at(0, -0.3, -0.32 * sh), at(0, -1.2, -0.32 * sh)], 0.055 * sh, 12, smooth_path=False), "chrome")
	m.add(g, tube([at(0, -0.25, -0.32 * sh), at(0, -0.75, -0.32 * sh)], 0.095 * sh, 12, smooth_path=False), "dark")
	m.add(g, cyl(0.3 * sh, 0.62 * sh, at(0, -1.4, 0), "x", 20, bevel=0.08), "chrome")
	if wreck and side < 0:
		# Torn off below the elbow: frayed cables and a ragged stump.
		stump = jitter(smooth((0.7 * sh, 0.7 * sh, 0.6 * sh), (0, 0, 0), cuts=1), 0.05, 4)
		m.add(g, stump, L["paint"], kit.xform(at(0, -1.45, -0.25)))
		for i in range(5):
			a = i * 1.3
			m.add(g, tube([at(0, -1.45, -0.5), at(math.cos(a) * 0.15, -1.5 + math.sin(a) * 0.1, -0.85), at(math.cos(a) * 0.3, -1.75 - i * 0.08, -1.0)], 0.03, 6), "hose" if i % 2 else "dark")
		return

	# Forearm fairing: tapers toward the wrist, stripe on top, a glow line
	# down the outside (Eco sees this one from the cockpit, so it's pretty).
	def fore_shape(co, half):
		u, v, t = nz(co, half)
		if t < 0:
			co.x *= 0.82
			co.y *= 0.82
		if t > 0 and v > 0:
			co.y += half.y * 0.12

	fore = smooth((0.74, 0.74, 1.6), (0, 0, 0), fore_shape)
	band(fore, 0, -0.07, 0.07, 1, lambda c, n: n.y > 0.3)
	m.add(g, fore, paint, kit.xform(at(0, -1.45, -0.55 * sh), (0, 0, 0), (sh, sh, sh)))
	if not P.get("scrap"):
		lamp = "glow_red" if P["lamps"] == "red" else "glow_core"
		m.add(g, smooth((0.05, 0.07, 1.0), (0, 0, 0), cuts=1), lamp, kit.xform(at(side * 0.37 * sh, -1.42, -0.55 * sh), (0, 0, 0), (1, 1, sh)))
	if side < 0:
		# Hand: an armoured mitt, a glossy knuckle plate and four fingers.
		m.add(g, smooth((0.58, 0.56, 0.5), (0, 0, 0), cuts=1), "dark", kit.xform(at(0, -1.45, -1.42 * sh), (0, 0, 0), (sh, sh, sh)))
		m.add(g, smooth((0.6, 0.22, 0.32), (0, 0, 0), cuts=1), L["paint"], kit.xform(at(0, -1.25 * sh, -1.5 * sh), (20, 0, 0), (sh, sh, sh)))
		for i in range(4):
			x = (-0.21 + i * 0.14) * sh
			m.add(g, smooth((0.12, 0.32, 0.22), (0, 0, 0), cuts=1), "dark", kit.xform(at(x, -1.62 * sh, -1.62 * sh), (25, 0, 0), (sh, sh, sh)))
		m.add(g, smooth((0.14, 0.26, 0.34), (0, 0, 0), cuts=1), "dark", kit.xform(at(0.33 * sh, -1.5, -1.42 * sh), (0, 0, -20), (sh, sh, sh)))
	else:
		m.add(g, cyl(0.3 * sh, 0.18, at(0, -1.45, -1.2 * sh + 0.05), "z", 20, bevel=0.06), "chrome")


def torso(m, P, L, ty):
	w, d, h = P["w"], P["d"], P["h"]
	nose = P.get("nose", 0.32)
	scrap = P.get("scrap")
	wreck = P.get("wreck")
	top = ty + h * 0.5
	lamp_mat = "glow_dead" if wreck else ("glow_red" if P["lamps"] == "red" else "glow_lamp")

	# Body: one subdivision shell. The low front sweeps forward into a nose,
	# the windscreen line rakes back, the tail tucks in.
	def body(co, half):
		u, v, t = nz(co, half)
		f = max(0.0, -t)
		b = max(0.0, t)
		if v <= 0:
			co.z -= d * nose * f * (1.0 + 0.3 * v)
		else:
			co.z += d * 0.28 * f * v
			co.y -= half.y * 0.45 * f * v
		co.x *= 1.0 - 0.22 * f - 0.16 * b - 0.14 * max(0.0, -v)
		if v > 0:
			co.y -= half.y * 0.32 * b

	hh = h * 0.62 if scrap else h
	hy = ty - h * 0.19 if scrap else ty
	hull = smooth((w, hh, d), (0, 0, 0), body)
	if wreck:
		dent(hull, (w * 0.3, hh * 0.3, -d * 0.4), 0.7, 0.25, 1)
		dent(hull, (-w * 0.45, -hh * 0.1, 0.0), 0.6, 0.2, 2)
		dent(hull, (0.1, hh * 0.5, 0.3), 0.5, 0.15, 3)
	stripe_band(hull, w * 0.1, w * 0.06)
	m.add("Torso", hull, [L["paint"], L["stripe"]], kit.xform((0, hy, 0)))
	m.add("Torso", smooth((w * 0.8, 0.5, d * 0.8), (0, 0, 0), cuts=1), "dark", kit.xform((0, ty - h * 0.5 - 0.1, 0)))

	# Almond headlights, a low grille slot and a chin spoiler on the nose.
	for s in (-1, 1):
		loc, n = kit.hit(hull, (s * w * 0.28, ty - h * 0.12, 0), (0, 0, 1))
		if loc is None:
			continue
		yaw = math.degrees(math.atan2(-n.x, -n.z))
		m.add("Eye", sphere(0.2, (0, 0, 0), (1.25, 0.45, 0.5), 18, 10), lamp_mat, kit.xform(tuple(loc), (-10, -yaw, s * 12)))
		m.add("Torso", sphere(0.2, (0, 0, 0), (1.4, 0.55, 0.45), 18, 10), "chrome", kit.xform(tuple(loc + n * -0.04), (-10, -yaw, s * 12)))
	loc, n = kit.hit(hull, (0, ty - h * 0.36, 0), (0, 0, 1))
	m.add("Torso", smooth((w * 0.42, 0.16, 0.3), (0, 0, 0), cuts=1), "dark", kit.xform(tuple(loc)))
	for dy in (-0.035, 0.035):
		m.add("Torso", cyl(0.022, w * 0.4, (loc.x, loc.y + dy, loc.z - 0.12), "x", 8), "chrome")
	chin = smooth((w * 0.7, 0.1, 0.45), (0, 0, 0), lambda co, h: co.__setitem__(0, co.x * (0.8 if co.z < 0 else 1.0)), cuts=1)
	m.add("Torso", chin, L["trim"], kit.xform((0, ty - h * 0.5 + 0.02, loc.z + 0.05)))

	# Chrome pinstripe along each flank, and a dark air scoop below it.
	for s in (-1, 1):
		pts = []
		for i in range(7):
			z = -d * (0.5 + nose * 0.7) + i * d * (1.0 + nose * 0.7) / 6.0
			p, n = kit.hit(hull, (s * w, ty + h * 0.06 - i * h * 0.015, z), (-s, 0, 0))
			if p is not None:
				pts.append(tuple(p + n * 0.02))
		if len(pts) > 2:
			m.add("Torso", tube(pts, 0.03, 8), "chrome")
		loc, n = kit.hit(hull, (s * w, ty - h * 0.17, d * 0.05), (-s, 0, 0))
		if loc is None:
			continue
		scoop = smooth((0.14, h * 0.24, d * 0.42), (0, 0, 0), lambda co, h: co.__setitem__(1, co.y * (0.6 if co.z < 0 else 1.0)), cuts=1)
		m.add("Torso", scoop, "dark", kit.xform(tuple(loc)))

	# Bubble canopy over the pilot (her eye sits inside it), on a trim ring.
	if P.get("open"):
		open_seat(m, P, L, ty)
	elif not scrap:
		def bubble(co, half):
			u, v, t = nz(co, half)
			f = max(0.0, -t)
			co.x *= 1.0 - 0.35 * f
			if v > 0:
				co.y -= half.y * 0.35 * f
			if v < 0:
				co.y *= 0.6

		cz = -0.2
		glass = smooth((w * 0.48, 1.15, 1.7), (0, 0, 0), bubble)
		if wreck:
			glass = jitter(glass, 0.03, 9)
		m.add("Canopy", glass, "glass", kit.xform((0, top - 0.05, cz)))
		ring = [(math.sin(a) * w * 0.23 * (1.0 - 0.25 * max(0.0, -math.cos(a))), top - 0.2, cz + math.cos(a) * 0.8) for a in [i * math.tau / 20 for i in range(20)]]
		m.add("Canopy", tube(ring, 0.045, 8, closed=True), "chrome")
		if wreck:
			m.add("Canopy", sphere(0.2, (w * 0.08, top + 0.25, cz - 0.5), (1, 0.6, 0.3), 10, 6), "soot")

	# Tail: a sleek cowling with the glowing core intake and twin exhausts,
	# or a jet turbine with fins.
	back = d * 0.5
	ey = ty - 0.05
	if P.get("jet"):
		m.add("Engine", cyl(h * 0.34, 0.9, (0, ey, back + 0.3), "z", 28, bevel=0.15, r2=h * 0.28), L["paint"])
		m.add("Engine", cyl(h * 0.27, 0.3, (0, ey, back + 0.75), "z", 28, bevel=0.06), "chrome")
		m.add("Engine", cyl(h * 0.22, 0.1, (0, ey, back + 0.86), "z", 24), "dark")
		m.add("Core", cyl(h * 0.17, 0.06, (0, ey, back + 0.9), "z", 24), "glow_core")
		for s in (-1, 1):
			fin = smooth((0.1, 1.1, 1.0), (0, 0, 0), lambda co, hh: co.__setitem__(2, co.z + (0.5 if co.y > 0 else 0.0)), cuts=1)
			band(fin, 1, 0.2, 0.55, 1)
			m.add("Engine", fin, [L["paint"], L["stripe"]], kit.xform((s * w * 0.28, top + 0.25, back - 0.05), (0, 0, s * -16)))
	else:
		def cowl(co, half):
			u, v, t = nz(co, half)
			if t > 0:
				co.x *= 0.82
				co.y *= 0.85

		hood = smooth((w * 0.66, h * 0.66, 0.9), (0, 0, 0), cowl)
		stripe_band(hood, w * 0.1, w * 0.06, 1, lambda c, n: n.y > 0.2 or n.z > 0.4)
		m.add("Engine", hood, [L["paint"], L["stripe"]], kit.xform((0, ey, back + 0.2)))
		m.add("Engine", cyl(0.36, 0.14, (0, ey + h * 0.08, back + 0.66), "z", 24, bevel=0.05), "chrome")
		m.add("Core", cyl(0.29, 0.05, (0, ey + h * 0.08, back + 0.73), "z", 24), "glow_dead" if wreck else "glow_core")
		for s in (-1, 1):
			m.add("Engine", cyl(0.13, 0.5, (s * w * 0.2, ey - h * 0.22, back + 0.55), "z", 16, bevel=0.04, r2=0.16), "chrome")
			m.add("Engine", cyl(0.1, 0.1, (s * w * 0.2, ey - h * 0.22, back + 0.81), "z", 16), "soot" if wreck else "dark")
		for i in range(P.get("stacks", 0)):
			x = (-1 + 2 * i / max(1, P["stacks"] - 1)) * w * 0.2
			pts = [(x, ey + h * 0.2, back + 0.5), (x, top + 0.1, back + 0.65), (x, top + 0.45, back + 0.55)]
			m.add("Engine", tube(pts, 0.1, 12), "chrome")
	ant = [(-w * 0.36, top - 0.1, back), (-w * 0.38, top + 1.2, back + 0.2)]
	m.add("Engine", tube(ant, 0.018, 6, smooth_path=False), "dark")
	m.add("Engine", sphere(0.05, ant[1]), "glow_red" if not wreck else "dark")

	if P.get("blades"):
		for s in (-1, 1):
			blade = smooth((0.14, 0.32, 1.7), (0, 0, 0), lambda co, h: (co.__setitem__(1, co.y * (0.2 if co.z < 0 else 1.0)), co.__setitem__(0, co.x * (0.4 if co.z < 0 else 1.0))), cuts=1)
			band(blade, 2, -0.85, -0.4, 1)
			m.add("Torso", blade, [L["paint"], L["stripe"]], kit.xform((s * w * 0.36, ty - h * 0.38, -d * (0.5 + nose) - 0.3), (6, s * 8, s * -12)))
	if scrap:
		# Open tub buggy: roll cage, a seat and a dash on show, a patch panel.
		cage = L["paint"]
		cy = top + 0.35
		cx = w * 0.4
		front = -d * 0.5
		for s in (-1, 1):
			m.add("Cage", tube([(s * cx, ty - h * 0.1, front), (s * cx, cy, front + d * 0.3), (s * cx, cy + 0.05, d * 0.25), (s * cx, ty, d * 0.5 + 0.1)], 0.07, 8), cage)
			m.add("Cage", tube([(s * w * 0.5, ty - h * 0.2, front + 0.1), (s * w * 0.52, ty + h * 0.15, 0), (s * w * 0.5, ty - h * 0.2, d * 0.45)], 0.06, 8), cage)
		for z in (front + d * 0.3, d * 0.25):
			m.add("Cage", tube([(-cx, cy, z), (cx, cy, z)], 0.065, 8, smooth_path=False), cage)
		seat_y = ty - h * 0.06
		m.add("Cage", smooth((w * 0.4, 0.2, d * 0.45), (0, 0, 0), cuts=1), "seat", kit.xform((0, seat_y, 0.1)))
		m.add("Cage", smooth((w * 0.4, h * 0.45, 0.22), (0, 0, 0), cuts=1), "seat", kit.xform((0, seat_y + h * 0.24, d * 0.32), (-10, 0, 0)))
		m.add("Cage", smooth((w * 0.7, 0.25, 0.3), (0, 0, 0), cuts=1), "dark", kit.xform((0, ty + h * 0.1, front + 0.25)))
		patch = m.add("Torso", rbox((0.08, h * 0.28, d * 0.4), (0, 0, 0), r=0.03, seg=1), L["stripe"], kit.xform((-w * 0.44, ty - h * 0.18, -0.1), (0, 0, 6)))
		m.add("Torso", studs(patch, [(0, ty - h * 0.18 + sy * h * 0.1, -0.1 + sz * d * 0.15) for sy in (-1, 1) for sz in (-1, 0, 1)], (1, 0, 0), 0.035), "metal")
	if wreck:
		rnd = random.Random(12)
		for i in range(9):
			p, _ = kit.hit(hull, (w * rnd.uniform(-0.4, 0.4), ty + h * rnd.uniform(-0.2, 0.25), 0), (0, 0, 1))
			if p is None:
				continue
			m.add("Torso", sphere(0.06, tuple(p), (1, 1, 0.3), 8, 4), "soot")
		p, n = kit.hit(hull, (-w, ty + h * 0.1, 0.0), (1, 0, 0))
		if p is not None:
			m.add("Torso", sphere(0.5, tuple(p), (0.15, 0.8, 1.0), 12, 8), "soot")
		for i in range(4):
			a = i * 0.9
			m.add("Engine", tube([(w * 0.25, ty - h * 0.2, -d * 0.4), (w * 0.3 + math.cos(a) * 0.2, ty - h * 0.45, -d * 0.6), (w * 0.35 + math.cos(a) * 0.3, ty - h * 0.75 - i * 0.05, -d * 0.7)], 0.025, 6), "hose" if i % 2 else "dark")


def pelvis(m, P, L):
	w, d, hip = P["w"], P["d"], P["hip"]
	m.add("Pelvis", smooth((w * 0.6, 0.65, d * 0.6), (0, 0, 0), cuts=1), "dark", kit.xform((0, hip, 0)))
	cod = smooth((w * 0.42, 0.45, 0.3), (0, 0, 0), lambda co, h: co.__setitem__(0, co.x * (0.7 if co.y < 0 else 1.0)), cuts=1)
	m.add("Pelvis", cod, L["paint"], kit.xform((0, hip + 0.02, -d * 0.3)))
	m.add("Pelvis", cyl(w * 0.22, 0.6, (0, hip + 0.5, 0), "y", 24, bevel=0.1), "dark")
	m.add("Pelvis", cyl(w * 0.235, 0.1, (0, hip + 0.55, 0), "y", 24, bevel=0.03), "chrome")
	for s in (-1, 1):
		m.add("Pelvis", tube([(s * w * 0.22, hip - 0.1, -d * 0.18), (s * w * 0.2, hip + 0.75, -d * 0.22)], 0.05, 10, smooth_path=False), "chrome")


def open_seat(m, P, L, ty):
	"""Stryder's open cockpit: she rides it like a racing bike. A bucket seat
	and headrest behind her, a low wraparound windscreen, chrome side rails
	and a halo hoop over the seat back."""
	w, d, h = P["w"], P["d"], P["h"]
	top = ty + h * 0.5
	m.add("Torso", smooth((0.62, 0.16, 0.6), (0, 0, 0), cuts=1), "seat", kit.xform((0, top + 0.02, 0.15)))
	back = smooth((0.62, 0.95, 0.2), (0, 0, 0), lambda co, hh: co.__setitem__(0, co.x * (0.8 if co.y > 0 else 1.0)), cuts=1)
	m.add("Torso", back, "seat", kit.xform((0, top + 0.5, 0.48), (-12, 0, 0)))
	m.add("Torso", smooth((0.4, 0.26, 0.2), (0, 0, 0), cuts=1), L["paint"], kit.xform((0, 6.3, 0.5), (-12, 0, 0)))
	halo = [(-0.42, top + 0.05, 0.62), (-0.36, 6.55, 0.62), (0, 6.78, 0.6), (0.36, 6.55, 0.62), (0.42, top + 0.05, 0.62)]
	m.add("Torso", tube(halo, 0.045, 10), "chrome")
	for s in (-1, 1):
		m.add("Torso", tube([(s * w * 0.38, top - 0.2, -d * 0.6), (s * 0.4, top + 0.12, -0.2), (s * 0.4, top + 0.12, 0.3), (s * 0.42, top - 0.1, 0.7)], 0.035, 10), "chrome")
	shield = smooth((0.8, 0.42, 0.05), (0, 0, 0), lambda co, hh: co.__setitem__(2, co.z + abs(co.x) ** 2 * 0.6), cuts=2)
	m.add("Torso", shield, "glass", kit.xform((0, top + 0.2, -0.62), (-38, 0, 0)))


def cockpit(m, P, L):
	"""What Eco sees from the seat: the canopy rim at the edges of her view,
	a little dash with glowing dials, and Dad's photo taped to the frame.
	Hidden unless she's piloting (titan_import.gd hides it, titan.gd shows it)."""
	if P.get("open"):
		top = P["hip"] + 0.75 + P["h"]
		# Low dash right behind the windscreen, and a mirror stalk for the dice.
		# The windscreen's chrome edge, just in view at the bottom.
		edge = [(-0.42, top + 0.1, -0.7), (-0.2, top + 0.3, -0.85), (0.2, top + 0.3, -0.85), (0.42, top + 0.1, -0.7)]
		m.add("Cockpit", tube(edge, 0.02, 8), "chrome")
		m.add("Cockpit", smooth((0.4, 0.1, 0.2), (0, 0, 0), cuts=1), "dark", kit.xform((0, top - 0.05, -0.6), (-20, 0, 0)))
		for i, x in enumerate((-0.1, 0.0, 0.1)):
			m.add("Cockpit", cyl(0.035, 0.03, (x, top + 0.01, -0.6), "y", 16, rot=(-30, 0, 0)), ("glow_core", "glow_lamp", "glow_red")[i])
		m.add("Cockpit", tube([(-0.42, top + 0.05, -0.45), (-0.55, 6.25, -0.6), (-0.5, 6.45, -0.7)], 0.02, 6), "chrome")
		m.add("Cockpit", smooth((0.2, 0.1, 0.03), (0, 0, 0), cuts=1), "glass", kit.xform((-0.5, 6.48, -0.71), (0, 25, 0)))
		cute_cockpit(m, (-0.5, 6.43, -0.7), (-0.12, top + 0.0, -0.62))
		return
	rim = [(-0.85, 5.5, -0.75), (-0.74, 6.3, -0.9), (-0.42, 6.9, -0.72), (0.42, 6.9, -0.72), (0.74, 6.3, -0.9), (0.85, 5.5, -0.75)]
	m.add("Cockpit", tube(rim, 0.045, 10), L["paint"])
	m.add("Cockpit", tube([(x * 1.04, y, z + 0.04) for x, y, z in rim], 0.025, 8), "chrome")
	dash = smooth((0.62, 0.16, 0.34), (0, 0, 0), lambda co, h: co.__setitem__(1, co.y - (0.05 if co.z > 0 else 0.0)), cuts=1)
	m.add("Cockpit", dash, "dark", kit.xform((0, 5.36, -1.0), (-18, 0, 0)))
	for i, x in enumerate((-0.17, 0.0, 0.17)):
		c = kit.Vector((x, 5.45, -0.98))
		m.add("Cockpit", cyl(0.06, 0.04, tuple(c), "y", 16, bevel=0.01, rot=(-30, 0, 0)), "chrome")
		m.add("Cockpit", cyl(0.048, 0.04, tuple(c + kit.Vector((0, 0.008, 0))), "y", 16, rot=(-30, 0, 0)), ("glow_core", "glow_lamp", "glow_red")[i])
	# Dad's photo: a faded print taped to the left pillar.
	m.add("Cockpit", rbox((0.16, 0.2, 0.01), (0, 0, 0), r=0.0), "photo", kit.xform((-0.66, 5.95, -0.86), (8, 30, -10)))
	m.add("Cockpit", rbox((0.06, 0.12, 0.012), (0, 0, 0), r=0.0), "tape", kit.xform((-0.66, 6.06, -0.858), (8, 30, 30)))
	if not P.get("wreck") and P["lamps"] != "red":
		cute_cockpit(m, (-0.3, 6.88, -0.72), (-0.2, 5.44, -0.98))


# --- the cute stuff ---------------------------------------------------------------
# Eco's touches: stickers on the paint, a ribbon on the antenna, a tool pouch
# with her wrench, fuzzy dice and a plush bunny in the cockpit. Only on the
# titans she builds (not the enemy, not Dad's wreck).

def fuzzy_dice(m, anchor):
	a = kit.Vector(anchor)
	for i, dx in enumerate((-0.05, 0.06)):
		end = a + kit.Vector((dx, -0.22 - i * 0.05, 0))
		m.add("Cockpit", tube([tuple(a), tuple(end)], 0.005, 4, smooth_path=False), "dark")
		m.add("Cockpit", rbox((0.075, 0.075, 0.075), (0, 0, 0), r=0.018, seg=2), "plush_pink", kit.xform(tuple(end - kit.Vector((0, 0.04, 0))), (20 * i, 30 + 25 * i, 10)))


def bunny(m, group, base, scale=1.0, mat="plush_lilac"):
	b = kit.Vector(base)
	k = scale
	m.add(group, sphere(0.06 * k, tuple(b + kit.Vector((0, 0.05 * k, 0))), (1, 1.05, 0.9), 12, 8), mat)
	m.add(group, sphere(0.05 * k, tuple(b + kit.Vector((0, 0.14 * k, 0))), (1, 0.95, 0.95), 12, 8), mat)
	for s in (-1, 1):
		m.add(group, sphere(0.018 * k, tuple(b + kit.Vector((s * 0.022 * k, 0.21 * k, 0))), (0.8, 3.2, 0.7), 8, 6), mat)
		m.add(group, sphere(0.008 * k, tuple(b + kit.Vector((s * 0.018 * k, 0.15 * k, -0.045 * k))), (1, 1, 0.5), 6, 4), "dark")
	m.add(group, sphere(0.01 * k, tuple(b + kit.Vector((0, 0.13 * k, -0.05 * k))), (1, 0.7, 0.6), 6, 4), "sticker_pink")


def cute_cockpit(m, dice_anchor, plush_base):
	fuzzy_dice(m, dice_anchor)
	bunny(m, "Cockpit", plush_base)


def sticker(m, group, p, direction, shape, size, mat, roll=0.0):
	loc, n = m.hit(group, p, direction)
	if loc is None:
		return
	pts = {"heart": kit.heart_outline, "star": kit.star_outline, "dot": kit.circle_outline}[shape](size)
	m.add(group, kit.flat(pts, 0.012), mat, kit.facing(loc, n, roll), smooth=False)


def flower(m, group, p, direction, size, petal, centre):
	loc, n = m.hit(group, p, direction)
	if loc is None:
		return
	for i in range(5):
		a = math.tau * i / 5
		m.add(group, kit.flat(kit.circle_outline(size * 0.42), 0.01), petal,
			kit.facing(loc, n, 0.0, 0.004) @ kit.Matrix.Translation((math.cos(a) * size * 0.5, math.sin(a) * size * 0.5, 0)), smooth=False)
	m.add(group, kit.flat(kit.circle_outline(size * 0.32), 0.012), centre, kit.facing(loc, n, 0.0, 0.009), smooth=False)


def decorate(m, P, L, ty, legs, arms):
	w, d, h, sh, lw, hip = P["w"], P["d"], P["h"], P["sh"], P["leg"], P["hip"]
	top = ty + h * 0.5
	# Flank stickers: a big heart, stars, a flower.
	k = h * 0.16
	sticker(m, "Torso", (-w, ty + h * 0.02, d * 0.1), (1, 0, 0), "heart", k * 1.4, "sticker_pink", 12)
	sticker(m, "Torso", (-w, ty + h * 0.26, -d * 0.2), (1, 0, 0), "star", k * 0.9, "sticker_yellow", -8)
	sticker(m, "Torso", (-w, ty - h * 0.18, -d * 0.32), (1, 0, 0), "star", k * 0.6, "sticker_mint", 20)
	flower(m, "Torso", (w, ty + h * 0.05, d * 0.05), (-1, 0, 0), k * 1.4, "sticker_white", "sticker_yellow")
	sticker(m, "Torso", (w, ty + h * 0.26, -d * 0.25), (-1, 0, 0), "heart", k * 0.7, "sticker_pink", -15)
	# On the nose, beside the stripes, where everyone sees it.
	sticker(m, "Torso", (w * 0.3, ty + h * 0.08, 0), (0, -0.4, 1), "heart", k * 0.8, "sticker_pink", -12)
	sticker(m, "Torso", (-w * 0.32, ty + h * 0.12, 0), (0, -0.4, 1), "star", k * 0.6, "sticker_yellow", 10)
	# Shoulders: a star on the left fender, a heart on the right.
	for s in (-1, 1):
		g = "ArmL" if s < 0 else "ArmR"
		a = kit.Vector(arms[s])
		sticker(m, g, (a.x + s * 2.0, a.y + 0.15 * sh, a.z), (-s, 0, 0), "star" if s < 0 else "heart", 0.3 * sh, "sticker_yellow" if s < 0 else "sticker_pink", s * 10)
	# Her side of the right forearm (seen from the cockpit): a little heart and stars.
	a = kit.Vector(arms[1])
	for dz, shape, mat, size in ((-0.25, "heart", "sticker_pink", 0.08), (-0.6, "star", "sticker_yellow", 0.07), (-0.9, "dot", "sticker_mint", 0.04)):
		sticker(m, "ArmR", (a.x - 0.16 * sh, a.y - 1.0, a.z + dz * sh), (0, -1, 0), shape, size * max(sh, 0.8), mat, 15)
	# Tool pouch strapped to the right thigh, wrench sticking out.
	g = kit.Vector(legs[1])
	px = g.x + lw * 0.58
	py = g.y - hip * 0.22
	m.add("LegR", smooth((0.16, 0.36, 0.34), (0, 0, 0), cuts=1), "seat", kit.xform((px, py, 0.02)))
	m.add("LegR", tube([(px - lw * 0.62, py + 0.05, -lw * 0.62), (px + 0.1, py + 0.05, -0.2), (px + 0.1, py + 0.05, 0.25), (px - lw * 0.62, py + 0.05, lw * 0.62)], 0.018, 6), "dark")
	m.add("LegR", cyl(0.025, 0.36, (px + 0.02, py + 0.3, 0.06), "y", 8), "chrome")
	ring = [(px + 0.02 + math.cos(t) * 0.05, py + 0.5 + math.sin(t) * 0.05, 0.06) for t in [math.radians(a) for a in range(-50, 231, 28)]]
	m.add("LegR", tube(ring, 0.017, 6, smooth_path=False), "chrome")
	sticker(m, "LegR", (px + 0.5, py, 0.0), (-1, 0, 0), "heart", 0.06, "sticker_pink")
	# Knee and shin stickers.
	g = kit.Vector(legs[-1])
	sticker(m, "LegL", (g.x - lw * 2, g.y - hip * 0.7, 0.0), (1, 0, 0), "star", lw * 0.3, "sticker_mint", 18)
	for s in (-1, 1):
		gl = kit.Vector(legs[s])
		sticker(m, "LegL" if s < 0 else "LegR", (gl.x + lw * 0.3 * s, gl.y - hip * 0.82, 0), (0, 0, 1), "heart" if s > 0 else "star", lw * 0.2, "sticker_white", 0)
	# Pink ribbon bow just under the antenna tip.
	tip = kit.Vector((-w * 0.38, top + 1.05, d * 0.5 + 0.18))
	for s in (-1, 1):
		m.add("Engine", sphere(0.07, tuple(tip + kit.Vector((s * 0.07, 0, 0))), (1.0, 0.6, 0.35), 10, 6), "plush_pink")
		m.add("Engine", tube([tuple(tip), tuple(tip + kit.Vector((s * 0.04, -0.14, 0)))], 0.015, 4, smooth_path=False), "plush_pink")
	m.add("Engine", sphere(0.03, tuple(tip), (1, 1, 0.7), 8, 6), "plush_pink")


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
	cockpit(m, P, L)
	for s in (-1, 1):
		leg(m, P, L, s, legs[s])
		arm(m, P, L, s, arms[s])
	if id in ("atlas", "ogre", "stryder", "scrap"):
		decorate(m, P, L, ty, legs, arms)
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
		body = smooth((0.72, 0.82, 1.5), (0, 0, 0), lambda co, h: (co.__setitem__(0, co.x * (0.85 if co.z < 0 else 1.0)), co.__setitem__(1, co.y * (0.85 if co.z < 0 else 1.0))))
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
		body = smooth((0.82, 0.92, 2.0), (0, 0, 0), lambda co, h: (co.__setitem__(1, co.y - (0.14 if co.z < 0 and co.y > 0 else 0)), co.__setitem__(0, co.x * (0.85 if co.z < 0 else 1.0))))
		band(body, 0, -0.12, 0.12, 1, lambda c, n: n.y > 0.3)
		m.add("Body", body, [paint, stripe], kit.xform((0, 0.05, -0.7)))
		m.add("Body", cyl(0.24, 1.7, (0, 0.1, -2.3), "z", 16, bevel=0.03), "dark")
		for z in (-1.8, -2.4):
			m.add("Body", cyl(0.3, 0.12, (0, 0.1, z), "z", 16, bevel=0.03), "metal")
		brake = smooth((0.66, 0.42, 0.55), (0, 0, 0), cuts=1)
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
		body = smooth((0.58, 0.72, 2.7), (0, 0, 0), lambda co, h: (co.__setitem__(1, co.y * (0.6 if co.z < 0 else 1.0)), co.__setitem__(0, co.x * (0.75 if co.z < 0 else 1.0))))
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
