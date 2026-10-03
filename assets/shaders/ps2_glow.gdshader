// The surface shader's unshaded materials (lights, screens, LEDs, lava, eye
// glints): the same uniforms and textures as ps2_surface.gdshader, drawn with
// render_mode unshaded so their colour is what reaches the screen. (On Godot
// 4.7 the lit shader's unshaded path, ALBEDO 0 with everything in EMISSION,
// rendered black.)
shader_type spatial;
render_mode unshaded;
#define PS2_UNSHADED

#include "res://assets/shaders/ps2_surface.gdshaderinc"
