"""Builds the people of Solace (the town past the temple's front gate) from
the same VRoid preset as Eco and the hub NPCs (preset/anime-fox-girl-preset.zip
-> Untitled.glb), so they share the toon look. Run through Blender 4, once per
person:

    blender -b --factory-startup -P tools/town/build_townsfolk.py -- <Untitled.glb> <repo root> <who|all>

`all` re-runs Blender for every person in PEOPLE. Everyone here is a grown
adult, from their twenties to their seventies:
- pell: Auntie Pell, fifties, keeps a market stall on the plaza. Fuller
  figure, a greying bob, a mustard tunic, a red apron, rolled sleeves.
- kit: Kit, twenties, the town courier. Slim, a short teal crop, a hi-vis
  orange jacket with silver bands, black leggings.
- wren: Wren, thirties, works the greenhouse. Long honey hair, green overalls
  over a cream tee.
- tobin: Old Tobin, seventies, sits on benches and knows everyone. Stout,
  bald with a white horseshoe, a brown cardigan, grey slacks.
- dez: Dez, thirties, the salvage yard mechanic. Lean, a black crop, navy
  coveralls, grease on the knees.
- harl: Harl, forties, a trader. Sturdy, a brown crop and stubble, a long
  olive coat over a rust shirt.
- mira: forties, tall, long black hair, a violet long coat.
- jun: twenties, slim, a magenta crop, a teal top with pink bands.
- rosa: sixties, small and round, a white bob, a blue cardigan over a rose
  top. Tobin's bench friend.
- bram: twenties, a big dock hand, a ginger crop, a sleeveless tee, cargo
  trousers.
Each gets idle, talk, walk and sit loops. Writes assets/models/npc/town_<who>.glb
and assets/textures/npc/town_<who>/*.png; assets/models/npc/npc_import.gd
gives them the hub NPCs' toon shading (scripts/hub/townsfolk.gd spawns them).
"""
import math
import os
import subprocess
import sys

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, ROOT, WHO = argv[0], argv[1], argv[2]

# --- the cast -----------------------------------------------------------------------
# sex: which builder body they start from; skin: multiplies the preset skin;
# hair: a dye ramp (dark to light, linear), cut: how it's cut; body: shape
# (female: push amounts; male: torso cross-sections); outfit: painted clothes.
GREY_BROWN = [(0.30, (0.03, 0.02, 0.016)), (0.62, (0.09, 0.07, 0.06)), (0.86, (0.25, 0.23, 0.22)), (1.0, (0.55, 0.54, 0.53))]
TEAL = [(0.30, (0.002, 0.03, 0.035)), (0.62, (0.01, 0.12, 0.13)), (0.86, (0.05, 0.35, 0.36)), (1.0, (0.3, 0.75, 0.72))]
HONEY = [(0.30, (0.09, 0.045, 0.012)), (0.62, (0.3, 0.17, 0.05)), (0.86, (0.55, 0.38, 0.14)), (1.0, (0.85, 0.7, 0.4))]
WHITE = [(0.30, (0.3, 0.29, 0.28)), (0.62, (0.5, 0.49, 0.48)), (0.86, (0.7, 0.69, 0.67)), (1.0, (0.9, 0.89, 0.87))]
BLACK = [(0.30, (0.006, 0.005, 0.005)), (0.62, (0.018, 0.015, 0.014)), (0.86, (0.05, 0.045, 0.042)), (1.0, (0.16, 0.15, 0.15))]
BROWN = [(0.30, (0.02, 0.009, 0.004)), (0.62, (0.06, 0.03, 0.014)), (0.86, (0.14, 0.08, 0.04)), (1.0, (0.35, 0.24, 0.15))]

