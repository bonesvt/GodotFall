"""The colony's own: the Shepherd (scripts/hub/shepherd.gd), the enforcer that
comes for citizens who skip their Hymn. Built like the Choir (choir.py) from
kit.py's metaballs and primitives, exported by build_threats.py as a rigid-part
puppet (scripts/threats/threat_model.gd, biped gait).

The Shepherd, ~2.2 m: tall and straight-backed where the Choir stoop. A long
white colony coat over grey synthetic limbs, a smooth faceless helmet with one
level slit of light, the dispensary tank on its back glowing with Hymn and
feeding two tubes over its shoulders, a loudspeaker horn on its left shoulder,
the colony's ringed seal on its chest, and a long white dart rifle held low in
its right hand. Faces -Y like the concept models."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import kit
from mathutils import Vector as V
from kit import Blob, strip, box, cone, ell, ell_between, mat, rod, torus


def piv(name):
    kit.PIVOT = name


def mats():
    M = {}
    M["white"] = mat("colony_white", (0.86, 0.88, 0.92), rough=0.3, coat=0.4)
    M["grey"] = mat("colony_grey", (0.28, 0.3, 0.35), rough=0.45)
    M["black"] = mat("black", (0.07, 0.07, 0.085), rough=0.25, coat=0.5)
    M["glow"] = mat("hymn_glow", (0.85, 0.94, 1.0), emit=(0.8, 0.92, 1.0), strength=30)
    M["glow_soft"] = mat("hymn_glow_soft", (0.85, 0.94, 1.0), emit=(0.7, 0.88, 1.0), strength=8)
    # choir.hand() reaches for these
    M["porc"] = M["white"]
    return M


def _hand(M, wrist, fwd, s, curl=0.7):
    """A gloved four-fingered hand: grey palm, white knuckle plate."""
    wrist, fwd = V(wrist), V(fwd).normalized()
    side = fwd.cross(V((0, 0, 1))).normalized() * s
    if side.length < 0.1:
        side = V((s, 0, 0))
    ell_between(wrist, wrist + fwd * 0.1, 0.04, 0.026, M["grey"])
    ell(wrist + fwd * 0.06 + V((0, 0, 0.012)), (0.035, 0.03, 0.012), M["white"])
    for i in range(4):
        o = (i - 1.5) * 0.018
        base = wrist + fwd * 0.1 + side * o
        tip = base + (fwd * (1 - curl) + V((0, 0, -1)) * curl).normalized() * 0.075
        rod(base, tip, 0.009, 0.007, M["grey"], seg=8)
    rod(wrist + fwd * 0.05 - side * 0.03, wrist + fwd * 0.1 - side * 0.05 + V((0, 0, -0.02)),
        0.01, 0.007, M["grey"], seg=8)


def shepherd(M, at=V((0, 0, 0))):
    o = V(at)
    b = Blob("shepherd_body", res=0.012)
    # torso: upright, broad square chest over a narrow waist
    b.ellip(o + V((0, 0, 1.06)), 0.14, (1.0, 0.75, 0.6))
    b.line(o + V((0, 0, 1.1)), o + V((0, 0, 1.4)), 0.11, 0.13)
    b.ellip(o + V((0, 0, 1.56)), 0.2, (1.05, 0.68, 0.9))
    b.path([o + V((0, 0, 1.74)), o + V((0, -0.01, 1.86))], [0.06, 0.055])
    # legs: long and straight, grey, white plates on thigh and shin, square boots
    for s in (1, -1):
        hip, knee, ankle = o + V((s * 0.11, 0, 1.0)), o + V((s * 0.115, -0.02, 0.55)), o + V((s * 0.115, 0.02, 0.1))
        b.line(hip, knee, 0.075, 0.055)
        b.line(knee, ankle, 0.055, 0.042)
        ell_between(hip + V((0, -0.035, -0.06)), knee + V((0, -0.03, 0.04)), 0.07, 0.05, M["white"], over=0.9)
        ell_between(knee + V((0, -0.035, -0.04)), ankle + V((0, -0.03, 0.08)), 0.055, 0.045, M["white"], over=0.9)
        ell(knee + V((0, -0.05, 0)), (0.05, 0.035, 0.05), M["grey"])
        box(o + V((s * 0.115, -0.05, 0.05)), (0.11, 0.26, 0.1), M["grey"], bevel=0.02)
        box(o + V((s * 0.115, -0.13, 0.04)), (0.1, 0.1, 0.08), M["white"], bevel=0.02)
    b.mesh(M["grey"], name="Shepherd")

    # the coat: a white shell over chest and shoulders, a high stand collar,
    # the colony seal on the chest, and long panels to the knee (on the hips)
    ell(o + V((0, -0.02, 1.55)), (0.215, 0.15, 0.24), M["white"])
    ell(o + V((0, 0.03, 1.32)), (0.17, 0.13, 0.16), M["white"])
    torus(o + V((0, -0.005, 1.78)), 0.085, 0.03, M["white"], rot=(0, 0, 0))
    ell(o + V((0, -0.01, 1.82)), (0.095, 0.09, 0.06), M["white"])
    seal = o + V((0, -0.165, 1.6))
    for r in (0.055, 0.035):
        torus(seal, r, 0.006, M["glow_soft"], rot=(90, 0, 0))
    ell(seal, (0.014, 0.008, 0.014), M["glow"])
    box(o + V((0, 0, 1.1)), (0.32, 0.26, 0.06), M["grey"], bevel=0.015)  # belt
    box(o + V((0, -0.135, 1.1)), (0.08, 0.02, 0.05), M["white"], bevel=0.008)
    piv("Hips")
    for x, y, w, tilt, yaw, seed in ((-0.1, -0.12, 0.17, 6, 0, 1), (0.1, -0.12, 0.17, 6, 0, 2),
                                     (0, 0.12, 0.34, -6, 180, 3), (-0.17, 0.0, 0.2, 0, 90, 4),
                                     (0.17, 0.0, 0.2, 0, -90, 5)):
        strip(o + V((x, y, 1.08)), w, 0.56, M["white"], bulge=0.02, tilt=tilt, seed=seed, yaw=yaw,
              taper=1.1, cols=7, rows=10, name="coat")
    piv(None)

    # arms: long, square white pauldrons, grey sleeves with white forearm plates
    piv("Torso")
    rh = o + V((0.24, -0.26, 1.06))  # right hand, low with the rifle
    lh = o + V((-0.3, -0.05, 0.86))  # left hand, hanging open
    arms = {1: [(0.26, 0, 1.68), (0.31, -0.06, 1.36), tuple(rh)],
            -1: [(-0.26, 0, 1.68), (-0.31, 0.0, 1.32), tuple(lh)]}
    a = Blob("shepherd_arms", res=0.012)
    for s, (sh, el, wr) in arms.items():
        sh, el, wr = o + V(sh), o + V(el), o + V(wr)
        a.line(sh, el, 0.055, 0.045)
        a.line(el, wr, 0.045, 0.035)
        ell(sh + V((s * 0.02, 0, 0.04)), (0.1, 0.11, 0.07), M["white"], rot=(0, s * -12, 0))
        box(sh + V((s * 0.04, 0, -0.04)), (0.1, 0.18, 0.05), M["white"], rot=(0, s * -20, 0), bevel=0.02)
        ell_between(el + (wr - el) * 0.12, wr - (wr - el) * 0.1, 0.05, 0.045, M["white"], over=0.9)
        _hand(M, wr, (wr - el) if s < 0 else V((0, -1, -0.15)), s, curl=0.35 if s < 0 else 0.8)
    a.mesh(M["grey"], name="Arms")
    # the loudspeaker horn on its left shoulder, facing ahead
    lsh = o + V((-0.27, 0.02, 1.78))
    rod(lsh, lsh + V((0, -0.05, 0.06)), 0.02, 0.02, M["grey"], seg=10)
    cone(lsh + V((0, -0.2, 0.08)), lsh + V((0, -0.02, 0.07)), 0.06, M["black"], seg=20)
    torus(lsh + V((0, -0.2, 0.08)), 0.06, 0.008, M["white"], rot=(90, 0, 0))
    # the dart rifle, held low, pointing ahead and down: white stock and body,
    # grey barrel, a glowing magazine of darts
    d = V((0.0, -1, -0.12)).normalized()
    st, mz = rh - d * 0.28, rh + d * 0.95
    ell_between(st, rh + d * 0.3, 0.035, 0.05, M["white"], name="rifle")
    rod(rh + d * 0.2, mz, 0.016, 0.012, M["grey"], seg=12)
    ell_between(rh + d * 0.28, rh + d * 0.62, 0.028, 0.03, M["white"])
    rod(rh + d * 0.1 + V((0, 0, -0.06)), rh + d * 0.2 + V((0, 0, -0.06)), 0.022, 0.022, M["glow_soft"], seg=10)
    for t in (0.66, 0.8):
        torus(rh + d * t, 0.02, 0.004, M["glow_soft"]).rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    cone(mz, mz + d * 0.05, 0.014, M["white"], seg=10)

    # the dispensary tank on its back: grey caps and cage, Hymn glowing inside,
    # two tubes up and over its shoulders to its collar
    tk = o + V((0, 0.24, 1.42))
    rod(tk + V((0, 0, -0.28)), tk + V((0, 0, 0.28)), 0.12, 0.12, M["glow_soft"], seg=24)
    for z in (-0.3, 0.3):
        rod(tk + V((0, 0, z - 0.03)), tk + V((0, 0, z + 0.03)), 0.135, 0.135, M["grey"], seg=24)
    for k in range(4):
        ang = math.radians(45 + k * 90)
        p = tk + V((math.cos(ang) * 0.125, math.sin(ang) * 0.125, 0))
        rod(p + V((0, 0, -0.28)), p + V((0, 0, 0.28)), 0.01, 0.01, M["white"], seg=8)
    box(o + V((0, 0.15, 1.42)), (0.26, 0.06, 0.5), M["grey"], bevel=0.02)  # its harness plate
    for s in (1, -1):
        pts = [tk + V((s * 0.05, 0, 0.3)), o + V((s * 0.1, 0.2, 1.84)), o + V((s * 0.08, 0.06, 1.86))]
        for p0, p1 in zip(pts, pts[1:]):
            rod(p0, p1, 0.016, 0.016, M["glow_soft"], seg=10)

    # head: smooth faceless white helmet, a black face band, one level slit of light
    piv("Head")
    hc = o + V((0, -0.02, 2.02))
    ell(hc, (0.11, 0.125, 0.135), M["white"])
    ell(hc + V((0, -0.06, -0.005)), (0.1, 0.07, 0.06), M["black"])
    ell(hc + V((0, -0.115, 0.0)), (0.085, 0.012, 0.012) if kit.GAME else (0.08, 0.008, 0.009), M["glow"])
    ell(hc + V((0, 0.02, 0.09)), (0.09, 0.11, 0.05), M["white"])  # crown
    ell(hc + V((0, 0.0, -0.1)), (0.075, 0.08, 0.04), M["grey"])  # jaw guard
    for s in (1, -1):
        rod(hc + V((s * 0.11, 0, 0.0)), hc + V((s * 0.125, 0, 0.0)), 0.03, 0.03, M["grey"], seg=14)
    piv(None)
