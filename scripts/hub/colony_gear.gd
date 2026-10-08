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
##   bridge      the calm bridge: a white clip over the bridge of her nose, a
##               tube up into each nostril, a glowing vial behind each ear
##   gloves      comfort gloves: seamless white to the shoulder, lines of light
##               down to every finger
##   band        the Processed tracker band: a heavy grey prison band round her
##               throat, bolts at the back, a small speaker grille under her chin
##               and a light beside it that blinks (the same band on everyone
##               processed)
##   crown       the Crown: a white circlet round her head with four lit nodes,
##               the piece that ties all the others together
##   spine       the Plumb Line: a white and chrome spine down her back from
##               just below her neck, a glowing node on each segment, cables
##               into her shoulders
## Each piece sits under a node named for it, and its moving parts are named
## too (Cup_L/R, Pin_L/R, Shell, Needle_N, EyeCup_L/R, Stalk_L/R, Prong_L/R), so the fitting in the
## dispensary's back room (fitting_scene.gd) can play them going on: open()
## puts a piece in its open, unfitted pose, fit() moves it along (0..1).

const Hymn := preload("res://scripts/hub/hymn.gd")

const HEAD := "J_Bip_C_Head"
const WRIST := "J_Bip_L_Hand"
const NODE := "ColonyGear"
const NECK := "J_Bip_C_Neck"
## Her ears and temples in rest model space.
const EAR := Vector3(0.072, 1.522, 0.012)
## Her nostrils (her right; her left mirrors it) and the bridge of her nose.
const NOSTRIL := Vector3(0.009, 1.481, -0.07)
const NOSE_BRIDGE := Vector3(0, 1.515, -0.071)
## Her spine below the neck, top to bottom, and the bones its segments ride.
const SPINE_BONES := ["J_Bip_C_UpperChest", "J_Bip_C_Chest", "J_Bip_C_Spine", "J_Bip_C_Hips"]
const SEGMENTS := 9
const TEMPLE := Vector3(0.07, 1.555, -0.035)
## Her right eye (her left mirrors it), the visor's inside face, and how far in
## front of her face it waits while the suction cups go on.
const EYE := Vector3(0.032, 1.532, -0.064)
const VISOR_INNER := -0.0825
const VISOR_HOVER := -0.075
## The modelled gear (tools/hub/build_colony_gear.py); without it the pieces are built from primitives.
const MODELS := "res://assets/models/colony_gear/colony_gear.glb"

static var _mats := {}
static var _parts := {}
static var _parts_loaded := false
static var _surfaces := {}
## False builds every piece from primitives (the render tools' before shots).
static var use_models := true


static func apply(model: Node, p_gear = null) -> void:
	if model == null:
		return
	# no list: Eco's own; someone else's (hub_grip.gd) may be empty
	var gear: Array = Hymn.gear if p_gear == null else p_gear
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone(HEAD) < 0:
		return
	for child in skel.get_children():
		if String(child.name).begins_with(NODE):
			skel.remove_child(child)
			child.free()
	if not Hymn.allowed():
		return
	if "headphones" in gear or "visor" in gear or "crown" in gear:
		var head := _root(skel, HEAD, NODE)
		if "headphones" in gear:
			_headphones(_piece(head, "headphones"))
		if "visor" in gear:
			_visor(_piece(head, "visor"))
		if "crown" in gear:
			_crown(_piece(head, "crown"))
			for g in model.find_children("Goggles*", "MeshInstance3D", true, false):
				g.visible = false  # the Crown sits where her goggles do
		_match_layers(model, head, "Face")
	if "bridge" in gear:
		var face := _root(skel, HEAD, NODE + "_Face")
		_bridge(_piece(face, "bridge"))
		_match_layers(model, face, "Face")
	if "gloves" in gear:
		_gloves(model, skel)
	if "spine" in gear and skel.find_bone(SPINE_BONES[0]) >= 0:
		_spine(model, skel)
	if "band" in gear and skel.find_bone(NECK) >= 0:
		var neck := _root(skel, NECK, NODE + "_Band")
		_band(_piece(neck, "band"), skel.get_bone_global_rest(skel.find_bone(NECK)).origin, _surface(model, skel))
		_match_layers(model, neck, "Body")
	if "cuff" in gear and skel.find_bone(WRIST) >= 0:
		var wrist := _root(skel, WRIST, NODE + "_Cuff")
		_cuff(_piece(wrist, "cuff"), skel.get_bone_global_rest(skel.find_bone(WRIST)).origin, _surface(model, skel), "gloves" in gear)
		_match_layers(model, wrist, "Body")


