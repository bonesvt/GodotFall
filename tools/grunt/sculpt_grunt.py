#!/usr/bin/env python3
"""Sculpts the militia grunt from signed distance fields and saves each part as
.npz (vertices, faces) for build_grunt.py to assemble in Blender. Needs numpy
and scikit-image.

    python3 tools/grunt/sculpt_grunt.py <out_dir> [part ...]

The grunt is drawn the way Eco pictures the men who turned her away: a toy
soldier blown up with his own importance. Barrel chest full of medals, a jaw
like a cinder block with a cigar in the smirk, a helmet two sizes too big
pulled down over a glowing visor slit, one fist on his hip.

Blender axes, metres: Z up, he faces +Y, his right is +X, feet at Z=0. He is
a rigid-part puppet (PS2 action figure), so every part belongs to one segment
that the game moves as a whole (see SEGMENTS in build_grunt.py). Overall size
stays inside grunt.gd's hit capsule (0.35 m radius, 1.8 m tall) with the head
above the 1.5 m headshot line."""
import sys
import time
from pathlib import Path

import numpy as np
from skimage import measure

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sdf import (V, norm, smin, smax, union, ellipsoid, capsule, round_cone,  # noqa: E402
                 rbox, cylinder, ring, plane)

SIDES = ((1.0, "R"), (-1.0, "L"))

# Joints. Pivots for the segments live in build_grunt.py and match these.
HIP = {s: V(s * 0.125, 0.0, 0.86) for s, _ in SIDES}
KNEE = {s: V(s * 0.135, 0.02, 0.48) for s, _ in SIDES}
ANKLE = {s: V(s * 0.145, -0.01, 0.13) for s, _ in SIDES}
SHOULDER = {s: V(s * 0.3, -0.01, 1.39) for s, _ in SIDES}
# Right arm holds the rifle at the hip, left fist planted on the belt.
ELBOW = {1.0: V(0.37, -0.1, 1.15), -1.0: V(-0.47, -0.07, 1.17)}
WRIST = {1.0: V(0.31, 0.05, 1.07), -1.0: V(-0.29, 0.0, 1.03)}
FIST = {1.0: V(0.3, 0.1, 1.06), -1.0: V(-0.255, 0.01, 1.01)}
# Rifle: muzzle sits at grunt.gd MUZZLE (Godot 0.3, 1.2, -0.6).
MUZZLE = V(0.3, 0.6, 1.2)
RIFLE_DIR = norm(V(0.0, 1.0, 0.09))
CHEST_C, CHEST_R = V(0.0, 0.025, 1.25), V(0.245, 0.175, 0.215)
HEAD_C = V(0.0, 0.0, 1.63)


# --- legs (one segment per thigh and per shin) ---------------------------------

def thigh(P, s):
    d = round_cone(P, HIP[s], KNEE[s], 0.115, 0.085)
    d = smin(d, ellipsoid(P, V(s * 0.135, 0.01, 0.7), V(0.105, 0.1, 0.15)), 0.04)
    # cargo pocket on the outside of the thigh
    d = smin(d, rbox(P, V(s * 0.225, 0.01, 0.67), V(0.028, 0.07, 0.075), rad=0.018), 0.01)
    return d


def shin(P, s):
    d = round_cone(P, KNEE[s], ANKLE[s] + V(0, 0, 0.12), 0.083, 0.07)
    # trousers bloused over the boot tops
    d = smin(d, ellipsoid(P, ANKLE[s] + V(0, 0, 0.17), V(0.085, 0.085, 0.05)), 0.03)
    return d


def knee_pad(P, s):
    c = KNEE[s] + V(0, 0.075, -0.01)
    d = rbox(P, c, V(0.07, 0.03, 0.075), rad=0.028)
    return smax(d, -rbox(P, c + V(0, 0.03, 0), V(0.08, 0.004, 0.006)), 0.004)  # ridge


def boot(P, s):
    a = ANKLE[s]
    d = rbox(P, V(a[0], 0.05, 0.075), V(0.085, 0.165, 0.07), rad=0.055)
    d = smin(d, cylinder(P, a - V(0, 0, 0.05), a + V(0, 0, 0.14), 0.088), 0.04)
    d = smin(d, ellipsoid(P, V(a[0], 0.15, 0.07), V(0.085, 0.08, 0.07)), 0.03)  # toe cap
    return smax(d, plane(P, V(0, 0, 0.035), V(0, 0, -1)), 0.0)


