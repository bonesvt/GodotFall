"""Wildlife past the border: creatures Eco has never seen. Run:
blender -b -P wild.py -- <creature> <outdir> [views...]"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import bpy
import kit
from mathutils import Vector as V
from kit import (Blob, cone, ell, ell_between, mat, rod, spike, stripes, torus, strip,
                 reset, stage, setup_render, shot)


def piv(name):
    """Tags what gets built next with the rigid part it hangs on in game (or None)."""
    kit.PIVOT = name


def mats():
    M = {}
    M["hide"] = mat("glass_hide", (0.34, 0.38, 0.36), rough=0.85, noise=((0.17, 0.19, 0.15), 1.6),
                    bump=0.4, bump_scale=14)
    M["belly"] = mat("glass_belly", (0.6, 0.57, 0.48), rough=0.8, bump=0.2, bump_scale=20)
    M["crystal"] = mat("crystal", (0.05, 0.45, 0.45), rough=0.05, coat=1.0, emit=(0.1, 0.75, 0.7),
                       strength=0.9)
    M["crystal_hot"] = mat("crystal_hot", (0.5, 1.0, 0.9), emit=(0.4, 1.0, 0.9), strength=6)
    M["eye_dark"] = mat("eye_dark", (0.02, 0.02, 0.02), rough=0.05, coat=1.0)
    M["horn"] = mat("horn", (0.62, 0.56, 0.45), rough=0.45, noise=((0.35, 0.3, 0.24), 5))
    M["toad"] = mat("lamp_skin", (0.27, 0.33, 0.16), rough=0.35, coat=0.4,
                    noise=((0.2, 0.22, 0.1), 3.0), bump=0.5, bump_scale=25)
    M["toad_belly"] = mat("lamp_belly", (0.62, 0.58, 0.4), rough=0.4, sss=0.2)
    M["mouth"] = mat("mouth", (0.32, 0.05, 0.07), rough=0.25, sss=0.3)
    M["tooth"] = mat("tooth", (0.66, 0.6, 0.45), rough=0.3)
    M["lure"] = mat("lure", (1.0, 0.85, 0.4), emit=(1.0, 0.8, 0.35), strength=25)
    M["spots"] = mat("spots", (0.5, 1.0, 0.6), emit=(0.4, 1.0, 0.5), strength=6)
    M["cat"] = stripes("quill_fur", (0.13, 0.13, 0.22), (0.24, 0.23, 0.36), axis="Y", scale=6,
                       rough=0.75, bump=0.3, warp=0.35)
    M["cat_dark"] = mat("cat_dark", (0.09, 0.09, 0.14), rough=0.7, bump=0.3, bump_scale=60)
    M["quill"] = mat("quill", (0.85, 0.8, 0.7), rough=0.4, noise=((0.4, 0.12, 0.1), 2.0))
    M["cat_eye"] = mat("cat_eye", (1.0, 0.9, 0.3), emit=(1.0, 0.85, 0.25), strength=12)
    M["bone"] = mat("bone", (0.55, 0.5, 0.4), rough=0.35, coat=0.3, noise=((0.3, 0.25, 0.18), 6))
    M["picker_flesh"] = mat("picker_flesh", (0.35, 0.12, 0.12), rough=0.3, sss=0.3)
    M["red_eye"] = mat("red_eye", (1, 0.1, 0.05), emit=(1, 0.1, 0.05), strength=10)
    M["ray"] = mat("ray_skin", (0.32, 0.31, 0.5), rough=0.4, coat=0.5, noise=((0.3, 0.25, 0.4), 2.5),
                   sss=0.1)
    M["ray_glow"] = mat("ray_glow", (0.7, 0.6, 1.0), emit=(0.7, 0.55, 1.0), strength=8)
    M["porc"] = mat("porcelain", (0.74, 0.7, 0.62), rough=0.22, coat=0.6)
    M["glow"] = mat("glow", (0.6, 0.95, 1.0), emit=(0.55, 0.95, 1.0), strength=10)
    M["gold"] = mat("gold", (0.85, 0.6, 0.28), rough=0.28, metal=1.0)
    return M


def glassback(M, at=V((0, 0, 0))):
    """Huge six-legged grazer, ~5 m at the crystals. Gentle until spooked."""
    o = V(at)
    b = Blob("glassback", res=0.05)
    b.path([o + V((0, 2.3, 2.6)), o + V((0, 1.0, 2.9)), o + V((0, -0.4, 3.0)), o + V((0, -1.5, 2.85))],
           [0.9, 1.15, 1.2, 1.0])
    b.ellip(o + V((0, 0.2, 2.6)), 1.15, (1.0, 1.4, 0.85))
    # neck swings low and forward, head grazing
    b.path([o + V((0, -1.6, 2.8)), o + V((0, -2.5, 2.4)), o + V((0, -3.2, 1.7)), o + V((0, -3.55, 1.15))],
           [0.75, 0.55, 0.42, 0.35])
    # heavy tail
    b.path([o + V((0, 2.6, 2.5)), o + V((0, 3.4, 2.0)), o + V((0, 4.0, 1.4))], [0.6, 0.35, 0.15])
    legs = [(-1.3, 1.05), (0.2, 1.1), (1.75, 1.05)]
    for s in (1, -1):
        for i, (y, x) in enumerate(legs):
            top = o + V((s * x * 0.8, y, 2.4))
            kn = o + V((s * x * 1.02, y - 0.15 + i * 0.05, 1.25))
            ft = o + V((s * x * 1.05, y, 0.2))
            b.line(top, kn, 0.55, 0.36)
            b.line(kn, ft, 0.34, 0.3)
            b.ellip(ft + V((0, -0.05, -0.05)), 0.36, (1.1, 1.15, 0.6))
    b.mesh(M["hide"], name="Glassback")
    for s in (1, -1):
        for i, (y, x) in enumerate(legs):
            ft = o + V((s * x * 1.05, y, 0.0))
            for k in (-1, 0, 1):  # toenails
                ell(ft + V((s * 0.0 + k * 0.17, -0.33, 0.1)), (0.1, 0.07, 0.09), M["horn"])
    ell(o + V((0, 0.0, 2.05)), (0.85, 2.0, 0.4), M["belly"])
    # head: long and soft, small kind eyes, drooping lip, little tusks
    piv("Head")
    hc = o + V((0, -3.75, 1.0))
    ell_between(hc + V((0, 0.25, 0.25)), hc + V((0, -0.55, -0.25)), 0.32, 0.3, M["hide"])
    ell_between(hc + V((0, -0.2, -0.15)), hc + V((0, -0.65, -0.45)), 0.18, 0.14, M["hide"])
    for s in (1, -1):
        ell(hc + V((s * 0.26, -0.05, 0.12)), (0.05, 0.07, 0.045), M["eye_dark"])
        spike(hc + V((s * 0.16, -0.38, -0.2)), hc + V((s * 0.3, -0.62, -0.05)), 0.05, M["horn"], curve=0.08)
        ell(hc + V((s * 0.22, 0.25, 0.32)), (0.07, 0.18, 0.12), M["hide"], rot=(30, s * 20, s * 30))  # ear
    # the glass: two rows of crystal plates along the spine, tallest over the shoulders
    piv("Body")
    rnd = random.Random(11)
    for i in range(9):
        t = i / 8
        y = 2.6 - t * 4.3
        z = 3.0 + math.sin(t * math.pi) * 0.3
        h = 0.5 + math.sin(min(1.0, t * 1.2) * math.pi) * 1.1
        for s in (1, -1):
            base = o + V((s * 0.32, y + s * 0.12, z + 0.5))
            tip = base + V((s * 0.35, -0.1, h))
            ell_between(base, tip, 0.06, 0.28 + h * 0.1, M["crystal"], over=1.05, roll=s * 10, seg=6)
            if rnd.random() < 0.6:
                tip2 = base + V((s * 0.6, 0.25, h * 0.55))
                ell_between(base, tip2, 0.04, 0.16, M["crystal"], over=1.05, seg=6)
    piv("Tail")
    for i in range(5):
        p = o + V((0, 2.9 + i * 0.25, 2.4 - i * 0.22))
        ell_between(p, p + V((0, 0.15, 0.4 - i * 0.06)), 0.04, 0.12, M["crystal"], seg=6)
    piv(None)


def lampjaw(M, at=V((0, 0, 0))):
    """Marsh ambush predator, ~2.8 m. Lies flat in shallow water with its lure lit."""
    o = V(at)
    b = Blob("lampjaw", res=0.025)
    b.ellip(o + V((0, 0.4, 0.42)), 0.6, (1.25, 1.5, 0.55))
    b.ellip(o + V((0, -0.35, 0.5)), 0.7, (1.3, 1.0, 0.6))
    b.path([o + V((0, 1.2, 0.35)), o + V((0, 1.8, 0.25)), o + V((0, 2.3, 0.2))], [0.3, 0.18, 0.08])
    for s in (1, -1):
        for y, fw in ((-0.45, -1), (0.75, 1)):
            sh = o + V((s * 0.62, y, 0.4))
            el = o + V((s * 0.95, y + fw * 0.05, 0.42))
            ft = o + V((s * 1.05, y - 0.15, 0.06))
            b.line(sh, el, 0.18, 0.12)
            b.line(el, ft, 0.12, 0.09)
            b.ellip(ft, 0.16, (1.2, 1.3, 0.35))
    b.mesh(M["toad"], name="Lampjaw")
    ell(o + V((0, 0.2, 0.3)), (0.62, 0.9, 0.18), M["toad_belly"])
    # the mouth: a wide upper jaw over a hinged lower one, cracked open
    hc = o + V((0, -0.95, 0.45))
    ell(hc + V((0, 0.05, 0.2)), (0.75, 0.55, 0.2), M["toad"], rot=(-22, 0, 0))
    piv("Jaw")
    ell(hc + V((0, 0.05, -0.2)), (0.72, 0.52, 0.14), M["toad"], rot=(12, 0, 0))
    piv(None)
    ell(hc + V((0, 0.22, 0.0)), (0.6, 0.38, 0.16), M["mouth"])
    ell(hc + V((0, 0.3, 0.0)), (0.3, 0.2, 0.1), M["eye_dark"])
    for k in range(17):  # needle teeth around both jaws
        a = math.radians(-80 + k * 10)
        x, y = math.sin(a) * 0.68, -math.cos(a) * 0.46
        if k % 4 == 3:
            continue
        L = random.Random(k).uniform(0.08, 0.24)
        top = hc + V((x, y + 0.06, 0.12 - y * 0.25))
        cone(top, top + V((0, -0.03, -L)), 0.012 + L * 0.06, M["tooth"], seg=8)
        bot = hc + V((x * 0.96, y + 0.06, -0.1))
        piv("Jaw")
        cone(bot, bot + V((0, -0.02, L * 0.7)), 0.012, M["tooth"], seg=8)
        piv(None)
    for s in (1, -1):  # little eyes high up, like a frog's
        ell(hc + V((s * 0.32, 0.4, 0.38)), (0.11, 0.11, 0.09), M["toad"])
        ell(hc + V((s * 0.34, 0.36, 0.43)), (0.06, 0.06, 0.05), M["cat_eye"])
        ell(hc + V((s * 0.345, 0.33, 0.45)), (0.012, 0.03, 0.03), M["eye_dark"])
    # lure: a long stalk arching forward from the brow, ending in a lit bulb
    piv("Lure")
    pts = [hc + V((0, 0.35, 0.3)), hc + V((0, 0.2, 0.9)), hc + V((0, -0.3, 1.25)),
           hc + V((0, -0.8, 1.15)), hc + V((0, -1.0, 0.85))]
    for i in range(len(pts) - 1):
        rod(pts[i], pts[i + 1], 0.05 - i * 0.008, 0.042 - i * 0.008, M["toad"], seg=12)
    ell(pts[-1] + V((0, 0, -0.08)), (0.09, 0.09, 0.11), M["lure"])
    for k in range(3):
        cone(pts[-1] + V((0, 0, -0.16)), pts[-1] + V((0.06 * (k - 1), -0.02, -0.4)), 0.012, M["toad"], seg=8)
    piv(None)
    # glowing spots down the flanks and tail
    rnd = random.Random(5)
    for k in range(26):
        s = 1 if k % 2 else -1
        y = -0.4 + rnd.random() * 2.2
        w = 0.7 * (1 - max(0, y - 0.9) / 1.6)
        ell(o + V((s * w, y, 0.5 - max(0, y - 1) * 0.2 + rnd.uniform(-0.05, 0.1))),
            (0.03, 0.03, 0.03), M["spots"])
    for k in range(7):  # warty dorsal nubs
        cone(o + V((0, -0.4 + k * 0.32, 0.78 - k * 0.04)), o + V((0, -0.35 + k * 0.32, 0.92 - k * 0.04)),
             0.05, M["toad"], seg=10)
    # flat paddle tail fin
    piv("Tail")
    ell(o + V((0, 2.15, 0.22)), (0.04, 0.45, 0.22), M["toad"])
    piv(None)
    # water plane it lurks in
    if "--dry" not in sys.argv:
        bpy.ops.mesh.primitive_plane_add(size=400, location=o + V((0, 0.4, 0.36)))
        bpy.context.object.data.materials.append(
            mat("water", (0.24, 0.3, 0.3), sheen=0.0, rim=0.0, shade=(0.8, 0.8, 0.84)))
        from kit import no_ink
        no_ink(bpy.context.object)


def quillcat(M, at=V((0, 0, 0))):
    """Pack hunter, ~1.1 m at the shoulder. Four eyes, a quill frill that flares when it commits."""
    o = V(at)
    b = Blob("quillcat", res=0.016)
    b.path([o + V((0, 0.75, 1.0)), o + V((0, 0.25, 0.95)), o + V((0, -0.3, 1.05)), o + V((0, -0.55, 1.0))],
           [0.2, 0.15, 0.24, 0.22])
    b.ellip(o + V((0, -0.4, 0.9)), 0.26, (0.8, 1.0, 1.15))
    b.path([o + V((0, -0.6, 1.05)), o + V((0, -0.85, 0.95)), o + V((0, -1.02, 0.82))], [0.15, 0.12, 0.1])
    for s in (1, -1):
        sh, el, wr, pw = (o + V((s * 0.17, -0.45, 0.95)), o + V((s * 0.22, -0.4, 0.55)),
                          o + V((s * 0.2, -0.62, 0.18)), o + V((s * 0.2, -0.72, 0.05)))
        b.line(sh, el, 0.13, 0.08)
        b.line(el, wr, 0.07, 0.05)
        b.line(wr, pw, 0.05, 0.06)
        hip, kn, an, pw2 = (o + V((s * 0.15, 0.65, 0.95)), o + V((s * 0.2, 0.45, 0.55)),
                            o + V((s * 0.19, 0.82, 0.28)), o + V((s * 0.19, 0.7, 0.05)))
        b.line(hip, kn, 0.16, 0.09)
        b.line(kn, an, 0.07, 0.05)
        b.line(an, pw2, 0.05, 0.055)
        for p in (pw, pw2):
            for k in (-1, 0, 1):
                cone(p + V((k * 0.03, -0.05, -0.02)), p + V((k * 0.035, -0.13, -0.05)), 0.012, M["horn"], seg=8)
    tail = [o + V((0, 0.85, 0.98)), o + V((0, 1.3, 0.9)), o + V((0, 1.75, 1.05)), o + V((0, 2.05, 1.35))]
    b.path(tail, [0.08, 0.06, 0.045, 0.03])
    b.mesh(M["cat"], name="Quillcat")
    # long narrow head, low and forward; four eyes in two pairs
    piv("Head")
    hc = o + V((0, -1.1, 0.8))
    ell_between(hc + V((0, 0.12, 0.05)), hc + V((0, -0.32, -0.08)), 0.1, 0.09, M["cat"])
    ell_between(hc + V((0, 0.0, -0.06)), hc + V((0, -0.3, -0.13)), 0.07, 0.04, M["cat_dark"])
    for k in range(5):
        for s in (1, -1):
            p = hc + V((s * (0.06 - k * 0.006), -0.08 - k * 0.05, -0.08 - k * 0.012))
            cone(p, p + V((0, 0, -0.05 - (k == 0) * 0.04)), 0.007 + (k == 0) * 0.005, M["tooth"], seg=8)
    for s in (1, -1):
        for e, (dy, dz, r) in enumerate(((-0.08, 0.06, 0.024), (0.0, 0.08, 0.018))):
            ell(hc + V((s * 0.075, dy, dz)), (r, r * 1.3, r), M["cat_eye"])
        ell(hc + V((s * 0.07, 0.12, 0.12)), (0.03, 0.06, 0.09), M["cat_dark"], rot=(-40, s * 15, 0))
    piv("Frill")
    # quill frill around the neck, flared
    for ring, (rad, ln) in enumerate(((0.16, 0.55), (0.2, 0.42))):
        n = 15
        for k in range(n):
            a = math.radians(-100 + k * (200 / (n - 1)))
            d = V((math.sin(a), 0.55 + ring * 0.2, math.cos(a))).normalized()
            base = o + V((0, -0.68 + ring * 0.08, 1.02)) + V((d.x, 0, d.z)) * rad
            spike(base, base + d * ln * (0.8 + 0.2 * math.cos(a)), 0.016, M["quill"], curve=0.03,
                  steps=3, side=V((0, 1, 0)))
    piv("Body")
    for k in range(12):  # quills down the spine
        y = -0.45 + k * 0.11
        base = o + V((0, y, 1.15 + math.sin(k * 0.3) * 0.03))
        spike(base, base + V((0, 0.2, 0.18 - k * 0.008)), 0.014, M["quill"], steps=3)
    piv("Tail")
    for k in range(7):  # tail tuft
        a = math.radians(k * 51)
        spike(tail[-1], tail[-1] + V((math.cos(a) * 0.12, 0.25, 0.15 + math.sin(a) * 0.12)), 0.012,
              M["quill"], steps=3)
    piv(None)


def picker(M, at, yaw=0, scale=1.0):
    """One bonepicker: six-legged scavenger in a bone shell, ~0.35 m long."""
    o = V(at)
    sc = scale
    c, s_, yw = math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), yaw

    def P(x, y, z):
        return o + V((x * c - y * s_, x * s_ + y * c, z)) * sc if False else o + V(((x * c - y * s_) * sc, (x * s_ + y * c) * sc, z * sc))

    for i in range(4):  # segmented shell, front to back
        ell(P(0, -0.1 + i * 0.08, 0.12 - i * 0.01), (0.09 - i * 0.012, 0.06, 0.05), M["bone"], rot=(0, 0, yw))
    ell(P(0, -0.15, 0.1), (0.07, 0.07, 0.06), M["picker_flesh"], rot=(0, 0, yw))
    ell(P(0, -0.19, 0.12), (0.06, 0.05, 0.045), M["bone"], rot=(0, 0, yw))
    for s in (1, -1):
        ell(P(s * 0.035, -0.23, 0.13), (0.012,) * 3, M["red_eye"])
        ell(P(s * 0.02, -0.25, 0.11), (0.008,) * 3, M["red_eye"])
        spike(P(s * 0.03, -0.24, 0.08), P(s * 0.015, -0.32, 0.06), 0.012 * sc, M["bone"], curve=0.0, steps=3)
        for k in range(3):
            y = -0.1 + k * 0.08
            kn = P(s * 0.15, y - 0.02, 0.18)
            ft = P(s * 0.22, y - 0.04 + k * 0.02, 0.0)
            rod(P(s * 0.05, y, 0.1), kn, 0.012 * sc, 0.009 * sc, M["bone"], seg=8)
            rod(kn, ft, 0.009 * sc, 0.003 * sc, M["bone"], seg=8)


def pickers(M, at=V((0, 0, 0))):
    """A swarm stripping something dead: here, a fallen Choir soldier's mask and halo."""
    o = V(at)
    # the carcass: cracked porcelain mask, a bent halo, black sinew strands
    ell(o + V((0, 0.0, 0.08)), (0.1, 0.16, 0.09), M["porc"], rot=(90, 0, 25))
    ell(o + V((0.0, -0.02, 0.17)), (0.006, 0.12, 0.09), M["glow"], rot=(90, 0, 25))
    torus(o + V((0.25, 0.2, 0.05)), 0.22, 0.006, M["gold"], rot=(80, 10, 30))
    for k in range(8):
        a = math.radians(k * 45 + 10)
        rod(o + V((0.1, 0.15, 0.04)), o + V((0.1 + math.cos(a) * 0.4, 0.15 + math.sin(a) * 0.35, 0.02)),
            0.02, 0.008, mat("sinew_dead", (0.03, 0.03, 0.035), rough=0.35), seg=8)
    rnd = random.Random(2)
    spots = [(-0.32, -0.22, 40), (0.34, -0.3, -30), (0.5, 0.32, 200), (-0.2, 0.45, 150),
             (-0.6, 0.12, 80), (0.02, -0.6, 0)]
    for x, y, yw in spots:
        picker(M, o + V((x, y, 0)), yaw=yw + rnd.uniform(-20, 20), scale=rnd.uniform(0.9, 1.2))


