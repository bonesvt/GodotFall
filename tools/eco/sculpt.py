#!/usr/bin/env python3
"""Sculpts Eco's meshes from signed distance fields and saves them as .npz
(vertices, faces) for build_eco.py to rig and export. Needs numpy, scipy and
scikit-image.

    python3 tools/eco/sculpt.py <out_dir> [part ...]
    python3 tools/eco/sculpt.py <out_dir> --fp      (first-person arm, pistol space)

Each part is one material on one bone rule (see PARTS at the bottom). Shapes
are in metres around the joints in rig.py. Body skin hidden under clothes is
cut away so it can't poke through."""
import sys
import time
from pathlib import Path

import numpy as np
from skimage import measure

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig import J  # noqa: E402
from sdf import (V, norm, smin, smax, union, rot, sphere, ellipsoid, capsule,  # noqa: E402
                 round_cone, rbox, cylinder, ring, shell, plane)

SIDES = ((1.0, "R"), (-1.0, "L"))


# --- body --------------------------------------------------------------------

def torso(P, grow=0.0):
    g = grow
    d = ellipsoid(P, V(0, 0, 0.9), V(0.165, 0.11, 0.105) + g)
    d = smin(d, ellipsoid(P, V(0, 0.0, 1.05), V(0.098, 0.074, 0.11) + g), 0.05)
    d = smin(d, ellipsoid(P, V(0, -0.006, 1.235), V(0.132, 0.088, 0.13) + g), 0.05)
    for s, _ in SIDES:
        d = smin(d, ellipsoid(P, V(s * 0.05, 0.052, 1.228), V(0.054, 0.04, 0.048) + g), 0.03)
        d = smin(d, ellipsoid(P, V(s * 0.066, -0.06, 0.85), V(0.084, 0.07, 0.088) + g), 0.035)
    d = smin(d, capsule(P, V(-0.14, -0.016, 1.355), V(0.14, -0.016, 1.355), 0.052 + g), 0.04)
    return d


def neck(P, grow=0.0):
    return round_cone(P, V(0, -0.012, 1.34), V(0, -0.004, 1.47), 0.047 + grow, 0.04 + grow)


def leg(P, s, side, grow=0.0):
    g = grow
    hip, knee, ankle, toe = J["hip." + side], J["knee." + side], J["ankle." + side], J["toe." + side]
    d = round_cone(P, hip, knee, 0.096 + g, 0.054 + g)
    d = smin(d, ellipsoid(P, V(s * 0.1, 0.008, 0.7), V(0.075, 0.07, 0.13) + g), 0.04)
    d = smin(d, round_cone(P, knee, ankle, 0.051 + g, 0.032 + g), 0.02)
    d = smin(d, ellipsoid(P, V(s * 0.09, -0.03, 0.32), V(0.048, 0.048, 0.1) + g), 0.03)
    d = smin(d, round_cone(P, ankle, toe, 0.036 + g, 0.028 + g), 0.02)
    return d


def arm(P, s, side, grow=0.0):
    g = grow
    sh, el, wr = J["shoulder." + side], J["elbow." + side], J["wrist." + side]
    d = ellipsoid(P, sh + V(s * 0.01, 0, -0.025), V(0.054, 0.054, 0.068) + g)
    d = smin(d, round_cone(P, sh, el, 0.045 + g, 0.033 + g), 0.025)
    d = smin(d, round_cone(P, el, wr, 0.034 + g, 0.023 + g), 0.015)
    fa = norm(wr - el)
    d = smin(d, ellipsoid(P, el + fa * 0.06 + V(0, -0.004, 0), V(0.036, 0.036, 0.075) + g,
                          _frame(fa)), 0.02)
    return d


def _frame(axis_z, hint=V(1, 0, 0)):
    """Rotation whose third column is axis_z."""
    z = norm(axis_z)
    x = norm(hint - z * (hint @ z))
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


def _front(x, z, off=0.0):
    return _on_torso(V(x, 1.0, z), off)


def toned_stomach(P, d):
    """Athletic abs: two columns of shallow pads either side of a centre line,
    the lines across them, obliques curving down to the hips, and a navel."""
    m = (P[:, 2] > 0.93) & (P[:, 2] < 1.2) & (P[:, 1] > 0.0) & (np.abs(P[:, 0]) < 0.13)
    if not m.any():
        return d
    Q, e = P[m], d[m]
    for z in (1.118, 1.078, 1.04):
        for s in (1, -1):
            c = _front(s * 0.018, z, -0.0035)
            e = smin(e, ellipsoid(Q, c, V(0.0155, 0.007, 0.0165)), 0.006)
    e = smax(e, -capsule(Q, _front(0, 1.16, 0.0005), _front(0, 1.0, 0.0005), 0.0028), 0.003)  # centre line
    for z in (1.098, 1.059):
        e = smax(e, -capsule(Q, _front(-0.03, z, 0.0004), _front(0.03, z, 0.0004), 0.0018), 0.003)
    for s in (1, -1):  # obliques / hip lines
        pts = [_front(s * x, z, 0.0004) for x, z in ((0.062, 1.09), (0.058, 1.03), (0.045, 0.98), (0.03, 0.94))]
        for a, b in zip(pts[:-1], pts[1:]):
            e = smax(e, -capsule(Q, a, b, 0.0022), 0.004)
    e = smax(e, -sphere(Q, _front(0, 1.012, -0.001), 0.0052), 0.003)  # navel
    d = d.copy()
    d[m] = e
    return d


def body(P):
    d = smin(torso(P), neck(P), 0.03)
    for s, side in SIDES:
        d = smin(d, leg(P, s, side), 0.04)
        d = smin(d, arm(P, s, side), 0.03)
        # kneecap
        d = smin(d, ellipsoid(P, J["knee." + side] + V(0, 0.043, 0.012), V(0.024, 0.014, 0.028)), 0.014)
    d = toned_stomach(P, d)
    # the thighs touch but stay separate surfaces below the crotch
    gap = np.maximum(np.abs(P[:, 0]) - 0.004, P[:, 2] - 0.765)
    return smax(d, -gap, 0.012)


# --- hands -----------------------------------------------------------------

def hand_frame(s, side):
    a = J["hand_dir." + side]
    n0 = V(-s, 0, 0)  # palm faces her leg
    n = norm(n0 - a * (a @ n0))
    w = np.cross(a, n)
    tw = w if w[1] > 0 else -w  # toward the front, where the thumb is
    return a, n, tw


