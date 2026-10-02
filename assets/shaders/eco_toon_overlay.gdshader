// Eco's toon shading for the layers painted over her face: irises, eye
// highlights, brows, lashes and liner. Alpha blended and drawn in order of
// the materials' render_priority. See eco_toon.gdshaderinc.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

#define OVERLAY
#include "res://assets/shaders/eco_toon.gdshaderinc"
