extends RefCounted
## What Eco picks up in Solace's shops and wears on top of any outfit:
## piercings and tattoos from Ink & Iron, and accessories from Stitch & Steel
## (town_shops.gd sells them; their screens are town_shop_screen.gd).
##
## Piercings and accessories are small meshes riding her head bone, built here
## from primitives at points measured on her face mesh (rest pose, model space:
## she faces -Z, her left is -X). Tattoos are textures in her body's UV space
## (tools/ink/build_tattoos.py bakes them, assets/textures/eco/tattoos/<id>.png):
## the worn ones are stacked into one and handed to her body materials'
## tattoo_tex (eco_toon.gdshaderinc), which only lays them on bare skin, so her
## clothes cover them.
##
## eco_model.gd apply_suit() calls apply() on every model of her (her full
## model, her first-person arm and body, the shop previews), so they follow
## whatever she has on.

const HEAD := "J_Bip_C_Head"
const NODE := "EcoExtras"
const TATTOO_DIR := "res://assets/textures/eco/tattoos/"
const STEEL := preload("res://assets/materials/eco/eco_v_steel.tres")
const CANVAS := preload("res://assets/materials/eco/eco_v_canvas.tres")
const LENS := preload("res://assets/materials/eco/eco_v_goggle_lens.tres")
const OUTLINED := preload("res://assets/materials/eco/eco_v_leather.tres")
const TWO_SIDED := preload("res://assets/shaders/eco_toon_2side.gdshader")

## Where her ears, nose and brows are (measured on eco.glb's Face mesh; the
## date outfit's hoops hang from the same lobes).
const LOBE := Vector3(0.0744, 1.5174, 0.0214)
const NOSE_TIP := Vector3(0.0, 1.4896, -0.078)

## Piercings: [name, Juno-style blurb, where]. "both" marks a pair (mirrored).
const PIERCINGS := {
	"lobes": {"name": "Lobe studs", "blurb": "A steel stud in each ear. The first thing anybody gets. Even soldiers."},
	"lobe_hoops": {"name": "Lobe hoops", "blurb": "Small steel hoops, both ears. They swing when she runs. (Her date night hoops take their place.)"},
	"helix": {"name": "Helix cuffs", "blurb": "Two tiny rings up the rim of her left ear, under the hair. You only see them when she tucks it back."},
	"nose_stud": {"name": "Nose stud", "blurb": "A pin of steel on the right side of her nose. Subtle. For her."},
	"septum": {"name": "Septum ring", "blurb": "A ring through the middle of her nose. The recruiters will hate it. That's the point."},
	"brow": {"name": "Eyebrow bar", "blurb": "A barbell through the end of her right brow. Makes every glare count double."},
}

## Tattoos, baked by tools/ink/build_tattoos.py: [name, blurb, where it sits].
const TATTOOS := {
	"precursor": {"name": "Precursor glyph", "where": "back of her left wrist", "blurb": "The spiral off the temple walls. Nobody in town knows what it means. Neither does she. Yet."},
	"cry_anyway": {"name": "\"cry anyway\"", "where": "inside her left forearm", "blurb": "Handwritten, with a little teal teardrop. For the recruiters. For Dad."},
	"fern_band": {"name": "Fern band", "where": "round her right upper arm", "blurb": "Fronds all the way round, like the rooftop garden. Solace on her skin."},
	"swallows": {"name": "Swallows", "where": "left collarbone", "blurb": "Two swallows, one chasing the other. Sailors got them for finding their way home."},
	"sun_tree": {"name": "Sun Tree", "where": "right shoulder blade", "blurb": "The tree on the plaza, sun behind it. The night Dad took her to see it switched on."},
	"stars": {"name": "Three stars", "where": "side of her neck", "blurb": "A little constellation under her left ear. Dad named it after her. Nobody else uses the name."},
	"heart_bolt": {"name": "Struck heart", "where": "top of her right shoulder", "blurb": "A red heart split by a lightning bolt. Loud, cute, a bit of a threat."},
	"wrench": {"name": "Spanner heart", "where": "back of her right wrist", "blurb": "A spanner through a teal heart. Mechanic for life."},
}

## Accessories: one per slot (head, eyes, face). Goggles go when something sits on her head.
const ACCESSORIES := {
	"shades": {"name": "Round shades", "slot": "eyes", "blurb": "Little round black lenses. Look like trouble, see like a hawk (she says)."},
	"visor": {"name": "Wraparound visor", "slot": "eyes", "blurb": "One curved band of teal glass, ear to ear. Very titan pilot. Mara swears it's not stolen."},
	"beanie": {"name": "Knit beanie", "slot": "head", "blurb": "Charcoal, rib-knit, warm. Her goggles go in her pocket."},
	"bandana": {"name": "Face bandana", "slot": "face", "blurb": "Red bandana tied over her nose and mouth. Dust, smoke, cameras. Very guerrilla."},
}

## Stacked tattoo textures, by the worn ids joined (so models share them).
static var _tattoo_cache := {}
static var _mats := {}


