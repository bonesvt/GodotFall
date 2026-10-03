extends RefCounted
## Builds run zones from the run's RNG.
## A zone is a chain of platforms over a void heading -Z, linked by traversal
## gaps (jump, wallrun, grapple, climb). Grunt squads hold some platforms from
## behind cover, and every platform past the spawn has cover for the pilot too.
## Two side platforms hold salvage caches, one of them guarded by a squad that
## must be cleared to unlock it. The last platform has the extraction beacon.
## Zones 1 to 3 are laid out by hand instead: the Pinewoods (forest_builder.gd),
## Blackwater (marsh_builder.gd) and the Boneyard (boneyard_builder.gd). The
## platform chain (build_chain) is what any zone past those gets. The arena,
## where the titan fight happens, is the forest's edge (forest_builder.gd).

const Kit := preload("res://scripts/run/level_kit.gd")
const SalvageCache := preload("res://scripts/run/salvage_cache.gd")
const SquadObjective := preload("res://scripts/run/squad_objective.gd")
const GruntScript := preload("res://scripts/grunt.gd")
const ExtractBeacon := preload("res://scripts/run/extract_beacon.gd")
const ForestBuilder := preload("res://scripts/run/forest_builder.gd")
const MarshBuilder := preload("res://scripts/run/marsh_builder.gd")
const BoneyardBuilder := preload("res://scripts/run/boneyard_builder.gd")

## Gap ranges in metres between platform edges, kept inside what the pilot can
## clear: a sprint jump covers about 6 m (9 m with the double jump), a wallrun
## about 18 m, the grapple 45 m.
const GAPS := {
	"jump": Vector2(4.0, 6.5),
	"wallrun": Vector2(13.0, 17.0),
	"grapple": Vector2(15.0, 20.0),
	"climb": Vector2(2.5, 3.5),
}
const WEIGHTS := {"jump": 3.0, "wallrun": 2.0, "grapple": 1.5, "climb": 1.5}
## A double jump peaks around 2.4 m, so climbs rise a little under that.
const CLIMB_RISE := 2.0
const SIDE_GAP := 5.0
## Chance that a path platform holds a grunt squad, per zone.
const SQUAD_CHANCE := [0.45, 0.6, 0.75]
## Cover keeps this much of each platform's centre line clear for running and landing.
const LANE_HALF := 1.5
const COVER := Color(0.42, 0.44, 0.4)

const GREY := Color(0.55, 0.57, 0.6)
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const ZONE_TINTS := [Color(0.62, 0.6, 0.55), Color(0.5, 0.58, 0.62), Color(0.62, 0.5, 0.5)]
const ZONE_SKIES := [
	[Color(0.3, 0.45, 0.7), Color(0.75, 0.8, 0.85)],
	[Color(0.35, 0.3, 0.55), Color(0.8, 0.65, 0.6)],
	[Color(0.45, 0.2, 0.2), Color(0.85, 0.55, 0.4)],
]


