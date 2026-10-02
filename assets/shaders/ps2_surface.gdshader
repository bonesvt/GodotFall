// The game's surface shader. Two looks, switched project-wide by the
// ps3_look shader global (F9, see scripts/ps2/ps2_screen.gd):
//   PS3 (1, default): high-res painted textures with normal maps, roughness
//     and metal masks (tools/make_textures.py), triplanar box projection,
//     soft-wrapped lambert plus GGX highlights, sky reflections.
//   PS2 (0): the old Jak and Daxter / Shadow of the Colossus look: blurry
//     low mips, flat surfaces, banded two-tone lighting, painted highlight.
// Textures are box projected (world space for level geometry, object space
// for models), so primitive-built models need no UVs. Both looks keep the
// painted rim light and the fake ambient occlusion toward a model's feet.
shader_type spatial;
render_mode diffuse_lambert;

// Snap grid width in pixels for vertex positions (PS1/PS2 wobble). 0 is off.
// Set project-wide in Project Settings > Shader Globals.
global uniform float ps2_vertex_snap;
// 1 = PS3 look, 0 = PS2 look.
global uniform float ps3_look;

// RGB albedo, A roughness.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// RG tangent normal (green up), B dielectric mask (0 = bare metal).
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Optional second texture pair for upward-facing faces (platform tops).
uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
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
// PS2 painted highlight: how bright, and how tight (0 broad, 1 pin-sharp).
// In the PS3 look gloss makes the surface smoother instead.
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_sharpness : hint_range(0.0, 1.0) = 0.5;

// PS3 look: physical surface knobs.
uniform float normal_strength : hint_range(0.0, 3.0) = 1.0;
// Multiplies the roughness in the texture's alpha (textures without one are 1).
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
// Metalness everywhere (chrome, gold, gun steel), plus how much the
// texture's bare-metal mask (paint chipped to steel, rivets) adds.
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float metal_mask : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// Light shining through thin things (leaves, grass, cloth).
uniform float translucency : hint_range(0.0, 1.0) = 0.0;
// How sharply the three box projections cross-fade on curved models.
uniform float blend_sharpness = 6.0;

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
varying float v_specular;

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

// PS2 look: blur the high-res textures back down to about 128 px.
float ps2_bias(sampler2D tex) {
	float size = float(textureSize(tex, 0).x);
	return (1.0 - ps3_look) * max(log2(size / 128.0), 0.0);
}

