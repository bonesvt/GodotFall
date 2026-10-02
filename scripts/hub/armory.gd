extends RefCounted
## Eco's armory: everything that carries over between runs, and the catalog the
## hub's workbenches sell from. Saved to a ConfigFile (user://armory.cfg).
##
## Three materials pay for everything, all collected out in the levels
## (scripts/run/loot.gd): scrap (grunts drop it, small crates hold it), alloy
## (mined from resource nodes) and circuits (rare, from crates and grunts).
## A run that ends in extraction banks everything you carried; a lost run
## banks half. The benches spend them:
##   gunsmith bench   weapon upgrades (three modest tracks per gun) and
##                    attachments (one per slot, each a trade-off), plus finishes
##   weapon rack      buy and pick the sidearm you head out with
##   titan workshop   buy titan parts to start runs with instead of scrap, and
##                    refit any part so every copy of it you install is better
## Titan paint and part tweaks stay at Eco's paint shop.
##
## Upgrades stay small on purpose: the smart pistol is weak and skill-heavy, and
## a maxed track is +18% at most. Starting parts are Mk I, so salvage still
## matters; refits apply to salvaged parts too.

const TitanParts := preload("res://scripts/run/titan_parts.gd")

const DEFAULT_PATH := "user://armory.cfg"
const MATERIALS := ["scrap", "alloy", "circuits"]
const MATERIAL_NAMES := {"scrap": "Scrap", "alloy": "Alloy", "circuits": "Circuits"}
## What Eco has stashed when you first start.
const STARTING_STASH := {"scrap": 60, "alloy": 10, "circuits": 1}
## Share of what you carried that a lost run still banks.
const LOST_RUN_KEEP := 0.5
## Salvaged off the enemy titan when you win.
const WIN_BONUS := {"scrap": 40, "alloy": 25, "circuits": 3}

## Pilot sidearms. `stats` use weapon.gd's property names; the smart pistol's
## are weapon.gd's defaults. `mag_step` is rounds per Magazine upgrade.
const WEAPONS := {
	"smart_pistol": {
		"name": "Dad's Smart Pistol", "cost": {}, "model": "pistol",
		"desc": "Semi-auto, suppressed. Weak on the body, brutal on the head.",
		"smart": true, "automatic": false, "suppressed": true, "mag_step": 1,
		"sound": "pistol", "sound_last": "pistol_last", "tracer": Color(0.75, 0.97, 1.0, 0.85),
		"stats": {
			"damage": 20.0, "headshot_multiplier": 2.25, "falloff_start": 15.0, "falloff_end": 35.0,
			"falloff_min": 0.6, "fire_interval": 0.16, "magazine_size": 8, "reload_time": 1.5,
			"base_spread": 0.25, "bloom_per_shot": 1.1, "bloom_recovery": 6.0, "max_bloom": 4.5,
			"move_spread": 0.9, "air_spread": 1.2, "recoil_kick": 1.4,
		},
		"lines": [
			"Dad's. The lock-on died with him.",
			"Tracker screen's smashed. Holo sight it is.",
			"Tape's holding. Mostly.",
			"Still pulls a hair left. I'll fix it. Someday.",
			"Smart pistol. Not so smart anymore.",
		],
	},
	"rivet_cannon": {
		"name": "Rivet Cannon", "cost": {"scrap": 120, "alloy": 20, "circuits": 3}, "model": "rivet_cannon",
		"desc": "Five heavy rounds off a titan's rivet driver. Slow, loud, kicks like a mule.",
		"smart": false, "automatic": false, "suppressed": false, "mag_step": 1,
		"sound": "rivet_cannon", "sound_last": "rivet_cannon", "tracer": Color(1.0, 0.75, 0.4, 0.9),
		"stats": {
			"damage": 42.0, "headshot_multiplier": 2.0, "falloff_start": 22.0, "falloff_end": 50.0,
			"falloff_min": 0.65, "fire_interval": 0.42, "magazine_size": 5, "reload_time": 2.1,
			"base_spread": 0.15, "bloom_per_shot": 2.4, "bloom_recovery": 5.0, "max_bloom": 6.0,
			"move_spread": 1.2, "air_spread": 1.6, "recoil_kick": 3.6,
		},
		"lines": [
			"Built it round a rivet driver. It still thinks it's holding titans together.",
			"Five shots. Make them count or make them run.",
			"The coils glow when it's angry. It's always a bit angry.",
		],
	},
	"machine_pistol": {
		"name": "Militia Machine Pistol", "cost": {"scrap": 100, "circuits": 2}, "model": "machine_pistol",
		"desc": "Full auto, light rounds, sprays wide. Hold the trigger, mind the bloom.",
		"smart": false, "automatic": true, "suppressed": false, "mag_step": 3,
		"sound": "machine_pistol", "sound_last": "machine_pistol", "tracer": Color(1.0, 0.9, 0.6, 0.7),
		"stats": {
			"damage": 8.0, "headshot_multiplier": 1.75, "falloff_start": 10.0, "falloff_end": 25.0,
			"falloff_min": 0.5, "fire_interval": 0.075, "magazine_size": 20, "reload_time": 1.7,
			"base_spread": 0.5, "bloom_per_shot": 0.45, "bloom_recovery": 7.0, "max_bloom": 5.5,
			"move_spread": 0.7, "air_spread": 1.0, "recoil_kick": 0.55,
		},
		"lines": [
			"Took it off a grunt who called me 'sweetheart'. He won't need it.",
			"Militia junk. Cheap, loud, and it works. Like them.",
			"The heart sticker is load-bearing.",
		],
	},
}

