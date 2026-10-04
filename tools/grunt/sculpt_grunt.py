#!/usr/bin/env python3
"""Sculpts the colony grunt from signed distance fields and saves each part as
.npz (vertices, faces) for build_grunt.py to assemble in Blender. Needs numpy
and scikit-image.

    python3 tools/grunt/sculpt_grunt.py <out_dir> [part ...]

The grunt is a soldier of the future the way Eco remembers the men who
laughed her out of the recruiting office: a crass, vain bully in showy power
armour. Chrome muscle cuirass with a gold chain over it, huge stacked
pauldrons, a closed helmet whose LED face display leers at you (half-lidded
eyes, one brow cocked, a lopsided grin, a wink, a kiss, a tongue, a laugh),
and a free left hand with three shapes (point, fist, middle finger) for the
crude taunts grunt_model.gd plays.

Every light is a "Visor*" part: grunt.gd tints all of them, so the whole
display and every glow strip flares red during the shot wind-up.

Blender axes, metres: Z up, he faces +Y, his right is +X, feet at Z=0. He is
a rigid-part puppet (PS2 action figure): every part belongs to one segment
that the game moves as a whole (pivots in build_grunt.py). He stays inside
grunt.gd's hit capsule (0.35 m radius, 1.8 m tall) apart from the pauldron
tips, with the head above the 1.5 m headshot line."""
import sys
import time
from pathlib import Path

import numpy as np
from skimage import measure

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sdf import (V, norm, smin, smax, rot, ellipsoid, capsule, round_cone,  # noqa: E402
                 rbox, cylinder, ring, plane)

SIDES = ((1.0, "R"), (-1.0, "L"))

# Joints. Segment pivots in build_grunt.py match these.
HIP = {s: V(s * 0.115, 0.0, 0.88) for s, _ in SIDES}
KNEE = {s: V(s * 0.125, 0.03, 0.49) for s, _ in SIDES}
ANKLE = {s: V(s * 0.135, -0.01, 0.12) for s, _ in SIDES}
SHOULDER = {s: V(s * 0.25, -0.01, 1.4) for s, _ in SIDES}
# Right hand holds the rifle at the hip; the left hangs loose, finger out.
ELBOW = {1.0: V(0.35, -0.09, 1.16), -1.0: V(-0.33, -0.02, 1.15)}
WRIST = {1.0: V(0.31, 0.05, 1.07), -1.0: V(-0.34, 0.06, 0.93)}
HAND = {1.0: V(0.3, 0.1, 1.06), -1.0: V(-0.34, 0.09, 0.88)}
POINT_DIR = norm(V(0.05, 0.55, -0.83))  # left index finger
MUZZLE = V(0.3, 0.6, 1.2)  # grunt.gd MUZZLE (Godot 0.3, 1.2, -0.6)
RIFLE_DIR = norm(V(0.0, 1.0, 0.09))
CHEST_C, CHEST_R = V(0.0, 0.01, 1.27), V(0.19, 0.13, 0.165)
HEAD_C = V(0.0, 0.0, 1.63)
DISPLAY_C, DISPLAY_H = V(0.0, 0.125, 1.6), V(0.088, 0.02, 0.072)
LED_Y = DISPLAY_C[1] + DISPLAY_H[1]  # front face of the display


def _frame(axis, hint=V(0, 0, 1)):
    """Rotation whose second column (local Y) is `axis`."""
    y = norm(axis)
    x = norm(np.cross(y, hint))
    return np.column_stack([x, y, np.cross(x, y)])


# --- legs: thigh segments and shin segments ----------------------------------------

def thigh(P, s):
    d = round_cone(P, HIP[s], KNEE[s], 0.105, 0.075)
    return smin(d, ellipsoid(P, V(s * 0.125, 0.0, 0.72), V(0.09, 0.09, 0.14)), 0.04)


