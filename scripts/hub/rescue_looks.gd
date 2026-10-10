extends RefCounted
## What going back to whoever had them does to Mom and Ophelia (rescue.gd):
## once one of them has walked to the same captor VISITS times
## (Rescue.visits), she dresses and talks like theirs until that captor's
## hold on her fades to nothing. Not Eco's hypno looks (vice_looks.gd): these
## are clothes on them, built round their own bodies.
##   marrow  a long dark coat lined violet, its sleeves down over her hands;
##           quiet, distant, defends him
##   colony  a white colony jumpsuit, hair pinned back; calm, polite, the
##           colony's phrases
##   cutter  an oversized grey hoodie with his red stripes, ripped jeans;
##           twitchy, fast, after Eco's scrap
## The clothes are shells: rings round each of her bones at rest (her own
## shape there, smoothed, and let out a little), joined into tubes and hung on
## that bone so they move with her (colony_gear.gd's _root). Built once per
## person and look and kept (_meshes).

const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const Hair := preload("res://scripts/hub/hair.gd")

const NODE := "RescueLook"
const SECTORS := 20
const SLICES := 4
## Their lines, while it lasts (Mom's and Ophelia's: %s is Eco's name for
## nobody; the lines are theirs as they are).
const LINES := {
	"marrow": {
		"mom": ["Mom, very quietly: \"He listens. You never sit still long enough.\"",
			"Mom: \"Don't look at me like that, sweetheart. I'm calmer than I've been since your father.\"",
			"Mom looks past Eco, at nothing. \"He said you could come and sit with us. Just sit.\"",
			"Mom: \"I'm fine. I'm finally fine. Why does that make you so angry?\""],
		"ophelia": ["Ophelia, quiet, not looking at her: \"He listens. You never sit still long enough.\"",
			"Ophelia: \"He's not what you think. He's the only one who doesn't want anything from me.\"",
			"Ophelia pulls the coat round herself. \"It's warm down there. It's quiet. You'd hate it.\"",
			"Ophelia: \"Stop. I know what you're going to say. Don't.\""],
	},
	"colony": {
		"mom": ["Mom, smiling, hands folded: \"Calm is a kindness, Eco.\"",
			"Mom: \"Have you taken your film today, sweetheart? It's for your own good. It's for everyone's.\"",
			"Mom: \"The line moves faster when everyone's polite. Remember that.\"",
			"Mom: \"Good morning, citizen. Oh. I mean, good morning, baby.\""],
		"ophelia": ["Ophelia, hair pinned back, smiling: \"Calm is a kindness, Eco.\"",
			"Ophelia: \"Compliance isn't the same as giving up. It's resting. You should rest.\"",
			"Ophelia: \"Good morning, citizen.\" A beat. \"Sorry. Habit. Good morning.\"",
			"Ophelia: \"Everyone's nicer in the white. Even me. Especially me.\""],
	},
	"cutter": {
		"mom": ["Mom, talking too fast: \"Eco! Eco, hi, have you got any scrap? Ten? Twenty? I'll pay you back, I swear.\"",
			"Mom, hands going: \"I'm good, I'm good, I'm so good, why are you looking at me like that?\"",
			"Mom: \"Cutter's not so bad, okay? He gets it. He gets me. You don't.\"",
			"Mom: \"Just spot me a little scrap, just till tomorrow, please, baby, please.\""],
		"ophelia": ["Ophelia, bouncing on her heels: \"Eco, Eco, you got scrap? Like ten? I'll pay you back, for real this time.\"",
			"Ophelia: \"I'm fine, I'm fine, I'm buzzing, it's good, it's so good, don't do the face.\"",
			"Ophelia: \"He was here first, you know? Before Marrow, before any of it. He gets me.\"",
			"Ophelia, picking at her sleeve: \"Twenty scrap. Fifteen. Ten. Come on. Come on.\""],
	},
}

static var _meshes := {}


## Dresses `npc` (a hub_npc.gd) in what `captor` has her in, or takes it off ("").
static func apply(npc: Node3D, who: String, captor: String) -> void:
	remove(npc)
	if captor == "":
		return
	var skel := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	npc.set_meta("rescue_look", captor)
	for mi in npc.find_children("Outfit_*", "MeshInstance3D", true, false):  # theirs under it would poke through
		if mi.visible:
			mi.visible = false
			mi.set_meta("rescue_hidden", true)
	var spec: Array = _spec(captor)
	for part in spec:
		var key := "%s/%s/%s" % [who, captor, part["name"]]
		if not _meshes.has(key):
			_meshes[key] = _build(npc, skel, part)
		var built: Array = _meshes[key]  # [[bone, mesh], ...]
		for b in built:
			var root := ColonyGear._root(skel, b[0], "%s_%s_%s" % [NODE, part["name"], b[0]])
			var mi := MeshInstance3D.new()
			mi.mesh = b[1]
			mi.material_override = part["mat"]
			root.add_child(mi)
			ColonyGear._match_layers(npc, root, "Body")
	_extras(npc, skel, who, captor)
	if captor == "colony" and who == "ophelia":
		Hair.apply(npc.get_node_or_null("Model") if npc.get_node_or_null("Model") != null else npc, who, "ponytail")


