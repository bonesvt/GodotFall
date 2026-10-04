extends RefCounted
## Zone 2, Blackwater: a flooded fen at dusk, the colony's fuel line.
##
## A laid-out level like the Pinewoods (forest_builder.gd): you wade north (-Z)
## through knee-deep water and swamp cypress, with three ways through.
##   The causeway (loud): the old raised road up the middle, through the
##     roadblock, the stilt village and over the blown bridge into the pump
##     station's yard.
##   The reeds (quiet): wade the shallows on the left through cattails, under
##     the left-hand stilt huts, over the channel on the back of a titan that
##     drowned there, and past the station through the reed beds by its tanks.
##   The pipeline (high): climb onto the fuel main on the right and run along
##     it, across the stilt huts' tin roofs, grapple the crane over the
##     channel, then up the junk and the station's pipe onto the pump house roof.
## Sections, in order: Eco's skiff on the bank where she came in; the roadblock
## on the causeway; the stilt village the colony took from the fishers; the
## channel with the causeway bridge blown (wallrun the grounded barge's side,
## grapple the crane, hop the old piers, or walk the drowned titan); the pump
## station (pump house, storage tanks, watchtower); the extraction beacon on
## a hummock past it.
## One cache is guarded (the village's squad or the station's, by the run seed)
## and the other sits up high: a stilt hut roof or the pump house roof.
## Reed beds mark hiding spots (Area3D in group "stealth_cover"), the dense ones
## block grunts' sight, and so does the shadow under each stilt hut.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const L := preload("res://scripts/run/laid_out.gd")
const Ambience := preload("res://scripts/ambience.gd")

const NAME := "BLACKWATER"
const ZONE := 1
const CELL := 2.0
const GRID_X := Vector2(-130.0, 130.0)
const GRID_Z := Vector2(-292.0, 52.0)

## The water's surface, the mud under the shallows, and the causeway's top.
const WATER_Y := -0.15
const MUD_Y := -0.75
const ROAD_Y := 1.0
const BANK_Y := 0.8
const PAD_Y := 1.2
## The causeway runs to the channel and on from its far side.
const ROAD_START := 16.0
## Stilt huts stand with their posts in the mud here, so their decks are
## level with the road, their roofs (3.9) just under the fuel main's top (4.0),
## and there's only crouching room under them.
const HUT_Y := -1.5
const ROADBLOCK_Z := -40.0
const VILLAGE_Z := -98.0
## The channel runs across the whole fen between these lips (on grid lines).
const NEAR_LIP := -124.0
const FAR_LIP := -144.0
const CHANNEL_FLOOR := -12.0
const CHANNEL_Z := (NEAR_LIP + FAR_LIP) * 0.5
## The bridge stubs reach this far out over the channel from each lip.
const BRIDGE_REACH := 2.0
## The grounded barge's painted side is this far left of the road; the crane's
## anchor this far right, ANCHOR_Y up; the old piers this far right.
const SHIELD_X := -4.5
const ANCHOR_X := 4.5
const ANCHOR_Y := BANK_Y + 11.0
const PILLAR_X := 16.0
const PILLAR := 5.0
## Piers: [front edge z, top y].
const PILLARS := [[-127.3, 1.2], [-135.7, 1.0]]
## The drowned titan lies across the channel this far left of the road.
const LOG_X := -24.0
const STATION_Z := -185.0
const END_Z := -250.0
## Below this you went into the channel.
const KILL_Y := -3.0
## The fuel main runs straight up the right on a gravel berm.
const PIPE_X := 20.0
const PIPE_BERM := 0.4
const PIPE_START := 6.0
## The main's segments are 12 m; the last one ends here, by the first hut.
const PIPE_SEGMENTS := 7
## Stilt huts: [x, z]. The right-hand three are the rooftop run on from the
## fuel main, their roofs 5.2 m apart.
const HUTS_RIGHT := [[20.0, -82.0], [18.0, -92.0], [16.0, -102.0]]
const HUTS_LEFT := [[-14.0, -86.0], [-16.0, -104.0], [-12.0, -116.0]]
## Up to the pump house roof: a pipe on a plinth beside it, this far right of the road.
const STATION_PIPE_X := 13.0

const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const GREEN := Color(0.3, 0.75, 0.4)
const CONCRETE := Color(0.55, 0.56, 0.55)


# --- the fen's shape -----------------------------------------------------------

static func trail_x(z: float) -> float:
	return 5.0 * sin((z + 20.0) / 40.0)


static func _plateau(z: float, lo: float, hi: float, ramp: float) -> float:
	if z > hi:
		return clampf(1.0 - (z - hi) / ramp, 0.0, 1.0)
	if z < lo:
		return clampf(1.0 - (lo - z) / ramp, 0.0, 1.0)
	return 1.0


