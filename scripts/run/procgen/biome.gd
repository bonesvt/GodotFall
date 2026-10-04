extends RefCounted
## How each biome dresses a generated zone (zone_generator.gd): sky, ground,
## trees, cover, the buildings that make up a yard and a rooftop run, and what
## lies across a chasm for the quiet lane. All of it is the handmade zones'
## kit (forest_kit.gd, zone_kit.gd), so generated zones look like they belong
## next to the Pinewoods, Blackwater and the Boneyard, mixed with the
## generated zones' own set pieces (set_pieces.gd: bunkers, blockhouses,
## garages, silos, water towers, cranes, barriers and wrecks) so no two yards
## are built the same.
##
## Each zone draws its own mix of those pieces (kit()): a handful of props
## (always the biome's own), three kinds of building, two kinds of wall to
## wallrun, two climbs, a chasm crossing and a wall hook. Two zones of the
## same biome share the look but not the furniture.
##
## Two more kinds of area are built from their own kits (tools/procgen/
## build_kits.py, models in assets/models/city and assets/models/military):
##   city: the high tech city's streets. Paved ground, asphalt roads, glass
##     towers and shopfronts, holo-ad walls and security walls to wallrun,
##     drone pylons and monorail pillars to grapple, planters and streetlights
##     for trees, neon everywhere, rain and machine hum.
##   military: the colony's bases and outposts. Packed earth, tarmac roads,
##     hangars, barracks and command posts, HESCO and T-wall rows to wallrun,
##     comms and guard towers to grapple, APCs and AA guns, scrub pines.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const L := preload("res://scripts/run/laid_out.gd")
const SP := preload("res://scripts/run/procgen/set_pieces.gd")
const Ambience := preload("res://scripts/ambience.gd")

const CONCRETE := Color(0.55, 0.56, 0.55)
const CHAR := Color(0.42, 0.38, 0.36)
## The marsh's water surface.
const WATER_Y := -0.15


static func environment(root: Node3D, biome: String) -> void:
	match biome:
		"marsh":
			L.environment(root, Color(0.3, 0.36, 0.38), Color(0.72, 0.68, 0.54), 0.0085, Color(1.0, 0.76, 0.5), 0.95, -24.0)
			Ambience.start(root, {"swamp_creek": -11.0, "rain": -19.0, "forest_night": -21.0, "wind_soft": -20.0})
		"boneyard":
			L.environment(root, Color(0.34, 0.31, 0.33), Color(0.8, 0.62, 0.48), 0.0065, Color(1.0, 0.7, 0.45), 1.15, -20.0)
			Ambience.start(root, {"wind_soft": -11.0, "forest_wind": -17.0, "radio_static_loop": -32.0})
		"city":
			# Overcast dusk over the towers: cold haze, a low violet sun, the neon doing the rest.
			L.environment(root, Color(0.2, 0.22, 0.34), Color(0.52, 0.5, 0.66), 0.009, Color(0.95, 0.72, 0.85), 0.75, -18.0)
			Ambience.start(root, {"machine_hum": -16.0, "rain": -17.0, "wind_soft": -20.0})
		"military":
			# Dry, dusty midday over the base.
			L.environment(root, Color(0.4, 0.5, 0.6), Color(0.84, 0.78, 0.64), 0.0055, Color(1.0, 0.88, 0.7), 1.1, -42.0)
			Ambience.start(root, {"wind_soft": -11.0, "radio_static_loop": -26.0, "machine_hum": -25.0})
		_:
			Kit.environment(root, Color(0.3, 0.46, 0.6), Color(0.78, 0.82, 0.7))
			Ambience.start(root, {"forest_day": -10.0, "forest_wind": -17.0, "forest_birds": -19.0})


## [top tint, rock tint, top material, footstep surface] for the terrain.
static func ground_style(biome: String) -> Array:
	match biome:
		"marsh":
			return [Color(0.62, 0.66, 0.42), Color(0.7, 0.68, 0.6), "grass", "grass"]
		"boneyard":
			return [Color(0.6, 0.6, 0.64), Color(0.66, 0.64, 0.64), "dirt", "gravel"]
		"city":
			return [Color(0.86, 0.88, 0.94), Color(0.5, 0.52, 0.58), "pavers", "concrete"]
		"military":
			return [Color(0.78, 0.72, 0.6), Color(0.74, 0.7, 0.62), "dirt", "gravel"]
	return [Color(0.58, 0.72, 0.48), Color(0.8, 0.8, 0.74), "grass", "grass"]


