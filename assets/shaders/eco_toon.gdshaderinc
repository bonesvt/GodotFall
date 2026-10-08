// Eco's anime toon shading, matching the VRoid preset she is built from
// (tools/eco/build_eco_vroid.py): two flat tones with a crisp edge between
// them (the shadow side is the colour times a tint, never black), a thin rim
// of light on her silhouette, an optional thin, hard sheen (the glossy suit,
// boots, goggle lenses) and glowing trims. Included by eco_toon.gdshader
// (one-sided), eco_toon_2side.gdshader (hair cards, face, boots) and
// eco_toon_overlay.gdshader (eyes, brows, lashes: alpha blended).

// Same vertex snap as ps2_surface.gdshader, so she wobbles with the rest of
// the world in the old PS2 look (F9).
global uniform float ps2_vertex_snap;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 albedo : source_color = vec4(1.0);
// VRoid textures are the final on-screen colour (anime skin is near white),
// so they are dimmed to sit under the game's sun and sky like everything else.
uniform float exposure : hint_range(0.0, 2.0) = 0.6;
// Texels with less alpha than this are cut away (hair cards). 0 keeps all.
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.0;
// Multiplies the colour on the side turned away from the light. Plain
// numbers (not a colour), like the preset's shade tints.
uniform vec3 shade_tint = vec3(0.93, 0.72, 0.72);
// Second shade tint, used where mask_tex is green (the suit on her body).
uniform vec3 shade_tint_2 = vec3(0.6, 0.6, 0.78);
// Where the lit side ends (light . normal) and how soft that edge is.
uniform float shade_edge : hint_range(-1.0, 1.0) = 0.0;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.04;
// Thin rim of light round her silhouette.
uniform float rim : hint_range(0.0, 1.0) = 0.22;
// Thin, hard sheen, and its colour.
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sheen_color : source_color = vec3(0.77, 0.8, 0.86);
// R: where the sheen may show; G: where shade_tint_2 applies. Only read when use_mask is on.
uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap;
uniform bool use_mask = false;
// Tangent-space normal map (her suit's cling), only read when use_normal is on.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool use_normal = false;
uniform float normal_depth = 1.0;
// Glowing trims: a texture and/or a flat colour.
uniform sampler2D glow_tex : source_color, hint_default_black, filter_linear_mipmap;
uniform float glow_tex_energy = 1.6;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Tattoos from Ink & Iron in Solace (scripts/hub/eco_extras.gd), baked into her
// body's UVs by tools/ink/build_tattoos.py: laid over the colour wherever the
// body texture is skin (the mask's green is low), so clothes cover them.
uniform sampler2D tattoo_tex : source_color, hint_default_transparent, filter_linear_mipmap;
// Suit upgrade armour edges: how brightly they glow gold once her trims turn gold.
uniform float gold_edge = 0.0;
// A suit weight's changes to the suit itself (eco_model.gd body_material), laid
// over whichever suit style she wears: kit_tex is their colour, kit_glow_tex
// their glowing trims, and kit_mask_tex R where the sheen shows, G where the
// suit's shade tint applies, B how much of the kit covers the style.
uniform bool use_kit = false;
uniform sampler2D kit_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D kit_mask_tex : hint_default_black, filter_linear_mipmap;
uniform sampler2D kit_glow_tex : source_color, hint_default_black, filter_linear_mipmap;

// Battle damage (scripts/ps2/battle_damage.gd): how dirty, scuffed, torn and
// scarred she has got this run, 0..1, the same for every copy of her.
global uniform float eco_grime;
global uniform float eco_scuffs;
global uniform float eco_tears;
global uniform float eco_scars;
// How far sliding has worn her suit through (her outer thighs, glutes and hips).
global uniform float eco_slide;
// Marrow's Glass (scripts/hub/glass.gd): how far violet crystal has crept
// over her skin, 0..1, spreading in the order dirt does (damage_tex R).
global uniform float eco_glass;
// The glass's colour: Marrow's violet, or a hypno look's own (vice_looks.gd:
// gold for the Faith Idol, ice for Kintsugi's frost).
global uniform vec3 eco_glass_tint;
// 0: none (hair, eyes, glass). 1: her body or face, from damage_tex
// (tools/eco/bake_damage.py; each channel the level at which a texel turns:
// R grime, G torn, B scuffed, A scarred; tears only open on her suit's fabric,
// where the mask's G is). 2: a piece of kit she wears: dust and scuffs only.
// 3: cloth over her suit (jackets, hoodie, skirts), from damage_tex (R grime,
// G torn by hits, B scuffed, A worn through by sliding): torn cloth is cut away.
uniform int damage_kind = 0;
uniform sampler2D damage_tex : hint_default_white, filter_linear, repeat_disable;
// Where sliding wears through (R: the slide level each texel opens at), and
// the stitched seams that hem a rip running up to a covered zone (G: the
// eco_tears level a seam shows at, B: the eco_slide level, A: its stitches).
uniform sampler2D damage_slide_tex : hint_default_white, filter_linear, repeat_disable;
// Her skin where the suit tears open.
uniform vec3 skin_tone : source_color = vec3(0.97, 0.86, 0.8);
const vec3 DIRT = vec3(0.24, 0.2, 0.16);
const vec3 CUT = vec3(0.62, 0.1, 0.12);
const vec3 GRAZE = vec3(0.9, 0.58, 0.52);

