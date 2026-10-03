// A blush on a hub person's cheeks (hub_npc.gd puts it between their face
// material and its ink outline). The face drawn again, nudged a hair toward
// the camera, multiplying a soft pink into two patches of the face texture
// where the VRoid preset paints its cheeks; nothing elsewhere, nothing at 0.
shader_type spatial;
render_mode unshaded, blend_mul, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blush : source_color = vec3(0.96, 0.56, 0.62);
// Cheek centres and radii in face-texture UV (1024 px: 330 / 690 across,
// a little under the 625 px from the bottom they sit at, so the blush
// reads on the cheek, not under the eye), the same patches the build scripts
// tone down in tools/npc/build_npc.py.
uniform vec2 left_cheek = vec2(0.318, 0.645);
uniform vec2 right_cheek = vec2(0.678, 0.645);
uniform vec2 radius = vec2(0.12, 0.06);

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz -= normalize(view.xyz) * 0.0006;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec2 a = (UV - left_cheek) / radius;
	vec2 b = (UV - right_cheek) / radius;
	float w = max(1.0 - smoothstep(0.15, 1.0, length(a)), 1.0 - smoothstep(0.15, 1.0, length(b)));
	ALBEDO = mix(vec3(1.0), blush, clamp(w * amount, 0.0, 1.0));
}
