extends SkeletonModifier3D
## The Rig's mods on Eco (redline.gd), on her own skeleton so they move with
## her: a modifier that runs after her animation every frame and reshapes the
## bones, plus the parts she didn't have before, hung on her bones like the
## Shepherd's gear (colony_gear.gd _root):
##   wiring        red veins up her arms and the sides of her neck, glowing with
##                 each heartbeat (faster while she's high)
##   heavy         her whole skeleton a size up, evenly (HEAVY each way)
##   compact       her whole skeleton a size down, evenly (COMPACT)
##   legs          her shins lengthened (SHIN), her skeleton lifted so her feet
##                 still meet the floor
##   core          her spine and head held at rest, straight and level
##   long_arms     her forearms lengthened (FOREARM)
##   cat_ears      cat's ears up through her hair, turning now and then
##   pointed_ears  long pointed ears out from her own
##   tail          a thin red tail from the base of her spine, swaying
##   red_eyes      red irises; night_eyes amber ones with slit pupils
##   spurs         red-tipped bone spurs along the backs of her forearms
##   vents         thin glowing slits down the sides of her neck, breathing
##   freckles      red lights in the skin of her cheeks and shoulders, and a
##                 soft red light round her
##   horns         small swept-back red horns
##   scales        red scales over her forearms and shins
##   wings         small leathery wings on her shoulder blades, spread while
##                 she glides (glide())
## Nothing here touches her chest, hips or thighs. On the copy in her gun's
## first-person arms her arms and size are left alone, so she still holds it.
## apply() puts them on (or updates them on) a model of her.

const Redline := preload("res://scripts/hub/redline.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")

const NODE := "RedlineBody"
const HEAVY := 1.05
const COMPACT := 0.92
const SHIN := 1.3
const FOREARM := 1.3
const VEIN := Color(0.95, 0.08, 0.06)
const VEIN_R := 0.0026
const RED := Color(0.62, 0.06, 0.08)
const BONE := Color(0.9, 0.86, 0.78)
const SKIN := Color(0.96, 0.82, 0.76)
const EAR_FUR := Color(0.13, 0.07, 0.08)
const EAR_PINK := Color(0.95, 0.55, 0.58)
const AMBER := Color(1.0, 0.68, 0.12)
const SPINE := ["J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck", "J_Bip_C_Head"]
const TAIL_BASE := Vector3(-72, 0, 0)
const TAIL_CURL := Vector3(-11, 0, 0)
const TAIL_SEGMENTS := 12
## Her cheeks and the tops of her shoulders (her right; her left mirrors), in
## rest model space, where the glow freckles go.
const CHEEK := Vector3(0.042, 1.506, -0.06)
const SHOULDER := Vector3(0.14, 1.37, -0.01)

## The mods this model shows (a copy of Redline.mods when applied).
var shown: Array = []
## The copy in her gun's first-person arms: hands, arms and size stay as they are.
var gun_arms := false
var _t := 0.0
var _base_y := NAN
var _veins: StandardMaterial3D
var _glow: StandardMaterial3D
var _vent_mat: StandardMaterial3D
var _light: OmniLight3D
var _beat := 0.0
var _ears: Array = []
var _tail: Array = []
var _wings: Array = []
var _spread := 0.0
var _twitch := 0.0
var _twitch_at := 2.0
## How many times it's reshaped her, and what it last set (bone: scale or
## length factor; for the tests: Godot only keeps a modifier's pose for the frame).
var runs := 0
var last := {}