## Returns {spawn, platforms, segments, caches, objectives, beacon, floor_y}.
## The laid-out zones add name, checkpoints, kill_y, routes and stealth_cover.
static func build_zone(root: Node3D, rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	match zone_index:
		0:
			return ForestBuilder.build_zone(root, rng)
		1:
			return MarshBuilder.build_zone(root, rng)
		2:
			return BoneyardBuilder.build_zone(root, rng)
	return build_chain(root, rng, zone_index)


## A seeded chain of platforms. Same keys as build_zone;
## platforms are {top: Vector3 (centre of the top face), size: Vector2 (x, z)}.
static func build_chain(root: Node3D, rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	var sky: Array = ZONE_SKIES[zone_index % ZONE_SKIES.size()]
	Kit.environment(root, sky[0], sky[1])
	var tint: Color = ZONE_TINTS[zone_index % ZONE_TINTS.size()]
	var info := {
		"spawn": Vector3(0, 0.1, 3.0), "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": 0.0, "grunts": [],
	}
	var cur := Vector3.ZERO
	var cur_size := Vector2(14, 14)
	_platform(root, info, cur, cur_size, tint)
	Kit.label(root, Vector3(0, 4, -3), "ZONE %d" % (zone_index + 1))

	var count := 5 + zone_index
	# Path platforms 1..count-1 can carry side caches; the last one has the beacon.
	var candidates := []
	for i in range(1, count):
		candidates.append(i)
	var guarded_at: int = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
	var open_at: int = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))

	for i in count:
		var type := _pick_segment(rng)
		var range_v: Vector2 = GAPS[type]
		var gap := rng.randf_range(range_v.x, range_v.y)
		var rise := 0.0
		match type:
			"jump":
				rise = rng.randf_range(-1.5, 0.5)
			"wallrun":
				rise = rng.randf_range(-1.0, 1.0)
			"grapple":
				rise = rng.randf_range(0.0, 3.0)
			"climb":
				rise = CLIMB_RISE
		var next_size := Vector2(rng.randf_range(8.0, 12.0), rng.randf_range(8.0, 12.0))
		if type == "wallrun" or type == "grapple":
			next_size.y = maxf(next_size.y, 12.0)  # you arrive fast, give room to stop
		if i == count - 1:
			next_size = Vector2(14, 14)
		var edge_z := cur.z - cur_size.y * 0.5
		var next := Vector3(cur.x + rng.randf_range(-3.0, 3.0), cur.y + rise, edge_z - gap - next_size.y * 0.5)
		var mid := Vector3((cur.x + next.x) * 0.5, maxf(cur.y, next.y), edge_z - gap * 0.5)

		match type:
			"wallrun":
				# One long wall beside the gap, just outside the platforms' width.
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				Kit.box(root, Vector3(mid.x + side * 4.5, mid.y, mid.z), Vector3(1, 12, gap), BLUE)
			"grapple":
				# Anchor overhead, a bit past the middle of the gap.
				var anchor := Vector3(mid.x, mid.y + 10.0, edge_z - gap * 0.6)
				Kit.box(root, anchor, Vector3(4, 2, 4), ORANGE)
				Kit.label(root, anchor + Vector3(0, 2, 0), "GRAPPLE", 64)

		_platform(root, info, next, next_size, tint)
		info["segments"].append({
			"type": type, "gap": gap, "rise": rise,
			"from": cur, "from_size": cur_size, "to": next, "to_size": next_size,
		})

		var path_index := i + 1
		_path_cover(root, rng, info, next, next_size, zone_index)
		if path_index == guarded_at or path_index == open_at:
			_side_cache(root, rng, info, next, next_size, tint, path_index == guarded_at, zone_index)
		cur = next
		cur_size = next_size

	var beacon := ExtractBeacon.new()
	beacon.text = "EXTRACT" if zone_index < 2 else "EXTRACT: TITANFALL"
	root.add_child(beacon)
	beacon.position = cur
	info["beacon"] = beacon

	var lowest := 0.0
	for p in info["platforms"]:
		lowest = minf(lowest, p["top"].y)
	info["floor_y"] = lowest
	return info


## The end-of-run arena: the forest's edge, with the enemy titan and the evac pad.
static func build_arena(root: Node3D) -> Dictionary:
	return ForestBuilder.build_edge(root)


