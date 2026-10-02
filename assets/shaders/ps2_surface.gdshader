// Stylized PS2 surface (Jak and Daxter / Shadow of the Colossus flavour):
// hand-painted textures mapped by box projection (world space for level
// geometry, object space for models, so primitive-built models need no UVs),
// soft wrapped two-tone lighting, a painted rim light, and a fake ambient
// occlusion gradient that darkens models toward their feet.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Snap grid width in pixels for vertex positions (PS1/PS2 wobble). 0 is off.
// Set project-wide in Project Settings > Shader Globals.
global uniform float ps2_vertex_snap;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
// Optional second texture for upward-facing faces (platform tops).
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_top_tex = false;
uniform vec4 albedo : source_color = vec4(1.0);
// Texture repeats per metre.
uniform float tex_scale = 0.5;
// Shifts the projected texture, in metres.
uniform vec3 tex_offset = vec3(0.0);
// true: textures stay put in the world (levels). false: they move with the model.
uniform bool world_space = true;
// Use the mesh's own UVs (times tex_scale) instead of box projection. Skinned
// models (Eco) bake their UVs so textures stick to them as they animate.
uniform bool use_uv = false;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Ignore lighting entirely (lights, screens, lava).
uniform bool unshaded = false;
// How far the light wraps round to the dark side, and how soft the terminator is.
uniform float light_wrap : hint_range(0.0, 1.0) = 0.35;
uniform float light_softness : hint_range(0.01, 1.0) = 0.45;
// Painted rim light from the sun side.
uniform float rim : hint_range(0.0, 1.0) = 0.25;
// Fake occlusion: darken toward the model's feet over this height (metres, 0 = off).
uniform float ao_height = 0.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.45;
// Baked occlusion in the mesh's vertex colour (red), for sculpted models (Eco).
uniform float vertex_ao : hint_range(0.0, 1.0) = 0.0;
// Painted highlight: how bright, and how tight (0 broad, 1 pin-sharp).
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_sharpness : hint_range(0.0, 1.0) = 0.5;

// Per-object knobs, set with set_instance_shader_parameter (see ps2_model.gd).
instance uniform float flash = 0.0;          // white hit flash, 0..1
instance uniform float glow = 1.0;           // multiplies emission
instance uniform vec4 paint : source_color = vec4(1.0);  // tints albedo and emission
// Row of the part's transform relative to the model root that gives height:
// height = dot(xyz, VERTEX) + w. Baked into each model part by tools/bake_models.gd.
instance uniform vec4 part_height_row = vec4(0.0, 1.0, 0.0, 0.0);

varying vec3 v_pos;
varying vec3 v_normal;
varying float v_height;

void vertex() {
	v_height = dot(part_height_row.xyz, VERTEX) + part_height_row.w;
	if (world_space) {
		v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		v_pos = VERTEX;
		v_normal = NORMAL;
	}
	// Writing POSITION replaces the default projection, so always write it.
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps2_vertex_snap > 0.0) {
		vec2 grid = vec2(ps2_vertex_snap, ps2_vertex_snap * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	// Box projection: use the dominant axis only, for crisp seams.
	vec3 n = abs(v_normal);
	vec3 p = v_pos + tex_offset;
	vec2 uv;
	bool top = false;
	if (n.y >= n.x && n.y >= n.z) {
		uv = p.xz;
		top = v_normal.y > 0.0;
	} else if (n.x >= n.z) {
		uv = vec2(p.z, -p.y);
	} else {
		uv = vec2(p.x, -p.y);
	}
	uv = use_uv ? UV : uv;
	uv *= tex_scale;
	vec3 tex = (use_top_tex && top) ? texture(top_tex, uv).rgb : texture(albedo_tex, uv).rgb;
	vec3 col = tex * albedo.rgb * paint.rgb;
	col *= mix(1.0, COLOR.r, vertex_ao);
	if (ao_height > 0.0) {
		col *= mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, v_height));
	}
	vec3 emit = emission.rgb * emission_energy * glow * paint.rgb + vec3(flash);
	if (unshaded) {
		ALBEDO = vec3(0.0);
		EMISSION = col + emit;
	} else {
		ALBEDO = col;
		EMISSION = emit;
		RIM = rim;
		RIM_TINT = 0.6;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = (ndl + light_wrap) / (1.0 + light_wrap);
	float lit = smoothstep(0.0, light_softness, wrapped);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
	if (gloss > 0.0) {
		// Highlights go through DIFFUSE_LIGHT (specular is off), so undo most
		// of the albedo tint to keep them bright.
		vec3 h = normalize(LIGHT + VIEW);
		float sp = pow(max(dot(NORMAL, h), 0.0), mix(6.0, 90.0, gloss_sharpness));
		sp = smoothstep(0.05, 0.6, sp) * step(0.0, ndl);
		vec3 untint = mix(vec3(1.0), 1.0 / max(ALBEDO, vec3(0.08)), 0.75);
		DIFFUSE_LIGHT += gloss * sp * untint * ATTENUATION * LIGHT_COLOR / PI;
	}
}