static func road_material(biome: String) -> Material:
	match biome:
		"marsh":
			return Art.material("dirt", Color(0.85, 0.8, 0.7))
		"boneyard":
			return Art.material("dirt", Color(0.58, 0.55, 0.54))
		"city":
			return Art.material("asphalt")
		"military":
			return Art.material("tarmac", Color(0.9, 0.88, 0.84))
	return Art.material("dirt")


## A tree (or a burnt snag) with a trunk collider.
static func tree(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, scale := 1.0) -> void:
	match biome_of(root):
		"marsh":
			Z.cypress(root, pos - Vector3(0, 0.3, 0), rng, scale)
		"boneyard":
			var s := scale * rng.randf_range(0.85, 1.25)
			F.spawn(root, "snag", pos, rng.randf_range(0, 360), s, {"bark": CHAR})
			Z.column(root, pos, 0.4 * s, 7.0 * s)
		"city":
			# The city's trees are planters, streetlights and ad pillars.
			var roll := rng.randf()
			var id := "city_planter" if roll < 0.55 else ("city_streetlight" if roll < 0.8 else "city_ad_pillar")
			SP.place(root, id, pos - Vector3(0, 0.05, 0), [0.0, 90.0, 180.0, 270.0][rng.randi() % 4])
		"military":
			# Scrub pines round the base, thinned out and dry.
			F.tree(root, pos, rng, scale * 0.9, ["pine_a", "pine_b", "pine_c", "snag"][rng.randi() % 4])
		_:
			F.tree(root, pos, rng, scale)


## How thick the trees are between the lanes (0 to 1).
static func tree_density(biome: String) -> float:
	match biome:
		"marsh":
			return 0.42
		"boneyard":
			return 0.14
		"city":
			return 0.12
		"military":
			return 0.3
	return 0.66


## The zone root carries its biome as metadata so dressing helpers can ask.
static func biome_of(root: Node3D) -> String:
	return root.get_meta("biome", "forest")


## Props anyone might leave lying about, and each biome's own.
const SHARED_PROPS := ["jersey_barrier", "tank_trap", "tire_stack", "cable_reel", "jeep", "fire_barrel", "pipe_stack",
		"supply_pod", "ammo_crates", "comms_dish", "lamp_post", "tarp_shelter", "field_table"]
const BIOME_PROPS := {
	"forest": ["lumber_stack", "woodpile"],
	"marsh": ["rowboat", "net_rack", "buoy"],
	"boneyard": ["rib_arch", "hull_plate", "engine_block"],
}
const BUILDINGS := ["bunker", "blockhouse", "garage", "cabin", "quonset", "radio_hut", "blockhouse_low"]
const WALLS := ["billboard", "blast", "panel_wall", "container_wall", "hull_wall"]
const CLIMBS := ["kick_slot", "scaffold", "corner_kick", "pillar_ledge"]
## The city's and the bases' own kits: their props (all of them, plus a few of
## the shared ones that suit the place), buildings and walls.
const KIT_PROPS := {
	"city": ["city_barricade", "city_hovercar", "city_kiosk", "city_planter", "city_ad_pillar", "city_dumpster",
			"city_hvac", "city_tram_stop", "city_traffic_light", "city_overpass", "city_streetlight"],
	"military": ["mil_footlockers", "mil_sandbag_wall", "mil_apc", "mil_generator", "mil_searchlight",
			"mil_fuel_bladder", "mil_aa_gun", "mil_camo_shelter", "mil_razor_fence", "mil_artillery", "mil_tent_large"],
}
const KIT_SHARED := {
	"city": ["jersey_barrier", "cable_reel", "supply_pod", "fire_barrel"],
	"military": ["jersey_barrier", "tank_trap", "tire_stack", "jeep", "supply_pod", "ammo_crates", "comms_dish",
			"field_table", "tarp_shelter", "fire_barrel"],
}
const KIT_BUILDINGS := {
	"city": ["city_shopfront", "city_apartment", "city_shopfront", "city_apartment", "city_stairs_plaza", "garage"],
	"military": ["mil_barracks", "mil_command", "mil_ammo_bunker", "bunker", "blockhouse", "quonset"],
}
const KIT_WALLS := {
	"city": ["city_holo_wall", "city_security_wall"],
	"military": ["mil_hesco_wall", "mil_t_wall"],
}
## The big piece in a yard's corner, and a camp's centrepiece.
const KIT_LANDMARKS := {
	"city": ["city_drone_pylon", "city_billboard_tower", "city_checkpoint", "city_drone_pylon"],
	"military": ["mil_comms_tower", "mil_guard_tower", "mil_radar", "mil_gate", "water_tower"],
}
const KIT_CENTREPIECE := {"city": "city_tower", "military": "mil_hangar"}
## What each use of a prop takes, by the room it has.
const LOW_PROPS := ["jersey_barrier", "ammo_crates", "woodpile", "buoy",
		"city_barricade", "city_dumpster", "city_planter", "mil_footlockers", "mil_sandbag_wall"]
