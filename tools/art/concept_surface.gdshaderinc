// Concept-art copy of ps2_surface.gdshaderinc (tools/art/style_shots.gd swaps
// it in on every surface for the art-style concept renders). Same uniforms, so
// materials keep their textures and knobs. Changes:
//   - textures are read from a blurrier mip (CONCEPT_FLAT) and posterised, so
//     the noisy painted grain becomes broad flat shapes like an anime background;
//   - no normal maps or GGX highlights;
//   - cel lighting: a hard-edged lit/shadow split (CONCEPT_CEL_SOFT wide);
//   - ROUGHNESS is written as 0.5 so the post pass can tell the set (painted)
//     from the characters (Eco's toon shaders write 1.0).
// The style file defines CONCEPT_FLAT, CONCEPT_CEL_SOFT, CONCEPT_POSTERIZE,
// CONCEPT_SATURATION, CONCEPT_SHADOW (vec4: rgb tint, a strength),
// CONCEPT_LAMP_ENERGY and CONCEPT_LAMP_NEUTRAL first.

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
instance uniform float flash : instance_index(0) = 0.0;          // white hit flash, 0..1
instance uniform float glow : instance_index(1) = 1.0;           // multiplies emission
instance uniform vec4 paint : source_color, instance_index(2) = vec4(1.0);  // tints albedo and emission
// Row of the part's transform relative to the model root that gives height:
// height = dot(xyz, VERTEX) + w. Baked into each model part by tools/bake_models.gd.
instance uniform vec4 part_height_row : instance_index(3) = vec4(0.0, 1.0, 0.0, 0.0);

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
	return max(log2(size / 128.0), 0.0) * (1.0 - ps3_look) + CONCEPT_FLAT;
}

vec3 tangent_normal(vec4 n) {
	vec2 xy = vec2(0.0);
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
	if (CONCEPT_POSTERIZE > 0.0) {
		col = floor(col * CONCEPT_POSTERIZE + 0.5) / CONCEPT_POSTERIZE;
	}
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = max(mix(vec3(grey), col, CONCEPT_SATURATION), vec3(0.0));
	col *= mix(1.0, COLOR.r, vertex_ao);
	if (ao_height > 0.0) {
		col *= mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, v_height));
	}
	vec3 emit = emission.rgb * emission_energy * glow * paint.rgb + vec3(flash);
#ifdef PS2_UNSHADED
	ALBEDO = col + emit;
#else
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
		ROUGHNESS = 0.5;
		METALLIC = 0.0;
		SPECULAR = 0.0;
		v_specular = specular;
	}
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shade = min(ndl, ATTENUATION * 2.0 - 0.5);
	float cel = smoothstep(-CONCEPT_CEL_SOFT, CONCEPT_CEL_SOFT, shade);
	vec3 radiance = LIGHT_COLOR;
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lamps: a soft painted glow pool that still ends in a clean edge.
		float pool = ATTENUATION;
		cel = smoothstep(0.0, 0.1, ndl) * smoothstep(0.12, 0.17, pool) * CONCEPT_LAMP_ENERGY;
		// Lamps lean toward white so warm bulbs don't flood the whole set orange.
		radiance = mix(radiance, vec3(dot(radiance, vec3(0.333))), CONCEPT_LAMP_NEUTRAL);
	}
	// Shadow side keeps a tinted share of the light: coloured shadows, not grey.
	vec3 lit = mix(CONCEPT_SHADOW.rgb * CONCEPT_SHADOW.a, vec3(1.0), cel);
	if (!LIGHT_IS_DIRECTIONAL) {
		lit = vec3(cel);
	}
	DIFFUSE_LIGHT += lit * radiance / PI;
}