## Puts her extras on a model of her (eco_model.gd): `worn` is
## {"piercings": [...], "tattoos": [...], "accessories": [...]}; empty uses
## what town_shops.gd has saved.
static func apply(model: Node, worn := {}) -> void:
	if model == null:
		return
	if worn.is_empty():
		worn = load("res://scripts/hub/town_shops.gd").worn()
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone(HEAD) < 0:
		return
	var outfit := String(model.get("outfit")) if model.get("outfit") != null else ""
	_dress_head(model, skel, worn.get("piercings", []), worn.get("accessories", []), outfit)
	_ink(model, worn.get("tattoos", []))


## Rebuilds the head pieces (piercings and accessories) on her head bone.
static func _dress_head(model: Node, skel: Skeleton3D, piercings: Array, accessories: Array, outfit: String) -> void:
	var old := skel.get_node_or_null(NODE)
	if old != null:
		skel.remove_child(old)
		old.free()
	var head := skel.find_bone(HEAD)
	var att := BoneAttachment3D.new()
	att.name = NODE
	att.bone_name = HEAD
	skel.add_child(att)
	# Built in rest model space, then moved into the head bone's space.
	var root := Node3D.new()
	root.transform = skel.get_bone_global_rest(head).affine_inverse()
	att.add_child(root)
	for id in piercings:
		if id in ["lobes", "lobe_hoops"] and outfit == "date":
			continue  # her date night hoops are in
		_piercing(root, String(id))
	var goggles := true
	for id in accessories:
		_accessory(root, String(id))
		if ACCESSORIES.get(id, {}).get("slot", "") == "head":
			goggles = false
	# (eco_model.gd apply_suit() shows them again for the next look)
	if not goggles:
		for mi in model.find_children("Goggles*", "MeshInstance3D", true, false):
			mi.visible = false
	# Same render layers as her own meshes (the first-person body hides some).
	var face := model.find_child("Face", true, false) as MeshInstance3D
	if face != null:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			mi.layers = face.layers


static func _piercing(root: Node3D, id: String) -> void:
	var steel := _mat("steel", STEEL, Color(0.78, 0.8, 0.84), false)
	match id:
		"lobes":
			for s: float in [-1.0, 1.0]:
				_ball(root, Vector3(LOBE.x * s + 0.0018 * s, LOBE.y - 0.002, LOBE.z), 0.0022, steel)
		"lobe_hoops":
			for s: float in [-1.0, 1.0]:
				_ring(root, Vector3(LOBE.x * s + 0.0018 * s, LOBE.y - 0.0065, LOBE.z), Vector3.RIGHT, 0.0055, 0.0009, steel)
		"helix":
			for spec in [Vector3(-0.0805, 1.5545, 0.024), Vector3(-0.0795, 1.5615, 0.017)]:
				_ring(root, spec, Vector3.RIGHT, 0.003, 0.0007, steel)
		"nose_stud":
			_ball(root, Vector3(0.0058, 1.4845, -0.0735), 0.0015, steel)
		"septum":
			_ring(root, Vector3(0.0, 1.4842, -0.0748), Vector3(0, 0.35, -1), 0.0034, 0.0007, steel)
		"brow":
			var n := Vector3(0.46, -0.2, -0.86).normalized()
			var top := Vector3(0.047, 1.5525, -0.0525) + n * 0.0016
			var bottom := Vector3(0.0473, 1.5385, -0.0493) + n * 0.0016
			_ball(root, top, 0.0019, steel)
			_ball(root, bottom, 0.0019, steel)


static func _accessory(root: Node3D, id: String) -> void:
	match id:
		"shades":
			var frame := _mat("frame", OUTLINED, Color(0.08, 0.08, 0.09), true)
			var glass := _mat("shade_lens", LENS, Color(0.12, 0.13, 0.17), false)
			for s: float in [-1.0, 1.0]:
				var c := Vector3(0.031 * s, 1.519, -0.0655)
				_disc(root, c, 0.0155, 0.002, glass)
				_ring(root, c, Vector3.BACK, 0.0158, 0.0012, frame)
				# arm back to her ear
				_bar(root, Vector3(0.046 * s, 1.521, -0.064), Vector3(0.075 * s, 1.525, 0.012), 0.0011, frame)
			_bar(root, Vector3(-0.0155, 1.522, -0.0655), Vector3(0.0155, 1.522, -0.0655), 0.0011, frame)
		"visor":
			var glass := _glass(Color(0.25, 0.95, 0.9, 0.35))
			_band(root, Vector3(0, 1.52, 0.004), Vector2(0.078, 0.073), 1.511, 1.531, -80.0, 80.0, glass)
			var frame := _mat("frame", OUTLINED, Color(0.08, 0.08, 0.09), true)
			_band(root, Vector3(0, 1.52, 0.004), Vector2(0.0785, 0.0735), 1.531, 1.535, -84.0, 84.0, frame)
		"beanie":
			var knit := _mat("knit", CANVAS, Color(0.24, 0.24, 0.28), true)
			var cap := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.is_hemisphere = true
			sphere.radius = 0.128
			sphere.height = 0.128
			sphere.radial_segments = 24
			sphere.rings = 10
			cap.mesh = sphere
			cap.material_override = knit
			cap.position = Vector3(0, 1.55, 0.03)
			cap.scale = Vector3(1.0, 1.0, 1.1)
			root.add_child(cap)
			# the folded cuff, hugging the dome's edge
			_band(root, Vector3(0, 1.55, 0.03), Vector2(0.125, 0.137), 1.543, 1.57, -180.0, 180.0, knit)
		"bandana":
			var red := _mat("bandana", CANVAS, Color(0.72, 0.12, 0.12), true)
			_band(root, Vector3(0, 1.46, 0.002), Vector2(0.066, 0.082), 1.424, 1.498, -100.0, 100.0, red, 0.016)
			# the knot and tails at the back of her neck
			_ball(root, Vector3(0, 1.46, 0.07), 0.012, red)
			for s: float in [-1.0, 1.0]:
				_bar(root, Vector3(0.004 * s, 1.455, 0.074), Vector3(0.018 * s, 1.40, 0.085), 0.006, red)


