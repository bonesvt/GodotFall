extends "res://scripts/ps2/ps2_model.gd"
## Puppet for the Choir and the wildlife past the border
## (assets/models/threats/*.glb, tools/threats/build_threats.py). Every model
## is rigid parts on named pivots; this moves them from the body's speed and a
## few knobs the creature's script sets each frame:
##   tell   0-1  the attack tell: glowing parts flare from their colour to white
##                (the Choir's cyan slits and pipes, a Quillcat's eyes, a
##                Lampjaw's spots, a Glassback's crystals when it's scared)
##   open   0-1  jaw open (Lampjaw), frill flared (Quillcat), vanes up (Hound),
##                head thrown back to sing (Seraph)
##   hurt   bool hit flash
##   look   yaw/pitch for the head (radians), where there is one
## `gait` picks the walk: "biped", "quad", "hex", "hover", "glide" or "scuttle".

@export var gait := "biped"
@export var stride_len := 1.6
@export var swing := 26.0

var tell := 0.0
var open := 0.0
var hurt := false
var look := Vector2.ZERO
## Extra speed for the cycle when the body isn't a CharacterBody3D that moves
## (the Veil Ray glides by setting its position).
var cycle_speed := -1.0

var _p := {}  # pivot name -> Node3D
var _rest := {}  # pivot -> rest rotation
var _glows: Array[GeometryInstance3D] = []
var _solid: Array[GeometryInstance3D] = []
var _t := 0.0
var _cycle := 0.0
var _move := 0.0


func _ready() -> void:
	for n in find_children("*", "Node3D", true, false):
		if n is MeshInstance3D:
			continue
		_p[String(n.name)] = n
		_rest[n] = n.rotation
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Ink":
			continue
		var m := (mi as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		var e = m.get_shader_parameter("emission_energy") if m != null else null
		if e != null and float(e) > 0.0:
			_glows.append(mi)
		else:
			_solid.append(mi)
	var n := get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	_body = n
	_t = randf() * 10.0
	set_process(true)


## The pivot called `name`, or null.
func part(name: String) -> Node3D:
	return _p.get(name)


func _process(delta: float) -> void:
	_t += delta
	var speed := cycle_speed
	if speed < 0.0 and _body != null:
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
		if not _body.is_on_floor() and gait != "hover" and gait != "glide":
			speed *= 0.3
	speed = maxf(speed, 0.0)
	_move = lerpf(_move, clampf(speed / 3.0, 0.0, 1.0), minf(delta * 6.0, 1.0))
	_cycle = fmod(_cycle + speed * delta / stride_len * TAU, TAU)
	var k := minf(delta * 12.0, 1.0)
	match gait:
		"biped":
			_biped(k)
		"quad":
			_quad(k)
		"hex":
			_hex(k)
		"hover":
			_hover(delta, k)
		"glide":
			_glide(k)
		"scuttle":
			_scuttle(k)
	_look(k)
	_open(k)
	for g in _glows:
		g.set_instance_shader_parameter("flash", (0.8 if hurt else 0.0) + tell * 1.1)
		g.set_instance_shader_parameter("glow", 1.0 + tell * 2.5)
	for g in _solid:
		g.set_instance_shader_parameter("flash", 0.6 if hurt else 0.0)


func _turn(name: String, rot: Vector3, k: float) -> void:
	var p: Node3D = _p.get(name)
	if p == null:
		return
	p.rotation = p.rotation.lerp(_rest[p] + rot, k)


func _biped(k: float) -> void:
	var a := sin(_cycle) * deg_to_rad(swing) * _move
	_turn("LegL", Vector3(a, 0, 0), k)
	_turn("LegR", Vector3(-a, 0, 0), k)
	# Backward-bent legs fold at the knee as the leg comes through.
	_turn("KneeL", Vector3(-maxf(-sin(_cycle + 0.6), 0.0) * 0.7 * _move, 0, 0), k)
	_turn("KneeR", Vector3(-maxf(sin(_cycle + 0.6), 0.0) * 0.7 * _move, 0, 0), k)
	var breathe := sin(_t * 1.3) * 0.02
	_turn("Torso", Vector3(-0.08 * _move + breathe, sin(_cycle) * 0.06 * _move, 0), k)
	_turn("Hips", Vector3(0, -sin(_cycle) * 0.05 * _move, 0), k)


func _quad(k: float) -> void:
	var a := sin(_cycle) * deg_to_rad(swing) * _move
	_turn("FrontL", Vector3(a, 0, 0), k)
	_turn("HindR", Vector3(a, 0, 0), k)
	_turn("FrontR", Vector3(-a, 0, 0), k)
	_turn("HindL", Vector3(-a, 0, 0), k)
	_turn("Body", Vector3(sin(_cycle * 2.0) * 0.03 * _move, 0, 0), k)
	_turn("Tail", Vector3(sin(_t * 1.7) * 0.12, sin(_t * 1.1) * 0.25, 0), k)


func _hex(k: float) -> void:
	var a := sin(_cycle) * deg_to_rad(swing) * _move
	for name in ["LegL1", "LegR2", "LegL3"]:
		_turn(name, Vector3(a, 0, 0), k)
	for name in ["LegR1", "LegL2", "LegR3"]:
		_turn(name, Vector3(-a, 0, 0), k)
	_turn("Body", Vector3(0, 0, sin(_cycle * 2.0) * 0.02 * _move), k)
	_turn("Tail", Vector3(0, sin(_t * 0.7) * 0.15, 0), k)


func _hover(delta: float, k: float) -> void:
	var b: Node3D = _p.get("Body")
	if b != null:
		b.position.y = sin(_t * 1.6) * 0.12
		b.rotation.z = sin(_t * 0.9) * 0.06
	var r: Node3D = _p.get("Ring")
	if r != null:
		r.rotate_object_local(Vector3.UP, delta * (0.8 + tell * 4.0))
	var r2: Node3D = _p.get("Ring2")
	if r2 != null:
		r2.rotate_object_local(Vector3.RIGHT, -delta * (0.5 + tell * 3.0))
	_turn("Tail", Vector3(sin(_t * 1.2) * 0.15, 0, sin(_t * 0.8) * 0.12), k)


func _glide(k: float) -> void:
	var flap := sin(_t * (1.4 + _move)) * (0.12 + 0.35 * _move)
	_turn("WingL", Vector3(0, 0, flap), k)
	_turn("WingR", Vector3(0, 0, -flap), k)
	_turn("Tail", Vector3(sin(_t * 1.5) * 0.15, sin(_t * 0.9) * 0.2, 0), k)


func _scuttle(k: float) -> void:
	var b: Node3D = _p.get("Body")
	if b != null:
		b.position.y = absf(sin(_cycle * 2.0)) * 0.02 * _move
		b.rotation.z = sin(_cycle * 2.0) * 0.12 * _move


func _look(k: float) -> void:
	var h: Node3D = _p.get("Head")
	if h == null:
		return
	var graze := 0.0
	if gait == "hex":  # the Glassback grazes with its head down when calm
		graze = 0.35 * (1.0 - _move) * (1.0 - tell)
	h.rotation = h.rotation.lerp(_rest[h] + Vector3(-look.y + graze, look.x, 0), k * 0.5)


func _open(k: float) -> void:
	_turn("Jaw", Vector3(-open * 0.7, 0, 0), k)
	_turn("Lure", Vector3(sin(_t * 1.1) * 0.08 - open * 0.3, sin(_t * 0.7) * 0.1, 0), k)
	var f: Node3D = _p.get("Frill")
	if f != null:
		f.scale = f.scale.lerp(Vector3.ONE * (0.75 + open * 0.55), k)
