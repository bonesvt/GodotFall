extends RefCounted
## The Shepherd's body (shepherd.gd), built in game from rounded primitives in
## the Choir's toon look (eco_toon shader, the threats' ink outline), cut into
## the rigid parts threat_model.gd's biped walk moves: Hips, LegL/R with
## KneeL/R under them, Torso, and Head on the torso. The same design as its
## Blender script (tools/threats/colony.py): ~2.2 m, tall and straight-backed,
## a long white colony coat over grey limbs, a smooth faceless helmet with one
## level slit of light, the dispensary tank on its back glowing with Hymn and
## feeding two tubes over its shoulders, a loudspeaker horn on its left
## shoulder, the colony's ringed seal on its chest and a long white dart rifle
## held low in its right hand. Faces -Z; its right is +X.

const TOON := preload("res://assets/shaders/eco_toon.gdshader")
const INK := preload("res://assets/materials/threats/threat_ink.tres")

static var _mats := {}


## A Node3D holding the whole Shepherd, pivots and all.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ShepherdModel"
	var white := _mat("white", Color(0.86, 0.88, 0.92), 0.0, 0.4)
	var grey := _mat("grey", Color(0.28, 0.3, 0.35), 0.0, 0.0)
	var black := _mat("black", Color(0.07, 0.07, 0.085), 0.0, 0.3)
	var glow := _mat("glow", Color(0.8, 0.92, 1.0), 1.1, 0.0)
	var soft := _mat("soft", Color(0.72, 0.86, 1.0), 0.6, 0.0)

	var hips := _pivot(root, "Hips", Vector3(0, 1.0, 0))
	var torso := _pivot(root, "Torso", Vector3(0, 1.08, 0))
	var head := _pivot(torso, "Head", Vector3(0, 1.86, 0.01))
	# legs: long and straight, grey, white plates on thigh and shin, square boots
	for side in ["L", "R"]:
		var s := 1.0 if side == "R" else -1.0
		var leg := _pivot(root, "Leg" + side, Vector3(0.11 * s, 1.0, 0))
		var knee := _pivot(leg, "Knee" + side, Vector3(0.115 * s, 0.55, 0.02))
		var hip_at := Vector3(0.11 * s, 1.0, 0)
		var knee_at := Vector3(0.115 * s, 0.55, 0.02)
		var ankle_at := Vector3(0.115 * s, 0.1, -0.02)
		_limb(leg, hip_at, knee_at, 0.075, 0.055, grey)
		_ell(leg, (hip_at + knee_at) * 0.5 + Vector3(0, 0, -0.035), Vector3(0.07, 0.21, 0.05), white)
		_ell(knee, knee_at + Vector3(0, 0, -0.05), Vector3(0.05, 0.05, 0.035), grey)
		_limb(knee, knee_at, ankle_at, 0.055, 0.042, grey)
		_ell(knee, (knee_at + ankle_at) * 0.5 + Vector3(0, 0.03, -0.035), Vector3(0.055, 0.2, 0.045), white)
		_box(knee, Vector3(0.115 * s, 0.05, -0.05), Vector3(0.11, 0.1, 0.26), grey)
		_box(knee, Vector3(0.115 * s, 0.04, -0.15), Vector3(0.1, 0.08, 0.08), white)
	# hips: belt and the long coat panels to the knee
	_ell(hips, Vector3(0, 1.06, 0), Vector3(0.14, 0.085, 0.105), grey)
	_box(hips, Vector3(0, 1.1, 0), Vector3(0.32, 0.06, 0.26), grey)
	_box(hips, Vector3(0, 1.1, -0.135), Vector3(0.08, 0.05, 0.02), white)
	for panel in [[Vector3(-0.1, 0.8, -0.13), Vector3(0.16, 0.56, 0.02), 6.0], [Vector3(0.1, 0.8, -0.13), Vector3(0.16, 0.56, 0.02), 6.0],
			[Vector3(0, 0.8, 0.13), Vector3(0.34, 0.56, 0.02), -6.0], [Vector3(-0.17, 0.8, 0), Vector3(0.02, 0.56, 0.22), 0.0],
			[Vector3(0.17, 0.8, 0), Vector3(0.02, 0.56, 0.22), 0.0]]:
		var p := _box(hips, panel[0], panel[1], white)
		p.rotation_degrees.x = -float(panel[2])
	# torso: square chest under the white coat shell, high stand collar, the seal
	_limb(torso, Vector3(0, 1.1, 0), Vector3(0, 1.4, 0), 0.11, 0.13, grey)
	_ell(torso, Vector3(0, 1.5, 0.0), Vector3(0.22, 0.3, 0.155), white)
	_ell(torso, Vector3(0, 1.62, -0.03), Vector3(0.2, 0.14, 0.13), white)
	_limb(torso, Vector3(0, 1.74, 0), Vector3(0, 1.86, 0.01), 0.06, 0.055, grey)
	_torus(torso, Vector3(0, 1.78, 0.005), 0.06, 0.115, white, Vector3.ZERO)
	_ell(torso, Vector3(0, 1.82, 0.01), Vector3(0.095, 0.06, 0.09), white)
	var seal := Vector3(0, 1.6, -0.165)
	_torus(torso, seal, 0.049, 0.061, soft, Vector3(90, 0, 0))
	_torus(torso, seal, 0.029, 0.041, soft, Vector3(90, 0, 0))
	_ell(torso, seal, Vector3(0.014, 0.014, 0.008), glow)
	# arms: square white pauldrons, grey sleeves, white forearm plates
	var rh := Vector3(0.24, 1.06, -0.26)  # right hand, low with the rifle
	var lh := Vector3(-0.3, 0.86, -0.05)  # left hand, hanging open
	for arm in [[1.0, Vector3(0.26, 1.68, 0), Vector3(0.31, 1.36, -0.06), rh], [-1.0, Vector3(-0.26, 1.68, 0), Vector3(-0.31, 1.32, 0.0), lh]]:
		var s: float = arm[0]
		var sh: Vector3 = arm[1]
		var el: Vector3 = arm[2]
		var wr: Vector3 = arm[3]
		_limb(torso, sh, el, 0.055, 0.045, grey)
		_limb(torso, el, wr, 0.045, 0.035, grey)
		_ell(torso, sh + Vector3(0.02 * s, 0.04, 0), Vector3(0.1, 0.07, 0.11), white)
		var pad := _box(torso, sh + Vector3(0.05 * s, -0.04, 0), Vector3(0.05, 0.12, 0.18), white)
		pad.rotation_degrees.z = 20.0 * s
		_ell_along(torso, el.lerp(wr, 0.12), wr.lerp(el, 0.1), 0.05, 0.048, white)
		_ell(torso, wr + (wr - el).normalized() * 0.06, Vector3(0.04, 0.03, 0.05), grey)
	# the loudspeaker horn on its left shoulder, facing ahead
	var lsh := Vector3(-0.27, 1.8, 0.02)
	_limb(torso, lsh, lsh + Vector3(0, 0.06, -0.05), 0.02, 0.02, grey)
	var horn := _cone(torso, lsh + Vector3(0, 0.08, -0.12), 0.06, 0.012, 0.18, black)
	horn.rotation_degrees.x = 90.0
	_torus(torso, lsh + Vector3(0, 0.08, -0.21), 0.054, 0.066, white, Vector3(90, 0, 0))
	# the dart rifle: white stock and body, grey barrel, glowing darts
	var d := Vector3(0, -0.12, -1).normalized()
	var stock := rh - d * 0.28
	var muzzle := rh + d * 0.95
	_limb(torso, stock, rh + d * 0.3, 0.04, 0.035, white)
	_limb(torso, rh + d * 0.2, muzzle, 0.016, 0.012, grey)
	_limb(torso, rh + d * 0.28, rh + d * 0.62, 0.03, 0.028, white)
	_limb(torso, rh + d * 0.1 + Vector3(0, -0.06, 0), rh + d * 0.2 + Vector3(0, -0.06, 0), 0.022, 0.022, soft)
	for t in [0.66, 0.8]:
		var r := _torus(torso, rh + d * t, 0.016, 0.024, soft, Vector3.ZERO)
		r.basis = _along(d)
	# the dispensary tank on its back: grey caps and cage, Hymn glowing inside,
	# two tubes up and over its shoulders to its collar
	var tk := Vector3(0, 1.42, 0.24)
	_limb(torso, tk + Vector3(0, -0.28, 0), tk + Vector3(0, 0.28, 0), 0.12, 0.12, soft)
	for y in [-0.3, 0.3]:
		_limb(torso, tk + Vector3(0, y - 0.03, 0), tk + Vector3(0, y + 0.03, 0), 0.135, 0.135, grey)
	for k in 4:
		var ang := deg_to_rad(45.0 + k * 90.0)
		var p := tk + Vector3(cos(ang) * 0.125, 0, sin(ang) * 0.125)
		_limb(torso, p + Vector3(0, -0.28, 0), p + Vector3(0, 0.28, 0), 0.01, 0.01, white)
	_box(torso, Vector3(0, 1.42, 0.15), Vector3(0.26, 0.5, 0.06), grey)
	for s in [-1.0, 1.0]:
		var pts := [tk + Vector3(s * 0.05, 0.3, 0), Vector3(s * 0.1, 1.84, 0.2), Vector3(s * 0.08, 1.86, 0.06)]
		for i in 2:
			_limb(torso, pts[i], pts[i + 1], 0.016, 0.016, soft)
	# head: smooth faceless white helmet, black face band, one level slit of light
	var hc := Vector3(0, 2.02, 0.02)
	_ell(head, hc + Vector3(0, 0.01, 0), Vector3(0.105, 0.15, 0.125), white)
	_ell(head, hc + Vector3(0, -0.005, -0.06), Vector3(0.1, 0.06, 0.07), black)
	_ell(head, hc + Vector3(0, 0, -0.118), Vector3(0.085, 0.012, 0.012), glow)
	_ell(head, hc + Vector3(0, 0.09, -0.02), Vector3(0.09, 0.05, 0.11), white)
	_ell(head, hc + Vector3(0, -0.1, 0), Vector3(0.075, 0.04, 0.08), grey)
	for s in [-1.0, 1.0]:
		_limb(head, hc + Vector3(s * 0.1, -0.02, 0.01), hc + Vector3(s * 0.112, -0.02, 0.01), 0.022, 0.022, grey)
	return root


