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

import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import Model, band, cyl, dent, gear, jitter, merge, rbox, rivets, row, smooth, sphere, tire, tube  # noqa: E402

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
	# The Precursor teal: dim on purpose, since glow_ materials render
	# unshaded at three times their colour and ACES bleaches bright ones.
	"glow_teal": ((0.004, 0.08, 0.065), (0.004, 0.08, 0.065)),
	"glow_hot": ((0.2, 0.34, 0.3), (0.2, 0.34, 0.3)),
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
		m.add(g + "Fender", pad, paint, kit.xform(at(side * 0.12 * sh, 0.14 * sh, 0), (0, 0, side * -12), (sh, sh, sh)))
		if P.get("slabs"):
			slab = smooth((0.85, 0.24, 1.15), (0, 0, 0), lambda co, h: co.__setitem__(0, co.x * (0.85 if co.y < 0 else 1.0)), cuts=1)
			m.add(g + "Fender", slab, L["trim"], kit.xform(at(side * 0.16 * sh, 0.6 * sh, 0.05), (0, 0, side * -14), (sh, sh, sh)))
		if P.get("fins"):
			fin = smooth((0.1, 0.7, 0.9), (0, 0, 0), lambda co, h: co.__setitem__(2, co.z + (0.4 if co.y > 0 else 0.0)), cuts=1)
			band(fin, 1, 0.12, 0.45, 1)
			m.add(g + "Fender", fin, paint, kit.xform(at(side * 0.42 * sh, 0.62 * sh, 0.25), (0, 0, side * -18), (sh, sh, sh)))
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
	m.add("Antenna", tube(ant, 0.018, 6, smooth_path=False), "dark")
	m.add("Antenna", sphere(0.05, ant[1]), "glow_red" if not wreck else "dark")

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
		m.add("CockpitCharms", tube([tuple(a), tuple(end)], 0.005, 4, smooth_path=False), "dark")
		m.add("CockpitCharms", rbox((0.075, 0.075, 0.075), (0, 0, 0), r=0.018, seg=2), "plush_pink", kit.xform(tuple(end - kit.Vector((0, 0.04, 0))), (20 * i, 30 + 25 * i, 10)))


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
	bunny(m, "CockpitCharms", plush_base)


def decals_of(group):
	"""Stickers live in their own nodes so the garage can peel them off."""
	return "Decals" if group == "Torso" else group + "Decals"


def sticker(m, group, p, direction, shape, size, mat, roll=0.0):
	loc, n = m.hit(group, p, direction)
	if loc is None:
		return
	pts = {"heart": kit.heart_outline, "star": kit.star_outline, "dot": kit.circle_outline}[shape](size)
	m.add(decals_of(group), kit.flat(pts, 0.012), mat, kit.facing(loc, n, roll), smooth=False)


