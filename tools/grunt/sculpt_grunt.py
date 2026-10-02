#!/usr/bin/env python3
"""Sculpts the militia grunt from signed distance fields and saves each part as
.npz (vertices, faces) for build_grunt.py to assemble in Blender. Needs numpy
and scikit-image.

    python3 tools/grunt/sculpt_grunt.py <out_dir> [part ...]

The grunt is drawn the way Eco pictures the men who turned her away: a toy
soldier blown up with his own importance. Barrel chest full of medals, a jaw
like a cinder block, a helmet two sizes too big
pulled down over a glowing visor slit, one fist on his hip. They said worse
than "too frail" to her face, so in her memory they leer: a wide toothy
sneer with a gold tooth and a toothpick, two narrow glowing eyes behind the
visor glass, and they look her up and down (grunt_model.gd).

Their kit is militia-issue future tech: a visor housing with ear pods,
glowing armour seams, a jump pack with twin thrusters and an energy rifle.
Every light is a "Visor*" part, so they all flare red during the shot
wind-up (grunt.gd tints parts by that prefix).

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
from sdf import (V, norm, smin, smax, union, rot, ellipsoid, capsule, round_cone,  # noqa: E402
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


def wrist_pad(P):
    """Wrist computer on the left forearm."""
    el, wr = ELBOW[-1.0], WRIST[-1.0]
    c = el + (wr - el) * 0.62
    ax = norm(wr - el)
    out = norm(np.cross(ax, V(0, 1, 0)))
    if out[0] > 0:
        out = -out
    R = np.column_stack([out, np.cross(ax, out), ax])
    return rbox(P, c + out * 0.05, V(0.018, 0.045, 0.06), R, 0.01)


def wrist_screen(P):
    el, wr = ELBOW[-1.0], WRIST[-1.0]
    c = el + (wr - el) * 0.62
    ax = norm(wr - el)
    out = norm(np.cross(ax, V(0, 1, 0)))
    if out[0] > 0:
        out = -out
    R = np.column_stack([out, np.cross(ax, out), ax])
    return rbox(P, c + out * 0.068, V(0.003, 0.032, 0.042), R, 0.002)


def shin_guard(P, s):
    k, a = KNEE[s], ANKLE[s]
    c = k + (a - k) * 0.45 + V(0, 0.07, 0)
    d = rbox(P, c, V(0.06, 0.025, 0.12), rad=0.022)
    return smax(d, -rbox(P, c + V(0, 0.025, 0), V(0.004, 0.01, 0.13)), 0.004)  # centre ridge


def vest_glow(P):
    """Light strips in the vest seams and round the pauldron rims."""
    shell = np.abs(ellipsoid(P, CHEST_C + V(0, 0.005, 0), CHEST_R + 0.026)) - 0.005
    front = -(P[:, 1] - 0.05)
    centre = np.maximum(np.abs(P[:, 0]) - 0.007, np.maximum(P[:, 2] - 1.38, 1.04 - P[:, 2]))
    seam = np.maximum(np.abs(P[:, 2] - 1.17) - 0.006, np.abs(P[:, 0]) - 0.16)
    d = np.maximum(np.maximum(shell, front), np.minimum(centre, seam))
    for s, _ in SIDES:
        c = SHOULDER[s] + V(s * 0.015, 0, 0.04)
        rim = ring(P, c + V(0, 0, -0.03), None, 0.13, 0.144, 0.004, 0.006)
        d = np.minimum(d, np.maximum(rim, -(P[:, 1] - 0.02)))
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
    """Jump pack."""
    d = rbox(P, V(0, -0.235, 1.25), V(0.155, 0.07, 0.15), rad=0.04)
    for s, _ in SIDES:  # shoulder-height intakes
        d = smin(d, rbox(P, V(s * 0.12, -0.25, 1.39), V(0.04, 0.05, 0.03), rad=0.015), 0.02)
    return d


def thrusters(P):
    d = 1.0
    for s, _ in SIDES:
        a, b = V(s * 0.1, -0.31, 1.25), V(s * 0.1, -0.31, 1.06)
        t = round_cone(P, a, b, 0.04, 0.05)
        t = smax(t, -cylinder(P, b - V(0, 0, 0.01), b + V(0, 0, 0.04), 0.036), 0.004)  # nozzle bell
        d = np.minimum(d, t)
    # whip antenna
    d = np.minimum(d, cylinder(P, V(0.11, -0.27, 1.38), V(0.13, -0.3, 1.72), 0.005))
    return d


def thruster_glow(P):
    d = 1.0
    for s, _ in SIDES:
        d = np.minimum(d, cylinder(P, V(s * 0.1, -0.31, 1.065), V(s * 0.1, -0.31, 1.08), 0.034))
    return np.minimum(d, ellipsoid(P, V(0.13, -0.3, 1.725), V(0.011, 0.011, 0.011)))


def _rifle_frame():
    d_ = RIFLE_DIR
    rear = MUZZLE - d_ * 0.82
    side = norm(np.cross(d_, V(0, 0, 1)))
    up = np.cross(side, d_)
    return d_, rear, side, up, np.column_stack([side, d_, up])


def rifle(P):
    """Energy rifle: slab-sided receiver, shrouded barrel, top rail."""
    d_, rear, side, up, R = _rifle_frame()
    mid = rear + d_ * 0.38
    d = rbox(P, mid, V(0.034, 0.22, 0.052), R, 0.016)                               # receiver
    d = np.minimum(d, rbox(P, mid + d_ * 0.29 + up * 0.012, V(0.028, 0.1, 0.034), R, 0.014))  # shroud
    d = np.minimum(d, cylinder(P, mid + d_ * 0.3, MUZZLE, 0.014))                   # barrel
    d = np.minimum(d, cylinder(P, MUZZLE - d_ * 0.05, MUZZLE, 0.022))               # emitter
    d = np.minimum(d, rbox(P, mid + up * 0.07 - d_ * 0.04, V(0.014, 0.09, 0.016), R, 0.006))  # rail
    d = np.minimum(d, rbox(P, mid + up * 0.1 - d_ * 0.02, V(0.02, 0.03, 0.022), R, 0.008))   # sight body
    return d


def rifle_frame(P):
    d_, rear, side, up, R = _rifle_frame()
    d = rbox(P, rear + d_ * 0.07 - up * 0.01, V(0.024, 0.09, 0.04), R, 0.014)       # stock
    d = smax(d, -rbox(P, rear + d_ * 0.07 - up * 0.01, V(0.03, 0.05, 0.016), R, 0.008), 0.006)  # skeleton cut
    d = np.minimum(d, rbox(P, rear + d_ * 0.27 - up * 0.075, V(0.02, 0.022, 0.05), R @ _rx(15), 0.008))  # grip
    d = np.minimum(d, rbox(P, rear + d_ * 0.47 - up * 0.08, V(0.024, 0.04, 0.05), R @ _rx(-10), 0.01))  # cell well
    return d


def rifle_glow(P):
    """Energy cell window and holo sight."""
    d_, rear, side, up, R = _rifle_frame()
    mid = rear + d_ * 0.38
    d = rbox(P, mid + side * 0.033 + d_ * 0.05, V(0.006, 0.09, 0.012), R, 0.004)
    d = np.minimum(d, rbox(P, mid - side * 0.033 + d_ * 0.05, V(0.006, 0.09, 0.012), R, 0.004))
    return np.minimum(d, rbox(P, mid + up * 0.135 - d_ * 0.02, V(0.016, 0.003, 0.014), R, 0.002))


def _rx(deg):
    a = np.radians(deg)
    return np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])


# --- head (tilts back, smug) ------------------------------------------------------

def _face(P):
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


def head_skin(P):
    """Face with the leering grin cut into it."""
    return smax(_face(P), -_grin(P), 0.004)


GRIN_C = V(0.0, 0.15, 1.562)
GRIN_R = rot(V(0, 1, 0), -9)  # lopsided: higher on his right


def _grin(P):
    """Wide crescent grin, thick in the middle and pulled up at the corners."""
    low = ellipsoid(P, GRIN_C, V(0.066, 0.06, 0.027), GRIN_R)
    top = ellipsoid(P, GRIN_C + GRIN_R @ V(0, 0, 0.034), V(0.085, 0.09, 0.036), GRIN_R)
    return smax(low, -top, 0.004)


def mouth(P):
    """Dark mouth behind the teeth."""
    return ellipsoid(P, GRIN_C + V(0, -0.045, 0.0), V(0.062, 0.03, 0.028), GRIN_R)


def _teeth_row(P):
    d = ellipsoid(P, GRIN_C + V(0, -0.024, 0.006), V(0.058, 0.03, 0.022), GRIN_R)
    d = np.maximum(d, -(P[:, 2] - (GRIN_C[2] - 0.006 + P[:, 0] * np.tan(np.radians(9)))))  # upper row only
    gap = np.abs(((P[:, 0] + 0.008) / 0.016) % 1.0 - 0.5) * 0.016 - 0.0065
    return smax(d, gap, 0.0015)


def teeth(P):
    return np.maximum(_teeth_row(P), -np.maximum(P[:, 0] - 0.032, 0.016 - P[:, 0]))


def gold_tooth(P):
    return np.maximum(_teeth_row(P) - 0.0005, np.maximum(P[:, 0] - 0.032, 0.016 - P[:, 0]))


def face_point(x, z, out=0.0):
    """Point on the front of the face at (x, z), pushed `out` metres forward."""
    lo, hi = 0.0, 0.3
    for _ in range(40):
        mid = (lo + hi) / 2
        if _face(V(x, mid, z)[None])[0] < 0:
            lo = mid
        else:
            hi = mid
    return V(x, lo + out, z)


def stubble(P):
    """Five o'clock shadow on the jaw."""
    d = _face(P) - 0.004
    d = smax(d, -_grin(P) - 0.004, 0.004)
    region = np.maximum(P[:, 2] - 1.55, 1.47 - P[:, 2])
    region = smax(region, -(P[:, 1] - 0.0), 0.02)
    return np.maximum(d, region)


