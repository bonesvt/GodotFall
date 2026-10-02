// Full-screen PS2 filter: 16-bit colour with ordered dithering, a faint
// interlace line pattern and slightly lifted blacks. The low internal
// resolution itself comes from Project Settings > Rendering > Scaling 3D.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// Levels per colour channel (32 = 5 bits, like a PS2 16-bit framebuffer).
uniform float color_levels = 32.0;
uniform float dither_strength = 1.0;
// Size of one dither cell in screen pixels.
uniform float pixel_size = 2.0;
uniform float interlace = 0.04;
uniform float black_lift = 0.02;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	ivec2 p = ivec2(floor(FRAGCOORD.xy / pixel_size)) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c += b * dither_strength / color_levels;
	c = floor(c * color_levels + 0.5) / color_levels;
	c = c * (1.0 - black_lift) + black_lift;
	if (int(floor(FRAGCOORD.y / pixel_size)) % 2 == 1) {
		c *= 1.0 - interlace;
	}
	COLOR = vec4(c, 1.0);
}
