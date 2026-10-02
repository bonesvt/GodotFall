"""Eco's skeleton: joint positions in metres, Blender axes (Z up, facing +Y, her
right is +X). Shared by sculpt.py (shapes are built around the joints) and
build_eco.py (the armature)."""
import numpy as np


def _n(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


J = {
    "hips": np.array([0.0, 0.0, 0.9]),
    "spine": np.array([0.0, 0.0, 1.03]),
    "chest": np.array([0.0, -0.005, 1.2]),
    "neck": np.array([0.0, -0.01, 1.39]),
    "head": np.array([0.0, -0.002, 1.47]),
    "head_top": np.array([0.0, -0.01, 1.67]),
}
for s, side in ((1.0, "R"), (-1.0, "L")):
    J["hip." + side] = np.array([s * 0.085, 0.0, 0.86])
    J["knee." + side] = np.array([s * 0.088, 0.008, 0.47])
    J["ankle." + side] = np.array([s * 0.092, -0.015, 0.085])
    J["toe." + side] = np.array([s * 0.1, 0.13, 0.025])
    J["clavicle." + side] = np.array([s * 0.03, -0.01, 1.365])
    J["shoulder." + side] = np.array([s * 0.172, -0.012, 1.352])
    J["elbow." + side] = J["shoulder." + side] + 0.265 * _n([s * 0.34, 0.0, -0.94])
    J["wrist." + side] = J["elbow." + side] + 0.232 * _n([s * 0.2, 0.16, -0.97])
    J["hand_dir." + side] = _n([s * 0.16, 0.1, -0.98])
    J["hand_end." + side] = J["wrist." + side] + 0.1 * J["hand_dir." + side]

# name, head joint, tail joint, parent
BONES = [
    ("hips", "hips", "spine", None),
    ("spine", "spine", "chest", "hips"),
    ("chest", "chest", "neck", "spine"),
    ("neck", "neck", "head", "chest"),
    ("head", "head", "head_top", "neck"),
]
for side in ("R", "L"):
    BONES += [
        ("thigh." + side, "hip." + side, "knee." + side, "hips"),
        ("shin." + side, "knee." + side, "ankle." + side, "thigh." + side),
        ("foot." + side, "ankle." + side, "toe." + side, "shin." + side),
        ("clavicle." + side, "clavicle." + side, "shoulder." + side, "chest"),
        ("upperarm." + side, "shoulder." + side, "elbow." + side, "clavicle." + side),
        ("forearm." + side, "elbow." + side, "wrist." + side, "upperarm." + side),
        ("hand." + side, "wrist." + side, "hand_end." + side, "forearm." + side),
    ]