def sole(P, s):
    a = ANKLE[s]
    return rbox(P, V(a[0], 0.055, 0.025), V(0.092, 0.18, 0.026), rad=0.02)


def lace_strap(P, s):
    a = ANKLE[s]
    d = 1.0
    for z in (0.15, 0.21):
        d = np.minimum(d, ring(P, V(a[0], a[1], z), None, 0.093, 0.093, 0.006, 0.012))
    return d


# --- hips (static) --------------------------------------------------------------

def pelvis(P):
    d = ellipsoid(P, V(0, -0.01, 0.9), V(0.215, 0.15, 0.125))
    for s, _ in SIDES:
        d = smin(d, round_cone(P, V(s * 0.12, 0, 0.92), HIP[s], 0.12, 0.115), 0.04)
    return d


def belt(P):
    return ring(P, V(0, 0.005, 0.975), None, 0.225, 0.16, 0.02, 0.035)


def buckle(P):
    d = rbox(P, V(0, 0.17, 0.975), V(0.055, 0.016, 0.04), rad=0.01)
    return smax(d, -rbox(P, V(0, 0.188, 0.975), V(0.035, 0.008, 0.022)), 0.003)


# --- torso (sways and puffs up as one piece) -------------------------------------

def chest_body(P, grow=0.0):
    d = ellipsoid(P, CHEST_C, CHEST_R + grow)
    d = smin(d, ellipsoid(P, V(0, 0.035, 1.05), V(0.2, 0.16, 0.12) + grow), 0.06)
    d = smin(d, capsule(P, SHOULDER[-1.0] + V(0.04, 0, 0), SHOULDER[1.0] - V(0.04, 0, 0), 0.105 + grow), 0.07)
    return d


def tunic(P):
    d = chest_body(P)
    d = smin(d, round_cone(P, V(0, -0.01, 1.4), V(0, 0.0, 1.47), 0.12, 0.112), 0.03)  # collar
    for s, _ in SIDES:  # sleeves, rolled up above the elbow
        sh, el = SHOULDER[s], ELBOW[s]
        cuff = sh + (el - sh) * 0.78
        d = smin(d, ellipsoid(P, sh + (el - sh) * 0.35, V(0.1, 0.1, 0.13)), 0.05)
        d = smin(d, round_cone(P, sh, cuff, 0.1, 0.082), 0.04)
        d = smin(d, round_cone(P, cuff, cuff + norm(el - sh) * 0.035, 0.092, 0.09), 0.01)
    return d


def forearms(P):
    """Popeye forearms, sleeves rolled to show them off."""
    d = 1.0
    for s, _ in SIDES:
        el, wr = ELBOW[s], WRIST[s]
        d = np.minimum(d, smin(round_cone(P, el, wr, 0.07, 0.052),
                               ellipsoid(P, el + (wr - el) * 0.38, V(0.074, 0.074, 0.074)), 0.04))
    return d


def gloves(P):
    d = 1.0
    for s, _ in SIDES:
        f = FIST[s]
        g = ellipsoid(P, f, V(0.058, 0.058, 0.062))
        g = smin(g, round_cone(P, WRIST[s], f, 0.054, 0.05), 0.02)
        for i in range(4):  # knuckles
            k = f + V(s * 0.04, (i - 1.5) * 0.023, 0.012)
            g = smin(g, ellipsoid(P, k, V(0.015, 0.015, 0.015)), 0.012)
        d = np.minimum(d, g)
    return d


