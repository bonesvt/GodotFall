extends CanvasLayer
## What the Rig's mods (redline.gd) let Eco sense and do, on a run or at home:
##   cat_ears / pointed_ears  enemies she hears (behind her, or all round,
##                            further) ping a red mark at the edge of her
##                            view, pointing their way
##   red_eyes                 while she's high, every enemy glows through walls
##   night_eyes               dark places drawn brighter for her
##   horns                    sprinting into an enemy knocks them down
## The run manager adds it; it reads the player and the "enemies" group.

const Redline := preload("res://scripts/hub/redline.gd")
const SFX := preload("res://scripts/sfx.gd")

const PING_EVERY := 1.2
const PING_FADE := 1.0
const RED := Color(1.0, 0.18, 0.12)
## The horns: how fast she has to be going, how close, how long they're down, what it does.
const CHARGE_SPEED := 7.0
const CHARGE_RANGE := 1.4
const CHARGE_STAGGER := 2.0
const CHARGE_DAMAGE := 20.0
const NIGHT_AMBIENT := 0.45

var rm: Node
var _draw_on: Control
var _ping_t := 0.0
## [angle (radians, 0 = straight ahead, + to her right), age]
var _pings: Array = []
var _charged := {}
var _env_seen: WorldEnvironment


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "RedlineSenses"
	layer = 3


func _ready() -> void:
	_draw_on = Control.new()
	_draw_on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_on.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_on.draw.connect(_draw)
	add_child(_draw_on)


func _player() -> Node3D:
	return rm.get("player") as Node3D


func _process(delta: float) -> void:
	var p := _player()
	if p == null or not Redline.allowed() or get_tree().paused:
		_pings.clear()
		_draw_on.queue_redraw()
		return
	_hear(p, delta)
	_horns(p)
	_night()
	_draw_on.queue_redraw()


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Node3D and is_instance_valid(e) and not ("dead" in e and e.dead))


## Enemies she can hear, pinged now and then.
func _hear(p: Node3D, delta: float) -> void:
	for ping in _pings:
		ping[1] += delta
	_pings = _pings.filter(func(ping): return ping[1] < PING_FADE)
	var h := Redline.hearing()
	if float(h[0]) <= 0.0:
		return
	_ping_t -= delta
	if _ping_t > 0.0:
		return
	_ping_t = PING_EVERY
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for e in _enemies():
		var to: Vector3 = (e as Node3D).global_position - p.global_position
		if to.length() > float(h[0]):
			continue
		to.y = 0.0
		if to.length() < 0.5:
			continue
		var ang := fwd.signed_angle_to(to.normalized(), Vector3.DOWN)
		if bool(h[1]) and absf(ang) < deg_to_rad(100.0):  # cat ears: only behind her
			continue
		_pings.append([ang, 0.0])


## The horns: going flat out into someone, they go down.
func _horns(p: Node3D) -> void:
	if not Redline.charge_knocks_down() or not p.has_method("horizontal_speed") or p.horizontal_speed() < CHARGE_SPEED:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var fwd := -p.global_basis.z
	for e in _enemies():
		var to: Vector3 = (e as Node3D).global_position - p.global_position
		to.y = 0.0
		if to.length() > CHARGE_RANGE or to.normalized().dot(Vector3(fwd.x, 0, fwd.z).normalized()) < 0.4:
			continue
		if now - float(_charged.get(e.get_instance_id(), -10.0)) < 1.5:
			continue
		_charged[e.get_instance_id()] = now
		if e.has_method("stagger"):
			e.stagger(CHARGE_STAGGER)
		if e.has_method("take_damage"):
			e.take_damage(CHARGE_DAMAGE, p.global_position, false)
		if e is CharacterBody3D:
			(e as CharacterBody3D).velocity += to.normalized() * 6.0 + Vector3.UP * 2.0
		SFX.play(self, "hit_body", -2.0, 0.7)
		if rm.get("hud") != null:
			rm.hud.toast("Horns first. Down he goes.", 1.2)


## Night eyes: the dark of wherever she is, brighter.
func _night() -> void:
	var root: Node = rm.get("zone_root")
	if root == null or not is_instance_valid(root):
		return
	var env: WorldEnvironment = null
	for n in root.find_children("*", "WorldEnvironment", true, false):
		env = n
		break
	if env == null or env.environment == null:
		return
	var e := env.environment
	if not e.has_meta("redline_ambient"):
		e.set_meta("redline_ambient", e.ambient_light_energy)
	var own: float = e.get_meta("redline_ambient")
	e.ambient_light_energy = maxf(own, NIGHT_AMBIENT) if Redline.sees_in_dark() else own


func _draw() -> void:
	var p := _player()
	if p == null:
		return
	var size := _draw_on.get_rect().size
	if size.x < 100.0:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	for ping in _pings:
		var a: float = ping[0]
		var fade := 1.0 - float(ping[1]) / PING_FADE
		var dir := Vector2(sin(a), -cos(a))
		var at := c + dir * r
		var side := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([at + dir * 16.0, at + side * 10.0, at - side * 10.0])
		_draw_on.draw_colored_polygon(pts, Color(RED, 0.85 * fade))
		_draw_on.draw_arc(c, r - 6.0, a - PI * 0.5 - 0.12, a - PI * 0.5 + 0.12, 8, Color(RED, 0.6 * fade), 3.0)
	if Redline.xray():
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		for e in _enemies():
			var at3: Vector3 = (e as Node3D).global_position + Vector3(0, 1.1, 0)
			if cam.is_position_behind(at3) or at3.distance_to(cam.global_position) > 60.0:
				continue
			var at := cam.unproject_position(at3)
			var k := 14.0
			_draw_on.draw_rect(Rect2(at - Vector2(k * 0.6, k * 1.4), Vector2(k * 1.2, k * 2.8)), Color(RED, 0.55), false, 2.0)
			_draw_on.draw_circle(at, 3.0, Color(RED, 0.9))
