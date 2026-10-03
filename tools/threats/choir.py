"""The Choir: the foreign enemy faction. Run:
blender -b -P choir.py -- <unit> <outdir> [views...]"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import bpy
import kit
from mathutils import Vector as V
from kit import (Blob, strip, slab, box, cone, ell, ell_between, mat, rod, spike, stripes, torus,
                 reset, stage, setup_render, shot, silhouette)


def piv(name):
    """Tags what gets built next with the rigid part it hangs on in game (or None)."""
    kit.PIVOT = name


def mats():
    M = {}
    M["porc"] = mat("porcelain", (0.74, 0.7, 0.62), rough=0.22, coat=0.6, sss=0.04,
                    noise=((0.6, 0.55, 0.48), 3.0))
    M["porc_dirty"] = mat("porcelain_dirty", (0.8, 0.75, 0.68), rough=0.35, coat=0.4,
                          noise=((0.45, 0.38, 0.33), 4.0))
    M["sinew"] = stripes("sinew", (0.07, 0.07, 0.085), (0.15, 0.145, 0.17), axis="Z", scale=30,
                         rough=0.32, bump=0.25, warp=0.6)
    M["black"] = mat("black", (0.07, 0.07, 0.085), rough=0.25, coat=0.5)
    M["gold"] = mat("gold", (0.85, 0.6, 0.28), rough=0.28, metal=1.0)
    M["glow"] = mat("glow", (0.6, 0.95, 1.0), emit=(0.55, 0.95, 1.0), strength=30)
    M["glow_soft"] = mat("glow_soft", (0.6, 0.95, 1.0), emit=(0.45, 0.85, 1.0), strength=8)
    M["cloth"] = mat("cloth", (0.45, 0.06, 0.08), rough=0.85, sss=0.1,
                     noise=((0.07, 0.006, 0.01), 6.0), bump=0.15, bump_scale=120)
    M["blood"] = mat("blood", (0.18, 0.01, 0.01), rough=0.3)
    return M


def hand(M, wrist, fwd, s, curl=0.6, n=3, length=0.13):
    """Long three-fingered hand: palm toward fwd, fingers curled by curl."""
    wrist, fwd = V(wrist), V(fwd).normalized()
    side = fwd.cross(V((0, 0, 1))).normalized() * s
    if side.length < 0.1:
        side = V((s, 0, 0))
    palm = wrist + fwd * 0.05
    ell_between(wrist, wrist + fwd * 0.1, 0.035, 0.022, M["black"])
    for i in range(n):
        o = (i - (n - 1) / 2) * 0.022
        base = palm + side * o + fwd * 0.04
        mid = base + fwd * length * 0.5 + V((0, 0, -1)) * curl * 0.02
        tip = mid + (fwd * (1 - curl) + V((0, 0, -1)) * curl).normalized() * length * 0.5
        rod(base, mid, 0.011, 0.009, M["black"], seg=10)
        rod(mid, tip, 0.009, 0.004, M["porc"], seg=10)
    rod(wrist + fwd * 0.04 - side * 0.03, wrist + fwd * 0.09 - side * 0.05 + V((0, 0, -0.03)),
        0.011, 0.006, M["black"], seg=10)


def digi_leg(M, b, s, hip, knee, ankle, ball, r=(0.1, 0.065, 0.055, 0.04, 0.035), toe=0.16):
    b.line(hip, knee, r[0], r[1])
    b.line(knee, ankle, r[2], r[3])
    b.line(ankle, ball, r[3], r[4])
    ell_between(V(hip) + V((0, -0.03, 0)), knee, r[0] * 0.8, r[0] * 0.7, M["porc"], over=0.95)
    ell_between(knee, ankle, r[2] * 0.9, r[2] * 1.05, M["porc"], over=0.9)
    ell(knee, (r[1] * 0.75,) * 3, M["gold"])
    for i, a in enumerate((-22, 0, 22)):
        d = V((math.sin(math.radians(a)) * 0.6 + s * 0.05, -1, -0.1)).normalized()
        tip = V(ball) + d * toe
        rod(ball, tip, 0.024, 0.014, M["black"], seg=12)
        cone(tip, tip + d * 0.07 + V((0, 0, -0.03)), 0.015, M["porc"], seg=12)
    cone(V(ankle) + V((0, 0.0, 0.0)), V(ankle) + V((0, 0.12, -0.12)), 0.022, M["porc"])


def hush(M, at=V((0, 0, 0)), pose="ready", rifle=True, crest=True, tilt=12):
    """Rank-and-file Choir soldier, ~2.35 m. Porcelain shell over black synthetic sinew,
    gaunt and stooped, head pushed forward on a long neck."""
    o = V(at)
    b = Blob("hush_body", res=0.011)
    # torso: narrow pelvis, wasp waist, deep ribcage tipped forward
    b.ellip(o + V((0, 0.02, 1.14)), 0.15, (1.0, 0.7, 0.7))
    b.line(o + V((0, 0.02, 1.16)), o + V((0, 0.0, 1.44)), 0.085, 0.09)
    b.ellip(o + V((0, -0.02, 1.62)), 0.19, (0.95, 0.62, 1.0), rot=(-12, 0, 0))
    neck = [o + V((0, -0.02, 1.76)), o + V((0, -0.08, 1.98)), o + V((0, -0.14, 2.1))]
    b.path(neck, [0.05, 0.04, 0.036])
    for s in (1, -1):
        b.ellip(o + V((s * 0.2, -0.02, 1.74)), 0.08, (1.2, 0.8, 0.6))
        digi_leg(M, b, s, o + V((s * 0.11, 0.02, 1.1)), o + V((s * 0.14, -0.2, 0.74)),
                 o + V((s * 0.14, 0.14, 0.34)), o + V((s * 0.14, -0.04, 0.05)),
                 r=(0.085, 0.055, 0.05, 0.035, 0.03), toe=0.17)
    # arms: low ready, needle rifle angled at the ground ahead
    piv("Torso")
    rh, lh = o + V((0.15, -0.3, 1.26)), o + V((-0.1, -0.52, 1.16))
    arms = {1: [(0.27, -0.02, 1.76), (0.33, 0.04, 1.45), tuple(rh)],
            -1: [(-0.27, -0.02, 1.76), (-0.34, -0.14, 1.42), tuple(lh)]}
    if pose == "point":  # reaches for you with the free hand, fingers splayed
        arms[-1] = [(-0.27, -0.02, 1.76), (-0.38, -0.34, 1.66), (-0.42, -0.72, 1.62)]
    if pose == "hang":
        arms = {s: [(s * 0.27, -0.02, 1.76), (s * 0.35, 0.0, 1.4), (s * 0.38, -0.06, 1.02)] for s in (1, -1)}
    for s, (sh, el, wr) in arms.items():
        sh, el, wr = o + V(sh), o + V(el), o + V(wr)
        b.line(sh, el, 0.05, 0.04)
        b.line(el, wr, 0.04, 0.03)
        ell_between(sh + (el - sh) * 0.15, el, 0.05, 0.045, M["porc"], over=0.8)
        ell_between(el + (wr - el) * 0.12, wr, 0.042, 0.038, M["porc"], over=0.85)
        cone(el, el + (el - sh).normalized() * 0.05 + (el - wr).normalized() * 0.07, 0.03, M["porc"])
        opened = pose == "hang" or (pose == "point" and s == -1)
        hand(M, wr, wr - el, s, curl=0.1 if opened else 0.75, length=0.2 if opened else 0.14)
        # petal pauldrons: three thin overlapping blades swept down and back
        for k in range(3):
            c = sh + V((s * (0.03 + k * 0.035), 0.03 * k, 0.03 - k * 0.055))
            ell(c, (0.12 - k * 0.012, 0.085, 0.018), M["porc"], rot=(-10 * k, s * (-30 - k * 14), 0))
        torus(sh + V((s * 0.03, 0, 0.03)), 0.105, 0.005, M["gold"], rot=(0, s * -30, 0))
    piv(None)
    b.mesh(M["sinew"], name="Hush")
    # ribcage: sternum keel + rib slats that let the black show through
    ell(o + V((0, -0.135, 1.62)), (0.022, 0.03, 0.15), M["porc"], rot=(-14, 0, 0))
    ell(o + V((0, -0.08, 1.73)), (0.17, 0.08, 0.06), M["porc"], rot=(-14, 0, 0))
    for i in range(5):
        z = 1.66 - i * 0.065
        for s in (1, -1):
            ell(o + V((s * 0.085, -0.1 + i * 0.012, z)), (0.095 - i * 0.008, 0.035, 0.016),
                M["porc"], rot=(-14, s * (12 + i * 6), s * -28))
    ell(o + V((0, 0.08, 1.64)), (0.16, 0.07, 0.15), M["porc"], rot=(12, 0, 0))
    ell(o + V((0, 0.1, 1.34)), (0.03, 0.05, 0.14), M["porc"])  # spine ridge
    ell(o + V((0, -0.0, 1.14)), (0.15, 0.12, 0.075), M["porc"])
    torus(o + V((0, -0.06, 1.8)), 0.06, 0.007, M["gold"], rot=(-25, 0, 0))
    torus(o + V((0, 0.0, 1.14)), 0.152, 0.005, M["gold"])
    # crimson tabard front and back, torn ragged
    piv("Hips")
    strip(o + V((0, -0.12, 1.12)), 0.2, 0.62, M["cloth"], bulge=0.03, tilt=4, seed=1)
    strip(o + V((0, 0.12, 1.14)), 0.24, 0.7, M["cloth"], bulge=-0.03, tilt=-8, seed=2)
    # head: tall blank porcelain mask with brow and cheek planes, one vertical slit of light
    piv("Head")
    hc = o + V((0, -0.17, 2.18))
    hr = (8, tilt, 0)
    head = []
    head.append(ell(hc, (0.088, 0.1, 0.16), M["porc"], rot=hr))
    head.append(ell(hc + V((0, 0.06, 0.03)), (0.08, 0.09, 0.13), M["black"], rot=(-20, tilt, 0)))
    head.append(ell(hc + V((0, -0.035, 0.035)), (0.09, 0.07, 0.025), M["porc"], rot=hr))  # brow
    for s in (1, -1):
        head.append(ell(hc + V((s * 0.045, -0.055, -0.04)), (0.035, 0.04, 0.06), M["porc"],
                        rot=(8, tilt, s * 20)))
    head.append(ell(hc + V((0, -0.002, -0.005)), (0.007, 0.108, 0.12), M["glow"], rot=hr))
    if crest:  # sweeping crest and a spiked halo behind the head
        spike(hc + V((0, 0.03, 0.12)), hc + V((0, 0.42, 0.02)), 0.045, M["porc"], curve=0.12)
        hal = hc + V((0, 0.14, 0.04))
        torus(hal, 0.22, 0.011, M["gold"], rot=(90 - 8, tilt, 0))
        for k in range(12):
            a = math.radians(k * 30 + 15)
            d = V((math.cos(a), 0, math.sin(a)))
            d.rotate(V((math.radians(-8), 0, 0)).__class__((0, 0, 0)).to_track_quat("Z", "Y")) if False else None
            cone(hal + d * 0.22, hal + d * (0.32 if k % 2 else 0.27), 0.013, M["gold"], seg=8)
    piv("Torso")
    if rifle and pose in ("ready", "point"):
        d = (lh - rh).normalized()
        st, mz = rh - d * 0.34, rh + d * 1.3
        ell_between(st, rh + d * 0.36, 0.032, 0.05, M["porc"], name="rifle")
        rod(rh + d * 0.2, mz, 0.013, 0.009, M["black"], seg=12)
        ell_between(rh + d * 0.32, rh + d * 0.74, 0.026, 0.028, M["porc"])
        for t in (0.42, 0.55, 0.68, 0.95, 1.12):
            torus(rh + d * t, 0.02, 0.005, M["gold"]).rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        ell(rh + d * 0.05 + V((0, 0, 0.045)), (0.012, 0.012, 0.012), M["glow"])
        rod(rh + d * 0.2 + V((0, 0, 0.03)), rh + d * 0.52 + V((0, 0, 0.03)), 0.007, 0.007,
            M["glow_soft"], seg=8)
        cone(mz, mz + d * 0.07, 0.011, M["gold"], seg=8)
    piv(None)


def hound(M, at=V((0, 0, 0))):
    """Quadruped synthetic hunter. Eyeless, hunts by sound; scythe forelimbs."""
    o = V(at)
    b = Blob("hound_body", res=0.014)
    # spine from hips (back, +Y) to shoulders (front, -Y): crouched, head low
    spine = [o + V((0, 0.75, 0.85)), o + V((0, 0.35, 0.95)), o + V((0, -0.05, 1.02)),
             o + V((0, -0.42, 0.98))]
    b.path(spine, [0.17, 0.15, 0.2, 0.17])
    b.ellip(o + V((0, -0.15, 0.95)), 0.22, (0.8, 1.2, 0.9))
    b.ellip(o + V((0, 0.55, 0.85)), 0.18, (0.9, 1.0, 0.85))
    neck = [o + V((0, -0.45, 1.0)), o + V((0, -0.72, 0.92)), o + V((0, -0.9, 0.78))]
    b.path(neck, [0.12, 0.08, 0.07])
    for s in (1, -1):
        # forelimbs end in long blades instead of feet
        sh, el, wr = o + V((s * 0.16, -0.38, 0.92)), o + V((s * 0.26, -0.55, 0.58)), o + V((s * 0.24, -0.5, 0.2))
        b.line(sh, el, 0.09, 0.055)
        b.line(el, wr, 0.05, 0.04)
        ell_between(sh, el, 0.08, 0.07, M["porc"], over=0.8)
        ell_between(el, wr, 0.055, 0.05, M["porc"], over=0.85)
        spike(wr, wr + V((s * 0.03, -0.52, -0.12)), 0.03, M["porc"], curve=0.12,
              side=V((0, 0, 1)))
        rod(wr, wr + V((0, -0.06, -0.18)), 0.03, 0.02, M["black"], seg=10)
        ell(el, (0.05,) * 3, M["gold"])
        # hind legs: digitigrade, springy
        hip, kn, an, ba = (o + V((s * 0.15, 0.62, 0.8)), o + V((s * 0.2, 0.42, 0.52)),
                           o + V((s * 0.2, 0.78, 0.26)), o + V((s * 0.2, 0.62, 0.04)))
        b.line(hip, kn, 0.12, 0.07)
        b.line(kn, an, 0.06, 0.045)
        b.line(an, ba, 0.045, 0.035)
        ell_between(hip, kn, 0.11, 0.09, M["porc"], over=0.85)
        ell_between(kn, an, 0.055, 0.06, M["porc"], over=0.9)
        for a in (-20, 0, 20):
            d = V((math.sin(math.radians(a)) * 0.6, -1, -0.15)).normalized()
            rod(ba, ba + d * 0.12, 0.022, 0.012, M["black"], seg=10)
            cone(ba + d * 0.12, ba + d * 0.18 + V((0, 0, -0.03)), 0.013, M["porc"], seg=10)
    # tail: segmented cable ending in a blade
    tail = [o + V((0, 0.8, 0.85)), o + V((0, 1.15, 0.95)), o + V((0, 1.45, 1.15)),
            o + V((0, 1.6, 1.45))]
    b.path(tail, [0.07, 0.05, 0.035, 0.025])
    b.mesh(M["sinew"], name="Hound")
    piv("Tail")
    for i, (p, r) in enumerate(zip([o + V((0, 0.9 + i * 0.18, 0.88 + i * 0.07)) for i in range(4)],
                                   (0.05, 0.045, 0.04, 0.035))):
        torus(p, r, 0.01, M["gold"], rot=(-60 - i * 10, 0, 0))
    cone(tail[-1], tail[-1] + V((0, 0.05, 0.38)), 0.03, M["porc"])
    piv(None)
    # porcelain spine plates, overlapping like a pangolin
    for i in range(9):
        t = i / 8
        y = 0.7 - t * 1.15
        z = 0.96 + math.sin(t * math.pi) * 0.14 + 0.06
        ell(o + V((0, y, z + 0.05)), (0.12 - abs(t - 0.6) * 0.05, 0.12, 0.04), M["porc"],
            rot=(-14, 0, 0))
        if i % 2 == 0:
            torus(o + V((0, y, z + 0.07)), 0.09, 0.005, M["gold"], rot=(-14, 0, 0))
    # head: long eyeless skull with a fan of glowing sensor vanes (it listens)
    piv("Head")
    hc = o + V((0, -1.0, 0.74))
    back, snout = hc + V((0, 0.1, 0.07)), hc + V((0, -0.3, -0.1))
    ell_between(back, snout, 0.085, 0.075, M["porc"], over=1.0)
    ell_between(hc + V((0, 0.02, -0.03)), snout + V((0, 0.03, -0.07)), 0.06, 0.04, M["black"])
    ell_between(back + V((0, 0, 0.03)), snout + V((0, 0.02, 0.06)), 0.01, 0.01, M["glow"], over=0.9)
    for k in range(6):  # needle teeth along the jaw
        t = 0.2 + k * 0.13
        p = (hc + V((0, 0.02, -0.03))).lerp(snout + V((0, 0.03, -0.07)), t)
        for s_ in (1, -1):
            cone(p + V((s_ * 0.045 * (1 - t * 0.5), 0, 0.0)), p + V((s_ * 0.045 * (1 - t * 0.5), -0.01, -0.07)),
                 0.008, M["porc"], seg=8)
    for s_ in (1, -1):
        for k in range(4):
            a_ = math.radians(15 + k * 24)
            root = hc + V((s_ * 0.06, 0.08, 0.04))
            tip = root + V((s_ * math.cos(a_) * 0.3, 0.14 + k * 0.03, math.sin(a_) * 0.3))
            spike(root, tip, 0.02, M["porc"], curve=0.04, side=V((0, 1, 0)))
            ell(root.lerp(tip, 0.55), (0.011,) * 3, M["glow"])
    piv(None)


def cantor(M, at=V((0, 0, 0))):
    """Heavy: hunched 3.2 m siege unit. Organ-pipe crown, a sonic emitter in the gut, slab shield."""
    o = V(at)
    b = Blob("cantor_body", res=0.018)
    b.ellip(o + V((0, 0.08, 1.55)), 0.27, (1.0, 0.8, 0.75))
    b.line(o + V((0, 0.06, 1.6)), o + V((0, -0.1, 2.0)), 0.22, 0.3)
    b.ellip(o + V((0, -0.12, 2.2)), 0.42, (1.05, 0.7, 0.75), rot=(-20, 0, 0))
    for s in (1, -1):
        b.ellip(o + V((s * 0.45, -0.12, 2.38)), 0.22, (1.0, 0.9, 0.8))
        digi_leg(M, b, s, o + V((s * 0.22, 0.08, 1.5)), o + V((s * 0.32, -0.32, 1.0)),
                 o + V((s * 0.32, 0.2, 0.48)), o + V((s * 0.32, -0.04, 0.08)),
                 r=(0.18, 0.12, 0.11, 0.075, 0.065), toe=0.26)
    # right arm: long, ends in a great three-fingered claw; left arm braces the shield
    piv("Torso")
    sh, el, wr = o + V((0.6, -0.12, 2.36)), o + V((0.78, -0.2, 1.72)), o + V((0.74, -0.42, 1.12))
    b.line(sh, el, 0.14, 0.11)
    b.line(el, wr, 0.11, 0.09)
    ell_between(sh, el, 0.15, 0.14, M["porc_dirty"], over=0.8)
    ell_between(el, wr, 0.13, 0.13, M["porc_dirty"], over=0.9)
    ell(el, (0.08,) * 3, M["gold"])
    ell_between(wr, wr + V((0, -0.08, -0.12)), 0.1, 0.08, M["black"])
    for k, a_ in enumerate((-30, 0, 30)):
        base = wr + V((math.sin(math.radians(a_)) * 0.08, -0.06, -0.1))
        tip = base + V((math.sin(math.radians(a_)) * 0.15, -0.28, -0.32))
        spike(base, tip, 0.04, M["porc_dirty"], curve=0.1, side=V((0, -1, 0)))
    shL, elL, wrL = o + V((-0.6, -0.12, 2.36)), o + V((-0.74, -0.42, 1.95)), o + V((-0.6, -0.72, 1.72))
    b.line(shL, elL, 0.14, 0.11)
    b.line(elL, wrL, 0.11, 0.09)
    ell_between(shL, elL, 0.15, 0.14, M["porc_dirty"], over=0.8)
    piv(None)
    b.mesh(M["sinew"], name="Cantor")
    piv("Torso")
    # shield: a coffin-shaped slab with a gold rim and a mask set in it
    sc = o + V((-0.58, -0.86, 1.5))
    out = [(0, 1.05), (0.42, 0.72), (0.34, -0.95), (0, -1.1), (-0.34, -0.95), (-0.42, 0.72)]
    slab(sc + V((0, 0.03, 0)), [(x * 1.06, z * 1.04) for x, z in out], 0.08, M["gold"], rot=(0, 0, 8))
    slab(sc, out, 0.1, M["porc_dirty"], rot=(0, 0, 8), bevel=0.03)
    mc = sc + V((-0.05, -0.07, 0.42))
    ell(mc, (0.13, 0.06, 0.2), M["porc"], rot=(0, 8, 0))
    ell(mc + V((0, -0.002, 0)), (0.008, 0.062, 0.16), M["glow"], rot=(0, 8, 0))
    ell(mc + V((0.0, -0.002, -0.32)), (0.006, 0.045, 0.22), M["gold"], rot=(0, 8, 0))
    for k in range(5):
        z = 0.95 - k * 0.42 if k < 4 else -1.05
        for s_ in (1, -1):
            x = 0.4 if z > 0.5 else 0.36
            if k < 4:
                p = sc + V((s_ * x * 0.98, 0, z * 0.85 - 0.1))
                cone(p, p + V((s_ * 0.14, 0, 0.02)), 0.025, M["gold"], seg=10)
    piv(None)
    # armour: segmented back carapace, sternum plate, stacked pauldrons
    for i in range(6):
        t = i / 5
        y = 0.32 - t * 0.38
        z = 1.65 + t * 0.95
        ell(o + V((0, y, z)), (0.44 + math.sin(t * math.pi) * 0.12, 0.2, 0.14), M["porc_dirty"],
            rot=(55 - t * 50, 0, 0))
        torus(o + V((0, y - 0.02, z - 0.06)), 0.3, 0.008, M["gold"], rot=(55 - t * 50, 0, 0)).scale = (1.5, 0.6, 1)
    ell(o + V((0, -0.42, 2.3)), (0.3, 0.12, 0.22), M["porc_dirty"], rot=(-20, 0, 0))
    for i in range(4):  # ribs below the sternum, sinew showing between
        for s_ in (1, -1):
            ell(o + V((s_ * 0.17, -0.38 + i * 0.02, 2.06 - i * 0.09)), (0.17 - i * 0.015, 0.05, 0.025),
                M["porc_dirty"], rot=(-20, s_ * 15, s_ * -22))
    for s in (1, -1):
        for k in range(3):
            ell(o + V((s * (0.55 + k * 0.08), -0.1 + k * 0.03, 2.52 - k * 0.12)),
                (0.28 - k * 0.03, 0.26, 0.06), M["porc_dirty"], rot=(0, s * (-22 - k * 16), 0))
        torus(o + V((s * 0.55, -0.1, 2.52)), 0.27, 0.01, M["gold"], rot=(0, s * -22, 0))
    ell(o + V((0, 0.0, 1.5)), (0.3, 0.26, 0.15), M["porc_dirty"])
    torus(o + V((0, 0.0, 1.5)), 0.3, 0.008, M["gold"])
    # the gut emitter: a round throat of light ringed in gold, facing forward
    ec = o + V((0, -0.36, 1.78))
    ell(ec, (0.17, 0.08, 0.17), M["black"])
    ell(ec + V((0, -0.035, 0)), (0.1, 0.05, 0.1), M["glow"])
    for i, r in enumerate((0.12, 0.165, 0.21)):
        torus(ec + V((0, -0.05 + i * 0.02, 0)), r, 0.016 - i * 0.003, M["gold"], rot=(90, 0, 0))
    # crimson cloth hanging between the legs and down the back
    piv("Hips")
    strip(o + V((0, -0.3, 1.5)), 0.42, 1.0, M["cloth"], bulge=0.05, tilt=6, seed=4)
    strip(o + V((0, 0.42, 1.75)), 0.7, 1.5, M["cloth"], bulge=-0.06, tilt=-10, seed=5)
    # no head: a crown of organ pipes rising off the hump, each lit at the mouth
    import random
    piv("Torso")
    rnd = random.Random(3)
    for k in range(11):
        x = (k - 5) * 0.075
        hgt = 0.5 + (1 - abs(k - 5) / 5) * 0.6 + rnd.uniform(-0.05, 0.05)
        base = o + V((x, -0.02 + abs(x) * 0.3, 2.6))
        top = base + V((x * 0.25, 0.14, hgt))
        rod(base, top, 0.035, 0.03, M["black"], seg=16, caps=False)
        torus(top, 0.034, 0.009, M["gold"])
        ell(top + V((0, 0, -0.005)), (0.028, 0.028, 0.006), M["glow"])
        torus(base.lerp(top, 0.35), 0.037, 0.006, M["gold"])
    # where a head should be: a small porcelain face sunk between the shoulders
    fc = o + V((0, -0.5, 2.52))
    ell(fc, (0.075, 0.06, 0.1), M["porc"], rot=(-10, 0, 0))
    ell(fc + V((0, -0.002, 0)), (0.005, 0.061, 0.075), M["glow"], rot=(-10, 0, 0))
    piv(None)


def seraph(M, at=V((0, 0, 0))):
    """Floating spotter. A porcelain mask with one great eye, haloed, trailing ribbons."""
    c = V(at)
    ell(c, (0.24, 0.12, 0.32), M["porc"])
    ell(c + V((0, 0.06, 0)), (0.2, 0.12, 0.28), M["black"])
    ell(c + V((0, -0.1, 0.03)), (0.1, 0.04, 0.1), M["black"])
    ell(c + V((0, -0.118, 0.03)), (0.06, 0.03, 0.06), M["glow"])
    ell(c + V((0, -0.143, 0.03)), (0.022, 0.01, 0.022), M["black"])
    for r in (0.11, 0.14):
        torus(c + V((0, -0.1, 0.03)), r, 0.01, M["gold"], rot=(90, 0, 0))
    ell(c + V((0, -0.11, -0.16)), (0.004, 0.02, 0.09), M["glow_soft"])
    piv("Ring2")
    t2 = torus(c, 0.52, 0.009, M["gold"], rot=(80, -35, 30))
    piv("Ring")
    t1 = torus(c, 0.45, 0.012, M["gold"], rot=(70, 20, 0))
    for k in range(8):
        a = math.radians(k * 45)
        d = V((math.cos(a) * 0.45, 0, math.sin(a) * 0.45))
        d.rotate(t1.rotation_euler)
        ell(c + d, (0.014, 0.014, 0.014), M["glow"])
    piv("Body")
    for s in (1, -1):  # little porcelain wings
        for k in range(3):
            spike(c + V((s * 0.18, 0.04, 0.12 - k * 0.1)),
                  c + V((s * (0.6 - k * 0.1), 0.15, 0.32 - k * 0.2)), 0.04 - k * 0.008, M["porc"],
                  curve=0.08, side=V((0, 0, 1)))
    import random
    piv("Tail")
    rnd = random.Random(7)
    for k in range(7):  # ribbons and cables hanging below
        x = (k - 3) * 0.05
        top = c + V((x, 0.02, -0.25))
        pts = [top]
        for j in range(5):
            pts.append(pts[-1] + V((rnd.uniform(-0.04, 0.04), rnd.uniform(0, 0.05), -0.18)))
        mm = M["cloth"] if k % 2 else M["black"]
        for j in range(5):
            if k % 2:
                ell_between(pts[j], pts[j + 1], 0.025, 0.004, mm, over=1.15)
            else:
                rod(pts[j], pts[j + 1], 0.009, 0.007, mm, seg=8)
    piv(None)


UNITS = {"hush": hush, "hound": hound, "cantor": cantor, "seraph": seraph}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    unit, out = argv[0], Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    reset()
    stage()
    eng = "BLENDER_EEVEE" if "--eevee" in argv else "CYCLES"
    setup_render(eng, samples=int(dict(a.split("=") for a in argv if "=" in a).get("samples", 64)))
    M = mats()
    if unit == "seraph":
        seraph(M, V((0, 0, 1.9)))
        tgt, dist = V((0, 0, 1.75)), 3.2
    else:
        UNITS[unit](M)
        tgt, dist = {"hush": (V((0, 0, 1.15)), 6.2), "hound": (V((0, 0, 0.75)), 6.0),
                     "cantor": (V((0, 0, 1.65)), 8.6)}[unit]
    views = [a for a in argv[2:] if "=" not in a and not a.startswith("--")] or ["front", "q", "side", "back"]
    yaws = {"front": 0, "q": 35, "side": 90, "back": 180, "qb": 215, "ql": -35}
    for v in views:
        shot(out / f"{unit}_{v}.png", tgt, dist, yaws[v], pitch=6)
