extends RefCounted
## Materials out in the levels, for the hub's workbenches (scripts/hub/armory.gd):
##   grunts drop scrap when they die, now and then a circuit
##   small supply crates (loot_crate.gd): F pries one open for scrap and circuits
##   alloy nodes (resource_node.gd): hold F to mine a buried titan wreck for alloy
## Everything drops as pickups (material_pickup.gd) that fly to the pilot when
## she gets close, and the run carries them until it ends (run_manager.gd banks
## them: all of it on an extraction, half on a lost run).
##
## scatter() places crates and nodes in a zone after it's built, on the forest's
## routes (zone 1) or on the platforms (later zones), so level builders need no
## changes. They settle onto the ground themselves on their first physics frame.

const LootArt := preload("res://scripts/run/loot_art.gd")
const LootCrate := preload("res://scripts/run/loot_crate.gd")
const ResourceNode := preload("res://scripts/run/resource_node.gd")
const Pickup := preload("res://scripts/run/material_pickup.gd")

## How many of each a zone gets: forest, then the platform zones.
const CRATES := [7, 4, 5]
const NODES := [3, 2, 2]
## Loot keeps this far from the spawn and from other loot (m).
const SPAWN_CLEAR := 14.0
const SPACING := 16.0
## Pickups fly to the pilot inside this range and are collected inside COLLECT.
const MAGNET := 5.0
const COLLECT := 0.9


## What a dead grunt drops.
static func roll_grunt(rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	var drop := {"scrap": rng.randi_range(3, 6) + zone_index}
	if rng.randf() < 0.15 + 0.05 * zone_index:
		drop["circuits"] = 1
	return drop


## What a supply crate holds.
static func roll_crate(rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	var loot := {"scrap": rng.randi_range(6, 12) + zone_index * 2}
	if rng.randf() < 0.4 + 0.1 * zone_index:
		loot["circuits"] = rng.randi_range(1, 2)
	return loot


## What an alloy node yields once mined out.
static func roll_node(rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	return {"alloy": rng.randi_range(8, 12) + zone_index * 3}


## Spills `materials` as pickups around `pos`: one pickup per few units, so a
## big haul is a shower of bits. Returns the pickups.
static func drop(parent: Node, pos: Vector3, materials: Dictionary, rng: RandomNumberGenerator) -> Array:
	var made := []
	for kind in materials:
		var left := int(materials[kind])
		var per := 1 if kind == "circuits" else 3
		while left > 0:
			var n := mini(per, left)
			left -= n
			var p := Pickup.new()
			p.kind = kind
			p.amount = n
			parent.add_child(p)
			p.global_position = pos + Vector3(0, 0.6, 0)
			var a := rng.randf() * TAU
			p.velocity = Vector3(cos(a) * rng.randf_range(1.0, 3.0), rng.randf_range(3.5, 5.5), sin(a) * rng.randf_range(1.0, 3.0))
			made.append(p)
	return made


## Places supply crates and alloy nodes in a built zone. Adds "loot" (crates
## and nodes) to info.
static func scatter(root: Node3D, info: Dictionary, rng: RandomNumberGenerator, zone_index: int) -> void:
	var spots := _candidates(info, rng)
	var spawn: Vector3 = info["spawn"]
	var taken: Array = []
	info["loot"] = []
	var want := [["node", NODES[mini(zone_index, NODES.size() - 1)]], ["crate", CRATES[mini(zone_index, CRATES.size() - 1)]]]
	for entry in want:
		var placed := 0
		for spot in spots:
			if placed >= entry[1]:
				break
			if spot.distance_to(spawn) < SPAWN_CLEAR or taken.any(func(t): return t.distance_to(spot) < SPACING):
				continue
			taken.append(spot)
			placed += 1
			var node: Node3D = ResourceNode.new() if entry[0] == "node" else LootCrate.new()
			node.loot = roll_node(rng, zone_index) if entry[0] == "node" else roll_crate(rng, zone_index)
			node.kill_y = float(info.get("kill_y", float(info["floor_y"]) - 15.0))
			root.add_child(node)
			node.position = spot
			node.rotation.y = rng.randf() * TAU
			info["loot"].append(node)


## Places to try, shuffled: beside the forest's routes, or on platforms.
static func _candidates(info: Dictionary, rng: RandomNumberGenerator) -> Array:
	var spots := []
	for route in info.get("routes", []):
		var pts: PackedVector3Array = route["points"]
		for i in range(1, pts.size() - 1):
			var dir := (pts[i + 1] - pts[i - 1])
			dir.y = 0.0
			if dir.length() < 0.1:
				continue
			var side := Vector3(-dir.z, 0, dir.x).normalized() * rng.randf_range(2.5, 6.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			spots.append(pts[i] + side)
	if spots.is_empty():
		for p in info.get("platforms", []):
			var top: Vector3 = p["top"]
			var size: Vector2 = p["size"]
			spots.append(top + Vector3(rng.randf_range(-0.35, 0.35) * size.x, 0, rng.randf_range(-0.35, 0.35) * size.y))
	# Fisher-Yates with the run's rng, so a seed always lays loot out the same.
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = spots[i]
		spots[i] = spots[j]
		spots[j] = t
	return spots
