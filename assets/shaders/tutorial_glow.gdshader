shader_type spatial;
// Tutorial highlight, first pass (scripts/run/tutorial.gd puts it on a thing's
// material_overlay): a pulsing rim of light over the surface, added on top of
// whatever the thing already looks like. Its next_pass draws the outline.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.25, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	ALBEDO = color.rgb * (0.03 + 0.07 * pulse + rim * (0.35 + 0.35 * pulse));
}