const TALL_PROPS := ["pipe_stack", "engine_block", "net_rack", "city_kiosk", "city_ad_pillar", "city_hvac", "mil_generator", "mil_apc"]
const WILD_PROPS := ["jeep", "tank_trap", "supply_pod", "tire_stack", "cable_reel", "hull_plate", "engine_block", "rowboat",
		"lumber_stack", "woodpile", "buoy", "city_hovercar", "city_dumpster", "city_barricade", "mil_apc", "mil_footlockers",
		"mil_sandbag_wall", "mil_generator"]
const YARD_PROPS := ["fire_barrel", "tire_stack", "cable_reel", "jersey_barrier", "supply_pod", "ammo_crates", "comms_dish",
		"lamp_post", "field_table", "woodpile", "buoy", "engine_block", "city_kiosk", "city_hvac", "city_dumpster",
		"city_hovercar", "city_ad_pillar", "city_traffic_light", "mil_generator", "mil_searchlight", "mil_footlockers",
		"mil_aa_gun", "mil_razor_fence"]
## Too big for a cover slot: set down where there's room (zone_generator._traversal).
const BIG_PROPS := ["rib_arch", "tarp_shelter", "rowboat", "hull_plate", "lumber_stack", "net_rack", "comms_dish",
		"city_tram_stop", "city_overpass", "mil_fuel_bladder", "mil_camo_shelter", "mil_artillery", "mil_tent_large"]