def flower(m, group, p, direction, size, petal, centre):
	loc, n = m.hit(group, p, direction)
	if loc is None:
		return
	into = decals_of(group)
	for i in range(5):
		a = math.tau * i / 5
		m.add(into, kit.flat(kit.circle_outline(size * 0.42), 0.01), petal,
			kit.facing(loc, n, 0.0, 0.004) @ kit.Matrix.Translation((math.cos(a) * size * 0.5, math.sin(a) * size * 0.5, 0)), smooth=False)
	m.add(into, kit.flat(kit.circle_outline(size * 0.32), 0.012), centre, kit.facing(loc, n, 0.0, 0.009), smooth=False)


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
		g = ("ArmL" if s < 0 else "ArmR") + "Fender"
		a = kit.Vector(arms[s])
		if g not in m.groups:
			continue
		sticker(m, g, (a.x + s * 2.0, a.y + 0.15 * sh, a.z), (-s, 0, 0), "star" if s < 0 else "heart", 0.3 * sh, "sticker_yellow" if s < 0 else "sticker_pink", s * 10)
	# Her side of the right forearm (seen from the cockpit): a little heart and stars.
	a = kit.Vector(arms[1])
	for dz, shape, mat, size in ((-0.25, "heart", "sticker_pink", 0.08), (-0.6, "star", "sticker_yellow", 0.07), (-0.9, "dot", "sticker_mint", 0.04)):
		sticker(m, "ArmR", (a.x - 0.16 * sh, a.y - 1.0, a.z + dz * sh), (0, -1, 0), shape, size * max(sh, 0.8), mat, 15)
	# Tool pouch strapped to the right thigh, wrench sticking out.
	g = kit.Vector(legs[1])
	px = g.x + lw * 0.58
	py = g.y - hip * 0.22
	m.add("LegRPouch", smooth((0.16, 0.36, 0.34), (0, 0, 0), cuts=1), "seat", kit.xform((px, py, 0.02)))
	m.add("LegRPouch", tube([(px - lw * 0.62, py + 0.05, -lw * 0.62), (px + 0.1, py + 0.05, -0.2), (px + 0.1, py + 0.05, 0.25), (px - lw * 0.62, py + 0.05, lw * 0.62)], 0.018, 6), "dark")
	m.add("LegRPouch", cyl(0.025, 0.36, (px + 0.02, py + 0.3, 0.06), "y", 8), "chrome")
	ring = [(px + 0.02 + math.cos(t) * 0.05, py + 0.5 + math.sin(t) * 0.05, 0.06) for t in [math.radians(a) for a in range(-50, 231, 28)]]
	m.add("LegRPouch", tube(ring, 0.017, 6, smooth_path=False), "chrome")
	sticker(m, "LegRPouch", (px + 0.5, py, 0.0), (-1, 0, 0), "heart", 0.06, "sticker_pink")
	# Knee and shin stickers.
	g = kit.Vector(legs[-1])
	sticker(m, "LegL", (g.x - lw * 2, g.y - hip * 0.7, 0.0), (1, 0, 0), "star", lw * 0.3, "sticker_mint", 18)
	for s in (-1, 1):
		gl = kit.Vector(legs[s])
		sticker(m, "LegL" if s < 0 else "LegR", (gl.x + lw * 0.3 * s, gl.y - hip * 0.82, 0), (0, 0, 1), "heart" if s > 0 else "star", lw * 0.2, "sticker_white", 0)
	# Pink ribbon bow just under the antenna tip.
	tip = kit.Vector((-w * 0.38, top + 1.05, d * 0.5 + 0.18))
	for s in (-1, 1):
		m.add("Ribbon", sphere(0.07, tuple(tip + kit.Vector((s * 0.07, 0, 0))), (1.0, 0.6, 0.35), 10, 6), "plush_pink")
		m.add("Ribbon", tube([tuple(tip), tuple(tip + kit.Vector((s * 0.04, -0.14, 0)))], 0.015, 4, smooth_path=False), "plush_pink")
	m.add("Ribbon", sphere(0.03, tuple(tip), (1, 1, 0.7), 8, 6), "plush_pink")


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
	pivots = {}
	for s in (-1, 1):
		pivots["LegL" if s < 0 else "LegR"] = kit.empty("LegL" if s < 0 else "LegR", legs[s])
		ap = kit.empty("ArmL" if s < 0 else "ArmR", arms[s])
		pivots["ArmL" if s < 0 else "ArmR"] = ap
		if s > 0:
			kit.empty("WeaponMount", (arms[s][0], arms[s][1] - 1.45, -1.2 * sh), ap)
	# Customisable bits get their own nodes (see scripts/run/titan_style.gd):
	# fenders scale about their own centre and carry their stickers; the
	# ribbon rides the antenna; charms hang inside the cockpit.
	for s in (-1, 1):
		side = "ArmL" if s < 0 else "ArmR"
		fender = objs.get(side + "Fender")
		if fender is not None:
			kit.set_origin(fender, (arms[s][0] + s * 0.12 * sh, arms[s][1] + 0.2 * sh, 0.0))
	for name, ob in objs.items():
		if name in ("LegLMesh", "LegRMesh", "ArmLMesh", "ArmRMesh"):
			kit.set_parent(ob, pivots[name[:4]])
		elif name.endswith("FenderDecals"):
			kit.set_parent(ob, objs[name[:-len("Decals")]])
		elif name[:4] in pivots:
			kit.set_parent(ob, pivots[name[:4]])
		elif name == "Ribbon":
			kit.set_parent(ob, objs["Antenna"])
		elif name == "CockpitCharms":
			kit.set_parent(ob, objs["Cockpit"])
	kit.export(os.path.join(OUT, "titan_%s.glb" % id))


# --- weapons ---------------------------------------------------------------------
# The XO-16, the Splitter and the Obelisk Rail (weapon id "scrap") follow
# the concept sheets Bones picked (side profiles drawn gun-forward: x
# forward, y left, z up). Sketch maps that
# frame onto the weapon's own: the wrist (WeaponMount) sits at sketch
# (x0, 0, z0), length scales by sx, width by sy and height by sz, so the
# side silhouette keeps the sheet's proportions while the cross-section is
# fat enough to swallow the end of the titan's forearm. Plates that the
# sheet puts on one side (stripes, vents, windows) go on both, since the
# pilot sees the inner side and everyone else the outer one.

