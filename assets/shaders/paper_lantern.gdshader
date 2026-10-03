// Lit paper for Solace's lanterns (town_props.gd, "glow_paper" parts): brightest
// where you look straight through the paper at the flame, dimmer towards the
// rim and the ends, with faint vertical ribs, so it reads as a glowing shade
// rather than a flat ball. Unshaded, so the colour is what reaches the screen.
shader_type spatial;
render_mode unshaded, cull_back;

instance uniform vec3 paint = vec3(1.0, 0.78, 0.5);

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float core = 0.35 + 1.25 * pow(facing, 2.0);
	float rib = 0.9 + 0.1 * smoothstep(0.0, 0.25, abs(fract(UV.x * 12.0) - 0.5));
	ALBEDO = paint * core * rib;
}
