// Glossy painted metal for the titans, in the spirit of the Jak II / Jak X
// vehicles: bold colour blocks with a hard candy highlight and a horizon-line
// reflection, paint chipped back to bare steel on the edges, and grime
// collected low down. Built for the Blender titans in assets/models/titans/:
//   COLOR.r  baked ambient occlusion
//   COLOR.g  edge convexity (chips start on sharp outer edges)
// The wear mask is box projected in object space, like ps2_surface, so the
// models need no UVs. Same per-object knobs as ps2_surface (flash, glow,
// paint), so ps2_model.gd set_param works on titans unchanged. No vertex
// snap: the import script builds these materials, and global uniforms don't
// exist while importing.
shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 albedo : source_color = vec4(0.5, 0.6, 0.8, 1.0);
// What shows through where the paint is chipped.
uniform vec4 chip_color : source_color = vec4(0.55, 0.55, 0.56, 1.0);
uniform sampler2D wear_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.35;
// 0 = factory fresh, 1 = more chip than paint.
uniform float wear : hint_range(0.0, 1.0) = 0.25;
uniform float grime : hint_range(0.0, 1.0) = 0.3;
uniform vec4 grime_color : source_color = vec4(0.22, 0.18, 0.14, 1.0);
// Glossy paint: highlight strength and tightness, and the fake reflection.
uniform float gloss : hint_range(0.0, 1.0) = 0.6;
uniform float shininess = 48.0;
uniform float reflection : hint_range(0.0, 1.0) = 0.35;
uniform vec4 sky_tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 ground_tint : source_color = vec4(0.25, 0.2, 0.16, 1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool unshaded = false;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.3;
uniform float light_softness : hint_range(0.01, 1.0) = 0.35;
uniform float rim : hint_range(0.0, 1.0) = 0.3;

instance uniform float flash = 0.0;
instance uniform float glow = 1.0;
instance uniform vec4 paint : source_color = vec4(1.0);

varying vec3 v_pos;
varying vec3 v_normal;
varying float v_shine;

void vertex() {
	v_pos = VERTEX;
	v_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(v_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = v_pos.xz;
	} else if (n.x >= n.z) {
		uv = vec2(v_pos.z, -v_pos.y);
	} else {
		uv = vec2(v_pos.x, -v_pos.y);
	}
	vec3 mask = texture(wear_tex, uv * tex_scale).rgb;
	float ao = mix(1.0, COLOR.r, ao_strength);
	float edge = COLOR.g;

	// Chips: the mask cut at a threshold that drops on convex edges.
	float cut = 1.0 - wear * (0.55 + edge * 0.9);
	float chip = smoothstep(cut, cut + 0.03, mask.r) * step(0.001, wear);
	// Paint edge: a thin dark rim round each chip, like flaked enamel.
	float rim_band = smoothstep(cut - 0.06, cut, mask.r) * (1.0 - chip);

	vec3 base = albedo.rgb * paint.rgb;
	vec3 metal = chip_color.rgb * (0.75 + mask.b * 0.5);
	vec3 col = mix(base, metal, chip);
	col *= 1.0 - rim_band * 0.35 * step(0.001, wear);
	// Grime: blotches and streaks, heavier in the occluded creases.
	float g = mask.g * grime * (1.3 - COLOR.r * 0.6);
	col = mix(col, grime_color.rgb, clamp(g, 0.0, 0.85));
	col *= ao;

	float shine = gloss * (1.0 - chip * 0.7) * (1.0 - clamp(g, 0.0, 1.0) * 0.6);
	// Horizon-line reflection: bright sky above, warm ground below, sharp
	// line between them, strongest at grazing angles. Sells the car paint.
	vec3 r = reflect(-VIEW, NORMAL);
	vec3 rw = (INV_VIEW_MATRIX * vec4(r, 0.0)).xyz;
	float horizon = smoothstep(-0.02, 0.06, rw.y);
	vec3 env = mix(ground_tint.rgb * 0.5, sky_tint.rgb, horizon);
	float fres = 0.08 + 0.92 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 refl = env * reflection * shine * fres * ao;

	vec3 emit = emission.rgb * emission_energy * glow * paint.rgb + vec3(flash);
	if (unshaded) {
		ALBEDO = vec3(0.0);
		EMISSION = col + emit;
	} else {
		ALBEDO = col;
		EMISSION = emit + refl;
		RIM = rim;
		RIM_TINT = 0.5;
		// Physical finish for the sky reflections of the PS3 look: polished
		// paint is smooth, grime and chips rough it up, chips are bare steel.
		ROUGHNESS = mix(0.75, 0.18, shine) + mask.b * 0.08;
		METALLIC = chip * 0.85;
		v_shine = shine;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = (ndl + light_wrap) / (1.0 + light_wrap);
	float lit = smoothstep(0.0, light_softness, wrapped);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
	// Candy highlight: Blinn-Phong pushed to a near hard edge.
	vec3 h = normalize(LIGHT + VIEW);
	float s = pow(max(dot(NORMAL, h), 0.0), shininess);
	s = smoothstep(0.35, 0.6, s) * 0.8 + s * 0.4;
	SPECULAR_LIGHT += s * v_shine * ATTENUATION * LIGHT_COLOR * step(0.0, ndl);
}