def vest(P):
    """Armour vest over the barrel chest, with plate seams."""
    d = smin(ellipsoid(P, CHEST_C + V(0, 0.005, 0), CHEST_R + 0.03),
             ellipsoid(P, V(0, 0.035, 1.07), V(0.215, 0.18, 0.1)), 0.05)
    d = smax(d, plane(P, V(0, 0, 1.0), V(0, 0, -1)), 0.02)
    d = smax(d, plane(P, V(0, 0, 1.43), V(0, 0, 1)), 0.03)
    d = smax(d, -cylinder(P, V(0, 0, 1.3), V(0, 0, 1.6), 0.12), 0.03)  # neck hole
    for z in (1.17, 1.07):  # horizontal plate seams
        d = smax(d, -ring(P, V(0, 0.03, z), None, 0.3, 0.23, 0.08, 0.006), 0.006)
    d = smax(d, -rbox(P, V(0, 0.25, 1.25), V(0.006, 0.05, 0.2)), 0.006)  # centre seam
    return d


def pauldrons(P):
    d = 1.0
    for s, _ in SIDES:
        c = SHOULDER[s] + V(s * 0.015, 0, 0.04)
        p = ellipsoid(P, c, V(0.12, 0.135, 0.095))
        p = smax(p, plane(P, c + V(0, 0, -0.035), V(0, 0, -1)), 0.01)
        p = smin(p, ellipsoid(P, c + V(0, 0, -0.03), V(0.128, 0.142, 0.018)), 0.01)  # rolled rim
        d = np.minimum(d, p)
    return d


def chevrons(P):
    """Sergeant's stripes on the right pauldron: three V bands."""
    c = SHOULDER[1.0] + V(0.015, 0, 0.04)
    shell = np.abs(ellipsoid(P, c, V(0.125, 0.14, 0.1))) - 0.005
    side = plane(P, c + V(0.06, 0, 0), V(-1, 0, 0))  # outer face only
    y = P[:, 1] - c[1]
    d = 1.0
    for k in range(3):
        zc = c[2] - 0.005 + k * 0.022 - np.abs(y) * 0.5
        d = np.minimum(d, np.abs(P[:, 2] - zc) - 0.006)
    return np.maximum(np.maximum(shell, side), np.maximum(d, np.abs(y) - 0.075))


def _vest_front(x, z):
    """Point on the vest's front surface."""
    c, r = CHEST_C + V(0, 0.005, 0), CHEST_R + 0.03
    t = 1 - ((x - c[0]) / r[0]) ** 2 - ((z - c[2]) / r[2]) ** 2
    return V(x, c[1] + r[1] * np.sqrt(max(t, 0.0)), z)


def medals(P):
    d = 1.0
    for i, x in enumerate((-0.17, -0.12, -0.07)):
        p = _vest_front(x, 1.27)
        disc = cylinder(P, p - V(0, 0.006, 0), p + V(0, 0.012, 0), 0.02)
        disc = smax(disc, -cylinder(P, p + V(0, 0.01, 0), p + V(0, 0.02, 0), 0.011), 0.003)
        d = np.minimum(d, disc)
    p = _vest_front(-0.12, 1.33)  # ribbon pins
    return np.minimum(d, rbox(P, p + V(0, 0.004, 0), V(0.08, 0.008, 0.008), rad=0.003))


def ribbons(P):
    d = 1.0
    for x in (-0.17, -0.12, -0.07):
        p = _vest_front(x, 1.305)
        d = np.minimum(d, rbox(P, p + V(0, 0.002, 0), V(0.016, 0.008, 0.024), rad=0.003))
    p = _vest_front(-0.12, 1.36)
    return np.minimum(d, rbox(P, p, V(0.075, 0.012, 0.018), rad=0.004))


def pouches(P):
    """Ammo pouches hanging off the front of the belt."""
    d = 1.0
    for x in (-0.13, 0.13, 0.19):
        y = 0.005 + 0.16 * np.sqrt(1 - (x / 0.225) ** 2) + 0.03
        d = np.minimum(d, rbox(P, V(x, y, 0.955), V(0.04, 0.03, 0.05), rad=0.012))
        d = np.minimum(d, rbox(P, V(x, y + 0.012, 0.995), V(0.043, 0.024, 0.012), rad=0.006))  # flap
    return d


def straps(P):
    """Webbing over the shoulders down to the belt."""
    d = 1.0
    for s, _ in SIDES:
        a, b = V(s * 0.13, 0.13, 0.99), V(s * 0.17, 0.0, 1.45)
        c = V(s * 0.15, -0.21, 1.1)
        d = np.minimum(d, capsule(P, a, b, 0.018))
        d = np.minimum(d, capsule(P, b, c, 0.018))
    return d


