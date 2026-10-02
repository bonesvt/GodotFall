extends RefCounted
## Builds run zones from the run's RNG.
## A zone is a chain of platforms over a void heading -Z, linked by traversal
## gaps (jump, wallrun, grapple, climb). Two side platforms hold salvage caches,
## one of them guarded by a hold objective. The last platform has the extraction
## beacon. The arena is the flat end-of-run map where the titan fight happens.

const Kit := preload("res://scripts/run/level_kit.gd")
const SalvageCache := preload("res://scripts/run/salvage_cache.gd")
const HoldObjective := preload("res://scripts/run/hold_objective.gd")
const ExtractBeacon := preload("res://scripts/run/extract_beacon.gd")
const Boss := preload("res://scripts/run/boss.gd")

## Gap ranges in metres between platform edges, kept inside what the pilot can
## clear: a sprint jump covers about 7 m, a wallrun about 18 m, the grapple 45 m.
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

const GREY := Color(0.55, 0.57, 0.6)
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const GREEN := Color(0.3, 0.75, 0.4)
const ZONE_TINTS := [Color(0.62, 0.6, 0.55), Color(0.5, 0.58, 0.62), Color(0.62, 0.5, 0.5)]
const ZONE_SKIES := [
	[Color(0.3, 0.45, 0.7), Color(0.75, 0.8, 0.85)],
	[Color(0.35, 0.3, 0.55), Color(0.8, 0.65, 0.6)],
	[Color(0.45, 0.2, 0.2), Color(0.85, 0.55, 0.4)],
]


## Returns {spawn, platforms, segments, caches, objectives, beacon, floor_y}.
## platforms are {top: Vector3 (centre of the top face), size: Vector2 (x, z)}.
static func build_zone(root: Node3D, rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	var sky: Array = ZONE_SKIES[zone_index % ZONE_SKIES.size()]
	Kit.environment(root, sky[0], sky[1])
	var tint: Color = ZONE_TINTS[zone_index % ZONE_TINTS.size()]
	var info := {
		"spawn": Vector3(0, 0.1, 3.0), "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": 0.0,
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


## The end-of-run arena: one big platform, some cover, and the enemy titan.
static func build_arena(root: Node3D) -> Dictionary:
	Kit.environment(root, Color(0.25, 0.2, 0.3), Color(0.9, 0.5, 0.35))
	var info := {
		"spawn": Vector3(0, 0.1, 30.0), "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": 0.0,
		"half_size": 38.0,
	}
	_platform(root, info, Vector3.ZERO, Vector2(80, 80), GREY)
	for p in [Vector3(-15, 0, 5), Vector3(16, 0, -2), Vector3(-6, 0, -18), Vector3(20, 0, 20)]:
		Kit.box(root, p + Vector3(0, 2.5, 0), Vector3(4, 5, 4), GREEN)
	Kit.label(root, Vector3(0, 4, 24), "CALL IN YOUR TITAN", 96)
	var boss := Boss.new()
	root.add_child(boss)
	boss.position = Vector3(0, 0, -25)
	info["boss"] = boss
	return info


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
		cache.set_locked(true)
		var objective := HoldObjective.new()
		objective.hold_time = 5.0 + zone_index * 1.5
		root.add_child(objective)
		objective.position = top - Vector3(side * 1.0, 0, 0)
		objective.cache = cache
		info["objectives"].append(objective)
