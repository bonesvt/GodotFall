extends RefCounted
## The layout of a generated run zone, as plain data: no nodes, so it can be
## planned, tested and drawn as a map without building anything.
## zone_generator.gd turns a plan into the level.
##
## A zone is a valley heading north (-Z), like the handmade zones, with 3 to 5
## lanes running up it side by side. Each lane is a way through with its own
## feel:
##   loud: the road up the middle. Open ground, the yards, the gates and the
##     bridges. Fastest, and where the grunts are dug in.
##   quiet: a sunken gully with tall grass on its banks. Crouch in it and the
##     grunts don't see you. It goes under walls through culverts and over
##     chasms on fallen logs (or a dead titan, or a toppled obelisk).
##   high: a rock ridge along the valley side that turns into a chain of
##     rooftops through the camps, a catwalk over the walls, and stepping
##     stones or a grapple over the chasms.
## One loud lane always, one quiet and one high; a fourth and fifth lane add
## another quiet or high lane on the far side. Lanes sit about LANE_SPACING
## apart with woods (or reeds, or wreckage) between them, so you can cut
## across between lanes anywhere, but each one reads as its own route.
##
## The valley is cut into sections that every lane crosses in turn:
##   start: Eco's drop-off, with the spawn on the road.
##   field: open wilds with a grunt patrol walking between the lanes.
##   picket: a small guard post on the road.
##   wall: the militia's wall across the valley: a breach on the road, a
##     culvert under it in each gully, a catwalk over it on each ridge.
##   outpost / camp: a clearing with buildings, a dug-in squad, a watchtower.
##     Each holds one salvage cache: one of them is guarded by its squad, the
##     other sits on the high lane's rooftops.
##   resource: a titan wreck off the lanes, with alloy to mine and a pair of
##     guards picking it over.
##   ruins: a bombed-out hamlet: house shells along the road (wallrun their
##     walls), a sniper upstairs, a sentry in the street.
##   chasm: a gap across the whole valley. The road has a blown bridge
##     (wallrun the hanging shield or grapple the crane), the gullies a fallen
##     log, the ridges rock pillars.
##   end: the extraction beacon on the road.
## Everything is seeded: the same seed always plans the same zone.

const CELL := 2.0
## Between neighbouring lanes' centres (m).
const LANE_SPACING := 22.0
## Valley floor beyond the outermost lanes before the hills rise (m).
const MARGIN := 16.0
## A ridge's top is RIDGE_H above the valley floor, RIDGE_TOP wide, with
## cliff sides RIDGE_SIDE across.
const RIDGE_H := 4.0
const RIDGE_TOP := 3.0
const RIDGE_SIDE := 2.0
## A gully's bed is GULLY_D deep and GULLY_BED wide, its banks GULLY_BANK across.
const GULLY_D := 1.8
const GULLY_BED := 2.0
const GULLY_BANK := 3.0
## Chasms: lip to lip and the drop to the river below. 20 m matches the
## Pinewoods' ravine so the same crossings work (run_loop_test flies those).
const CHASM_GAP := 20.0
const CHASM_DEPTH := 16.0
## Blown bridge decks reach this far out from each lip on the road.
const BRIDGE_REACH := 2.0
## How long each kind of section is along the valley (m).
const SECTION_LEN := {
	"start": 36.0, "field": 44.0, "picket": 36.0, "wall": 28.0,
	"outpost": 56.0, "camp": 56.0, "resource": 44.0, "chasm": 48.0, "end": 36.0, "ruins": 48.0,
}
## Flat ground round the spawn and the beacon.
const SPAWN_CLEAR := 10.0
const BIOMES := ["forest", "marsh", "boneyard"]
const LANE_NAMES := {
	"forest": {"loud": "The logging road", "quiet": "The creek", "high": "The ridge"},
	"marsh": {"loud": "The causeway", "quiet": "The reed channel", "high": "The pipeline bank"},
	"boneyard": {"loud": "The haul road", "quiet": "The trench", "high": "The spine"},
}
const ZONE_NAMES := {
	"forest": ["THE DEEPWOOD", "HOLLOW PINES", "WIDOW'S RIDGE", "THE STUMPS", "GREYBARK"],
	"marsh": ["THE SINKS", "MIRE ROW", "DROWNED MILE", "THE STILLWATER", "FENWICK"],
	"boneyard": ["THE OSSUARY", "RUSTFIELD", "COLD FOUNDRY", "THE GAUNTLET", "KNELL"],
}

