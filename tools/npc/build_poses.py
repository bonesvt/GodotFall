"""Extra poses for a hub person, as a separate animation file next to their
model: assets/models/npc/<who>_poses.glb, just the armature and its actions
(hub_npc.gd adds them to the model's AnimationPlayer at load). Their model
glb stays as tools/npc/build_npc.py made it.

    blender -b --factory-startup --python tools/npc/build_poses.py -- <repo root> <who> [--shots <dir>]

It imports the built model (assets/models/npc/<who>.glb), poses its rig with
the same helpers Eco's animations use (tools/eco/build_eco_vroid.py: turn(),
key_pose(); she faces +Y, her right is +X, angles in degrees), and exports
only the armature with the new actions. --shots renders each pose with
Workbench for a quick look.

Axes (about the world axis, in order hips first): spine / chest / neck /
head X: negative bows forward. head Z: positive turns to her left. head and
hips Y: positive tips the top toward her right. upperarm / forearm / thigh X:
positive swings forward (forearm: elbow bends, hand comes up in front).
upperarm.R Y: positive brings the arm down to her side (L: negative).
thigh.R Y: positive crosses inward (L: negative). shin X: negative bends the
knee.

Ophelia's poses (loops; "idle_*" are where she hangs out between talks, the
rest are struck for her heart scenes):
  idle_lounge   reclined on her mattress, propped on an elbow, one knee up
  idle_smoke    leaning by the window, cigarette to her lips now and then
  idle_read     sitting cross-legged on the floor, a book in her lap
  idle_sway     standing by the record player, swaying with her eyes shut
  scene_sit     sitting on the floor, arms round her knees
  scene_mirror  standing, eyeliner to one eye, little mirror in the other hand
  scene_shy     standing, hands behind her back, weight on one hip

Pip's (tools/npc/build_poses.py -- . pip): work loops, one for each of her
businesses, played where she stands that hub stay (downtown.gd PIP_SPOTS):
  work_casino   at the Velvet Ace's door, shuffling a deck, a look up the street
  work_club     at the Undertow's door, cocktail in hand, a slow sip
  work_rooms    in the corridor of rooms below, foot up on the wall, ticking
                off her ledger, glancing at the doors
  work_high     in her chair in the high rollers' room, legs crossed, walking
                a chip over her knuckles

Level 2 (the holding cell and getting out of it; scripts/run/escort.gd):
  chained       sitting on the cell floor, knees up, shackled wrists resting
                on them, head down
  stasis        hanging limp in the stasis column: arms loose, head tipped,
                toes pointed, drifting slowly (holding_cell.gd lifts her)
  move_walk     a careful, hunched walking stride (about 1.15 m a cycle)
  move_run      a running stride (about 3.6 m a cycle)
  move_crouch   crouched low, still
  move_crouch_walk  creeping along crouched (about 0.9 m a cycle)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT, WHO = argv[0], argv[1]
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else None
# --mesh: the shots show the model itself (untextured) rather than a stick figure
MESH = "--mesh" in argv

_eco_path = os.path.join(ROOT, "tools", "eco", "build_eco_vroid.py")
_src = open(_eco_path).read()
_src = _src[:_src.rindex("\nmain()")]
_saved = sys.argv
sys.argv = ["blender", "--", "none.glb", ROOT]
E = {"__name__": "eco_vroid"}
exec(compile(_src, _eco_path, "exec"), E)
sys.argv = _saved

X, Y, Z = E["X"], E["Y"], E["Z"]
eco_hips_loc = E["hips_loc"]
add, key_pose, base_pose = E["add"], E["key_pose"], E["base_pose"]
BONE, ORDER, FINGERS = E["BONE"], E["ORDER"], E["FINGERS"]

MODEL = os.path.join(ROOT, "assets", "models", "npc", WHO + ".glb")
OUT = os.path.join(ROOT, "assets", "models", "npc", WHO + "_poses.glb")
FPS = 30


## Her hips' rest height, and where they sit lying on the mattress (its top
## is 0.31 m up) and sitting on the floor; set by load().
HIPS = 0.85
LIE = 0.52
SIT = 0.13


def load():
    global HIPS
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=MODEL, bone_heuristic="BLENDER")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # the model's own actions stay in its glb
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    HIPS = (arm.matrix_world @ arm.pose.bones["J_Bip_C_Hips"].head).z
    print("hips at %.3f m" % HIPS)
    return arm


def wave(f, n, k=1.0, phase=0.0):
    return math.sin(f / n * 2 * math.pi * k + phase)


def lounge(f, n):
    """Reclined on the mattress, head toward her pillows, propped on her left
    elbow and turned a little onto that side, right knee raised with her
    right wrist draped over it, looking out at whoever comes in."""
    p = base_pose()
    b = wave(f, n, 2)
    add(p, "hips", X, 80)
    add(p, "hips", Y, -18)
    add(p, "spine", X, -22)
    add(p, "chest", X, -20 - 1.0 * b)
    add(p, "neck", X, -16)
    add(p, "head", X, -14 + 2 * wave(f, n, 1, 1))
    add(p, "head", Y, 10)
    # left arm: upper arm back under her shoulder, forearm flat forward
    add(p, "upperarm.L", X, -55)
    add(p, "upperarm.L", Y, 10)
    add(p, "forearm.L", X, 90)
    # right arm over the raised knee
    add(p, "upperarm.R", X, 35)
    add(p, "upperarm.R", Y, -10)
    add(p, "forearm.R", X, 55)
    add(p, "hand.R", X, -30)
    # legs: left long, right knee up
    add(p, "thigh.R", X, 55)
    add(p, "shin.R", X, -100)
    add(p, "foot.R", X, 30)
    add(p, "thigh.L", X, 6)
    add(p, "thigh.L", Y, -4)
    add(p, "shin.L", X, -14)
    add(p, "foot.L", X, 35)
    p["_hips_loc"] = (0.0, -0.1, LIE - HIPS)
    return p


def smoke(f, n):
    """Leaning a shoulder on the wall by the window, cigarette in her right
    hand; it comes up to her lips in the middle of the loop."""
    p = base_pose()
    lift = max(0.0, math.sin(f / n * math.pi)) ** 2   # 0 -> 1 -> 0 over the loop
    add(p, "hips", Y, 6)
    add(p, "hips", Z, 8)
    add(p, "spine", Y, -4)
    add(p, "chest", Z, -6)
    add(p, "chest", X, -1.2 * wave(f, n, 3))
    add(p, "head", Z, 14 - 8 * lift)
    add(p, "head", Y, 6)
    add(p, "head", X, 4 * (1 - lift))
    # left arm across her waist, holding her right elbow
    add(p, "upperarm.L", X, 15)
    add(p, "forearm.L", X, 85)
    add(p, "forearm.L", Z, -60)
    # right arm: forearm up, cigarette between two fingers, to her lips
    add(p, "upperarm.R", X, 20 + 15 * lift)
    add(p, "upperarm.R", Y, -10 - 15 * lift)
    add(p, "forearm.R", X, 95 + 40 * lift)
    add(p, "forearm.R", Z, 20 * lift)
    add(p, "hand.R", X, -20)
    add(p, "thigh.R", X, 6)
    add(p, "shin.R", X, -12)
    add(p, "thigh.L", Y, -4)
    add(p, "thigh.L", X, -4)
    p["_hips_loc"] = (0.03, 0.0, -0.01)
    p["_grip"] = 0.8
    return p


def read(f, n):
    """Cross-legged on the floor, a book open in both hands, head bowed."""
    p = base_pose()
    b = wave(f, n, 2)
    add(p, "spine", X, -10)
    add(p, "chest", X, -8 - 1.0 * b)
    add(p, "neck", X, -14)
    add(p, "head", X, -18 + 2 * wave(f, n, 1))
    add(p, "head", Y, 6)
    for s, sgn in (("R", 1), ("L", -1)):
        # thighs forward and splayed, shins folded back across each other
        add(p, "thigh." + s, X, 80)
        add(p, "thigh." + s, Y, -sgn * 50)
        add(p, "shin." + s, X, -150)
        add(p, "shin." + s, Y, sgn * 40)
        add(p, "upperarm." + s, X, 25)
        add(p, "upperarm." + s, Y, sgn * 12)
        add(p, "forearm." + s, X, 60)
        add(p, "forearm." + s, Y, sgn * 25)
    p["_hips_loc"] = (0.0, 0.0, SIT - HIPS)
    p["_grip"] = 0.6
    return p


def sway(f, n):
    """By the record player: a slow side-to-side sway, head tipped, eyes shut
    (hub_npc.gd closes them)."""
    p = base_pose()
    s = wave(f, n)
    add(p, "hips", Y, 5 * s)
    add(p, "hips", Z, 4 * wave(f, n, 1, 0.6))
    add(p, "spine", Y, -3 * s)
    add(p, "chest", Y, -3 * s)
    add(p, "head", Y, 9 + 5 * s)
    add(p, "head", X, 6)
    add(p, "upperarm.R", Y, -6 * s)
    add(p, "upperarm.L", Y, -6 * s)
    add(p, "thigh.R", X, 4 + 4 * max(0.0, s))
    add(p, "shin.R", X, -8 * max(0.0, s))
    add(p, "thigh.L", X, 4 + 4 * max(0.0, -s))
    add(p, "shin.L", X, -8 * max(0.0, -s))
    p["_hips_loc"] = (0.03 * s, 0.0, -0.01)
    return p


def sit(f, n):
    """On the floor, knees up, arms wrapped round them, chin near her knees."""
    p = base_pose()
    b = wave(f, n, 2)
    add(p, "spine", X, -14)
    add(p, "chest", X, -12 - 1.0 * b)
    add(p, "neck", X, -10)
    add(p, "head", X, -6 + 2 * wave(f, n, 1))
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "thigh." + s, X, 140)
        add(p, "thigh." + s, Y, -sgn * 6)
        add(p, "shin." + s, X, -82)
        add(p, "foot." + s, X, 25)
        add(p, "upperarm." + s, X, 50)
        add(p, "forearm." + s, X, 30)
        add(p, "forearm." + s, Z, sgn * 65)
    p["_hips_loc"] = (0.0, 0.0, SIT - HIPS)
    return p


def chained(f, n):
    """On the cell floor, knees up, her shackled wrists together resting on
    her knees, head hung; a slow breath, a glance up now and then."""
    p = base_pose()
    b = wave(f, n, 2)
    look = max(0.0, wave(f, n, 1, -1.2)) ** 3
    add(p, "spine", X, -10)
    add(p, "chest", X, -8 - 1.2 * b)
    add(p, "neck", X, -16 + 10 * look)
    add(p, "head", X, -18 + 16 * look)
    add(p, "head", Z, 6 * look)
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "thigh." + s, X, 128)
        add(p, "thigh." + s, Y, -sgn * 8)
        add(p, "shin." + s, X, -100)
        add(p, "foot." + s, X, 30)
        add(p, "upperarm." + s, X, 42)
        add(p, "upperarm." + s, Y, sgn * 10)
        add(p, "forearm." + s, X, 38)
        add(p, "forearm." + s, Z, sgn * 48)
        add(p, "hand." + s, X, -20)
    p["_hips_loc"] = (0.0, 0.0, SIT - HIPS)
    return p


def stasis(f, n):
    """Held in the stasis column: hanging limp a hand off the floor, arms
    loose a little out from her sides, head tipped, toes pointed. Time barely
    moves in the field, so she only drifts, very slowly."""
    p = base_pose()
    d = wave(f, n, 1)
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "upperarm." + s, Y, -sgn * (12 + 2 * d))
        add(p, "upperarm." + s, X, -6)
        add(p, "forearm." + s, X, 12 + 3 * d)
        add(p, "hand." + s, X, -10)
    add(p, "spine", X, 4)
    add(p, "chest", X, 4)
    add(p, "neck", X, 6)
    add(p, "head", X, 8 + 2 * d)
    add(p, "head", Y, 8)
    add(p, "thigh.R", X, 6)
    add(p, "shin.R", X, -18)
    add(p, "thigh.L", X, -3)
    add(p, "shin.L", X, -6)
    add(p, "foot.R", X, 35)
    add(p, "foot.L", X, 30)
    p["_hips_loc"] = (0.0, 0.0, 0.012 * d)
    return p


## How far down her hips go in a crouch (Eco's 0.4 m, scaled to her).
def _crouch_drop():
    return 0.4 * HIPS / 0.9


def sneak_walk(f, n):
    """Eco's walk, hunched and careful: knees soft, shoulders in, arms close."""
    p = base_pose()
    t = f / n * 2 * math.pi
    sw = math.sin(t)
    add(p, "upperarm.R", Y, 6)
    add(p, "upperarm.L", Y, -6)
    add(p, "thigh.R", X, 22 * sw + 8)
    add(p, "thigh.L", X, -22 * sw + 8)
    add(p, "shin.R", X, -40 * max(0.0, math.sin(t - 1.2)) - 14)
    add(p, "shin.L", X, -40 * max(0.0, math.sin(t + math.pi - 1.2)) - 14)
    add(p, "foot.R", X, 8 * math.cos(t) + 4)
    add(p, "foot.L", X, -8 * math.cos(t) + 4)
    add(p, "upperarm.R", X, -12 * sw + 10)
    add(p, "upperarm.L", X, 12 * sw + 10)
    add(p, "forearm.R", X, 35)
    add(p, "forearm.L", X, 35)
    add(p, "hips", Z, 4 * sw)
    add(p, "chest", Z, -5 * sw)
    add(p, "spine", X, -12)
    add(p, "neck", X, 6)
    add(p, "head", X, 6)
    add(p, "head", Z, 10 * math.sin(t * 0.5))   # glancing round
    p["_hips_loc"] = eco_hips_loc(-0.05 - 0.015 * abs(math.cos(t)), 0.02)
    return p