def wing(root, s, m, span=2.1, chord=1.1, lift=0.35, name="wing"):
    """Manta wing as a thin curved sheet: leading edge swept back, tip curled up."""
    import bmesh
    from kit import _finish
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    nx, ny = 16, 8
    g = []
    for i in range(nx):
        u = i / (nx - 1)
        lead = -chord * 0.55 + u ** 1.6 * chord * 0.9
        trail = chord * 0.5 - u * chord * 0.25
        if u > 0.85:
            lead = lead + (u - 0.85) * 2.5 * (trail - lead) * 0.5
        row = []
        for j in range(ny):
            v = j / (ny - 1)
            y = lead + (trail - lead) * v
            z = lift * u * u + 0.06 * math.sin(v * math.pi) * (1 - u)
            row.append(bm.verts.new((s * u * span, y, z)))
        g.append(row)
    for i in range(nx - 1):
        for j in range(ny - 1):
            f = (g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1])
            bm.faces.new(f if s > 0 else f[::-1])
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = V(root)
    o.modifiers.new("t", "SOLIDIFY").thickness = 0.04
    o.modifiers.new("s", "SUBSURF").levels = 1 if kit.GAME else 2
    return _finish(o, m)


def veilray(M, at=V((0, 0, 0))):
    """Gliding sky ray, ~4.5 m wingspan. Harmless; flocks drift over the canopy at dusk."""
    o = V(at)
    ell(o, (0.42, 0.85, 0.16), M["ray"])
    ell(o + V((0, -0.7, 0.0)), (0.22, 0.25, 0.09), M["ray"])
    for s in (1, -1):
        piv("WingR" if s < 0 else "WingL")
        wing(o + V((s * 0.25, 0, 0.02)), s, M["ray"])
        piv(None)
        ell(o + V((s * 0.13, -0.86, 0.06)), (0.035, 0.045, 0.03), M["ray_glow"])
        spike(o + V((s * 0.18, -0.85, 0.0)), o + V((s * 0.32, -1.25, -0.1)), 0.05, M["ray"], curve=0.1,
              side=V((s, 0, 0)))
    piv("Tail")
    rod(o + V((0, 0.8, 0)), o + V((0, 2.6, -0.2)), 0.06, 0.008, M["ray"], seg=10)
    for k in range(5):  # trailing filaments
        x = (k - 2) * 0.12
        pts = [o + V((x, 0.5, -0.1))]
        for j in range(6):
            pts.append(pts[-1] + V((math.sin(j + k) * 0.05, 0.32, -0.07 * j)))
        for j in range(6):
            rod(pts[j], pts[j + 1], 0.01, 0.006, M["ray_glow"] if j % 2 else M["ray"], seg=6, caps=False)
    piv(None)