static func remove(npc: Node3D) -> void:
	var skel := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for c in skel.get_children():
		if String(c.name).begins_with(NODE):
			skel.remove_child(c)
			c.free()
	for mi in npc.find_children("Outfit_*", "MeshInstance3D", true, false):
		if mi.has_meta("rescue_hidden"):
			mi.visible = true
			mi.remove_meta("rescue_hidden")
	if npc.get_meta("rescue_look", "") == "colony":
		Hair.apply(npc.get_node_or_null("Model") if npc.get_node_or_null("Model") != null else npc, String(npc.get("who")))
	if npc.has_meta("rescue_look"):
		npc.remove_meta("rescue_look")


static func line(who: String, captor: String, n: int) -> String:
	var pool: Array = LINES.get(captor, {}).get(who, [])
	return pool[n % pool.size()] if not pool.is_empty() else ""


static func _mat(c: Color, rough := 0.85, sheen := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = sheen
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The garment's parts: chains of bones it runs along, how far it's let out
## from her, how far past the chain's end it runs, and its stuff.
static func _spec(captor: String) -> Array:
	match captor:
		"marrow":
			var coat := _mat(Color(0.09, 0.08, 0.11))
			return [
				{"name": "body", "chain": ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck"], "out": 0.024, "mat": coat, "smooth": 3},
				{"name": "sleeve_L", "chain": ["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", "J_Bip_L_Hand"], "out": 0.02, "past": 0.09, "flare": 1.35, "mat": coat, "smooth": 2},
				{"name": "sleeve_R", "chain": ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_R_Hand"], "out": 0.02, "past": 0.09, "flare": 1.35, "mat": coat, "smooth": 2},
			]
		"colony":
			var white := _mat(Color(0.93, 0.94, 0.96), 0.6)
			return [
				{"name": "body", "chain": ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck"], "out": 0.008, "mat": white, "smooth": 3},
				{"name": "sleeve_L", "chain": ["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", "J_Bip_L_Hand"], "out": 0.007, "mat": white, "smooth": 2},
				{"name": "sleeve_R", "chain": ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_R_Hand"], "out": 0.007, "mat": white, "smooth": 2},
				{"name": "hips", "out": 0.01, "drop": 0.16, "mat": white, "smooth": 3, "wide": true},
				{"name": "leg_L", "chain": ["J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", "J_Bip_L_Foot"], "out": 0.008, "mat": white, "smooth": 2},
				{"name": "leg_R", "chain": ["J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg", "J_Bip_R_Foot"], "out": 0.008, "mat": white, "smooth": 2},
			]
		"cutter":
			var grey := _mat(Color(0.42, 0.4, 0.43))
			var denim := _mat(Color(0.24, 0.3, 0.45))
			return [
				{"name": "body", "chain": ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_UpperChest", "J_Bip_C_Neck"], "out": 0.035, "mat": grey, "smooth": 4, "start": -0.08},
				{"name": "sleeve_L", "chain": ["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", "J_Bip_L_Hand"], "out": 0.03, "past": 0.02, "flare": 1.15, "mat": grey, "smooth": 3},
				{"name": "sleeve_R", "chain": ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_R_Hand"], "out": 0.03, "past": 0.02, "flare": 1.15, "mat": grey, "smooth": 3},
				{"name": "hips", "out": 0.014, "drop": 0.16, "mat": denim, "smooth": 3, "wide": true},
				{"name": "leg_L", "chain": ["J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", "J_Bip_L_Foot"], "out": 0.012, "mat": denim, "smooth": 2},
				{"name": "leg_R", "chain": ["J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg", "J_Bip_R_Foot"], "out": 0.012, "mat": denim, "smooth": 2},
			]
	return []


## The tubes for one part: [[bone, mesh], ...], a mesh per bone of the chain
## (rest model space, hung on that bone).
static func _build(npc: Node3D, skel: Skeleton3D, part: Dictionary) -> Array:
	var pts := ColonyGear._surface(npc, skel)
	var chain: Array = (part.get("chain", []) as Array).filter(func(b): return skel.find_bone(b) >= 0)
	var out: Array = []
	var torso: bool = part["name"] in ["body", "hips"]
	if part["name"] == "hips":  # from her waist down over the tops of her legs, both in one
		chain = ["J_Bip_C_Hips", "J_Bip_C_Hips"]
	for i in chain.size() - 1:
		var a := _rest(skel, chain[i])
		var b := _rest(skel, chain[i + 1])
		if part["name"] == "hips":
			var leg_y := _rest(skel, "J_Bip_L_UpperLeg").y if skel.find_bone("J_Bip_L_UpperLeg") >= 0 else a.y - 0.1
			a = Vector3(a.x, a.y + 0.06, a.z)
			b = Vector3(a.x, leg_y - float(part.get("drop", 0.1)), a.z + 0.0001)
		if i == 0 and part.has("start"):
			a += (a - b).normalized() * float(part["start"])
		var last := i == chain.size() - 2
		# overlapping the next and the last a little, so no gap opens as she bends
		var dir := (b - a).normalized()
		if part["name"] != "hips":
			if i > 0:
				a -= dir * 0.03
			if not last:
				b += dir * 0.03
		var reach := (0.25 if part.get("wide", false) else (0.14 if last else 0.17)) if torso else (0.14 if String(part["name"]).begins_with("leg") else 0.1)
		var flare := 1.0
		if last and part.has("past"):
			b += (b - a).normalized() * float(part["past"])
			flare = float(part.get("flare", 1.0))
		var rings: Array = []
		for s in SLICES + 1:
			var k := float(s) / SLICES
			var ring := _ring(pts, a.lerp(b, k), (b - a).normalized(), reach, 0.02 if torso else 0.012, int(part["smooth"]), signf(a.x) if String(part["name"]).begins_with("leg") else 0.0)
			var grow := lerpf(1.0, flare, k * k) if last else 1.0
			for j in ring[1].size():
				ring[1][j] = ring[1][j] * grow + float(part["out"])
			rings.append(ring)
		out.append([chain[i], _tube(rings)])
	return out


static func _rest(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(bone)).origin


## Her outline round `axis` at `at`: [frame, radii by sector] (frame: centre,
## u, v), the furthest of her surface in each sector of the slab there,
## smoothed `smooth` times so the cloth doesn't follow every dip.
static func _ring(pts: PackedVector3Array, at: Vector3, axis: Vector3, reach: float, slab: float, smooth: int, side := 0.0) -> Array:
	var u := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	var r := PackedFloat32Array()
	r.resize(SECTORS)
	var centre := Vector3.ZERO
	var n := 0
	for p in pts:
		if side != 0.0 and p.x * side < 0.004:  # a leg: only her own side of her
			continue
		var d := p - at
		var along := d.dot(axis)
		if absf(along) > slab:
			continue
		var across := d - axis * along
		if across.length() > reach:
			continue
		centre += across
		n += 1
	var mid := at + (centre / n if n > 0 else Vector3.ZERO)
	for p in pts:
		if side != 0.0 and p.x * side < 0.004:
			continue
		var d := p - mid
		var along := d.dot(axis)
		if absf(along) > slab:
			continue
		var across := d - axis * along
		var len := across.length()
		if len > reach:
			continue
		var ang := atan2(across.dot(v), across.dot(u))
		var i := int(floor((ang + PI) / TAU * SECTORS)) % SECTORS
		r[i] = maxf(r[i], len)
	# empty sectors take their neighbours'
	var best := 0.0
	for x in r:
		best = maxf(best, x)
	if best <= 0.0:
		best = 0.04
	for i in SECTORS:
		if r[i] <= 0.0:
			r[i] = best * 0.8
	var own := r.duplicate()
	for _pass in smooth:
		var s := PackedFloat32Array()
		s.resize(SECTORS)
		for i in SECTORS:
			s[i] = (r[(i + SECTORS - 1) % SECTORS] + r[i] * 2.0 + r[(i + 1) % SECTORS]) * 0.25
		r = s
	for i in SECTORS:  # smoothed out, never in: nothing of her pokes through
		r[i] = maxf(r[i], own[i])
	return [[mid, u, v], Array(r)]


static func _tube(rings: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array = []
	for ring in rings:
		var f: Array = ring[0]
		var row: Array = []
		for i in SECTORS:
			var ang := (float(i) + 0.5) / SECTORS * TAU - PI
			row.append(f[0] + (f[1] * cos(ang) + f[2] * sin(ang)) * float(ring[1][i]))
		verts.append(row)
	for s in verts.size() - 1:
		for i in SECTORS:
			var j := (i + 1) % SECTORS
			var a: Vector3 = verts[s][i]
			var b: Vector3 = verts[s][j]
			var c: Vector3 = verts[s + 1][i]
			var d: Vector3 = verts[s + 1][j]
			for p in [a, c, b, b, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## The bits that aren't tubes: the coat's skirt and collar, the jumpsuit's belt
## and seal, the hoodie's stripes and hood, the jeans' rips.
static func _extras(npc: Node3D, skel: Skeleton3D, who: String, captor: String) -> void:
	if skel.find_bone("J_Bip_C_Hips") < 0:
		return
	var hips := ColonyGear._root(skel, "J_Bip_C_Hips", NODE + "_Extras_Hips")
	var chest := ColonyGear._root(skel, "J_Bip_C_UpperChest", NODE + "_Extras_Chest") if skel.find_bone("J_Bip_C_UpperChest") >= 0 else hips
	var hip := _rest(skel, "J_Bip_C_Hips")
	var knee_y := _rest(skel, "J_Bip_L_LowerLeg").y if skel.find_bone("J_Bip_L_LowerLeg") >= 0 else hip.y * 0.5
	var neck := _rest(skel, "J_Bip_C_Neck") if skel.find_bone("J_Bip_C_Neck") >= 0 else hip + Vector3(0, 0.5, 0)
	match captor:
		"marrow":
			# the long skirt of the coat, from her hips to past her knees, open a little at the front
			var coat := _mat(Color(0.09, 0.08, 0.11))
			var lining := _mat(Color(0.42, 0.14, 0.62))
			var skirt := _cone(hips, hip + Vector3(0, 0.02, 0.0), 0.2, 0.31, hip.y + 0.02 - (knee_y - 0.16), coat)
			skirt.scale = Vector3(1.0, 1.0, 0.82)
			var inner := _cone(hips, hip + Vector3(0, 0.0, 0.0), 0.19, 0.3, hip.y - (knee_y - 0.15), lining)
			inner.scale = Vector3(0.97, 1.0, 0.8)
			# its high collar, lined violet
			var collar := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.06
			t.outer_radius = 0.085
			collar.mesh = t
			collar.material_override = lining
			collar.position = neck + Vector3(0, 0.03, 0.005)
			chest.add_child(collar)
		"colony":
			var grey := _mat(Color(0.5, 0.54, 0.6), 0.5, 0.3)
			var belt := MeshInstance3D.new()
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.135
			t2.outer_radius = 0.155
			belt.mesh = t2
			belt.material_override = grey
			belt.scale = Vector3(1.0, 0.6, 0.78)
			belt.position = hip + Vector3(0, 0.1, 0)
			hips.add_child(belt)
			var seal := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.022
			c.bottom_radius = 0.022
			c.height = 0.004
			seal.mesh = c
			var lit := _mat(Color(0.8, 0.92, 1.0))
			lit.emission_enabled = true
			lit.emission = Color(0.8, 0.92, 1.0)
			lit.emission_energy_multiplier = 2.0
			seal.material_override = lit
			seal.rotation_degrees = Vector3(90, 0, 0)
			seal.position = neck + Vector3(0.07, -0.13, -0.11)
			chest.add_child(seal)
		"cutter":
			var red := _mat(Color(0.85, 0.12, 0.12))
			for side in ["L", "R"]:
				var up := "J_Bip_%s_UpperArm" % side
				var low := "J_Bip_%s_LowerArm" % side
				var hand := "J_Bip_%s_Hand" % side
				if [up, low, hand].any(func(b): return skel.find_bone(b) < 0):
					continue
				for seg in [[up, low], [low, hand]]:
					var root := ColonyGear._root(skel, seg[0], NODE + "_Stripe_" + String(seg[0]))
					var a := _rest(skel, seg[0])
					var b := _rest(skel, seg[1])
					var r := 0.058 if seg[0] == up else 0.05
					ColonyGear._line(root, a + Vector3(0, r, 0), b + Vector3(0, r * 0.9, 0), 0.006, red)
			# the hood, down at her back
			var hood := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.1
			s.height = 0.14
			hood.mesh = s
			hood.material_override = _mat(Color(0.42, 0.4, 0.43))
			hood.position = neck + Vector3(0, -0.03, 0.09)
			hood.scale = Vector3(1.3, 0.8, 0.6)
			chest.add_child(hood)
			# the rips at her knees: skin through the denim
			for side in ["L", "R"]:
				var bone := "J_Bip_%s_LowerLeg" % side
				if skel.find_bone(bone) < 0:
					continue
				var knee := ColonyGear._root(skel, bone, NODE + "_Rip_" + side)
				var rip := MeshInstance3D.new()
				var e := SphereMesh.new()
				e.radius = 0.028
				e.height = 0.03
				rip.mesh = e
				rip.material_override = _mat(Color(0.93, 0.78, 0.7))
				rip.scale = Vector3(1.2, 0.6, 0.35)
				rip.position = _rest(skel, bone) + Vector3(0, 0.0, -0.068)
				knee.add_child(rip)
	ColonyGear._match_layers(npc, hips, "Body")
	ColonyGear._match_layers(npc, chest, "Body")


static func _cone(parent: Node3D, top: Vector3, r_top: float, r_bottom: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 28
	mi.mesh = c
	mi.material_override = m
	mi.position = top - Vector3(0, h * 0.5, 0)
	parent.add_child(mi)
	return mi