def thigh_plate(P, s):
    c = V(s * 0.13, 0.085, 0.71)
    d = rbox(P, c, V(0.075, 0.025, 0.13), rot(V(1, 0, 0), -6), 0.02)
    d = np.minimum(d, rbox(P, V(s * 0.21, 0.0, 0.76), V(0.025, 0.07, 0.1), rot(V(0, 1, 0), s * 8), 0.015))
    return d


def shin(P, s):
    return round_cone(P, KNEE[s], ANKLE[s] + V(0, 0, 0.1), 0.072, 0.06)


def knee_cap(P, s):
    c = KNEE[s] + V(0, 0.07, 0.0)
    d = rbox(P, c, V(0.065, 0.035, 0.065), rot(V(1, 0, 0), 20), 0.03)
    return smax(d, -rbox(P, c + V(0, 0.04, 0), V(0.075, 0.01, 0.006)), 0.004)


def shin_plate(P, s):
    k, a = KNEE[s], ANKLE[s]
    c = k + (a - k) * 0.45 + V(0, 0.065, 0)
    d = rbox(P, c, V(0.062, 0.025, 0.13), rot(V(1, 0, 0), -4), 0.02)
    return smax(d, -rbox(P, c + V(0, 0.026, 0), V(0.004, 0.01, 0.14)), 0.004)


def boot(P, s):
    a = ANKLE[s]
    d = rbox(P, V(a[0], 0.05, 0.07), V(0.08, 0.16, 0.07), rad=0.045)
    d = smin(d, cylinder(P, a - V(0, 0, 0.06), a + V(0, 0, 0.12), 0.08), 0.03)
    d = smin(d, rbox(P, V(a[0], -0.1, 0.09), V(0.06, 0.04, 0.05), rad=0.02), 0.02)  # heel jet
    d = smax(d, plane(P, V(0, 0, 0.03), V(0, 0, -1)), 0.0)
    return d


def sole(P, s):
    a = ANKLE[s]
    return rbox(P, V(a[0], 0.05, 0.022), V(0.088, 0.175, 0.024), rad=0.018)


def heel_glow(P, s):
    a = ANKLE[s]
    return cylinder(P, V(a[0], -0.145, 0.09), V(a[0], -0.15, 0.09), 0.026)


# --- hips -----------------------------------------------------------------------------

def pelvis(P):
    d = ellipsoid(P, V(0, -0.01, 0.9), V(0.18, 0.13, 0.12))
    for s, _ in SIDES:
        d = smin(d, round_cone(P, V(s * 0.1, 0, 0.92), HIP[s], 0.11, 0.105), 0.04)
    return d


def belt(P):
    d = ring(P, V(0, 0.0, 0.99), None, 0.19, 0.145, 0.022, 0.03)
    return np.minimum(d, rbox(P, V(0, 0.15, 0.985), V(0.06, 0.02, 0.04), rad=0.012))  # buckle


def belt_glow(P):
    return rbox(P, V(0, 0.171, 0.985), V(0.035, 0.003, 0.012), rad=0.003)


def pouches(P):
    d = 1.0
    for s, _ in SIDES:
        d = np.minimum(d, rbox(P, V(s * 0.2, -0.04, 0.96), V(0.035, 0.05, 0.05), rad=0.012))
    return d


# --- torso -----------------------------------------------------------------------------

def undersuit(P):
    d = ellipsoid(P, CHEST_C, CHEST_R)
    d = smin(d, ellipsoid(P, V(0, 0.01, 1.07), V(0.145, 0.115, 0.12)), 0.06)    # narrow waist
    d = smin(d, capsule(P, SHOULDER[-1.0], SHOULDER[1.0], 0.1), 0.06)
    d = smin(d, round_cone(P, V(0, -0.01, 1.38), V(0, 0.0, 1.48), 0.085, 0.075), 0.03)  # neck
    sh, el, wr = SHOULDER[1.0], ELBOW[1.0], WRIST[1.0]                          # rifle arm
    d = smin(d, round_cone(P, sh, el, 0.085, 0.065), 0.04)
    d = smin(d, round_cone(P, el, wr, 0.065, 0.05), 0.02)
    return d