PEOPLE = {
    "pell": {
        "sex": "f", "height": 1.62, "head": 0.95, "legs": 0.99, "skin": (0.82, 0.63, 0.5),
        "hair": GREY_BROWN, "cut": "bob", "iris": (0.18, 0.1, 0.05), "lips": (0.7, 0.4, 0.38), "age": 0.7,
        "body": {"hips": 0.018, "bust": 0.008, "belly": 0.036, "waist": 0.03, "arms": 0.018},
        "boots": ((0.02, 0.012, 0.008), (0.16, 0.1, 0.06)),
        "outfit": {"top": (0.45, 0.3, 0.04), "sleeve": 0.3, "hem": 0.7, "neck": 0.03,
                   "bottom": (0.05, 0.045, 0.04), "cuff_z": 0.14,
                   "apron": (0.42, 0.04, 0.03), "apron_lo": 0.64},
        "stance": "easy", "voice": {"pitch": 270.0, "spread": 6.0, "rate": 15.5, "bright": 0.4, "breath": 0.05, "gain": 0.5},
    },
    "kit": {
        "sex": "f", "height": 1.68, "head": 0.96, "legs": 1.04, "skin": (0.56, 0.4, 0.31),
        "hair": TEAL, "cut": "crop", "iris": (0.12, 0.07, 0.035), "lips": (0.55, 0.32, 0.3), "age": 0.0,
        "body": {"slim": 0.02},
        "boots": ((0.01, 0.01, 0.012), (0.08, 0.08, 0.09)),
        "outfit": {"top": (0.75, 0.16, 0.01), "sleeve": 0.468, "hem": 0.76, "neck": 0.0, "collar": (0.04, 0.04, 0.045),
                   "bands": (0.62, 0.64, 0.66), "zip": (0.05, 0.05, 0.05),
                   "bottom": (0.012, 0.012, 0.014), "cuff_z": 0.12, "stripe": (0.75, 0.16, 0.01)},
        "stance": "weight", "voice": {"pitch": 330.0, "spread": 7.0, "rate": 18.5, "bright": 0.3, "breath": 0.03, "gain": 0.45},
    },
    "wren": {
        "sex": "f", "height": 1.65, "head": 0.95, "legs": 1.02, "skin": (1.0, 0.96, 0.94),
        "hair": HONEY, "cut": "long", "iris": (0.16, 0.3, 0.14), "lips": (0.8, 0.45, 0.45), "age": 0.15,
        "body": {"slim": 0.008, "muscle": 0.009},
        "boots": ((0.03, 0.02, 0.01), (0.22, 0.15, 0.08)),
        "outfit": {"top": (0.62, 0.58, 0.48), "sleeve": 0.24, "hem": 0.7, "neck": 0.03,
                   "bottom": (0.08, 0.2, 0.07), "cuff_z": 0.16, "overalls": (0.08, 0.2, 0.07),
                   "patch": (0.45, 0.3, 0.06)},
        "stance": "pockets", "voice": {"pitch": 290.0, "spread": 4.0, "rate": 14.0, "bright": 0.25, "breath": 0.08, "gain": 0.45},
    },
    "tobin": {
        "sex": "m", "height": 1.7, "head": 0.93, "legs": 0.97, "skin": (0.9, 0.76, 0.64),
        "hair": WHITE, "cut": "horseshoe", "iris": (0.18, 0.22, 0.26), "lips": None, "age": 1.0, "stubble": 0.15,
        "build": {"hip": 0.146, "waist": 0.152, "chest": 0.15, "hip_front": 0.088, "belly": 0.155, "pecs": 0.088, "back": 0.072,
                  "thigh": 0.06, "knee": 0.047, "calf": 0.05, "ankle": 0.037, "widen": 0.03, "hand": 1.12, "arms": 0.016, "neck": 0.018},
        "boots": ((0.02, 0.014, 0.01), (0.14, 0.1, 0.07)),
        "outfit": {"top": (0.6, 0.56, 0.48), "sleeve": 0.468, "hem": 0.72, "neck": 0.0, "cardigan": (0.17, 0.09, 0.045),
                   "bottom": (0.16, 0.16, 0.17), "cuff_z": 0.12, "belt": (0.04, 0.025, 0.015)},
        "stance": "belly", "gait": 0.7, "voice": {"pitch": 115.0, "spread": 4.0, "rate": 11.0, "bright": 0.45, "breath": 0.14, "gain": 0.55},
    },
    "dez": {
        "sex": "m", "height": 1.76, "head": 0.93, "legs": 1.02, "skin": (0.86, 0.7, 0.56),
        "hair": BLACK, "cut": "crop", "iris": (0.1, 0.06, 0.03), "lips": None, "age": 0.1, "stubble": 0.3,
        "build": {"hip": 0.12, "waist": 0.106, "chest": 0.124, "hip_front": 0.064, "belly": 0.082, "pecs": 0.094, "back": 0.058,
                  "thigh": 0.05, "knee": 0.041, "calf": 0.045, "ankle": 0.034, "widen": 0.035, "hand": 1.14, "arms": 0.004, "neck": 0.01},
        "boots": ((0.012, 0.01, 0.008), (0.1, 0.08, 0.06)),
        "outfit": {"top": (0.03, 0.05, 0.13), "sleeve": 0.3, "hem": 0.0, "neck": 0.0, "zip": (0.35, 0.35, 0.36),
                   "bottom": (0.03, 0.05, 0.13), "cuff_z": 0.12, "belt": (0.02, 0.02, 0.02),
                   "grease": (0.01, 0.01, 0.012), "collar": (0.02, 0.035, 0.09)},
        "stance": "clasp", "voice": {"pitch": 140.0, "spread": 5.0, "rate": 15.0, "bright": 0.5, "breath": 0.06, "gain": 0.52},
    },
    "harl": {
        "sex": "m", "height": 1.8, "head": 0.92, "legs": 1.0, "skin": (0.5, 0.35, 0.27),
        "hair": BROWN, "cut": "crop", "iris": (0.08, 0.05, 0.03), "lips": None, "age": 0.35, "stubble": 0.6,
        "build": {"hip": 0.134, "waist": 0.134, "chest": 0.144, "hip_front": 0.074, "belly": 0.118, "pecs": 0.09, "back": 0.068,
                  "thigh": 0.058, "knee": 0.046, "calf": 0.051, "ankle": 0.037, "widen": 0.05, "hand": 1.2, "arms": 0.016, "neck": 0.02},
        "boots": ((0.02, 0.012, 0.006), (0.18, 0.1, 0.05)),
        "outfit": {"top": (0.3, 0.09, 0.04), "sleeve": 0.468, "hem": 0.72, "neck": 0.02,
                   "coat": (0.13, 0.15, 0.07), "coat_lo": 0.34, "bottom": (0.09, 0.075, 0.06), "cuff_z": 0.12,
                   "belt": (0.06, 0.03, 0.012), "scarf": (0.5, 0.35, 0.12)},
        "stance": "easy", "voice": {"pitch": 105.0, "spread": 3.0, "rate": 12.5, "bright": 0.6, "breath": 0.07, "gain": 0.58},
    },
    "mira": {
        "sex": "f", "height": 1.7, "head": 0.95, "legs": 1.04, "skin": (0.46, 0.32, 0.25),
        "hair": BLACK, "cut": "long", "iris": (0.1, 0.06, 0.03), "lips": (0.45, 0.2, 0.25), "age": 0.4,
        "body": {"slim": 0.013, "waist": -0.004},
        "boots": ((0.01, 0.008, 0.01), (0.09, 0.06, 0.08)),
        "outfit": {"top": (0.5, 0.42, 0.3), "sleeve": 0.468, "hem": 0.74, "neck": 0.03,
                   "coat": (0.2, 0.06, 0.3), "coat_lo": 0.4, "bottom": (0.03, 0.025, 0.035), "cuff_z": 0.12},
        "stance": "weight", "voice": {"pitch": 250.0, "spread": 3.5, "rate": 13.5, "bright": 0.3, "breath": 0.06, "gain": 0.48},
    },
    "jun": {
        "sex": "m", "height": 1.74, "head": 0.94, "legs": 1.04, "skin": (0.95, 0.82, 0.68),
        "hair": [(0.30, (0.06, 0.0, 0.03)), (0.62, (0.25, 0.01, 0.12)), (0.86, (0.6, 0.06, 0.32)), (1.0, (0.95, 0.4, 0.7))],
        "cut": "crop", "iris": (0.12, 0.08, 0.04), "lips": None, "age": 0.0, "stubble": 0.0,
        "build": {"hip": 0.114, "waist": 0.098, "chest": 0.114, "hip_front": 0.06, "belly": 0.078, "pecs": 0.088, "back": 0.054,
                  "thigh": 0.046, "knee": 0.039, "calf": 0.042, "ankle": 0.033, "widen": 0.022, "hand": 1.1, "arms": 0.0, "neck": 0.006},
        "boots": ((0.06, 0.06, 0.07), (0.6, 0.6, 0.62)),
        "outfit": {"top": (0.02, 0.3, 0.32), "sleeve": 0.468, "hem": 0.72, "neck": 0.0, "bands": (0.85, 0.2, 0.55),
                   "bottom": (0.04, 0.04, 0.05), "cuff_z": 0.14, "stripe": (0.85, 0.2, 0.55)},
        "stance": "easy", "voice": {"pitch": 160.0, "spread": 6.0, "rate": 17.0, "bright": 0.4, "breath": 0.05, "gain": 0.5},
    },
    "rosa": {
        "sex": "f", "height": 1.58, "head": 0.95, "legs": 0.98, "skin": (0.92, 0.8, 0.7),
        "hair": WHITE, "cut": "bob", "iris": (0.2, 0.25, 0.3), "lips": (0.7, 0.42, 0.45), "age": 1.0,
        "body": {"hips": 0.008, "bust": 0.004, "belly": 0.036, "waist": 0.034, "arms": 0.014},
        "boots": ((0.02, 0.015, 0.012), (0.2, 0.15, 0.12)),
        "outfit": {"top": (0.55, 0.22, 0.25), "sleeve": 0.468, "hem": 0.72, "neck": 0.02, "cardigan": (0.15, 0.25, 0.32),
                   "bottom": (0.12, 0.1, 0.16), "cuff_z": 0.18},
        "stance": "hands_front", "gait": 0.75, "voice": {"pitch": 320.0, "spread": 5.0, "rate": 13.0, "bright": 0.3, "breath": 0.1, "gain": 0.45},
    },
    "bram": {
        "sex": "m", "height": 1.84, "head": 0.92, "legs": 1.0, "skin": (0.7, 0.52, 0.4),
        "hair": [(0.30, (0.05, 0.02, 0.005)), (0.62, (0.14, 0.06, 0.015)), (0.86, (0.3, 0.14, 0.04)), (1.0, (0.6, 0.35, 0.15))],
        "cut": "crop", "iris": (0.15, 0.2, 0.12), "lips": None, "age": 0.0, "stubble": 0.35,
        "build": {"hip": 0.128, "waist": 0.118, "chest": 0.164, "hip_front": 0.07, "belly": 0.09, "pecs": 0.09, "back": 0.08,
                  "thigh": 0.062, "knee": 0.048, "calf": 0.056, "ankle": 0.039, "widen": 0.07, "hand": 1.25, "arms": 0.028, "neck": 0.03,
                  "delts": 0.016},
        "boots": ((0.02, 0.015, 0.008), (0.2, 0.14, 0.07)),
        "outfit": {"top": (0.55, 0.53, 0.48), "sleeve": 0.17, "hem": 0.74, "neck": 0.015,
                   "bottom": (0.2, 0.2, 0.13), "cuff_z": 0.14, "belt": (0.05, 0.03, 0.015)},
        "stance": "clasp", "voice": {"pitch": 98.0, "spread": 4.0, "rate": 13.5, "bright": 0.55, "breath": 0.05, "gain": 0.58},
    },
}