## Upgrade tracks, levels 0..MAX_LEVEL for every gun. Each level costs UPGRADE_COST[level].
const UPGRADES := {
	"calibre": {"name": "Calibre", "desc": "+6% damage per level"},
	"action": {"name": "Action", "desc": "8% faster reload per level"},
	"magazine": {"name": "Magazine", "desc": "more rounds per level"},
}
const UPGRADE_ORDER := ["calibre", "action", "magazine"]
const MAX_LEVEL := 3
## Upgraded looks a gun has beyond stock.
const MODEL_TIERS := 5
const UPGRADE_COST := [{"scrap": 40}, {"scrap": 70, "circuits": 2}, {"scrap": 110, "circuits": 5}]
const CALIBRE_STEP := 0.06
const ACTION_STEP := 0.08

## Attachments: one per slot per gun. Bought once, usable on every gun.
## `mods` multiply weapon stats (magazine_size rounds, never below 1).
const ATTACHMENT_SLOTS := ["muzzle", "mag", "grip"]
const SLOT_NAMES := {"muzzle": "Muzzle", "mag": "Mag", "grip": "Grip"}
const ATTACHMENTS := {
	"muzzle": [
		{"id": "stock", "name": "Stock", "desc": "As it came.", "cost": {}, "mods": {}},
		{"id": "long_barrel", "name": "Long barrel", "desc": "Holds damage 40% further and tighter, but slower to fire.", "cost": {"scrap": 50, "circuits": 1},
			"mods": {"falloff_start": 1.4, "falloff_end": 1.4, "base_spread": 0.7, "fire_interval": 1.12}},
		{"id": "compensator", "name": "Compensator", "desc": "Less kick and bloom, but sloppier on the move.", "cost": {"scrap": 50, "circuits": 1},
			"mods": {"recoil_kick": 0.6, "bloom_per_shot": 0.8, "move_spread": 1.25, "air_spread": 1.25}},
	],
	"mag": [
		{"id": "stock", "name": "Stock", "desc": "As it came.", "cost": {}, "mods": {}},
		{"id": "extended", "name": "Extended mag", "desc": "40% more rounds, 20% slower reload.", "cost": {"scrap": 50, "circuits": 1},
			"mods": {"magazine_size": 1.4, "reload_time": 1.2}},
		{"id": "speed", "name": "Speed base", "desc": "30% faster reload, 20% fewer rounds.", "cost": {"scrap": 50, "circuits": 1},
			"mods": {"magazine_size": 0.8, "reload_time": 0.7}},
	],
	"grip": [
		{"id": "stock", "name": "Stock", "desc": "As it came.", "cost": {}, "mods": {}},
		{"id": "wrap", "name": "Paracord wrap", "desc": "Steadier on the ground, bloom settles faster; worse in the air.", "cost": {"scrap": 45, "circuits": 1},
			"mods": {"move_spread": 0.75, "bloom_recovery": 1.3, "air_spread": 1.15}},
		{"id": "skeleton", "name": "Skeleton grip", "desc": "Accurate in the air, but kicks harder.", "cost": {"scrap": 45, "circuits": 1},
			"mods": {"air_spread": 0.6, "move_spread": 0.85, "recoil_kick": 1.25}},
	],
}