def cuirass(P):
    """Chrome muscle cuirass: sculpted pecs and a six-pack. He's very proud of it."""
    d = 1.0
    for s, _ in SIDES:
        d = np.minimum(d, ellipsoid(P, V(s * 0.088, 0.11, 1.31), V(0.105, 0.075, 0.085),
                                    rot(V(0, 0, 1), s * -12)))
    d = smin(d, rbox(P, V(0, 0.09, 1.14), V(0.095, 0.048, 0.11), rad=0.045), 0.05)
    d = smin(d, ellipsoid(P, V(0, 0.0, 1.27), V(0.215, 0.15, 0.178)), 0.03)  # wraps round the chest
    d = smax(d, plane(P, V(0, 0, 1.03), V(0, 0, -1)), 0.02)
    groove = np.maximum(np.abs(P[:, 0]) - 0.004, -(P[:, 1] - 0.08))
    groove = np.maximum(groove, P[:, 2] - 1.36)
    for z in (1.19, 1.12):
        groove = np.minimum(groove, np.maximum(np.abs(P[:, 2] - z) - 0.004,
                                               np.maximum(np.abs(P[:, 0]) - 0.075, -(P[:, 1] - 0.08))))
    for s, _ in SIDES:  # under the pecs
        groove = np.minimum(groove, np.maximum(np.abs(P[:, 2] - (1.245 + np.abs(P[:, 0]) * 0.25)) - 0.004,
                                               np.maximum(np.abs(P[:, 0]) - 0.17, -(P[:, 1] - 0.08))))
    return smax(d, -groove, 0.006)


def plates(P):
    """Bone-white armour: collar, back plate, upper-arm plate, gauntlets."""
    d = ring(P, V(0, -0.01, 1.43), None, 0.14, 0.12, 0.022, 0.035)                  # collar
    d = np.minimum(d, rbox(P, V(0, -0.12, 1.27), V(0.18, 0.04, 0.15), rot(V(1, 0, 0), 6), 0.04))  # back
    sh, el, wr = SHOULDER[1.0], ELBOW[1.0], WRIST[1.0]
    R = _frame(wr - el, V(1, 0, 0))
    d = np.minimum(d, rbox(P, el + (wr - el) * 0.55, V(0.06, 0.07, 0.06), R, 0.02))   # gauntlet
    return d


def pauldrons(P, s):
    """Huge stacked shoulder plates, tipped up like a bodybuilder's lats."""
    d = 1.0
    for k in range(3):
        c = V(s * (0.3 + 0.03 * k), -0.005, 1.49 - 0.042 * k)
        R = rot(V(0, 1, 0), s * (20 + 9 * k))
        d = smin(d, rbox(P, c, V(0.105 - 0.008 * k, 0.125 - 0.01 * k, 0.034), R, 0.02), 0.01)
    return d


def pauldron_trim(P, s):
    c = V(s * 0.3, -0.005, 1.49)
    R = rot(V(0, 1, 0), s * 20)
    return rbox(P, c + R @ V(0, 0, 0.034), V(0.06, 0.11, 0.006), R, 0.004)


def _on_cuirass(x, z, out):
    """Point on the front of the cuirass at (x, z), `out` metres proud of it."""
    lo, hi = 0.0, 0.4
    for _ in range(40):
        mid = (lo + hi) / 2
        if min(cuirass(V(x, mid, z)[None])[0], plates(V(x, mid, z)[None])[0]) < 0:
            lo = mid
        else:
            hi = mid
    return V(x, lo + out, z)