## This zone's mix of set pieces, from its own seed:
##   props: 7-9 ids, the biome's own first; buildings: 3; walls: 2 (wallrun);
##   climbs: 2; chasm: "towers" (a shield hung between lattice towers) or
##   "pier"; wall_hook: "bracket" (on the wall's top) or "pole" (behind it).
static func kit(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	if KIT_PROPS.has(biome):
		return _own_kit(biome, rng)
	var props: Array = BIOME_PROPS.get(biome, []).duplicate()
	var shared := _shuffled(SHARED_PROPS, rng)
	var want := rng.randi_range(7, 9)
	while props.size() < want and not shared.is_empty():
		props.append(shared.pop_back())
	var walls := _shuffled(WALLS, rng)
	if biome == "boneyard" and not "hull_wall" in walls.slice(0, 2):
		walls[1] = "hull_wall"  # the Boneyard's walls are made of titans
	return {
		"props": props,
		"buildings": _shuffled(BUILDINGS, rng).slice(0, 3),
		"walls": walls.slice(0, 2),
		"climbs": _shuffled(CLIMBS, rng).slice(0, 2),
		"chasm": "towers" if rng.randf() < 0.5 else "pier",
		"wall_hook": "pole" if rng.randf() < 0.5 else "bracket",
	}


## The city's or a base's mix: most of its own props and a couple of the
## shared ones, three of its buildings, both its walls and the shared climbs.
static func _own_kit(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var own := _shuffled(KIT_PROPS[biome].filter(func(id): return SP.has(id)), rng)
	var props: Array = own.slice(0, maxi(own.size() - 2, 1))
	var shared := _shuffled(KIT_SHARED[biome], rng)
	props.append_array(shared.slice(0, 2))
	var buildings := []
	for id in _shuffled(KIT_BUILDINGS[biome].filter(func(id): return SP.has(id)), rng):
		if buildings.size() < 3 and not id in buildings:
			buildings.append(id)
	var walls: Array = _shuffled(KIT_WALLS[biome].filter(func(id): return SP.has(id)), rng)
	if walls.size() < 2:
		walls.append("blast")
	return {
		"props": props,
		"buildings": buildings,
		"walls": walls.slice(0, 2),
		"climbs": _shuffled(CLIMBS, rng).slice(0, 2),
		"chasm": "towers" if rng.randf() < 0.5 else "pier",
		"wall_hook": "pole" if rng.randf() < 0.5 else "bracket",
	}


static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	var out := a.duplicate()
	for k in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = out[k]
		out[k] = out[j]
		out[j] = t
	return out


## One of this zone's props that suits `allowed`, or "" (none in the mix, or
## outside a build: the old kit then).
static func kit_prop(root: Node3D, rng: RandomNumberGenerator, allowed: Array) -> String:
	var info = _info(root)
	if info == null or not info.has("kit"):
		return ""
	var ok := (info["kit"]["props"] as Array).filter(func(id): return id in allowed)
	return "" if ok.is_empty() else ok[rng.randi() % ok.size()]


## The zone's info while it's being built (zone_generator.gd sets it), so set
## pieces note their hooks and walls; null outside a build.
static func _info(root: Node3D):
	return root.get_meta("zone_info", null)


## Low cover (crouch behind it), about 2 m wide and 1.2 m high.
static func cover_low(root: Node3D, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.35:
		var id := kit_prop(root, rng, LOW_PROPS)
		if id != "":
			SP.place(root, id, pos - Vector3(0, 0.05, 0), yaw, _info(root))
			return
	match biome_of(root):
		"boneyard":
			if rng.randf() < 0.5:
				Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.sandbags(root, pos, yaw)
		"city":
			SP.place(root, "city_barricade", pos - Vector3(0, 0.05, 0), yaw, _info(root))
		"military":
			SP.place(root, "mil_sandbag_wall" if rng.randf() < 0.6 else "jersey_barrier", pos - Vector3(0, 0.05, 0), yaw, _info(root))
		_:
			F.sandbags(root, pos, yaw)


## Tall cover (stand behind it).
static func cover_tall(root: Node3D, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.3:
		var id := kit_prop(root, rng, TALL_PROPS)
		if id != "":
			SP.place(root, id, pos - Vector3(0, 0.05, 0), yaw + 90.0, _info(root))
			return
	match biome_of(root):
		"boneyard":
			if rng.randf() < 0.5:
				Z.titan_arm(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.crate_stack(root, pos, yaw)
		"city":
			SP.place(root, ["city_kiosk", "city_hvac", "city_ad_pillar"][rng.randi() % 3], pos - Vector3(0, 0.05, 0), yaw + 90.0, _info(root))
		_:
			F.crate_stack(root, pos, yaw)


## Cover out in the wilds: a log, a boulder, a wreck.
static func wild_cover(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(0, 360)
	var id := kit_prop(root, rng, WILD_PROPS) if rng.randf() < 0.35 else ""
	if id != "":
		# Left behind: a burnt-out jeep, tank traps, a drop pod, the biome's own junk.
		SP.place(root, id, pos - Vector3(0, 0.05, 0), yaw, _info(root))
		if id == "tank_trap":
			for k in 2:
				var a := rng.randf_range(0, TAU)
				SP.place(root, id, pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.0, 3.0) - Vector3(0, 0.05, 0), rng.randf_range(0, 360), _info(root))
		return
	match biome_of(root):
		"city":
			SP.place(root, ["city_hovercar", "city_dumpster", "city_barricade"][rng.randi() % 3], pos - Vector3(0, 0.05, 0), yaw, _info(root))
		"military":
			if rng.randf() < 0.5:
				SP.place(root, ["mil_apc", "mil_footlockers", "mil_sandbag_wall", "tank_trap"][rng.randi() % 4], pos - Vector3(0, 0.05, 0), yaw, _info(root))
			else:
				F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], pos, yaw, rng.randf_range(1.0, 2.0))
		"boneyard":
			match rng.randi() % 3:
				0:
					Z.titan_arm(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
				1:
					Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
				_:
					F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], pos, yaw, rng.randf_range(1.0, 2.2))
		_:
			if rng.randf() < 0.4:
				F.fallen_log(root, pos - Vector3(0, 0.1, 0), yaw)
			else:
				F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], pos, yaw, rng.randf_range(1.0, 2.4))