## A pivot at `at` (model space) under `parent`, whose own pivot is at its position.
static func _pivot(parent: Node3D, pname: String, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pname
	var base := _model_pos(parent)
	p.position = at - base
	p.set_meta("model_pos", at)
	parent.add_child(p)
	return p


static func _model_pos(n: Node3D) -> Vector3:
	return n.get_meta("model_pos", Vector3.ZERO)


## Puts `mi` at model-space `at` under `parent`.
static func _put(parent: Node3D, mi: MeshInstance3D, at: Vector3) -> MeshInstance3D:
	mi.position = at - _model_pos(parent)
	parent.add_child(mi)
	return mi


static func _ell(parent: Node3D, at: Vector3, r: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 12
	mi.mesh = sm
	sm.material = m
	mi.scale = r
	return _put(parent, mi, at)


## A tapered rod from `a` to `b` (radius r1 to r2), rounded at both ends.
static func _limb(parent: Node3D, a: Vector3, b: Vector3, r1: float, r2: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r1
	c.top_radius = r2
	c.height = maxf(a.distance_to(b), 0.001)
	c.radial_segments = 16
	c.rings = 1
	mi.mesh = c
	c.material = m
	_put(parent, mi, (a + b) * 0.5)
	mi.basis = _along((b - a).normalized())
	for end in [[a, r1], [b, r2]]:
		_ell(parent, end[0], Vector3.ONE * float(end[1]), m)
	return mi


## A basis turning +Y onto dir.
static func _along(dir: Vector3) -> Basis:
	var up := Vector3.UP
	if absf(dir.dot(up)) < 0.999:
		return Basis(up.cross(dir).normalized(), up.angle_to(dir))
	return Basis(Vector3.RIGHT, PI) if dir.y < 0.0 else Basis()


## A long ellipsoid plate from  to , x wide and z deep.
static func _ell_along(parent: Node3D, a: Vector3, b: Vector3, rx: float, rz: float, m: Material) -> MeshInstance3D:
	var mi := _ell(parent, (a + b) * 0.5, Vector3.ONE, m)
	mi.basis = _along((b - a).normalized()) * Basis.from_scale(Vector3(rx, a.distance_to(b) * 0.5, rz))
	return mi


static func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	bm.material = m
	return _put(parent, mi, at)


static func _cone(parent: Node3D, at: Vector3, r_wide: float, r_narrow: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_wide
	c.bottom_radius = r_narrow
	c.height = h
	c.radial_segments = 20
	mi.mesh = c
	c.material = m
	return _put(parent, mi, at)


static func _torus(parent: Node3D, at: Vector3, inner: float, outer: float, m: Material, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 8
	mi.mesh = t
	t.material = m
	mi.rotation_degrees = rot
	return _put(parent, mi, at)


## The threats' toon look: eco_toon with an ink outline (none on what glows).
static func _mat(key: String, c: Color, glow: float, sheen: float) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("exposure", 0.62)
	m.set_shader_parameter("shade_tint", Vector3(0.7, 0.72, 0.84))
	m.set_shader_parameter("sheen", sheen)
	m.set_shader_parameter("rim", 0.0 if glow > 0.0 else 0.22)
	if glow > 0.0:
		m.set_shader_parameter("emission", c)
		m.set_shader_parameter("emission_energy", glow)
	else:
		m.next_pass = INK
	_mats[key] = m
	return m