def run(f, n):
    """Eco's run, a little less flashy."""
    p = base_pose()
    t = f / n * 2 * math.pi
    sw = math.sin(t)
    add(p, "upperarm.R", Y, -9)
    add(p, "upperarm.L", Y, 9)
    add(p, "thigh.R", X, 40 * sw + 6)
    add(p, "thigh.L", X, -40 * sw + 6)
    add(p, "shin.R", X, -90 * max(0.0, math.sin(t - 1.4)) - 14)
    add(p, "shin.L", X, -90 * max(0.0, math.sin(t + math.pi - 1.4)) - 14)
    add(p, "foot.R", X, 16 * math.cos(t))
    add(p, "foot.L", X, -16 * math.cos(t))
    add(p, "upperarm.R", X, -30 * sw)
    add(p, "upperarm.L", X, 30 * sw)
    add(p, "forearm.R", X, 55 + 12 * max(0.0, -sw))
    add(p, "forearm.L", X, 55 + 12 * max(0.0, sw))
    add(p, "spine", X, -10)
    add(p, "head", X, 8)
    add(p, "hips", Z, 8 * sw)
    add(p, "chest", Z, -11 * sw)
    p["_hips_loc"] = eco_hips_loc(-0.035 + 0.03 * abs(math.sin(t)), 0)
    return p


