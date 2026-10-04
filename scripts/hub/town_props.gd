extends RefCounted
## Solace's modelled buildings and props (assets/models/town/*.glb, made by
## tools/town/build_town.py in Blender). Like hub_props.gd, each mesh is named
## "<part>__<material>" and gets a game material for that suffix when spawned.
## `tints` picks the per-building colours: "wall" (the render), "shop" (the lit
## interior and lamps), "neon" (tubes and sign frames, defaults to shop),
## "awning" and "leaves".

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const Props := preload("res://scripts/hub/hub_props.gd")
const TITAN_PAINT := preload("res://assets/shaders/titan_paint.gdshader")
const PAPER := preload("res://assets/shaders/paper_lantern.gdshader")

const DIR := "res://assets/models/town/"
const IDS := ["shop_w13_f3", "shop_w13_f3b", "shop_w13_f2", "shop_w11_f4", "shop_w11_f3", "shop_w9_f3", "shop_w9_f2",
	"militia_office", "greenhouse", "gate_pylon", "gate_arch", "checkpoint", "sun_tree", "solar_lamp",
	"turbine_tower", "turbine_rotor", "noodle_stall", "scooter", "vending", "bench", "planter", "crates",
	"blade_sign_2", "blade_sign_3", "pergola", "city_tower_a", "city_tower_b", "lantern", "market_stall", "cafe_table", "ice_cream_kiosk", "gift_shop"]

const WARM := Color(1.0, 0.78, 0.5)
const COOL := Color(0.72, 0.88, 1.0)
const GLOWS := {
	"glow_warm": WARM, "glow_cool": COOL, "glow_red": Color(1.0, 0.18, 0.2),
	"glow_cyan": Color(0.25, 0.95, 1.0), "glow_lime": Color(0.6, 1.0, 0.35),
}

static var _scenes := {}
static var _mats := {}


static func spawn(parent: Node, id: String, pos: Vector3, yaw_deg := 0.0, tints := {}, scale := 1.0) -> Node3D:
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".glb")
	var node: Node3D = _scenes[id].instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("__")
		var kind := parts[1] if parts.size() > 1 else "wall"
		kind = kind.rstrip("0123456789").trim_suffix("_")
		var glow := glow_color(kind, tints)
		if tints.get("no_fog", false):
			# Far backdrop (the city): flat colours that ignore the haze, a hazy blue silhouette.
			mi.material_override = _unfogged(glow if glow.a > 0.0 else Color(0.3, 0.33, 0.42), glow.a > 0.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif kind == "glow_paper":
			mi.material_override = _paper()
			mi.set_instance_shader_parameter("paint", Color(glow.r, glow.g, glow.b))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif glow.a > 0.0:
			mi.material_override = Art.material("light")
			mi.set_instance_shader_parameter("paint", Color(glow.r, glow.g, glow.b))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.material_override = material(kind, tints)
			if kind == "glass" or kind == "water":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## The light colour for a glowing part (alpha 0 when the part doesn't glow).
static func glow_color(kind: String, tints: Dictionary) -> Color:
	if kind == "glow_warm" or kind == "glow_cool":
		return GLOWS[kind] * 0.9
	if GLOWS.has(kind):
		return GLOWS[kind] * 1.5
	if kind == "glow_shop" or kind == "glow_paper":
		return tints.get("shop", WARM) * 0.75
	if kind == "neon":
		return tints.get("neon", tints.get("shop", WARM)) * 1.8
	return Color(0, 0, 0, 0)


static func material(kind: String, tints: Dictionary) -> Material:
	var wall: Color = tints.get("wall", Color(0.93, 0.92, 0.88))
	match kind:
		"wall":
			return Art.material("concrete", wall)
		"trim":
			return Art.material("concrete", wall.darkened(0.12))
		"base":
			return Art.material("gunmetal", Color(0.42, 0.42, 0.46))
		"metal":
			return Art.material("gunmetal")
		"dark":
			return paint(Color(0.07, 0.07, 0.09), 0.6)
		"glass_dark":
			return paint(Color(0.04, 0.05, 0.08), 0.9)
		"panel":
			return paint(Color(0.1, 0.16, 0.32), 0.9)
		"glass":
			return _glass()
		"water":
			return _water()
		"stone":
			return Art.material("temple_stone", Color(1.0, 1.0, 0.96))
		"leaves":
			return Props.material("leaves", tints.get("leaves", Color.WHITE))
		"bark":
			return Props.material("bark")
		"moss":
			return Art.material("moss", Color(0.72, 1.0, 0.62))
		"wood":
			return Art.material("wood")
		"canvas":
			return Art.material("canvas", tints.get("awning", Color.WHITE))
	return Art.material("concrete", wall)


## Glossy paint in the titans' paint shader (cached by colour and gloss).
static func paint(color: Color, gloss: float) -> ShaderMaterial:
	var key := "%s/%s" % [color.to_html(), gloss]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = TITAN_PAINT
		mat.set_shader_parameter("albedo", color)
		mat.set_shader_parameter("wear", 0.0)
		mat.set_shader_parameter("grime", 0.15)
		mat.set_shader_parameter("gloss", gloss)
		_mats[key] = mat
	return _mats[key]


static func _paper() -> Material:
	if not _mats.has("paper"):
		var mat := ShaderMaterial.new()
		mat.shader = PAPER
		_mats["paper"] = mat
	return _mats["paper"]


static func _glass() -> Material:
	if not _mats.has("glass"):
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.7, 0.92, 0.88, 0.25)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.roughness = 0.05
		glass.metallic_specular = 1.0
		_mats["glass"] = glass
	return _mats["glass"]


static func _water() -> Material:
	if not _mats.has("water"):
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.22, 0.55, 0.6, 0.85)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness = 0.05
		water.metallic_specular = 0.9
		_mats["water"] = water
	return _mats["water"]


static func _unfogged(color: Color, lit: bool) -> Material:
	var key := "nofog%s%s" % [color.to_html(), lit]
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b)
		mat.disable_fog = true
		if lit:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			mat.roughness = 0.6
		_mats[key] = mat
	return _mats[key]
