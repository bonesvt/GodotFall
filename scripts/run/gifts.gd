extends RefCounted
## Gifts Eco finds out on runs for the people back at the temple. Now and then
## a zone hides one (a little wrapped bundle with a pink glow, off one of the
## routes like the supply crates); walking into it picks it up, and it goes
## straight into the gift bag saved with the hub talks (npc_talk.gd), so a lost
## run doesn't lose it. In the hub, G by someone romanceable offers what's in
## the bag (npc_talk.gd offer_gifts()).
##
## What each gift means to whom is up to them: their dialogue file's [romance]
## likes / dislikes name these ids.

const Loot := preload("res://scripts/run/loot.gd")
const Kit := preload("res://scripts/hub/hub_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

## id: [name, what Eco thinks when she picks it up]
const CATALOG := {
	"book": ["Water-stained paperback", "A paperback. Somebody died reading it, probably. She'll love it."],
	"eyeliner": ["Black eyeliner pencil", "Black eyeliner. Barely used. Ophelia goes through these."],
	"black_lipstick": ["Black lipstick", "Black lipstick. In a militia locker. Somebody had secrets."],
	"cigarettes": ["Pack of smokes", "A full pack of smokes. Mom's going to kill me."],
	"tape": ["Cassette of sad songs", "A mixtape. Track one is called 'Bury Me Twice'. Perfect."],
	"horror_movie": ["Horror film reel", "A horror reel. The box says 'banned in three provinces'."],
	"candles": ["Box of black candles", "Black candles. For the girl who lives in the dark."],
	"arcade_tokens": ["Glowbox tokens", "A roll of Glowbox tokens. That's a date, right there."],
	"flowers": ["Wild flowers", "Flowers. Pretty. Ophelia's going to hate these, isn't she."],
	"perfume": ["Officer's perfume", "Militia officer's perfume. Smells like money and bad decisions."],
}
## Chance a zone hides a gift, and the most one can hold.
const CHANCE := 0.6
const MAX_PER_ZONE := 1
const PICKUP_RANGE := 1.6


static func display_name(id: String) -> String:
	return CATALOG.get(id, [id.capitalize()])[0]


static func roll(rng: RandomNumberGenerator) -> String:
	var ids := CATALOG.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]


## Maybe hides a gift in a built zone (after Loot.scatter, so it can keep
## clear of the crates). Adds "gifts" to info. Returns the gifts placed.
static func scatter(root: Node3D, info: Dictionary, rng: RandomNumberGenerator) -> Array:
	info["gifts"] = []
	if rng.randf() >= CHANCE:
		return []
	var spawn: Vector3 = info["spawn"]
	var taken: Array = []
	for node in info.get("loot", []):
		taken.append(node.position)
	for spot in Loot._candidates(info, rng):
		if info["gifts"].size() >= MAX_PER_ZONE:
			break
		if spot.distance_to(spawn) < Loot.SPAWN_CLEAR or taken.any(func(t): return t.distance_to(spot) < 6.0):
			continue
		var g := GiftPickup.new()
		g.gift = roll(rng)
		g.kill_y = float(info.get("kill_y", float(info["floor_y"]) - 15.0))
		root.add_child(g)
		g.position = spot
		info["gifts"].append(g)
	return info["gifts"]


## A gift on the ground: settles onto whatever is under it, bobs and spins
## with a pink glow, and is picked up when the pilot walks into it (the run
## manager is the "loot_collector" and has collect_gift()).
class GiftPickup extends Node3D:
	var gift := "book"
	var kill_y := -100.0
	var _model: Node3D
	var _age := 0.0
	var _settled := false

	func _ready() -> void:
		_model = Node3D.new()
		add_child(_model)
		var paper := Art.material("canvas", Color(0.22, 0.12, 0.3))
		var ribbon := Color(1.0, 0.4, 0.75)
		Kit.mesh(_model, Vector3(0, 0.16, 0), Vector3(0.36, 0.28, 0.28), paper)
		Kit.glow(_model, Vector3(0, 0.16, 0), Vector3(0.38, 0.29, 0.05), ribbon)
		Kit.glow(_model, Vector3(0, 0.16, 0), Vector3(0.05, 0.29, 0.3), ribbon)
		Kit.glow(_model, Vector3(-0.05, 0.33, 0), Vector3(0.1, 0.06, 0.04), ribbon, Vector3(0, 0, 30))
		Kit.glow(_model, Vector3(0.05, 0.33, 0), Vector3(0.1, 0.06, 0.04), ribbon, Vector3(0, 0, -30))
		var glow := OmniLight3D.new()
		glow.light_color = ribbon
		glow.light_energy = 1.2
		glow.omni_range = 2.2
		glow.position.y = 0.4
		add_child(glow)

	func _physics_process(delta: float) -> void:
		_age += delta
		if not _settled:
			_settled = true
			var hit = Loot.LootArt.ground_under(get_world_3d(), global_position, kill_y, [])
			if hit != null:
				global_position = hit
		_model.position.y = 0.1 + sin(_age * 2.5) * 0.06
		_model.rotation.y += delta * 1.5
		var collector := get_tree().get_first_node_in_group("loot_collector")
		var pilot: Node3D = collector.player if collector != null else null
		if pilot == null or not pilot.is_inside_tree():
			return
		var d := pilot.global_position - global_position
		if Vector2(d.x, d.z).length() < PICKUP_RANGE and absf(d.y) < 2.0:
			collector.collect_gift(gift)
			queue_free()
