// Holo sight pane: a faint tinted glass with a projected reticle (ring,
// centre dot and four ticks) drawn in light. Additive, so it glows over
// whatever is behind it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 reticle : source_color = vec4(0.35, 1.0, 0.95, 1.0);
uniform vec4 glass : source_color = vec4(0.25, 0.55, 0.7, 1.0);
uniform float glass_alpha = 0.08;
uniform float brightness = 1.6;
// Set from script: 0..1 flicker on the projection.
instance uniform float glitch = 0.0;
// Set from script: 1 on a shot or a flourish, falling to 0. A second ring
// snaps out from the first and the reticle flares white.
instance uniform float pulse = 0.0;

float band(float d, float r, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d - r));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 0.92;  // the pane is a touch narrower than tall
	float d = length(p);
	float ring = band(d, 0.3, 0.025);
	float dot_ = 1.0 - smoothstep(0.03, 0.05, d);
	float ticks = 0.0;
	ticks += step(abs(p.x), 0.012) * step(0.34, abs(p.y)) * step(abs(p.y), 0.44);
	ticks += step(abs(p.y), 0.012) * step(0.34, abs(p.x)) * step(abs(p.x), 0.44);
	float scan = 0.85 + 0.15 * sin(UV.y * 120.0 + TIME * 6.0);
	float flick = 1.0 - glitch * step(0.5, fract(sin(floor(TIME * 40.0)) * 43758.5));
	float edge = smoothstep(0.5, 0.42, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	float echo = band(d, 0.3 + (1.0 - pulse) * 0.14, 0.02) * pulse;
	vec3 tint = mix(reticle.rgb, vec3(1.0), pulse * 0.6);
	vec3 col = tint * (ring + dot_ * 1.4 + ticks + echo) * scan * flick * brightness * (1.0 + pulse * 1.5);
	col += glass.rgb * glass_alpha * edge;
	ALBEDO = col * edge;
}