class Sketch:
	def __init__(self, m, x0, z0, sx, sy, sz):
		self.m = m
		self.s = (sx, sy, sz)
		self.M = kit.Matrix(((0, -sy, 0, 0), (0, 0, sz, -z0 * sz), (-sx, 0, 0, x0 * sx), (0, 0, 0, 1)))

	def at(self, p):
		return self.M @ kit.Vector(p)

	@staticmethod
	def arc(cx, cz, r, a0, a1, n=8):
		return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
			cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

	def prof(self, group, pts, y0, y1, mat, bevel=0.0):
		"""A side profile (x, z) extruded across y from y0 to y1; edges sharper
		than 35 degrees get a bevel, like the sheet's bevel modifier."""
		bm = bmesh.new()
		vs = [bm.verts.new((x, y0, z)) for x, z in pts]
		f = bm.faces.new(vs)
		ext = bmesh.ops.extrude_face_region(bm, geom=[f])
		bmesh.ops.translate(bm, vec=kit.Vector((0, y1 - y0, 0)), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		if bevel > 0.0:
			edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(35)]
			bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
				affect="EDGES", clamp_overlap=True)
		bmesh.ops.transform(bm, matrix=self.M, verts=bm.verts)
		return self.m.add(group, bm, mat, smooth=False)

	def sym(self, group, pts, w, mat, bevel=0.0):
		return self.prof(group, pts, -w / 2, w / 2, mat, bevel)

	def side(self, group, pts, w, y, mat, both=True):
		"""A thin plate on the face at |y| (the sheet's camera side, and the
		other side too unless both=False)."""
		y = abs(y)
		self.prof(group, pts, -y, -y - w, mat)
		if both:
			self.prof(group, pts, y, y + w, mat)

	def box(self, group, c, s, mat, bevel=0.0):
		x, y, z = c
		w, d, h = s
		return self.prof(group, [(x - w / 2, z - h / 2), (x + w / 2, z - h / 2), (x + w / 2, z + h / 2), (x - w / 2, z + h / 2)],
			y - d / 2, y + d / 2, mat, bevel)

	def cyl(self, group, p0, p1, r, mat, r1=None, segs=24, bevel=0.0):
		"""Round in the game whatever the width scale (radius scales with sz)."""
		a, b = self.at(p0), self.at(p1)
		rs = self.s[2]
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r * rs,
			radius2=(r if r1 is None else r1) * rs, depth=(b - a).length)
		if bevel > 0.0:
			caps = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(60)]
			bmesh.ops.bevel(bm, geom=caps, offset=bevel * rs, offset_type="OFFSET", segments=2, profile=0.5,
				affect="EDGES", clamp_overlap=True)
		q = kit.Vector((0, 0, 1)).rotation_difference((b - a).normalized())
		bmesh.ops.transform(bm, matrix=kit.Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), verts=bm.verts)
		return self.m.add(group, bm, mat)

	def tube(self, group, pts, r, mat, closed=False, curved=True):
		return self.m.add(group, tube([tuple(self.at(p)) for p in pts], r * self.s[2], 8, closed=closed, smooth_path=curved), mat)

	def hull(self, group, pts, mat, bevel=0.0):
		"""Convex hull of sketch points (frusta, pyramidions, wedges); edges
		sharper than 30 degrees get a bevel."""
		bm = bmesh.new()
		for p in pts:
			bm.verts.new(p)
		bmesh.ops.convex_hull(bm, input=bm.verts[:])
		bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts[:], edges=bm.edges[:])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		if bevel > 0.0:
			edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(30)]
			bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
				affect="EDGES", clamp_overlap=True)
		bmesh.ops.transform(bm, matrix=self.M, verts=bm.verts)
		return self.m.add(group, bm, mat, smooth=False)

	def slots(self, group, x0, x1, n, z0, z1, y, mat="soot", gap=0.4, slant=0.0):
		step = (x1 - x0) / n
		for i in range(n):
			x = x0 + i * step
			self.side(group, [(x, z0), (x + step * (1 - gap), z0), (x + step * (1 - gap) + slant, z1), (x + slant, z1)], 0.006, y, mat)

	def grip(self, group, x, ztop, mat, h=0.5, rake=0.12, w=0.2, depth=0.17, accent=None):
		xb, zb = x - rake, ztop - h
		self.sym(group, [(x - depth / 2, ztop), (x + depth / 2 + 0.02, ztop), (xb + depth / 2 + 0.03, zb + 0.05),
			(xb + depth / 2, zb), (xb - depth / 2 - 0.02, zb), (xb - depth / 2 - 0.04, zb + 0.06)], w, mat, 0.025)
		self.sym(group, [(xb - depth / 2 - 0.05, zb + 0.01), (xb + depth / 2 + 0.03, zb + 0.01), (xb + depth / 2 + 0.04, zb - 0.05),
			(xb - depth / 2 - 0.07, zb - 0.05)], w + 0.03, accent or mat, 0.015)
		for i in range(3):
			zz = ztop - 0.1 - i * 0.11
			self.box(group, (x + depth / 2 + 0.02 - (ztop - zz) / h * rake, 0, zz), (0.03, w + 0.004, 0.04), "soot", 0.008)

	def guard(self, group, x0, x1, ztop, depth, mat, w=0.08, th=0.035):
		zb, r = ztop - depth, 0.06
		outer = [(x0, ztop), (x0, zb)] + self.arc(x1 - r, zb + r, r, -90, 0, 5) + [(x1, ztop)]
		inner = [(x1 - th, ztop)] + self.arc(x1 - r, zb + r, r - th, 0, -90, 5) + [(x0 + th, zb + th), (x0 + th, ztop)]
		self.sym(group, outer + inner, w, mat, 0.008)

	def trigger(self, group, x, ztop, mat, curl=0.12, w=0.05):
		self.sym(group, [(x, ztop), (x + 0.035, ztop), (x + 0.025, ztop - curl * 0.6), (x - 0.01, ztop - curl),
			(x - 0.03, ztop - curl + 0.02), (x - 0.005, ztop - curl * 0.6)], w, mat, 0.006)


