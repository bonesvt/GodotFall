shader_type spatial;
// Tutorial highlight, second pass: an inverted hull pushed out a few pixels on
// screen (the same width near and far), so the thing gets a solid bright edge.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.25, 1.0);
uniform float width_px = 4.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	float pulse = 1.0 + 0.35 * sin(TIME * 5.0);
	clip.xy += dir * width_px * pulse * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
