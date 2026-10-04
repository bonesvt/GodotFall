// The Anime look's full-screen finish (PS2 autoload, scripts/ps2/ps2_screen.gd,
// hangs it on whatever camera is current). Drawn on a 2x2 quad. In order:
//   1. paint: a Kuwahara filter over the set (not the characters) turns the
//      flattened textures into brushy painted shapes, like an anime background;
//   2. ink: outlines from depth and normal breaks, thinner with distance;
//   3. grade: late-90s cel anime finish: warm highlights / cool shadows,
//      halation round bright lights, vignette and film grain (Settings > Video).
// The set writes ROUGHNESS 0.5 (ps2_surface.gdshaderinc), characters 1.0.
// Tuned from the "blend" concept (tools/art/style_shots.gd, concept_post).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest;

// Kuwahara radius in pixels (0 = off).
uniform int paint_radius = 4;
uniform vec4 ink : source_color = vec4(0.14, 0.1, 0.13, 1.0);
uniform float ink_width = 1.7;
// Depth break (relative) and normal break that make a line.
uniform float depth_edge = 0.065;
uniform float normal_edge = 0.35;
// Lines fade out past this distance (metres).
uniform float ink_far = 38.0;
uniform float saturation = 0.92;
uniform float contrast = 1.08;
uniform vec3 shadow_tone : source_color = vec3(0.42, 0.46, 0.62);
uniform vec3 highlight_tone : source_color = vec3(0.62, 0.52, 0.40);
uniform float split = 0.32;
uniform float black_lift = 0.09;
uniform float halation = 0.35;
uniform vec3 halation_color : source_color = vec3(1.0, 0.45, 0.25);
uniform float vignette = 0.25;
uniform float grain = 0.025;
uniform float grain_size = 1.4;
// Paper/gouache texture showing through the set.
uniform float paper = 0.06;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

// Sin-free hash: the sin() kind turns into a regular crosshatch once its
// input gets large (fp32 precision).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 kuwahara(vec2 uv, vec2 px, int r) {
	vec3 m[4];
	vec3 s[4];
	for (int k = 0; k < 4; k++) {
		m[k] = vec3(0.0);
		s[k] = vec3(0.0);
	}
	for (int j = -r; j <= r; j++) {
		for (int i = -r; i <= r; i++) {
			vec3 c = textureLod(screen_tex, uv + vec2(float(i), float(j)) * px, 0.0).rgb;
			vec3 c2 = c * c;
			if (i <= 0 && j <= 0) { m[0] += c; s[0] += c2; }
			if (i >= 0 && j <= 0) { m[1] += c; s[1] += c2; }
			if (i <= 0 && j >= 0) { m[2] += c; s[2] += c2; }
			if (i >= 0 && j >= 0) { m[3] += c; s[3] += c2; }
		}
	}
	float n = float((r + 1) * (r + 1));
	float best = 1e9;
	vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 mean = m[k] / n;
		vec3 var = abs(s[k] / n - mean * mean);
		float v = var.r + var.g + var.b;
		if (v < best) {
			best = v;
			col = mean;
		}
	}
	return col;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec4 nr = texture(nr_tex, uv);
	float depth = lin_depth(uv, INV_PROJECTION_MATRIX);
	bool is_set = nr.a < 0.75 || depth > 500.0;

	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (paint_radius > 0 && is_set) {
		col = kuwahara(uv, px, paint_radius);
	}
	if (paper > 0.0 && is_set) {
		float fib = vnoise(uv * VIEWPORT_SIZE / 3.0) * 0.6 + vnoise(uv * VIEWPORT_SIZE / 11.0) * 0.4;
		col *= 1.0 + (fib - 0.5) * paper;
	}

	// Ink.
	float w = ink_width * VIEWPORT_SIZE.y / 900.0;
	w *= mix(1.0, 0.55, clamp(depth / ink_far, 0.0, 1.0));
	vec2 o[4] = vec2[](vec2(w, 0.0), vec2(-w, 0.0), vec2(0.0, w), vec2(0.0, -w));
	vec3 n0 = normalize(nr.xyz * 2.0 - 1.0);
	float edge = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 q = uv + o[k] * px;
		float dq = lin_depth(q, INV_PROJECTION_MATRIX);
		// Only the nearer side of a depth break draws, so lines hug the object.
		float rel = (dq - depth) / max(depth, 0.05);
		if (rel > depth_edge * (1.0 + depth * 0.02)) {
			edge = 1.0;
		}
		vec3 nq = normalize(texture(nr_tex, q).xyz * 2.0 - 1.0);
		if (depth < 500.0 && dot(n0, nq) < 1.0 - normal_edge) {
			edge = max(edge, 0.85);
		}
	}
	edge *= 1.0 - smoothstep(ink_far * 0.6, ink_far, depth);
	col = mix(col, ink.rgb, edge * ink.a);

	// Grade.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	lum = clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	vec3 tone = mix(shadow_tone, highlight_tone, smoothstep(0.15, 0.75, lum));
	col = mix(col, col * tone * 2.0, split);
	col = col * (1.0 - black_lift) + black_lift * shadow_tone;
	if (halation > 0.0) {
		vec3 glow = textureLod(screen_tex, uv, 4.0).rgb;
		float g = max(dot(glow, vec3(0.333)) - 0.6, 0.0);
		col += halation_color * g * halation;
	}
	vec2 c = uv - 0.5;
	col *= 1.0 - vignette * dot(c, c) * 2.2;
	if (grain > 0.0) {
		// New grain 24 times a second, like film.
		float gn = vnoise(FRAGCOORD.xy / grain_size + 17.0 + mod(floor(TIME * 24.0), 61.0) * vec2(37.1, 91.7)) - 0.5;
		col += gn * grain;
	}
	ALBEDO = clamp(col, 0.0, 1.0);
}