var seed_value := 0
var zone_index := 0
var biome := "forest"
var zone_name := ""
## Each lane: {kind, name, offset (from the valley's centre line), amp, freq, phase}.
var lanes: Array = []
## Each section: {kind, z0 (its near edge, the larger z), z1 (far edge), mid}
## plus per kind: chasm {near_lip, far_lip, level}, wall {wall_z},
## outpost/camp {cache: "guarded" or "high", level}.
var sections: Array = []
var spawn_z := 8.0
var end_z := 0.0
## Where the valley's flat floor starts and ends (z), for the terrain and fences.
var z_top := 0.0
var z_bottom := 0.0
## Below this you have fallen (into a chasm).
var kill_y := -10.0
var floor_y := -20.0

var _phase := []
var _ridge_spans: Array = []


## Plans a zone from `seed_value`. `zone_index` sets how long it is and how
## hard; `lane_count` 0 lets the seed pick 3 to 5; `biome` "" lets it pick.
static func make(seed_value: int, zone_index := 3, lane_count := 0, biome := "") -> RefCounted:
	var plan = load("res://scripts/run/procgen/level_plan.gd").new()
	plan._plan(seed_value, zone_index, lane_count, biome)
	return plan


func _plan(s: int, zi: int, lane_count: int, b: String) -> void:
	seed_value = s
	zone_index = zi
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	biome = b if b != "" else BIOMES[rng.randi() % BIOMES.size()]
	var names: Array = ZONE_NAMES[biome]
	zone_name = names[rng.randi() % names.size()]
	for i in 6:
		_phase.append(rng.randf() * TAU)
	var n := lane_count if lane_count > 0 else rng.randi_range(3, 5)
	_plan_lanes(rng, clampi(n, 3, 5))
	_plan_sections(rng)
	_plan_ridges()
	_plan_depths()


# --- lanes ---------------------------------------------------------------------

func _plan_lanes(rng: RandomNumberGenerator, n: int) -> void:
	# Left to right. The road is in the middle (left of middle with four); the
	# quiet and high lanes take a side each, picked by the seed, and any extra
	# lanes go outside them.
	var kinds := []
	var flip := rng.randf() < 0.5
	var a := "quiet" if flip else "high"
	var b := "high" if flip else "quiet"
	match n:
		3:
			kinds = [a, "loud", b]
		4:
			kinds = [a, "loud", b, a]
		_:
			# Five lanes: one of each on both sides of the road.
			kinds = [b, a, "loud", b, a]
	var counts := {}
	for i in n:
		var kind: String = kinds[i]
		counts[kind] = counts.get(kind, 0) + 1
	var seen := {}
	for i in n:
		var kind: String = kinds[i]
		seen[kind] = seen.get(kind, 0) + 1
		var lane_name: String = LANE_NAMES[biome][kind]
		if counts[kind] > 1:
			lane_name += " (west)" if seen[kind] == 1 else " (east)"
		lanes.append({
			"kind": kind, "name": lane_name,
			"offset": (i - (n - 1) * 0.5) * LANE_SPACING,
			"amp": 0.0 if kind == "loud" else rng.randf_range(2.0, 3.5),
			"freq": rng.randf_range(1.0 / 34.0, 1.0 / 22.0),
			"phase": rng.randf() * TAU,
		})


func lane_count() -> int:
	return lanes.size()


## Index of the first lane of `kind`, or -1.
func lane_of(kind: String) -> int:
	for i in lanes.size():
		if lanes[i]["kind"] == kind:
			return i
	return -1


func lanes_of(kind: String) -> Array:
	var out := []
	for i in lanes.size():
		if lanes[i]["kind"] == kind:
			out.append(i)
	return out