def helmet(P):
    """Two sizes too big: a tech dome with a visor housing and ear pods."""
    c = HEAD_C + V(0, -0.005, 0.045)
    dome = ellipsoid(P, c, V(0.19, 0.205, 0.17))
    dome = smax(dome, plane(P, V(0, 0, 1.6), V(0, 0, -1)), 0.01)
    housing = ellipsoid(P, V(0, 0.02, 1.64), V(0.158, 0.172, 0.06))
    housing = smax(housing, plane(P, V(0, 0, 1.602), V(0, 0, -1)), 0.006)
    d = smin(dome, housing, 0.02)
    d = smax(d, -np.maximum(np.abs(P[:, 2] - 1.628) - 0.02, -(P[:, 1] - 0.03)), 0.006)  # visor slot
    d = smin(d, ellipsoid(P, c + V(0, -0.03, 0.15), V(0.035, 0.14, 0.035)), 0.03)  # crest
    for s, _ in SIDES:
        d = smin(d, cylinder(P, V(s * 0.15, -0.005, 1.63), V(s * 0.2, -0.005, 1.63), 0.05), 0.012)
    # antenna fin over his left ear
    fin = rbox(P, V(-0.19, -0.05, 1.69), V(0.006, 0.03, 0.06), rot(V(1, 0, 0), -25), 0.005)
    return smin(d, fin, 0.01)