def xo16(m, paint, stripe, trim):
	"""Concept B, Bullpup Heavy Rifle: long low receiver, box mag behind the
	grip, square vented shroud, heavy barrel and brake, carry handle with
	Eco's re-glassed optic, one yellow flash. The forearm plugs into the butt.
	Barrels holds the barrel and brake (it used to be the rotary cluster)."""
	k = Sketch(m, -0.983, -0.016, 0.75, 1.25, 0.9)
	B = "Body"
	k.sym(B, [(-1.15, -0.2), (0.75, -0.2), (0.8, -0.1), (0.8, 0.22), (0.65, 0.3), (-0.95, 0.3), (-1.15, 0.18)], 0.5, paint, 0.03)
	# Butt: a rubber socket the wrist sits in.
	k.sym(B, [(-1.25, -0.26), (-1.12, -0.24), (-1.12, 0.22), (-1.25, 0.26)], 0.52, "rubber", 0.02)
	k.side(B, [(-1.05, -0.02), (-0.75, 0.16), (0.78, 0.16), (0.78, 0.22), (-0.78, 0.22), (-1.08, 0.04)], 0.01, 0.25, stripe)
	# Ejection port and bolt on the outer side only.
	k.side(B, [(-0.15, 0.0), (0.2, 0.0), (0.2, 0.1), (-0.15, 0.1)], 0.006, 0.25, "soot", both=False)
	k.cyl(B, (-0.12, -0.25, 0.05), (0.15, -0.25, 0.05), 0.04, "chrome", segs=12)
	# Box magazine behind the grip, round window with brass showing.
	k.sym(B, [(-0.62, -0.2), (-0.25, -0.2), (-0.22, -0.82), (-0.6, -0.86)], 0.36, trim, 0.025)
	k.sym(B, [(-0.64, -0.84), (-0.2, -0.8), (-0.2, -0.9), (-0.65, -0.94)], 0.4, stripe, 0.02)
	k.slots(B, -0.55, -0.3, 1, -0.35, -0.7, 0.181, gap=0.0, slant=0.02)
	for s in (-1, 1):
		for i in range(5):
			z = -0.4 - i * 0.07
			k.cyl(B, (-0.5, s * 0.183, z), (-0.32, s * 0.183, z + 0.004), 0.025, "brass", segs=10)
	k.grip(B, 0.02, -0.2, "rubber", h=0.48, accent=trim)
	k.guard(B, 0.09, 0.4, -0.2, 0.22, trim)
	k.trigger(B, 0.17, -0.2, "metal")
	# Square vented shroud with a yellow band at the nose.
	k.sym(B, [(0.8, -0.14), (1.75, -0.12), (1.8, -0.06), (1.8, 0.16), (1.75, 0.2), (0.8, 0.22)], 0.36, paint, 0.025)
	k.slots(B, 0.95, 1.65, 5, 0.0, 0.14, 0.181, slant=0.03)
	k.side(B, [(1.62, -0.11), (1.72, -0.11), (1.72, 0.19), (1.62, 0.19)], 0.006, 0.181, stripe)
	k.sym(B, [(1.05, -0.12), (1.2, -0.12), (1.17, -0.52), (1.08, -0.52)], 0.15, "rubber", 0.02)
	# Heavy barrel and muzzle brake.
	k.cyl("Barrels", (1.78, 0, 0.04), (2.47, 0, 0.04), 0.1, "chrome", segs=20)
	k.cyl("Barrels", (1.8, 0, 0.04), (1.95, 0, 0.04), 0.14, "metal", segs=20, bevel=0.01)
	k.sym("Barrels", [(2.45, -0.08), (2.85, -0.08), (2.9, -0.04), (2.9, 0.12), (2.85, 0.16), (2.45, 0.16)], 0.28, trim, 0.02)
	for x in (2.52, 2.64, 2.76):
		k.box("Barrels", (x + 0.035, 0, 0.04), (0.06, 0.3, 0.17), "soot")
	k.cyl("Barrels", (2.89, 0, 0.04), (2.91, 0, 0.04), 0.05, "soot", segs=12)
	# Carry handle and optic.
	k.sym(B, [(-0.7, 0.29), (-0.6, 0.5), (0.4, 0.5), (0.5, 0.29), (0.38, 0.29), (0.3, 0.41), (-0.5, 0.41), (-0.58, 0.29)], 0.12, trim, 0.015)
	k.cyl(B, (-0.3, 0, 0.6), (0.25, 0, 0.6), 0.09, paint, bevel=0.012)
	k.cyl(B, (0.2, 0, 0.6), (0.32, 0, 0.6), 0.12, trim, bevel=0.012)
	k.cyl(B, (0.32, 0, 0.6), (0.335, 0, 0.6), 0.09, "glass_optic")
	k.box(B, (-0.05, 0, 0.53), (0.3, 0.1, 0.06), trim, 0.01)
	k.box(B, (-0.25, -0.12, 0.6), (0.06, 0.06, 0.06), stripe, 0.008)
	# Eco's ammo count on the stock.
	for i in range(5):
		k.side(B, [(-0.865 + i * 0.05, 0.035), (-0.835 + i * 0.05, 0.035), (-0.835 + i * 0.05, 0.085), (-0.865 + i * 0.05, 0.085)], 0.01, 0.251, "glow_core")