def finger_chains(s, side, curl=(14, 34, 58), grip=False):
    """Capsule chains [(points, radii)] for the four fingers and thumb."""
    wr = J["wrist." + side]
    a, n, tw = hand_frame(s, side)
    chains = []
    offs = (0.026, 0.009, -0.008, -0.024)
    lens = (0.04, 0.045, 0.043, 0.034)
    for i, (o, L) in enumerate(zip(offs, lens)):
        p = wr + a * (0.086 - 0.004 * abs(i - 1.5)) + tw * o - n * 0.002
        pts, radii = [p], [0.0098 - 0.0006 * i]
        ang = 0.0
        for k, f in enumerate((1.0, 0.66, 0.5)):
            ang += np.radians(curl[k] + (4 * i if not grip else 0))
            dvec = np.cos(ang) * a + np.sin(ang) * n
            p = p + dvec * L * f
            pts.append(p)
            radii.append(radii[-1] * 0.88)
        chains.append((pts, radii))
    # thumb
    p = wr + a * 0.028 + tw * 0.026 + n * 0.012
    pts, radii = [p], [0.0125]
    for L, d in ((0.036, norm(a * 0.55 + tw * 0.55 + n * 0.45)), (0.03, norm(a * 0.8 + tw * 0.2 + n * 0.55))):
        p = p + d * L
        pts.append(p)
        radii.append(radii[-1] * 0.82)
    chains.append((pts, radii))
    return chains


def palm(P, s, side, grow=0.0):
    wr = J["wrist." + side]
    a, n, tw = hand_frame(s, side)
    R = np.column_stack([tw, a, n])
    return rbox(P, wr + a * 0.046, V(0.037, 0.045, 0.0135) + grow, R, 0.011 + grow * 0.5)


def hand(P, s, side):
    d = palm(P, s, side)
    for pts, radii in finger_chains(s, side):
        for k in range(len(pts) - 1):
            d = smin(d, round_cone(P, pts[k], pts[k + 1], radii[k], radii[k + 1]), 0.008)
    wr = J["wrist." + side]
    d = smin(d, round_cone(P, J["elbow." + side] * 0.3 + wr * 0.7, wr + J["hand_dir." + side] * 0.01, 0.026, 0.023), 0.015)
    return d


def glove(P, s, side):
    """Fingerless mechanic's glove: palm, first knuckles and a padded cuff."""
    wr = J["wrist." + side]
    a, n, tw = hand_frame(s, side)
    d = palm(P, s, side, 0.0035)
    for pts, radii in finger_chains(s, side)[:4]:
        mid = pts[0] + (pts[1] - pts[0]) * 0.55
        d = smin(d, round_cone(P, pts[0], mid, radii[0] + 0.0028, radii[0] + 0.0024), 0.006)
    tpts, trad = finger_chains(s, side)[4]
    d = smin(d, round_cone(P, tpts[0], tpts[0] + (tpts[1] - tpts[0]) * 0.8, trad[0] + 0.003, trad[1] + 0.003), 0.006)
    cuff = round_cone(P, wr - J["hand_dir." + side] * 0.045, wr + a * 0.012, 0.0315, 0.03)
    d = smin(d, cuff, 0.01)
    # padded knuckle ridge on the back of the hand
    d = smin(d, capsule(P, wr + a * 0.083 + tw * 0.03 - n * 0.012, wr + a * 0.083 - tw * 0.03 - n * 0.012, 0.0085), 0.006)
    return d


def knuckle_plate(P, s, side):
    wr = J["wrist." + side]
    a, n, tw = hand_frame(s, side)
    R = np.column_stack([tw, a, n])
    return rbox(P, wr + a * 0.05 - n * 0.019, V(0.026, 0.024, 0.0035), R, 0.003)


# --- head --------------------------------------------------------------------

EYE_C = {s: V(s * 0.0365, 0.06, 1.553) for s, _ in SIDES}
EYE_R = 0.0205


def head(P):
    d = ellipsoid(P, V(0, -0.012, 1.566), V(0.085, 0.097, 0.097))
    d = smin(d, ellipsoid(P, V(0, 0.022, 1.512), V(0.06, 0.066, 0.064)), 0.035)
    d = smin(d, ellipsoid(P, V(0, 0.055, 1.464), V(0.022, 0.024, 0.019)), 0.026)
    for s, _ in SIDES:
        d = smin(d, ellipsoid(P, V(s * 0.053, 0.046, 1.537), V(0.025, 0.023, 0.015)), 0.018)
        d = smin(d, ellipsoid(P, V(s * 0.037, 0.074, 1.575), V(0.027, 0.013, 0.01), rot(V(0, 1, 0), -s * 12)), 0.014)
        d = smin(d, ellipsoid(P, V(s * 0.085, -0.008, 1.54), V(0.011, 0.019, 0.027), rot(V(0, 0, 1), s * 18)), 0.01)
    # nose
    d = smin(d, round_cone(P, V(0, 0.081, 1.556), V(0, 0.099, 1.516), 0.0055, 0.0088), 0.011)
    for s, _ in SIDES:
        d = smin(d, sphere(P, V(s * 0.0078, 0.09, 1.511), 0.0064), 0.008)
    # lips
    d = smin(d, ellipsoid(P, V(0, 0.077, 1.4885), V(0.0195, 0.012, 0.0072)), 0.008)
    d = smin(d, ellipsoid(P, V(0, 0.073, 1.4775), V(0.0175, 0.013, 0.0085)), 0.008)
    d = smax(d, -ellipsoid(P, V(0, 0.086, 1.4835), V(0.02, 0.012, 0.0012)), 0.002)  # mouth line
    # tapered V jawline from the jaw angle to a narrow chin
    for s, _ in SIDES:
        a, b = V(s * 0.026, 0, 1.446), V(s * 0.072, 0, 1.502)
        n = norm(V(s * (b[2] - a[2]), 0, -(abs(b[0]) - abs(a[0]))))
        cut = (P - a) @ n
        cut = cut - np.clip(-P[:, 1] / 0.03, 0, 1) * 0.05
        d = smax(d, cut, 0.018)
    # neck, blended in under the jaw
    d = smin(d, round_cone(P, V(0, -0.01, 1.4), V(0, -0.006, 1.49), 0.043, 0.041), 0.03)
    # almond eye openings, outer corners lifted
    for s, _ in SIDES:
        sock = ellipsoid(P, EYE_C[s] + V(0, 0.024, 0.0002), V(0.021, 0.022, 0.0098), rot(V(0, 1, 0), -s * 14))
        d = smax(d, -sock, 0.004)
    return d