def chain(P):
    """Gold chain with a fat medallion, slung over the cuirass."""
    pts = [_on_cuirass(s * x, z, 0.008) for s, x, z in
           ((-1, 0.115, 1.45), (-1, 0.11, 1.4), (-1, 0.075, 1.34), (-1, 0.035, 1.3), (-1, 0.012, 1.287), (1, 0.012, 1.287),
            (1, 0.035, 1.3), (1, 0.075, 1.34), (1, 0.11, 1.4), (1, 0.115, 1.45))]
    d = 1.0
    for a, b in zip(pts, pts[1:]):
        d = np.minimum(d, capsule(P, a, b, 0.009))
    m = _on_cuirass(0.03, 1.245, 0.018) * V(0, 1, 1)  # off the centre groove
    d = np.minimum(d, cylinder(P, m - V(0, 0.008, 0), m + V(0, 0.01, 0), 0.032))
    return smax(d, -cylinder(P, m + V(0, 0.006, 0), m + V(0, 0.02, 0), 0.02), 0.003)


def pack(P):
    """Power pack with vent fins and twin thrusters."""
    d = rbox(P, V(0, -0.2, 1.28), V(0.13, 0.06, 0.14), rad=0.035)
    for k in range(4):
        d = np.minimum(d, rbox(P, V(0, -0.265, 1.2 + 0.045 * k), V(0.1, 0.012, 0.01), rad=0.004))
    for s, _ in SIDES:
        a, b = V(s * 0.12, -0.25, 1.26), V(s * 0.15, -0.28, 1.08)
        t = round_cone(P, a, b, 0.038, 0.048)
        d = np.minimum(d, smax(t, -cylinder(P, b - V(0, 0, 0.02), b + V(0, 0, 0.04), 0.034), 0.004))
    return d


def pack_glow(P):
    d = rbox(P, V(0, -0.262, 1.36), V(0.05, 0.004, 0.02), rad=0.004)
    for s, _ in SIDES:
        b = V(s * 0.15, -0.28, 1.08)
        d = np.minimum(d, cylinder(P, b + V(0, 0, -0.005), b + V(0, 0, 0.012), 0.032))
    return d


def glove_r(P):
    f = HAND[1.0]
    g = ellipsoid(P, f, V(0.05, 0.05, 0.055))
    g = smin(g, round_cone(P, WRIST[1.0], f, 0.05, 0.046), 0.02)
    for i in range(4):
        g = smin(g, ellipsoid(P, f + V(0.035, (i - 1.5) * 0.021, 0.012), V(0.014, 0.014, 0.014)), 0.01)
    return g


# --- rifle -----------------------------------------------------------------------------

def _rifle_frame():
    d_ = RIFLE_DIR
    rear = MUZZLE - d_ * 0.82
    side = norm(np.cross(d_, V(0, 0, 1)))
    up = np.cross(side, d_)
    return d_, rear, side, up, np.column_stack([side, d_, up])


def _rx(deg):
    return rot(V(1, 0, 0), deg)


def rifle(P):
    d_, rear, side, up, R = _rifle_frame()
    mid = rear + d_ * 0.38
    d = rbox(P, mid, V(0.036, 0.22, 0.055), R, 0.016)
    d = np.minimum(d, rbox(P, mid + d_ * 0.29 + up * 0.012, V(0.03, 0.1, 0.036), R, 0.014))
    d = np.minimum(d, cylinder(P, mid + d_ * 0.3, MUZZLE, 0.014))
    d = np.minimum(d, cylinder(P, MUZZLE - d_ * 0.05, MUZZLE, 0.022))
    d = np.minimum(d, rbox(P, mid + up * 0.072 - d_ * 0.04, V(0.014, 0.09, 0.016), R, 0.006))
    d = np.minimum(d, rbox(P, mid + up * 0.1 - d_ * 0.02, V(0.02, 0.03, 0.022), R, 0.008))
    return d