def splitter(m, paint, stripe, trim):
	"""Concept A, Twin Rail: white receiver with the core glowing through
	window panels, two long emitter rails bolted into a dark yoke with the
	core rod between them and arcs jumping rail to rail. The skeleton stock
	is split into two side braces so the forearm runs between them. Every
	glowing part is in Glow."""
	k = Sketch(m, -0.797, -0.0165, 0.885, 1.2, 0.885)
	B, G = "Body", "Glow"
	top, bot, x1 = 0.3, -0.24, 0.5
	k.sym(B, [(-1.0, bot)] + k.arc(-0.85, top - 0.15, 0.15, 180, 90, 5) + [(x1 - 0.15, top), (x1, top - 0.08), (x1, bot)], 0.5, paint, 0.03)
	k.sym(B, [(-0.95, bot + 0.02), (x1, bot + 0.02), (x1 - 0.04, bot - 0.08), (-0.9, bot - 0.08)], 0.44, "dark", 0.02)
	for s in (-1, 1):
		y = s * 0.27
		k.prof(B, [(-1.0, -0.15), (-1.35, -0.3), (-1.42, -0.26), (-1.42, 0.16), (-1.35, 0.2), (-1.0, 0.2), (-1.0, 0.1),
			(-1.32, 0.1), (-1.32, -0.18), (-1.0, -0.05)], y - 0.025, y + 0.025, "dark", 0.012)
		k.prof(B, [(-1.48, -0.3), (-1.4, -0.3), (-1.4, 0.2), (-1.48, 0.2)], y - 0.035, y + 0.035, "rubber", 0.015)
	# Core window panels.
	x0w, x1w, z0w, z1w = -0.75, 0.25, 0.0, 0.14
	k.side(B, [(x0w - 0.03, z0w - 0.03), (x1w + 0.03, z0w - 0.03), (x1w + 0.03, z1w + 0.03), (x0w - 0.03, z1w + 0.03)], 0.008, 0.25, "dark")
	k.side(G, [(x0w, z0w), (x1w, z0w), (x1w, z1w), (x0w, z1w)], 0.006, 0.258, "glow_core")
	for i in range(1, 4):
		x = x0w + (x1w - x0w) * i / 4
		k.side(B, [(x - 0.015, z0w), (x + 0.015, z0w), (x + 0.015, z1w), (x - 0.015, z1w)], 0.006, 0.262, "dark")
	# Yoke and rails.
	k.sym(B, [(0.45, -0.3), (0.75, -0.3), (0.8, -0.24), (0.8, 0.34), (0.75, 0.38), (0.45, 0.38)], 0.4, "dark", 0.025)
	zc, tip = 0.04, 2.65
	for s in (1, -1):
		zi, zo = zc + s * 0.11, zc + s * 0.27
		lo, hi = min(zi, zo), max(zi, zo)
		if s > 0:
			pts = [(0.75, lo), (tip - 0.15, lo), (tip, lo + 0.05), (tip - 0.1, hi), (0.75, hi)]
		else:
			pts = [(0.75, hi), (tip - 0.15, hi), (tip, hi - 0.05), (tip - 0.1, lo), (0.75, lo)]
		k.sym(B, pts, 0.2, paint, 0.025)
		ze = zi + (-0.01 if s > 0 else 0.01)
		k.sym(G, [(0.8, ze - 0.012), (tip - 0.15, ze - 0.012), (tip - 0.15, ze + 0.012), (0.8, ze + 0.012)], 0.12, "glow_core")
		zm = (zi + zo) / 2
		k.side(B, [(1.0, zm - 0.02), (2.2, zm - 0.02), (2.2, zm + 0.02), (1.0, zm + 0.02)], 0.008, 0.1, "dark")
	# Core rod and arcs.
	k.cyl(G, (0.8, 0, zc), (2.3, 0, zc), 0.035, "glow_core", segs=12)
	for x in (1.1, 1.45, 1.8, 2.15):
		pts = [(x + (0.05 if i % 2 else -0.05) if 0 < i < 5 else x, 0.0, zc - 0.12 + 0.24 * i / 5) for i in range(6)]
		k.tube(G, pts, 0.014, "glow_core")
	# Far-side braces keep the rails parallel.
	for x in (1.3, 2.0):
		k.box(B, (x, 0.12, zc), (0.1, 0.04, 0.6), "dark", 0.012)
	k.grip(B, -0.05, -0.32, "rubber", h=0.48, accent="dark")
	k.guard(B, 0.02, 0.31, -0.32, 0.2, "dark")
	k.trigger(B, 0.1, -0.32, "metal")
	k.sym(B, [(0.48, -0.32), (0.64, -0.32), (0.61, -0.72), (0.51, -0.72)], 0.16, "rubber", 0.02)
	# Heat sink fins.
	for i in range(5):
		x = -0.5 + i * 0.12
		k.sym(B, [(x, 0.29), (x + 0.05, 0.29), (x + 0.05, 0.38), (x, 0.38)], 0.36, "dark", 0.008)


