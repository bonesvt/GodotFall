// PS2-style surface: small nearest-filtered textures mapped by box projection
// (world space for level geometry, object space for models, so primitive-built
// models need no UVs), lambert-only lighting, and a slight vertex snap that
// gives the faint wobble of low-precision hardware.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Snap grid width in pixels for vertex positions. 0 turns the wobble off.
// Set project-wide in Project Settings > Shader Globals.
global uniform float ps2_vertex_snap;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Optional second texture for upward-facing faces (platform tops).
uniform sampler2D top_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_top_tex = false;
uniform vec4 albedo : source_color = vec4(1.0);
// Texture repeats per metre.
uniform float tex_scale = 0.5;
// Shifts the projected texture, in metres.
uniform vec3 tex_offset = vec3(0.0);
// true: textures stay put in the world (levels). false: they move with the model.
uniform bool world_space = true;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Ignore lighting entirely (lights, screens, lava).
uniform bool unshaded = false;

// Per-object knobs, set with set_instance_shader_parameter (see ps2_model.gd).
instance uniform float flash = 0.0;          // white hit flash, 0..1
instance uniform float glow = 1.0;           // multiplies emission
instance uniform vec4 paint : source_color = vec4(1.0);  // tints albedo and emission

varying vec3 v_pos;
varying vec3 v_normal;

void vertex() {
	if (world_space) {
		v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		v_pos = VERTEX;
		v_normal = NORMAL;
	}
	if (ps2_vertex_snap > 0.0) {
		vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		vec2 grid = vec2(ps2_vertex_snap, ps2_vertex_snap * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
		POSITION = clip;
	}
}

void fragment() {
	// Box projection: use the dominant axis only, for crisp PS2-era seams.
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
	uv *= tex_scale;
	vec3 tex = (use_top_tex && top) ? texture(top_tex, uv).rgb : texture(albedo_tex, uv).rgb;
	vec3 col = tex * albedo.rgb * paint.rgb;
	vec3 emit = emission.rgb * emission_energy * glow * paint.rgb + vec3(flash);
	if (unshaded) {
		ALBEDO = vec3(0.0);
		EMISSION = col + emit;
	} else {
		ALBEDO = col;
		EMISSION = emit;
	}
}
