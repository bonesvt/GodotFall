extends RefCounted
## The Shepherd's gear on Eco (hymn.gd GEAR), built from primitives on her
## bones the way eco_extras.gd builds her piercings: authored in rest model
## space (she faces -Z, her left is -X), moved into the bone's space, on the
## same render layers as her own meshes. eco_model.gd apply_suit() calls
## apply() on every model of her, so it follows whatever she has on.
##   headphones  white cans with glowing rings and a band over her head; a
##               pin from each cup locked into her ear (why they won't come off)
##   cuff        a white dose cuff on her left wrist, its ring glowing, four
##               needles in under it
##   visor       the clarity visor: a white band over her eyes, lit across,
##               a glass suction cup sealed on each eye under it, and a prong
##               into each temple
## Each piece sits under a node named for it, and its moving parts are named
## too (Cup_L/R, Pin_L/R, Shell, Needle_N, EyeCup_L/R, Stalk_L/R, Prong_L/R), so the fitting in the
## dispensary's back room (fitting_scene.gd) can play them going on: open()
## puts a piece in its open, unfitted pose, fit() moves it along (0..1).

const Hymn := preload("res://scripts/hub/hymn.gd")

const HEAD := "J_Bip_C_Head"
const WRIST := "J_Bip_L_Hand"
const NODE := "ColonyGear"
## Her ears and temples in rest model space.
const EAR := Vector3(0.072, 1.522, 0.012)
const TEMPLE := Vector3(0.07, 1.555, -0.035)
## Her right eye (her left mirrors it), the visor's inside face, and how far in
## front of her face it waits while the suction cups go on.
const EYE := Vector3(0.032, 1.532, -0.064)
const VISOR_INNER := -0.0475
const VISOR_HOVER := -0.075

static var _mats := {}


static func apply(model: Node, gear: Array = []) -> void:
	if model == null:
		return
	if gear.is_empty() and Hymn.allowed():
		gear = Hymn.gear
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone(HEAD) < 0:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(NODE):
			skel.remove_child(child)
			child.free()
	if not Hymn.allowed():
		return
	if "headphones" in gear or "visor" in gear:
		var head := _root(skel, HEAD, NODE)
		if "headphones" in gear:
			_headphones(_piece(head, "headphones"))
		if "visor" in gear:
			_visor(_piece(head, "visor"))
		_match_layers(model, head, "Face")
	if "cuff" in gear and skel.find_bone(WRIST) >= 0:
		var wrist := _root(skel, WRIST, NODE + "_Cuff")
		_cuff(_piece(wrist, "cuff"), skel.get_bone_global_rest(skel.find_bone(WRIST)).origin)
		_match_layers(model, wrist, "Body")


## The piece's node on a model (null if it isn't wearing it).
static func piece_node(model: Node, piece: String) -> Node3D:
	return model.find_child(piece, true, false) as Node3D