if WHO == "all":
    for who in PEOPLE:
        subprocess.check_call([bpy.app.binary_path, "-b", "--factory-startup", "-P", os.path.abspath(__file__), "--", SRC, ROOT, who])
    sys.exit(0)

P_ = PEOPLE[WHO]
NAME = "town_" + WHO

# The hub NPC builder's helpers (and through it Eco's), without running it.
# Women start from Mom's build, men from Biggie's.
_npc_path = os.path.join(ROOT, "tools", "npc", "build_npc.py")
_src = open(_npc_path).read()
_src = _src[:_src.rindex("\nmain()")]
_saved = sys.argv
sys.argv = ["blender", "--", SRC, ROOT, "mom" if P_["sex"] == "f" else "biggie", "--no-export"]
N = {"__name__": "build_npc"}
exec(compile(_src, _npc_path, "exec"), N)
sys.argv = _saved
E = N["E"]
TEX_OUT = os.path.join(ROOT, "assets", "textures", "npc", NAME)
GLB_OUT = os.path.join(ROOT, "assets", "models", "npc", NAME + ".glb")
E["TEX_OUT"] = TEX_OUT
N["TEX_OUT"] = TEX_OUT
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
ss, smooth = E["ss"], E["smooth"]
read_px, write_png, to_lin, to_srgb = E["read_px"], E["write_png"], E["to_lin"], E["to_srgb"]
ramp, lum, mat_index, delete_faces = E["ramp"], E["lum"], E["mat_index"], E["delete_faces"]
push, gauss, move_verts, fold_hair = N["push"], N["gauss"], N["move_verts"], N["fold_hair"]
INK = N["INK"]
BAKE = 1024   # seen across a street: half the hub NPCs' texture size


# --- hair ---------------------------------------------------------------------------------

def cut_hair():
    cut = P_["cut"]
    if cut == "bob":   # chin length, the fringe swept up off her eyes
        def rules(p, m):
            if m == 1:
                return 1.33 - 0.02 * smooth(0.0, -0.05, p.x), 0.03, 0.0
            return 1.235, 0.03, 0.1
        fold_hair(rules, drop_below=1.2)
    elif cut == "crop" and P_["sex"] == "f":   # short and choppy, ears showing
        def rules(p, m):
            if m == 1:
                return 1.315, 0.022, 0.0
            jag = 0.008 * math.sin(math.atan2(p.y - 0.02, p.x) * 11.0)
            return 1.275 + jag, 0.025, 0.3
        fold_hair(rules, drop_below=1.24)
    elif cut == "long":   # the preset's length kept, the fringe lifted
        def rules(p, m):
            if m == 1:
                return 1.33 + 0.015 * smooth(0.0, 0.05, p.x), 0.03, 0.0
            return -1.0, 0.03, 0.0
        fold_hair(rules)
    elif cut == "horseshoe":   # Biggie's: bald crown, the sides and back left
        bpy.data.objects.remove(bpy.data.objects["Hair"])
        body = bpy.data.objects["Body"]
        cap = mat_index(body, "HairBack")

        def bald(c):
            return c.z > 1.325 + 0.035 * smooth(-0.02, 0.07, c.y) or (c.y < -0.035 and c.z > 1.29)
        delete_faces(body, lambda f: not (f.material_index in cap and bald(f.calc_center_median())))
    else:   # men's crop: no hair mesh, just the scalp shell, cut back off the brow
        bpy.data.objects.remove(bpy.data.objects["Hair"])
        body = bpy.data.objects["Body"]
        cap = mat_index(body, "HairBack")
        delete_faces(body, lambda f: not (f.material_index in cap and f.calc_center_median().y < -0.05 and f.calc_center_median().z > 1.3))


# --- body ---------------------------------------------------------------------------------

def body_female():
    b = P_["body"]

    def amount(P, N):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        out = N[:, 0] * np.sign(x)
        hip = b.get("hips", 0.0) * np.exp(-((z - 0.76) / 0.085) ** 2) * ss(0.1, 0.65, out)
        glute = b.get("hips", 0.0) * 1.2 * np.exp(-((ax - 0.064) / 0.064) ** 2 - ((z - 0.755) / 0.08) ** 2) * ss(-0.02, 0.04, y)
        thigh = b.get("hips", 0.0) * 0.7 * ss(0.4, 0.55, z) * ss(0.8, 0.68, z)
        bust = b.get("bust", 0.0) * gauss(P, 0.062, -0.105, 1.035, 0.052, 0.055, 0.055) * ss(-0.03, -0.07, y)
        waist = b.get("waist", 0.0) * np.exp(-((z - 0.92) / 0.07) ** 2) * (0.3 + 0.7 * np.clip(out, 0, 1)) * (ax < 0.2)
        belly = b.get("belly", 0.0) * gauss(P, 0.0, -0.08, 0.86, 0.08, 0.06, 0.06) * ss(-0.02, -0.06, y)
        arms = b.get("arms", 0.0) * ss(0.11, 0.15, ax) * ss(0.33, 0.27, ax) * (np.abs(z - 1.145) < 0.07)
        # slim: less hip, seat, thigh and bust all over
        slim = -b.get("slim", 0.0) * (np.exp(-((z - 0.74) / 0.08) ** 2) * (0.4 + 0.6 * np.clip(out, 0, 1))
                                      + 0.8 * ss(0.4, 0.55, z) * ss(0.75, 0.68, z)
                                      + 0.5 * np.exp(-((ax - 0.064) / 0.06) ** 2 - ((z - 0.755) / 0.08) ** 2) * ss(-0.02, 0.04, y)
                                      + 0.5 * ss(0.18, 0.4, z) * ss(0.48, 0.4, z)
                                      + 0.6 * gauss(P, 0.062, -0.105, 1.035, 0.052, 0.055, 0.055) * ss(-0.03, -0.07, y)
                                      + 0.4 * ss(0.11, 0.15, ax) * ss(0.5, 0.44, ax) * (np.abs(z - 1.145) < 0.07))
        # muscle: shoulders, upper arms, calves and the front of the thighs
        mus = b.get("muscle", 0.0)
        muscle = mus * (np.exp(-((ax - 0.14) / 0.03) ** 2 - ((z - 1.135) / 0.035) ** 2)
                        + 0.7 * np.exp(-((ax - 0.22) / 0.04) ** 2) * (np.abs(z - 1.145) < 0.06)
                        + 0.8 * np.exp(-((z - 0.33) / 0.05) ** 2) * ss(0.0, 0.03, y) * (z < 0.5)
                        + 0.6 * np.exp(-((z - 0.56) / 0.06) ** 2) * ss(0.0, -0.03, y) * (z < 0.68))
        return hip + glute + thigh + bust + waist + belly + arms + slim + muscle
    print("%s body: up to %.1f mm" % (WHO, push(bpy.data.objects["Body"], amount, passes=7) * 1000))


