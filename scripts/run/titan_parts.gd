extends RefCounted
## Titan part catalog for the Scrap Titan run loop.
## A titan has four slots. Each run starts with scrap in every slot; salvage
## caches offer real parts, and whatever you hold at the end is your titan.
## Parts roll a tier (Mk I to III); later zones roll higher tiers.

const SLOTS := ["chassis", "weapon", "core", "kit"]
const SLOT_NAMES := {"chassis": "Chassis", "weapon": "Weapon", "core": "Core", "kit": "Kit"}
const TIER_NAMES := ["I", "II", "III"]
## Stats that grow with tier, by this much per tier above Mk I.
const SCALING := ["hp", "dps", "power"]
const TIER_STEP := 0.25

const CATALOG := {
	"chassis": [
		{"id": "atlas", "name": "Atlas Frame", "desc": "Balanced armor and speed.", "hp": 2400.0, "speed": 8.0, "dashes": 1},
		{"id": "ogre", "name": "Ogre Frame", "desc": "Heavy armor, slow on its feet.", "hp": 3400.0, "speed": 6.0, "dashes": 1},
		{"id": "stryder", "name": "Stryder Frame", "desc": "Light and fast, two dash charges.", "hp": 1700.0, "speed": 10.0, "dashes": 2},
	],
	"weapon": [
		{"id": "xo16", "name": "XO-16 Chaingun", "desc": "Steady high damage while on target.", "dps": 260.0},
		{"id": "tracker", "name": "40mm Tracker", "desc": "Lower damage, charges the core faster.", "dps": 200.0, "core_rate": 1.5},
		{"id": "splitter", "name": "Splitter Rifle", "desc": "Damage ramps up the longer you stay on target.", "dps": 170.0, "ramp": 0.8},
	],
	"core": [
		{"id": "laser", "name": "Laser Core", "desc": "Burst of heavy damage to the enemy titan.", "core": "laser", "power": 1500.0},
		{"id": "shield", "name": "Shield Core", "desc": "Restores a chunk of armor.", "core": "shield", "power": 0.4},
		{"id": "overdrive", "name": "Overdrive Core", "desc": "Double damage and full dashes for a few seconds.", "core": "overdrive", "power": 8.0},
	],
	"kit": [
		{"id": "thrusters", "name": "Thruster Kit", "desc": "One extra dash charge, faster recharge.", "kit": "thrusters", "power": 0.3},
		{"id": "plating", "name": "Plating Kit", "desc": "More armor.", "kit": "plating", "power": 0.25},
		{"id": "coolant", "name": "Coolant Kit", "desc": "Core charges faster.", "kit": "coolant", "power": 0.5},
	],
}

## What an empty slot falls back to. A titan of pure scrap should lose the final fight.
const SCRAP := {
	"chassis": {"id": "scrap", "name": "Scrap Frame", "hp": 1500.0, "speed": 7.0, "dashes": 1},
	"weapon": {"id": "scrap", "name": "Obelisk Rail", "dps": 110.0},
	"core": {"id": "scrap", "name": "No Core", "core": "none", "power": 0.0},
	"kit": {"id": "scrap", "name": "No Kit", "kit": "none", "power": 0.0},
}


static func make_part(slot: String, base: Dictionary, tier: int) -> Dictionary:
	var part := base.duplicate()
	part["slot"] = slot
	part["tier"] = tier
	var scale := 1.0 + TIER_STEP * (tier - 1)
	for key in SCALING:
		if part.has(key):
			part[key] = part[key] * scale
	part["display"] = "%s Mk %s" % [base["name"], TIER_NAMES[tier - 1]]
	return part


## Rolls `count` distinct parts. Tier odds by zone: zone 1 is Mk I or II,
## zone 2 can roll Mk III, zone 3 is never below Mk II.
static func roll_offer(rng: RandomNumberGenerator, zone_index: int, count: int) -> Array:
	var pool := []
	for slot in SLOTS:
		for base in CATALOG[slot]:
			pool.append([slot, base])
	var offer := []
	while offer.size() < count and not pool.is_empty():
		var pick: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		offer.append(make_part(pick[0], pick[1], roll_tier(rng, zone_index)))
	return offer


static func roll_tier(rng: RandomNumberGenerator, zone_index: int) -> int:
	var roll := rng.randf() + zone_index * 0.35
	if roll > 1.25:
		return 3
	if roll > 0.7:
		return 2
	return 1


static func display_name(parts: Dictionary, slot: String) -> String:
	if parts.has(slot):
		return parts[slot]["display"]
	return "%s (scrap)" % SCRAP[slot]["name"]


## One-line stat summary for the salvage choice screen.
static func describe(part: Dictionary) -> String:
	match part["slot"]:
		"chassis":
			return "%d armor, speed %.1f, %d dash" % [part["hp"], part["speed"], part["dashes"]]
		"weapon":
			return "%d damage/s" % part["dps"]
		"core":
			match part["core"]:
				"laser":
					return "%d burst damage" % part["power"]
				"shield":
					return "restores %d%% armor" % roundi(part["power"] * 100.0)
				"overdrive":
					return "%.0f s of double damage" % part["power"]
		"kit":
			match part["kit"]:
				"thrusters":
					return "+1 dash, %d%% faster recharge" % roundi(part["power"] * 100.0)
				"plating":
					return "+%d%% armor" % roundi(part["power"] * 100.0)
				"coolant":
					return "+%d%% core charge rate" % roundi(part["power"] * 100.0)
	return ""


## Turns the installed parts into the numbers the titan runs on.
## `refits` ("slot:id" -> multiplier, from the hub's titan workshop) scales a
## part's tier-scaled stats, scrap included.
static func assemble(parts: Dictionary, refits := {}) -> Dictionary:
	var chassis: Dictionary = _refit("chassis", parts.get("chassis", SCRAP["chassis"]), refits)
	var weapon: Dictionary = _refit("weapon", parts.get("weapon", SCRAP["weapon"]), refits)
	var core: Dictionary = _refit("core", parts.get("core", SCRAP["core"]), refits)
	var kit: Dictionary = _refit("kit", parts.get("kit", SCRAP["kit"]), refits)
	var stats := {
		"hp": float(chassis["hp"]),
		"speed": float(chassis["speed"]),
		"dashes": int(chassis["dashes"]),
		"dash_rate": 1.0,
		"dps": float(weapon["dps"]),
		"ramp": float(weapon.get("ramp", 0.0)),
		"core": String(core["core"]),
		"core_power": float(core["power"]),
		"core_rate": float(weapon.get("core_rate", 1.0)),
	}
	match kit["kit"]:
		"thrusters":
			stats["dashes"] += 1
			stats["dash_rate"] += kit["power"]
		"plating":
			stats["hp"] *= 1.0 + kit["power"]
		"coolant":
			stats["core_rate"] *= 1.0 + kit["power"]
	return stats


static func _refit(slot: String, part: Dictionary, refits: Dictionary) -> Dictionary:
	var key := "%s:%s" % [slot, part["id"]]
	if not refits.has(key):
		return part
	part = part.duplicate()
	for stat in SCALING:
		if part.has(stat):
			part[stat] = part[stat] * float(refits[key])
	return part