static func half_width(z: float) -> float:
	return 40.0 + 4.0 * _plateau(z, -216.0, -150.0, 10.0)


static func _bumps(x: float, z: float) -> float:
	return 0.7 * sin(x * 0.19 + z * 0.11) * sin(z * 0.23 - x * 0.08) + 0.35 * sin(x * 0.47 + 1.3) * sin(z * 0.41 + 0.7)


## Low islands of tussock poking out of the water here and there.
static func _islands(x: float, z: float) -> float:
	var n := sin(x * 0.11 + 1.7) * sin(z * 0.09 - 0.4) + 0.5 * sin(x * 0.27 - z * 0.19)
	return maxf(n - 0.55, 0.0) * 1.6


static func causeway(z: float) -> bool:
	return z < ROAD_START and not (z < NEAR_LIP and z > FAR_LIP)


## Ground height anywhere in the zone.
static func ground(x: float, z: float) -> float:
	if z < NEAR_LIP and z > FAR_LIP:
		return CHANNEL_FLOOR + 0.8 * sin(x * 0.3) * sin(z * 0.7)
	var c := trail_x(z)
	var d := absf(x - c)
	var h := MUD_Y + 0.12 * _bumps(x, z) + _islands(x, z)
	# Dry banks either side of the channel.
	h = lerpf(h, BANK_Y + 0.1 * _bumps(x, z), _plateau(z, FAR_LIP - 10.0, NEAR_LIP + 10.0, 4.0))
	# The bank Eco poled in to.
	h = maxf(h, ROAD_Y - maxf(Vector2(x, z).distance_to(Vector2(trail_x(6.0), 6.0)) - 13.0, 0.0) * 0.3)
	# The pump station's hardstanding (the left edge stays reed bed).
	var pad := _plateau(z, -218.0, -150.0, 4.0) * clampf((x - (c - 20.0)) / 3.0, 0.0, 1.0) * clampf((c + 36.0 - x) / 3.0, 0.0, 1.0)
	h = lerpf(h, PAD_Y, pad)
	# The hummock with the extraction beacon.
	h = maxf(h, 1.6 - maxf(Vector2(x, z).distance_to(Vector2(trail_x(END_Z), END_Z)) - 12.0, 0.0) * 0.22)
	# The fuel main's gravel berm.
	if z < PIPE_START + 6.0 and z > PIPE_START - PIPE_SEGMENTS * 12.0 - 4.0:
		h = maxf(h, lerpf(h, PIPE_BERM, clampf((4.0 - absf(x - PIPE_X)) / 1.5, 0.0, 1.0)))
	# The causeway: a 6 m road with sloping shoulders.
	if causeway(z):
		var fade := clampf((ROAD_START - z) / 4.0, 0.0, 1.0)
		h = maxf(h, lerpf(h, ROAD_Y, clampf((6.5 - d) / 3.5, 0.0, 1.0) * fade))
	# Wooded bluffs close the fen in on both sides.
	var w := half_width(z)
	if d > w:
		var o := d - w
		h += minf(o * 0.45 + o * o * 0.015, 16.0) + (0.5 + 0.5 * sin(z * 0.05 + x * 0.03)) * minf(o / 12.0, 1.0) * 4.0
	return h


static func _on(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, ground(x, z) + up, z)


## Standing height at (x, z): the ground, or the water's floor (you wade).
static func _road(z: float, off := 0.0, up := 0.0) -> Vector3:
	return _on(trail_x(z) + off, z, up)


# --- the zone ------------------------------------------------------------------