def rifle_frame(P):
    d_, rear, side, up, R = _rifle_frame()
    d = rbox(P, rear + d_ * 0.07 - up * 0.01, V(0.024, 0.09, 0.04), R, 0.014)
    d = smax(d, -rbox(P, rear + d_ * 0.07 - up * 0.01, V(0.03, 0.05, 0.016), R, 0.008), 0.006)
    d = np.minimum(d, rbox(P, rear + d_ * 0.27 - up * 0.075, V(0.02, 0.022, 0.05), R @ _rx(15), 0.008))
    d = np.minimum(d, rbox(P, rear + d_ * 0.47 - up * 0.08, V(0.024, 0.04, 0.05), R @ _rx(-10), 0.01))
    return d


def rifle_glow(P):
    d_, rear, side, up, R = _rifle_frame()
    mid = rear + d_ * 0.38
    d = rbox(P, mid + side * 0.035 + d_ * 0.05, V(0.006, 0.09, 0.012), R, 0.004)
    d = np.minimum(d, rbox(P, mid - side * 0.035 + d_ * 0.05, V(0.006, 0.09, 0.012), R, 0.004))
    return np.minimum(d, rbox(P, mid + up * 0.135 - d_ * 0.02, V(0.016, 0.003, 0.014), R, 0.002))


# --- left arm: upper arm segment (ArmL) and forearm + hand segment (ElbowL) ------------

def arm_l_upper(P):
    sh, el = SHOULDER[-1.0], ELBOW[-1.0]
    return round_cone(P, sh, el, 0.085, 0.066)


def arm_l_plate(P):
    sh, el = SHOULDER[-1.0], ELBOW[-1.0]
    R = _frame(el - sh, V(1, 0, 0))
    return rbox(P, sh + (el - sh) * 0.5, V(0.06, 0.07, 0.05), R, 0.02)


def arm_l_fore(P):
    el, wr = ELBOW[-1.0], WRIST[-1.0]
    return round_cone(P, el, wr, 0.066, 0.05)


def arm_l_gauntlet(P):
    el, wr = ELBOW[-1.0], WRIST[-1.0]
    R = _frame(wr - el, V(1, 0, 0))
    d = rbox(P, el + (wr - el) * 0.55, V(0.06, 0.07, 0.06), R, 0.02)
    return np.minimum(d, ellipsoid(P, el, V(0.06, 0.06, 0.06)))  # elbow cop


def _fist_l(P):
    h, wr = HAND[-1.0], WRIST[-1.0]
    ax = norm(h - wr)
    g = ellipsoid(P, h, V(0.048, 0.04, 0.052), _frame(ax, V(1, 0, 0)))
    g = smin(g, round_cone(P, wr, h, 0.048, 0.044), 0.02)
    g = smin(g, capsule(P, h + V(0.03, 0.02, 0.0), h + V(0.035, 0.05, -0.02), 0.014), 0.01)  # thumb
    return g


def glove_l_fist(P):
    """Left hand, plain fist (grabs, scratches, pumps)."""
    h = HAND[-1.0]
    g = _fist_l(P)
    for i in range(4):  # knuckles
        g = smin(g, ellipsoid(P, h + V(-0.012 + 0.008 * i, 0.03, -0.03 + 0.003 * i), V(0.014, 0.014, 0.014)), 0.01)
    return g


def glove_l_point(P):
    """Left hand, index finger out (points, beckons, wags)."""
    h, wr = HAND[-1.0], WRIST[-1.0]
    knuckle = h + norm(h - wr) * 0.035 + V(0.0, 0.015, 0.0)
    return smin(_fist_l(P), capsule(P, knuckle, knuckle + POINT_DIR * 0.075, 0.014), 0.01)


def glove_l_bird(P):
    """Left hand, middle finger up (straight along the forearm)."""
    h, wr = HAND[-1.0], WRIST[-1.0]
    ax = norm(h - wr)
    knuckle = h + ax * 0.04
    return smin(_fist_l(P), capsule(P, knuckle, knuckle + ax * 0.085, 0.015), 0.01)


