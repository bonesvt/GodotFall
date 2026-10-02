// Painted sky: a soft gradient, banded clouds lit warm on the sun side, two
// hazy mountain ranges from a tiny panorama (R clouds, G far range, B near
// ridge), and a sun with a big soft halo.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.3, 0.45, 0.7, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.75, 0.8, 0.85, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform sampler2D layers : filter_linear, repeat_enable;
// How high above the horizon the panorama reaches, in degrees.
uniform float band_degrees = 35.0;
uniform float sun_size = 0.9995;
uniform float halo = 0.6;

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, -d.z) / TAU + 0.5;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.3, 0.6, 0.4));
	float sd = max(dot(d, sun_dir), 0.0);
	float sun_side = pow(sd, 3.0);

	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(smoothstep(0.0, 0.9, d.y), 0.7));
	if (d.y < 0.0) {
		// the void below fades into thick mist
		col = mix(horizon_color.rgb, horizon_color.rgb * 0.75, smoothstep(0.0, 0.6, -d.y));
	}
	float v = elev / radians(band_degrees);
	if (v >= 0.0 && v <= 1.0) {
		vec3 l = texture(layers, vec2(az * 2.0, 1.0 - v)).rgb;
		vec3 cloud = mix(mix(horizon_color.rgb, vec3(1.0), 0.55), sun_color.rgb * 1.2, sun_side * 0.7);
		col = mix(col, cloud, l.r * 0.85);
		vec3 far_col = mix(horizon_color.rgb, top_color.rgb, 0.35) * 0.92;
		col = mix(col, far_col, l.g * 0.8);
		col = mix(col, mix(horizon_color.rgb, top_color.rgb, 0.6) * 0.72, l.b * 0.9);
	}
	col += sun_color.rgb * (pow(sd, 8.0) * halo + pow(sd, 64.0) * 0.6);
	col = mix(col, sun_color.rgb * 4.0, smoothstep(sun_size - 0.0003, sun_size, sd));
	COLOR = col;
}