static func build_zone(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	L.environment(root, Color(0.3, 0.36, 0.38), Color(0.72, 0.68, 0.54), 0.0085, Color(1.0, 0.76, 0.5), 0.95, -24.0)
	Ambience.start(root, {"swamp_creek": -11.0, "rain": -19.0, "forest_night": -21.0, "wind_soft": -20.0})
	var info := L.info(NAME, _road(6.0, 0.0, 0.1), CHANNEL_FLOOR, KILL_Y)
	var guard_village := rng.randf() < 0.5
	var dress := RandomNumberGenerator.new()
	dress.seed = rng.randi()

	L.terrain(root, ground, GRID_X, GRID_Z, CELL, Color(0.62, 0.66, 0.42), Color(0.7, 0.68, 0.6))
	L.water(root, Vector3(0, WATER_Y, (GRID_Z.x + GRID_Z.y) * 0.5), Vector2(GRID_X.y - GRID_X.x + 200.0, GRID_Z.y - GRID_Z.x + 120.0),
			Color(0.09, 0.12, 0.08, 0.93))
	L.fences(root, func(z): return Vector2(trail_x(z) - half_width(z) - 6.0, trail_x(z) + half_width(z) + 6.0), 30.0, -268.0)
	L.strip(root, ground, trail_x, ROAD_START, END_Z - 4.0, 2.4, Art.material("dirt", Color(0.85, 0.8, 0.7)),
			func(z): return z < NEAR_LIP + 2.0 and z > FAR_LIP - 2.0)
	var keep_out: Array = []
	_landing(root, dress, info, keep_out)
	_pipeline(root, info, keep_out)
	_roadblock(root, rng, info, keep_out)
	_village(root, rng, dress, info, keep_out, guard_village)
	_channel(root, rng, dress, info, keep_out)
	_station(root, rng, dress, info, keep_out, not guard_village)
	_end(root, info, keep_out)
	_reeds(root, dress, info, keep_out)
	_swamp(root, dress, info, keep_out)
	_routes(info)
	L.collect_cover(root, info)

	for z in [6.0, -30.0, -66.0, VILLAGE_Z, NEAR_LIP + 8.0, FAR_LIP - 10.0, -176.0, -236.0]:
		info["checkpoints"].append(_road(z, 0.0, 0.1))
	var cr := trail_x(CHANNEL_Z)
	for p in [Vector3(PIPE_X, PIPE_BERM + 3.7, -30.0), Vector3(trail_x(-40.0) - 22.0, 0.0, -40.0),
			Vector3(cr + LOG_X, 0.0, NEAR_LIP + 7.0), Vector3(cr + LOG_X, 0.0, FAR_LIP - 7.0),
			Vector3(trail_x(-196.0) - 24.0, 0.0, -196.0)]:
		info["checkpoints"].append(p if p.y > 0.0 else _on(p.x, p.z, 0.1))
	return info


## A grunt on the ground at (x, z) looking back down the fen (+Z).
static func _post(root: Node3D, info: Dictionary, x: float, z: float, leash := 2.0) -> Node:
	return L.grunt(root, info, _on(x, z), Vector3(0, 0, 1), ZONE, leash)


# --- 1. the landing ------------------------------------------------------------

static func _landing(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var c := trail_x(8.0)
	Z.spawn(root, "skiff", _on(c - 6.0, 12.0, 0.05), 160.0)
	Z.spawn(root, "lily_pads", Vector3(c - 9.0, WATER_Y + 0.02, 15.0), 30.0)
	Z.cypress(root, _on(c + 9.0, 10.0, -0.3), rng, 1.0, "cypress_dead")
	F.rock(root, "rock_b", _on(c - 7.5, 2.0), 20.0, 1.2)
	keep_out.append(Rect2(c - 9.0, -2.0, 18.0, 18.0))


# --- the fuel main (the high road) -------------------------------------------------

static func _pipeline(root: Node3D, info: Dictionary, keep_out: Array) -> void:
	for k in PIPE_SEGMENTS:
		Z.pipe_run(root, Vector3(PIPE_X, PIPE_BERM, PIPE_START - 6.0 - k * 12.0), 90.0)
	keep_out.append(Rect2(PIPE_X - 4.0, PIPE_START - PIPE_SEGMENTS * 12.0 - 2.0, 8.0, PIPE_SEGMENTS * 12.0 + 6.0))
	# Up onto it at the start: a valve box, then a stack of crates.
	Kit.box(root, Vector3(PIPE_X - 2.4, PIPE_BERM + 0.6, PIPE_START - 3.0), Vector3(1.2, 1.2, 1.2), GREEN)
	F.crate_stack(root, Vector3(PIPE_X - 1.6, PIPE_BERM, PIPE_START - 5.2), 0.0)
	F.barrels(root, _on(PIPE_X - 4.0, PIPE_START - 30.0), 80.0)
	F.floodlight(root, _on(PIPE_X - 3.0, PIPE_START - 54.0), 180.0)


# --- 2. the roadblock ----------------------------------------------------------

static func _roadblock(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var z := ROADBLOCK_Z
	var c := trail_x(z)
	F.sandbags(root, _on(c - 2.4, z), 4.0)
	F.sandbags(root, _on(c + 2.6, z - 0.6), -6.0)
	F.wreck_truck(root, _on(c - 0.5, z - 6.0), 20.0)
	F.floodlight(root, _on(c + 4.6, z - 3.0), 0.0)
	F.barrels(root, _on(c + 4.2, z - 7.0), 15.0)
	F.pallet(root, _on(c - 4.2, z - 3.5), -10.0)
	keep_out.append(Rect2(c - 8, z - 10, 16, 14))
	for k in rng.randi_range(1, 2):
		_post(root, info, c + (-2.4 if k == 0 else 2.6), z - 1.2 - 0.6 * k)


# --- 3. the stilt village ------------------------------------------------------

static func _village(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var roofs := []
	var decks := []
	for side in [HUTS_RIGHT, HUTS_LEFT]:
		for h in side:
			var pos := Vector3(h[0], HUT_Y, h[1])
			var yaw := 0.0
			roofs.append(Z.stilt_hut(root, pos, yaw))
			decks.append(pos + Vector3(0, 2.5, 0))
			keep_out.append(Rect2(pos.x - 4.0, pos.z - 4.0, 8.0, 8.0))
			# Hide in the shadow under the deck, among the stilts.
			F.stealth_cover(root, pos + Vector3(0, 0.9, 0), Vector3(5.6, 1.8, 5.6))
			F.sight_blocker(root, pos + Vector3(0, 1.0, 0), Vector3(4.6, 1.4, 4.6))
			# A walk from the road out to the deck.
			var road_edge := trail_x(pos.z) + signf(pos.x - trail_x(pos.z)) * 3.0
			var deck_edge := pos.x - signf(pos.x - trail_x(pos.z)) * 3.0
			var length := absf(deck_edge - road_edge)
			var n := int(ceil(length / 6.0))
			for k in n:
				var t := (k + 0.5) / n
				Z.boardwalk(root, Vector3(lerpf(road_edge, deck_edge, t), ROAD_Y, pos.z + 1.6), 90.0)
	# Colony stuff on the decks and along the road.
	F.floodlight(root, _road(-90.0, -4.0), 30.0)
	F.floodlight(root, _road(-112.0, 4.5), -150.0)
	F.antenna(root, _road(-80.0, -6.0))
	F.generator(root, _road(-94.0, -4.6), 90.0)
	F.barrels(root, _road(-108.0, -4.0), 30.0)
	F.crate_stack(root, decks[1] + Vector3(-1.8, 0, 1.2), 10.0)
	F.pallet(root, decks[4] + Vector3(1.5, 0, 1.2), 80.0)
	F.barrels(root, decks[5] + Vector3(-1.6, 0, 1.4), 0.0)
	Z.dock(root, Vector3(trail_x(-118.0) + 7.0, 1.0, -118.0), 0.0)
	for p in [Vector2(-8.0, -90.0), Vector2(9.0, -112.0), Vector2(-25.0, -96.0), Vector2(27.0, -100.0)]:
		Z.spawn(root, "lily_pads", Vector3(trail_x(p.y) + p.x, WATER_Y + 0.02, p.y), dress.randf_range(0, 360))
	keep_out.append(Rect2(trail_x(VILLAGE_Z) - 26, -122, 52, 46))
	# The lookouts on two porches.
	L.grunt(root, info, decks[1] + Vector3(-0.5, 0, 2.2), Vector3(0, 0, 1), ZONE, 0.8)
	L.grunt(root, info, decks[3] + Vector3(0.5, 0, 2.2), Vector3(0, 0, 1), ZONE, 0.8)
	# The squad dug in on the road in the middle of the village.
	var c := trail_x(VILLAGE_Z)
	var posts := [Vector2(c - 2.2, -96.0), Vector2(c + 2.4, -97.5), Vector2(c + 0.2, -103.0)]
	F.sandbags(root, _on(posts[0].x, posts[0].y), 6.0)
	F.sandbags(root, _on(posts[1].x, posts[1].y), -8.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].y), 5.0)
	var squad := []
	for k in rng.randi_range(2, 3):
		var p: Vector2 = posts[k]
		squad.append(_post(root, info, p.x, p.y - (1.1 if k != 2 else 1.3)))
	if guarded:
		L.guard(root, info, L.cache(root, info, _road(-108.0, 0.6)), squad)
	else:
		L.cache(root, info, roofs[1])


# --- 4. the channel ------------------------------------------------------------

static func _channel(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var c := trail_x(CHANNEL_Z)
	keep_out.append(Rect2(c - 10.0, FAR_LIP - 12.0, 32.0, NEAR_LIP - FAR_LIP + 24.0))
	keep_out.append(Rect2(c + LOG_X - 3.0, FAR_LIP - 6.0, 6.0, NEAR_LIP - FAR_LIP + 12.0))
	var gap := (NEAR_LIP - FAR_LIP) - BRIDGE_REACH * 2.0
	var near_end := NEAR_LIP - BRIDGE_REACH
	var far_end := FAR_LIP + BRIDGE_REACH
	F.bridge_stub(root, Vector3(c, ROAD_Y, near_end + 5.0), 0.0)
	F.bridge_stub(root, Vector3(c, ROAD_Y, far_end - 5.0), 180.0)
	# What the tutorial points at (tutorial.gd): each crossing's pieces.
	var crossing := {"lip": _road(NEAR_LIP + 14.0, 0.0), "wallrun": [], "grapple": [], "pillars": [], "log": []}
	info["crossing"] = crossing
	# Route 1: a barge ran aground against the old bridge; wallrun its painted side.
	var before := root.get_child_count()
	Z.barge(root, Vector3(c + SHIELD_X - 2.0, 0.5, CHANNEL_Z), 90.0)
	crossing["wallrun"] = root.get_children().slice(before)
	info["segments"].append({"type": "wallrun", "gap": gap, "rise": 0.0})
	# Route 2: a crane on the far bank; grapple the anchor on its arm.
	var anchor_z := near_end - gap * 0.6
	F.pylon(root, Vector3(c + ANCHOR_X, BANK_Y, anchor_z - 9.0), 0.0)
	crossing["grapple"].append(Kit.box(root, Vector3(c + ANCHOR_X, ANCHOR_Y, anchor_z), Vector3(3, 2, 3), ORANGE))
	info["segments"].append({"type": "grapple", "gap": gap, "rise": 0.0})
	# Route 3: what's left of the old bridge's piers, right of the new one.
	var px := c + PILLAR_X
	var last_edge := NEAR_LIP
	var last_top := BANK_Y
	for p in PILLARS:
		var front: float = p[0]
		var top: float = p[1]
		var back := front - PILLAR
		var h := top - CHANNEL_FLOOR + 1.0
		crossing["pillars"].append(Kit.box(root, Vector3(px, top - h * 0.5, (front + back) * 0.5), Vector3(PILLAR, h, PILLAR), CONCRETE, Vector3.ZERO, Art.material("concrete", Color(0.75, 0.78, 0.7))))
		Kit.box(root, Vector3(px, top - 0.3, (front + back) * 0.5), Vector3(PILLAR - 0.4, 0.62, PILLAR - 0.4), CONCRETE, Vector3.ZERO, Art.material("moss"))
		info["segments"].append({"type": "jump", "gap": last_edge - front, "rise": top - last_top})
		last_edge = back
		last_top = top
	info["segments"].append({"type": "jump", "gap": last_edge - FAR_LIP, "rise": BANK_Y - last_top})
	# Route 4: a titan drowned here in the war, face down across the channel. Walk its back.
	before = root.get_child_count()
	Z.titan_fallen(root, Vector3(c + LOG_X, BANK_Y, CHANNEL_Z), 90.0, Color(0.55, 0.62, 0.5))
	crossing["log"] = root.get_children().slice(before)
	for z in [NEAR_LIP + 4.0, FAR_LIP - 4.0, FAR_LIP - 9.0]:
		L.hide(root, ground, dress, info, c + LOG_X + (3.5 if z < CHANNEL_Z else -3.5), z, Vector2(3.0, 5.0), true)
	# Rocks and stumps along both banks.
	for z in [NEAR_LIP + 1.0, FAR_LIP - 1.0]:
		for i in 12:
			var x := c - 48.0 + i * 8.5 + rng.randf_range(-2, 2)
			if absf(x - c) < 5.0 or absf(x - px) < 3.5 or absf(x - (c + LOG_X)) < 3.0 or absf(x - (c + SHIELD_X - 2.0)) < 4.0:
				continue
			F.rock(root, ["rock_a", "rock_b", "rock_c"][i % 3], _on(x, z), rng.randf_range(0, 360), rng.randf_range(0.9, 1.5))
	# Grunts dug in on the far bank, watching the bridge.
	var picket := [Vector2(c - 9.0, FAR_LIP - 8.0), Vector2(c + 10.0, FAR_LIP - 9.0)]
	for k in picket.size():
		var p: Vector2 = picket[k]
		F.sandbags(root, _on(p.x, p.y), rng.randf_range(-10, 10))
		if k == 0 or rng.randf() < 0.5:
			_post(root, info, p.x, p.y - 1.1)
	F.floodlight(root, _on(c + 6.0, FAR_LIP - 14.0), 180.0)


# --- 5. the pump station -------------------------------------------------------

static func _station(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var c := trail_x(STATION_Z)
	keep_out.append(Rect2(c - 20, -218, 56, 70))
	var house := Vector3(c + 15.0, PAD_Y, -194.0)
	var roof := Z.pump_house(root, house, 0.0)
	# Up to the roof: a pipe on a plinth beside the house, crates and a valve box onto the plinth.
	var sx := c + STATION_PIPE_X
	Kit.box(root, Vector3(sx, PAD_Y + 0.5, -178.0), Vector3(2.4, 1.0, 16.0), CONCRETE, Vector3.ZERO, Art.material("concrete"))
	Z.pipe_run(root, Vector3(sx, PAD_Y + 1.0, -182.6), 90.0)
	Kit.box(root, Vector3(sx, PAD_Y + 1.6, -171.0), Vector3(1.2, 1.2, 1.2), GREEN)
	F.crate_stack(root, Vector3(sx, PAD_Y + 1.0, -174.0), 0.0)
	# Tanks on the left, against the reed beds.
	Z.storage_tank(root, _on(c - 12.0, -168.0), 0.0)
	Z.storage_tank(root, _on(c - 13.0, -200.0), 40.0)
	Z.storage_tank(root, _on(c - 4.0, -212.0), 80.0)
	F.fuel_tank(root, _on(c - 8.0, -184.0), 90.0)
	var deck := F.watchtower(root, _on(c - 5.0, -158.0), 0.0)
	L.grunt(root, info, deck + Vector3(0, 0, 0.6), Vector3(0, 0, 1), ZONE, 0.6)
	F.floodlight(root, _on(c - 3.0, -170.0), 10.0)
	F.floodlight(root, _on(c + 24.0, -182.0), -60.0)
	F.generator(root, _on(c + 4.0, -200.0), 0.0)
	F.barrels(root, _on(c + 6.0, -168.0), 20.0)
	F.pallet(root, _on(c - 6.0, -176.0), 10.0)
	F.pallet(root, _on(c + 25.0, -200.0), 80.0)
	F.camo_net(root, _on(c + 2.0, -208.0), 0.0)
	F.tent(root, _on(c - 0.5, -208.0), 0.0)
	F.tent(root, _on(c + 4.5, -208.0), 0.0)
	F.antenna(root, _on(c + 26.0, -208.0))
	F.wreck_truck(root, _on(c + 28.0, -170.0), 100.0)
	# The yard in front of the pump house.
	var posts := [Vector2(c + 2.0, -176.0), Vector2(c - 3.5, -179.5), Vector2(c + 8.0, -178.5), Vector2(c - 1.0, -186.0)]
	F.sandbags(root, _on(posts[0].x, posts[0].y), -5.0)
	F.sandbags(root, _on(posts[1].x, posts[1].y), 12.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].y), 0.0)
	F.sandbags(root, _on(posts[3].x, posts[3].y), -15.0)
	var squad := []
	for k in rng.randi_range(2, 4):
		var p: Vector2 = posts[k]
		squad.append(_post(root, info, p.x, p.y - (1.1 if k != 2 else 1.3)))
	if guarded:
		L.guard(root, info, L.cache(root, info, _on(c + 3.0, -191.0)), squad)
	else:
		L.cache(root, info, roof + Vector3(-1.0, 0, 1.5))


# --- 6. the hummock ------------------------------------------------------------

static func _end(root: Node3D, info: Dictionary, keep_out: Array) -> void:
	var x := trail_x(END_Z)
	L.beacon(root, info, _on(x, END_Z))
	keep_out.append(Rect2(x - 12, END_Z - 12, 24, 24))
	F.spawn(root, "rock_b", _on(x - 6.0, END_Z - 4.0), 40.0, 1.6)
	F.spawn(root, "rock_a", _on(x + 7.0, END_Z + 2.0), 10.0, 1.3)


# --- the reed beds -------------------------------------------------------------

## The quiet route's reed beds down the left, plus clumps out in the fen.
static func _reeds(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var z := 4.0
	var i := 0
	while z > -72.0:
		var x := trail_x(z) - 22.0
		_bed(root, rng, info, x - 3.5 + rng.randf_range(-1, 1), z, Vector2(3.5, 7.0), i % 2 == 0)
		_bed(root, rng, info, x + 3.5 + rng.randf_range(-1, 1), z - 4.0, Vector2(3.0, 6.0), i % 2 == 1)
		z -= 9.0
		i += 1
	for p in [Vector2(-26.0, -78.0), Vector2(-28.0, -94.0), Vector2(-24.0, -110.0), Vector2(-20.0, -120.0)]:
		_bed(root, rng, info, trail_x(p.y) + p.x, p.y, Vector2(4.0, 6.0), true)
	z = -156.0
	i = 0
	while z > -224.0:
		_bed(root, rng, info, trail_x(z) - 25.0 + rng.randf_range(-1.5, 1.5), z, Vector2(4.5, 7.0), i % 3 != 2)
		z -= 8.0
		i += 1
	var patches := 0
	var tries := 0
	while patches < 22 and tries < 500:
		tries += 1
		var gz := rng.randf_range(-240.0, 20.0)
		var gx := trail_x(gz) + rng.randf_range(-36.0, 36.0)
		if _bare(gx, gz, keep_out) or ground(gx, gz) > 0.4 or (gz < NEAR_LIP + 3.0 and gz > FAR_LIP - 3.0):
			continue
		_bed(root, rng, info, gx, gz, Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(3.0, 6.0)), rng.randf() < 0.35, rng.randf_range(0, 180))
		patches += 1


static func _bed(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, x: float, z: float, size: Vector2, dense := false, yaw := 0.0) -> void:
	L.hide(root, ground, rng, info, x, z, size, dense, yaw)


# --- the routes ----------------------------------------------------------------

static func _routes(info: Dictionary) -> void:
	var cr := trail_x(CHANNEL_Z)
	var cs := trail_x(STATION_Z)
	var loud := PackedVector3Array()
	var z := 8.0
	while z > END_Z:
		var x := cr if (z < NEAR_LIP + 8.0 and z > FAR_LIP - 8.0) else trail_x(z)
		loud.append(Vector3(x, ROAD_Y + 0.3, z) if (z < NEAR_LIP and z > FAR_LIP) else _on(x, z, 0.3))
		z -= 4.0
	var quiet := PackedVector3Array()
	z = 4.0
	while z > -72.0:
		quiet.append(_on(trail_x(z) - 22.0, z, 0.3))
		z -= 4.0
	for h in [HUTS_LEFT[0], HUTS_LEFT[1]]:
		quiet.append(_on(h[0], h[1], 0.3))
	quiet.append(_on(cr + LOG_X, NEAR_LIP + 6.0, 0.3))
	quiet.append(Vector3(cr + LOG_X, BANK_Y + 0.5, NEAR_LIP))
	quiet.append(Vector3(cr + LOG_X, BANK_Y + 0.5, FAR_LIP))
	for p in [Vector2(cr + LOG_X, -152.0), Vector2(trail_x(-164.0) - 24.0, -164.0), Vector2(cs - 24.0, -184.0),
			Vector2(cs - 24.0, -206.0), Vector2(trail_x(-224.0) - 20.0, -224.0), Vector2(trail_x(END_Z), END_Z)]:
		quiet.append(_on(p.x, p.y, 0.3))
	var high := PackedVector3Array()
	high.append(_on(PIPE_X - 2.4, PIPE_START, 0.3))
	z = PIPE_START - 6.0
	while z > PIPE_START - PIPE_SEGMENTS * 12.0:
		high.append(Vector3(PIPE_X, PIPE_BERM + 3.9, z))
		z -= 6.0
	for h in HUTS_RIGHT:
		high.append(Vector3(h[0], HUT_Y + 5.7, h[1] - 0.8))
	var near_end := NEAR_LIP - BRIDGE_REACH
	var gap := (NEAR_LIP - FAR_LIP) - BRIDGE_REACH * 2.0
	for p in [_on(cr + ANCHOR_X, NEAR_LIP + 2.0, 0.3), Vector3(cr + ANCHOR_X, ANCHOR_Y - 1.0, near_end - gap * 0.6),
			_on(cr + 2.0, FAR_LIP - 6.0, 0.3), Vector3(cs + STATION_PIPE_X, PAD_Y + 2.3, -171.0),
			Vector3(cs + STATION_PIPE_X, PAD_Y + 4.0, -174.0), Vector3(cs + STATION_PIPE_X, PAD_Y + 4.9, -180.0),
			Vector3(cs + 15.0, PAD_Y + 6.3, -192.0), _on(cs + 10.0, -218.0, 0.3), _on(trail_x(END_Z) + 2.0, END_Z, 0.3)]:
		high.append(p)
	info["routes"] = [
		{"name": "The causeway", "kind": "loud", "points": loud},
		{"name": "The reeds", "kind": "quiet", "points": quiet},
		{"name": "The pipeline and rooftops", "kind": "high", "points": high},
	]


# --- the fen itself -----------------------------------------------------------

static func _bare(x: float, z: float, keep_out: Array) -> bool:
	if causeway(z) and absf(x - trail_x(z)) < 7.0:
		return true
	if Vector2(x, z).distance_to(Vector2(trail_x(6.0), 6.0)) < 10.0:
		return true
	if z < PIPE_START + 4.0 and z > PIPE_START - PIPE_SEGMENTS * 12.0 - 4.0 and absf(x - PIPE_X) < 4.5:
		return true
	if z < 8.0 and z > -124.0 and absf(x - (trail_x(z) - 22.0)) < 3.0:
		return true  # the wading line through the reeds
	for r in keep_out:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


static func _swamp(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var cr := trail_x(CHANNEL_Z)
	# Cypress standing in the water, thick on the flanks.
	var z := 30.0
	while z > -262.0:
		var w := half_width(z) + 3.0
		var x := trail_x(z) - w
		while x < trail_x(z) + w:
			var p := Vector2(x + rng.randf_range(-2.2, 2.2), z + rng.randf_range(-2.2, 2.2))
			var in_channel := p.y < NEAR_LIP + 1.5 and p.y > FAR_LIP - 1.5
			var edge := absf(p.x - trail_x(p.y)) > 14.0
			if rng.randf() < (0.6 if edge else 0.25) and not _bare(p.x, p.y, keep_out) and not in_channel:
				Z.cypress(root, _on(p.x, p.y, -0.2), rng, rng.randf_range(0.85, 1.25))
			x += 6.2
		z -= 6.2
	# A few in the village and round the station so they sit in the fen.
	for p in [Vector2(-30, -80), Vector2(28, -118), Vector2(-30, -150), Vector2(34, -160), Vector2(-24, -224), Vector2(30, -222)]:
		Z.cypress(root, _on(trail_x(p.y) + p.x, p.y, -0.2), rng, 1.15)
	# Logs and stumps through the shallows.
	var logs := 0
	var tries := 0
	while logs < 12 and tries < 400:
		tries += 1
		var lz := rng.randf_range(-240.0, 12.0)
		var lx := trail_x(lz) + rng.randf_range(-34.0, 34.0)
		if _bare(lx, lz, keep_out) or (lz < NEAR_LIP + 6.0 and lz > FAR_LIP - 6.0):
			continue
		F.fallen_log(root, _on(lx, lz, -0.25), rng.randf_range(0, 360))
		logs += 1
	# Lily pads on open water.
	var pads := []
	tries = 0
	while pads.size() < 120 and tries < 2000:
		tries += 1
		var pz := rng.randf_range(-260.0, 30.0)
		var px := trail_x(pz) + rng.randf_range(-half_width(pz), half_width(pz))
		var g := ground(px, pz)
		if g > WATER_Y - 0.1 or (pz < NEAR_LIP + 1.0 and pz > FAR_LIP - 1.0 and absf(px - cr) < 8.0):
			continue
		pads.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(px, WATER_Y + 0.02, pz)))
	Z.scatter(root, "lily_pads", pads, {"leaves": Color(0.6, 0.72, 0.42)}, false)
	# Far swamp beyond the bluffs: batched, no collision.
	var far := {"cypress_a": [], "cypress_b": [], "cypress_dead": []}
	z = 60.0
	while z > -296.0:
		for side in [-1.0, 1.0]:
			var d := half_width(z) + 4.0
			while d < half_width(z) + 80.0:
				var px: float = trail_x(z) + side * (d + rng.randf_range(-2.0, 2.0))
				var pz := z + rng.randf_range(-3.0, 3.0)
				var id: String = ["cypress_a", "cypress_b", "cypress_a", "cypress_dead"][rng.randi() % 4]
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5))
				far[id].append(Transform3D(basis, _on(px, pz, -0.3)))
				d += rng.randf_range(6.0, 9.0)
		z -= 6.0
	for zz in [[30.0, 60.0], [-296.0, -262.0]]:
		for i in 160:
			var pz := rng.randf_range(zz[0], zz[1])
			var px := trail_x(pz) + rng.randf_range(-70.0, 70.0)
			far[["cypress_a", "cypress_b", "cypress_dead"][i % 3]].append(
					Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.4)), _on(px, pz, -0.3)))
	for id in far:
		Z.scatter(root, id, far[id], {"leaves": Z.CYPRESS_TINTS[0], "grass_blade": Z.MOSS_BEARD})
	for i in 16:
		var ang := TAU * i / 16.0
		var base := Vector3(sin(ang) * 240.0, -8.0, -110.0 + cos(ang) * 270.0)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.0, 1.3),
				{"hill_forest": Color(0.6, 0.68, 0.58)})
	# Sedge and grass on the dry ground, ferns at the water's edge.
	var grass := []
	var ferns := []
	tries = 0
	while grass.size() < 7000 and tries < 60000:
		tries += 1
		var pz := rng.randf_range(-262.0, 30.0)
		var px := trail_x(pz) + rng.randf_range(-half_width(pz) - 4.0, half_width(pz) + 4.0)
		var g := ground(px, pz)
		if g < WATER_Y + 0.05 or (pz < NEAR_LIP + 0.5 and pz > FAR_LIP - 0.5):
			continue
		if causeway(pz) and absf(px - trail_x(pz)) < 2.6:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5))
		if g < WATER_Y + 0.4 and rng.randf() < 0.25:
			ferns.append(Transform3D(basis, Vector3(px, g - 0.05, pz)))
		else:
			grass.append(Transform3D(basis, Vector3(px, g - 0.05, pz)))
	F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.74, 0.74, 0.5)}, false)
	F.scatter(root, "fern", ferns, {"leaves": Color(0.55, 0.66, 0.42)}, false)
	Z.scatter(root, "reeds", info["tall_grass"], {"grass_blade": Color(0.72, 0.74, 0.5), "bark": Color(0.6, 0.45, 0.35)}, false)
	info["tall_grass"] = []