def _spine(a, b):
	"""Unit direction a -> b in the sketch's (x, z) plane and its front normal."""
	dx, dz = b[0] - a[0], b[1] - a[1]
	n = math.hypot(dx, dz)
	return (dx / n, dz / n), (-dz / n, dx / n)


def _along(a, b, t, off=0.0):
	d, n = _spine(a, b)
	return (a[0] + (b[0] - a[0]) * t + n[0] * off, a[1] + (b[1] - a[1]) * t + n[1] * off)


def _ribbon(pts, th):
	"""A thick (x, z) polyline as a closed outline; one thickness per point."""
	L, R = [], []
	for i, p in enumerate(pts):
		q0, q1 = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
		dx, dz = q1[0] - q0[0], q1[1] - q0[1]
		ln = math.hypot(dx, dz) or 1
		nx, nz = -dz / ln, dx / ln
		L.append((p[0] + nx * th[i] / 2, p[1] + nz * th[i] / 2))
		R.append((p[0] - nx * th[i] / 2, p[1] - nz * th[i] / 2))
	return L + R[::-1]


def obelisk_rail(m, paint, stripe, trim):
	"""Precursor concept I, Obelisk Rail: Precursor tech Eco found at the
	temple. Two pale obelisks hover one over the other with a teal beam
	thread between them, carved with glowing glyph channels, rooted in a
	faceted receiver with the great eye on its flank; keystones and a
	capstone hover over it on gaps held by nothing. The sheet's lying-obelisk
	stock is split into two cheek slabs so the forearm runs between them,
	each ending in a hovering butt plate. Inverted-obelisk grip, glowing
	keystone trigger in a hovering bracket, floating pommel, and Eco's one
	touch: a wrap of orange cord. Every glowing part is in Glow."""
	k = Sketch(m, -0.8, 0.037, 0.9, 1.3, 0.95)
	B, G = "Body", "Glow"
	TEAL, HOT = "glow_teal", "glow_hot"
	R = 0.01

	def groove(pts, y, r=R, mat=TEAL):
		# Carved channels go on both flanks: the pilot sees the inner one.
		for s in (1, -1):
			k.tube(G, [(x, s * y, z) for x, z in pts], r, mat, curved=False)

	def line(a, b, y, r=R):
		groove([a, b], y, r)

	def dot(x, z, y, r, mat=TEAL):
		for s in (1, -1):
			m.add(G, sphere(r * k.s[2], tuple(k.at((x, s * y, z))), seg=8, rings=6), mat)

	def circle(cx, cz, r, y, n=12, rr=R):
		groove([(cx + r * math.cos(math.tau * i / n), cz + r * math.sin(math.tau * i / n)) for i in range(n + 1)], y, rr)

	def eye(cx, cz, L, H, y, iris=True, r=R):
		groove([(cx - L / 2 + L * i / 12, cz + H / 2 * math.sin(math.pi * i / 12)) for i in range(13)], y, r)
		groove([(cx + L / 2 - L * i / 12, cz - H / 2 * math.sin(math.pi * i / 12)) for i in range(13)], y, r)
		if iris:
			ri = H * 0.36
			for s in (1, -1):
				k.cyl(G, (cx, s * (y - 0.006), cz), (cx, s * (y + 0.006), cz), ri, TEAL, segs=28)
				k.cyl(G, (cx, s * (y + 0.006), cz), (cx, s * (y + 0.011), cz), ri * 0.45, HOT, segs=20)

	def glyphs(x0, x1, zc, h, y, seed, r=0.008):
		"""A row of Precursor glyphs: bars, rings, little eyes, chevrons, dots."""
		rnd = random.Random(seed)
		step = h * 0.9
		x = x0
		while x + step * 0.8 < x1:
			c, hh = x + step / 2, h / 2
			g = rnd.choice(("bar", "ring", "eye", "chev", "dots", "tee"))
			if g == "bar":
				line((c, zc - hh), (c, zc + hh), y, r)
				line((c - hh * 0.5, zc + hh * 0.3), (c + hh * 0.5, zc + hh * 0.3), y, r)
			elif g == "ring":
				circle(c, zc, hh * 0.6, y, 10, r)
				line((c, zc - hh), (c, zc - hh * 0.6), y, r)
			elif g == "eye":
				eye(c, zc, h * 0.8, h * 0.45, y, False, r)
				dot(c, zc, y, r * 1.6)
			elif g == "chev":
				groove([(c - hh * 0.5, zc + hh), (c + hh * 0.4, zc), (c - hh * 0.5, zc - hh)], y, r)
			elif g == "dots":
				for dz in (-hh * 0.6, 0, hh * 0.6):
					dot(c, zc + dz, y, r * 1.5)
			else:
				line((c - hh * 0.5, zc + hh), (c + hh * 0.5, zc + hh), y, r)
				line((c, zc + hh), (c, zc - hh), y, r)
			x += step

	def slab(secs, mat, c=0.05, bevel=0.012, y0=None):
		"""Faceted block along x: secs = [(x, zlo, zhi, half_y)], corners
		chamfered by c. y0 shifts it off-centre to a side slab (y0..y0+2*half_y)."""
		pts = []
		for x, z0, z1, hy in secs:
			yc = 0.0 if y0 is None else y0 + hy
			for y, z in ((-hy + c, z0), (hy - c, z0), (hy, z0 + c), (hy, z1 - c), (hy - c, z1), (-hy + c, z1),
					(-hy, z1 - c), (-hy, z0 + c)):
				pts.append((x, yc + y, z))
		return k.hull(B, pts, mat, bevel)

	def rail(x0, x1, zc, h0, h1, w, tip):
		pts = [(x, y, z) for x, h in ((x0, h0), (x1, h1)) for y in (-w / 2, w / 2) for z in (zc - h / 2, zc + h / 2)]
		k.hull(B, pts + [(x1 + tip, 0, zc)], paint, 0.02)

	def pyramid(x, z, s, sy=None):
		sy = s if sy is None else sy
		k.hull(B, [(x - s, -sy, z), (x + s, -sy, z), (x - s, sy, z), (x + s, sy, z), (x, 0, z + s * 1.6)], paint, 0.008)

	# Two obelisks with the beam thread between them.
	w = 0.24
	yz = w / 2 + 0.004
	zu, zl = 0.27, -0.09
	rail(-0.6, 2.05, zu, 0.24, 0.16, w, 0.3)
	rail(-0.6, 1.85, zl, 0.24, 0.16, w, 0.28)
	glyphs(-0.1, 1.85, zu + 0.005, 0.085, yz, 11)
	glyphs(-0.1, 1.65, zl - 0.005, 0.085, yz, 12)
	for zz, x1 in ((zu, 1.95), (zl, 1.75)):
		line((-0.1, zz - 0.085), (x1, zz - 0.055), yz)
	k.cyl(G, (-0.12, 0, 0.09), (2.1, 0, 0.09), 0.03, TEAL, segs=16)
	k.cyl(G, (-0.12, 0, 0.09), (2.12, 0, 0.09), 0.014, HOT, segs=12)
	# Keystones hovering over the upper obelisk.
	for x, s in ((0.3, 0.09), (0.62, 0.07), (0.88, 0.05)):
		pyramid(x, 0.43, s)
	# Receiver: the faceted block both obelisks grow out of, the great eye on
	# its flanks and a capstone hovering over it.
	hr = 0.28
	slab([(-0.96, -0.19, 0.37, hr - 0.05), (-0.84, -0.27, 0.44, hr), (-0.3, -0.27, 0.44, hr), (-0.12, -0.23, 0.4, hr - 0.04)], paint, 0.08)
	ym = hr + 0.004
	eye(-0.52, 0.12, 0.42, 0.19, ym)
	for dx in (-0.1, 0.0, 0.1):
		line((-0.52 + dx, 0.24), (-0.52 + dx * 1.3, 0.32), ym)
	glyphs(-0.8, -0.26, -0.1, 0.08, ym, 13)
	line((-0.8, -0.2), (-0.26, -0.2), ym)
	pyramid(-0.52, 0.48, 0.16, 0.15)
	# Stock: the lying obelisk, split into two cheek slabs the forearm runs
	# between, its underside rising so the grip hand has room.
	yi, yo = 0.24, 0.28
	for s in (1, -1):
		k.prof(B, [(-0.88, -0.15), (-1.32, -0.05), (-1.32, 0.27), (-0.88, 0.35)], s * yi, s * yo, paint, 0.012)
	for z0, z1 in ((0.26, 0.2), (-0.06, 0.03)):
		line((-0.97, z0), (-1.28, z1), yo + 0.004)
	glyphs(-1.24, -0.98, 0.11, 0.075, yo + 0.004, 14)
	# Butt plates hovering behind a glowing seam.
	for s in (1, -1):
		k.box(G, (-1.347, s * (yi + yo) / 2, 0.11), (0.012, yo - yi - 0.01, 0.24), TEAL)
		k.hull(B, [(x, s * y, z) for x, z0, z1 in ((-1.37, -0.1, 0.33), (-1.46, -0.14, 0.37))
			for y in (yi, yo + 0.01) for z in (z0, z1)], trim, 0.012)
	line((-1.415, -0.06), (-1.415, 0.28), yo + 0.014)
	obelisk_grip(k, (-0.56, -0.17), (-0.74, -0.93), -0.31, paint, stripe, TEAL, HOT, groove)


