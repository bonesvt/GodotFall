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
// Suit upgrade armour edges: how brightly they glow gold once her trims turn gold.
uniform float gold_edge = 0.0;

// Per-object knobs shared with ps2_surface.gdshader (see ps2_model.gd).
instance uniform float flash : instance_index(0) = 0.0;
instance uniform float glow : instance_index(1) = 1.0;
instance uniform vec4 paint : source_color, instance_index(2) = vec4(1.0);
// Top suit tier (eco_model.gd suit_tier 5, Dad's colours): every glowing trim
// turns gold and the armour edges light up.
instance uniform float trim_gold : instance_index(3) = 0.0;
const vec3 GOLD = vec3(1.0, 0.68, 0.2);

varying float v_sheen_mask;
varying float v_rim;
varying vec3 v_shade;

void vertex() {
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
	v_sheen_mask = sheen * mask.r;
	v_shade = mix(shade_tint, shade_tint_2, mask.g);
	ALBEDO = col * exposure;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 emit = texture(glow_tex, UV).rgb * glow_tex_energy + emission.rgb * emission_energy;
	if (trim_gold > 0.0) {
		emit = mix(emit, GOLD * max(emit.r, max(emit.g, emit.b)), trim_gold) + GOLD * gold_edge * trim_gold;
	}
	EMISSION = emit * glow * paint.rgb + vec3(flash);
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
