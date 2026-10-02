// Painted PS2-style sky: a two-colour gradient with banded clouds and two
// mountain silhouettes from a tiny panorama (R clouds, G far range, B near ridge).
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.3, 0.45, 0.7, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.75, 0.8, 0.85, 1.0);
uniform sampler2D layers : filter_nearest, repeat_enable;
// How high above the horizon the panorama reaches, in degrees.
uniform float band_degrees = 35.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, -d.z) / TAU + 0.5;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.8, d.y));
	if (d.y < 0.0) {
		col = mix(horizon_color.rgb, horizon_color.rgb * 0.55, smoothstep(0.0, 0.5, -d.y));
	}
	float v = elev / radians(band_degrees);
	if (v >= 0.0 && v <= 1.0) {
		vec3 l = texture(layers, vec2(az * 2.0, 1.0 - v)).rgb;
		col = mix(col, mix(horizon_color.rgb, vec3(1.0), 0.45), l.r * 0.75);
		vec3 far_col = mix(horizon_color.rgb, top_color.rgb, 0.45) * 0.8;
		col = mix(col, far_col, l.g);
		col = mix(col, horizon_color.rgb * 0.45, l.b);
	} else if (v < 0.0 && v > -0.02) {
		col = horizon_color.rgb * 0.45;
	}
	// 5 bits per channel, like a 16-bit framebuffer.
	COLOR = floor(col * 31.0 + 0.5) / 31.0;
}