def eyelash(P):
    """A thin dark lash flick along each upper lid, winged at the outer corner."""
    d = None
    for s, _ in SIDES:
        c = EYE_C[s]
        pts = [c + V(-s * 0.019, 0.016, 0.0005), c + V(-s * 0.005, 0.0205, 0.0088),
               c + V(s * 0.011, 0.018, 0.0108), c + V(s * 0.022, 0.011, 0.0095), c + V(s * 0.033, 0.006, 0.0165)]
        rr = (0.0012, 0.002, 0.0023, 0.002, 0.0008)
        for k in range(len(pts) - 1):
            e = round_cone(P, pts[k], pts[k + 1], rr[k], rr[k + 1])
            d = e if d is None else smin(d, e, 0.002)
    return d


# --- hair --------------------------------------------------------------------

SCALP_C = V(0, -0.012, 1.566)
SCALP_R = V(0.085, 0.097, 0.097)
HAIRLINE = [(0, 1.612), (30, 1.607), (55, 1.592), (80, 1.575), (100, 1.56), (125, 1.53),
            (150, 1.495), (180, 1.475)]


def hairline_z(phi_deg):
    a = np.abs(phi_deg)
    xs, ys = zip(*HAIRLINE)
    return np.interp(a, xs, ys)


def scalp_point(theta, phi, lift=0.0):
    """Point on the scalp: theta from the crown (deg), phi round from the front (deg, + to her right)."""
    t, p = np.radians(theta), np.radians(phi)
    dirv = V(np.sin(t) * np.sin(p), np.sin(t) * np.cos(p), np.cos(t))
    pt = SCALP_C + dirv * SCALP_R
    nrm = norm(dirv / SCALP_R)
    return pt + nrm * lift, nrm


def scalp_normal(p):
    q = (p - SCALP_C) / SCALP_R
    return norm(q / SCALP_R)


def scalp_dist(p):
    q = (p - SCALP_C) / SCALP_R
    return (np.linalg.norm(q) - 1.0) * SCALP_R.min()


def hair_strands():
    """List of (points, radii) locks: a crown whorl, a long fringe swept to her
    right, short layered sides and nape, and spiky tips that flick outward."""
    rng = np.random.default_rng(7)
    whorl, _ = scalp_point(28, 180)
    strands = []
    rows = [(8, 6, 0), (20, 11, 16), (33, 15, 6), (40, 24, 4), (47, 19, 0), (61, 22, 8), (75, 23, 0), (89, 22, 9), (103, 18, 4), (114, 12, 15)]
    for theta, count, offset in rows:
        for i in range(count):
            phi = -180 + offset + 360.0 * i / count + rng.uniform(-6, 6)
            phi = (phi + 180) % 360 - 180
            if theta == 40 and abs(phi) > 60:
                continue  # extra fringe row, front only
            th = theta + rng.uniform(-3, 3)
            root, n = scalp_point(th, phi, 0.004)
            if root[2] < hairline_z(phi) + 0.004:
                continue
            front = abs(phi) < 62 and th > 22
            # flow away from the crown whorl, along the scalp
            flow = root - whorl
            flow = flow - n * (flow @ n)
            if np.linalg.norm(flow) < 1e-4:
                flow = V(0, 1, 0)
            flow = norm(flow)
            if front:  # fringe: swept across to her right and down over the brow
                flow = norm(flow * 0.7 + V(0.95, 0.15, -0.35))
            side = 60 <= abs(phi) <= 130
            back = abs(phi) > 130
            k_r = rng.uniform(0.85, 1.15)
            if front:
                L, r0, lift, flick, grav = rng.uniform(0.08, 0.1), 0.0125, 0.35, 0.12, 0.3
            elif th < 16:
                L, r0, lift, flick, grav = rng.uniform(0.07, 0.085), 0.0135, 0.15, 0.05, 0.5
            elif th < 30:
                L, r0, lift, flick, grav = rng.uniform(0.09, 0.115), 0.0135, 0.3, 0.25, 0.4
            elif side:
                L, r0, lift, flick, grav = rng.uniform(0.065, 0.09), 0.0115, 0.15, 0.35, 0.9
            elif back:
                L, r0, lift, flick, grav = rng.uniform(0.07, 0.095), 0.0125, 0.2, 0.42, 0.8
            else:
                L, r0, lift, flick, grav = rng.uniform(0.085, 0.105), 0.013, 0.25, 0.3, 0.6
            r0 *= k_r
            pts, radii = [root], [r0]
            dirv = norm(flow + n * lift)
            steps = 9
            for k in range(steps):
                t = (k + 1) / steps
                p = pts[-1]
                nn = scalp_normal(p)
                dirv = norm(dirv + V(0, 0, -grav * 0.18) + nn * (flick * 0.5 * t * t))
                if front and p[2] < 1.592:  # the fringe sweeps aside above her eyes
                    dirv = norm(V(dirv[0] + 0.2, dirv[1], dirv[2] * 0.15))
                p = p + dirv * L / steps
                # keep the lock lying on the head rather than inside it
                lim = (0.012 if front else 0.009) + 0.004 * t
                if front and p[2] < 1.6:
                    lim += 0.006  # clear the brow ridge
                dist = scalp_dist(p)
                if dist < lim:
                    p = p + scalp_normal(p) * (lim - dist)
                pts.append(p)
                radii.append(r0 * (1.0 - 0.9 * t ** 1.15))
            strands.append((pts, radii, n))
            # split tip: a thinner offshoot peeling away from the lock's last third
            if rng.random() < 0.6:
                j = 5
                side_v = norm(np.cross(n, norm(pts[-1] - pts[j])) + rng.normal(0, 0.2, 3))
                sub, sr = [pts[j]], [radii[j] * 0.7]
                for k in range(1, 4):
                    t = k / 3
                    q = pts[min(j + k * 1, len(pts) - 1)] + side_v * 0.008 * t + n * 0.002 * t
                    sub.append(q)
                    sr.append(radii[j] * 0.7 * (1 - 0.88 * t))
                strands.append((sub, sr, n))
    # sideburn locks in front of the ears
    for s, _ in SIDES:
        root, n = scalp_point(98, s * 76, 0.004)
        pts, radii = [root], [0.012]
        dirv = norm(V(s * 0.1, 0.25, -1.0))
        for k in range(6):
            t = (k + 1) / 6
            p = pts[-1] + dirv * 0.075 / 6
            dist = scalp_dist(p)
            if dist < 0.008:
                p = p + scalp_normal(p) * (0.008 - dist)
            pts.append(p)
            radii.append(0.012 * (1 - 0.85 * t))
            dirv = norm(dirv + V(0, 0.08, 0))
        strands.append((pts, radii, n))
    return strands