# --- sections ------------------------------------------------------------------

func _plan_sections(rng: RandomNumberGenerator) -> void:
	# The beats between the start and the end: always an outpost, a camp, a wall
	# and a chasm, topped up with fields, pickets and resource sites. Longer
	# further into the run.
	var extra := 2 + clampi(zone_index - 3, 0, 2)
	var middle := ["outpost", "camp", "wall", "chasm"]
	var fillers := ["field", "picket", "resource", "field", "ruins"]
	for i in extra:
		middle.append(fillers[rng.randi() % fillers.size()])
	if rng.randf() < 0.35 + 0.15 * clampi(zone_index - 3, 0, 2):
		middle.append("chasm")  # a second gap to cross
	var order: Array = middle
	for attempt in 200:
		order = middle.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		if _good_order(order):
			break
	var z := spawn_z + 28.0
	z_top = z
	var seq := ["start"] + order + ["end"]
	var caches := ["guarded", "high"] if rng.randf() < 0.5 else ["high", "guarded"]
	for kind in seq:
		var length: float = SECTION_LEN[kind]
		var s := {"kind": kind, "z0": z, "z1": z - length, "mid": z - length * 0.5}
		match kind:
			"chasm":
				# Lips on terrain grid lines so the cliff faces are clean.
				var near := snappedf(s["mid"] + CHASM_GAP * 0.5, CELL)
				s["near_lip"] = near
				s["far_lip"] = near - CHASM_GAP
			"wall":
				s["wall_z"] = snappedf(s["mid"], CELL)
			"outpost", "camp":
				s["cache"] = caches.pop_front()
		sections.append(s)
		z -= length
	end_z = sections[-1]["mid"]
	z_bottom = z
	# Flat stretches (chasm lips, yards) sit at one level each.
	for s in sections:
		if s["kind"] in ["chasm", "outpost", "camp", "start", "end"]:
			s["level"] = _noise_height(s["mid"])
			if biome == "marsh":
				s["level"] = maxf(s["level"], 0.5)  # yards and bridge decks stay above the water


## No chasm first or last, no chasm or wall next to another of either, and
## the two cache sites apart.
func _good_order(order: Array) -> bool:
	if order[0] == "chasm" or order[-1] == "chasm":
		return false
	for i in order.size() - 1:
		var a: String = order[i]
		var b: String = order[i + 1]
		if a in ["chasm", "wall"] and b in ["chasm", "wall"]:
			return false
		if a in ["outpost", "camp"] and b in ["outpost", "camp"]:
			return false
	return true


func sections_of(kind: String) -> Array:
	return sections.filter(func(s): return s["kind"] == kind)


func section_at(z: float) -> Dictionary:
	for s in sections:
		if z <= s["z0"] and z > s["z1"]:
			return s
	return sections[0] if z > sections[0]["z0"] else sections[-1]


# --- shape ---------------------------------------------------------------------

## The valley's centre line: a slow meander.
func center_x(z: float) -> float:
	return 7.0 * sin(z / 61.0 + _phase[0]) + 3.0 * sin(z / 23.0 + _phase[1])


## Lanes wander a little, but run straight across walls and chasms.
func lane_x(i: int, z: float) -> float:
	var lane: Dictionary = lanes[i]
	var wob: float = lane["amp"] * sin(z * lane["freq"] + lane["phase"]) * _calm(z)
	return center_x(z) + lane["offset"] + wob


## 0 within 10 m of a wall or a chasm (so crossings line up) and through the
## yards (so rooftops line up), 1 away from them.
func _calm(z: float) -> float:
	var c := 1.0
	for s in sections:
		if s["kind"] in ["outpost", "camp"]:
			c = minf(c, 1.0 - _plateau(z, s["z1"], s["z0"], 10.0))
		if s["kind"] == "chasm":
			c = minf(c, clampf((absf(z - (s["near_lip"] + s["far_lip"]) * 0.5) - 20.0) / 10.0, 0.0, 1.0))
		elif s["kind"] == "wall":
			c = minf(c, clampf((absf(z - s["wall_z"]) - 6.0) / 10.0, 0.0, 1.0))
	return c