def obelisk_grip(k, a, b, gz, paint, cord, teal, hot, groove):
	"""Inverted-obelisk grip along spine a -> b: faceted, tapering out of the
	receiver, a glowing keystone trigger in a hovering angular bracket, a
	floating pyramidion pommel and two loops of Eco's orange cord. gz = height
	of the bracket's top end."""
	B, G = "Body", "Glow"
	d, n = _spine(a, b)

	def octo(t, hd, hy, c=0.32):
		p = _along(a, b, t)
		return [(p[0] + n[0] * u, v, p[1] + n[1] * u) for u, v in ((hd, hy * (1 - c)), (hd * (1 - c), hy),
			(-hd * (1 - c), hy), (-hd, hy * (1 - c)), (-hd, -hy * (1 - c)), (-hd * (1 - c), -hy), (hd * (1 - c), -hy), (hd, -hy * (1 - c)))]

	def hd_at(t):
		return 0.16 - 0.07 * (t - 0.13) / 0.72

	def hy_at(t):
		return 0.11 - 0.02 * (t - 0.13) / 0.72

	k.hull(B, octo(0.0, 0.17, 0.11) + octo(0.13, 0.16, 0.11) + octo(0.85, 0.09, 0.09), paint, 0.01)
	# Pyramidion pommel hovering under the grip.
	p, q = _along(a, b, 0.885), _along(a, b, 1.04)
	k.hull(B, [(p[0] + n[0] * u, v, p[1] + n[1] * u) for u in (-0.085, 0.085) for v in (-0.085, 0.085)] + [(q[0], 0, q[1])], paint, 0.008)
	# Glyph channel down the flanks.
	groove([_along(a, b, 0.2), _along(a, b, 0.8)], hy_at(0.5) + 0.004)
	for t, L in ((0.3, 0.05), (0.42, 0.035), (0.54, 0.05), (0.66, 0.035)):
		groove([_along(a, b, t, -L), _along(a, b, t, L)], hy_at(t) + 0.004, 0.008)
	# Glowing keystone trigger hovering off the front face.
	tc = _along(a, b, 0.29, hd_at(0.29) + 0.05)
	kp = []
	for s in (-1, 1):
		for u in (-0.028, 0.028):
			for v in (-0.045, 0.045):
				hl = 0.07 - (0.015 if u > 0 else 0)
				kp.append((tc[0] + d[0] * s * hl + n[0] * u, v, tc[1] + d[1] * s * hl + n[1] * u))
	k.hull(G, kp, teal, 0.006)
	groove([(tc[0] - d[0] * 0.05, tc[1] - d[1] * 0.05), (tc[0] + d[0] * 0.05, tc[1] + d[1] * 0.05)], 0.05, 0.01, hot)
	# Open angular bracket guard, hovering, straight facets only.
	br = [(tc[0] + 0.1, gz), (tc[0] + 0.15, tc[1] + 0.02), (tc[0] + 0.12, tc[1] - 0.15),
		(tc[0] + 0.0, tc[1] - 0.205), (tc[0] - 0.08, tc[1] - 0.185)]
	k.sym(B, _ribbon(br, [0.03, 0.05, 0.05, 0.05, 0.03]), 0.1, paint, 0.01)
	groove(br[1:-1], 0.054, 0.008)
	# Eco's touch: a tight wrap of orange cord.
	for t in (0.56, 0.61):
		c = _along(a, b, t)
		r = 0.014
		F, Y = hd_at(t) + 0.004 + r, hy_at(t) + 0.004 + r
		qq = 0.35
		ring = [(F, -Y * (1 - qq)), (F, Y * (1 - qq)), (F * (1 - qq), Y), (-F * (1 - qq), Y),
			(-F, Y * (1 - qq)), (-F, -Y * (1 - qq)), (-F * (1 - qq), -Y), (F * (1 - qq), -Y)]
		k.tube(B, [(c[0] + n[0] * u, v, c[1] + n[1] * u) for u, v in ring], r, cord, closed=True, curved=False)