def _crouch_body(p, breath):
    add(p, "spine", X, -26 - 1.5 * breath)
    add(p, "chest", X, -6)
    add(p, "neck", X, 14)
    add(p, "head", X, 16)
    add(p, "upperarm.R", X, 34)
    add(p, "upperarm.L", X, 26)
    add(p, "forearm.R", X, 40)
    add(p, "forearm.L", X, 46)


def crouch(f, n):
    """Low on her heels, hands near her knees, breathing quick and shallow."""
    p = base_pose()
    for sd, sgn in (("R", 1), ("L", -1)):
        add(p, "thigh." + sd, X, 74)
        add(p, "thigh." + sd, Y, -9 * sgn)
        add(p, "shin." + sd, X, -112)
        add(p, "foot." + sd, X, 36)
    _crouch_body(p, wave(f, n, 3))
    add(p, "head", Z, 12 * wave(f, n, 1))
    p["_hips_loc"] = eco_hips_loc(-_crouch_drop(), 0.13)
    return p


def crouch_walk(f, n):
    """Creeping along crouched: short steps, hips low and level."""
    p = base_pose()
    t = f / n * 2 * math.pi
    sw = math.sin(t)
    for sd, sgn, ph in (("R", 1, 0.0), ("L", -1, math.pi)):
        s2 = math.sin(t + ph)
        add(p, "thigh." + sd, X, 68 + 20 * s2)
        add(p, "thigh." + sd, Y, -7 * sgn)
        add(p, "shin." + sd, X, -104 - 18 * max(0.0, math.sin(t + ph - 1.2)))
        add(p, "foot." + sd, X, 30 + 8 * math.cos(t + ph))
    _crouch_body(p, sw)
    add(p, "hips", Z, 4 * sw)
    p["_hips_loc"] = eco_hips_loc(-_crouch_drop() + 0.03 + 0.015 * abs(math.cos(t)), 0.11)
    return p