def pack(P):
    d = rbox(P, V(0, -0.24, 1.24), V(0.17, 0.075, 0.16), rad=0.045)
    return smin(d, rbox(P, V(0, -0.235, 1.07), V(0.19, 0.06, 0.04), rad=0.03), 0.02)  # bedroll


def radio(P):
    d = rbox(P, V(0.09, -0.32, 1.33), V(0.06, 0.035, 0.09), rad=0.015)
    d = np.minimum(d, cylinder(P, V(0.12, -0.33, 1.4), V(0.13, -0.34, 1.82), 0.006))
    return np.minimum(d, ellipsoid(P, V(0.13, -0.34, 1.82), V(0.012, 0.012, 0.012)))


def rifle(P):
    d_ = RIFLE_DIR
    rear = MUZZLE - d_ * 0.82
    side = norm(np.cross(d_, V(0, 0, 1)))
    up = np.cross(side, d_)
    R = np.column_stack([side, d_, up])
    mid = rear + d_ * 0.36
    d = rbox(P, mid, V(0.032, 0.2, 0.05), R, 0.01)                              # receiver
    d = np.minimum(d, cylinder(P, mid + d_ * 0.18 + up * 0.015, MUZZLE, 0.016))   # barrel
    d = np.minimum(d, cylinder(P, MUZZLE - d_ * 0.04, MUZZLE, 0.024))             # muzzle brake
    d = np.minimum(d, rbox(P, mid + up * 0.07 - d_ * 0.02, V(0.012, 0.07, 0.02), R, 0.006))  # sight rail
    mag = mid + d_ * 0.08 - up * 0.1
    d = np.minimum(d, rbox(P, mag, V(0.022, 0.035, 0.07), R @ _rx(-15), 0.008))
    return d


def rifle_wood(P):
    d_ = RIFLE_DIR
    rear = MUZZLE - d_ * 0.82
    side = norm(np.cross(d_, V(0, 0, 1)))
    up = np.cross(side, d_)
    R = np.column_stack([side, d_, up])
    d = rbox(P, rear + d_ * 0.07 - up * 0.02, V(0.026, 0.09, 0.045), R, 0.012)      # stock
    d = np.minimum(d, rbox(P, rear + d_ * 0.63 + up * 0.0, V(0.03, 0.1, 0.035), R, 0.012))  # handguard
    d = np.minimum(d, rbox(P, rear + d_ * 0.26 - up * 0.07, V(0.02, 0.022, 0.05), R @ _rx(15), 0.008))  # grip
    return d


def _rx(deg):
    a = np.radians(deg)
    return np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])


# --- head (tilts back, smug) ------------------------------------------------------

def head_skin(P):
    neck = round_cone(P, V(0, -0.01, 1.42), V(0, 0.0, 1.56), 0.098, 0.088)   # bull neck
    skull = ellipsoid(P, HEAD_C, V(0.108, 0.118, 0.12))
    jaw = rbox(P, V(0, 0.06, 1.545), V(0.108, 0.085, 0.058), rad=0.048)        # cinder-block jaw
    chin = ellipsoid(P, V(0, 0.13, 1.515), V(0.085, 0.06, 0.052))
    d = smin(smin(skull, jaw, 0.04), chin, 0.03)
    d = smin(d, neck, 0.04)
    d = smin(d, ellipsoid(P, V(0, 0.125, 1.612), V(0.027, 0.034, 0.034)), 0.012)  # blunt nose
    for s, _ in SIDES:
        d = smin(d, ellipsoid(P, V(s * 0.108, 0.0, 1.605), V(0.02, 0.032, 0.04)), 0.01)  # ears
        d = smin(d, ellipsoid(P, V(s * 0.07, 0.1, 1.555), V(0.045, 0.04, 0.035)), 0.03)   # jowls
    return d


def face_point(x, z, out=0.0):
    """Point on the front of the face at (x, z), pushed `out` metres forward."""
    lo, hi = 0.0, 0.3
    for _ in range(40):
        mid = (lo + hi) / 2
        if head_skin(V(x, mid, z)[None])[0] < 0:
            lo = mid
        else:
            hi = mid
    return V(x, lo + out, z)