## Puts the mods on `model` (an eco_model.gd), or takes them off if there are
## none. Called from her apply_suit().
static func apply(model: Node) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(NODE):
			if child is SkeletonModifier3D:
				# her skeleton back to her own size and height
				skel.scale = Vector3.ONE
				if not is_nan(child.get("_base_y")):
					skel.position.y = child.get("_base_y")
			skel.remove_child(child)
			child.free()
	_irises(model, Color(0, 0, 0, 0))
	if not Redline.allowed() or Redline.mods.is_empty():
		return
	var mod: SkeletonModifier3D = load("res://scripts/hub/redline_body.gd").new()
	mod.name = NODE
	mod.shown = Redline.mods.duplicate()
	var p := model.get_parent()
	while p != null:
		if String(p.name) == "Weapon":
			mod.gun_arms = true
			break
		p = p.get_parent()
	skel.add_child(mod)
	mod.active = true
	mod._build(model, skel)


## The Rig's mod on the model (for a renders and the Rig's preview): `mods` instead of hers.
static func apply_mods(model: Node, mods: Array) -> void:
	var was: Array = Redline.mods
	Redline.mods = mods
	apply(model)
	Redline.mods = was


func _build(model: Node, skel: Skeleton3D) -> void:
	var body := ColonyGear._surface(model, skel)
	if "wiring" in shown:
		_wire(model, skel, body)
	if skel.find_bone(ColonyGear.HEAD) >= 0:
		var head := ColonyGear._root(skel, ColonyGear.HEAD, NODE + "_Head")
		if "cat_ears" in shown:
			for s in [-1.0, 1.0]:
				_ears.append(_cat_ear(head, s))
		if "pointed_ears" in shown:
			for s in [-1.0, 1.0]:
				_pointed_ear(head, s)
		if "horns" in shown:
			for s in [-1.0, 1.0]:
				_horn(head, s)
		if "night_eyes" in shown:
			for s in [-1.0, 1.0]:
				_slit(head, s)
		if "freckles" in shown:
			_freckles_face(model, head)
		ColonyGear._match_layers(model, head, "Face")
	if "red_eyes" in shown:
		_irises(model, Color(0.95, 0.08, 0.06))
	elif "night_eyes" in shown:
		_irises(model, AMBER)
	if "tail" in shown and skel.find_bone("J_Bip_C_Hips") >= 0:
		_tail_on(model, skel)
	if not gun_arms:
		if "spurs" in shown:
			_spurs(model, skel, body)
		if "scales" in shown:
			_scales(model, skel, body)
	if "vents" in shown:
		_vents(model, skel, body)
	if "freckles" in shown:
		_freckles_body(model, skel, body)
	if "wings" in shown and not gun_arms and skel.find_bone("J_Bip_C_UpperChest") >= 0:
		_wings_on(model, skel, body)


func _rest(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(bone)).origin


