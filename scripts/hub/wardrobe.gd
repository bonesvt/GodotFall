extends RefCounted
## Eco's wardrobe in the hub: one place to pick what everyone wears (Eco,
## Mom, Ophelia). The picks are saved; an NPC left on "changes every run"
## rotates through her outfits as before (hub_npc.gd wear_for_run). Eco wears
## her pick at home and in town and her pilot suit on a run. The screen is
## wardrobe_screen.gd; build() puts the wardrobe itself by her bed.

const K := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const ECO_MODEL := "res://scripts/ps2/eco_model.gd"
const HUB_NPC := "res://scripts/hub/hub_npc.gd"

## Whose clothes are in it, in tab order, with their tab names.
const PEOPLE := [["eco", "ECO"], ["mom", "MOM"], ["ophelia", "OPHELIA"]]
## What each outfit is called on the screen (anything missing is capitalised).
const NAMES := {
	"suit": "Pilot suit", "sleep": "Sleepwear", "work": "Work clothes", "date": "Date night",
	"casual": "Casual", "swim": "Bikini", "bikini": "Bikini", "sheer": "Sheer layers",
	"tight": "Tight and daring", "lingerie": "Lingerie", "home": "Home clothes",
	"tee": "Band tee", "hoodie": "Hoodie", "night": "Nightwear",
}
## The NPCs' "no pick": their outfit changes after every run.
const ROTATE := ""

## Where the picks are saved ([wardrobe] <who> = <outfit>).
static var save_path := "user://wardrobe.cfg"
## What Eco has on when she isn't resting: her pick at home, the suit on a run.
## eco_fp_body.gd puts her back in it when she gets up.
static var eco_now := "suit"


## The outfits someone has. Eco's come from her model (eco_model.gd OUTFITS);
## until her outfits are in the game that is just the suit.
static func outfits(who: String) -> Array:
	if who == "eco":
		var eco: Script = load(ECO_MODEL)
		return eco.get_script_constant_map().get("OUTFITS", ["suit"]).duplicate()
	var npc: Script = load(HUB_NPC)
	return npc.get_script_constant_map().get("OUTFITS", {}).get(who, []).duplicate()


## The options on the screen: the NPCs' first is "changes every run".
static func options(who: String) -> Array:
	return outfits(who) if who == "eco" else [ROTATE] + outfits(who)


static func outfit_name(outfit: String) -> String:
	if outfit == ROTATE:
		return "Changes every run"
	return NAMES.get(outfit, outfit.capitalize())


## Someone's saved pick: an outfit, or ROTATE (Eco: "suit") if none.
static func choice(who: String) -> String:
	var fallback := "suit" if who == "eco" else ROTATE
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return fallback
	var pick := String(cfg.get_value("wardrobe", who, fallback))
	return pick if options(who).has(pick) else fallback


static func choose(who: String, outfit: String) -> void:
	if not options(who).has(outfit):
		return
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("wardrobe", who, outfit)
	cfg.save(save_path)


## Puts Eco (the player's full-body model) in her pick at home, or her suit
## on a run. Left alone while she's lying down or sitting.
static func dress_eco(player: Node, at_home: bool) -> void:
	eco_now = choice("eco") if at_home else "suit"
	var body := player.get_node_or_null("EcoBody") if player != null else null
	if body == null:
		return
	var shadow = body.get("shadow")
	if shadow == null or not shadow.has_method("wear"):
		return
	if body.has_method("is_resting") and body.is_resting():
		return
	shadow.wear(eco_now)


## The wardrobe against the front wall by her bed (hub_builder.gd), outside
## the bed curtain: a tall cupboard with one door hanging open on clothes, a
## cracked mirror on the other door.
static func build(root: Node3D, info: Dictionary, floor_y: float, front_z: float) -> void:
	var w := Vector3(-5.5, floor_y, front_z - 0.38)
	var wood := Color(0.55, 0.38, 0.26)
	K.mesh(root, w + Vector3(0, 1.1, 0), Vector3(1.3, 2.2, 0.62), Art.material("wood", wood))
	K.mesh(root, w + Vector3(0, 2.25, 0), Vector3(1.42, 0.1, 0.7), Art.material("wood", wood.darkened(0.2)))
	# the clothes inside, seen past the open door: a rail of colours
	K.mesh(root, w + Vector3(0, 1.85, -0.32), Vector3(1.16, 0.03, 0.03), Art.material("gunmetal"))
	var cloth := [Color(0.85, 0.2, 0.25), Color(0.15, 0.12, 0.16), Color(0.95, 0.85, 0.75), Color(0.45, 0.6, 0.85), Color(0.9, 0.5, 0.75)]
	for i in cloth.size():
		K.mesh(root, w + Vector3(-0.5 + i * 0.25, 1.35, -0.33), Vector3(0.2, 0.95 - (i % 2) * 0.25, 0.04), Art.material("fabric", cloth[i]), Vector3(0, 6 - i * 3, 0))
	# right door shut with the mirror on it, left door swung open
	K.mesh(root, w + Vector3(0.32, 1.1, -0.33), Vector3(0.6, 2.0, 0.04), Art.material("wood", wood.lightened(0.08)))
	var mirror := K.mesh(root, w + Vector3(0.32, 1.3, -0.36), Vector3(0.4, 1.2, 0.01), Art.material("light"))
	mirror.set_instance_shader_parameter("paint", Color(0.75, 0.85, 0.9))
	K.mesh(root, w + Vector3(-0.55, 1.1, -0.61), Vector3(0.6, 2.0, 0.04), Art.material("wood", wood.lightened(0.08)), Vector3(0, 70, 0))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.3, 2.2, 0.62)
	body.add_child(shape)
	body.position = w + Vector3(0, 1.1, 0)
	root.add_child(body)
	K.interactable(info, "wardrobe", w + Vector3(0, 0.1, -1.1), "[F] Wardrobe (outfits for everyone)", [], 2.3)
	info["interactables"].back()["screen"] = "wardrobe"