# --- head ----------------------------------------------------------------------------------

def helmet(P):
    """Closed tech helmet: rounded shell, crest fin, ear cans, neck guard."""
    d = rbox(P, V(0, -0.01, 1.655), V(0.125, 0.135, 0.13), rad=0.08)
    d = smin(d, rbox(P, V(0, -0.02, 1.7), V(0.012, 0.13, 0.12), rot(V(1, 0, 0), -12), 0.01), 0.02)  # crest
    d = smin(d, rbox(P, V(0, -0.1, 1.52), V(0.11, 0.05, 0.05), rot(V(1, 0, 0), 25), 0.03), 0.02)    # neck guard
    for s, _ in SIDES:
        d = smin(d, cylinder(P, V(s * 0.11, -0.01, 1.62), V(s * 0.15, -0.01, 1.62), 0.055), 0.015)
    # recess for the face display
    d = smax(d, -rbox(P, DISPLAY_C + V(0, 0.03, 0), DISPLAY_H + V(0.006, 0.03, 0.006), rad=0.02), 0.006)
    return d


def helmet_trim(P):
    """Red accent: crest stripe and ear-can rims."""
    d = rbox(P, V(0, -0.02, 1.7), V(0.014, 0.131, 0.121), rot(V(1, 0, 0), -12), 0.01)
    d = np.maximum(d, -(P[:, 2] - 1.76))
    for s, _ in SIDES:
        d = np.minimum(d, ring(P, V(s * 0.152, -0.01, 1.62), rot(V(0, 1, 0), 90), 0.055, 0.055, 0.006, 0.006))
    return d


def jaw(P):
    """Mouth grille under the display."""
    c = V(0, 0.1, 1.525)
    d = rbox(P, c, V(0.07, 0.04, 0.035), rad=0.022)
    for k in range(3):
        d = smax(d, -rbox(P, c + V(0, 0.04, -0.016 + 0.016 * k), V(0.045, 0.01, 0.004)), 0.003)
    return d


def display(P):
    """Dark glass face screen."""
    return rbox(P, DISPLAY_C, DISPLAY_H, rad=0.02)


def ear_lights(P):
    d = 1.0
    for s, _ in SIDES:
        d = np.minimum(d, cylinder(P, V(s * 0.15, -0.01, 1.62), V(s * 0.156, -0.01, 1.62), 0.024))
    return d


# LED face: flat shapes on the display (x, z), extruded a hair in front of it.

def _led(P, shape2d):
    return np.maximum(np.abs(P[:, 1] - LED_Y - 0.002) - 0.0025, shape2d(P[:, 0], P[:, 2]))


def _seg2d(x, z, a, b, r):
    pa = np.stack([x - a[0], z - a[1]], 1)
    ba = np.array(b) - np.array(a)
    h = np.clip((pa @ ba) / (ba @ ba), 0, 1)
    return np.sqrt(((pa - h[:, None] * ba) ** 2).sum(1)) - r


def _polyline2d(x, z, pts, r):
    d = np.full(x.shape, 1.0)
    for a, b in zip(pts, pts[1:]):
        d = np.minimum(d, _seg2d(x, z, a, b, r))
    return d


EYE_Z = 1.622


def _eye2d(x, z, s):
    """Half-lidded, smug: an ellipse with a heavy lid sloping down to the nose."""
    cx = s * 0.042
    e = np.sqrt(((x - cx) / 0.026) ** 2 + ((z - EYE_Z) / 0.016) ** 2) - 1.0
    e *= 0.016
    lid = (z - EYE_Z) - 0.003 - 0.25 * s * (x - cx)  # top cut, lower toward the nose
    return np.maximum(e, lid)


def led_eyes(P):
    return _led(P, lambda x, z: _eye2d(x, z, -1.0))


def led_eye_r(P):
    return _led(P, lambda x, z: _eye2d(x, z, 1.0))