def male_sections(b):
    """A man's torso and leg cross-sections from his build: half widths at the
    hip, waist and chest, how far the front stands out at the hip, belly and
    pecs, and the back; leg radii at the thigh, knee, calf and ankle. Torso
    rows are (z, half width, front, back) about y = -0.02, as Biggie's TORSO."""
    h, w, c = b["hip"], b["waist"], b["chest"]
    hf, bf, pf, bk = b["hip_front"] - 0.02, b["belly"] - 0.02, b["pecs"] - 0.02, b["back"] + 0.02
    torso = [(0.68, h * 0.97, hf * 0.9, bk + 0.004), (0.74, h, hf, bk + 0.012),
             (0.80, (h + w) / 2, (hf + bf) / 2, bk + 0.004), (0.86, w, bf, bk - 0.006),
             (0.92, w * 0.6 + c * 0.4, bf * 0.6 + pf * 0.4, bk - 0.008), (0.98, c * 0.96, max(pf, bf * 0.78), bk - 0.002),
             (1.04, c, pf * 0.95, bk + 0.006), (1.10, c * 0.9, pf * 0.82, bk + 0.004)]
    cx = 0.0686
    top = max(h - cx, b["thigh"])
    legs = [(0.14, b["ankle"]), (0.24, b["calf"] * 0.9), (0.34, b["calf"]), (0.46, b["knee"]),
            (0.56, b["thigh"]), (0.64, (b["thigh"] + top) / 2), (0.70, top)]
    return torso, legs