## The piece's node on a model (null if it isn't wearing it).
static func piece_node(model: Node, piece: String) -> Node3D:
	return model.find_child(piece, true, false) as Node3D


## Fits piece on model to k (0..1): the gloves and the spine are spread
## over several bones, so they're found on the model; the rest by piece_node().
##   gloves      the hands first, then up the forearms, then to the shoulders
##   spine       segment by segment from below her neck down
static func fit_model(model: Node, piece: String, k: float) -> void:
	match piece:
		"gloves":
			for side in ["L", "R"]:
				for part in [["Hand", 0.0], ["Fore", 0.3], ["Upper", 0.6]]:
					var n := model.find_child(part[0] + side, true, false) as Node3D
					if n != null:
						n.scale = Vector3.ONE * maxf(smoothstep(part[1], part[1] + 0.3, k), 0.01)
		"spine":
			for i in SEGMENTS:
				var n := model.find_child("Seg_%d" % i, true, false) as Node3D
				if n != null:
					var at := float(i) / float(SEGMENTS) * 0.8
					n.scale = Vector3.ONE * maxf(smoothstep(at, at + 0.15, k), 0.01)
		_:
			fit(piece_node(model, piece), piece, k)


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
		"crown":
			# it comes down onto her head, then its nodes light one by one
			node.position = Vector3(0, 0.3 * (1.0 - smoothstep(0.0, 0.55, k)), 0)
			for i in 4:
				var dot := node.get_node_or_null("Node_%d" % i) as Node3D
				if dot != null:
					dot.scale = Vector3.ONE * maxf(smoothstep(0.55 + i * 0.1, 0.65 + i * 0.1, k), 0.01)
		"band":
			# it closes round her throat, the bolts drive home, then the speaker
			# and its light come on
			var band := node.get_node_or_null("Band") as Node3D
			if band != null:
				band.scale = Vector3.ONE * lerpf(1.6, 1.0, smoothstep(0.0, 0.5, k))
			for n in node.get_children():
				if String(n.name).begins_with("Bolt_"):
					(n as Node3D).scale = Vector3(maxf(smoothstep(0.5, 0.7, k), 0.01), 1, 1)
			for part in ["Speaker", "Light"]:
				var n := node.get_node_or_null(part) as Node3D
				if n != null:
					n.scale = Vector3.ONE * maxf(smoothstep(0.7, 0.85, k), 0.01)
		"bridge":
			node.position = Vector3(0, 0.25 * (1.0 - smoothstep(0.0, 0.35, k)), 0)
			for side in ["L", "R"]:
				var tube := node.get_node_or_null("Tube_" + side) as Node3D
				if tube != null:
					tube.scale = Vector3(1, maxf(smoothstep(0.35, 0.85, k), 0.01), 1)
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


## Same render layers and shadow casting as her own meshes, so on her
## first-person copies (eco_fp_body.gd: "Shadow" casts only shadows) the gear
## doesn't float in front of the camera.
static func _match_layers(model: Node, root: Node3D, mesh_name: String) -> void:
	var own := model.find_child(mesh_name, true, false) as MeshInstance3D
	if own == null:
		own = model.find_child("Body", true, false) as MeshInstance3D
	if own != null:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			mi.layers = own.layers
			mi.cast_shadow = own.cast_shadow


static func _headphones(root: Node3D) -> void:
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var cup := Node3D.new()
		cup.name = "Cup_" + side
		root.add_child(cup)
		if not _model(cup, "hp_cup_" + side):
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
		if not _model(pin, "pin"):
			_cylinder(pin, Vector3(0, 0.022, 0), 0.006, 0.044, _lit())
			_cylinder(pin, Vector3(0, 0.002, 0), 0.011, 0.008, _shell())
	if not _model(root, "hp_band"):
		for i in 9:
			var a := PI * (i + 0.5) / 9.0
			var seg := _box(root, Vector3(cos(a) * 0.098, 1.515 + sin(a) * 0.125, 0.012), Vector3(0.05, 0.016, 0.03), _dark())
			seg.rotation_degrees = Vector3(0, 0, rad_to_deg(a) + 90.0)


