// Eco's ink outline (next pass of her toon materials): the mesh drawn again,
// pushed out along its normals and seen only from inside, so a thin dark line
// shows round her silhouette and where parts overlap. The push is worked out
// on screen, so the line stays about the same number of pixels wide near and
// far. With alpha_cut set, the line follows the cut-out of hair cards.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

global uniform float ps2_vertex_snap;

uniform vec4 ink : source_color = vec4(0.25, 0.19, 0.23, 1.0);
// Line width in pixels at 1080p (scaled with the screen height).
uniform float width = 1.6;
// Never wider than this in metres (close up, where pixels are huge on her).
uniform float max_width = 0.003;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
// Tints the ink toward the surface colour underneath (0 plain ink).
uniform float tint : hint_range(0.0, 1.0) = 0.35;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.0;

instance uniform vec4 paint : source_color, instance_index(2) = vec4(1.0);

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	// metres that make `width` pixels at this depth. abs(): on Vulkan the
	// projection's Y scale is negative (flipped), which pushed the line inward
	// and hid it behind the surface.
	float px_size = 2.0 * -view.z / (abs(PROJECTION_MATRIX[1][1]) * 1080.0);
	view.xyz += n * min(width * px_size, max_width);
	vec4 clip = PROJECTION_MATRIX * view;
	if (ps2_vertex_snap > 0.0) {
		vec2 grid = vec2(ps2_vertex_snap, ps2_vertex_snap * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = ink.rgb * mix(vec3(1.0), tex.rgb * paint.rgb, tint);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