def body_male(arm):
    """Biggie's way (build_npc.py body_biggie): the torso and legs moved out or
    in to cross-sections (male_sections()), so the preset's waist, hips and
    bust are gone, not padded over; then the neck, arms and shoulders for
    his build, broader shoulders and bigger hands."""
    b = P_["build"]
    TORSO, LEGS = male_sections(b)
    profile, reshape = N["profile"], N["reshape"]
    body = bpy.data.objects["Body"]

    def torso(P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        A, F, B = profile(TORSO, z)
        cy = -0.02
        dx, dy = x, y - cy
        D = np.where(dy < 0, F, B)
        n = 2.4
        k = 1.0 / np.maximum((np.abs(dx / A) ** n + np.abs(dy / D) ** n) ** (1 / n), 1e-6)
        Q = P.copy()
        Q[:, 0] = dx * k
        Q[:, 1] = cy + dy * k
        w = ss(0.66, 0.72, z) * ss(1.13, 1.09, z)
        w *= 1 - ss(1.06, 1.1, z) * ss(0.1, 0.14, np.abs(x))
        # down by the crotch, leave what's deep inside the section alone (the
        # inner thighs, the crotch itself) or it's dragged out into a shelf
        w *= 1 - ss(0.82, 0.76, z) * (1 - ss(0.45, 0.7, 1 / k))
        return Q, w

    def legs(P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        (R,) = profile(LEGS, z)
        s = np.sign(x)
        cx = s * 0.0686
        cy = 0.012
        dx, dy = x - cx, y - cy
        r = np.maximum(np.hypot(dx, dy), 1e-6)
        inner = (dx * s) < 0
        lim = np.abs(cx) - 0.003
        Rx = np.where(inner, np.minimum(R, lim), R)
        Rt = np.hypot(Rx * dx / r, R * 0.92 * dy / r)
        Q = P.copy()
        Q[:, 0] = cx + dx * (Rt / r)
        Q[:, 1] = cy + dy * (Rt / r)
        return Q, ss(0.12, 0.18, z) * ss(0.73, 0.67, z)
    # A few short passes rather than one long one: the smoothing spreads each
    # move, so one pass only half flattens something as local as the bust.
    for _ in range(4):
        moved = reshape(body, torso, passes=4)
    print("%s torso: last %.1f mm" % (WHO, moved * 1000))
    for _ in range(2):
        moved = reshape(body, legs, passes=4)
    print("%s legs: last %.1f mm" % (WHO, moved * 1000))
    # Paint his clothes on this shape, not the preset's: a coat's edge drawn
    # straight on her would curve round a bust he no longer has.
    rest = body.data.attributes["rest"].data
    for v in body.data.vertices:
        rest[v.index].vector = v.co

    def amount(P, N_):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        neck = b["neck"] * ss(1.11, 1.15, z) * ss(1.26, 1.21, z) * (ax < 0.07)
        traps = b["neck"] * gauss(P, 0.08, 0.01, 1.15, 0.06, 0.05, 0.035)
        # thicker upper arms, tapering to the wrist
        arms = b["arms"] * ss(0.1, 0.14, ax) * ss(0.5, 0.44, ax) * (1 - 0.6 * ss(0.28, 0.44, ax)) * (np.abs(z - 1.145) < 0.08)
        delts = b.get("delts", 0.0) * (np.exp(-((ax - 0.15) / 0.035) ** 2 - ((z - 1.14) / 0.04) ** 2)
                                      + 0.6 * np.exp(-((ax - 0.25) / 0.04) ** 2 - ((z - 1.15) / 0.035) ** 2) * ss(0.0, 0.02, -y + 0.01))
        calves = b.get("delts", 0.0) * 0.5 * np.exp(-((z - 0.33) / 0.05) ** 2) * ss(0.0, 0.03, y - 0.0)
        return neck + traps + arms + delts + calves
    print("%s arms, neck: up to %.1f mm" % (WHO, push(body, amount, passes=8) * 1000))

    widen_by, hand = b["widen"], b["hand"]
    wrist = arm.data.bones["J_Bip_L_Hand"].head_local.x

    def widen(p):
        ax, s = abs(p.x), (1 if p.x >= 0 else -1)
        w = smooth(1.02, 1.12, p.z) * smooth(0.03, 0.09, ax) * smooth(1.3, 1.2, p.z)
        q = Vector((p.x + s * widen_by * w, p.y, p.z))
        if ax > wrist - 0.01 and abs(p.z - 1.145) < 0.08:
            c = Vector((s * (wrist + widen_by), 0.022, 1.145))
            q = c + (q - c) * (1 + (hand - 1) * smooth(wrist - 0.01, wrist + 0.02, ax))
        return q
    move_verts(body, lambda i, p: widen(p))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for e in arm.data.edit_bones:
        e.head, e.tail = widen(e.head.copy()), widen(e.tail.copy())
    bpy.ops.object.mode_set(mode="OBJECT")


# --- face ---------------------------------------------------------------------------------

def shape_face():
    if P_["sex"] == "m":
        N["face_biggie"]()
    else:
        N["scale_eyes"](bpy.data.objects["Face"], 0.92 if P_["age"] > 0.5 else 0.96)


def face_paint(face, img):
    """The preset's face recoloured: their skin, a toned-down blush, lip
    colour, age lines and stubble, painted from rest positions."""
    px = read_px(img).copy()
    H, W = px.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    yy = H - 1 - yy
    w = np.zeros((H, W))
    for cx in (330, 690):
        w = np.maximum(w, np.clip(1.4 - (((xx - cx) / 130.0) ** 2 + ((yy - 625) / 85.0) ** 2), 0, 1))
    rgb = px[..., :3]
    pink = (rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2) * 255
    d = np.clip(pink - 19.0, 0, None) * w * 0.9 / 255
    rgb[..., 0] -= d * 2 / 3
    rgb[..., 1] += d / 3
    rgb[..., 2] += d / 3
    px[..., :3] = px[..., :3] * np.array(P_["skin"])
    pos, mask = E["face_position_map"](face, W, H)
    x, y, z = np.abs(pos[..., 0]), pos[..., 1], pos[..., 2]

    def tint(col, amount):
        a = (amount * mask)[..., None]
        px[..., :3] = px[..., :3] * (1 - a) + px[..., :3] * np.array(col) * a

    def line(ax_, az, bx, bz, width):
        a, b = np.array((ax_, az)), np.array((bx, bz))
        ab = b - a
        t = np.clip(((x - a[0]) * ab[0] + (z - a[1]) * ab[1]) / ab.dot(ab), 0, 1)
        return 1 - ss(width * 0.4, width, np.hypot(x - (a[0] + t * ab[0]), z - (a[1] + t * ab[1])))
    front = y < -0.02
    dz = z - 1.2397
    lips = (pos[..., 0] / 0.0098) ** 2 + (dz / np.where(dz < 0, 0.0036, 0.0021)) ** 2
    if P_["lips"] is not None:
        tint(P_["lips"], 0.55 * (1 - ss(0.35, 1.0, lips)) * (y < -0.04))
    age = P_["age"]
    if age > 0.2:
        lines = (line(0.0, 1.334, 0.035, 1.336, 0.0009) * (age - 0.3)
                 + line(0.066, 1.288, 0.076, 1.283, 0.0008) + line(0.066, 1.292, 0.077, 1.293, 0.0008)
                 + line(0.03, 1.275, 0.052, 1.277, 0.001) * 0.7 + line(0.016, 1.255, 0.024, 1.236, 0.001) * age)
        tint((0.62, 0.48, 0.42), np.clip(lines, 0, 1) * 0.55 * age * front)
    if P_.get("stubble", 0.0) > 0.0:
        jaw = ss(1.25, 1.235, z) * ss(1.17, 1.2, z) * (y < -0.01)
        lip_top = np.exp(-((pos[..., 0] / 0.016) ** 2 + ((z - 1.247) / 0.004) ** 2))
        grain = 0.75 + 0.25 * np.sin(xx * 2.1) * np.sin(yy * 1.7)
        tint((0.45, 0.42, 0.42), np.clip(jaw + lip_top, 0, 1) * grain * P_["stubble"] * ss(0.6, 1.4, lips))
    return px


# --- clothes, painted on and baked -------------------------------------------------------

def clothes_graph(nt, skin):
    """Their outfit, worked out per pixel from each point's rest position (as
    build_npc.py's clothes_graph). Returns the albedo socket."""
    o = P_["outfit"]
    g = E["NG"](nt)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "rest"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(at.outputs["Vector"], sep.inputs[0])
    x, y, z = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    ax = g.abs(x)
    front = g.sub(1.0, g.sstep(-0.045, -0.02, y))
    back = g.sub(1.0, front)
    AA = 0.00045

    def cov(d):
        return g.sstep(-AA, AA, d)

    def edge(d, w=0.0008):
        return g.band(d, 0.0, w)

    def sine(v, period):
        return g.op("SINE", g.mul(v, 2 * math.pi / period))
    # the top: a scoop at the neck, sleeves to `sleeve` along the arm, down to `hem`
    scoop = g.mul(g.mul(o.get("neck", 0.0), front), g.op("EXPONENT", g.mul(g.sq(g.div(ax, 0.045)), -1.0)))
    neck_z = g.lerp(g.sub(1.17, scoop), 1.4, g.sstep(0.065, 0.09, ax))
    hem = o["hem"] if o["hem"] > 0 else 0.6
    d_top = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, hem)), g.sub(o["sleeve"], ax))
    top = cov(d_top)
    waist = 0.79
    d_bottom = g.mn(g.sub(waist, z), g.sub(z, o["cuff_z"]))
    bottom = cov(d_bottom)
    col = g.mixc(skin, o["bottom"], bottom)
    ink = g.mul(edge(g.sub(z, o["cuff_z"])), bottom)
    # legs: a side stripe, grease on the knees
    if "stripe" in o:
        col = g.mixc(col, o["stripe"], g.mul(g.band(g.abs(y), 0.0, 0.006), g.mul(bottom, g.sstep(0.055, 0.075, ax))))
    if "grease" in o:
        knees = g.mul(g.op("EXPONENT", g.mul(g.add(g.sq(g.div(g.sub(ax, 0.07), 0.04)), g.sq(g.div(g.sub(z, 0.45), 0.05))), -1.0)), front)
        smudge = g.mul(knees, g.add(0.6, g.mul(0.4, sine(g.add(x, g.mul(z, 0.7)), 0.02))))
        col = g.mixc(col, o["grease"], g.mul(smudge, g.mul(bottom, 0.6)))
    col = g.mixc(col, o["top"], top)
    ink = g.mx(ink, g.mx(edge(d_top), g.mul(edge(d_bottom), g.sub(1.0, top))))
    # a jacket's reflective bands round the sleeves and chest
    if "bands" in o:
        b = g.mx(g.mul(g.band(ax, 0.3, 0.32), top), g.mul(g.band(z, 0.93, 0.95), g.mul(top, g.sstep(0.15, 0.14, ax))))
        col = g.mixc(col, o["bands"], b)
    if "collar" in o:
        col = g.mixc(col, o["collar"], g.mul(g.band(z, 1.13, 1.2), g.mul(top, g.sstep(0.1, 0.08, ax))))
    if "zip" in o:   # down the front, collar to the waist (or the crotch on coveralls)
        lo = 0.72 if o["hem"] == 0 else hem
        zp = g.mul(g.mul(g.band(x, -0.0025, 0.0025), front), g.mul(g.sstep(lo, lo + 0.01, z), g.sstep(1.18, 1.17, z)))
        col = g.mixc(col, o["zip"], zp)
        ink = g.mx(ink, g.mul(g.band(g.abs(x), 0.0025, 0.0035), g.mul(front, g.mul(g.sstep(lo, lo + 0.01, z), g.sstep(1.18, 1.17, z)))))
    # a cardigan: open down the front over the top, ribbed hems
    if "cardigan" in o:
        open_ = g.sub(g.mul(front, g.sub(0.03, g.sub(ax, g.mul(g.sub(1.2, z), 0.1)))), back)
        cardi = g.mul(top, g.sub(1.0, cov(open_)))
        col = g.mixc(col, o["cardigan"], cardi)
        knit = g.mul(g.mul(g.sstep(0.6, 0.9, sine(g.add(x, g.mul(z, 0.3)), 0.012)), 0.25), cardi)
        rib = g.mul(g.mx(g.band(g.sub(z, hem), 0.0, 0.025), g.band(ax, 0.44, 0.468)), cardi)
        col = g.mixc(col, g.mixc(o["cardigan"], (0, 0, 0, 1), 0.3), g.mx(knit, rib))
        ink = g.mx(ink, g.mul(edge(open_), top))
    # overalls: a bib and straps over the top, the legs below
    if "overalls" in o:
        bib = g.mul(cov(g.mn(g.sub(0.085, ax), g.sub(1.05, z))), g.mul(front, g.sstep(0.78, 0.79, z)))
        strap_x = g.add(0.06, g.mul(g.sub(z, 1.05), 0.2))
        straps = g.mul(g.band(g.sub(ax, strap_x), -0.012, 0.012), g.mul(g.sstep(1.04, 1.05, z), g.sstep(1.17, 1.16, z)))
        back_straps = g.mul(g.mul(g.band(g.sub(ax, g.mul(g.sub(1.15, z), 0.35)), -0.012, 0.012), back), g.mul(g.sstep(0.78, 0.8, z), g.sstep(1.17, 1.16, z)))
        ov = g.mx(g.mx(bib, straps), back_straps)
        col = g.mixc(col, o["overalls"], ov)
        pocket = g.mul(cov(g.mn(g.sub(0.045, ax), g.mn(g.sub(1.0, z), g.sub(z, 0.9)))), front)
        col = g.mixc(col, o.get("patch", o["overalls"]), g.mul(pocket, 0.9))
        ink = g.mx(ink, g.mx(g.mul(edge(g.mn(g.sub(0.085, ax), g.sub(1.05, z))), g.mul(front, g.sstep(0.78, 0.79, z))), g.mul(edge(g.mn(g.sub(0.045, ax), g.mn(g.sub(1.0, z), g.sub(z, 0.9)))), front)))
    # an apron: front only, chest to knee, a neck loop and waist ties
    if "apron" in o:
        a_lo = o.get("apron_lo", 0.45)
        half = g.lerp(0.075, 0.125, g.sstep(1.0, 0.86, z))
        d_ap = g.mn(g.mn(g.sub(half, ax), g.sub(1.06, z)), g.sub(z, a_lo))
        apron = g.mul(cov(d_ap), front)
        loop = g.mul(g.band(g.sub(ax, g.add(0.06, g.mul(g.sub(z, 1.06), 0.3))), -0.006, 0.006), g.mul(g.sstep(1.05, 1.06, z), g.sstep(1.17, 1.16, z)))
        ties = g.mul(g.band(z, 0.83, 0.85), back)
        col = g.mixc(col, o["apron"], g.mx(g.mx(apron, loop), ties))
        ink = g.mx(ink, g.mul(edge(d_ap), front))
        pocket = g.mul(cov(g.mn(g.sub(0.07, ax), g.mn(g.sub(0.92, z), g.sub(z, 0.84)))), front)
        ink = g.mx(ink, g.mul(edge(g.mn(g.sub(0.07, ax), g.mn(g.sub(0.92, z), g.sub(z, 0.84)))), front))
        col = g.mixc(col, g.mixc(o["apron"], (0, 0, 0, 1), 0.2), pocket)
    # a long coat, open at the front, down to the shins
    if "coat" in o:
        c_lo = o.get("coat_lo", 0.35)
        d_coat = g.mn(g.mn(g.sub(neck_z, z), g.sub(z, c_lo)), g.sub(0.468, ax))
        open_ = g.sub(g.mul(front, g.sub(0.035, g.sub(ax, g.mul(g.sub(1.17, z), 0.06)))), back)
        coat = g.mul(cov(d_coat), g.sub(1.0, cov(open_)))
        lapel = g.mul(g.band(g.sub(ax, g.add(0.035, g.mul(g.sub(1.17, z), 0.06))), 0.0, 0.03), g.mul(front, g.sstep(1.0, 1.02, z)))
        col = g.mixc(col, o["coat"], coat)
        col = g.mixc(col, g.mixc(o["coat"], (0, 0, 0, 1), 0.35), g.mul(lapel, coat))
        cuffs = g.mul(g.band(ax, 0.43, 0.468), coat)
        col = g.mixc(col, g.mixc(o["coat"], (0, 0, 0, 1), 0.3), cuffs)
        folds = g.mul(g.mul(g.sstep(0.55, 1.0, sine(g.add(x, g.mul(z, 0.12)), 0.05)), 0.25), g.mul(coat, g.sstep(0.82, 0.8, z)))
        col = g.mixc(col, g.mixc(o["coat"], (0, 0, 0, 1), 0.4), folds)
        ink = g.mx(ink, g.mx(g.mul(edge(d_coat), g.sub(1.0, cov(open_))), g.mul(edge(open_), cov(d_coat))))
    if "scarf" in o:
        sc = g.mul(g.band(z, 1.135, 1.185), g.sstep(0.11, 0.09, ax))
        tail = g.mul(cov(g.mn(g.sub(0.016, g.abs(g.sub(x, 0.04))), g.mn(g.sub(1.17, z), g.sub(z, 0.98)))), front)
        stripes = g.sstep(0.3, 0.6, sine(g.add(z, g.mul(x, 0.4)), 0.02))
        s_all = g.mx(sc, tail)
        col = g.mixc(col, o["scarf"], s_all)
        col = g.mixc(col, g.mixc(o["scarf"], (0, 0, 0, 1), 0.45), g.mul(g.mul(stripes, s_all), 0.6))
        ink = g.mx(ink, g.mul(edge(g.mn(g.sub(0.016, g.abs(g.sub(x, 0.04))), g.mn(g.sub(1.17, z), g.sub(z, 0.98)))), front))
    if "belt" in o:
        bl = g.mul(g.band(z, waist - 0.02, waist), g.sstep(0.2, 0.18, ax))
        col = g.mixc(col, o["belt"], bl)
        buckle = g.mul(g.mul(g.band(x, -0.012, 0.012), front), g.band(z, waist - 0.022, waist + 0.002))
        col = g.mixc(col, (0.5, 0.48, 0.42), g.mul(buckle, 0.9))
    return g.mixc(col, INK, ink)