def led_brows(P):
    """His right brow cocked high, the left flat and low: a leer."""
    def f(x, z):
        up = _polyline2d(x, z, [(0.018, EYE_Z + 0.022), (0.04, EYE_Z + 0.036), (0.068, EYE_Z + 0.03)], 0.0035)
        flat = _polyline2d(x, z, [(-0.018, EYE_Z + 0.014), (-0.068, EYE_Z + 0.02)], 0.0035)
        return np.minimum(up, flat)
    return _led(P, f)


def led_grin(P):
    """Lopsided grin pulled up toward his right."""
    pts = [(-0.06, 1.568), (-0.035, 1.557), (0.0, 1.553), (0.035, 1.56), (0.062, 1.58)]
    def f(x, z):
        d = _polyline2d(x, z, pts, 0.0042)
        return np.minimum(d, _polyline2d(x, z, [(0.062, 1.58), (0.07, 1.574)], 0.0035))  # dimple tick
    return _led(P, f)


def led_laugh_r(P):
    """His right eye squeezed shut laughing (with the wink shape on the left)."""
    return _led(P, lambda x, z: _polyline2d(x, z, [(0.018, EYE_Z - 0.004), (0.042, EYE_Z + 0.01),
                                                    (0.066, EYE_Z - 0.004)], 0.0035))


def led_kiss(P):
    """Puckered lips, blowing a kiss."""
    def f(x, z):
        r = np.sqrt((x - 0.012) ** 2 + ((z - 1.565) * 1.15) ** 2)
        return np.abs(r - 0.011) - 0.0035
    return _led(P, f)


def led_tongue(P):
    """Tongue lolling out of the grin."""
    def f(x, z):
        e = np.sqrt(((x - 0.012) / 0.017) ** 2 + ((z - 1.551) / 0.017) ** 2) - 1.0
        return np.maximum(e * 0.015, z - 1.553)
    return _led(P, f)


def led_laugh_mouth(P):
    """Wide open laughing mouth."""
    def f(x, z):
        top = _seg2d(x, z, (-0.05, 1.575), (0.052, 1.578), 0.0035)
        r = np.sqrt((x / 0.05) ** 2 + ((z - 1.576) / 0.032) ** 2)
        arc = np.maximum(np.abs(r - 1.0) * 0.03 - 0.0035, z - 1.576)
        return np.minimum(top, arc)
    return _led(P, f)


def led_wink(P):
    """Wink: the left eye squeezed into a ^ (shown only while winking)."""
    return _led(P, lambda x, z: _polyline2d(x, z, [(-0.066, EYE_Z - 0.004), (-0.042, EYE_Z + 0.01),
                                                    (-0.018, EYE_Z - 0.004)], 0.0035))


# --- parts table -----------------------------------------------------------------------
# name: (segment, material, sdf, voxel size, target triangles). Parts named
# visor_* glow and are tinted by grunt.gd.

PARTS = {}
for s, side in SIDES:
    PARTS[f"thigh_{side}"] = ("Thigh" + side, "grunt_suit", lambda P, s=s: thigh(P, s), 0.006, 700)
    PARTS[f"thighplate_{side}"] = ("Thigh" + side, "grunt_plate", lambda P, s=s: thigh_plate(P, s), 0.004, 500)
    PARTS[f"shin_{side}"] = ("Shin" + side, "grunt_suit", lambda P, s=s: shin(P, s), 0.006, 500)
    PARTS[f"kneecap_{side}"] = ("Shin" + side, "grunt_chrome", lambda P, s=s: knee_cap(P, s), 0.004, 400)
    PARTS[f"shinplate_{side}"] = ("Shin" + side, "grunt_plate", lambda P, s=s: shin_plate(P, s), 0.004, 400)
    PARTS[f"boot_{side}"] = ("Shin" + side, "grunt_metal", lambda P, s=s: boot(P, s), 0.005, 900)
    PARTS[f"sole_{side}"] = ("Shin" + side, "grunt_dark", lambda P, s=s: sole(P, s), 0.005, 300)
    PARTS[f"visor_heel_{side}"] = ("Shin" + side, "grunt_visor", lambda P, s=s: heel_glow(P, s), 0.003, 100)
    PARTS[f"pauldron_{side}"] = ("Torso", "grunt_plate", lambda P, s=s: pauldrons(P, s), 0.004, 900)
    PARTS[f"pauldrontrim_{side}"] = ("Torso", "grunt_accent", lambda P, s=s: pauldron_trim(P, s), 0.003, 300)