## What a rooftop run is built from, picked once per run: the biome's own
## (forest huts, stilt huts, stacked containers), a scaffold, or bunkers.
## {id, length (along Z), width (along X)}.
static func perch_style(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	if biome in ["city", "military"]:
		# Scaffolds over the street, or stacked containers (the tram stops and
		# barracks sit too low to step on from a ridge).
		if roll < 0.55:
			return {"id": "scaffold", "length": 6.2, "width": 7.0}
		return {"id": "containers", "length": 6.0, "width": 2.4}
	if roll < 0.25:
		return {"id": "scaffold", "length": 6.2, "width": 7.0}
	if roll < 0.4:
		return {"id": "bunker", "length": 6.4, "width": 5.4}
	match biome:
		"marsh":
			return {"id": "stilt_hut", "length": 6.1, "width": 4.8}
		"boneyard":
			return {"id": "containers", "length": 6.0, "width": 2.4}
	return {"id": "hut", "length": 8.2, "width": 5.2}


## The building a rooftop run is made of, its long side along Z. Returns
## {roof: top centre of its roof, length: along Z, width: along X}. `toward`
## is which way the road is (+1 or -1 in x), for a scaffold's steps.
static func perch(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, style := {}, toward := 1.0) -> Dictionary:
	if style.is_empty():
		style = perch_style(biome_of(root), rng)
	match style["id"]:
		"scaffold":
			var placed := SP.place(root, "scaffold", pos, 0.0 if toward > 0.0 else 180.0, _info(root))
			return {"roof": placed["tops"][0], "length": style["length"], "width": style["width"]}
		"bunker":
			var placed := SP.place(root, "bunker", pos, 90.0, _info(root))
			return {"roof": placed["tops"][0], "length": style["length"], "width": style["width"]}
		"stilt_hut":
			# Stilt huts with their posts sunk in: the roof is 3.9 m up.
			var roof := Z.stilt_hut(root, pos - Vector3(0, 1.5, 0), 90.0)
			return {"roof": roof, "length": 6.1, "width": 4.8}
		"containers":
			# Two containers stacked: 5.2 m up.
			var tint: Color = Z.CONTAINER_TINTS[rng.randi() % Z.CONTAINER_TINTS.size()]
			var top := Z.container(root, pos, 90.0, tint)
			var roof := Z.container(root, top, 90.0 + rng.randf_range(-3, 3), Z.CONTAINER_TINTS[(rng.randi() + 1) % Z.CONTAINER_TINTS.size()])
			return {"roof": roof, "length": 6.0, "width": 2.4}
	var hut_roof := F.hut(root, pos, 90.0)
	return {"roof": hut_roof, "length": 8.2, "width": 5.2}


## A mast to swing from between two lanes: the city swaps its masts for drone
## pylons and monorail pillars, a base for its radio towers.
static func mast(id: String, biome: String, rng: RandomNumberGenerator) -> String:
	if id == "scaffold_roost":
		return id
	var own: Array = {"city": ["city_drone_pylon", "city_drone_pylon", "city_billboard_tower", "city_monorail"],
			"military": ["mil_comms_tower", "grapple_mast_short"]}.get(biome, []).filter(func(m): return SP.has(m))
	return own[rng.randi() % own.size()] if not own.is_empty() and rng.randf() < 0.8 else id


## A yard's barracks, broadside to the road (long along X). Returns its footprint size (x, z).
static func barracks(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Vector2:
	var roll := rng.randf()
	var info = _info(root)
	if roll < 0.6 or KIT_PROPS.has(biome_of(root)):
		# One of the zone's three kinds: a bunker, a two-storey blockhouse
		# (stairs up to a hook on its roof), a garage, a cabin, a quonset hut, a
		# radio hut (a mast with a hook) or a low blockhouse.
		var kinds: Array = info["kit"]["buildings"] if info != null and info.has("kit") else ["bunker", "blockhouse", "garage"]
		var id: String = kinds[mini(int(roll / 0.6 * kinds.size()), kinds.size() - 1)] if roll < 0.6 else kinds[rng.randi() % kinds.size()]
		# A quonset's long side along X, like the rest.
		var yaw := 90.0 if id == "quonset" else 0.0
		SP.place(root, id, pos, yaw, info)
		return SP.turned_size(id, yaw)
	match biome_of(root):
		"marsh":
			Z.stilt_hut(root, pos - Vector3(0, 1.5, 0), 0.0)
			return Vector2(6.2, 6.2)
		"boneyard":
			Z.container(root, pos, 0.0, Z.CONTAINER_TINTS[rng.randi() % Z.CONTAINER_TINTS.size()])
			Z.container(root, pos + Vector3(0, 0, 3.0), 0.0, Z.CONTAINER_TINTS[(rng.randi() + 2) % Z.CONTAINER_TINTS.size()])
			return Vector2(6.0, 5.6)
	F.hut(root, pos, 0.0)
	return Vector2(8.2, 5.2)


## A camp's big building. Returns its footprint size (x, z).
static func centrepiece(root: Node3D, pos: Vector3, rng: RandomNumberGenerator = null) -> Vector2:
	var own: String = KIT_CENTREPIECE.get(biome_of(root), "")
	if own != "" and SP.has(own) and rng != null:
		SP.place(root, own, pos, 0.0, _info(root))
		return SP.size(own)
	if rng != null and rng.randf() < 0.4:
		SP.place(root, "warehouse", pos, 0.0, _info(root))
		return SP.size("warehouse")
	match biome_of(root):
		"city", "military":
			# No room for the big one: a building of the zone's instead.
			var kinds: Array = _info(root)["kit"]["buildings"] if _info(root) != null else ["bunker"]
			var id: String = kinds[0]
			SP.place(root, id, pos, 0.0, _info(root))
			return SP.size(id)
		"marsh":
			Z.pump_house(root, pos, 90.0)
			return Vector2(11.0, 19.0)
		"boneyard":
			Z.salvage_shed(root, pos, 0.0)
			return Vector2(12.4, 8.4)
	F.sawmill(root, pos, 0.0)
	return Vector2(12.4, 8.4)


## Clutter round a yard: something to hide behind that fits in about 3 x 3 m.
static func yard_clutter(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(0, 360)
	var pick := rng.randi() % 10
	if KIT_PROPS.has(biome_of(root)):
		pick = 9  # the kit's own clutter only
	if pick >= 5:
		var id := kit_prop(root, rng, YARD_PROPS)
		if id != "":
			SP.place(root, id, pos - Vector3(0, 0.05, 0), yaw, _info(root))
			return
		pick = 4
	match pick:
		0:
			F.barrels(root, pos, yaw)
		1:
			F.pallet(root, pos, yaw)
		2:
			F.generator(root, pos, yaw)
		3:
			if biome_of(root) == "forest":
				F.log_pile(root, pos, yaw)
			elif biome_of(root) == "boneyard":
				Z.scrap_pile(root, pos, yaw, Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()])
			else:
				F.barrels(root, pos, yaw)
		_:
			F.crate_stack(root, pos, yaw)


## The big piece in a yard's far corner: a fuel tank, a storage tank, a gantry.
static func landmark(root: Node3D, pos: Vector3, rng: RandomNumberGenerator = null) -> Vector2:
	var own: Array = KIT_LANDMARKS.get(biome_of(root), []).filter(func(id): return SP.has(id) and SP.size(id).x <= 10.5 and SP.size(id).y <= 10.5)
	if not own.is_empty():
		var id: String = own[(rng.randi() if rng != null else 0) % own.size()]
		var yaw: float = [0.0, 90.0, 180.0, 270.0][rng.randi() % 4] if rng != null else 0.0
		SP.place(root, id, pos, yaw, _info(root))
		return SP.turned_size(id, yaw)
	if rng != null and rng.randf() < 0.6:
		# Something tall with a hook on top to grapple: a silo, a water tower, a crane.
		var id: String = ["silo", "water_tower", "tower_crane"][rng.randi() % 3]
		SP.place(root, id, pos, [0.0, 90.0, 180.0, 270.0][rng.randi() % 4], _info(root))
		return SP.size(id)
	match biome_of(root):
		"marsh":
			Z.storage_tank(root, pos)
			return Vector2(7.4, 7.4)
		"boneyard":
			Z.titan_kneeling(root, pos, 180.0, Z.HULL_TINTS[1])
			return Vector2(8.0, 6.0)
	F.fuel_tank(root, pos, 0.0)
	return Vector2(6.2, 2.8)


## Lies across a chasm along Z for the quiet lane, its walkable top at `top`
## (the lip's height). `z` is the chasm's middle.
static func quiet_crossing(root: Node3D, x: float, top: float, z: float) -> void:
	match biome_of(root):
		"marsh", "city", "military":
			# A downed titan across the gap (in the city, off a collapsed overpass).
			Z.titan_fallen(root, Vector3(x, top + 0.3, z), 90.0, Z.HULL_TINTS[0 if biome_of(root) != "military" else 2])
		"boneyard":
			Z.obelisk_fallen(root, Vector3(x, top + 0.3, z), 90.0)
		_:
			F.log_bridge(root, Vector3(x, top - 0.3, z), 90.0)


## Water at the bottom of a chasm, `width` across X.
static func chasm_floor(root: Node3D, center: Vector3, size: Vector2) -> void:
	if biome_of(root) in ["boneyard", "military"]:
		return
	if biome_of(root) == "city":
		# A storm drain: black water with an oily shine.
		L.water(root, center, size, Color(0.05, 0.07, 0.1, 0.96))
		return
	L.water(root, center, size, Color(0.2, 0.42, 0.45, 0.95) if biome_of(root) == "forest" else Color(0.09, 0.12, 0.08, 0.95))


## A wreck to mine for alloy: a titan lying along Z. Returns its footprint (x, z).
static func wreck(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Vector2:
	var tint: Color = Z.HULL_TINTS[rng.randi() % Z.HULL_TINTS.size()]
	if rng.randf() < 0.5:
		Z.titan_fallen(root, pos + Vector3(0, 3.4, 0), 90.0 + rng.randf_range(-12, 12), tint)
		return Vector2(7.0, 26.0)
	Z.titan_kneeling(root, pos, rng.randf_range(0, 360), tint)
	Z.titan_arm(root, pos + Vector3(5.5, 0, 4.0), rng.randf_range(0, 360), tint)
	return Vector2(12.0, 12.0)


## A hiding patch (tall grass, reeds, dead grass); see forest_kit.grass_patch.
static func hide(root: Node3D, ground: Callable, rng: RandomNumberGenerator, info: Dictionary, x: float, z: float,
		size: Vector2, dense := false, yaw := 0.0) -> void:
	L.hide(root, ground, rng, info, x, z, size, dense, yaw)


## Batches everything the zone gathered into info["tall_grass"].
static func finish_grass(root: Node3D, info: Dictionary, grass: Array) -> void:
	match biome_of(root):
		"marsh":
			Z.scatter(root, "reeds", info["tall_grass"], {"grass_blade": Color(0.72, 0.74, 0.5), "bark": Color(0.6, 0.45, 0.35)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.74, 0.74, 0.5)}, false)
		"boneyard", "military":
			F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.9, 0.78, 0.52)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.82, 0.74, 0.55)}, false)
		"city":
			# Overgrown verges: dark, wet weeds pushing up through the paving.
			F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.5, 0.66, 0.5)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.46, 0.6, 0.48)}, false)
		_:
			F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.75, 0.8, 0.55)}, false)
			F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.68, 0.8, 0.58)}, false)
	info["tall_grass"] = []