def bake_body(body, skin_img):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 8
    m = bpy.data.materials.new("bake_body")
    m.use_nodes = True
    for i in mat_index(body, "Body_00_SKIN"):
        body.material_slots[i].material = m
    for o in bpy.data.objects:
        o.select_set(o == body)
    bpy.context.view_layer.objects.active = body
    nt = m.node_tree
    nt.nodes.clear()
    uv = nt.nodes.new("ShaderNodeUVMap")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = skin_img
    nt.links.new(uv.outputs[0], t.inputs[0])
    col = clothes_graph(nt, t.outputs["Color"])
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    nt.links.new(col, em.inputs[0])
    img = bpy.data.images.new("body", BAKE, BAKE, alpha=False)
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = os.path.join(TEX_OUT, "body.png")
    img.file_format = "PNG"
    img.save()
    print("baked body")


def dye(px, stops):
    out = px.copy()
    out[..., :3] = to_srgb(ramp(lum(to_lin(px[..., :3])), stops))
    return out


def textures(objs, boots):
    """Every surface's texture into assets/textures/npc/town_<who>/, and plain
    materials named npc_town_<who>_<surface> for the importer."""
    tex_of = E["tex_of"]
    face = bpy.data.objects["Face"]
    body = bpy.data.objects["Body"]
    hair = bpy.data.objects.get("Hair")
    plan = []
    dark = np.array(P_["hair"][1][1])
    for i, m in enumerate(face.data.materials):
        img = tex_of(m)
        if "Face_00_SKIN" in m.name:
            write_png(face_paint(face, img), "face")
            plan.append((face, i, "face"))
        elif "FaceBrow" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(np.array(P_["hair"][1 if P_["cut"] != "horseshoe" else 2][1]))
            px[..., 3] = ss(0.12, 0.45, px[..., 3])
            write_png(px, "brow")
            plan.append((face, i, "brow"))
        elif "FaceEyeline" in m.name or "FaceEyelash" in m.name:
            px = read_px(img).copy()
            px[..., :3] = to_srgb(to_lin(px[..., :3]) * np.array((0.4, 0.3, 0.28)))
            if P_["sex"] == "m":
                px[..., 3] *= 0.55
            name = "eyeline" if "Eyeline" in m.name else "lash"
            write_png(px, name)
            plan.append((face, i, name))
        elif "EyeIris" in m.name:
            px = read_px(img).copy()
            L = lum(to_lin(px[..., :3]))[..., None]
            px[..., :3] = to_srgb(np.clip(L * 1.6, 0, 1.4) * np.array(P_["iris"]))
            write_png(px, "iris")
            plan.append((face, i, "iris"))
        else:
            key = next(k for k in ("FaceMouth", "EyeHighlight", "EyeWhite") if k in m.name)
            name = {"FaceMouth": "mouth", "EyeHighlight": "eye_glint", "EyeWhite": "eye_white"}[key]
            write_png(read_px(img).copy(), name)
            plan.append((face, i, name))
    if hair:
        for i, m in enumerate(hair.data.materials):
            if "HAIR_01" in m.name:
                write_png(dye(read_px(tex_of(m)), P_["hair"]), "hair")
                plan.append((hair, i, "hair"))
            elif "HAIR_02" in m.name:
                write_png(dye(read_px(tex_of(m)), P_["hair"]), "hair_fringe")
                plan.append((hair, i, "hair_fringe"))
    for i, m in enumerate(body.data.materials):
        if m and "HairBack" in m.name:
            px = dye(read_px(tex_of(m)), P_["hair"])
            if P_["sex"] == "m":   # short and matte, not the preset's long-hair shine
                px[..., :3] = np.clip(px[..., :3] * 0.75 + to_srgb(dark) * 0.25, 0, 1)
            write_png(px, "hair_cap")
            plan.append((body, i, "hair_cap"))
    for i, m in enumerate(boots.data.materials):
        if m and "Shoes" in m.name:
            px = read_px(tex_of(m)).copy()
            t = lum(to_lin(px[..., :3]))[..., None]
            lo, hi = P_["boots"]
            px[..., :3] = to_srgb(np.array(lo) * (1 - t) + np.array(hi) * t)
            write_png(px, "boots")
            plan.append((boots, i, "boots"))
    skin_m = body.data.materials[next(iter(mat_index(body, "Body_00_SKIN")))]
    px = read_px(tex_of(skin_m)).copy()
    hole = E["dilate"](px[..., :3].mean(-1) < 150 / 255, 5)
    px[..., :3] = E["fill_holes"](px[..., :3], hole)
    px[..., :3] = px[..., :3] * np.array(P_["skin"])
    clean = write_png(px, "body_skin_src")
    bake_body(body, clean)
    os.remove(os.path.join(TEX_OUT, "body_skin_src.png"))
    plan.append((body, next(iter(mat_index(body, "bake_body"))), "body"))
    for ob, i, name in plan:
        ob.material_slots[i].material = N["new_mat"]("npc_%s_%s" % (NAME, name))
    for ob in objs:
        if ob.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = ob
        for o in bpy.data.objects:
            o.select_set(o == ob)
        bpy.ops.object.material_slot_remove_unused()