## How far through its fitting a piece is: 0 open and clear of her, 1 locked on.
##   headphones  0-0.3 the cups come in close, 0.3-0.7 the pins slide into her
##               ears, 0.7-1 the cups clamp shut
##   cuff        0-0.4 the needles slide in, 0.4-1 the cuff closes round them
##   visor       0-0.35 it comes down and stops just in front of her face,
##               0.35-0.65 the suction cups reach out of it onto her eyes,
##               0.65-0.8 it seats over them, 0.8-1 the prongs go in
static func fit(node: Node3D, piece: String, k: float) -> void:
	if node == null:
		return
	match piece:
		"headphones":
			for side in ["L", "R"]:
				var s := -1.0 if side == "L" else 1.0
				var cup := node.get_node_or_null("Cup_" + side) as Node3D
				var pin := node.get_node_or_null("Pin_" + side) as Node3D
				if cup != null:
					var open := lerpf(0.13, 0.08, smoothstep(0.0, 0.3, k)) * (1.0 - smoothstep(0.7, 1.0, k))
					cup.position = Vector3(open * s, 0, 0)
				if pin != null:
					pin.scale = Vector3(1, maxf(smoothstep(0.3, 0.7, k), 0.01), 1)
		"cuff":
			var shell := node.get_node_or_null("Shell") as Node3D
			if shell != null:
				var r := lerpf(1.8, 1.0, smoothstep(0.4, 1.0, k))
				shell.scale = Vector3(1, r, r)
			for n in node.get_children():
				if String(n.name).begins_with("Needle_"):
					(n as Node3D).scale = Vector3(1, maxf(smoothstep(0.0, 0.4, k), 0.01), 1)
		"visor":
			var hover := VISOR_HOVER * (1.0 - smoothstep(0.65, 0.8, k))
			node.position = Vector3(0, 0.35 * (1.0 - smoothstep(0.0, 0.35, k)), hover)
			var reach := smoothstep(0.35, 0.65, k)
			var inner := VISOR_INNER + node.position.z  # the visor's inside face, where the cups come from
			for side in ["L", "R"]:
				var cup := node.get_node_or_null("EyeCup_" + side) as Node3D
				var stalk := node.get_node_or_null("Stalk_" + side) as Node3D
				if cup != null:
					# out of the visor's face and onto her eye, then left there as it seats
					var z := lerpf(inner, EYE.z, reach) - node.position.z
					cup.position = Vector3(cup.position.x, EYE.y - node.position.y, z)
					cup.scale = Vector3.ONE * maxf(smoothstep(0.35, 0.45, k), 0.01)
				if stalk != null:
					var length := maxf(lerpf(inner, EYE.z, reach) - inner, 0.0)
					stalk.visible = length > 0.004 and k < 0.8
					stalk.position = Vector3(stalk.position.x, EYE.y - node.position.y, VISOR_INNER + length * 0.5)
					stalk.scale = Vector3(1, maxf(length / 0.01, 0.01), 1)
				var prong := node.get_node_or_null("Prong_" + side) as Node3D
				if prong != null:
					prong.scale = Vector3(1, maxf(smoothstep(0.8, 1.0, k), 0.01), 1)


static func _root(skel: Skeleton3D, bone: String, node_name: String) -> Node3D:
	var att := BoneAttachment3D.new()
	att.name = node_name
	att.bone_name = bone
	skel.add_child(att)
	var root := Node3D.new()
	root.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()
	att.add_child(root)
	return root


static func _piece(root: Node3D, piece: String) -> Node3D:
	var n := Node3D.new()
	n.name = piece
	root.add_child(n)
	return n


static func _match_layers(model: Node, root: Node3D, mesh_name: String) -> void:
	var own := model.find_child(mesh_name, true, false) as MeshInstance3D
	if own != null:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			mi.layers = own.layers


static func _headphones(root: Node3D) -> void:
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var cup := Node3D.new()
		cup.name = "Cup_" + side
		root.add_child(cup)
		var c := _cylinder(cup, Vector3(0.088 * s, 1.505, 0.012), 0.048, 0.035, _shell())
		c.rotation_degrees = Vector3(0, 0, 90)
		var ring := _torus(cup, Vector3(0.107 * s, 1.505, 0.012), 0.026, 0.034, _lit())
		ring.rotation_degrees = Vector3(0, 0, 90)
		# the pin: from the cup's inside face into her ear, grown along its own Y
		var pin := Node3D.new()
		pin.name = "Pin_" + side
		pin.position = Vector3(0.105 * s, EAR.y, EAR.z)
		pin.rotation_degrees = Vector3(0, 0, 90.0 * s)  # its +Y points in at her ear
		root.add_child(pin)
		_cylinder(pin, Vector3(0, 0.022, 0), 0.006, 0.044, _lit())
		_cylinder(pin, Vector3(0, 0.002, 0), 0.011, 0.008, _shell())
	for i in 9:
		var a := PI * (i + 0.5) / 9.0
		var seg := _box(root, Vector3(cos(a) * 0.098, 1.515 + sin(a) * 0.125, 0.012), Vector3(0.05, 0.016, 0.03), _dark())
		seg.rotation_degrees = Vector3(0, 0, rad_to_deg(a) + 90.0)