def helmet_band(P):
    return ring(P, V(0, -0.005, 1.67), None, 0.19, 0.205, 0.007, 0.012)


def visor(P):
    """Dark visor glass in the housing slot (grunt.gd tints its glow)."""
    d = ellipsoid(P, V(0, 0.012, 1.628), V(0.14, 0.152, 0.12))
    d = np.maximum(d, np.abs(P[:, 2] - 1.628) - 0.019)
    return np.maximum(d, -(P[:, 1] - 0.0))


def _eye_centres():
    out = []
    for s in (1.0, -1.0):
        x = s * 0.046
        y = 0.012 + 0.152 * np.sqrt(1 - (x / 0.14) ** 2) + 0.001
        out.append((s, V(x, y, 1.627)))
    return out


def visor_eyes(P):
    """Two narrow glowing eyes behind the glass, squinting in a leer."""
    d = 1.0
    for s, c in _eye_centres():
        R = rot(V(0, 1, 0), s * 12) @ rot(V(0, 0, 1), s * 14)  # outer corners droop
        d = np.minimum(d, ellipsoid(P, c, V(0.027, 0.006, 0.0052), R))
    return d


def visor_lights(P):
    """Status lights on the ear pods."""
    d = 1.0
    for s, _ in SIDES:
        d = np.minimum(d, cylinder(P, V(s * 0.2, -0.005, 1.63), V(s * 0.204, -0.005, 1.63), 0.022))
    return d