def mirror(f, n):
    """Doing her eyeliner: right hand up at her right eye, left hand holding a
    small mirror at chest height, head tipped back a touch."""
    p = base_pose()
    t = wave(f, n, 4)
    add(p, "hips", Z, 5)
    add(p, "chest", X, -1.0 * wave(f, n, 2))
    add(p, "head", X, 6)
    add(p, "head", Y, -4)
    add(p, "upperarm.R", X, 40)
    add(p, "upperarm.R", Y, -35)
    add(p, "forearm.R", X, 120 + 3 * t)
    add(p, "forearm.R", Z, 30)
    add(p, "upperarm.L", X, 30)
    add(p, "forearm.L", X, 95)
    add(p, "forearm.L", Z, -45)
    add(p, "thigh.R", X, 5)
    add(p, "shin.R", X, -10)
    p["_grip"] = 0.7
    return p


def shy(f, n):
    """Hands knotted together up under her chin, weight on her left hip,
    rocking a little on her heels, head down and turned away."""
    p = base_pose()
    r = wave(f, n)
    add(p, "hips", Z, -6)
    add(p, "hips", X, 2 * r)
    add(p, "chest", X, -3 - 1.0 * wave(f, n, 2))
    add(p, "head", X, -12)
    add(p, "head", Z, 12)
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "upperarm." + s, X, 18)
        add(p, "upperarm." + s, Y, sgn * 14)
        add(p, "forearm." + s, X, 100 + 3 * r)
        add(p, "forearm." + s, Z, sgn * 35)
    add(p, "thigh.R", X, 8)
    add(p, "thigh.R", Y, -6)
    add(p, "shin.R", X, -14)
    add(p, "foot.R", X, -10)
    p["_hips_loc"] = (-0.03, 0.0, -0.01)
    p["_grip"] = 0.5
    return p