_STRANDS = None


def hair(P):
    global _STRANDS
    if _STRANDS is None:
        _STRANDS = hair_strands()
    cap = ellipsoid(P, SCALP_C, SCALP_R + 0.009)
    phi = np.degrees(np.arctan2(P[:, 0], P[:, 1]))
    cap = smax(cap, hairline_z(phi) - P[:, 2], 0.006)
    d = cap
    flat = 2.0  # locks are ribbons: this much wider than they are thick
    for pts, radii, n in _STRANDS:
        lo = np.min(pts, axis=0) - 0.03
        hi = np.max(pts, axis=0) + 0.03
        m = np.all((P >= lo) & (P <= hi), axis=1)
        if not m.any():
            continue
        # stretch space along the scalp normal so round locks become flat ribbons
        o = pts[0]
        Q = P[m] - o
        Q = Q + np.outer(Q @ n, n) * (flat - 1.0)
        tp = [(q - o) + n * ((q - o) @ n) * (flat - 1.0) for q in pts]
        e = None
        for k in range(len(pts) - 1):
            seg = round_cone(Q, tp[k], tp[k + 1], radii[k] * flat, radii[k + 1] * flat) / flat
            e = seg if e is None else smin(e, seg, 0.003)
        d[m] = smin(d[m], e, 0.0012)  # nearly hard joins keep a crease between locks
    return d


# --- clothes -------------------------------------------------------------------

def sports_bra(P):
    """Racerback sports bra: scoop front, wide under-bust band."""
    d = torso(P, 0.0035)
    d = smax(d, P[:, 2] - 1.40, 0.005)
    d = smax(d, 1.163 - P[:, 2], 0.004)
    for s, side in SIDES:
        d = smax(d, -ellipsoid(P, V(s * 0.145, -0.005, 1.34), V(0.075, 0.13, 0.085)), 0.005)  # armholes
        d = smax(d, -ellipsoid(P, V(s * 0.115, -0.085, 1.34), V(0.095, 0.06, 0.12)), 0.005)  # racerback
        d = smax(d, -arm(P, s, side, 0.003), 0.004)
    d = smax(d, -ellipsoid(P, V(0, 0.12, 1.37), V(0.062, 0.1, 0.105)), 0.005)          # deep scoop
    band = np.maximum(torso(P, 0.0058), np.abs(P[:, 2] - 1.171) - 0.0075)
    return smin(d, band, 0.002)


def _hips(P, grow=0.0):
    d = torso(P, grow)
    for s, side in SIDES:
        d = smin(d, leg(P, s, side, grow), 0.02)
    return d


def shorts_hem(P):
    return 0.762 + np.clip(np.abs(P[:, 0]) - 0.09, 0, 0.1) * 0.3 - np.clip(-P[:, 1], 0, 0.1) * 0.08


def shorts_top(P):
    return 0.99 - P[:, 1] * 0.1


def _leg_gap(P, z=0.774, w=0.0065):
    return np.maximum(np.abs(P[:, 0]) - w, P[:, 2] - z)


def shorts(P):
    """Fitted short shorts: rolled cuffs, waistband, back patch pockets,
    front pocket seams and a fly."""
    base = _hips(P)
    hem, top = shorts_hem(P), shorts_top(P)
    d = base - 0.008
    d = smax(d, hem - P[:, 2], 0.003)
    d = smax(d, P[:, 2] - top, 0.004)
    cuff = np.maximum(base - 0.0125, np.abs(P[:, 2] - hem - 0.009) - 0.009)
    band = np.maximum(base - 0.0115, np.abs(P[:, 2] - top + 0.013) - 0.012)
    d = smin(np.minimum(d, cuff), band, 0.002)
    for s, side in SIDES:
        c = _on_torso(V(s * 0.068, -1.0, 0.905), 0.0095)
        d = smin(d, rbox(P, c, V(0.037, 0.005, 0.033), rot(V(1, 0, 0), -12), 0.006), 0.002)
        pts = [_on_torso(V(s * x, 1.0, z), 0.008) for x, z in ((0.062, 0.975), (0.09, 0.95), (0.125, 0.925), (0.15, 0.92))]
        for a, b in zip(pts[:-1], pts[1:]):
            d = smax(d, -capsule(P, a, b, 0.0022), 0.0015)
    fly = [_on_torso(V(x, 1.0, z), 0.008) for x, z in ((0.014, 0.968), (0.014, 0.9), (0.004, 0.875))]
    for a, b in zip(fly[:-1], fly[1:]):
        d = smax(d, -capsule(P, a, b, 0.0018), 0.0012)
    return smax(d, -_leg_gap(P), 0.01)


def socks(P):
    """Slouchy ribbed socks peeking out of the boots."""
    d = None
    for s, side in SIDES:
        ang = np.arctan2(P[:, 0] - s * 0.09, P[:, 1] + 0.02)
        e = np.maximum(leg(P, s, side, 0.0045), np.abs(P[:, 2] - 0.288) - 0.032)
        e += 0.0008 * np.sin(ang * 26) - 0.0016 * np.sin(P[:, 2] * 170 + ang * 2 + s)
        d = e if d is None else np.minimum(d, e)
    return d


def _band(base, P, zc, half_h, out=0.003, thick=0.0025):
    """A strap hugging the surface `base` (an SDF) at height zc."""
    return np.maximum(np.abs(base - out) - thick, np.abs(P[:, 2] - zc) - half_h)


def knee_pads(P):
    d = None
    for s, side in SIDES:
        k = J["knee." + side]
        R = rot(V(1, 0, 0), -8)
        e = rbox(P, k + V(0, 0.078, 0.006), V(0.04, 0.011, 0.05), R, 0.012)
        base = leg(P, s, side)
        e = np.minimum(e, _band(base, P, k[2] + 0.004, 0.009))
        d = e if d is None else np.minimum(d, e)
    return d