static func _visor(root: Node3D) -> void:
	if not _model(root, "visor_body"):
		_box(root, Vector3(0, 1.535, -0.085), Vector3(0.175, 0.075, 0.075), _shell())
		_box(root, Vector3(0, 1.535, -0.124), Vector3(0.15, 0.022, 0.004), _lit())
		for s in [-1.0, 1.0]:
			_box(root, Vector3(0.088 * s, 1.54, -0.01), Vector3(0.012, 0.03, 0.15), _dark())
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		# a glass suction cup for each eye, on a stalk from the visor's inside face
		var cup := Node3D.new()
		cup.name = "EyeCup_" + side
		cup.position = Vector3(EYE.x * s, EYE.y, EYE.z)
		root.add_child(cup)
		if not _model(cup, "eyecup"):
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
		if not _model(prong, "prong"):
			_cylinder(prong, Vector3(0, 0.014, 0), 0.004, 0.03, _lit())


static func _bridge(root: Node3D) -> void:
	if not _model(root, "bridge_clip"):
		_box(root, NOSE_BRIDGE + Vector3(0, 0, -0.004), Vector3(0.046, 0.012, 0.012), _shell())
	var vials := _model(root, "bridge_vial")
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		if not vials:
			var vial := _cylinder(root, Vector3(0.074 * s, 1.5, 0.045), 0.009, 0.03, _lit())
			vial.rotation_degrees = Vector3(90, 0, 0)
			# a line from the clip along her cheek to the vial
			_line(root, NOSE_BRIDGE + Vector3(0.022 * s, -0.004, 0.0), Vector3(0.074 * s, 1.5, 0.03), 0.0025, _shell())
		# the tube: down the side of her nose and up into the nostril
		var tube := Node3D.new()
		tube.name = "Tube_" + side
		tube.position = NOSE_BRIDGE + Vector3(0.02 * s, -0.004, 0.0)
		root.add_child(tube)
		var low := Vector3(0.016 * s, 1.47, -0.076) - tube.position
		var up := NOSTRIL * Vector3(s, 1, 1) - tube.position
		_line(tube, Vector3.ZERO, low, 0.0028, _lit())
		_line(tube, low, up, 0.0028, _lit())
		_ball(tube, low, 0.0028, _lit())  # round where it bends