# --- tattoos ------------------------------------------------------------------

## Hands the stacked texture of `ids` to every body material on the model.
static func _ink(model: Node, ids: Array) -> void:
	var tex := tattoo_texture(ids)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as ShaderMaterial
			if mat != null and _is_body(mat):
				mat.set_shader_parameter("tattoo_tex", tex)


static func _is_body(mat: Material) -> bool:
	var key := mat.resource_name if mat.resource_name != "" else mat.resource_path.get_file().get_basename()
	return key.begins_with("eco_v_body")


## The worn tattoos stacked into one texture (null for none).
static func tattoo_texture(ids: Array) -> Texture2D:
	var have := ids.filter(func(id): return TATTOOS.has(id) and ResourceLoader.exists(TATTOO_DIR + id + ".png"))
	if have.is_empty():
		return null
	have.sort()
	var key := ",".join(have)
	if _tattoo_cache.has(key):
		return _tattoo_cache[key]
	var img: Image = null
	for id in have:
		var one: Image = (load(TATTOO_DIR + id + ".png") as Texture2D).get_image()
		if one.is_compressed():
			one.decompress()
		one.convert(Image.FORMAT_RGBA8)
		if img == null:
			img = one.duplicate()
		else:
			img.blend_rect(one, Rect2i(Vector2i.ZERO, one.get_size()), Vector2i.ZERO)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tattoo_cache[key] = tex
	return tex


# --- little meshes ---------------------------------------------------------------

## A copy of an Eco toon material in another colour (outline kept or dropped:
## tiny steel bits go black under an outline).
static func _mat(key: String, base: ShaderMaterial, color: Color, outline: bool) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := base.duplicate() as ShaderMaterial
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("albedo_tex", null)
	m.set_shader_parameter("use_mask", false)
	m.set_shader_parameter("use_normal", false)
	m.shader = TWO_SIDED
	if not outline:
		m.next_pass = null
	_mats[key] = m
	return m


## Tinted see-through glass (a visor): the toon shader has no see-through.
static func _glass(color: Color) -> StandardMaterial3D:
	if _mats.has("glass"):
		return _mats["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.8
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b) * 0.25
	_mats["glass"] = m
	return m


static func _ball(root: Node3D, at: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi


## A ring round `axis` through `at`.
static func _ring(root: Node3D, at: Vector3, axis: Vector3, r: float, thick: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 18
	t.ring_segments = 6
	mi.mesh = t
	mi.material_override = mat
	mi.position = at
	# TorusMesh lies flat round Y: turn Y onto the axis.
	mi.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	root.add_child(mi)
	return mi


static func _disc(root: Node3D, at: Vector3, r: float, thick: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = thick
	c.radial_segments = 20
	mi.mesh = c
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees.x = 90.0
	root.add_child(mi)
	return mi


static func _bar(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	root.add_child(mi)
	return mi


## A curved band round a vertical axis through `c` (radii x, z), from y0 to y1,
## between two angles (degrees, 0 = straight in front of her, -Z). `taper`
## pulls the bottom edge in (a bandana closing under her chin). Its material
## is two-sided (_mat), so the winding doesn't matter.
static func _band(root: Node3D, c: Vector3, radii: Vector2, y0: float, y1: float, a0: float, a1: float, mat: Material,
		taper := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 28
	for i in steps:
		var quad: Array[Vector3] = []
		for spec in [[i, y0], [i + 1, y0], [i + 1, y1], [i, y1]]:
			var t := deg_to_rad(lerpf(a0, a1, float(spec[0]) / steps))
			var shrink := taper if spec[1] == y0 else 0.0
			quad.append(Vector3(c.x + sin(t) * (radii.x - shrink), spec[1], c.z - cos(t) * (radii.y - shrink)))
		for v in [0, 2, 1, 0, 3, 2]:
			var out: Vector3 = quad[v] - c
			out.y = 0.0
			st.set_normal(out.normalized())
			st.add_vertex(quad[v])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)
	return mi