static func _pick_segment(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for w in WEIGHTS.values():
		total += w
	var roll := rng.randf() * total
	for type in WEIGHTS:
		roll -= WEIGHTS[type]
		if roll <= 0.0:
			return type
	return "jump"


static func _platform(root: Node3D, info: Dictionary, top: Vector3, size: Vector2, color: Color) -> void:
	Kit.box(root, top - Vector3(0, 0.5, 0), Vector3(size.x, 1, size.y), color)
	info["platforms"].append({"top": top, "size": size})


## Cover on a path platform: a couple of pieces near the front for the pilot to
## land behind, and sometimes a grunt squad dug in behind cover at the back.
static func _path_cover(root: Node3D, rng: RandomNumberGenerator, info: Dictionary,
		top: Vector3, size: Vector2, zone_index: int) -> void:
	var facing := Vector3(0, 0, 1)  # the pilot arrives from +Z
	var half_x := size.x * 0.5
	for k in rng.randi_range(1, 2):
		var lateral := (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(LANE_HALF + 1.1, half_x - 1.2)
		_cover_piece(root, rng, top, facing, lateral, size.y * 0.2)
	if rng.randf() >= SQUAD_CHANCE[mini(zone_index, SQUAD_CHANCE.size() - 1)]:
		return
	var count := rng.randi_range(1, 2 + mini(zone_index, 1))
	for k in count:
		var lateral := (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(LANE_HALF + 1.1, half_x - 1.2)
		var depth := -size.y * 0.25 + (0.0 if k < 2 else 1.5)
		_cover_post(root, rng, info, top, facing, lateral, depth, zone_index, false)


## A piece of cover with a grunt posted behind it. Returns the grunt.
static func _cover_post(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, top: Vector3,
		facing: Vector3, lateral: float, depth: float, zone_index: int, guard: bool) -> Node:
	_cover_piece(root, rng, top, facing, lateral, depth)
	var right := facing.cross(Vector3.UP)
	var g := CharacterBody3D.new()
	g.set_script(GruntScript)
	g.leash = 2.0 if guard else 2.5
	g.sight_range = 35.0 + zone_index * 5.0
	g.damage = 8.0 + zone_index * 2.0
	root.add_child(g)
	g.position = top + right * lateral + facing * (depth - 1.1) + Vector3(0, 0.1, 0)
	g.post = g.position
	g.rotation.y = atan2(-facing.x, -facing.z)
	info["grunts"].append(g)
	return g


## Low wall (crouch or slide behind it) or a tall block (full cover).
static func _cover_piece(root: Node3D, rng: RandomNumberGenerator, top: Vector3,
		facing: Vector3, lateral: float, depth: float) -> void:
	var right := facing.cross(Vector3.UP)
	var tall := rng.randf() < 0.3
	var width := 1.4 if tall else 2.2
	var height := 2.6 if tall else 1.2
	var thick := 1.4 if tall else 0.5
	var size := (right * width + facing * thick).abs() + Vector3(0, height, 0)
	Kit.box(root, top + right * lateral + facing * depth + Vector3(0, height * 0.5, 0), size, COVER)


static func _side_cache(root: Node3D, rng: RandomNumberGenerator, info: Dictionary,
		at: Vector3, at_size: Vector2, tint: Color, guarded: bool, zone_index: int) -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var size := Vector2(9, 9)
	var top := Vector3(at.x + side * (at_size.x * 0.5 + SIDE_GAP + size.x * 0.5), at.y + rng.randf_range(-0.5, 1.0), at.z)
	_platform(root, info, top, size, tint.lightened(0.15))
	var cache := SalvageCache.new()
	root.add_child(cache)
	cache.position = top + Vector3(side * 2.5, 0, 0)
	info["caches"].append(cache)
	if guarded:
		# The squad digs in facing the path platform the pilot comes from.
		cache.set_locked(true)
		var facing := Vector3(-side, 0, 0)
		var squad := []
		var count := 2 + mini(zone_index, 2)
		for k in count:
			var lateral := (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(LANE_HALF + 1.1, size.y * 0.5 - 1.2)
			var depth := 0.8 - float(k >> 1) * 2.2
			squad.append(_cover_post(root, rng, info, top, facing, lateral, depth, zone_index, true))
		var objective := SquadObjective.new()
		root.add_child(objective)
		objective.position = top
		objective.cache = cache
		objective.set_squad(squad)
		info["objectives"].append(objective)