WEAPONS = {
	"xo16": {"paint": (0.15, 0.16, 0.18), "stripe": (1.0, 0.72, 0.02), "trim": (0.22, 0.23, 0.26)},
	"tracker": {"paint": (0.22, 0.32, 0.17), "stripe": (1.0, 0.4, 0.02)},
	"splitter": {"paint": (0.9, 0.9, 0.88), "stripe": (0.2, 0.75, 0.95), "trim": (0.78, 0.79, 0.8)},
	"scrap": {"paint": (0.36, 0.31, 0.23), "stripe": (1.0, 0.2, 0.02), "trim": (0.64, 0.54, 0.38)},
}


def weapon(id, P):
	paint, stripe = "paint_gun_" + id, "stripe_gun_" + id
	mats = dict(SHARED)
	mats[paint] = P["paint"]
	mats[stripe] = P["stripe"]
	trim = "trim_gun_" + id
	if "trim" in P:
		mats[trim] = P["trim"]
	mats["glass_optic"] = (0.3, 0.78, 0.92)
	kit.reset(mats)
	m = Model()
	if id == "xo16":
		xo16(m, paint, stripe, trim)
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
		splitter(m, paint, stripe, trim)
	else:
		# The pale alloy takes the trim_ finish (clean, satin), the darker
		# butt plates the gun paint's weathered one.
		obelisk_rail(m, trim, stripe, paint)
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