def boot(P, s, side):
    x = s * 0.093
    d = round_cone(P, V(x, -0.014, 0.07), V(x, -0.01, 0.245), 0.062, 0.07)
    d = smin(d, rbox(P, V(x + s * 0.002, 0.045, 0.05), V(0.052, 0.11, 0.046), rot(V(1, 0, 0), 4), 0.03), 0.03)
    d = smin(d, round_cone(P, V(x, -0.01, 0.225), V(x, -0.01, 0.272), 0.077, 0.08), 0.008)  # folded cuff
    for z in (0.135, 0.195):  # straps
        d = smin(d, ring(P, V(x, -0.012, z), np.eye(3), 0.066 + (z - 0.135) * 0.06, 0.066 + (z - 0.135) * 0.06, 0.004, 0.009), 0.003)
    # laces ridge down the front
    d = smin(d, capsule(P, V(x, 0.042, 0.2), V(x, 0.085, 0.088), 0.008), 0.012)
    return d


def soles(P):
    d = None
    for s, side in SIDES:
        x = s * 0.095
        e = rbox(P, V(x, 0.043, 0.014), V(0.058, 0.127, 0.014), None, 0.008)
        e = smin(e, rbox(P, V(x, -0.07, 0.022), V(0.052, 0.035, 0.022), None, 0.01), 0.004)  # heel
        d = e if d is None else np.minimum(d, e)
    return d


def toe_caps(P):
    d = None
    for s, side in SIDES:
        x = s * 0.095
        e = ellipsoid(P, V(x, 0.115, 0.042), V(0.058, 0.052, 0.044))
        e = smax(e, 0.095 - P[:, 1], 0.004)
        e = smax(e, 0.022 - P[:, 2], 0.002)
        d = e if d is None else np.minimum(d, e)
    return d


def jacket_outer(P, extra=0.0):
    d = smax(torso(P, 0.017 + extra), P[:, 2] - 1.44, 0.01)
    for s, side in SIDES:
        sh, el = J["shoulder." + side], J["elbow." + side]
        d = smin(d, ellipsoid(P, sh + V(s * 0.008, 0, -0.026), V(0.062, 0.063, 0.072) + extra), 0.03)
        d = smin(d, round_cone(P, sh, sh + (el - sh) * 0.9, 0.057 + extra, 0.049 + extra), 0.03)
    return d


def jacket_inner(P):
    d = torso(P, 0.007)
    for s, side in SIDES:
        sh, el = J["shoulder." + side], J["elbow." + side]
        d = smin(d, ellipsoid(P, sh + V(s * 0.008, 0, -0.026), V(0.053, 0.054, 0.063)), 0.03)
        d = smin(d, round_cone(P, sh - (el - sh) * 0.3, el + (el - sh) * 0.3, 0.049, 0.04), 0.03)
    return d


def jacket_open(P):
    """Open front: a V-shaped cut widening toward the cropped hem, and the neck."""
    w = 0.026 + np.maximum(0.0, 1.37 - P[:, 2]) * 0.24
    front = np.maximum(np.abs(P[:, 0]) - w, -P[:, 1])
    neckhole = round_cone(P, V(0, -0.01, 1.37), V(0, -0.01, 1.5), 0.05, 0.05)
    return np.minimum(front, neckhole)


def jacket_clip(P):
    d = 1.142 - P[:, 2]
    for s, side in SIDES:  # sleeve ends just above the elbow
        sh, el = J["shoulder." + side], J["elbow." + side]
        ax = norm(el - sh)
        cut = (P - (sh + (el - sh) * 0.8)) @ ax
        near = np.abs(P[:, 0]) > 0.11
        d = np.where(near, np.maximum(d, cut), d)
    return d


def jacket(P):
    d = smax(jacket_outer(P), -jacket_inner(P), 0.004)
    # back and shoulder seams, and a hem band
    d = smax(d, jacket_clip(P), 0.003)
    d = smax(d, -jacket_open(P), 0.004)
    return d


def jacket_trim(P):
    """Rolled sleeve cuffs, a thick hem band and the popped collar (darker)."""
    d = None
    for s, side in SIDES:
        sh, el = J["shoulder." + side], J["elbow." + side]
        a = sh + (el - sh) * 0.76
        b = sh + (el - sh) * 0.86
        cuff = smax(round_cone(P, a, b, 0.0565, 0.0545), -round_cone(P, a - (b - a), b + (b - a), 0.044, 0.042), 0.002)
        d = cuff if d is None else np.minimum(d, cuff)
    hem = smax(torso(P, 0.022), -torso(P, 0.008), 0.003)
    hem = smax(hem, np.maximum(1.142 - P[:, 2], P[:, 2] - 1.168), 0.003)
    hem = smax(hem, -jacket_open(P), 0.003)
    d = np.minimum(d, hem)
    col_out = round_cone(P, V(0, -0.012, 1.375), V(0, -0.006, 1.452), 0.076, 0.07)
    col_in = round_cone(P, V(0, -0.012, 1.3), V(0, -0.006, 1.5), 0.064, 0.062)
    col = smax(col_out, -col_in, 0.002)
    col = smax(col, 1.39 - P[:, 2], 0.004)
    vcut = np.maximum(np.abs(P[:, 0]) - (0.022 + np.maximum(0, P[:, 2] - 1.39) * 0.45), -P[:, 1])
    col = smax(col, -vcut, 0.003)
    return np.minimum(d, col)


def bandage(P):
    side, s = "L", -1.0
    el, wr = J["elbow." + side], J["wrist." + side]
    a = el + (wr - el) * 0.3
    b = el + (wr - el) * 0.78
    d = round_cone(P, a, b, 0.0335, 0.0285)
    ax = norm(b - a)
    t = (P - a) @ ax
    d -= 0.0013 * np.sin(t * 260.0)
    d = smax(d, -round_cone(P, a - ax * 0.05, b + ax * 0.05, 0.026, 0.021), 0.002)
    return d


# --- gear --------------------------------------------------------------------

def belt(P):
    """Worn low on the hips, dipping at the front, over the shorts' waistband."""
    zb = 0.962 - P[:, 1] * 0.06
    return np.maximum(np.abs(torso(P) - 0.0135) - 0.0045, np.abs(P[:, 2] - zb) - 0.0145)