vec3 tangent_normal(vec4 n) {
	vec2 xy = (n.rg * 2.0 - 1.0) * normal_strength * ps3_look;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

void fragment() {
	vec4 tex;
	vec4 ntex;
	vec3 surf_n;  // in the projection's space (world or object)
	if (use_uv) {
		vec2 uv = UV * tex_scale;
		tex = texture(albedo_tex, uv, ps2_bias(albedo_tex));
		ntex = texture(normal_tex, uv);
		vec3 tn = tangent_normal(ntex);
		NORMAL = normalize(TANGENT * tn.x + BINORMAL * tn.y + NORMAL * tn.z);
	} else {
		// Box projection, cross-faded by how much the surface faces each axis.
		// Boxes face one axis exactly, so level geometry keeps crisp seams.
		vec3 p = (v_pos + tex_offset) * tex_scale;
		vec3 an = abs(v_normal);
		vec3 w = pow(an, vec3(blend_sharpness));
		w /= w.x + w.y + w.z;
		bool top = v_normal.y > 0.0 && use_top_tex;
		vec2 uv_x = vec2(p.z, -p.y);
		vec2 uv_y = p.xz;
		vec2 uv_z = vec2(p.x, -p.y);
		tex = vec4(0.0);
		ntex = vec4(0.0);
		vec3 n = vec3(0.0);
		if (w.x > 0.01) {
			vec4 a = texture(albedo_tex, uv_x, ps2_bias(albedo_tex));
			vec4 b = texture(normal_tex, uv_x);
			vec3 tn = tangent_normal(b);
			// u runs along +Z, image up is +Y.
			n += w.x * vec3(tn.z * sign(v_normal.x), tn.y, tn.x);
			tex += w.x * a;
			ntex += w.x * b;
		}
		if (w.y > 0.01) {
			vec4 a = top ? texture(top_tex, uv_y, ps2_bias(top_tex)) : texture(albedo_tex, uv_y, ps2_bias(albedo_tex));
			vec4 b = top ? texture(top_normal_tex, uv_y) : texture(normal_tex, uv_y);
			vec3 tn = tangent_normal(b);
			// u runs along +X, image up is -Z.
			n += w.y * vec3(tn.x, tn.z * sign(v_normal.y), -tn.y);
			tex += w.y * a;
			ntex += w.y * b;
		}
		if (w.z > 0.01) {
			vec4 a = texture(albedo_tex, uv_z, ps2_bias(albedo_tex));
			vec4 b = texture(normal_tex, uv_z);
			vec3 tn = tangent_normal(b);
			// u runs along +X, image up is +Y.
			n += w.z * vec3(tn.x, tn.y, tn.z * sign(v_normal.z));
			tex += w.z * a;
			ntex += w.z * b;
		}
		surf_n = normalize(n);
		if (ps3_look > 0.0) {
			vec3 view_n = world_space ? (VIEW_MATRIX * vec4(surf_n, 0.0)).xyz : (VIEW_MATRIX * (MODEL_MATRIX * vec4(surf_n, 0.0))).xyz;
			NORMAL = normalize(view_n);
		}
	}
	vec3 col = tex.rgb * albedo.rgb * paint.rgb;
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
		RIM = rim * mix(1.0, 0.6, ps3_look);
		RIM_TINT = 0.6;
		float r = clamp(tex.a * roughness, 0.04, 1.0);
		if (gloss > 0.0) {
			r = min(r, mix(0.65, 0.12, gloss * gloss_sharpness));
		}
		ROUGHNESS = r;
		METALLIC = clamp(metallic + metal_mask * (1.0 - ntex.b), 0.0, 1.0) * ps3_look;
		SPECULAR = specular * ps3_look;
		v_specular = specular;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// PS2: banded two-tone. PS3: wrapped lambert, a touch of the paint left in.
	float wrapped = (ndl + light_wrap) / (1.0 + light_wrap);
	float toon = smoothstep(0.0, light_softness, wrapped);
	float w = light_wrap * 0.4;
	float soft = clamp((ndl + w) / (1.0 + w), 0.0, 1.0);
	float lit = mix(toon, soft, ps3_look);
	vec3 radiance = ATTENUATION * LIGHT_COLOR;
	DIFFUSE_LIGHT += lit * radiance / PI;
	DIFFUSE_LIGHT += translucency * ps3_look * clamp(-ndl, 0.0, 1.0) * 0.5 * radiance / PI;
	if (ps3_look > 0.0) {
		// GGX highlight (Schlick fresnel, Smith visibility).
		vec3 h = normalize(LIGHT + VIEW);
		float nl = max(ndl, 0.0);
		float nv = max(dot(NORMAL, VIEW), 1e-3);
		float nh = max(dot(NORMAL, h), 0.0);
		float lh = max(dot(LIGHT, h), 0.0);
		float a = ROUGHNESS * ROUGHNESS;
		float a2 = a * a;
		float d = nh * nh * (a2 - 1.0) + 1.0;
		float D = a2 / (PI * d * d);
		float k = a * 0.5;
		float V = 0.25 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
		vec3 f0 = mix(vec3(0.08 * v_specular), ALBEDO, METALLIC);
		vec3 F = f0 + (1.0 - f0) * pow(1.0 - lh, 5.0);
		SPECULAR_LIGHT += ps3_look * D * V * F * nl * radiance;
	} else if (gloss > 0.0) {
		// Highlights go through DIFFUSE_LIGHT, so undo most of the albedo tint
		// to keep them bright.
		vec3 h = normalize(LIGHT + VIEW);
		float sp = pow(max(dot(NORMAL, h), 0.0), mix(6.0, 90.0, gloss_sharpness));
		sp = smoothstep(0.05, 0.6, sp) * step(0.0, ndl);
		vec3 untint = mix(vec3(1.0), 1.0 / max(ALBEDO, vec3(0.08)), 0.75);
		DIFFUSE_LIGHT += gloss * sp * untint * radiance / PI;
	}
}
