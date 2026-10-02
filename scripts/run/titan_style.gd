extends RefCounted
## Eco's paint jobs and small tweaks for the player's titans, one style per
## chassis, saved to user://. The garage in the hub (scripts/hub/garage.gd)
## edits them; titan.gd applies them to every titan you drop.
##
## A style is a Dictionary of option key -> value name (see OPTIONS). Colours
## that say "" follow the paint job; the factory paint job is the colour the
## model was built with in Blender (tools/titans/build_titans.py).
## apply() works on the node and material names the Blender build gives the
## titans: paint_/stripe_/trim_<chassis> livery materials, glow_lamp lamps,
## the Core and Canopy meshes, the ArmLFender/ArmRFender, Antenna, LegRPouch,
## CockpitCharms and *Decals groups.

const CHASSIS := ["atlas", "ogre", "stryder", "scrap"]

## Colours you can pick for the body, stripes and trim (sRGB).
const PALETTE := {
	"cherry": Color(0.86, 0.12, 0.16), "tangerine": Color(1.0, 0.5, 0.12),
	"sunflower": Color(1.0, 0.82, 0.2), "lime": Color(0.62, 0.86, 0.2),
	"racing green": Color(0.08, 0.36, 0.2), "mint": Color(0.55, 0.93, 0.78),
	"teal": Color(0.1, 0.58, 0.62), "sky": Color(0.55, 0.8, 1.0),
	"dad's blue": Color(0.44, 0.72, 0.93), "navy": Color(0.1, 0.14, 0.34),
	"grape": Color(0.48, 0.24, 0.78), "lilac": Color(0.8, 0.68, 0.98),
	"bubblegum": Color(1.0, 0.6, 0.8), "hot pink": Color(1.0, 0.24, 0.58),
	"cream": Color(0.97, 0.92, 0.8), "snow": Color(0.96, 0.97, 0.99),
	"graphite": Color(0.24, 0.25, 0.28), "licorice": Color(0.07, 0.07, 0.08),
}

## Paint jobs: body, stripes, trim, as PALETTE names. "factory" is the build's own.
const LIVERIES := {
	"factory": [],
	"dad's blue": ["dad's blue", "tangerine", "cream"],
	"bubblegum": ["bubblegum", "snow", "lilac"],
	"sunset": ["tangerine", "hot pink", "cream"],
	"midnight": ["licorice", "hot pink", "graphite"],
	"mint chip": ["mint", "graphite", "cream"],
	"grape soda": ["grape", "sunflower", "lilac"],
	"racing green": ["racing green", "cream", "sunflower"],
	"snow cone": ["snow", "sky", "bubblegum"],
	"cherry bomb": ["cherry", "snow", "licorice"],
}

## Built colours of each chassis (linear, as in build_titans.py): body, stripes, trim.
const FACTORY := {
	"atlas": [Color(0.16, 0.48, 0.86), Color(1.0, 0.38, 0.02), Color(0.92, 0.87, 0.74)],
	"ogre": [Color(1.0, 0.66, 0.02), Color(0.1, 0.22, 0.12), Color(0.16, 0.3, 0.16)],
	"stryder": [Color(0.92, 0.92, 0.9), Color(0.86, 0.1, 0.08), Color(0.3, 0.32, 0.36)],
	"scrap": [Color(0.3, 0.4, 0.16), Color(1.0, 0.4, 0.05), Color(0.6, 0.55, 0.45)],
}