## Trees beyond the hillsides (no collision) and hills on the horizon.
static func far_scenery(root: Node3D, rng: RandomNumberGenerator, plan, ground: Callable) -> void:
	var biome: String = plan.biome
	if biome == "city" and SP.has("city_tower"):
		_skyline(root, rng, plan, ground)
		return
	var ids: Array
	var tints := {}
	match biome:
		"marsh":
			ids = ["cypress_a", "cypress_b", "cypress_dead"]
			tints = {"leaves": Z.CYPRESS_TINTS[0], "grass_blade": Z.MOSS_BEARD}
		"boneyard":
			ids = ["snag", "snag", "pine_a"]
			tints = {"bark": CHAR, "leaves": F.NEEDLE_TINTS[0]}
		"military":
			ids = ["pine_a", "pine_b", "snag"]
			tints = {"leaves": Color(0.56, 0.6, 0.44)}
		_:
			ids = ["pine_a", "pine_b", "pine_c", "tree_a", "snag"]
			tints = {"leaves": F.NEEDLE_TINTS[0]}
	var far := {}
	for id in ids:
		far[id] = []
	var z: float = plan.z_top + 40.0
	while z > plan.z_bottom - 40.0:
		for side in [-1.0, 1.0]:
			var w: float = plan.half_width(z)
			var d := w + 5.0
			while d < w + 70.0:
				var px: float = plan.center_x(z) + side * (d + rng.randf_range(-2.0, 2.0))
				var pz := z + rng.randf_range(-2.5, 2.5)
				var id: String = ids[rng.randi() % ids.size()]
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
				far[id].append(Transform3D(basis, Vector3(px, ground.call(px, pz) - 0.3, pz)))
				d += rng.randf_range(4.5, 7.5) * (2.2 if biome == "boneyard" else (1.8 if biome == "military" else 1.0))
		z -= 5.0
	# Across both ends of the valley too.
	for band in [[plan.z_top - 6.0, plan.z_top + 40.0], [plan.z_bottom - 40.0, plan.z_bottom + 6.0]]:
		for i in 260:
			var pz := rng.randf_range(band[0], band[1])
			var px: float = plan.center_x(pz) + rng.randf_range(-plan.half_width(pz) - 20.0, plan.half_width(pz) + 20.0)
			var id: String = ids[i % ids.size()]
			far[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), Vector3(px, ground.call(px, pz) - 0.3, pz)))
	for id in far:
		Z.scatter(root, id, far[id], tints)
	var mid: float = (plan.z_top + plan.z_bottom) * 0.5
	var reach: float = (plan.z_top - plan.z_bottom) * 0.5 + 120.0
	for i in 16:
		var ang := TAU * i / 16.0
		var base := Vector3(sin(ang) * 240.0, -6.0, mid + cos(ang) * reach)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.0, 1.4),
				{"hill_forest": Color(0.7, 0.85, 0.75) if not biome in ["boneyard", "military"] else Color(0.7, 0.62, 0.58)})