CREATURES = {"glassback": glassback, "lampjaw": lampjaw, "quillcat": quillcat, "pickers": pickers,
             "veilray": veilray}
FRAME = {"glassback": (V((0, 0, 2.6)), 17.0), "lampjaw": (V((0, 0, 0.6)), 7.5),
         "quillcat": (V((0, 0, 0.75)), 6.0), "pickers": (V((0, 0, 0.1)), 3.6),
         "veilray": (V((0, 0, 3.0)), 7.0)}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    unit, out = argv[0], Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    reset()
    stage()
    eng = "BLENDER_EEVEE" if "--eevee" in argv else "CYCLES"
    setup_render(eng, samples=int(dict(a.split("=") for a in argv if "=" in a).get("samples", 64)))
    M = mats()
    CREATURES[unit](M, V((0, 0, 3.0)) if unit == "veilray" else V((0, 0, 0)))
    tgt, dist = FRAME[unit]
    views = [a for a in argv[2:] if "=" not in a and not a.startswith("--")] or ["front", "q", "side", "back"]
    yaws = {"front": 0, "q": 35, "side": 90, "back": 180, "qb": 215, "ql": -35, "top": 20}
    for v in views:
        shot(out / f"{unit}_{v}.png", tgt, dist, yaws[v], pitch=55 if v == "top" else {"pickers": 32, "veilray": -14}.get(unit, 8))