static func _visor(root: Node3D) -> void:
	_box(root, Vector3(0, 1.535, -0.085), Vector3(0.175, 0.075, 0.075), _shell())
	_box(root, Vector3(0, 1.535, -0.124), Vector3(0.15, 0.022, 0.004), _lit())
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		_box(root, Vector3(0.088 * s, 1.54, -0.01), Vector3(0.012, 0.03, 0.15), _dark())
		# a glass suction cup for each eye, on a stalk from the visor's inside face
		var cup := Node3D.new()
		cup.name = "EyeCup_" + side
		cup.position = Vector3(EYE.x * s, EYE.y, EYE.z)
		root.add_child(cup)
		var dome := SphereMesh.new()
		dome.radius = 0.014
		dome.height = 0.014
		dome.is_hemisphere = true
		var d := _add(cup, dome, Vector3.ZERO, _lens())
		d.rotation_degrees = Vector3(-90, 0, 0)  # the dome away from her eye, open side on it
		var rim := _torus(cup, Vector3.ZERO, 0.012, 0.0155, _dark())
		rim.rotation_degrees = Vector3(90, 0, 0)
		var stalk := Node3D.new()
		stalk.name = "Stalk_" + side
		stalk.position = Vector3(EYE.x * s, EYE.y, VISOR_INNER)
		root.add_child(stalk)
		var tube := _cylinder(stalk, Vector3.ZERO, 0.003, 0.01, _dark())
		tube.rotation_degrees = Vector3(90, 0, 0)
		var prong := Node3D.new()
		prong.name = "Prong_" + side
		prong.position = Vector3(0.096 * s, TEMPLE.y, TEMPLE.z)
		prong.rotation_degrees = Vector3(0, 0, 90.0 * s)
		root.add_child(prong)
		_cylinder(prong, Vector3(0, 0.014, 0), 0.004, 0.03, _lit())


static func _cuff(root: Node3D, wrist: Vector3) -> void:
	var at := wrist + Vector3(0.04, 0, 0)  # up her left forearm from the hand bone (her left is -X)
	var shell := Node3D.new()
	shell.name = "Shell"
	shell.position = at
	root.add_child(shell)
	var c := _cylinder(shell, Vector3.ZERO, 0.042, 0.05, _shell())
	c.rotation_degrees = Vector3(0, 0, 90)
	var r := _torus(shell, Vector3.ZERO, 0.041, 0.047, _lit())
	r.rotation_degrees = Vector3(0, 0, 90)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var needle := Node3D.new()
		needle.name = "Needle_%d" % i
		var out := Vector3(0, cos(a), sin(a))
		needle.position = at + out * 0.06
		needle.basis = Basis(Vector3(1, 0, 0), a + PI)  # +Y points in at her wrist
		root.add_child(needle)
		_cylinder(needle, Vector3(0, 0.015, 0), 0.0025, 0.03, _lit())


static func _shell() -> StandardMaterial3D:
	return _mat("shell", Color(0.93, 0.94, 0.97), 0.0)


static func _dark() -> StandardMaterial3D:
	return _mat("dark", Color(0.12, 0.13, 0.16), 0.0)


## Wet, faintly lit glass (the visor's eye cups).
static func _lens() -> StandardMaterial3D:
	if _mats.has("lens"):
		return _mats["lens"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.88, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 1.0
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = Color(0.5, 0.75, 1.0)
	m.emission_energy_multiplier = 0.6
	_mats["lens"] = m
	return m


static func _lit() -> StandardMaterial3D:
	return _mat("lit", Color(0.8, 0.94, 1.0), 2.0)


static func _mat(key: String, c: Color, glow: float) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _box(root: Node3D, at: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(root, b, at, m)


static func _cylinder(root: Node3D, at: Vector3, r: float, h: float, m: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	return _add(root, c, at, m)


static func _torus(root: Node3D, at: Vector3, inner: float, outer: float, m: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return _add(root, t, at, m)


static func _add(root: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	root.add_child(mi)
	return mi