func half_width(_z: float) -> float:
	return (lanes.size() - 1) * 0.5 * LANE_SPACING + MARGIN


static func _plateau(z: float, lo: float, hi: float, ramp: float) -> float:
	if z > hi:
		return clampf(1.0 - (z - hi) / ramp, 0.0, 1.0)
	if z < lo:
		return clampf(1.0 - (lo - z) / ramp, 0.0, 1.0)
	return 1.0


func _noise_height(z: float) -> float:
	var amp := 0.6 if biome == "marsh" else 2.6
	return amp * (0.6 * sin(z / 53.0 + _phase[2]) + 0.4 * sin(z / 29.0 + _phase[3]))


## The valley floor's height at depth z, levelled over chasm lips and yards.
func base_height(z: float) -> float:
	var h := _noise_height(z)
	for s in sections:
		if s.has("level"):
			h = lerpf(h, s["level"], _plateau(z, s["z1"], s["z0"], 10.0))
	return h


## 1 in the yards and round the spawn and beacon, where the ground is flat and
## the gullies and ridges stop.
func clearing(x: float, z: float) -> float:
	var c := 0.0
	for s in sections:
		if s["kind"] in ["outpost", "camp"]:
			c = maxf(c, _plateau(z, s["z1"] + 2.0, s["z0"] - 2.0, 6.0))
	var loud := lane_of("loud")
	for z0 in [spawn_z, end_z]:
		var d := Vector2(x, z).distance_to(Vector2(lane_x(loud, z0), z0))
		c = maxf(c, clampf(1.0 - (d - SPAWN_CLEAR) / 6.0, 0.0, 1.0))
	return c


func _bumps(x: float, z: float) -> float:
	return 0.8 * sin(x * 0.17 + z * 0.11 + _phase[4]) * sin(z * 0.21 - x * 0.07) \
		+ 0.35 * sin(x * 0.43 + 1.3) * sin(z * 0.39 + _phase[5])