def prune_bones(arm):
    E["prune_bones"](arm)
    if P_["sex"] != "m":
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for e in [e for e in eb if "Bust" in e.name or e.name.startswith("J_Sec_Hair")]:
        eb.remove(e)
    bpy.ops.object.mode_set(mode="OBJECT")
    names = {b.name for b in arm.data.bones}
    for ob in arm.children:
        for g in list(ob.vertex_groups):
            if g.name.startswith("J_Sec_") and g.name not in names:
                ob.vertex_groups.remove(g)


# --- poses and loops -----------------------------------------------------------------------

def stance():
    """Their resting pose, in the rig's final space (facing +Y, their right +X)."""
    p = E["base_pose"]()
    add = E["add"]
    s = P_["stance"]
    if s == "easy":   # Pell, Harl, Jun: arms easy at their sides, weight on one hip, chin up
        add(p, "upperarm.R", Y, -5)
        add(p, "upperarm.L", Y, 5)
        add(p, "forearm.R", X, 10)
        add(p, "forearm.L", X, 10)
        add(p, "hips", Y, -4)
        add(p, "thigh.R", X, 5)
        add(p, "shin.R", X, -8)
        add(p, "chest", X, -2)
        add(p, "head", X, -3)
    elif s == "weight":   # Kit: weight on one leg, one hand at the strap of a bag
        add(p, "hips", Y, 5)
        add(p, "thigh.L", Y, -4)
        add(p, "thigh.R", X, 6)
        add(p, "shin.R", X, -10)
        add(p, "upperarm.R", X, 12)
        add(p, "forearm.R", X, 95)
        add(p, "forearm.R", Z, 30)
        add(p, "head", Y, -6)
    elif s == "pockets":   # Wren: hands in her overall pockets, easy
        add(p, "upperarm.R", X, 14)
        add(p, "upperarm.L", X, 14)
        add(p, "upperarm.R", Y, -8)
        add(p, "upperarm.L", Y, 8)
        add(p, "forearm.R", X, 34)
        add(p, "forearm.L", X, 34)
        add(p, "head", Y, 4)
        add(p, "hips", Y, -3)
    elif s == "belly":   # Tobin: at ease, hands folded on his belly (Biggie's), a little stooped
        add(p, "upperarm.R", Y, -14)
        add(p, "upperarm.L", Y, 14)
        add(p, "upperarm.R", X, 10)
        add(p, "upperarm.L", X, 10)
        add(p, "forearm.R", X, 70)
        add(p, "forearm.L", X, 70)
        add(p, "forearm.R", Z, 40)
        add(p, "forearm.L", Z, -40)
        add(p, "spine", X, 6)
        add(p, "neck", X, -4)
    elif s == "clasp":   # Dez, Bram: hands clasped low in front, weight back
        add(p, "upperarm.R", X, 8)
        add(p, "upperarm.L", X, 8)
        add(p, "upperarm.R", Y, -4)
        add(p, "upperarm.L", Y, 4)
        add(p, "forearm.R", X, 50)
        add(p, "forearm.L", X, 50)
        add(p, "forearm.R", Z, 34)
        add(p, "forearm.L", Z, -34)
        add(p, "spine", X, -3)
    elif s == "hands_front":   # Rosa: hands folded in front of her, head on one side
        add(p, "upperarm.R", X, 14)
        add(p, "upperarm.L", X, 14)
        add(p, "forearm.R", X, 72)
        add(p, "forearm.L", X, 72)
        add(p, "forearm.R", Z, 38)
        add(p, "forearm.L", Z, -38)
        add(p, "head", Y, 6)
        add(p, "spine", X, 4)
    return p