## Finishes: free, cosmetic. Colours for the pistol_* paint slots.
const FINISHES := [
	{"id": "dads", "name": "Dad's colours", "shell": Color(1.0, 1.02, 1.05), "blue": Color(0.42, 0.58, 0.8), "stripe": Color(1.2, 0.62, 0.22)},
	{"id": "bubblegum", "name": "Bubblegum chrome", "shell": Color(1.15, 0.72, 0.9), "blue": Color(0.95, 0.95, 1.0), "stripe": Color(0.4, 0.95, 1.1)},
	{"id": "jungle", "name": "Jungle", "shell": Color(0.52, 0.62, 0.4), "blue": Color(0.36, 0.28, 0.2), "stripe": Color(1.1, 0.85, 0.3)},
	{"id": "midnight", "name": "Midnight", "shell": Color(0.22, 0.22, 0.28), "blue": Color(0.45, 0.3, 0.8), "stripe": Color(1.2, 0.3, 0.6)},
	{"id": "bone", "name": "Bone white", "shell": Color(1.1, 1.05, 0.92), "blue": Color(0.3, 0.3, 0.32), "stripe": Color(0.95, 0.2, 0.15)},
	{"id": "ember", "name": "Ember", "shell": Color(0.3, 0.26, 0.24), "blue": Color(1.1, 0.4, 0.15), "stripe": Color(1.3, 0.85, 0.3)},
]

## Titan parts you can buy to start runs with (Mk I), by slot. Scrap is free.
const TITAN_PART_COST := {
	"chassis": {"alloy": 60, "scrap": 40},
	"weapon": {"alloy": 40, "scrap": 40, "circuits": 2},
	"core": {"alloy": 30, "circuits": 4},
	"kit": {"alloy": 30, "scrap": 20},
}
## Refits: per part id, levels 0..MAX_LEVEL, +REFIT_STEP to its scaling stats each.
const REFIT_STEP := 0.06
const REFIT_COST := [{"alloy": 25}, {"alloy": 50, "circuits": 2}, {"alloy": 90, "circuits": 4}]

var path := DEFAULT_PATH
## material -> amount banked
var stash := STARTING_STASH.duplicate()
var owned_weapons := ["smart_pistol"]
var equipped := "smart_pistol"
## weapon id -> {track: level}
var upgrades := {}
## attachment ids owned (shared by every gun)
var owned_attachments := []
## weapon id -> {slot: attachment id}
var fitted := {}
## weapon id -> finish id
var finishes := {}
## "slot:id" strings for titan parts owned
var owned_parts := []
## slot -> part id to start runs with ("scrap" for none)
var titan_loadout := {"chassis": "scrap", "weapon": "scrap", "core": "scrap", "kit": "scrap"}
## part id -> refit level (ids are unique across slots except "scrap", so key by "slot:id")
var refits := {}
var lifetime := {}


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path


static func open(p_path := DEFAULT_PATH) -> RefCounted:
	var a = load("res://scripts/hub/armory.gd").new(p_path)
	a.load_file()
	return a


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	stash.merge(cfg.get_value("armory", "stash", {}), true)
	lifetime = cfg.get_value("armory", "lifetime", {})
	owned_weapons = cfg.get_value("weapons", "owned", owned_weapons)
	equipped = cfg.get_value("weapons", "equipped", equipped)
	upgrades = cfg.get_value("weapons", "upgrades", {})
	owned_attachments = cfg.get_value("weapons", "attachments", [])
	fitted = cfg.get_value("weapons", "fitted", {})
	finishes = cfg.get_value("weapons", "finishes", {})
	owned_parts = cfg.get_value("titan", "owned", [])
	titan_loadout.merge(cfg.get_value("titan", "loadout", {}), true)
	refits = cfg.get_value("titan", "refits", {})
	if not WEAPONS.has(equipped) or not equipped in owned_weapons:
		equipped = "smart_pistol"


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("armory", "stash", stash)
	cfg.set_value("armory", "lifetime", lifetime)
	cfg.set_value("weapons", "owned", owned_weapons)
	cfg.set_value("weapons", "equipped", equipped)
	cfg.set_value("weapons", "upgrades", upgrades)
	cfg.set_value("weapons", "attachments", owned_attachments)
	cfg.set_value("weapons", "fitted", fitted)
	cfg.set_value("weapons", "finishes", finishes)
	cfg.set_value("titan", "owned", owned_parts)
	cfg.set_value("titan", "loadout", titan_loadout)
	cfg.set_value("titan", "refits", refits)
	cfg.save(path)


