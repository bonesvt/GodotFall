extends CanvasLayer
## What a few drinks at the Rusted Halo do to Eco's eyes (vices.gd): the view
## softens, doubles and drifts, the edges close in and warm up. Strength
## follows Vices.haze() (the buzz, a stim crash or the shakes), so it fades
## as they wear off and is off entirely when clean or under Teen. Sits after the 3D view and the PS2/PS3
## post pass (layer -1), before the HUD, so the HUD stays readable.

const Vices := preload("res://scripts/hub/vices.gd")

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform vec2 ghost = vec2(0.0);

vec3 soft(vec2 uv, float lod) {
	return textureLod(screen_tex, uv, lod).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// A slow swim: the picture breathes in and out from the centre.
	vec2 c = uv - 0.5;
	uv = 0.5 + c * (1.0 - 0.012 * strength * (0.5 + 0.5 * sin(TIME * 0.8)));
	float lod = 1.4 * strength;
	vec3 base = soft(uv, lod);
	// Double vision: a second picture sliding beside the first.
	vec3 dbl = soft(uv + ghost, lod + 0.5);
	vec3 col = mix(base, dbl, 0.5 * strength);
	// Edges blur more and close in, a little warm.
	float r = length(c * vec2(1.0, 0.8));
	vec3 edge = soft(uv, lod + 2.0);
	col = mix(col, edge, smoothstep(0.25, 0.7, r) * strength);
	col *= 1.0 - smoothstep(0.2, 0.65, r) * 0.6 * strength;
	col = mix(col, col * vec3(1.08, 0.97, 0.88), 0.6 * strength);
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _process(delta: float) -> void:
	var e := Vices.haze()
	_rect.visible = e > 0.01
	if not _rect.visible:
		return
	_t += delta
	var g := Vector2(sin(_t * 0.6) * 0.6 + sin(_t * 1.7) * 0.4, sin(_t * 0.45 + 1.0) * 0.5) * 0.026 * e
	_mat.set_shader_parameter("strength", e)
	_mat.set_shader_parameter("ghost", g)