## Lamp, core and canopy colours. The first of each is what the build uses.
const LIGHTS := {
	"warm": Color(1.0, 0.95, 0.82), "white": Color(0.92, 0.96, 1.0), "pink": Color(1.0, 0.55, 0.8),
	"mint": Color(0.55, 1.0, 0.82), "amber": Color(1.0, 0.65, 0.2), "violet": Color(0.75, 0.55, 1.0),
}
const CORES := {
	"blue": Color(0.66, 0.93, 1.0), "pink": Color(1.0, 0.45, 0.75), "green": Color(0.5, 1.0, 0.55),
	"gold": Color(1.0, 0.8, 0.3), "violet": Color(0.7, 0.45, 1.0), "red": Color(1.0, 0.3, 0.25),
}
const CANOPIES := {
	"blue": Color(0.15, 0.3, 0.4), "rose": Color(0.45, 0.18, 0.3), "amber": Color(0.45, 0.3, 0.1),
	"smoke": Color(0.1, 0.1, 0.12), "mint": Color(0.15, 0.42, 0.35),
}
const FENDERS := {"slim": 0.85, "stock": 1.0, "big": 1.18}
const ANTENNAS := {"off": 0.0, "short": 0.7, "stock": 1.0, "tall": 1.35}

## The garage's rows, in order. "" in a colour row means "from the paint job";
## "none" for stripes paints them over in the body colour.
const OPTIONS := [
	{"key": "livery", "label": "Paint job"},
	{"key": "body", "label": "Body"},
	{"key": "stripe", "label": "Stripes"},
	{"key": "trim", "label": "Trim"},
	{"key": "lights", "label": "Lamps"},
	{"key": "core", "label": "Core glow"},
	{"key": "canopy", "label": "Canopy tint"},
	{"key": "fenders", "label": "Shoulder fenders"},
	{"key": "antenna", "label": "Antenna"},
	{"key": "stickers", "label": "Stickers"},
	{"key": "pouch", "label": "Tool pouch"},
	{"key": "charms", "label": "Cockpit charms"},
]

const DEFAULT := {
	"livery": "factory", "body": "", "stripe": "", "trim": "", "lights": "warm",
	"core": "blue", "canopy": "blue", "fenders": "stock", "antenna": "stock",
	"stickers": "on", "pouch": "on", "charms": "on",
}

## Where styles are saved; tests point it somewhere else.
static var path := "user://titan_style.cfg"
## (material name, colour) -> recoloured copy, shared by every titan.
static var _materials := {}


## The value names a row cycles through.
static func values(key: String) -> Array:
	match key:
		"livery":
			return LIVERIES.keys()
		"body", "trim":
			return [""] + PALETTE.keys()
		"stripe":
			return ["", "none"] + PALETTE.keys()
		"lights":
			return LIGHTS.keys()
		"core":
			return CORES.keys()
		"canopy":
			return CANOPIES.keys()
		"fenders":
			return FENDERS.keys()
		"antenna":
			return ANTENNAS.keys()
	return ["on", "off"]


## The saved style for a chassis (DEFAULT for anything unsaved).
static func load_style(chassis: String) -> Dictionary:
	var style := DEFAULT.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key in DEFAULT:
			var v = cfg.get_value(chassis, key, DEFAULT[key])
			if v is String and v in values(key):
				style[key] = v
	return style