def sit_pose():
    """Sat on a bench (seat about 0.45 m up), hands on their thighs."""
    p = E["base_pose"]()
    add = E["add"]
    for side, sg in (("R", 1), ("L", -1)):
        add(p, "thigh." + side, X, 86)
        add(p, "thigh." + side, Y, -5 * sg)
        add(p, "shin." + side, X, -82)
        # elbows a little forward, forearms down along the thighs, hands in on the knees
        add(p, "upperarm." + side, X, 22)
        add(p, "upperarm." + side, Y, -6 * sg)
        add(p, "forearm." + side, X, 42)
        add(p, "forearm." + side, Z, 12 * sg)
    add(p, "spine", X, 8)
    add(p, "head", X, 3)
    return p


def make_actions(arm):
    """idle and talk in their stance (as the hub NPCs'), a walk (Eco's stride,
    slower and smaller for the old), and sitting on a bench."""
    arm.animation_data_create()
    bpy.context.scene.render.fps = 30
    BONE, ORDER, FINGERS = E["BONE"], E["ORDER"], E["FINGERS"]
    keyed = [BONE[n] for n in ORDER] + ["J_Bip_%s_%s%d" % (s, f, j) for s in "RL" for f in FINGERS + ("Thumb",) for j in (1, 2, 3)]
    add, hips_loc = E["add"], E["hips_loc"]

    def key_pose(arm, f, p, keyed):
        # Eco's key_pose() never resets bone scale, so the tiny scale each
        # pose.matrix write leaves behind piled up over a few hundred poses
        # until the fingertips stretched off to the horizon. Clear it before
        # each pose and key it at 1.
        for pb in arm.pose.bones:
            pb.scale = (1.0, 1.0, 1.0)
        E["key_pose"](arm, f, p, keyed)
        for name in keyed:
            pb = arm.pose.bones[name]
            pb.scale = (1.0, 1.0, 1.0)
            pb.keyframe_insert("scale", frame=f)
    # the bench sit drops the hips this far (m): standing hip height less the seat's
    hip_h = arm.data.bones["J_Bip_C_Hips"].head_local.z
    for name, n, base in (("idle", 120, stance), ("talk", 90, stance), ("sit", 120, sit_pose), ("sit_talk", 90, sit_pose)):
        a = bpy.data.actions.new(name)
        arm.animation_data.action = a
        for f in range(0, n + 1, 6):
            t = f / n * 2 * math.pi
            p = base()
            talk = name.endswith("talk")
            breath = math.sin(t * 2) if not talk else math.sin(t * 3)
            add(p, "chest", X, -1.2 * breath)
            add(p, "head", Z, (5 if not talk else 3) * math.sin(t))
            if talk:
                g = 0.5 - 0.5 * math.cos(t)
                add(p, "upperarm.L", X, 14 * g)
                add(p, "forearm.L", X, 30 * g)
                add(p, "head", X, -3 * math.sin(t * 2))
            drop = -(hip_h - 0.5) if base is sit_pose else 0.0
            p["_hips_loc"] = hips_loc(drop + 0.002 * breath, 0.04 if base is sit_pose else 0)
            key_pose(arm, f, p, keyed)
    # walk: one stride (two steps) in 32 frames at full gait, about 1.3 m
    gait = P_.get("gait", 1.0)
    a = bpy.data.actions.new("walk")
    arm.animation_data.action = a
    n = 32
    for f in range(0, n + 1, 2):
        t = f / n * 2 * math.pi
        p = E["base_pose"]()
        add(p, "upperarm.R", Y, -4)
        add(p, "upperarm.L", Y, 4)
        sw = math.sin(t)
        add(p, "thigh.R", X, 26 * gait * sw)
        add(p, "thigh.L", X, -26 * gait * sw)
        add(p, "shin.R", X, -38 * gait * max(0.0, math.sin(t - 1.2)) - 6)
        add(p, "shin.L", X, -38 * gait * max(0.0, math.sin(t + math.pi - 1.2)) - 6)
        add(p, "foot.R", X, 10 * gait * math.cos(t))
        add(p, "foot.L", X, -10 * gait * math.cos(t))
        add(p, "upperarm.R", X, -20 * gait * sw)
        add(p, "upperarm.L", X, 20 * gait * sw)
        add(p, "forearm.R", X, 8 + 8 * max(0.0, -sw))
        add(p, "forearm.L", X, 8 + 8 * max(0.0, sw))
        add(p, "hips", Z, 6 * gait * sw)
        add(p, "chest", Z, -8 * gait * sw)
        add(p, "head", Z, 2 * sw)
        add(p, "spine", X, 3)
        p["_hips_loc"] = hips_loc(-0.018 * gait * abs(math.cos(t)), 0)
        key_pose(arm, f, p, keyed)
    for act in bpy.data.actions:
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
    arm.animation_data.action = bpy.data.actions["idle"]


def main():
    os.makedirs(TEX_OUT, exist_ok=True)
    E["HEIGHT"], E["HEAD_SCALE"], E["LEG_SCALE"] = P_["height"], P_["head"], P_["legs"]
    arm = E["setup_scene"]()
    E["remove_fox_parts"]()
    boots = N["strip_clothes"]()
    cut_hair()
    shape_face()
    if P_["sex"] == "m":
        body_male(arm)
    else:
        body_female()
    objs = [bpy.data.objects[n] for n in ("Body", "Face", "Hair") if n in bpy.data.objects] + [boots]
    textures(objs, boots)
    prune_bones(arm)
    E["proportions"](arm, objs)
    E["face_forward_and_scale"](arm, objs)
    make_actions(arm)
    if "rest" in bpy.data.objects["Body"].data.attributes:
        bpy.data.objects["Body"].data.attributes.remove(bpy.data.objects["Body"].data.attributes["rest"])
    for o in bpy.data.objects:
        o.select_set(o == arm or o in objs)
    os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_morph=True, export_materials="EXPORT", export_image_format="NONE",
                              export_yup=True, export_apply=False)
    print("exported", GLB_OUT)


main()
