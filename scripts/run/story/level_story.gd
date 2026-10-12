extends Node3D
## A level's story set piece (levels.gd "story"): the yard it takes over in
## the generated level (a "story" section, level_plan.gd), the things Eco can
## use there with F, and what has to be done before the way out lets her
## leave. zone_generator.gd builds it (build()); the run manager hands it
## itself when the zone loads (begin()), asks it for a prompt and passes F on
## (prompt(), use()), ticks it, and asks it at the beacon (can_leave(),
## leave_nag(), finish()).
##
## How deep Marrow's Hold goes when she gets there decides how it plays
## (stage(): CLEAN, HOOKED, HIS; vices.gd), read once at the start of the run.

const Vices := preload("res://scripts/hub/vices.gd")
const SFX := preload("res://scripts/sfx.gd")
const Kit := preload("res://scripts/run/level_kit.gd")

enum { CLEAN, HOOKED, HIS }
## Marrow's Hold at each stage's start (vices.gd hold, 0..100).
const HOOKED_AT := 30.0
const HIS_AT := 60.0
## How close Eco has to be to use something.
const REACH := 3.0

var rm: Node
var stage := CLEAN
## The things she can use: id -> {"at": Vector3 (local), "prompt": String}.
var spots := {}
var _said := {}


## How deep his Hold is now.
static func stage_now() -> int:
	if Vices.hold >= HIS_AT:
		return HIS
	if Vices.hold >= HOOKED_AT:
		return HOOKED
	return CLEAN


## Builds the set piece into the generated yard. Overridden.
func build(_gen, _plan, _info: Dictionary, _keep_out: Array, _s: Dictionary, _c: float, _side: float,
		_squad: Array, _zone_index: int, _dress: RandomNumberGenerator) -> void:
	pass


## The run's begun here (the zone is built and Eco placed).
func begin(run_manager: Node) -> void:
	rm = run_manager
	stage = stage_now()
	_begin()


func _begin() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## The id of what she's in reach of, or "".
func near(pos: Vector3) -> String:
	var best := ""
	var d := REACH
	for id in spots:
		if not _usable(id):
			continue
		var at: Vector3 = to_global(spots[id]["at"])
		var dist := Vector2(pos.x - at.x, pos.z - at.z).length()
		if dist < d and absf(pos.y - at.y) < 3.0:
			best = id
			d = dist
	return best


func prompt(pos: Vector3) -> String:
	var id := near(pos)
	return "" if id == "" else String(spots[id]["prompt"])


## F by it. Returns whether something happened.
func use(pos: Vector3) -> bool:
	var id := near(pos)
	if id == "":
		return false
	_use(id)
	return true


func _usable(_id: String) -> bool:
	return true


func _use(_id: String) -> void:
	pass


## Whether the beacon lets her go yet.
func can_leave() -> bool:
	return true


## Why not, for the HUD.
func leave_nag() -> String:
	return ""


## She's leaving: settles what the level did (once) and returns the run
## summary's line.
func finish() -> String:
	return "Out."


## Lines one after another, a beat apart, while she's still on the level.
func say(lines: Array, gap := 3.4) -> void:
	var t := 0.0
	for line in lines:
		if t == 0.0:
			rm.hud.toast(line, gap + 0.2)
		else:
			get_tree().create_timer(t, false, true).timeout.connect(_line.bind(line, gap))
		t += gap


## A line once only (by key).
func say_once(key: String, lines: Array) -> void:
	if _said.has(key):
		return
	_said[key] = true
	say(lines)


func _line(line: String, gap: float) -> void:
	if is_instance_valid(rm) and rm.phase == rm.Phase.ZONE:
		rm.hud.toast(line, gap + 0.2)


## A plain box, for props.
func box(at: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	return mi


## A label in the world, facing the road.
func sign_text(at: Vector3, text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 6
	add_child(l)
	l.position = at
	return l