static func _mat(c: Color, glow := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## Her irises in `c` (alpha 0: back to what they were).
static func _irises(model: Node, c: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i)
			if base == null or base.resource_name != "eco_v_iris":
				continue
			var key := "redline_iris_%d" % i
			if c.a <= 0.0:
				if m3.has_meta(key):
					m3.set_surface_override_material(i, m3.get_meta(key))
					m3.remove_meta(key)
				continue
			if not m3.has_meta(key):
				m3.set_meta(key, m3.get_surface_override_material(i))
			var from: Material = m3.get_meta(key) if m3.get_meta(key) != null else base
			if from is ShaderMaterial:
				var d: ShaderMaterial = from.duplicate()
				d.set_shader_parameter("albedo", c)
				d.set_shader_parameter("emission", c)
				d.set_shader_parameter("emission_energy", 0.5)
				m3.set_surface_override_material(i, d)


## Veins up each arm and the sides of her neck: thin red lines just over her
## skin, wandering a little, each on the bone it runs along.
func _wire(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	_veins = _mat(VEIN, 0.6)
	var runs_: Array = []  # [bone, from, to, angles round it]
	for side in ["L", "R"]:
		var up := "J_Bip_%s_UpperArm" % side
		var low := "J_Bip_%s_LowerArm" % side
		var hand := "J_Bip_%s_Hand" % side
		if [up, low, hand].any(func(b): return skel.find_bone(b) < 0):
			continue
		runs_.append([low, _rest(skel, hand), _rest(skel, low), [-0.3, 0.6, 2.4]])  # wrist to elbow
		runs_.append([up, _rest(skel, low), _rest(skel, up).lerp(_rest(skel, low), 0.25), [0.2, 2.0]])  # elbow up the arm
	if skel.find_bone("J_Bip_C_Neck") >= 0 and skel.find_bone(ColonyGear.HEAD) >= 0:
		runs_.append(["J_Bip_C_Neck", _rest(skel, "J_Bip_C_Neck") - Vector3(0, 0.02, 0), _rest(skel, ColonyGear.HEAD) - Vector3(0, 0.015, 0), [1.25, -1.25]])
	for run in runs_:
		var root := ColonyGear._root(skel, run[0], NODE + "_Veins_" + String(run[0]))
		var a: Vector3 = run[1]
		var b: Vector3 = run[2]
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.UP).normalized()
		var other := axis.cross(side).normalized()
		for ang in run[3]:
			var pts: Array = []
			for i in 6:
				var k := float(i) / 5.0
				var at := a.lerp(b, k)
				var g := ColonyGear._girth(body, at, axis, 0.012, 0.07)
				var mid: Vector3 = g[0] if g.size() == 2 else at
				var r: float = (float(g[1]) if g.size() == 2 else 0.03) + 0.0012
				var wob := float(ang) + 0.18 * sin(k * 7.0 + float(ang) * 3.0)
				pts.append(mid + (side * cos(wob) + other * sin(wob)) * r)
			for i in pts.size() - 1:
				ColonyGear._line(root, pts[i], pts[i + 1], VEIN_R, _veins, VEIN_R * 0.8)
		ColonyGear._match_layers(model, root, "Body")


## A cat's ear on top of her head, side `s`, facing forward: its pivot at the base.
func _cat_ear(head: Node3D, s: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.056 * s, 1.638, 0.004)
	pivot.rotation_degrees = Vector3(-6, 0, -16 * s)
	head.add_child(pivot)
	var outer := _cone(pivot, Vector3(0, 0.038, 0), 0.036, 0.003, 0.078, _mat(EAR_FUR, 0.0, 0.9))
	outer.scale = Vector3(1.0, 1.0, 0.5)
	var inner := _cone(pivot, Vector3(0, 0.032, -0.009), 0.024, 0.002, 0.058, _mat(EAR_PINK, 0.0, 0.8))
	inner.scale = Vector3(1.0, 1.0, 0.25)
	return pivot


## A long pointed ear out from her own, side `s`.
func _pointed_ear(head: Node3D, s: float) -> void:
	var base := ColonyGear.EAR * Vector3(s, 1, 1) + Vector3(0.004 * s, 0.006, 0.004)
	var dir := Vector3(0.62 * s, 0.5, 0.5).normalized()
	var ear := ColonyGear._line(head, base, base + dir * 0.075, 0.016, _mat(SKIN, 0.0, 0.85), 0.0015)
	ear.scale = Vector3(1.0, 1.0, 0.35)  # flat, like an ear, not a horn


## A small swept-back horn up through her hair, side `s`: four tapering
## segments curling back.
func _horn(head: Node3D, s: float) -> void:
	var at := Vector3(0.042 * s, 1.618, -0.04)
	var dir := Vector3(0.18 * s, 0.85, -0.2).normalized()
	var r := 0.0115
	var red := _mat(RED, 0.0, 0.4)
	var tip := _mat(Color(0.18, 0.03, 0.04), 0.0, 0.4)
	for i in 4:
		var nxt := at + dir * 0.026
		ColonyGear._line(head, at, nxt, r, tip if i == 3 else red, r * 0.72)
		ColonyGear._ball(head, nxt, r * 0.72, tip if i == 3 else red)
		at = nxt
		r *= 0.72
		dir = dir.rotated(Vector3.RIGHT * 1.0, deg_to_rad(28)).normalized()  # curling back over her head


## A slit pupil over her eye, side `s`.
func _slit(head: Node3D, s: float) -> void:
	var at := ColonyGear.EYE * Vector3(s, 1, 1) + Vector3(0.0105 * s, -0.014, -0.009)  # the middle of her iris
	var slit := ColonyGear._ball(head, at, 0.0035, _mat(Color(0.01, 0.0, 0.0), 0.0, 0.3))
	slit.scale = Vector3(0.3, 1.25, 0.25)


## Glow freckles on her cheeks: little red lights in a scatter.
func _freckles_face(model: Node, head: Node3D) -> void:
	_glow = _mat(Color(1.0, 0.18, 0.12), 2.2)
	var face := _mesh_points(model, "Face")
	var spots := [Vector2(0.0, 0.0), Vector2(0.009, 0.004), Vector2(-0.008, 0.006), Vector2(0.004, -0.007), Vector2(0.014, -0.004), Vector2(-0.004, 0.012)]
	for s in [-1.0, 1.0]:
		for d: Vector2 in spots:
			var want := CHEEK * Vector3(s, 1, 1) + Vector3(d.x * s, d.y, 0)
			var at := _nearest(face, want, 0.03) if not face.is_empty() else want
			ColonyGear._ball(head, at + Vector3(0, 0, -0.0028), 0.0024, _glow)


## Glow freckles on the tops of her shoulders, and the soft red light round her.
func _freckles_body(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	if _glow == null:
		_glow = _mat(Color(1.0, 0.18, 0.12), 2.2)
	for side in ["L", "R"]:
		var bone := "J_Bip_%s_UpperArm" % side
		if skel.find_bone(bone) < 0:
			continue
		var s := 1.0 if _rest(skel, bone).x > 0.0 else -1.0
		var root := ColonyGear._root(skel, bone, NODE + "_Freckles_" + side)
		for i in 9:
			var want := SHOULDER * Vector3(s, 1, 1) + Vector3((i % 3) * 0.014 * s - 0.01 * s, 0.02, (i / 3) * 0.016 - 0.016)
			var at := _nearest(body, want + Vector3(0, 0.05, 0), 0.08)
			ColonyGear._ball(root, at, 0.0022, _glow)
		ColonyGear._match_layers(model, root, "Body")
	if skel.find_bone("J_Bip_C_UpperChest") >= 0:
		var chest := ColonyGear._root(skel, "J_Bip_C_UpperChest", NODE + "_Glow")
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.25, 0.18)
		_light.light_energy = 0.12
		_light.omni_range = 2.4
		_light.shadow_enabled = false
		_light.position = Vector3(0, 0.9, -0.35)  # low and in front: a glow round her, not on her face
		chest.add_child(_light)


## Thin vents down each side of her neck: three slits, glowing, breathing.
func _vents(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	if skel.find_bone("J_Bip_C_Neck") < 0 or skel.find_bone(ColonyGear.HEAD) < 0:
		return
	_vent_mat = _mat(Color(1.0, 0.12, 0.08), 1.5)
	var root := ColonyGear._root(skel, "J_Bip_C_Neck", NODE + "_Vents")
	var a := _rest(skel, "J_Bip_C_Neck")
	var b := _rest(skel, ColonyGear.HEAD)
	var axis := (b - a).normalized()
	var dark := _mat(Color(0.25, 0.04, 0.05), 0.0, 0.6)
	for s in [-1.0, 1.0]:
		for i in 3:
			var at := a.lerp(b, 0.5 + i * 0.14)  # on the bare skin of her neck, above her collar
			var g := ColonyGear._girth(body, at, axis, 0.006, 0.07)
			var mid: Vector3 = g[0] if g.size() == 2 else at
			var r: float = (float(g[1]) if g.size() == 2 else 0.04) + 0.0006
			var out := Vector3(s * 0.9, 0, -0.45).normalized()  # her side, a little to the front
			var p := mid + out * r
			var along := Vector3(0, 1.0, -0.35).normalized() * 0.0075
			ColonyGear._line(root, p - along, p + along, 0.0013, dark)
			ColonyGear._line(root, p - along * 0.85 + out * 0.0006, p + along * 0.85 + out * 0.0006, 0.0009, _vent_mat)
	ColonyGear._match_layers(model, root, "Body")


## Bone spurs along the backs of her forearms, tipped red.
func _spurs(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	var bone_m := _mat(BONE, 0.0, 0.5)
	var tip_m := _mat(Color(0.85, 0.08, 0.06), 0.4, 0.4)
	for side in ["L", "R"]:
		var low := "J_Bip_%s_LowerArm" % side
		var hand := "J_Bip_%s_Hand" % side
		if skel.find_bone(low) < 0 or skel.find_bone(hand) < 0:
			continue
		var root := ColonyGear._root(skel, low, NODE + "_Spurs_" + side)
		var a := _rest(skel, low)
		var b := _rest(skel, hand)
		var axis := (b - a).normalized()
		for i in 3:
			var at := a.lerp(b, 0.3 + i * 0.22)
			var g := ColonyGear._girth(body, at, axis, 0.01, 0.06)
			var mid: Vector3 = g[0] if g.size() == 2 else at
			var r: float = float(g[1]) if g.size() == 2 else 0.03
			var base := mid + Vector3.UP * r * 0.9  # the back of her forearm
			var tip := base + Vector3.UP * (0.03 - i * 0.004) - axis * 0.022
			ColonyGear._line(root, base, base.lerp(tip, 0.65), 0.0065, bone_m, 0.0035)
			ColonyGear._line(root, base.lerp(tip, 0.65), tip, 0.0035, tip_m, 0.0004)
		ColonyGear._match_layers(model, root, "Body")


## Red scales over her forearms and shins: rows of small overlapping plates.
func _scales(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	var m := _mat(Color(0.7, 0.07, 0.08), 0.0, 0.35)
	m.metallic = 0.25
	var edge := _mat(Color(0.35, 0.03, 0.04), 0.0, 0.5)
	for side in ["L", "R"]:
		for limb in [["LowerArm", "Hand", 0.012, 6], ["LowerLeg", "Foot", 0.016, 8]]:
			var from := "J_Bip_%s_%s" % [side, limb[0]]
			var to := "J_Bip_%s_%s" % [side, limb[1]]
			if skel.find_bone(from) < 0 or skel.find_bone(to) < 0:
				continue
			var root := ColonyGear._root(skel, from, NODE + "_Scales_%s_%s" % [side, limb[0]])
			var a := _rest(skel, from)
			var b := _rest(skel, to)
			var axis := (b - a).normalized()
			var u := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.UP).normalized()
			var v := axis.cross(u).normalized()
			var rows: int = limb[3]
			var size: float = limb[2]
			for row in rows:
				var k := 0.12 + 0.76 * float(row) / float(rows - 1)
				var at := a.lerp(b, k)
				var g := ColonyGear._girth(body, at, axis, 0.01, 0.09)
				var mid: Vector3 = g[0] if g.size() == 2 else at
				var r: float = (float(g[1]) if g.size() == 2 else 0.04) + 0.0015
				for j in 9:
					var ang := TAU * (float(j) + 0.5 * (row % 2)) / 9.0
					var out := u * cos(ang) + v * sin(ang)
					var plate := MeshInstance3D.new()
					var c := CylinderMesh.new()
					c.top_radius = size * 0.8
					c.bottom_radius = size
					c.height = 0.0022
					c.radial_segments = 6
					c.rings = 1
					plate.mesh = c
					plate.material_override = m if (row + j) % 5 else edge
					plate.position = mid + out * r
					var tilt := (out + axis * 0.35).normalized()  # each overlapping the next down the limb
					plate.basis = Basis(Quaternion(Vector3.UP, tilt))
					root.add_child(plate)
			ColonyGear._match_layers(model, root, "Body")


## The tail: a chain of shrinking red segments from the base of her spine,
## each a pivot under the last so it can sway.
func _tail_on(model: Node, skel: Skeleton3D) -> void:
	var hips := ColonyGear._root(skel, "J_Bip_C_Hips", NODE + "_Tail")
	var at := _rest(skel, "J_Bip_C_Hips") + Vector3(0, 0.06, 0.1)  # the small of her back
	var parent: Node3D = hips
	var mat := _mat(RED, 0.0, 0.8)
	for i in TAIL_SEGMENTS:
		var seg := Node3D.new()
		seg.position = at if i == 0 else Vector3(0, -0.075, 0.0)
		seg.rotation_degrees = TAIL_BASE if i == 0 else TAIL_CURL
		parent.add_child(seg)
		var r := lerpf(0.024, 0.009, float(i) / TAIL_SEGMENTS)
		var mi := MeshInstance3D.new()
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(0.095, r * 2.0)
		mi.mesh = c
		mi.material_override = mat
		mi.position = Vector3(0, -0.0375, 0)
		seg.add_child(mi)
		_tail.append(seg)
		parent = seg
	ColonyGear._match_layers(model, hips, "Body")


## Two small leathery wings on her shoulder blades: a bony leading edge, two
## fingers, and the skin between, folded back; they spread when she glides.
func _wings_on(model: Node, skel: Skeleton3D, body: PackedVector3Array) -> void:
	var root := ColonyGear._root(skel, "J_Bip_C_UpperChest", NODE + "_Wings")
	var y := 1.31
	var back := ColonyGear._back_at(body, y)
	if is_nan(back):
		back = 0.09
	var skin := _mat(Color(0.42, 0.05, 0.07), 0.0, 0.75)
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bone_m := _mat(Color(0.25, 0.03, 0.04), 0.0, 0.5)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.065 * s, y, back + 0.012)
		root.add_child(pivot)
		var wing := Node3D.new()
		pivot.add_child(wing)
		# in the wing's own plane: x out from her spine, y up
		var outline := [Vector2(0, 0), Vector2(0.05, 0.13), Vector2(0.2, 0.1), Vector2(0.17, 0.02), Vector2(0.22, -0.04), Vector2(0.12, -0.03), Vector2(0.1, -0.09), Vector2(0.03, -0.05)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1, outline.size() - 1):
			for p: Vector2 in [outline[0], outline[i], outline[i + 1]]:
				st.set_normal(Vector3(0, 0, 1))
				st.add_vertex(Vector3(p.x * s, p.y, 0))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = skin
		wing.add_child(mi)
		for f in [[Vector2(0, 0), Vector2(0.05, 0.13)], [Vector2(0.05, 0.13), Vector2(0.2, 0.1)], [Vector2(0.05, 0.13), Vector2(0.22, -0.04)], [Vector2(0.05, 0.13), Vector2(0.1, -0.09)]]:
			var a: Vector2 = f[0]
			var b: Vector2 = f[1]
			ColonyGear._line(wing, Vector3(a.x * s, a.y, 0.001), Vector3(b.x * s, b.y, 0.001), 0.004, bone_m, 0.0022)
		_wings.append([pivot, s])
	ColonyGear._match_layers(model, root, "Body")
	_fold(0.0)


## The wings folded back against her (0) or spread for a glide (1).
func _fold(k: float) -> void:
	for w in _wings:
		var pivot: Node3D = w[0]
		var s: float = w[1]
		if is_instance_valid(pivot):
			pivot.rotation_degrees = Vector3(lerpf(-8.0, 10.0, k), lerpf(-62.0, -8.0, k) * s, lerpf(-20.0, 0.0, k) * s)


## Spreads her wings (while she glides) or folds them.
func glide(on: bool) -> void:
	_spread = 1.0 if on else 0.0


func _cone(parent: Node3D, at: Vector3, r_base: float, r_tip: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r_base
	c.top_radius = r_tip
	c.height = h
	c.radial_segments = 16
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


## A mesh's vertices at rest (in the model's space), e.g. her face's.
static func _mesh_points(model: Node, prefix: String) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for mi in model.find_children(prefix + "*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for sfc in m3.mesh.get_surface_count():
			for v in (m3.mesh.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(m3.transform * v)
		break
	return pts


## The point of `pts` nearest `want`, within `reach` (else `want`). Prefers
## the front-most where several are close (her skin, not what's inside).
static func _nearest(pts: PackedVector3Array, want: Vector3, reach: float) -> Vector3:
	var best := want
	var best_d := reach
	for p in pts:
		var d := p.distance_to(want)
		if d < best_d:
			best_d = d
			best = p
	return best


func _process_modification_with_delta(delta: float) -> void:
	_modify(delta)


func _process_modification() -> void:
	_modify(1.0 / maxf(Engine.get_frames_per_second(), 30.0))


func _modify(delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	runs += 1
	_t += delta
	if is_nan(_base_y):
		_base_y = skel.position.y
	var size := 1.0
	if not gun_arms:
		size = HEAVY if "heavy" in shown else (COMPACT if "compact" in shown else 1.0)
	skel.scale = Vector3.ONE * size
	last["skeleton:scale"] = size
	var lift := 0.0
	if "legs" in shown:
		for side in ["L", "R"]:
			var i := _stretch(skel, "J_Bip_%s_Foot" % side, SHIN)
			if i >= 0:
				lift = skel.get_bone_rest(i).origin.length() * (SHIN - 1.0) * size
	skel.position.y = _base_y + lift
	if "long_arms" in shown and not gun_arms:
		for side in ["L", "R"]:
			_stretch(skel, "J_Bip_%s_Hand" % side, FOREARM)
	if "core" in shown:
		for b in SPINE:
			var i := skel.find_bone(b)
			if i >= 0:
				skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion())
		last["core"] = true
	_animate(delta)


## The segment that ends at bone `name` (its offset from its parent), k times
## as long. Returns the bone's index (-1 if there's none).
func _stretch(skel: Skeleton3D, bone: String, k: float) -> int:
	var i := skel.find_bone(bone)
	if i >= 0:
		skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin * k)
		last[bone + ":length"] = k
	return i


## Veins and vents with her heart, ears twitching, the tail swaying, the wings
## spreading or folding, the freckles' light breathing.
func _animate(delta: float) -> void:
	var period := 0.55 if Redline.high() else 1.1
	_beat = fmod(_beat + delta, period)
	var k := exp(-_beat * 7.0)
	if _veins != null:
		_veins.emission_energy_multiplier = 1.0 + 2.6 * k
	if _vent_mat != null:
		_vent_mat.emission_energy_multiplier = 0.8 + 1.4 * (0.5 + 0.5 * sin(_t * 2.4))
	if _light != null:
		_light.light_energy = 0.1 + 0.04 * sin(_t * 1.3)
	if not _ears.is_empty():
		if _t >= _twitch_at:
			_twitch = 1.0
			_twitch_at = _t + randf_range(1.5, 4.0)
		_twitch = maxf(_twitch - 0.08, 0.0)
		for i in _ears.size():
			var ear: Node3D = _ears[i]
			if is_instance_valid(ear):
				var s := -1.0 if i == 0 else 1.0
				ear.rotation_degrees = Vector3(-6 - 10 * _twitch * sin(_t * 40.0), 12 * _twitch * s, -16 * s)
	for i in _tail.size():
		var seg: Node3D = _tail[i]
		if is_instance_valid(seg):
			var base := TAIL_BASE if i == 0 else TAIL_CURL
			seg.rotation_degrees = base + Vector3(0, 0, 9.0 * sin(_t * 1.7 - i * 0.5))
	if not _wings.is_empty():
		var now: float = _wings[0][0].get_meta("k", 0.0)
		now = move_toward(now, _spread, delta * 4.0)
		_wings[0][0].set_meta("k", now)
		_fold(now)
		last["wings"] = now
