extends Node
## Solace's two moods: sunlit solarpunk on the plaza and the garden, and a dark
## cyberpunk dusk under the canopy over the shop rows. While the camera is in
## one of `zones` the sun and ambient light fade down and the haze turns violet,
## so the neon carries the street; stepping back out fades them up again.
## Works on the hub's own WorldEnvironment and sun (siblings in the hub root).

## (x, z, width, depth) rectangles under the canopy.
var zones: Array[Rect2] = []
## How far a zone's edge fades in, metres.
var fade := 6.0

var _env: Environment
var _sun: DirectionalLight3D
var _base := {}
var _amount := 0.0

const DARK := {"ambient": 0.22, "sun": 0.3, "glow": 1.7}
const HAZE := Color(0.32, 0.26, 0.42)


func _ready() -> void:
	_grab.call_deferred()


## Reads the base values once the look (look.gd) has set them up.
func _grab() -> void:
	for node in get_parent().get_children():
		if node is WorldEnvironment:
			_env = node.environment
		elif node is DirectionalLight3D:
			_sun = node
	if _env == null or _sun == null:
		set_process(false)
		return
	_base = {"ambient": _env.ambient_light_energy, "sun": _sun.light_energy, "fog": _env.fog_light_color,
		"glow": _env.glow_intensity}


func _process(delta: float) -> void:
	if _base.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var target := inside(cam.global_position)
	_amount = move_toward(_amount, target, delta * 1.5)
	var t := smoothstep(0.0, 1.0, _amount)
	_env.ambient_light_energy = lerpf(_base["ambient"], _base["ambient"] * DARK["ambient"], t)
	_sun.light_energy = lerpf(_base["sun"], _base["sun"] * DARK["sun"], t)
	_env.fog_light_color = (_base["fog"] as Color).lerp(HAZE, t)
	_env.glow_intensity = lerpf(_base["glow"], _base["glow"] * DARK["glow"], t)


## 0 outside every zone, 1 deep inside one, fading over `fade` metres at the edges.
func inside(p: Vector3) -> float:
	var best := 0.0
	for r in zones:
		var dx := minf(p.x - r.position.x, r.end.x - p.x)
		var dz := minf(p.z - r.position.y, r.end.y - p.z)
		best = maxf(best, clampf(minf(dx, dz) / fade, 0.0, 1.0))
	return best