func amount(material: String) -> int:
	return int(stash.get(material, 0))


func can_afford(cost: Dictionary) -> bool:
	for m in cost:
		if amount(m) < int(cost[m]):
			return false
	return true


func _spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for m in cost:
		stash[m] = amount(m) - int(cost[m])
	return true


## Banks materials and saves.
func bank(materials: Dictionary) -> void:
	for m in materials:
		stash[m] = amount(m) + int(materials[m])
		lifetime[m] = int(lifetime.get(m, 0)) + int(materials[m])
	save()


## What a finished run banks from what you carried: everything plus the enemy
## titan's salvage on a win, half (rounded down) otherwise.
static func run_haul(carried: Dictionary, won: bool) -> Dictionary:
	var haul := {}
	for m in MATERIALS:
		var n := int(carried.get(m, 0))
		haul[m] = n + int(WIN_BONUS[m]) if won else int(floor(n * LOST_RUN_KEEP))
	return haul


## "40 scrap, 2 circuits", or "free".
static func cost_text(cost: Dictionary) -> String:
	var bits := []
	for m in MATERIALS:
		if int(cost.get(m, 0)) > 0:
			bits.append("%d %s" % [cost[m], m])
	return ", ".join(bits) if not bits.is_empty() else "free"


# --- pilot weapons --------------------------------------------------------------

func owns_weapon(id: String) -> bool:
	return id in owned_weapons


## Buys the gun if you don't have it. Returns false if you can't afford it.
func buy_weapon(id: String) -> bool:
	if owns_weapon(id):
		return true
	if not _spend(WEAPONS[id]["cost"]):
		return false
	owned_weapons.append(id)
	save()
	return true


func equip(id: String) -> bool:
	if not owns_weapon(id):
		return false
	equipped = id
	save()
	return true


func upgrade_level(weapon: String, track: String) -> int:
	return upgrades.get(weapon, {}).get(track, 0)


## Cost of the next level of a track, or {} when it's maxed.
func upgrade_cost(weapon: String, track: String) -> Dictionary:
	var level := upgrade_level(weapon, track)
	return UPGRADE_COST[level] if level < MAX_LEVEL else {}


func buy_upgrade(weapon: String, track: String) -> bool:
	if upgrade_level(weapon, track) >= MAX_LEVEL or not owns_weapon(weapon) or not _spend(upgrade_cost(weapon, track)):
		return false
	if not upgrades.has(weapon):
		upgrades[weapon] = {}
	upgrades[weapon][track] = upgrade_level(weapon, track) + 1
	save()
	return true


## The gun's look tier, 0 (stock) to MODEL_TIERS: every upgrade level bought
## moves it on, so a maxed gun (all three tracks at MAX_LEVEL) is the top model.
## The smart pistol has a model per tier (the gun's `tier` property picks it).
func weapon_tier(id: String) -> int:
	var total := 0
	for track in UPGRADE_ORDER:
		total += upgrade_level(id, track)
	return ceili(float(total) * MODEL_TIERS / (MAX_LEVEL * UPGRADE_ORDER.size()))


static func attachment(slot: String, id: String) -> Dictionary:
	for a in ATTACHMENTS[slot]:
		if a["id"] == id:
			return a
	return ATTACHMENTS[slot][0]


func owns_attachment(id: String) -> bool:
	return id == "stock" or id in owned_attachments


