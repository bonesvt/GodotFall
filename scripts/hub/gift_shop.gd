extends RefCounted
## Lucky Lantern, Solace's gift shop: a little kiosk on the Sun Plaza's east
## corner by the Rusted Halo, its back shelves lined with the gifts it sells.
## Press F at the counter for the shop screen (gift_screen.gd), where the
## materials Eco brings back from runs (armory.gd) buy gifts for the people
## she's romancing (romance.gd: npc_talk.give_gift() hands them over).
##
## Every gift id is one a [romance] section can list under likes / dislikes
## (Ophelia's are in dialogue/npc/ophelia.txt). Most cost scrap; the few she
## really loves cost alloy, circuits or both.
##
## Models: tools/town/build_gifts.py -> assets/models/gifts/<id>.glb and the
## kiosk, assets/models/town/gift_shop.glb.

const K := preload("res://scripts/hub/hub_kit.gd")
const TP := preload("res://scripts/hub/town_props.gd")
const Armory := preload("res://scripts/hub/armory.gd")

const DIR := "res://assets/models/gifts/"
const SIGN := "LUCKY LANTERN"
const PINK := Color(1.0, 0.55, 0.72)

## id -> name, cost and the shop card's blurb. Ordered as on the shelves,
## cheapest first.
const GIFTS := {
	"flowers": {"name": "Sun lilies", "cost": {"scrap": 20}, "blurb": "Grown under the Sun Tree. Everybody's mum loves them."},
	"tape": {"name": "Mixtape", "cost": {"scrap": 20}, "blurb": "Hand-labelled. Pim swears every song on it is sad."},
	"arcade_tokens": {"name": "Glowbox tokens", "cost": {"scrap": 25}, "blurb": "A pouch of brass tokens for the arcade. Good for a rematch."},
	"candles": {"name": "Black candles", "cost": {"scrap": 25}, "blurb": "Three black pillar candles. Smell like smoke and rain."},
	"eyeliner": {"name": "Eyeliner", "cost": {"scrap": 25}, "blurb": "Two jet black pencils. Smudges just right."},
	"book": {"name": "Old paperback", "cost": {"scrap": 30}, "blurb": "'The Keeper of the Light'. Dog-eared. Somebody cried on page 90."},
	"cigarettes": {"name": "Night Owls", "cost": {"scrap": 30}, "blurb": "Black papers, gold filters, a steel lighter thrown in."},
	"perfume": {"name": "Plaza perfume", "cost": {"scrap": 35}, "blurb": "Rose and sugar in a pink bottle. Very loud."},
	"horror_movie": {"name": "Holo-reel: Nobody Came", "cost": {"scrap": 30, "alloy": 10}, "blurb": "Banned by the militia for 'morale'. Best horror film ever made."},
	"records": {"name": "Vinyl: Drowned Lanterns", "cost": {"scrap": 40, "alloy": 15}, "blurb": "First pressing, purple sleeve. Pre-war gloom rock."},
	"black_lipstick": {"name": "Black lipstick", "cost": {"alloy": 20, "circuits": 1}, "blurb": "Off-world import. Pim keeps it under the counter."},
	"makeup": {"name": "Midnight palette", "cost": {"alloy": 30, "circuits": 2}, "blurb": "Six shades of dark in a mirrored compact. The good stuff."},
}

## Paint for the models' gift_<colour> parts.
const PAINT := {
	"black": Color(0.06, 0.055, 0.07), "white": Color(0.92, 0.9, 0.86), "cream": Color(0.93, 0.86, 0.7),
	"red": Color(0.75, 0.08, 0.12), "pink": Color(1.0, 0.5, 0.68), "purple": Color(0.38, 0.18, 0.55),
	"yellow": Color(1.0, 0.8, 0.2), "green": Color(0.3, 0.55, 0.25), "gold": Color(0.85, 0.65, 0.25),
	"silver": Color(0.72, 0.74, 0.78), "teal": Color(0.15, 0.55, 0.55),
}
const GLOSS := {"black": 0.7, "silver": 0.9, "gold": 0.85, "pink": 0.8}