def buckle(P):
    d = rbox(P, V(0, 0.115, 0.956), V(0.024, 0.006, 0.019), rot(V(1, 0, 0), -7), 0.004)
    d = smax(d, -rbox(P, V(0, 0.121, 0.956), V(0.014, 0.01, 0.009), rot(V(1, 0, 0), -7), 0.002), 0.001)
    return d


def pouches(P):
    d = rbox(P, V(0.188, -0.05, 0.922), V(0.022, 0.036, 0.042), rot(V(0, 0, 1), -25), 0.012)
    d = smin(d, rbox(P, V(0.192, -0.05, 0.957), V(0.025, 0.04, 0.012), rot(V(0, 0, 1), -25), 0.006), 0.004)
    # holster strapped to the bare right thigh
    R = rot(V(0, 1, 0), -6)
    d = np.minimum(d, rbox(P, V(0.187, 0.008, 0.6), V(0.016, 0.034, 0.07), R, 0.01))
    return d


def leather_dark(P):
    """Straps: crossbody strap (left shoulder to right hip), holster thigh strap,
    goggle strap is separate (on the head)."""
    thigh = leg(P, 1.0, "R")
    d = _band(thigh, P, 0.6, 0.009)
    d = np.minimum(d, capsule(P, V(0.158, 0.004, 0.952), V(0.182, 0.006, 0.675), 0.0065))  # drop strap
    for front in (True, False):
        pts = []
        for t in np.linspace(0, 1, 28):
            x = -0.115 + t * 0.235
            z = 1.4 - t * 0.43
            off = 0.013 + 0.011 * np.clip((z - 0.97) / 0.18, 0, 1)
            pts.append(_on_torso(V(x, 1.0 if front else -1.0, z), off))
        for k in range(len(pts) - 1):
            d = np.minimum(d, capsule(P, pts[k], pts[k + 1], 0.0075))
    top_f = _on_torso(V(-0.115, 1.0, 1.4), 0.024)
    top_b = _on_torso(V(-0.115, -1.0, 1.4), 0.024)
    d = np.minimum(d, capsule(P, top_f, V(-0.125, -0.012, 1.432), 0.0075))
    d = np.minimum(d, capsule(P, top_b, V(-0.125, -0.012, 1.432), 0.0075))
    return d


def _on_torso(p, offset):
    """Push a point along Y from the body axis until it sits `offset` above the torso."""
    y_sign = np.sign(p[1])
    lo, hi = 0.0, 0.25
    for _ in range(40):
        mid = (lo + hi) / 2
        q = V(p[0], y_sign * mid, p[2])[None]
        if torso(q)[0] < offset:
            lo = mid
        else:
            hi = mid
    return V(p[0], y_sign * lo, p[2])


def shoulder_plate(P):
    c = V(-0.19, -0.012, 1.392)
    R = rot(V(0, 1, 0), 22)
    e = ellipsoid(P, c, V(0.074, 0.088, 0.05), R)
    d = shell(e, 0.0045)
    d = smax(d, -plane(P, c + V(0, 0, -0.012), R @ V(0, 0, 1)) , 0.003)
    return d


def plate_stripe(P):
    c = V(-0.19, -0.012, 1.392)
    R = rot(V(0, 1, 0), 22)
    e = ellipsoid(P, c, V(0.0765, 0.0905, 0.0525), R)
    d = shell(e, 0.002)
    d = smax(d, -plane(P, c + V(0, 0, -0.01), R @ V(0, 0, 1)), 0.002)
    d = smax(d, np.abs((P - c) @ (R @ V(0, 1, 0)) - 0.015) - 0.012, 0.002)
    return d


def metal(P):
    d = None
    # rivets on the shoulder plate
    c = V(-0.19, -0.012, 1.392)
    R = rot(V(0, 1, 0), 22)
    for ang in (-60, -20, 20, 60):
        a = np.radians(ang)
        p = c + R @ V(0.066 * np.cos(a) * 0.0 + 0.0, 0.0, 0.0)
        q = c + R @ V(-0.045, 0.075 * np.sin(a), 0.03)
        e = sphere(P, q, 0.0045)
        d = e if d is None else np.minimum(d, e)
    # wrench hanging on the left hip
    w0, w1 = V(-0.176, 0.03, 0.952), V(-0.213, 0.035, 0.81)
    ax = norm(w1 - w0)
    d = np.minimum(d, rbox(P, (w0 + w1) / 2, V(0.004, 0.01, 0.078), _frame(ax, V(1, 0, 0)), 0.003))
    head = cylinder(P, w1 - V(0.005, 0, 0), w1 + V(0.005, 0, 0), 0.022)
    head = smax(head, -cylinder(P, w1 - V(0.01, 0, 0), w1 + V(0.01, 0, 0), 0.011), 0.002)
    head = smax(head, -rbox(P, w1 + V(0, 0, -0.02), V(0.012, 0.009, 0.02)), 0.002)
    d = np.minimum(d, head)
    # pistol grip in the holster, and the buckle prong
    d = np.minimum(d, rbox(P, V(0.187, -0.004, 0.69), V(0.012, 0.02, 0.032), rot(V(1, 0, 0), -14), 0.006))
    return d


def rag(P):
    c = V(0.072, -0.148, 0.88)
    q = P - c
    sheet = np.abs(q[:, 1] - 0.006 * np.sin(q[:, 0] * 90) + 0.01 * (q[:, 2] / 0.08) ** 2) - 0.0025
    box = np.maximum(np.abs(q[:, 0]) - 0.028 - q[:, 2] * -0.08, np.abs(q[:, 2] + 0.02) - 0.07)
    return np.maximum(sheet, box)


GOG_C = {s: V(s * 0.034, 0.07, 1.664) for s, _ in SIDES}
GOG_AX = norm(V(0, 0.55, 0.84))


def goggle_rims(P):
    d = None
    for s, _ in SIDES:
        c = GOG_C[s]
        e = cylinder(P, c - GOG_AX * 0.012, c + GOG_AX * 0.012, 0.025)
        e = smax(e, -cylinder(P, c - GOG_AX * 0.02, c + GOG_AX * 0.02, 0.019), 0.002)
        d = e if d is None else np.minimum(d, e)
    d = np.minimum(d, capsule(P, GOG_C[1.0] - V(0.014, 0, 0), GOG_C[-1.0] + V(0.014, 0, 0), 0.006))
    return d