## The city past the valley's walls: rows of towers (no collision, nobody goes
## there) climbing away on both sides and across both ends, every one lit.
static func _skyline(root: Node3D, rng: RandomNumberGenerator, plan, ground: Callable) -> void:
	var placed := []
	var z: float = plan.z_top + 30.0
	while z > plan.z_bottom - 30.0:
		for side in [-1.0, 1.0]:
			var w: float = plan.half_width(z)
			var d := w + 14.0
			while d < w + 110.0:
				var px: float = plan.center_x(z) + side * (d + rng.randf_range(-3.0, 3.0))
				var s := rng.randf_range(0.8, 1.5) * (1.0 + (d - w) / 120.0)
				placed.append(Transform3D(Basis(Vector3.UP, deg_to_rad([0.0, 90.0, 180.0, 270.0][rng.randi() % 4])).scaled(Vector3(1.0, s, 1.0) * rng.randf_range(0.9, 1.2)),
						Vector3(px, ground.call(px, z) - 1.0, z + rng.randf_range(-4.0, 4.0))))
				d += rng.randf_range(16.0, 24.0)
		z -= 22.0
	for band in [[plan.z_top + 20.0, plan.z_top + 120.0], [plan.z_bottom - 120.0, plan.z_bottom - 20.0]]:
		for i in 40:
			var pz := rng.randf_range(band[0], band[1])
			var px: float = plan.center_x(pz) + rng.randf_range(-plan.half_width(pz) - 60.0, plan.half_width(pz) + 60.0)
			placed.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(1.0, rng.randf_range(0.8, 1.8), 1.0)),
					Vector3(px, ground.call(px, pz) - 1.0, pz)))
	SP.scatter(root, "city_tower", placed, "city")
