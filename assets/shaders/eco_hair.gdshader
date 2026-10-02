// Eco's hair: white, painted strands that catch the light in slow technicolor
// waves. Bands of rainbow colour drift up through the hair over time and shift
// with viewing angle (strongest at grazing angles, like oil on water), and
// the strand tips sway a little so the short cut seems to flow.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D strand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.86, 1.0);
uniform float tex_scale = 14.0;
// How strong the colour waves are (0 = plain white hair).
uniform float iridescence : hint_range(0.0, 1.0) = 0.85;
// Wave bands per metre, and how fast they travel.
uniform float wave_scale = 22.0;
uniform float wave_speed = 1.4;
// How far strand tips sway, in metres. The mesh's vertex colour (red) says how
// far each vertex is out along its lock, so roots stay put.
uniform float sway = 0.006;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.4;
// Baked occlusion between the locks (vertex colour green).
uniform float vertex_ao : hint_range(0.0, 1.0) = 0.8;
uniform float light_softness : hint_range(0.01, 1.0) = 0.4;

instance uniform float flash = 0.0;
instance uniform vec4 paint : source_color = vec4(1.0);

varying vec3 v_world;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tip = COLOR.r;
	VERTEX.x += sin(TIME * 2.1 + world.y * 30.0 + world.x * 11.0) * sway * tip;
	VERTEX.z += cos(TIME * 1.7 + world.y * 24.0 + world.z * 13.0) * sway * tip;
	v_world = world;
}

void fragment() {
	vec3 tex = texture(strand_tex, vec2(UV.x, UV.y * 0.35) * tex_scale).rgb;
	vec3 base = tex * albedo.rgb * paint.rgb;

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 1.6);
	// Phase of the travelling wave: height, a diagonal drift, time and view angle.
	float phase = v_world.y * wave_scale + dot(v_world.xz, vec2(9.0, 6.0))
			- TIME * wave_speed * 3.0 + fresnel * 4.0;
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (phase * 0.12 + vec3(0.0, 0.33, 0.67)));
	rainbow = smoothstep(0.1, 0.9, rainbow);  // punchier, more saturated hues
	// Bright crests that sweep through the hair.
	float crest = smoothstep(0.3, 1.0, sin(phase) * 0.5 + 0.5);
	float amount = clamp(iridescence * (0.3 + 0.6 * fresnel + 0.6 * crest), 0.0, 1.0);

	float ao = mix(1.0, COLOR.g, vertex_ao);
	ALBEDO = mix(base, base * rainbow * 1.25, amount * 0.75) * ao;
	EMISSION = rainbow * amount * 0.22 * ao + vec3(flash);
	RIM = 0.6;
	RIM_TINT = 0.8;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = (ndl + light_wrap) / (1.0 + light_wrap);
	float lit = smoothstep(0.0, light_softness, wrapped);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
	// A soft sheen band across the strands.
	vec3 h = normalize(LIGHT + VIEW);
	float sheen = pow(max(dot(NORMAL, h), 0.0), 24.0);
	SPECULAR_LIGHT += sheen * 0.3 * ATTENUATION * LIGHT_COLOR;
}