// Per-object knobs shared with ps2_surface.gdshader (see ps2_model.gd).
instance uniform float flash : instance_index(0) = 0.0;
instance uniform float glow : instance_index(1) = 1.0;
instance uniform vec4 paint : source_color, instance_index(2) = vec4(1.0);
// Top suit tier (eco_model.gd suit_tier 5, Dad's colours): every glowing trim
// turns gold and the armour edges light up.
instance uniform float trim_gold : instance_index(3) = 0.0;
const vec3 GOLD = vec3(1.0, 0.68, 0.2);
// Marrow's Hush (vices.gd): violet spirals turning in her irises, stronger
// the deeper his Hold (eco_model.gd sets `hypno` 0..1). Only on the iris
// layer (iris_swirl), whose texture holds both irises (centres IRIS_L/R,
// radius IRIS_R in UV).
uniform bool iris_swirl = false;
instance uniform float hypno : instance_index(4) = 0.0;
const vec2 IRIS_L = vec2(0.252, 0.504);
const vec2 IRIS_RIGHT = vec2(0.747, 0.504);
const vec2 IRIS_R = vec2(0.112, 0.225);
const vec3 HUSH_VIOLET = vec3(0.72, 0.32, 1.0);

varying float v_sheen_mask;

float damage_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float damage_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(damage_hash(i), damage_hash(i + vec2(1.0, 0.0)), f.x),
			mix(damage_hash(i + vec2(0.0, 1.0)), damage_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
varying float v_rim;
varying vec3 v_shade;
// her model-space position (feet at 0, head at about 1.6 m), for the Glass's spread
varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (ps2_vertex_snap > 0.0) {
		vec2 grid = vec2(ps2_vertex_snap, ps2_vertex_snap * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 col = tex.rgb * albedo.rgb * paint.rgb;
	vec2 mask = use_mask ? texture(mask_tex, UV).rg : vec2(1.0, 0.0);
	vec3 kit_mask = use_kit ? texture(kit_mask_tex, UV).rgb : vec3(0.0);
	if (use_kit) {
		col = mix(col, texture(kit_tex, UV).rgb * albedo.rgb * paint.rgb, kit_mask.b);
		mask = mix(mask, kit_mask.rg, kit_mask.b);
	}
	// battle damage, laid on in the order it happens to her: scuffed fabric,
	// torn open, cut, then dirt over all of it
	float torn = 0.0;
	float scuffed = 0.0;
	vec3 glass_emit = vec3(0.0);
#ifndef OVERLAY
	if (damage_kind == 1) {
		vec4 d = texture(damage_tex, UV);
		float fabric = step(0.5, mask.g);
		float speck = damage_noise(UV * 900.0);
		scuffed = smoothstep(d.b, d.b + 0.1, eco_scuffs) * fabric;
		vec3 worn = mix(col, vec3(dot(col, vec3(0.333))), 0.55) * 1.3 + 0.05;
		col = mix(col, worn, scuffed * (0.45 + 0.35 * speck));
		// torn by hits (G, eco_tears) or worn through by sliding (the slide
		// map, eco_slide): whichever is further past its level here
		float tl = d.g;
		float tv = eco_tears;
		vec4 sm = texture(damage_slide_tex, UV);
		float sl = sm.r;
		float grazed = 0.0;
		if (eco_slide - sl > tv - tl) {
			tl = sl;
			tv = eco_slide;
			grazed = 1.0;
		}
		torn = smoothstep(tl, tl + 0.012, tv) * fabric;
		// the fabric round a tear darkens and frays before it opens
		float fray = smoothstep(tl - 0.07, tl, tv) * fabric * (1.0 - torn) * step(tl, 0.99);
		col *= 1.0 - fray * (0.55 + 0.3 * speck);
		// skin inside, a little shadowed under the torn edge (and grazed pink
		// where she slid on it)
		float lip = 1.0 - smoothstep(tl + 0.012, tl + 0.08, tv);
		vec3 skin = mix(skin_tone, skin_tone * GRAZE, grazed * smoothstep(0.3, 0.7, damage_noise(UV * 260.0)) * 0.7);
		col = mix(col, skin * albedo.rgb * (1.0 - 0.3 * lip), torn);
		mask = mix(mask, vec2(0.0), torn);
		// a rip's hem: a darker, doubled-over band of fabric, stitched down
		float seam = max(smoothstep(sm.g, sm.g + 0.012, eco_tears), smoothstep(sm.b, sm.b + 0.012, eco_slide))
				* fabric * step(min(sm.g, sm.b), 0.99);
		col = mix(col, col * 0.45, seam);
		col = mix(col, vec3(0.86, 0.82, 0.74) * albedo.rgb, seam * sm.a * 0.9);
		// fresh cuts, on her skin only (bare, or where the suit tore)
		float cut = smoothstep(d.a, d.a + 0.02, eco_scars) * max(torn, 1.0 - fabric);
		col = mix(col, CUT, cut * 0.85);
		float g = smoothstep(d.r, d.r + 0.22, eco_grime);
		col = mix(col, col * DIRT * 2.2 + DIRT * 0.1, g * (0.4 + 0.25 * damage_noise(UV * 140.0)) * (0.8 + 0.2 * speck));
		// Glass on her skin: faceted violet crystal, its seams glowing
		if (eco_glass > 0.0) {
			// it creeps up from her limbs, round the sides of her neck and jaw
			// and up her cheeks, the middle of her face last; never quite all of it
			float reach = smoothstep(1.66, 1.15, v_obj.y) * 0.7 + clamp(abs(v_obj.x) / 0.08, 0.0, 1.0) * 0.3
					+ (damage_noise(v_obj.xy * 38.0) - 0.5) * 0.3;
			float front = 1.0 - eco_glass * 0.82;
			float glassed = smoothstep(front, front + 0.03, reach) * max(torn, 1.0 - fabric);
			vec2 fc = UV * 70.0;
			vec2 gi = floor(fc);
			vec2 gf = fract(fc);
			float d1 = 8.0;
			float d2 = 8.0;
			float facet = 0.0;
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					vec2 o = vec2(float(x), float(y));
					vec2 pt = o + vec2(damage_hash(gi + o), damage_hash(gi + o + 17.3)) - gf;
					float dd = length(pt);
					if (dd < d1) {
						d2 = d1;
						d1 = dd;
						facet = damage_hash(gi + o + 5.1);
					} else if (dd < d2) {
						d2 = dd;
					}
				}
			}
			float seam_glow = 1.0 - smoothstep(0.0, 0.06, d2 - d1);
			// each facet a flat plane of glass: a light and a dark side, a pale glint
			float plane = step(0.5, fract(facet * 7.0));
			vec3 crystal = mix(eco_glass_tint * vec3(0.417, 0.375, 0.48), mix(eco_glass_tint, vec3(1.0), 0.55), 0.2 + 0.5 * facet + 0.2 * plane);
			// a soft edge where it meets her skin, glassy right through further in
			float rim_in = smoothstep(front + 0.03, front + 0.1, reach);
			col = mix(col, crystal, glassed * (0.55 + 0.4 * rim_in));
			glass_emit = eco_glass_tint * (seam_glow * 1.2 + 0.08 + 0.12 * facet) * glassed;
		}
	} else if (damage_kind == 3) {
		vec4 d = texture(damage_tex, UV);
		float speck = damage_noise(UV * 900.0);
		scuffed = smoothstep(d.b, d.b + 0.1, eco_scuffs);
		col = mix(col, mix(col, vec3(dot(col, vec3(0.333))), 0.55) * 1.3 + 0.05, scuffed * (0.45 + 0.35 * speck));
		float tl = d.g;
		float tv = eco_tears;
		if (eco_slide - d.a > tv - tl) {
			tl = d.a;
			tv = eco_slide;
		}
		if (tv > tl + 0.006 && tl < 0.99) {
			discard;
		}
		float fray = smoothstep(tl - 0.07, tl, tv) * step(tl, 0.99);
		col *= 1.0 - fray * (0.55 + 0.3 * speck);
		float g = smoothstep(d.r, d.r + 0.22, eco_grime);
		col = mix(col, col * DIRT * 2.2 + DIRT * 0.1, g * (0.4 + 0.25 * damage_noise(UV * 140.0)) * (0.8 + 0.2 * speck));
	} else if (damage_kind == 2) {
		float n = damage_noise(UV * 30.0) * 0.6 + damage_noise(UV * 95.0) * 0.4;
		scuffed = smoothstep(0.35 + n * 0.6, 0.5 + n * 0.6, eco_scuffs);
		col = mix(col, mix(col, vec3(dot(col, vec3(0.333))), 0.5) * 1.25 + 0.04, scuffed * 0.4);
		float g = smoothstep(n * 0.7, n * 0.7 + 0.35, eco_grime);
		col = mix(col, col * DIRT * 2.2 + DIRT * 0.1, g * 0.55);
	}
#endif
	v_sheen_mask = sheen * mask.r * (1.0 - scuffed * 0.8);
	vec3 hypno_emit = vec3(0.0);
	if (iris_swirl && hypno > 0.0) {
		bool left = UV.x < 0.5;
		vec2 d = (UV - (left ? IRIS_L : IRIS_RIGHT)) / IRIS_R;
		float r = length(d);
		float turn = (left ? 1.0 : -1.0) * TIME * (1.5 + 2.0 * hypno);
		float arms = 0.5 + 0.5 * sin(atan(d.y, d.x) * 3.0 + r * 16.0 - turn);
		float band = smoothstep(0.45, 0.8, arms) * (1.0 - smoothstep(0.8, 1.0, r)) * smoothstep(0.1, 0.3, r);
		float k = clamp(hypno, 0.0, 1.0);
		col = mix(col, col * 0.4 + HUSH_VIOLET * 0.7, k * 0.55);
		col = mix(col, vec3(1.0, 0.8, 1.0), band * k);
		// the iris glows softly all the time, breathing; the spiral arms brightest
		float iris = 1.0 - smoothstep(0.85, 1.0, r);
		float breath = 0.2 + 0.08 * sin(TIME * 1.6);
		hypno_emit = HUSH_VIOLET * (band * 0.9 + iris * breath) * k;
	}
	v_shade = mix(shade_tint, shade_tint_2, mask.g);
	vec4 tattoo = texture(tattoo_tex, UV);
	if (use_mask && tattoo.a > 0.0) {
		col = mix(col, tattoo.rgb, tattoo.a * 0.9 * (1.0 - smoothstep(0.3, 0.6, mask.g)));
	}
	ALBEDO = col * exposure;
	if (use_normal) {
		NORMAL_MAP = mix(texture(normal_tex, UV).rgb, vec3(0.5, 0.5, 1.0), torn);
		NORMAL_MAP_DEPTH = normal_depth;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 emit = texture(glow_tex, UV).rgb * glow_tex_energy + emission.rgb * emission_energy;
	if (use_kit) {
		emit = mix(emit, texture(kit_glow_tex, UV).rgb * glow_tex_energy, kit_mask.b);
	}
	emit *= 1.0 - torn;
	if (trim_gold > 0.0) {
		emit = mix(emit, GOLD * max(emit.r, max(emit.g, emit.b)), trim_gold) + GOLD * gold_edge * trim_gold;
	}
	EMISSION = emit * glow * paint.rgb + vec3(flash) + hypno_emit + glass_emit;
	v_rim = smoothstep(0.72, 0.9, fres) * rim;
#ifdef OVERLAY
	ALPHA = tex.a * albedo.a;
#else
	ALPHA = tex.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(shade_edge - shade_softness, shade_edge + shade_softness, ndl);
	vec3 radiance = ATTENUATION * LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += mix(v_shade, vec3(1.0), lit) * radiance;
	// rim: light added straight on top, so it reads on dark suit and pale skin alike
	SPECULAR_LIGHT += v_rim * exposure * radiance;
	if (v_sheen_mask > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = pow(max(dot(NORMAL, h), 0.0), 60.0);
		SPECULAR_LIGHT += sheen_color * smoothstep(0.45, 0.55, s) * smoothstep(0.1, 0.3, ndl) * v_sheen_mask * exposure * radiance;
	}
}