func fitted_attachment(weapon: String, slot: String) -> String:
	return fitted.get(weapon, {}).get(slot, "stock")


## Fits an attachment, buying it first if you don't own it yet.
func fit(weapon: String, slot: String, id: String) -> bool:
	if not owns_attachment(id):
		if not _spend(attachment(slot, id)["cost"]):
			return false
		owned_attachments.append(id)
	if not fitted.has(weapon):
		fitted[weapon] = {}
	fitted[weapon][slot] = id
	save()
	return true


static func finish(id: String) -> Dictionary:
	for f in FINISHES:
		if f["id"] == id:
			return f
	return FINISHES[0]


func finish_of(weapon: String) -> String:
	return finishes.get(weapon, "dads")


func set_finish(weapon: String, id: String) -> void:
	finishes[weapon] = id
	save()


## Everything weapon.gd's equip() needs: the gun's flags, its stats after
## upgrades and attachments, which attachments to bolt on, and its finish.
func weapon_profile(id := "") -> Dictionary:
	if id == "":
		id = equipped
	var base: Dictionary = WEAPONS[id]
	var stats: Dictionary = base["stats"].duplicate()
	stats["damage"] *= 1.0 + CALIBRE_STEP * upgrade_level(id, "calibre")
	stats["reload_time"] *= 1.0 - ACTION_STEP * upgrade_level(id, "action")
	stats["magazine_size"] += int(base["mag_step"]) * upgrade_level(id, "magazine")
	var parts := {}
	for slot in ATTACHMENT_SLOTS:
		var a := attachment(slot, fitted_attachment(id, slot))
		parts[slot] = a["id"]
		for key in a["mods"]:
			stats[key] *= a["mods"][key]
	stats["magazine_size"] = maxi(1, roundi(stats["magazine_size"]))
	var profile := base.duplicate()
	profile["id"] = id
	profile["tier"] = weapon_tier(id)
	profile["stats"] = stats
	profile["attachments"] = parts
	profile["finish"] = finish(finish_of(id))
	return profile


# --- titan ----------------------------------------------------------------------

static func part_key(slot: String, id: String) -> String:
	return "%s:%s" % [slot, id]


static func catalog_part(slot: String, id: String) -> Dictionary:
	for p in TitanParts.CATALOG[slot]:
		if p["id"] == id:
			return p
	return TitanParts.SCRAP[slot]


func owns_part(slot: String, id: String) -> bool:
	return id == "scrap" or part_key(slot, id) in owned_parts


func buy_part(slot: String, id: String) -> bool:
	if owns_part(slot, id):
		return true
	if not _spend(TITAN_PART_COST[slot]):
		return false
	owned_parts.append(part_key(slot, id))
	save()
	return true


## Picks the part a run starts with in `slot`, buying it first if needed.
func set_start_part(slot: String, id: String) -> bool:
	if not owns_part(slot, id) and not buy_part(slot, id):
		return false
	titan_loadout[slot] = id
	save()
	return true


## The parts a run starts with: Mk I of each chosen part; scrap slots stay empty.
func start_parts() -> Dictionary:
	var parts := {}
	for slot in TitanParts.SLOTS:
		var id: String = titan_loadout.get(slot, "scrap")
		if id != "scrap" and owns_part(slot, id):
			parts[slot] = TitanParts.make_part(slot, catalog_part(slot, id), 1)
	return parts


func refit_level(slot: String, id: String) -> int:
	return refits.get(part_key(slot, id), 0)


func refit_cost(slot: String, id: String) -> Dictionary:
	var level := refit_level(slot, id)
	return REFIT_COST[level] if level < MAX_LEVEL else {}


## Refits a part you own (scrap counts: everyone owns scrap).
func buy_refit(slot: String, id: String) -> bool:
	if refit_level(slot, id) >= MAX_LEVEL or not owns_part(slot, id) or not _spend(refit_cost(slot, id)):
		return false
	refits[part_key(slot, id)] = refit_level(slot, id) + 1
	save()
	return true


## slot:id -> stat multiplier, for TitanParts.assemble().
func refit_bonus() -> Dictionary:
	var bonus := {}
	for key in refits:
		bonus[key] = 1.0 + REFIT_STEP * refits[key]
	return bonus