## The kiosk's back shelves in its own space (tools/town/build_gifts.py: front
## edge SHELF_Y, tops SHELF_Z, SHELF_W wide), and how big gifts stand on them.
const SHELF_Y := 2.55
const SHELF_Z := [0.95, 1.5, 2.05]
const SHELF_W := 4.2
## Gifts per shelf, top shelf first.
const SHELF_ROWS := [5, 5, 2]
## How big (m, widest of width and height) a gift stands on the shelves.
const SHELF_SIZE := 0.3
const TILT_UP := ["eyeliner"]

static var _scenes := {}


static func ids() -> Array:
	return GIFTS.keys()


static func gift_name(id: String) -> String:
	return GIFTS[id]["name"] if GIFTS.has(id) else id.capitalize()


static func cost(id: String) -> Dictionary:
	return GIFTS[id]["cost"]


## A gift's model, painted (origin at its base, real size).
static func model(id: String) -> Node3D:
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".glb")
	var node: Node3D = _scenes[id].instantiate()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var parts := String(mi.name).split("__")
		var kind := (parts[1] if parts.size() > 1 else "gift_white").rstrip("0123456789").trim_suffix("_")
		if kind.begins_with("gift_"):
			var c := kind.trim_prefix("gift_")
			mi.material_override = TP.paint(PAINT.get(c, Color.WHITE), GLOSS.get(c, 0.5))
			continue
		var glow := TP.glow_color(kind, {})
		if glow.a > 0.0:
			mi.material_override = preload("res://scripts/ps2/ps2_assets.gd").material("light")
			mi.set_instance_shader_parameter("paint", Color(glow.r, glow.g, glow.b))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.material_override = TP.material(kind, {})
	return node


## Spawns the kiosk at `at` (front facing -Z, towards the Sun Tree) with every
## gift on its shelves, and the counter's interactable (screen "gifts").
## town.gd adds its colliders, sign and light.
static func build(root: Node3D, info: Dictionary, at: Vector3) -> Node3D:
	var kiosk := TP.spawn(root, "gift_shop", at, 180.0, {"wall": Color(1.0, 0.94, 0.95), "shop": PINK,
			"neon": Color(1.0, 0.35, 0.55), "awning": Color(1.0, 0.75, 0.85)})
	shelve(kiosk)
	K.interactable(info, "shop_gifts", at + Vector3(0, 0, -1.6), "[F] Lucky Lantern: gifts", [
		"Auntie Pim wraps everything in ribbon. Even the cigarettes.",
	], 2.8)
	info["interactables"].back()["shop"] = "gifts"
	info["interactables"].back()["screen"] = "gifts"
	return kiosk


## Lines every gift up along the kiosk's shelves (SHELF_ROWS to a shelf, top
## down), each scaled to about SHELF_SIZE so a cassette and an LP read alike.
## The bottom shelf only fills its left end: the counter hides the right.
static func shelve(kiosk: Node3D) -> void:
	var list := ids()
	var per: int = SHELF_ROWS.max()
	var i := 0
	for row in SHELF_ROWS.size():
		for col in SHELF_ROWS[row]:
			if i >= list.size():
				return
			var id: String = list[i]
			i += 1
			var g := model(id)
			g.name = "Gift_" + id
			# Flat things (the eyeliner on its card) stand tilted up to face out.
			if id in TILT_UP:
				g.rotation_degrees.x = 70.0
			g.rotation_degrees.y = (col - (per - 1) * 0.5) * -6.0
			var box := bounds(g)
			var k := SHELF_SIZE / maxf(maxf(box.size.x, box.size.y), 0.01)
			g.scale = Vector3.ONE * k
			# Model space: shelves run along x, depth y (Godot -z after export), up z (Godot y).
			var x := -SHELF_W * 0.5 + SHELF_W * (col + 0.5) / per
			var top: float = SHELF_Z[SHELF_Z.size() - 1 - row]
			g.position = Vector3(x, top - box.position.y * k, -(SHELF_Y + 0.2))
			kiosk.add_child(g)


## The box round a gift's meshes, in its parent's space (rotation included, scale not).
static func bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var basis := Transform3D(Basis.from_euler(root.rotation), Vector3.ZERO)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = basis * _local(root, mi) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _local(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