def _smirk():
    """Lopsided smirk, rising to his right where the cigar sits."""
    return [face_point(x, z, -0.002) for x, z in
            ((-0.055, 1.566), (-0.025, 1.561), (0.0, 1.561), (0.025, 1.566), (0.05, 1.578))]


def mouth(P):
    pts = _smirk()
    d = 1.0
    for a, b in zip(pts, pts[1:]):
        d = np.minimum(d, capsule(P, a, b, 0.0055))
    c = face_point(0.0, 1.5, -0.003)  # cleft chin
    return np.minimum(d, capsule(P, c, c + V(0, 0.0, 0.035), 0.004))


def stubble(P):
    """Five o'clock shadow on the jaw."""
    d = head_skin(P) - 0.006
    region = np.maximum(P[:, 2] - 1.548, 1.47 - P[:, 2])
    region = smax(region, -(P[:, 1] - 0.0), 0.02)
    return np.maximum(d, region)


def helmet(P):
    """Two sizes too big and pulled down to the eyes."""
    c = HEAD_C + V(0, -0.005, 0.045)
    dome = ellipsoid(P, c, V(0.185, 0.2, 0.165))
    dome = smax(dome, plane(P, V(0, 0, 1.66), V(0, 0, -1)), 0.01)
    brim = ellipsoid(P, V(0, 0.03, 1.665), V(0.215, 0.25, 0.02))
    d = smin(dome, brim, 0.02)
    d = smin(d, ellipsoid(P, c + V(0, 0, 0.15), V(0.05, 0.13, 0.03)), 0.04)  # crest ridge
    return d


def helmet_band(P):
    return ring(P, V(0, -0.005, 1.7), None, 0.186, 0.2, 0.008, 0.016)


def visor(P):
    """Glowing slit across the eyes under the brim (grunt.gd tints it)."""
    d = ellipsoid(P, V(0, 0.01, 1.625), V(0.122, 0.135, 0.12))
    d = np.maximum(d, np.abs(P[:, 2] - 1.627) - 0.016)
    return np.maximum(d, -(P[:, 1] - 0.03))


def straps_chin(P):
    d = 1.0
    for s, _ in SIDES:  # unbuckled, hanging loose
        d = np.minimum(d, capsule(P, V(s * 0.155, 0.0, 1.665), V(s * 0.125, 0.04, 1.53), 0.007))
    return d


def _cigar_ends():
    a = face_point(0.04, 1.574, -0.01)
    return a, a + norm(V(0.4, 1.0, -0.12)) * 0.1


def cigar(P):
    a, b = _cigar_ends()
    return round_cone(P, a, b, 0.011, 0.012)


def ember(P):
    a, b = _cigar_ends()
    return ellipsoid(P, b + norm(b - a) * 0.004, V(0.012, 0.012, 0.012))


# --- parts table -----------------------------------------------------------------
# name: (segment, material, sdf, voxel size, target triangles)

PARTS = {}
for s, side in SIDES:
    PARTS[f"thigh_{side}"] = ("Thigh" + side, "grunt_uniform", lambda P, s=s: thigh(P, s), 0.006, 900)
    PARTS[f"shin_{side}"] = ("Shin" + side, "grunt_uniform", lambda P, s=s: shin(P, s), 0.006, 700)
    PARTS[f"kneepad_{side}"] = ("Shin" + side, "grunt_armor", lambda P, s=s: knee_pad(P, s), 0.004, 300)
    PARTS[f"boot_{side}"] = ("Shin" + side, "grunt_leather", lambda P, s=s: boot(P, s), 0.005, 900)
    PARTS[f"sole_{side}"] = ("Shin" + side, "grunt_dark", lambda P, s=s: sole(P, s), 0.005, 300)
    PARTS[f"laces_{side}"] = ("Shin" + side, "grunt_dark", lambda P, s=s: lace_strap(P, s), 0.004, 300)