def goggle_lenses(P):
    d = None
    for s, _ in SIDES:
        c = GOG_C[s] + GOG_AX * 0.004
        e = ellipsoid(P, c, V(0.0195, 0.0195, 0.006), _frame(GOG_AX, V(1, 0, 0)))
        d = e if d is None else np.minimum(d, e)
    return d


def goggle_strap(P):
    front = V(0, 0.05, 1.655)
    back = V(0, -0.105, 1.575)
    c = (front + back) / 2 + V(0, 0.0, 0.0)
    axis_y = norm(front - back)
    R = np.column_stack([V(1, 0, 0), axis_y, np.cross(V(1, 0, 0), axis_y)])
    return ring(P, c, R, 0.098, 0.093, 0.0035, 0.009)


# --- first-person arm (Godot axes: X right, Y up, -Z forward; pistol space) ----

FP_GRIP_C = V(0, -0.088, 0.072)
FP_A = V(0, np.cos(np.radians(16)), -np.sin(np.radians(16)))    # up the grip
FP_F = -V(0, np.sin(np.radians(16)), np.cos(np.radians(16)))    # forward out of the grip
FP_X = V(1, 0, 0)
FP_WRIST = V(0.02, -0.142, 0.138)
FP_ARM_DIR = norm(V(0.09, -0.58, 0.81))


def fp_fingers():
    c, A, F, X = FP_GRIP_C, FP_A, FP_F, FP_X
    chains = []
    # middle, ring and little fingers wrap round the front of the grip
    for a, r in ((0.012, 0.0092), (-0.012, 0.0088), (-0.034, 0.0078)):
        k = c + X * 0.03 + F * 0.004 + A * a
        p1 = k + norm(F * 0.85 - X * 0.15) * 0.03
        p2 = p1 + norm(-X * 0.9 + F * 0.15) * 0.026
        p3 = p2 + norm(-X * 0.35 - F * 0.9) * 0.017
        chains.append(([k, p1, p2, p3], [r, r * 0.92, r * 0.85, r * 0.75]))
    # index finger along the frame onto the trigger
    k = c + X * 0.03 + F * 0.006 + A * 0.036
    p1 = k + norm(F * 0.9 + A * 0.1 - X * 0.1) * 0.032
    p2 = p1 + norm(F * 0.5 - X * 0.85) * 0.022
    p3 = p2 + norm(-X * 0.6 - F * 0.5 - A * 0.3) * 0.016
    chains.append(([k, p1, p2, p3], [0.0095, 0.0088, 0.008, 0.007]))
    # thumb over the back strap and along the left side
    b = c + X * 0.02 - F * 0.034 + A * 0.0
    p1 = b + norm(A * 0.55 - X * 0.6 + F * 0.2) * 0.036
    p2 = p1 + norm(F * 0.8 + A * 0.2 - X * 0.15) * 0.03
    chains.append(([b, p1, p2], [0.0125, 0.0105, 0.009]))
    return chains


def fp_palm(P, grow=0.0):
    c, A, F, X = FP_GRIP_C, FP_A, FP_F, FP_X
    R = np.column_stack([X, A, F]) @ rot(V(0, 1, 0), -38)
    R = rot(A, -38) @ np.column_stack([X, A, F])
    return rbox(P, c + X * 0.03 - F * 0.016 - A * 0.012, V(0.016, 0.05, 0.034) + grow, R, 0.012 + grow * 0.5)


def fp_hand(P):
    d = fp_palm(P)
    for pts, radii in fp_fingers():
        for k in range(len(pts) - 1):
            d = smin(d, round_cone(P, pts[k], pts[k + 1], radii[k], radii[k + 1]), 0.007)
    d = smin(d, round_cone(P, FP_WRIST, FP_WRIST + FP_ARM_DIR * 0.3, 0.026, 0.036), 0.018)
    return d


def fp_glove(P):
    d = fp_palm(P, 0.0035)
    for pts, radii in fp_fingers():
        mid = pts[0] + (pts[1] - pts[0]) * 0.55
        d = smin(d, round_cone(P, pts[0], mid, radii[0] + 0.003, radii[0] + 0.0026), 0.006)
    d = smin(d, round_cone(P, FP_WRIST - FP_ARM_DIR * 0.012, FP_WRIST + FP_ARM_DIR * 0.045, 0.03, 0.032), 0.01)
    return d


def fp_sleeve(P):
    a = FP_WRIST + FP_ARM_DIR * 0.3
    b = FP_WRIST + FP_ARM_DIR * 0.4
    return smax(round_cone(P, a, b, 0.05, 0.054), -round_cone(P, a - FP_ARM_DIR * 0.05, b + FP_ARM_DIR * 0.05, 0.034, 0.038), 0.002)


FP_PARTS = {
    "fp_hand": (fp_hand, V(-0.06, -0.33, -0.02), V(0.09, 0.0, 0.42), 0.0015, 5000),
    "fp_glove": (fp_glove, V(-0.06, -0.2, -0.02), V(0.09, 0.0, 0.24), 0.0015, 3500),
    "fp_sleeve": (fp_sleeve, V(-0.05, -0.36, 0.26), V(0.13, -0.17, 0.48), 0.002, 1200),
}


# --- part list and meshing ------------------------------------------------------

def visible_body(P):
    return body(P)


def skin_cut(verts):
    """True for body vertices hidden under clothes (cut from the body mesh)."""
    hidden = (sports_bra(verts) < 0.004) | (shorts(verts) < 0.006) | (socks(verts) < 0.003)
    for s, side in SIDES:
        hidden |= boot(verts, s, side) < 0.004
    hidden |= (jacket_outer(verts) < 0.0) & (jacket_open(verts) > 0.0) & (verts[:, 2] > 1.15)
    # upper arms under the sleeves
    for s, side in SIDES:
        sh, el = J["shoulder." + side], J["elbow." + side]
        hidden |= (round_cone(verts, sh, sh + (el - sh) * 0.78, 0.06, 0.05) < 0.0) & (np.abs(verts[:, 0]) > 0.14)
    hidden &= ~(verts[:, 2] > 1.43)  # keep the neck
    # forearms stay visible below the rolled sleeves
    for s, side in SIDES:
        sh, el = J["shoulder." + side], J["elbow." + side]
        ax = norm(el - sh)
        beyond = ((verts - (sh + (el - sh) * 0.8)) @ ax) > 0.0
        hidden &= ~(beyond & (np.abs(verts[:, 0]) > 0.15) & (verts[:, 2] > 0.75))
    return hidden