def _reach(side):
    """Both arms straight up overhead, leaning into a side stretch."""
    p = {}
    for s, out in (("R", -1), ("L", 1)):
        add(p, "upperarm." + s, X, 155)
        # a little wide, clear of her hair
        add(p, "upperarm." + s, Y, out * 18)
        add(p, "forearm." + s, X, -4)
    add(p, "spine", Y, side * 10)
    add(p, "chest", Y, side * 12)
    add(p, "neck", Y, side * 4)
    add(p, "head", X, 8)
    p["_hips_loc"] = (-side * 0.03, 0.0, 0.0)
    return p


def _tree():
    """Tree pose: right foot up against her left thigh, knee out, palms
    pressed together at her chest."""
    p = {}
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "upperarm." + s, X, 18)
        add(p, "upperarm." + s, Y, sgn * 14)
        add(p, "forearm." + s, X, 100)
        add(p, "forearm." + s, Z, sgn * 35)
    add(p, "thigh.R", X, 30)
    add(p, "thigh.R", Y, -30)
    add(p, "thigh.R", Z, 60)
    add(p, "shin.R", X, -125)
    add(p, "foot.R", X, 20)
    add(p, "head", X, -4)
    p["_hips_loc"] = (-0.05, 0.0, -0.005)
    return p


def _warrior():
    """Warrior two: feet wide, right knee bent, arms out level, looking out
    past her right hand."""
    p = {}
    add(p, "upperarm.R", Y, -72)
    add(p, "upperarm.L", Y, 72)
    add(p, "thigh.R", Y, -22)
    add(p, "thigh.R", X, 22)
    add(p, "shin.R", X, -40)
    add(p, "thigh.L", Y, 18)
    add(p, "head", Z, -55)
    p["_hips_loc"] = (0.04, 0.0, -0.09)
    return p


def _blend(a, b, w):
    out = {}
    for src, k in ((a, 1.0 - w), (b, w)):
        for bone, turns in src.items():
            if bone == "_hips_loc":
                old = out.get(bone, (0.0, 0.0, 0.0))
                out[bone] = tuple(o + v * k for o, v in zip(old, turns))
            else:
                for axis, deg in turns:
                    add(out, bone, axis, deg * k)
    return out