static func _smooth(edge0: float, edge1: float, v: float) -> float:
	var t := clampf((v - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## True inside a chasm (between its lips).
func in_chasm(z: float) -> Dictionary:
	for s in sections:
		if s["kind"] == "chasm" and z < s["near_lip"] and z > s["far_lip"]:
			return s
	return {}


## Ground height anywhere in the zone.
func ground(x: float, z: float) -> float:
	var chasm := in_chasm(z)
	if not chasm.is_empty():
		return chasm["level"] - CHASM_DEPTH + 0.8 * sin(x * 0.3) * sin(z * 0.7)
	var c := center_x(z)
	var d := absf(x - c)
	var w := half_width(z)
	var h := base_height(z)
	var clear := clearing(x, z)
	var near_lane := 99.0
	var lane_h := 0.0
	for i in lanes.size():
		var dx := absf(x - lane_x(i, z))
		var kind: String = lanes[i]["kind"]
		near_lane = minf(near_lane, dx)
		if kind == "quiet":
			var depth := GULLY_D * gully_on(z) * (1.0 - clear)
			lane_h -= depth * (1.0 - _smooth(GULLY_BED, GULLY_BED + GULLY_BANK, dx))
		elif kind == "high":
			lane_h += RIDGE_H * ridge_on(z) * (1.0 - _smooth(RIDGE_TOP, RIDGE_TOP + RIDGE_SIDE, dx))
	# Rough between the lanes, calm on them and in the yards.
	var rough := (1.0 - clear) * _smooth(3.0, 7.0, near_lane)
	h += _bumps(x, z) * maxf(rough, 0.15 * (1.0 - clear))
	if biome == "marsh":
		# The fen between the lanes is mud under shallow water; lanes are dry banks.
		h -= 1.3 * (1.0 - clear) * _smooth(4.0, 8.0, near_lane)
	h += lane_h
	# Hills close the valley in on both sides.
	if d > w:
		var o := d - w
		h += minf(o * 0.5 + o * o * 0.015, 16.0) + (0.5 + 0.5 * sin(z * 0.05 + x * 0.03)) * minf(o / 12.0, 1.0) * 4.0
	return h


# --- ridges and gullies along the valley -----------------------------------------

## Where the high lanes run on a ridge: [z_hi, z_lo, ramp_in, ramp_out] spans.
## Yards are rooftops instead, walls have a catwalk over them, the ridge stops
## short of the beacon, and the first one ramps up from the spawn.
func _plan_ridges() -> void:
	var spans := []
	for s in sections:
		match s["kind"]:
			"start":
				spans.append([spawn_z - 2.0, s["z1"], 16.0, 0.0])
			"outpost", "camp":
				pass
			"wall":
				spans.append([s["z0"], s["wall_z"] + 3.0, 0.0, 0.0])
				spans.append([s["wall_z"] - 3.0, s["z1"], 0.0, 0.0])
			"end":
				spans.append([s["z0"], s["z0"] - 14.0, 0.0, 12.0])
			_:
				spans.append([s["z0"], s["z1"], 0.0, 0.0])
	# Merge touching spans so there's no seam between sections.
	for span in spans:
		if not _ridge_spans.is_empty() and absf(_ridge_spans[-1][1] - span[0]) < 0.01 and _ridge_spans[-1][3] == 0.0 and span[2] == 0.0:
			_ridge_spans[-1][1] = span[1]
			_ridge_spans[-1][3] = span[3]
		else:
			_ridge_spans.append(span.duplicate())


func ridge_spans() -> Array:
	return _ridge_spans


## How raised the high lanes are at z, 0 to 1. Cliffs at span ends, except
## the start's ramp up and the end's ramp down.
func ridge_on(z: float) -> float:
	for span in _ridge_spans:
		var hi: float = span[0]
		var lo: float = span[1]
		if z <= hi and z >= lo:
			var t := 1.0
			if span[2] > 0.0:
				t = minf(t, (hi - z) / span[2])
			if span[3] > 0.0:
				t = minf(t, (z - lo) / span[3])
			return clampf(t, 0.0, 1.0)
	return 0.0


## How deep the gullies are at z, 0 to 1: they fill in round the chasm lips
## (the log crossings start at the lip) and start a little past the spawn.
func gully_on(z: float) -> float:
	var g := clampf((spawn_z - 6.0 - z) / 10.0, 0.0, 1.0)
	g = minf(g, clampf((z - (end_z + 8.0)) / 10.0, 0.0, 1.0))
	for s in sections:
		if s["kind"] == "chasm":
			var d := minf(absf(z - s["near_lip"]), absf(z - s["far_lip"]))
			if z < s["near_lip"] and z > s["far_lip"]:
				d = 0.0
			g = minf(g, clampf((d - 6.0) / 6.0, 0.0, 1.0))
	return g


func _plan_depths() -> void:
	# The lowest walkable ground anywhere (not in a chasm), and the chasm floors.
	var low := 99.0
	var z := z_top
	while z > z_bottom:
		if in_chasm(z).is_empty():
			for i in lanes.size():
				for dx in [-12.0, -6.0, 0.0, 6.0, 12.0]:
					low = minf(low, ground(lane_x(i, z) + dx, z))
		z -= CELL
	floor_y = 99.0
	for s in sections_of("chasm"):
		floor_y = minf(floor_y, s["level"] - CHASM_DEPTH)
	if floor_y > 90.0:
		floor_y = low - 6.0
	kill_y = minf(low - 3.0, floor_y + 8.0)


# --- for the map and the tests -----------------------------------------------------

## A short readable summary, e.g. for the map's caption.
func describe() -> String:
	var kinds: Array = sections.map(func(s): return s["kind"])
	var lane_kinds: Array = lanes.map(func(l): return l["kind"])
	return "%s  seed %d  %s  %d lanes [%s]  %s  %d m" % [
		zone_name, seed_value, biome, lanes.size(), ", ".join(lane_kinds), " > ".join(kinds), int(z_top - z_bottom)]