def straps_chin(P):
    d = 1.0
    for s, _ in SIDES:  # unbuckled, hanging loose
        d = np.minimum(d, capsule(P, V(s * 0.155, 0.0, 1.665), V(s * 0.125, 0.04, 1.53), 0.007))
    return d


def toothpick(P):
    a = GRIN_C + V(0.058, -0.004, 0.012)
    return capsule(P, a, a + norm(V(0.55, 1.0, -0.25)) * 0.075, 0.0032)


# --- parts table -----------------------------------------------------------------
# name: (segment, material, sdf, voxel size, target triangles)

PARTS = {}
for s, side in SIDES:
    PARTS[f"thigh_{side}"] = ("Thigh" + side, "grunt_uniform", lambda P, s=s: thigh(P, s), 0.006, 900)
    PARTS[f"shin_{side}"] = ("Shin" + side, "grunt_uniform", lambda P, s=s: shin(P, s), 0.006, 700)
    PARTS[f"kneepad_{side}"] = ("Shin" + side, "grunt_armor", lambda P, s=s: knee_pad(P, s), 0.004, 300)
    PARTS[f"boot_{side}"] = ("Shin" + side, "grunt_leather", lambda P, s=s: boot(P, s), 0.005, 900)
    PARTS[f"sole_{side}"] = ("Shin" + side, "grunt_dark", lambda P, s=s: sole(P, s), 0.005, 300)
    PARTS[f"shinguard_{side}"] = ("Shin" + side, "grunt_metal", lambda P, s=s: shin_guard(P, s), 0.004, 400)
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
    "pack": ("Torso", "grunt_armor", pack, 0.005, 900),
    "thrusters": ("Torso", "grunt_metal", thrusters, 0.004, 900),
    "visor_thrust": ("Torso", "grunt_visor", thruster_glow, 0.003, 200),
    "visor_trim": ("Torso", "grunt_visor", vest_glow, 0.003, 1200),
    "wrist_pad": ("Torso", "grunt_metal", wrist_pad, 0.003, 300),
    "visor_screen": ("Torso", "grunt_visor", wrist_screen, 0.002, 100),
    "rifle": ("Torso", "grunt_metal", rifle, 0.004, 1200),
    "rifle_frame": ("Torso", "grunt_dark", rifle_frame, 0.004, 600),
    "visor_cell": ("Torso", "grunt_visor", rifle_glow, 0.0025, 200),
    "head": ("Head", "grunt_skin", head_skin, 0.0035, 2400),
    "stubble": ("Head", "grunt_stubble", stubble, 0.003, 2400),
    "mouth": ("Head", "grunt_dark", mouth, 0.003, 300),
    "teeth": ("Head", "grunt_teeth", teeth, 0.0015, 900),
    "gold_tooth": ("Head", "grunt_brass", gold_tooth, 0.0015, 150),
    "helmet": ("Head", "grunt_armor", helmet, 0.0035, 3000),
    "helmet_band": ("Head", "grunt_dark", helmet_band, 0.003, 500),
    "visor": ("Head", "grunt_glass", visor, 0.003, 500),
    "visor_eyes": ("Head", "grunt_visor", visor_eyes, 0.0015, 300),
    "visor_lights": ("Head", "grunt_visor", visor_lights, 0.002, 150),
    "chinstraps": ("Head", "grunt_leather", straps_chin, 0.003, 200),
    "toothpick": ("Head", "grunt_cigar", toothpick, 0.0012, 120),
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