PARTS.update({
    "pelvis": ("Hips", "grunt_suit", pelvis, 0.006, 800),
    "belt": ("Hips", "grunt_metal", belt, 0.004, 700),
    "visor_buckle": ("Hips", "grunt_visor", belt_glow, 0.002, 80),
    "pouches": ("Hips", "grunt_dark", pouches, 0.004, 400),
    "undersuit": ("Torso", "grunt_suit", undersuit, 0.006, 2000),
    "cuirass": ("Torso", "grunt_chrome", cuirass, 0.005, 4000),
    "plates": ("Torso", "grunt_plate", plates, 0.005, 1600),
    "chain": ("Torso", "grunt_gold", chain, 0.0025, 900),
    "pack": ("Torso", "grunt_metal", pack, 0.004, 1400),
    "visor_pack": ("Torso", "grunt_visor", pack_glow, 0.003, 200),
    "glove_r": ("Torso", "grunt_dark", glove_r, 0.004, 600),
    "rifle": ("Torso", "grunt_metal", rifle, 0.004, 1200),
    "rifle_frame": ("Torso", "grunt_dark", rifle_frame, 0.004, 600),
    "visor_cell": ("Torso", "grunt_visor", rifle_glow, 0.0025, 200),
    "arm_l": ("ArmL", "grunt_suit", arm_l_upper, 0.005, 500),
    "armplate_l": ("ArmL", "grunt_plate", arm_l_plate, 0.004, 300),
    "forearm_l": ("ElbowL", "grunt_suit", arm_l_fore, 0.005, 400),
    "gauntlet_l": ("ElbowL", "grunt_plate", arm_l_gauntlet, 0.004, 500),
    "glove_l_point": ("ElbowL", "grunt_dark", glove_l_point, 0.003, 700),
    "glove_l_bird": ("ElbowL", "grunt_dark", glove_l_bird, 0.003, 700),
    "glove_l_fist": ("ElbowL", "grunt_dark", glove_l_fist, 0.003, 700),
    "helmet": ("Head", "grunt_plate", helmet, 0.004, 2400),
    "helmet_trim": ("Head", "grunt_accent", helmet_trim, 0.003, 600),
    "jaw": ("Head", "grunt_metal", jaw, 0.003, 600),
    "visor": ("Head", "grunt_glass", display, 0.003, 400),
    "visor_ears": ("Head", "grunt_visor", ear_lights, 0.002, 150),
    "visor_eye_l": ("Head", "grunt_visor", led_eyes, 0.0015, 200),
    "visor_eye_r": ("Head", "grunt_visor", led_eye_r, 0.0015, 200),
    "visor_brows": ("Head", "grunt_visor", led_brows, 0.0015, 250),
    "visor_grin": ("Head", "grunt_visor", led_grin, 0.0015, 300),
    "visor_wink": ("Head", "grunt_visor", led_wink, 0.0015, 150),
    "visor_laugh_r": ("Head", "grunt_visor", led_laugh_r, 0.0015, 150),
    "visor_kiss": ("Head", "grunt_visor", led_kiss, 0.0015, 200),
    "visor_tongue": ("Head", "grunt_visor", led_tongue, 0.0015, 200),
    "visor_laugh_mouth": ("Head", "grunt_visor", led_laugh_mouth, 0.0015, 300),
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
