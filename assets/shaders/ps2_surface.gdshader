// The game's surface shader. Two looks, switched project-wide by the
// ps3_look shader global (F9, see scripts/ps2/ps2_screen.gd):
//   PS3 (1, default): high-res painted textures with normal maps, roughness
//     and metal masks (tools/make_textures.py), triplanar box projection,
//     soft-wrapped lambert plus GGX highlights, sky reflections.
//   PS2 (0): the old Jak and Daxter / Shadow of the Colossus look: blurry
//     low mips, flat surfaces, banded two-tone lighting, painted highlight.
// Textures are box projected (world space for level geometry, object space
// for models), so primitive-built models need no UVs. Both looks keep the
// painted rim light and the fake ambient occlusion toward a model's feet.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://assets/shaders/ps2_surface.gdshaderinc"