## Seamless white to the shoulder over each arm, a line of light down each finger
## side, built on her arm bones (UpperArm to Hand), lit seams down to the hand,
## rounded over the shoulder, elbow, wrist and fingertips.
static func _gloves(model: Node, skel: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var bones := ["J_Bip_%s_UpperArm" % side, "J_Bip_%s_LowerArm" % side, "J_Bip_%s_Hand" % side]
		if bones.any(func(b): return skel.find_bone(b) < 0):
			continue
		var pts: Array = bones.map(func(b): return skel.get_bone_global_rest(skel.find_bone(b)).origin)
		var tip: Vector3 = pts[2] + (pts[2] - pts[1]).normalized() * 0.07
		var parts := [["Upper", 0, 0.048, 0.042], ["Fore", 1, 0.042, 0.034]]
		for part in parts:
			var root := _root(skel, bones[part[1]], NODE + "_Glove%s%s" % [part[0], side])
			var n := _piece(root, part[0] + side)
			# the piece sits at its near end, so it grows out from there in the fitting
			n.position = pts[part[1]]
			var b: Vector3 = pts[part[1] + 1] - n.position
			_line(n, Vector3.ZERO, b, float(part[2]), _shell(), float(part[3]))
			_ball(n, Vector3.ZERO, float(part[2]) * 1.01, _shell())  # the shoulder, the elbow
			_line(n, Vector3(0, 0, -float(part[2]) * 0.95), b + Vector3(0, 0, -float(part[3]) * 0.95), 0.003, _lit())
			_match_layers(model, root, "Body")
		var hroot := _root(skel, bones[2], NODE + "_GloveHand%s" % side)
		var h := _piece(hroot, "Hand" + side)
		h.position = pts[2]
		_line(h, Vector3.ZERO, tip - pts[2], 0.034, _shell(), 0.026)
		_ball(h, Vector3.ZERO, 0.0345, _shell())  # the wrist
		_ball(h, tip - pts[2], 0.026, _shell())  # the fingertips
		_line(h, Vector3(0, 0, -0.03), tip - pts[2] + Vector3(0, 0, -0.022), 0.0025, _lit())
		_match_layers(model, hroot, "Body")


## The Plumb Line: segments down her back from her neck to her hips, each on the
## nearest spine bone, with a glowing node and short cables out to the sides.
static func _spine(model: Node, skel: Skeleton3D) -> void:
	var body := _surface(model, skel)
	var top := skel.get_bone_global_rest(skel.find_bone(SPINE_BONES[0])).origin
	var bottom := skel.get_bone_global_rest(skel.find_bone(SPINE_BONES[SPINE_BONES.size() - 1])).origin
	var roots := {}
	for i in SEGMENTS:
		var t := float(i) / float(SEGMENTS - 1)
		var at := top.lerp(bottom, t)
		# flush on her back, tipped to follow its curve: her own surface there,
		# else a guess (out on her back, further at the shoulder blades)
		var tilt := 0.0
		var back := _back_at(body, at.y)
		if not is_nan(back):
			var up := _back_at(body, at.y + 0.02)
			var down := _back_at(body, at.y - 0.02)
			if not is_nan(up) and not is_nan(down):
				tilt = atan2(up - down, 0.04)  # leaning out going up: the plate tips back
			at.z = back
		else:
			at.z += 0.075 + 0.035 * sin(t * PI)
		var last := SPINE_BONES.size() - 1
		var bone: String = SPINE_BONES[clampi(roundi(t * last), 0, last)]
		if not roots.has(bone):
			roots[bone] = _root(skel, bone, NODE + "_Spine_" + bone)
		var seg := Node3D.new()
		seg.name = "Seg_%d" % i
		seg.position = at
		seg.rotation.x = tilt
		(roots[bone] as Node3D).add_child(seg)
		var plate := Node3D.new()
		plate.scale = Vector3((0.05 - 0.01 * t) / 0.05, 1, 1)
		seg.add_child(plate)
		if not _model(plate, "spine_seg"):
			_box(seg, Vector3.ZERO, Vector3(0.05 - 0.01 * t, 0.028, 0.026), _shell())
			_box(seg, Vector3(0, 0, 0.008), Vector3(0.018, 0.018, 0.018), _chrome())
			var node := _cylinder(seg, Vector3(0, 0, 0.018), 0.007, 0.006, _lit())
			node.rotation_degrees = Vector3(90, 0, 0)
		for s in [-1.0, 1.0]:
			_line(seg, Vector3(0.022 * s, 0, -0.004), Vector3(0.06 * s, 0.03, -0.03), 0.003, _chrome())
	for r in roots.values():
		_match_layers(model, r, "Body")


## The Processed tracker band: a heavy grey band round her throat, ridged top
## and bottom, a seam and two bolts at the back, a round speaker grille under
## her chin and a light beside it that blinks.
static func _band(root: Node3D, neck: Vector3, body: PackedVector3Array) -> void:
	var at := neck + Vector3(0, 0.035, 0)
	# snug on her neck: its middle and girth there (the model's inside is 0.052 across)
	var fit := _girth(body, at, Vector3.UP, 0.012, 0.09)
	var size := 1.0
	if fit.size() == 2:
		at = Vector3(fit[0].x, at.y, fit[0].z)
		size = clampf((float(fit[1]) + 0.004) / 0.052, 0.7, 1.4)
	var band := Node3D.new()
	band.name = "Band"
	band.position = at
	root.add_child(band)
	var snug := Node3D.new()
	snug.scale = Vector3(size, 1, size)
	band.add_child(snug)
	if not _model(snug, "band_body"):
		_cylinder(band, Vector3.ZERO, 0.057, 0.034, _steel())
		_torus(band, Vector3(0, 0.017, 0), 0.054, 0.06, _dark())
		_torus(band, Vector3(0, -0.017, 0), 0.054, 0.06, _dark())
	for s in [-1.0, 1.0]:
		var bolt := Node3D.new()
		bolt.name = "Bolt_%d" % (0 if s < 0 else 1)
		bolt.position = at + Vector3(0.012 * s, 0, 0.058 * size)
		root.add_child(bolt)
		if not _model(bolt, "band_bolt"):
			_box(bolt, Vector3.ZERO, Vector3(0.01, 0.02, 0.008), _chrome())
	var speaker := Node3D.new()
	speaker.name = "Speaker"
	speaker.position = at + Vector3(0.008, -0.002, -0.06 * size)
	root.add_child(speaker)
	if not _model(speaker, "band_speaker"):
		var grille := _cylinder(speaker, Vector3.ZERO, 0.011, 0.005, _dark())
		grille.rotation.x = PI * 0.5
		for i in 3:
			_box(speaker, Vector3(0, (i - 1) * 0.0045, -0.003), Vector3(0.014, 0.0012, 0.002), _chrome())
	var light := Node3D.new()
	light.name = "Light"
	light.position = at + Vector3(-0.016, 0.004, -0.06 * size)
	root.add_child(light)
	if not _model(light, "band_light"):
		_box(light, Vector3.ZERO, Vector3(0.007, 0.007, 0.004), _blink())


## The Crown: a white circlet round her head above the brow, a peak at the
## front, four lit nodes round it.
static func _crown(root: Node3D) -> void:
	var c := Vector3(0, 1.603, 0.004)
	if not _model(root, "crown_ring"):
		var ring := _torus(root, c, 0.108, 0.124, _shell())
		ring.rotation_degrees = Vector3(-8, 0, 0)
		_box(root, c + Vector3(0, 0.026, -0.118), Vector3(0.034, 0.05, 0.014), _shell())
	for i in 4:
		var a := TAU * i / 4.0
		var dot := Node3D.new()
		dot.name = "Node_%d" % i
		# round the ring, which tips forward 12 degrees
		dot.position = c + Vector3(sin(a) * 0.111, 0.002 - cos(a) * 0.023, -cos(a) * 0.111)
		root.add_child(dot)
		if not _model(dot, "crown_node"):
			var s := SphereMesh.new()
			s.radius = 0.008
			s.height = 0.016
			_add(dot, s, Vector3.ZERO, _lit())


static func _cuff(root: Node3D, wrist: Vector3, body: PackedVector3Array, gloved := false) -> void:
	var at := wrist + Vector3(0.04, 0, 0)  # up her left forearm from the hand bone (her left is -X)
	# snug on her wrist (the model's inside is 0.033 across; her arm lies along X at rest)
	var fit := _girth(body, at, Vector3.RIGHT, 0.012, 0.07)
	var size := 1.0
	if fit.size() == 2:
		at = Vector3(at.x, fit[0].y, fit[0].z)
		size = clampf((float(fit[1]) + 0.003) / 0.033, 0.6, 1.4)
	if gloved:  # over the glove there (_gloves: about 0.036 round her wrist)
		size = maxf(size, 0.04 / 0.033)
	var shell := Node3D.new()
	shell.name = "Shell"
	shell.position = at
	root.add_child(shell)
	var snug := Node3D.new()
	snug.scale = Vector3(1, size, size)
	shell.add_child(snug)
	if not _model(snug, "cuff_shell"):
		var c := _cylinder(shell, Vector3.ZERO, 0.042, 0.05, _shell())
		c.rotation_degrees = Vector3(0, 0, 90)
		var r := _torus(shell, Vector3.ZERO, 0.041, 0.047, _lit())
		r.rotation_degrees = Vector3(0, 0, 90)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var needle := Node3D.new()
		needle.name = "Needle_%d" % i
		var out := Vector3(0, cos(a), sin(a))
		needle.position = at + out * 0.06 * size
		needle.basis = Basis(Vector3(1, 0, 0), a + PI)  # +Y points in at her wrist
		root.add_child(needle)
		if not _model(needle, "needle"):
			_cylinder(needle, Vector3(0, 0.015, 0), 0.0025, 0.03, _lit())


## Her skin and clothes at rest (every mesh on her but her hair, face, goggles
## and boots), in rest model space, so pieces can sit snug on her: cached per
## set of meshes.
static func _surface(model: Node, skel: Skeleton3D) -> PackedVector3Array:
	var key := ""
	var parts: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if mi.mesh == null or not mi.visible or n.begins_with("Hair") or n.begins_with("Face") or n.begins_with("Goggles") or n.begins_with("Boots"):
			continue
		if mi.get_parent() != skel:
			continue  # gear and props hang off attachments, not the skeleton
		key += str(mi.mesh.get_rid().get_id()) + ","
		parts.append(mi)
	if _surfaces.has(key):
		return _surfaces[key]
	var pts := PackedVector3Array()
	for mi in parts:
		var xf: Transform3D = (mi as Node3D).transform
		for sfc in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(sfc)
			for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(xf * v)
	_surfaces[key] = pts
	return pts


## Round `axis` through `at`: the middle and outer radius of her surface within
## `half` of `at` along it and `reach` of the axis. [] if there's none.
static func _girth(pts: PackedVector3Array, at: Vector3, axis: Vector3, half: float, reach: float) -> Array:
	var near: Array = []
	var mid := Vector3.ZERO
	for p in pts:
		var d := p - at
		var along := d.dot(axis)
		if absf(along) > half:
			continue
		var across := d - axis * along
		if across.length() > reach:
			continue
		near.append(p - axis * along)
		mid += p - axis * along
	if near.size() < 12:
		return []
	mid /= near.size()
	var radii: Array = near.map(func(p): return (p - mid).length())
	radii.sort()
	return [mid, radii[int(radii.size() * 0.9)]]


## How far out her back is at height y (the most +Z of her surface near her
## spine there), or NAN.
static func _back_at(pts: PackedVector3Array, y: float) -> float:
	var best := NAN
	for p in pts:
		if absf(p.y - y) < 0.008 and absf(p.x) < 0.02 and (is_nan(best) or p.z > best):
			best = p.z
	return best


## The modelled parts (tools/hub/build_colony_gear.py): part name -> [[mesh,
## transform, material key], ...], read once from the glTF.
static func _load_parts() -> void:
	if _parts_loaded:
		return
	_parts_loaded = true
	var scene := load(MODELS) as PackedScene if ResourceLoader.exists(MODELS) else null
	if scene == null:
		return
	var inst := scene.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bits := String(mi.name).split("__")
		if bits.size() < 2:
			continue
		# the material key, without the number Blender or Godot put on a repeat
		var key := ""
		for ch in bits[1]:
			if ch < "a" or ch > "z":
				break
			key += ch
		if not _parts.has(bits[0]):
			_parts[bits[0]] = []
		_parts[bits[0]].append([(mi as MeshInstance3D).mesh, (mi as Node3D).transform, key])
	inst.free()


## Hangs the modelled `part`'s meshes on `root`, each in the game's material for
## its key. False if there's no such part (the primitives are built instead).
static func _model(root: Node3D, part: String) -> bool:
	_load_parts()
	if not use_models or not _parts.has(part):
		return false
	var mats := {"shell": _shell(), "dark": _dark(), "lit": _lit(), "chrome": _chrome(), "steel": _steel(), "lens": _lens(), "blink": _blink()}
	for p in _parts[part]:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[1]
		mi.material_override = mats.get(p[2], _shell())
		root.add_child(mi)
	return true


static func _ball(root: Node3D, at: Vector3, r: float, m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return _add(root, s, at, m)

## A tapered rod from  to  (radius r, to r2 at  if given).
static func _line(root: Node3D, a: Vector3, b: Vector3, r: float, m: Material, r2 := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r2 < 0.0 else r2
	c.height = maxf(a.distance_to(b), 0.0005)
	c.radial_segments = 24
	c.rings = 1
	var mi := _add(root, c, (a + b) * 0.5, m)
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		mi.basis = Basis(Vector3.RIGHT, PI)
	return mi


static func _chrome() -> StandardMaterial3D:
	if _mats.has("chrome"):
		return _mats["chrome"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.78, 0.82)
	m.metallic = 0.9
	m.roughness = 0.2
	_mats["chrome"] = m
	return m


static func _steel() -> StandardMaterial3D:
	var m := _mat("steel", Color(0.42, 0.45, 0.5), 0.0)
	m.metallic = 0.8
	m.roughness = 0.35
	return m


## The tracker band's light: red, blinking on its own (a short flash a second).
static func _blink() -> ShaderMaterial:
	if _mats.has("blink"):
		return _mats["blink"]
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() {\n\tfloat on = step(fract(TIME * 1.1), 0.18);\n\tALBEDO = mix(vec3(0.25, 0.02, 0.02), vec3(1.0, 0.12, 0.08) * 3.0, on);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	_mats["blink"] = m
	return m


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
