extends CanvasLayer
## What the craving looks like (vices.gd crave_level(): the stim shakes, or
## Marrow's clock running on her at full Hold). A violet dark closes in from
## the edges and thumps like a heartbeat, faster and harder as it builds; past
## halfway, spiral tendrils curl in from the corners. A trigger word (or his
## pull) flares it. Off when clean, dosed or under Teen. Sits over the 3D view
## and the drunk haze (drunk_screen.gd), under the HUD.

const Vices := preload("res://scripts/hub/vices.gd")

const SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform float beat = 0.0;
uniform float flare = 0.0;
uniform float aspect = 1.777;

void fragment() {
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(c);
	float a = atan(c.y, c.x);
	float s = strength;
	// The dark closes in: further the worse it gets, and it thumps.
	float reach = mix(0.95, 0.42, s) - 0.06 * beat * s;
	float edge = smoothstep(reach, reach + 0.55, r);
	// Spiral tendrils curling in from the edges once it's past halfway.
	float spiral = sin(a * 5.0 + log(r + 0.05) * 9.0 - TIME * 1.6);
	float tendrils = smoothstep(0.55, 1.0, spiral) * smoothstep(reach - 0.25, reach + 0.3, r) * smoothstep(0.45, 0.9, s);
	float k = clamp(edge * (0.55 + 0.35 * beat) + tendrils * 0.5, 0.0, 1.0);
	vec3 violet = mix(vec3(0.08, 0.0, 0.14), vec3(0.62, 0.22, 0.95), tendrils + 0.25 * beat);
	k = max(k * s, flare * (0.35 + 0.5 * smoothstep(0.1, 0.8, r)));
	violet = mix(violet, vec3(0.75, 0.4, 1.0), flare * 0.6);
	COLOR = vec4(violet, k * 0.85);
}
"""

## Beats a minute: just there, and as bad as it gets.
const BPM_LOW := 70.0
const BPM_HIGH := 140.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _phase := 0.0
var _flare := 0.0


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


## Two thumps a beat, lub-dub, 0..1.
static func heartbeat(phase: float) -> float:
	var p := fposmod(phase, 1.0)
	return maxf(exp(-pow((p - 0.05) * 14.0, 2.0)), 0.7 * exp(-pow((p - 0.28) * 14.0, 2.0)))


func _process(delta: float) -> void:
	var s := Vices.crave_level()
	# His words or his pull: it flares while they have her.
	_flare = move_toward(_flare, 1.0 if (Vices.entranced and Vices.allowed()) else 0.0, delta * 2.5)
	_rect.visible = s > 0.01 or _flare > 0.01
	if not _rect.visible:
		return
	_phase += delta * lerpf(BPM_LOW, BPM_HIGH, s) / 60.0
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("strength", s)
	_mat.set_shader_parameter("beat", heartbeat(_phase))
	_mat.set_shader_parameter("flare", _flare)