def _box(points, pad):
    pts = np.array(points)
    return pts.min(0) - pad, pts.max(0) + pad


R_HAND = {side: _box([J["wrist." + side], J["hand_end." + side]], 0.075) for _, side in SIDES}

PARTS = {
    # name: (sdf, lo, hi, voxel size, target triangles)
    "body": (visible_body, V(-0.36, -0.2, -0.01), V(0.36, 0.2, 1.52), 0.003, 15000),
    "head": (head, V(-0.11, -0.13, 1.37), V(0.11, 0.13, 1.69), 0.0018, 6500),
    "lashes": (eyelash, V(-0.08, 0.05, 1.53), V(0.08, 0.1, 1.58), 0.0007, 600),
    "hair": (hair, V(-0.17, -0.18, 1.42), V(0.18, 0.21, 1.75), 0.0015, 22000),
    "hand_R": (lambda P: hand(P, 1.0, "R"), *R_HAND["R"], 0.0018, 2600),
    "hand_L": (lambda P: hand(P, -1.0, "L"), *R_HAND["L"], 0.0018, 2600),
    "glove_R": (lambda P: glove(P, 1.0, "R"), *R_HAND["R"], 0.0018, 2500),
    "glove_L": (lambda P: glove(P, -1.0, "L"), *R_HAND["L"], 0.0018, 2500),
    "bra": (sports_bra, V(-0.2, -0.13, 1.11), V(0.2, 0.14, 1.43), 0.0025, 4500),
    "shorts": (shorts, V(-0.25, -0.2, 0.72), V(0.25, 0.17, 1.03), 0.0025, 6500),
    "socks": (socks, V(-0.16, -0.1, 0.24), V(0.16, 0.08, 0.33), 0.002, 1800),
    "knee_pads": (knee_pads, V(-0.17, -0.08, 0.38), V(0.17, 0.13, 0.56), 0.0022, 3000),
    "boots": (lambda P: np.minimum(boot(P, 1.0, "R"), boot(P, -1.0, "L")), V(-0.18, -0.1, 0.0), V(0.18, 0.18, 0.29), 0.0028, 4000),
    "soles": (soles, V(-0.18, -0.12, -0.01), V(0.18, 0.2, 0.06), 0.0025, 1500),
    "toe_caps": (toe_caps, V(-0.18, 0.06, 0.0), V(0.18, 0.2, 0.1), 0.0022, 1200),
    "jacket": (jacket, V(-0.29, -0.14, 1.1), V(0.29, 0.15, 1.47), 0.0028, 7000),
    "jacket_trim": (jacket_trim, V(-0.29, -0.14, 1.1), V(0.29, 0.15, 1.47), 0.0024, 3000),
    "bandage": (bandage, V(-0.36, -0.06, 0.88), V(-0.18, 0.1, 1.15), 0.0018, 1500),
    "belt": (belt, V(-0.2, -0.17, 0.93), V(0.2, 0.15, 0.99), 0.0022, 2000),
    "buckle": (buckle, V(-0.04, 0.09, 0.925), V(0.04, 0.14, 0.985), 0.0012, 400),
    "pouches": (pouches, V(0.12, -0.11, 0.51), V(0.25, 0.07, 0.99), 0.0025, 1500),
    "straps": (leather_dark, V(-0.2, -0.16, 0.53), V(0.22, 0.16, 1.46), 0.0025, 3000),
    "plate": (shoulder_plate, V(-0.29, -0.12, 1.3), V(-0.1, 0.1, 1.46), 0.0018, 2000),
    "plate_stripe": (plate_stripe, V(-0.29, -0.12, 1.3), V(-0.1, 0.1, 1.46), 0.0018, 600),
    "metal": (metal, V(-0.26, -0.12, 0.64), V(0.25, 0.08, 1.44), 0.0018, 2000),
    "rag": (rag, V(0.02, -0.19, 0.77), V(0.13, -0.11, 0.95), 0.0018, 600),
    "goggle_rims": (goggle_rims, V(-0.08, 0.02, 1.63), V(0.08, 0.1, 1.71), 0.0012, 1500),
    "goggle_lenses": (goggle_lenses, V(-0.07, 0.03, 1.64), V(0.07, 0.1, 1.71), 0.0012, 400),
    "goggle_strap": (goggle_strap, V(-0.13, -0.15, 1.52), V(0.13, 0.11, 1.7), 0.0018, 1500),
}


def mesh_part(fn, lo, hi, res):
    lo = np.asarray(lo, float)
    hi = np.asarray(hi, float)
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


def hair_lock_shade(verts):
    """A random shade per lock for each hair vertex (the lock it is nearest
    to), so the build can tint locks apart instead of one smooth mass."""
    strands = _STRANDS or hair_strands()
    shades = np.random.default_rng(11).uniform(0, 1, len(strands))
    best = np.full(len(verts), np.inf)
    out = np.full(len(verts), 0.5)
    for i, (pts, radii, _) in enumerate(strands):
        for k in range(len(pts) - 1):
            # distance relative to the lock's thickness there
            dd = seg_dist_np(verts, pts[k], pts[k + 1]) / max(radii[k], 0.003)
            m = dd < best
            best[m] = dd[m]
            out[m] = shades[i]
    out[best > 6.0] = 0.5  # the scalp cap between locks
    return out


def seg_dist_np(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    only = [a for a in sys.argv[2:] if a != "--fp"]
    fp = "--fp" in sys.argv
    for name, (fn, lo, hi, res, tris) in (FP_PARTS if fp else PARTS).items():
        if only and name not in only:
            continue
        t = time.time()
        v, f = mesh_part(fn, lo, hi, res)
        if fp:  # Godot axes to Blender axes, so the glTF export maps them back
            v = np.stack([v[:, 0], -v[:, 2], v[:, 1]], 1)
        if name == "body":
            hidden = skin_cut(v)
            keep = ~hidden[f].all(1)
            f = f[keep]
        extra = {"lock": hair_lock_shade(v)} if name == "hair" else {}
        np.savez(out / f"{name}.npz", verts=v, faces=f, target=tris, **extra)
        print(f"{name}: {len(v)} verts {len(f)} faces ({time.time() - t:.1f}s)", flush=True)


if __name__ == "__main__":
    main()
