"""Writes assets/materials/threats/*.tres: the game's toon materials
(eco_toon.gdshader) for the material names choir.py and wild.py give their
models, in the same flat colours as the concept sheets. Run with plain Python:

    python3 tools/threats/materials.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets/materials/threats"
SHADE = (0.66, 0.62, 0.8)
METAL_SHADE = (0.8, 0.62, 0.42)

# name: colour, and optional sheen / shade / emission (colour, energy) / rim
MATERIALS = {
    # the Choir
    "porcelain": ((0.74, 0.7, 0.62), {"sheen": 0.45}),
    "porcelain_dirty": ((0.8, 0.75, 0.68), {"sheen": 0.3}),
    "sinew": ((0.1, 0.1, 0.12), {}),
    "black": ((0.07, 0.07, 0.085), {"sheen": 0.4}),
    "gold": ((0.85, 0.6, 0.28), {"sheen": 0.7, "shade": METAL_SHADE}),
    "glow": ((0.6, 0.95, 1.0), {"emit": ((0.55, 0.95, 1.0), 2.4), "rim": 0.0}),
    "glow_soft": ((0.6, 0.95, 1.0), {"emit": ((0.45, 0.85, 1.0), 1.4), "rim": 0.0}),
    "cloth": ((0.45, 0.06, 0.08), {}),
    "blood": ((0.18, 0.01, 0.01), {"sheen": 0.4}),
    "sinew_dead": ((0.03, 0.03, 0.035), {}),
    # wildlife
    "glass_hide": ((0.34, 0.38, 0.36), {}),
    "glass_belly": ((0.6, 0.57, 0.48), {}),
    "crystal": ((0.05, 0.45, 0.45), {"sheen": 0.8, "emit": ((0.1, 0.75, 0.7), 0.6)}),
    "crystal_hot": ((0.5, 1.0, 0.9), {"emit": ((0.4, 1.0, 0.9), 2.0), "rim": 0.0}),
    "eye_dark": ((0.02, 0.02, 0.02), {"sheen": 0.8}),
    "horn": ((0.62, 0.56, 0.45), {}),
    "lamp_skin": ((0.27, 0.33, 0.16), {"sheen": 0.35}),
    "lamp_belly": ((0.62, 0.58, 0.4), {}),
    "mouth": ((0.32, 0.05, 0.07), {"sheen": 0.5}),
    "tooth": ((0.66, 0.6, 0.45), {}),
    "lure": ((1.0, 0.85, 0.4), {"emit": ((1.0, 0.8, 0.35), 2.6), "rim": 0.0}),
    "spots": ((0.5, 1.0, 0.6), {"emit": ((0.4, 1.0, 0.5), 1.8), "rim": 0.0}),
    "quill_fur": ((0.17, 0.17, 0.28), {}),
    "cat_dark": ((0.09, 0.09, 0.14), {}),
    "quill": ((0.85, 0.8, 0.7), {}),
    "cat_eye": ((1.0, 0.9, 0.3), {"emit": ((1.0, 0.85, 0.25), 2.0), "rim": 0.0}),
    "bone": ((0.55, 0.5, 0.4), {"sheen": 0.3}),
    "picker_flesh": ((0.35, 0.12, 0.12), {"sheen": 0.4}),
    "red_eye": ((1.0, 0.1, 0.05), {"emit": ((1.0, 0.1, 0.05), 2.0), "rim": 0.0}),
    "ray_skin": ((0.32, 0.31, 0.5), {"sheen": 0.35}),
    "ray_glow": ((0.7, 0.6, 1.0), {"emit": ((0.7, 0.55, 1.0), 1.8), "rim": 0.0}),
}


def vec(c):
    return ", ".join(f"{x:g}" for x in c)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (color, o) in MATERIALS.items():
        lines = [
            '[gd_resource type="ShaderMaterial" load_steps=2 format=3]',
            "",
            '[ext_resource type="Shader" path="res://assets/shaders/eco_toon.gdshader" id="1_shader"]',
            "",
            "[resource]",
            f'resource_name = "{name}"',
            "shader = ExtResource(\"1_shader\")",
            f"shader_parameter/albedo = Color({vec(color)}, 1)",
            "shader_parameter/exposure = 0.62",
            f"shader_parameter/shade_tint = Vector3({vec(o.get('shade', SHADE))})",
            f"shader_parameter/sheen = {o.get('sheen', 0.0):g}",
            f"shader_parameter/rim = {o.get('rim', 0.22):g}",
        ]
        if "emit" in o:
            c, e = o["emit"]
            lines.append(f"shader_parameter/emission = Color({vec(c)}, 1)")
            lines.append(f"shader_parameter/emission_energy = {e:g}")
        (OUT / f"{name}.tres").write_text("\n".join(lines) + "\n")
    ink = [
        '[gd_resource type="ShaderMaterial" load_steps=2 format=3]',
        "",
        '[ext_resource type="Shader" path="res://assets/shaders/eco_outline.gdshader" id="1_shader"]',
        "",
        "[resource]",
        'resource_name = "threat_ink"',
        "shader = ExtResource(\"1_shader\")",
        "shader_parameter/ink = Color(0.16, 0.12, 0.16, 1)",
        "shader_parameter/width = 2.4",
        "shader_parameter/max_width = 0.012",
        "shader_parameter/tint = 0.0",
    ]
    (OUT / "threat_ink.tres").write_text("\n".join(ink) + "\n")
    print("wrote", len(MATERIALS) + 1, "materials to", OUT)


main()