static func save_style(chassis: String, style: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key in DEFAULT:
		cfg.set_value(chassis, key, style.get(key, DEFAULT[key]))
	cfg.save(path)


## Steps one option to its next (+1) or previous (-1) value. Picking a paint
## job clears the hand-picked colours so the whole job shows.
static func step(style: Dictionary, key: String, dir: int) -> void:
	var vals := values(key)
	var i := vals.find(style.get(key, DEFAULT[key]))
	style[key] = vals[posmod(i + dir, vals.size())]
	if key == "livery":
		for k in ["body", "stripe", "trim"]:
			style[k] = ""


## Body, stripe and trim colours (sRGB) the style paints a chassis with.
static func livery(chassis: String, style: Dictionary) -> Array[Color]:
	var factory: Array = FACTORY.get(chassis, FACTORY["atlas"])
	var job: Array = LIVERIES.get(style.get("livery", "factory"), [])
	var out: Array[Color] = []
	for i in 3:
		var key: String = ["body", "stripe", "trim"][i]
		var pick: String = style.get(key, "")
		if pick == "none":
			out.append(out[0])
		elif PALETTE.has(pick):
			out.append(PALETTE[pick])
		elif job.size() == 3:
			out.append(PALETTE[job[i]])
		else:
			out.append((factory[i] as Color).linear_to_srgb())
	return out


## The swatch colour of a row's current value, or null when it has none.
static func swatch(chassis: String, style: Dictionary, key: String) -> Variant:
	match key:
		"livery", "body":
			return livery(chassis, style)[0]
		"stripe":
			return livery(chassis, style)[1]
		"trim":
			return livery(chassis, style)[2]
		"lights":
			return LIGHTS[style["lights"]]
		"core":
			return CORES[style["core"]]
		"canopy":
			return CANOPIES[style["canopy"]]
	return null


## Paints and tweaks a titan model from Art.titan() (before or after it is in
## the tree). Parts that are switched off are freed, not hidden, so the
## piloted view in titan.gd can't bring them back.
static func apply(model: Node3D, chassis: String, style: Dictionary) -> void:
	if not FACTORY.has(chassis):
		return
	# Only what the style changes from the factory paint gets a new material.
	var colors := livery(chassis, style)
	var swap := {}
	var job: bool = style.get("livery", "factory") != "factory"
	for i in 3:
		var key: String = ["body", "stripe", "trim"][i]
		if job or style.get(key, "") != "":
			swap[["paint_", "stripe_", "trim_"][i] + chassis] = colors[i]
	var lamp: Color = LIGHTS[style["lights"]]
	var core: Color = CORES[style["core"]]
	var tint: Color = CANOPIES[style["canopy"]]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var in_cockpit := mi.name == &"Cockpit" or mi.get_parent().name == &"Cockpit"
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as ShaderMaterial
			if mat == null:
				continue
			var key := mat.resource_name
			var color: Variant = null
			if swap.has(key):
				color = swap[key]
			elif in_cockpit:
				continue
			elif key == "glow_core" and mi.name == &"Core":
				if style["core"] != "blue":
					color = core
			elif key == "glow_lamp" or key == "glow_core":
				if style["lights"] != "warm":
					color = lamp
			elif key == "glass":
				if style["canopy"] != "blue":
					color = tint
			if color != null:
				mi.set_surface_override_material(s, _recolored(mat, color))
	for side in ["ArmLFender", "ArmRFender"]:
		var fender := model.find_child(side, true, false) as Node3D
		if fender != null:
			fender.scale = Vector3.ONE * FENDERS[style["fenders"]]
	var antenna := model.find_child("Antenna", true, false) as MeshInstance3D
	if antenna != null:
		var size: float = ANTENNAS[style["antenna"]]
		if size == 0.0:
			_drop(antenna)
		elif size != 1.0:
			# Grow it from its base, where it meets the hull.
			var box := antenna.get_aabb()
			var base := antenna.transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
			antenna.transform = Transform3D(Basis.from_scale(Vector3(1.0, size, 1.0)), base) * Transform3D(Basis.IDENTITY, -base) * antenna.transform
	var drop: Array[String] = []
	if style["stickers"] == "off":
		for node in model.find_children("*Decals", "MeshInstance3D", true, false):
			drop.append(node.name)
	if style["pouch"] == "off":
		drop.append_array(["LegRPouch", "LegRPouchDecals"])
	if style["charms"] == "off":
		drop.append("CockpitCharms")
	for part in drop:
		var node := model.find_child(part, true, false)
		if node != null:
			_drop(node)


static func _drop(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()


static func _recolored(mat: ShaderMaterial, color: Color) -> ShaderMaterial:
	var key := mat.resource_name + color.to_html()
	if not _materials.has(key):
		var copy := mat.duplicate() as ShaderMaterial
		copy.set_shader_parameter("albedo", color)
		copy.set_shader_parameter("emission", color)
		_materials[key] = copy
	return _materials[key]
