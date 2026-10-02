// Eco's toon shading, one-sided (body, mouth, eye whites, goggles).
// The shading itself is in eco_toon.gdshaderinc.
shader_type spatial;
render_mode cull_back, depth_prepass_alpha;

#include "res://assets/shaders/eco_toon.gdshaderinc"