def yoga(f, n):
    """On her rug, flowing slowly round four stretches: a side reach each
    way, tree pose, warrior two, then back to the first."""
    flow = [_reach(1), _reach(-1), _tree(), _warrior()]
    seg = n / len(flow)
    i = int(f // seg) % len(flow)
    t = (f - i * seg) / seg
    # ease into each stretch over its first third, then hold it
    w = min(1.0, t * 3.0)
    w = w * w * (3 - 2 * w)
    move = _blend(flow[i - 1], flow[i], w)
    p = base_pose()
    for bone, turns in move.items():
        if bone == "_hips_loc":
            p[bone] = turns
        else:
            for axis, deg in turns:
                add(p, bone, axis, deg)
    add(p, "chest", X, -1.5 * wave(f, n, 8))
    return p


# --- Pip at work, one loop for each of her businesses (downtown.gd PIP_SPOTS) ---

def _boss(p):
    """Her stand: weight on her left hip, chest up, chin up."""
    add(p, "hips", Y, -6)
    add(p, "spine", Y, 3)
    add(p, "chest", X, 4)
    add(p, "head", X, 4)
    add(p, "thigh.L", Y, 4)
    add(p, "thigh.R", Y, -3)
    add(p, "thigh.R", X, 6)
    add(p, "shin.R", X, -10)


def casino(f, n):
    """The Velvet Ace's door: shuffling a deck in front of her, riffle after
    riffle, eyes on the cards; halfway through she looks up the street to
    see who's coming, then back down."""
    p = base_pose()
    _boss(p)
    riffle = wave(f, n, 6)
    look = max(0.0, math.sin(f / n * math.pi)) ** 3   # the glance up
    add(p, "chest", X, -1.0 * wave(f, n, 2))
    add(p, "head", X, -14 + 18 * look)
    add(p, "head", Z, 22 * look)
    add(p, "head", Y, 5)
    for s, sgn in (("R", 1), ("L", -1)):
        add(p, "upperarm." + s, X, 8)
        add(p, "upperarm." + s, Y, sgn * 10)
        add(p, "forearm." + s, X, 58)
        add(p, "forearm." + s, Z, sgn * (40 - 8 * riffle))   # hands apart and together, at her waist
    add(p, "hand.R", X, 10 * riffle)
    add(p, "hand.L", X, -10 * riffle)
    p["_hips_loc"] = (-0.025, 0.0, -0.005)
    p["_grip"] = 0.8
    return p


def club(f, n):
    """The Undertow's door: a cocktail in her right hand, her left arm folded
    under it, watching the queue; a slow sip in the middle of the loop."""
    p = base_pose()
    _boss(p)
    sip = max(0.0, math.sin(f / n * math.pi)) ** 2
    add(p, "chest", X, -1.0 * wave(f, n, 3))
    add(p, "head", Z, 10 * (1 - sip) - 4)
    add(p, "head", Y, 6 * (1 - sip))
    add(p, "head", X, 8 * sip)
    # left arm across her waist, holding her right elbow
    add(p, "upperarm.L", X, 10)
    add(p, "forearm.L", X, 62)
    add(p, "forearm.L", Z, -62)
    # right: elbow on that arm, the glass in front of her chest, up to her lips for the sip
    add(p, "upperarm.R", X, 14 + 10 * sip)
    add(p, "upperarm.R", Y, 4 + 6 * sip)
    add(p, "forearm.R", X, 96 + 22 * sip)
    add(p, "forearm.R", Z, 28 + 32 * sip)
    add(p, "hand.R", Z, -10 * wave(f, n, 2))   # the swirl
    p["_hips_loc"] = (-0.025, 0.0, -0.005)
    p["_grip"] = 1.3
    return p


def rooms(f, n):
    """The corridor of rooms under the club: back to the wall, one foot up
    against it, a little black ledger open in her left hand; she ticks a line
    off, glances down the corridor at the doors, ticks another."""
    p = base_pose()
    write = wave(f, n, 8)
    look = max(0.0, math.sin(f / n * 2 * math.pi)) ** 4
    add(p, "spine", X, 4)
    add(p, "chest", X, -1.0 * wave(f, n, 2))
    add(p, "head", X, -16 + 14 * look)
    add(p, "head", Z, -26 * look)
    add(p, "hips", Y, -4)
    # the right foot up flat against the wall behind her
    add(p, "thigh.R", X, 30)
    add(p, "shin.R", X, -95)
    add(p, "foot.R", X, 20)
    add(p, "thigh.L", Y, 3)
    # the ledger
    add(p, "upperarm.L", X, 12)
    add(p, "upperarm.L", Y, 6)
    add(p, "forearm.L", X, 64)
    add(p, "forearm.L", Z, -30)
    # the pen hand, writing (small strokes, still while she looks up)
    k = 1 - look
    add(p, "upperarm.R", X, 12)
    add(p, "upperarm.R", Y, 6)
    add(p, "forearm.R", X, 66 + 3 * write * k)
    add(p, "forearm.R", Z, 46 + 4 * wave(f, n, 16) * k)
    p["_hips_loc"] = (-0.02, -0.04, -0.01)
    p["_grip"] = 1.2
    return p


SEAT = 0.78   # her hips in the high rollers' chair (its cushion is 0.7 m up, step and all)


def high(f, n):
    """Her chair in the high rollers' room: sat back, legs crossed right over
    left, her left hand on her knee, a chip walking over the knuckles of her
    right hand held up by her shoulder; she watches the stage."""
    p = base_pose()
    b = wave(f, n, 2)
    add(p, "spine", X, 6)
    add(p, "chest", X, -1.0 * b)
    add(p, "head", X, 3 + 2 * wave(f, n, 1))
    add(p, "head", Y, -6)
    add(p, "head", Z, 6 * wave(f, n, 1, 0.8))
    # legs: the left down to the floor, the right crossed over its knee
    add(p, "thigh.L", X, 82)
    add(p, "thigh.L", Y, -6)
    add(p, "shin.L", X, -78)
    add(p, "foot.L", X, 10)
    add(p, "thigh.R", X, 108)
    add(p, "thigh.R", Y, 34)
    add(p, "shin.R", X, -78)
    add(p, "foot.R", X, -18 + 6 * wave(f, n, 3))   # the toe bounces
    # left hand resting on her right knee
    add(p, "upperarm.L", X, 38)
    add(p, "upperarm.L", Y, -8)
    add(p, "forearm.L", X, 30)
    add(p, "forearm.L", Z, -30)
    # right hand up by her shoulder, the chip
    add(p, "upperarm.R", X, 20)
    add(p, "upperarm.R", Y, -30)
    add(p, "forearm.R", X, 115)
    add(p, "forearm.R", Z, 10)
    add(p, "hand.R", X, -15 + 8 * wave(f, n, 8))
    p["_hips_loc"] = (0.0, -0.06, SEAT - HIPS)
    p["_grip"] = 0.9
    return p


PIP_POSES = {
    "work_casino": (casino, 150),
    "work_club": (club, 180),
    "work_rooms": (rooms, 180),
    "work_high": (high, 180),
}


POSES = {
    "idle_lounge": (lounge, 150),
    "idle_smoke": (smoke, 180),
    "idle_read": (read, 150),
    "idle_sway": (sway, 120),
    "idle_yoga": (yoga, 600),
    "scene_sit": (sit, 150),
    "scene_mirror": (mirror, 120),
    "scene_shy": (shy, 120),
    "chained": (chained, 180),
    "stasis": (stasis, 240, 20),
    "move_walk": (sneak_walk, 32, 2),
    "move_run": (run, 22, 1),
    "move_crouch": (crouch, 60),
    "move_crouch_walk": (crouch_walk, 36, 2),
}


def make(arm):
    arm.animation_data_create()
    bpy.context.scene.render.fps = FPS
    keyed = [BONE[n] for n in ORDER] + ["J_Bip_%s_%s%d" % (s, f, j) for s in "RL" for f in FINGERS + ("Thumb",) for j in (1, 2, 3)]
    keyed = [k for k in keyed if k in arm.pose.bones]
    acts = []
    for name, spec in (PIP_POSES if WHO == "pip" else POSES).items():
        fn, n = spec[0], spec[1]
        step = spec[2] if len(spec) > 2 else 10
        a = bpy.data.actions.new(name)
        a.use_fake_user = True
        arm.animation_data.action = a
        for f in range(0, n + 1, step):
            key_pose(arm, f, fn(f, n), keyed)
        acts.append(a)
    return acts


CHAINS = [["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck", "J_Bip_C_Head"]] + [
    ["J_Bip_C_UpperChest", "J_Bip_%s_Shoulder" % s, "J_Bip_%s_UpperArm" % s, "J_Bip_%s_LowerArm" % s, "J_Bip_%s_Hand" % s, "J_Bip_%s_Middle3" % s]
    for s in "RL"] + [["J_Bip_C_Hips", "J_Bip_%s_UpperLeg" % s, "J_Bip_%s_LowerLeg" % s, "J_Bip_%s_Foot" % s, "J_Bip_%s_ToeBase" % s] for s in "RL"]


def stick(arm):
    """A stick figure of the posed rig, joint to joint (the skinned meshes
    preview badly here, and imported bone tails point anywhere)."""
    import bmesh
    from mathutils import Matrix
    bm = bmesh.new()
    def at(name):
        return arm.matrix_world @ arm.pose.bones[name].head
    for chain in CHAINS:
        names = [n for n in chain if n in arm.pose.bones]
        for n0, n1 in zip(names, names[1:]):
            a, b = at(n0), at(n1)
            d = b - a
            if d.length < 1e-4:
                continue
            m = Matrix.Translation((a + b) / 2) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.025, radius2=0.025, depth=d.length, matrix=m)
    head = at("J_Bip_C_Head")
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.1, matrix=Matrix.Translation(head + (head - at("J_Bip_C_Neck")).normalized() * 0.08))
    me = bpy.data.meshes.new("stick")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("stick", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def shots(arm, acts, out):
    os.makedirs(out, exist_ok=True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = not MESH
    if WHO == "pip":   # her chair (seat 0.7 m up, step and all) and the corridor wall behind her
        for name, at, size in (("chair", (0, -0.05, 0.35), (0.8, 0.7, 0.7)), ("back", (0, -0.42, 0.95), (0.8, 0.12, 1.0)), ("wall", (0, -0.42, 1.2), (3.0, 0.1, 2.4))):
            bpy.ops.mesh.primitive_cube_add(location=at)
            ob = bpy.context.active_object
            ob.name = name
            ob.scale = Vector(size) / 2
    slab = bpy.data.meshes.new("slab")
    slab.from_pydata([(-0.9, -0.8, 0.31), (0.9, -0.8, 0.31), (0.9, 0.8, 0.31), (-0.9, 0.8, 0.31)], [], [(0, 1, 2, 3)])
    slab_ob = bpy.data.objects.new("slab", slab)
    bpy.context.scene.collection.objects.link(slab_ob)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    floor = bpy.data.meshes.new("floor")
    floor.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    bpy.data.objects.new("floor", floor)
    sc.collection.objects.link(bpy.data.objects["floor"])
    k = HIPS / 0.85   # framed for their height
    cams = {"front": (Vector((1.2, 3.2, 1.2)) * k, Vector((0, 0, 0.65)) * k), "side": (Vector((3.4, 0.0, 0.9)) * k, Vector((0, 0, 0.6)) * k)}
    for a in acts:
        arm.animation_data.action = a
        end = a.frame_range[1]
        # the yoga flow at each stretch it holds; the rest midway
        frames = [int(end * (k + 0.7) / 4) for k in range(4)] if a.name == "idle_yoga" else [int(end / 2)]
        for fi, frame in enumerate(frames):
            sc.frame_set(frame)
            bpy.context.view_layer.update()
            slab_ob.hide_render = a.name != "idle_lounge"
            for name, shown in (("chair", "work_high"), ("back", "work_high"), ("wall", "work_rooms")):
                if name in bpy.data.objects:
                    bpy.data.objects[name].hide_render = a.name != shown
            fig = stick(arm)
            fig.hide_render = MESH
            tag = a.name if len(frames) == 1 else "%s%d" % (a.name, fi + 1)
            for view, (at, look) in cams.items():
                cam_data = bpy.data.cameras.new("cam")
                cam = bpy.data.objects.new("cam", cam_data)
                sc.collection.objects.link(cam)
                cam.location = at
                cam.rotation_euler = (look - at).to_track_quat("-Z", "Y").to_euler()
                sc.camera = cam
                sc.render.filepath = os.path.join(out, "%s_%s.png" % (tag, view))
                bpy.ops.render.render(write_still=True)
                bpy.data.objects.remove(cam)
            bpy.data.objects.remove(fig)


def main():
    arm = load()
    acts = make(arm)
    if SHOTS:
        shots(arm, acts, SHOTS)
    for o in bpy.data.objects:
        o.select_set(o == arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=False, export_materials="NONE", export_yup=True, export_apply=False)
    print("exported", OUT, [a.name for a in acts])


main()