PARTS.update({
    "pelvis": ("Hips", "grunt_uniform", pelvis, 0.006, 900),
    "belt": ("Hips", "grunt_leather", belt, 0.004, 600),
    "buckle": ("Hips", "grunt_brass", buckle, 0.003, 200),
    "tunic": ("Torso", "grunt_uniform", tunic, 0.006, 2600),
    "forearms": ("Torso", "grunt_skin", forearms, 0.005, 900),
    "gloves": ("Torso", "grunt_leather", gloves, 0.004, 900),
    "vest": ("Torso", "grunt_armor", vest, 0.005, 2200),
    "pauldrons": ("Torso", "grunt_armor", pauldrons, 0.005, 1000),
    "chevrons": ("Torso", "grunt_brass", chevrons, 0.003, 500),
    "medals": ("Torso", "grunt_brass", medals, 0.0025, 500),
    "ribbons": ("Torso", "grunt_ribbon", ribbons, 0.0025, 300),
    "pouches": ("Hips", "grunt_leather", pouches, 0.004, 500),
    "straps": ("Torso", "grunt_dark", straps, 0.004, 600),
    "pack": ("Torso", "grunt_uniform", pack, 0.006, 700),
    "radio": ("Torso", "grunt_metal", radio, 0.004, 400),
    "rifle": ("Torso", "grunt_metal", rifle, 0.004, 900),
    "rifle_wood": ("Torso", "grunt_dark", rifle_wood, 0.004, 500),
    "head": ("Head", "grunt_skin", head_skin, 0.0035, 2400),
    "stubble": ("Head", "grunt_stubble", stubble, 0.003, 2400),
    "mouth": ("Head", "grunt_dark", mouth, 0.002, 400),
    "helmet": ("Head", "grunt_armor", helmet, 0.004, 1600),
    "helmet_band": ("Head", "grunt_dark", helmet_band, 0.003, 500),
    "visor": ("Head", "grunt_visor", visor, 0.003, 400),
    "chinstraps": ("Head", "grunt_leather", straps_chin, 0.003, 200),
    "cigar": ("Head", "grunt_cigar", cigar, 0.0025, 200),
    "ember": ("Head", "grunt_ember", ember, 0.002, 80),
})

BOUNDS = (V(-0.62, -0.45, -0.02), V(0.62, 0.72, 1.92))


def _bbox(fn, pad=0.03, step=0.02):
    """Where the shape is, from a coarse sample of the whole character box."""
    lo, hi = BOUNDS
    axes = [np.arange(lo[i], hi[i], step) for i in range(3)]
    G = np.stack(np.meshgrid(*axes, indexing="ij"), -1).reshape(-1, 3)
    inside = G[fn(G) < step]
    if len(inside) == 0:
        raise ValueError("empty part")
    return inside.min(0) - pad, inside.max(0) + pad


def mesh_part(fn, lo, hi, res):
    n = np.ceil((hi - lo) / res).astype(int) + 1
    xs, ys, zs = (lo[i] + np.arange(n[i]) * res for i in range(3))
    vol = np.empty(tuple(n), dtype=np.float32)
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    chunk = max(1, 2_000_000 // (n[0] * n[1]))
    for k0 in range(0, n[2], chunk):
        k1 = min(n[2], k0 + chunk)
        Z = zs[k0:k1]
        P = np.stack([np.repeat(X[..., None], len(Z), 2), np.repeat(Y[..., None], len(Z), 2),
                      np.broadcast_to(Z, (n[0], n[1], len(Z)))], -1).reshape(-1, 3)
        vol[:, :, k0:k1] = fn(P).reshape(n[0], n[1], len(Z))
    vol[0], vol[-1], vol[:, 0], vol[:, -1], vol[:, :, 0], vol[:, :, -1] = (1.0,) * 6
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(res, res, res))
    return verts + lo, faces


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    only = sys.argv[2:]
    for name, (seg, mat, fn, res, tris) in PARTS.items():
        if only and name not in only:
            continue
        t = time.time()
        lo, hi = _bbox(fn)
        v, f = mesh_part(fn, lo, hi, res)
        np.savez(out / f"{name}.npz", verts=v, faces=f, target=tris, segment=seg, material=mat)
        print(f"{name}: {len(v)} verts {len(f)} faces ({time.time() - t:.1f}s)", flush=True)


if __name__ == "__main__":
    main()
