extends RefCounted
## Zone 3, the Boneyard: the old front line, where the titans died.
##
## A laid-out level like the Pinewoods (forest_builder.gd): a burnt valley of
## craters and dead titans heading north (-Z) under a smoky sky, where the
## colony strips the wrecks for parts. Three ways through.
##   The haul road (loud): the strippers' truck road up the middle, past the
##     picket, through the salvage yard's gate, over the blown haul bridge and
##     into the ruins they made a radio post of.
##   The old trenches (quiet): drop into the war's front-line trench and follow
##     the communication trench forward on the left, out through a wall slab
##     their crane knocked flat, round the back of the strip shed, across the
##     rift on a fallen precursor obelisk, and up the dead grass on the left of
##     the ruins.
##   The titan's back (high): climb a dead titan lying face down on the right by
##     its hand and head and run along its back, then up the containers onto the
##     yard wall and the container stacks inside, grapple the crane over the
##     rift, and up a hut roof onto a precursor column.
## Sections, in order: the front-line trench; no-man's land (craters, wire, a
## dead titan on its knees, the picket); the salvage yard (wall, gantry crane
## over a titan they're stripping, strip shed, containers, watchtower); the rift
## (wallrun a titan's tower shield wedged in it, grapple the crane, hop the
## ruin columns, or walk the obelisk); the ruins of the precursor's shrine with
## the colony's radio post; the extraction beacon at the edge of the burn,
## where the living forest starts again.
## One cache is guarded (the yard's squad or the ruins', by the run seed) and
## the other is up high: on a container stack in the yard or a ruin column.
## Dead grass and the trenches mark hiding spots (Area3D in group
## "stealth_cover"); the dense grass blocks grunts' sight.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Z := preload("res://scripts/run/zone_kit.gd")
const L := preload("res://scripts/run/laid_out.gd")
const Ambience := preload("res://scripts/ambience.gd")

const NAME := "THE BONEYARD"
const ZONE := 2
const CELL := 2.0
const GRID_X := Vector2(-130.0, 130.0)
const GRID_Z := Vector2(-292.0, 52.0)

## The front-line trench crosses the valley here; trenches are this deep.
const FRONT_Z := -2.0
const TRENCH_DEPTH := 1.9
## The communication trench: [x off the road, z] corners, front to back.
const TRENCH := [[-5.0, -2.0], [-12.0, -14.0], [-9.0, -26.0], [-17.0, -38.0], [-14.0, -50.0], [-21.0, -62.0], [-19.0, -76.0]]
## Craters: [x off the road, z, radius].
const CRATERS := [[11.0, -12.0, 4.5], [-28.0, -20.0, 4.0], [27.0, -64.0, 5.0], [-31.0, -46.0, 4.5], [9.0, -36.0, 3.5],
		[-6.0, -44.0, 3.0], [-27.0, -70.0, 3.5], [30.0, -12.0, 4.0], [-24.0, 18.0, 4.0], [20.0, 16.0, 3.5]]
## The dead titan lying face down on the right: its centre, this far right of the road.
const FALLEN_X := 22.0
const FALLEN_Z := -36.0
const FALLEN_UP := 3.4
const PICKET_Z := -50.0
const WALL_Z := -84.0
const YARD_Z := -108.0
## The rift runs across the whole valley between these lips (on grid lines).
const NEAR_LIP := -144.0
const FAR_LIP := -164.0
const RIFT_FLOOR := -18.0
const RIFT_Z := (NEAR_LIP + FAR_LIP) * 0.5
const BRIDGE_REACH := 2.0
## The tower shield to wallrun is wedged this far left of the bridge; the crane's
## anchor hangs this far right, ANCHOR_Y up; the ruin columns stand further right.
const SHIELD_X := -4.5
const ANCHOR_X := 4.5
const ANCHOR_Y := 11.0
const PILLAR_X := 16.0
const PILLAR := 5.0
const PILLARS := [[-147.3, -0.4], [-155.7, -0.2]]
## The fallen obelisk lies across the rift this far left of the bridge.
const LOG_X := -24.0
## The ruins sit on a rise this high.
const RUIN_Y := 3.0
const RUINS_Z := -202.0
const END_Z := -250.0
const KILL_Y := -8.0

const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const GREEN := Color(0.3, 0.75, 0.4)
const CONCRETE := Color(0.55, 0.56, 0.55)
const ASH := Color(0.66, 0.6, 0.54)
const CHAR := Color(0.36, 0.33, 0.31)


# --- the valley's shape --------------------------------------------------------

static func trail_x(z: float) -> float:
	return 6.0 * sin((z + 10.0) / 36.0)


static func _plateau(z: float, lo: float, hi: float, ramp: float) -> float:
	if z > hi:
		return clampf(1.0 - (z - hi) / ramp, 0.0, 1.0)
	if z < lo:
		return clampf(1.0 - (lo - z) / ramp, 0.0, 1.0)
	return 1.0


static func half_width(z: float) -> float:
	return 34.0 + 5.0 * maxf(_plateau(z, -134.0, -84.0, 10.0), _plateau(z, -232.0, -176.0, 10.0))


static func base_height(z: float) -> float:
	if z >= -170.0:
		return 0.0
	if z >= -188.0:
		return RUIN_Y * smoothstep(-170.0, -188.0, z)
	return RUIN_Y


static func _bumps(x: float, z: float) -> float:
	return 0.7 * sin(x * 0.19 + z * 0.11) * sin(z * 0.23 - x * 0.08) + 0.35 * sin(x * 0.47 + 1.3) * sin(z * 0.41 + 0.7)


## The front-line trench's centre z at x: it wanders a little.
static func front_z(x: float) -> float:
	return FRONT_Z + 1.5 * sin(x * 0.12)


## The communication trench's corners as world points (x, z).
static func trench_points() -> Array:
	var pts := []
	for p in TRENCH:
		pts.append(Vector2(trail_x(p[1]) + p[0], p[1]))
	return pts


## The communication trench's centre x at z (on the polyline).
static func trench_x(z: float) -> float:
	var pts := trench_points()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if z <= a.y and z >= b.y:
			return lerpf(a.x, b.x, (a.y - z) / (a.y - b.y))
	return (pts[-1] as Vector2).x


## 0 to 1: how far down a trench (x, z) is. Steep sides, a 2.8 m floor.
static func trench(x: float, z: float) -> float:
	var t := clampf((2.1 - absf(z - front_z(x))) / 0.7, 0.0, 1.0)
	if z < 1.0 and z > -80.0:
		var pts := trench_points()
		var p := Vector2(x, z)
		var best := 99.0
		for i in pts.size() - 1:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p))
		# It ramps up out of the ground over its last few metres.
		var fade := clampf((z + 76.0) / 5.0, 0.0, 1.0)
		t = maxf(t, clampf((2.1 - best) / 0.7, 0.0, 1.0) * fade)
	return t


static func crater(x: float, z: float) -> float:
	var h := 0.0
	for c in CRATERS:
		var d := Vector2(x, z).distance_to(Vector2(trail_x(c[1]) + c[0], c[1]))
		var r: float = c[2]
		if d < r:
			h += -1.8 * (1.0 - (d / r) * (d / r))
		elif d < r * 1.5:
			h += 0.5 * sin((d - r) / (r * 0.5) * PI)
	return h


## Ground height anywhere in the zone.
static func ground(x: float, z: float) -> float:
	if z < NEAR_LIP and z > FAR_LIP:
		return RIFT_FLOOR + 1.0 * sin(x * 0.3) * sin(z * 0.7)
	var c := trail_x(z)
	var d := absf(x - c)
	var w := half_width(z)
	var h := base_height(z)
	var flat := maxf(_plateau(z, -136.0, -82.0, 6.0), _plateau(z, -232.0, -140.0, 6.0))
	var rough := maxf(1.0 - flat, clampf((d - w) / 8.0, 0.0, 1.0))
	h += _bumps(x, z) * rough * (0.3 if d < 5.0 else 0.6)
	h += crater(x, z) - TRENCH_DEPTH * trench(x, z)
	if d > w:
		var o := d - w
		h += minf(o * 0.5 + o * o * 0.015, 16.0) + (0.5 + 0.5 * sin(z * 0.05 + x * 0.03)) * minf(o / 12.0, 1.0) * 4.0
	return h


static func _on(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, ground(x, z) + up, z)


static func _road(z: float, off := 0.0, up := 0.0) -> Vector3:
	return _on(trail_x(z) + off, z, up)


static func _fallen_top() -> Vector3:
	var x := trail_x(FALLEN_Z) + FALLEN_X
	return Vector3(x, ground(x, FALLEN_Z) + FALLEN_UP, FALLEN_Z)


# --- the zone ------------------------------------------------------------------

static func build_zone(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	L.environment(root, Color(0.34, 0.31, 0.33), Color(0.8, 0.62, 0.48), 0.0065, Color(1.0, 0.7, 0.45), 1.15, -20.0)
	Ambience.start(root, {"wind_soft": -11.0, "forest_wind": -17.0, "radio_static_loop": -32.0})
	var info := L.info(NAME, _road(8.0, 0.0, 0.1), RIFT_FLOOR, KILL_Y)
	var guard_yard := rng.randf() < 0.5
	var dress := RandomNumberGenerator.new()
	dress.seed = rng.randi()

	L.terrain(root, ground, GRID_X, GRID_Z, CELL, Color(0.6, 0.6, 0.64), Color(0.66, 0.64, 0.64), "dirt", "gravel")
	L.fences(root, func(z): return Vector2(trail_x(z) - half_width(z) - 6.0, trail_x(z) + half_width(z) + 6.0), 30.0, -268.0)
	L.strip(root, ground, trail_x, 20.0, END_Z - 4.0, 2.2, Art.material("dirt", Color(0.58, 0.55, 0.54)),
			func(z): return (z < NEAR_LIP + 2.0 and z > FAR_LIP - 2.0) or absf(z - FRONT_Z) < 2.5)
	var keep_out: Array = []
	_trenches(root, dress, info, keep_out)
	_no_mans_land(root, rng, dress, info, keep_out)
	_yard(root, rng, dress, info, keep_out, guard_yard)
	_rift(root, rng, dress, info, keep_out)
	_ruins(root, rng, dress, info, keep_out, not guard_yard)
	_end(root, dress, info, keep_out)
	_burn(root, dress, info, keep_out)
	_routes(info)
	L.collect_cover(root, info)

	for z in [8.0, -30.0, -62.0, YARD_Z, NEAR_LIP + 8.0, FAR_LIP - 10.0, RUINS_Z, -236.0]:
		info["checkpoints"].append(_road(z, 0.0, 0.1))
	var cr := trail_x(RIFT_Z)
	for p in [Vector2(trench_x(-30.0), -30.0), Vector2(trench_x(-60.0), -60.0), Vector2(cr + LOG_X, NEAR_LIP + 7.0),
			Vector2(cr + LOG_X, FAR_LIP - 7.0), Vector2(trail_x(-200.0) - 26.0, -200.0)]:
		info["checkpoints"].append(_on(p.x, p.y, 0.1))
	info["checkpoints"].append(_fallen_top() + Vector3(0, 0.1, 0))
	return info


static func _post(root: Node3D, info: Dictionary, x: float, z: float, leash := 2.0) -> Node:
	return L.grunt(root, info, _on(x, z), Vector3(0, 0, 1), ZONE, leash)


# --- 1. the trenches -----------------------------------------------------------

static func _trenches(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var c0 := trail_x(FRONT_Z)
	# The front line, across the valley: plank walls, sandbags on the lip.
	var x := c0 - 34.0
	while x < c0 + 34.0:
		if absf(x - c0) > 3.5:
			var zt := front_z(x)
			var floor_y := ground(x, zt)
			var yaw := -rad_to_deg(atan(1.5 * 0.12 * cos(x * 0.12)))
			Z.spawn(root, "revetment", Vector3(x, floor_y, zt - 1.45), yaw)
			if rng.randf() < 0.7:
				Z.spawn(root, "revetment", Vector3(x + 0.6, floor_y, zt + 1.45), yaw + 180.0)
			F.stealth_cover(root, Vector3(x, floor_y + 0.9, zt), Vector3(4.0, 1.8, 2.6), yaw)
		x += 4.0
	# Planks over it where the road crosses.
	Kit.box(root, Vector3(c0, 0.1, front_z(c0)), Vector3(4.6, 0.3, 5.0), Color(0.6, 0.5, 0.4), Vector3.ZERO, Art.material("wood"))
	keep_out.append(Rect2(c0 - 40.0, FRONT_Z - 4.0, 80.0, 8.0))
	# The communication trench forward on the left.
	var pts := trench_points()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir := (b - a).normalized()
		var yaw := rad_to_deg(atan2(-dir.x, -dir.y))
		var right := Vector2(-dir.y, dir.x)
		var length := a.distance_to(b)
		var t := 2.0
		var k := 0
		while t < length - 1.0:
			var p := a + dir * t
			var floor_y := ground(p.x, p.y)
			F.stealth_cover(root, Vector3(p.x, floor_y + 0.9, p.y), Vector3(2.8, 1.8, 4.2), yaw)
			if p.y > -72.0:
				var side := 1.0 if k % 2 == 0 else -1.0
				var w := p + right * side * 1.45
				Z.spawn(root, "revetment", Vector3(w.x, floor_y, w.y), yaw + 90.0 * side)
			t += 4.0
			k += 1
		keep_out.append(Rect2(minf(a.x, b.x) - 3.0, minf(a.y, b.y) - 3.0, absf(a.x - b.x) + 6.0, absf(a.y - b.y) + 6.0))
	# A dugout where the two trenches meet.
	Kit.box(root, _on(pts[0].x - 2.5, pts[0].y - 3.0, 0.2), Vector3(3.0, 0.3, 3.0), Color(0.6, 0.5, 0.4), Vector3.ZERO, Art.material("wood"))
	keep_out.append(Rect2(c0 - 8.0, 2.0, 16.0, 14.0))


# --- 2. no-man's land ----------------------------------------------------------

static func _no_mans_land(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var tint: Color = Z.HULL_TINTS[0]
	# The dead titan on its face (the high road starts at its hand).
	var top := _fallen_top()
	Z.titan_fallen(root, top, 90.0, Z.HULL_TINTS[1])
	keep_out.append(Rect2(top.x - 5.0, FALLEN_Z - 14.0, 10.0, 34.0))
	# One that died on its knees behind the picket, and a torn-off arm by the road.
	var c := trail_x(-60.0)
	Z.titan_kneeling(root, _on(c + 9.0, -60.0, -0.2), -10.0, Z.HULL_TINTS[2])
	keep_out.append(Rect2(c + 4.0, -65.0, 10.0, 10.0))
	Z.titan_arm(root, _on(trail_x(-22.0) + 9.0, -22.0, -0.2), -15.0, tint)
	keep_out.append(Rect2(trail_x(-22.0) + 3.0, -25.0, 12.0, 6.0))
	Z.scrap_pile(root, _road(14.0, 6.5), 30.0, tint)
	Z.scrap_pile(root, _road(-16.0, -5.5), 120.0, Z.HULL_TINTS[1])
	# Wire across no-man's land, with gaps for the road and the trench.
	for z in [-20.0, -68.0]:
		var x := trail_x(z) - 32.0
		while x < trail_x(z) + 30.0:
			var mid := x + 2.0
			var skip := absf(mid - trail_x(z)) < 5.0 or absf(mid - trench_x(z)) < 4.0 or absf(mid - (trail_x(FALLEN_Z) + FALLEN_X)) < 5.0
			if not skip and dress.randf() < 0.85:
				Z.barbed_wire(root, _on(mid, z + dress.randf_range(-0.6, 0.6), -0.1), dress.randf_range(-8, 8))
			x += 4.2
	# The picket on the road.
	var p := trail_x(PICKET_Z)
	F.sandbags(root, _on(p - 3.0, PICKET_Z), 5.0)
	F.sandbags(root, _on(p + 3.5, PICKET_Z - 1.0), -10.0)
	F.floodlight(root, _on(p - 6.0, PICKET_Z - 3.0), 20.0)
	F.barrels(root, _on(p + 6.5, PICKET_Z - 3.5), 30.0)
	keep_out.append(Rect2(p - 9.0, PICKET_Z - 6.0, 18.0, 10.0))
	for k in rng.randi_range(1, 2):
		_post(root, info, p + (-3.0 if k == 0 else 3.5), PICKET_Z - 1.2 - k)


# --- 3. the salvage yard -------------------------------------------------------

static func _yard(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var c := trail_x(YARD_Z)
	var cw := trail_x(WALL_Z)
	keep_out.append(Rect2(c - 34, -136, 68, 54))
	# The wall: slabs hillside to hillside, the gate gap on the road, and one
	# slab their crane knocked flat where the trench comes up.
	var flat_x := trench_x(-76.0)
	for k in 18:
		var x := cw - 34.0 + 4.0 * k
		if absf(x - cw) < 5.0:
			continue
		if absf(x - flat_x) < 2.1:
			Kit.box(root, _on(x, WALL_Z + 3.2, 0.4), Vector3(4.0, 0.8, 6.0), CONCRETE, Vector3(0, 8, 0), Art.material("concrete"))
			continue
		var y := minf(minf(ground(x - 2.0, WALL_Z), ground(x + 2.0, WALL_Z)), ground(x, WALL_Z)) - 0.3
		F.wall_slab(root, Vector3(x, y, WALL_Z))
	F.sandbags(root, _on(cw - 6.0, WALL_Z + 2.5), 10.0)
	F.sandbags(root, _on(cw + 6.5, WALL_Z + 3.0), -15.0)
	F.floodlight(root, _on(cw + 8.0, WALL_Z - 1.5), 0.0)
	# The high road over it: a container, a crate on it, a stack of two, the wall top.
	var hx := cw + 24.0
	Z.container(root, _on(hx, -75.0, -0.1), 0.0, Z.CONTAINER_TINTS[0])
	Kit.box(root, Vector3(hx - 1.8, ground(hx, -75.0) - 0.1 + 3.2, -75.0), Vector3(1.2, 1.2, 1.2), GREEN)
	var stack := _on(hx, -80.2, -0.1)
	Z.container(root, stack, 0.0, Z.CONTAINER_TINTS[1])
	Z.container(root, stack + Vector3(0, 2.6, 0), 0.0, Z.CONTAINER_TINTS[3])
	# Inside: container stacks down the right.
	var inner := _on(c + 24.0, -88.4, -0.1)
	Z.container(root, inner, 0.0, Z.CONTAINER_TINTS[2])
	var stack_top := Z.container(root, inner + Vector3(0, 2.6, 0), 0.0, Z.CONTAINER_TINTS[0])
	Z.container(root, _on(c + 24.0, -95.0, -0.1), 0.0, Z.CONTAINER_TINTS[3])
	Z.container(root, _on(c + 26.0, -124.0, -0.1), 90.0, Z.CONTAINER_TINTS[1])
	Z.container(root, _on(c + 22.0, -124.0, -0.1), 90.0, Z.CONTAINER_TINTS[2])
	Z.container(root, _on(c - 27.0, -95.0, -0.1), 90.0, Z.CONTAINER_TINTS[2])
	Z.container(root, _on(c - 27.0, -121.0, -0.1), 80.0, Z.CONTAINER_TINTS[0])
	# The gantry over the titan they're stripping.
	var gx := c + 12.0
	Z.gantry(root, _on(gx, -114.0), 0.0)
	Z.titan_kneeling(root, _on(gx, -114.5, -0.3), 0.0, Z.HULL_TINTS[0])
	Z.scrap_pile(root, _on(gx - 6.0, -108.0), 40.0, Z.HULL_TINTS[2])
	Z.scrap_pile(root, _on(gx + 6.5, -120.0), 160.0, Z.HULL_TINTS[1])
	Z.titan_arm(root, _on(gx + 3.0, -104.0), 80.0, Z.HULL_TINTS[0])
	# The strip shed on the left, a generator and lamps.
	Z.salvage_shed(root, _on(c - 14.0, -106.0), 0.0)
	F.generator(root, _on(c - 6.0, -116.0), 90.0)
	F.floodlight(root, _on(c - 4.0, -90.0), 0.0)
	F.floodlight(root, _on(c + 8.0, -128.0), 180.0)
	F.barrels(root, _on(c - 20.0, -98.0), 10.0)
	F.barrels(root, _on(c + 18.0, -100.0), 40.0)
	F.pallet(root, _on(c - 8.0, -128.0), 0.0)
	F.wreck_truck(root, _on(c - 4.0, -122.0), 75.0)
	var deck := F.watchtower(root, _on(c - 10.0, -132.0), 0.0)
	L.grunt(root, info, deck + Vector3(0, 0, 0.6), Vector3(0, 0, 1), ZONE, 0.6)
	# Dead grass along the left fence, for the trench crawlers.
	for z in [-90.0, -100.0, -112.0, -124.0, -134.0]:
		L.hide(root, ground, dress, info, c - 31.0 + dress.randf_range(-1, 1), z, Vector2(4.0, 7.0), true)
	# The squad in the yard, facing the gate.
	var posts := [Vector2(c + 1.0, -96.0), Vector2(c - 4.0, -99.5), Vector2(c + 6.0, -98.5), Vector2(c - 1.0, -104.0)]
	F.sandbags(root, _on(posts[0].x, posts[0].y), 6.0)
	F.sandbags(root, _on(posts[1].x, posts[1].y), -8.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].y), 5.0)
	F.sandbags(root, _on(posts[3].x, posts[3].y), 20.0)
	var squad := []
	for k in rng.randi_range(2, 4):
		var p: Vector2 = posts[k]
		squad.append(_post(root, info, p.x, p.y - (1.1 if k != 2 else 1.3)))
	if guarded:
		L.guard(root, info, L.cache(root, info, _on(c + 2.0, -111.0)), squad)
	else:
		L.cache(root, info, stack_top + Vector3(-1.0, 0, 0))


# --- 4. the rift ---------------------------------------------------------------

static func _rift(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var c := trail_x(RIFT_Z)
	keep_out.append(Rect2(c - 9.0, FAR_LIP - 12.0, 31.0, NEAR_LIP - FAR_LIP + 24.0))
	keep_out.append(Rect2(c + LOG_X - 3.0, FAR_LIP - 6.0, 6.0, NEAR_LIP - FAR_LIP + 12.0))
	var gap := (NEAR_LIP - FAR_LIP) - BRIDGE_REACH * 2.0
	var near_end := NEAR_LIP - BRIDGE_REACH
	var far_end := FAR_LIP + BRIDGE_REACH
	F.bridge_stub(root, Vector3(c, 0, near_end + 5.0), 0.0)
	F.bridge_stub(root, Vector3(c, 0, far_end - 5.0), 180.0)
	# Route 1: a titan's tower shield wedged upright in the rift. Wallrun it.
	var mid := (near_end + far_end) * 0.5
	# What the tutorial points at (tutorial.gd): each crossing's pieces.
	var crossing := {"lip": _road(NEAR_LIP + 14.0, 0.0), "wallrun": [], "grapple": [], "pillars": [], "log": []}
	info["crossing"] = crossing
	crossing["wallrun"].append(Kit.box(root, Vector3(c + SHIELD_X, 0, mid), Vector3(1, 12, gap), BLUE))
	Kit.box(root, Vector3(c + SHIELD_X - 0.3, 6.3, mid), Vector3(1.4, 0.8, gap + 1.2), CONCRETE, Vector3.ZERO, Art.material("titan_armor", Z.HULL_TINTS[1]))
	Kit.box(root, Vector3(c + SHIELD_X - 0.3, 0, mid - gap * 0.5 - 0.3), Vector3(1.4, 12.6, 0.8), CONCRETE, Vector3.ZERO, Art.material("titan_armor", Z.HULL_TINTS[1]))
	Kit.box(root, Vector3(c + SHIELD_X - 0.3, 0, mid + gap * 0.5 + 0.3), Vector3(1.4, 12.6, 0.8), CONCRETE, Vector3.ZERO, Art.material("titan_armor", Z.HULL_TINTS[1]))
	info["segments"].append({"type": "wallrun", "gap": gap, "rise": 0.0})
	# Route 2: the strippers' crane on the far lip. Grapple its anchor.
	var anchor_z := near_end - gap * 0.6
	F.pylon(root, Vector3(c + ANCHOR_X, 0, anchor_z - 9.0), 0.0)
	crossing["grapple"].append(Kit.box(root, Vector3(c + ANCHOR_X, ANCHOR_Y, anchor_z), Vector3(3, 2, 3), ORANGE))
	info["segments"].append({"type": "grapple", "gap": gap, "rise": 0.0})
	# Route 3: precursor columns standing up out of the rift. Hop them.
	var px := c + PILLAR_X
	var last_edge := NEAR_LIP
	var last_top := 0.0
	for p in PILLARS:
		var front: float = p[0]
		var top: float = p[1]
		var back := front - PILLAR
		var h := top - RIFT_FLOOR + 1.0
		crossing["pillars"].append(Kit.box(root, Vector3(px, top - h * 0.5, (front + back) * 0.5), Vector3(PILLAR, h, PILLAR), CONCRETE, Vector3.ZERO, Art.material("temple_stone")))
		Kit.box(root, Vector3(px, top - 0.25, (front + back) * 0.5), Vector3(PILLAR + 0.3, 0.5, PILLAR + 0.3), CONCRETE, Vector3.ZERO, Art.material("temple_carving"))
		info["segments"].append({"type": "jump", "gap": last_edge - front, "rise": top - last_top})
		last_edge = back
		last_top = top
	info["segments"].append({"type": "jump", "gap": last_edge - FAR_LIP, "rise": -last_top})
	# Route 4: a precursor obelisk fell across the rift. Walk along it.
	var before := root.get_child_count()
	Z.obelisk_fallen(root, Vector3(c + LOG_X, 0.0, RIFT_Z), 90.0)
	crossing["log"] = root.get_children().slice(before)
	L.hide(root, ground, dress, info, c + LOG_X - 3.0, NEAR_LIP + 5.0, Vector2(3.0, 5.0), true)
	L.hide(root, ground, dress, info, c + LOG_X + 3.5, FAR_LIP - 5.0, Vector2(3.0, 6.0), true)
	for z in [NEAR_LIP + 1.0, FAR_LIP - 1.0]:
		for i in 12:
			var x := c - 48.0 + i * 8.5 + rng.randf_range(-2, 2)
			if absf(x - c) < 5.0 or absf(x - px) < 3.5 or absf(x - (c + LOG_X)) < 3.0:
				continue
			F.rock(root, ["rock_a", "rock_b", "rock_c"][i % 3], _on(x, z), rng.randf_range(0, 360), rng.randf_range(1.0, 1.8))
	var picket := [Vector2(c - 9.0, FAR_LIP - 8.0), Vector2(c + 10.0, FAR_LIP - 9.0)]
	for k in picket.size():
		var p: Vector2 = picket[k]
		F.sandbags(root, _on(p.x, p.y), rng.randf_range(-10, 10))
		if k == 0 or rng.randf() < 0.6:
			_post(root, info, p.x, p.y - 1.1)
	F.floodlight(root, _on(c + 6.0, FAR_LIP - 14.0), 180.0)
	Z.scrap_pile(root, _on(c - 4.0, FAR_LIP - 13.0), 20.0, Z.HULL_TINTS[0])


# --- 5. the ruins --------------------------------------------------------------

static func _ruins(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var c := trail_x(RUINS_Z)
	keep_out.append(Rect2(c - 22, -232, 44, 52))
	# A ring of the precursor's columns round a court, some still standing.
	for i in 12:
		var a := TAU * i / 12.0 + 0.12
		var p := Vector2(c + sin(a) * 16.0, RUINS_Z + cos(a) * 15.0)
		if absf(p.x - trail_x(p.y)) < 5.0:
			continue
		if i % 4 == 3:
			Kit.box(root, _on(p.x, p.y, 0.9), Vector3(2.0, 1.8, 7.0), CONCRETE, Vector3(0, rad_to_deg(a) + 70.0, 0), Art.material("temple_stone"))
			continue
		Z.ruin_pillar(root, _on(p.x, p.y, -0.1), rad_to_deg(a) + 180.0, i % 3 == 1)
	Z.eye_shrine(root, _on(c, -226.0, -0.1), 0.0)
	# The colony's radio post in the court.
	F.antenna(root, _on(c + 12.0, -192.0))
	var hut := _on(c - 14.0, -204.0)
	var hut_roof := F.hut(root, hut, 90.0)
	Kit.box(root, _on(c - 10.6, -199.0, 0.6), Vector3(1.2, 1.2, 1.2), GREEN)
	var column_top := Z.ruin_pillar(root, _on(c - 14.0, -210.4, -0.1), 0.0, true)
	F.generator(root, _on(c - 9.0, -210.0), 0.0)
	F.crate_stack(root, _on(c + 9.0, -206.0), 15.0)
	F.camo_net(root, _on(c + 8.0, -214.0), 0.0)
	F.tent(root, _on(c + 6.0, -214.0), 0.0)
	F.tent(root, _on(c + 10.5, -214.0), 0.0)
	F.floodlight(root, _on(c - 4.0, -186.0), 0.0)
	F.floodlight(root, _on(c + 6.0, -220.0), 180.0)
	var deck := F.watchtower(root, _on(c + 16.0, -214.0), -20.0)
	L.grunt(root, info, deck + Vector3(0, 0, 0.6), Vector3(0, 0, 1), ZONE, 0.6)
	# Dead grass up the left side.
	for z in [-180.0, -192.0, -204.0, -216.0, -228.0]:
		L.hide(root, ground, dress, info, c - 27.0 + dress.randf_range(-1.5, 1.5), z, Vector2(4.5, 8.0), z != -204.0)
	var posts := [Vector2(c + 2.0, -193.0), Vector2(c - 5.0, -196.0), Vector2(c + 7.5, -196.5), Vector2(c + 0.5, -200.0)]
	F.sandbags(root, _on(posts[0].x, posts[0].y), -5.0)
	F.sandbags(root, _on(posts[1].x, posts[1].y), 12.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].y), 0.0)
	F.sandbags(root, _on(posts[3].x, posts[3].y), 0.0)
	var squad := []
	for k in rng.randi_range(3, 4):
		var p: Vector2 = posts[k]
		squad.append(_post(root, info, p.x, p.y - (1.1 if k != 2 else 1.3)))
	if guarded:
		L.guard(root, info, L.cache(root, info, _on(c + 1.0, -207.0)), squad)
	else:
		L.cache(root, info, column_top)
	info["ruin_hut_roof"] = hut_roof


# --- 6. the edge of the burn ------------------------------------------------------

static func _end(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var x := trail_x(END_Z)
	L.beacon(root, info, _on(x, END_Z), "EXTRACT: TITANFALL")
	keep_out.append(Rect2(x - 12, END_Z - 12, 24, 24))
	F.spawn(root, "rock_b", _on(x - 6.0, END_Z - 4.0), 40.0, 1.8)
	F.spawn(root, "rock_a", _on(x + 7.0, END_Z + 2.0), 10.0, 1.5)


# --- the routes ----------------------------------------------------------------

static func _routes(info: Dictionary) -> void:
	var cr := trail_x(RIFT_Z)
	var cy := trail_x(YARD_Z)
	var cu := trail_x(RUINS_Z)
	var loud := PackedVector3Array()
	var z := 8.0
	while z > END_Z:
		var x := cr if (z < NEAR_LIP + 8.0 and z > FAR_LIP - 8.0) else trail_x(z)
		loud.append(Vector3(x, 0.3, z) if (z < NEAR_LIP and z > FAR_LIP) else _on(x, z, 0.3))
		z -= 4.0
	var quiet := PackedVector3Array()
	quiet.append(_on(trail_x(FRONT_Z) - 3.0, front_z(trail_x(FRONT_Z) - 3.0), 0.3))
	z = -6.0
	while z > -76.0:
		quiet.append(_on(trench_x(z), z, 0.3))
		z -= 4.0
	for p in [Vector2(trench_x(-76.0), WALL_Z + 2.0), Vector2(trench_x(-76.0), WALL_Z - 4.0), Vector2(cy - 30.0, -96.0),
			Vector2(cy - 30.0, -112.0), Vector2(cy - 30.0, -128.0), Vector2(cr + LOG_X, NEAR_LIP + 6.0)]:
		quiet.append(_on(p.x, p.y, 0.3))
	quiet.append(Vector3(cr + LOG_X, 0.3, NEAR_LIP))
	quiet.append(Vector3(cr + LOG_X, 0.3, FAR_LIP))
	for p in [Vector2(cr + LOG_X, -172.0), Vector2(cu - 27.0, -184.0), Vector2(cu - 27.0, -204.0), Vector2(cu - 26.0, -226.0),
			Vector2(trail_x(END_Z) - 6.0, END_Z + 4.0), Vector2(trail_x(END_Z), END_Z)]:
		quiet.append(_on(p.x, p.y, 0.3))
	var high := PackedVector3Array()
	var top := _fallen_top()
	high.append(top + Vector3(3.6, -2.4, 15.0))
	high.append(top + Vector3(-0.4, -0.1, 11.2))
	z = top.z + 8.0
	while z > top.z - 11.0:
		high.append(Vector3(top.x, top.y + 0.3, z))
		z -= 4.0
	var hx := trail_x(WALL_Z) + 24.0
	for p in [_on(hx, -72.0, 0.3), Vector3(hx, ground(hx, -75.0) + 2.8, -75.0), Vector3(hx - 1.8, ground(hx, -75.0) + 4.1, -75.0),
			Vector3(hx, ground(hx, -80.2) + 5.3, -80.2), Vector3(hx, 6.3, WALL_Z), Vector3(cy + 24.0, ground(cy + 24.0, -88.4) + 5.3, -88.4),
			Vector3(cy + 24.0, ground(cy + 24.0, -95.0) + 2.8, -95.0), _on(cy + 20.0, -134.0, 0.3),
			_on(cr + ANCHOR_X, NEAR_LIP + 2.0, 0.3), Vector3(cr + ANCHOR_X, ANCHOR_Y - 1.0, NEAR_LIP - BRIDGE_REACH - 9.6),
			_on(cr + 2.0, FAR_LIP - 6.0, 0.3), _on(cu - 10.6, -199.0, 1.5), _on(cu - 14.0, -204.0, 3.8),
			_on(cu - 14.0, -210.4, 4.7), _on(cu - 8.0, -222.0, 0.3), _on(trail_x(END_Z) + 2.0, END_Z, 0.3)]:
		high.append(p)
	info["routes"] = [
		{"name": "The haul road", "kind": "loud", "points": loud},
		{"name": "The old trenches", "kind": "quiet", "points": quiet},
		{"name": "The titan's back and the containers", "kind": "high", "points": high},
	]


# --- the burnt valley ------------------------------------------------------------

static func _bare(x: float, z: float, keep_out: Array) -> bool:
	if absf(x - trail_x(z)) < 4.5 or Vector2(x, z).distance_to(Vector2(trail_x(8.0), 8.0)) < 9.0:
		return true
	if trench(x, z) > 0.0:
		return true
	for r in keep_out:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


## A burnt snag with a trunk collider.
static func _snag(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, scale: float) -> void:
	var s := scale * rng.randf_range(0.85, 1.3)
	F.spawn(root, "snag", pos, rng.randf_range(0, 360), s, {"bark": CHAR})
	Z.column(root, pos, 0.45 * s, 7.0 * s)


static func _burn(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var cr := trail_x(RIFT_Z)
	var z := 34.0
	while z > -262.0:
		var w := half_width(z) + 3.0
		var x := trail_x(z) - w
		while x < trail_x(z) + w:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), z + rng.randf_range(-2.0, 2.0))
			var in_rift := p.y < NEAR_LIP + 1.5 and p.y > FAR_LIP - 1.5
			var edge := absf(p.x - trail_x(p.y)) > 18.0
			if rng.randf() < (0.5 if edge else 0.18) and not _bare(p.x, p.y, keep_out) and not (in_rift and absf(p.x - cr) < 34.0):
				if p.y < -238.0 and rng.randf() < 0.7:
					F.tree(root, _on(p.x, p.y, -0.2), rng, rng.randf_range(0.9, 1.3), ["pine_a", "pine_b", "pine_c"][rng.randi() % 3])
				elif rng.randf() < 0.2:
					# Half burnt: the needles gone black.
					F.spawn(root, ["pine_a", "pine_c"][rng.randi() % 2], _on(p.x, p.y, -0.2), rng.randf_range(0, 360), rng.randf_range(0.9, 1.2),
							{"leaves": Color(0.22, 0.2, 0.18), "bark": CHAR})
					Z.column(root, _on(p.x, p.y, -0.2), 0.45, 7.0)
				else:
					_snag(root, _on(p.x, p.y, -0.2), rng, rng.randf_range(0.9, 1.4))
			x += 5.4
		z -= 5.4
	# Rubble and rocks.
	var rocks := 0
	var tries := 0
	while rocks < 36 and tries < 600:
		tries += 1
		var rz := rng.randf_range(-258.0, 30.0)
		var rx := trail_x(rz) + rng.randf_range(-30.0, 30.0)
		if _bare(rx, rz, keep_out) or (rz < NEAR_LIP + 3.0 and rz > FAR_LIP - 3.0):
			continue
		F.rock(root, ["rock_a", "rock_b", "rock_c"][rocks % 3], _on(rx, rz), rng.randf_range(0, 360), rng.randf_range(0.8, 2.0))
		rocks += 1
	# More wreckage out in the open.
	for i in 8:
		var sz := rng.randf_range(-236.0, 24.0)
		var sx := trail_x(sz) + rng.randf_range(-28.0, 28.0)
		if _bare(sx, sz, keep_out) or (sz < NEAR_LIP + 4.0 and sz > FAR_LIP - 4.0):
			continue
		Z.scrap_pile(root, _on(sx, sz, -0.2), rng.randf_range(0, 360), Z.HULL_TINTS[i % 3])
	# Dead grass to hide in, out in the open.
	var patches := 0
	tries = 0
	while patches < 24 and tries < 600:
		tries += 1
		var gz := rng.randf_range(-258.0, 20.0)
		var gx := trail_x(gz) + rng.randf_range(-29.0, 29.0)
		if _bare(gx, gz, keep_out) or (gz < NEAR_LIP + 3.0 and gz > FAR_LIP - 3.0):
			continue
		L.hide(root, ground, rng, info, gx, gz, Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(3.0, 6.0)), rng.randf() < 0.3, rng.randf_range(0, 180))
		patches += 1
	# Far off: more of the burn, then living forest at the far end.
	var far := {"snag": [], "pine_a": [], "pine_b": []}
	z = 66.0
	while z > -296.0:
		for side in [-1.0, 1.0]:
			var d := half_width(z) + 4.0
			while d < half_width(z) + 80.0:
				var px: float = trail_x(z) + side * (d + rng.randf_range(-2.0, 2.0))
				var pz := z + rng.randf_range(-2.5, 2.5)
				var id: String = "snag" if pz > -240.0 or rng.randf() < 0.3 else ["pine_a", "pine_b"][rng.randi() % 2]
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
				far[id].append(Transform3D(basis, _on(px, pz, -0.3)))
				d += rng.randf_range(5.0, 8.0)
		z -= 5.5
	for zz in [[30.0, 66.0], [-296.0, -262.0]]:
		for i in 200:
			var pz := rng.randf_range(zz[0], zz[1])
			var px := trail_x(pz) + rng.randf_range(-70.0, 70.0)
			var id: String = "snag" if pz > 0.0 else ["pine_a", "pine_b"][i % 2]
			far[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), _on(px, pz, -0.3)))
	Z.scatter(root, "snag", far["snag"], {"bark": CHAR})
	for id in ["pine_a", "pine_b"]:
		Z.scatter(root, id, far[id], {"leaves": F.NEEDLE_TINTS[0]})
	for i in 16:
		var ang := TAU * i / 16.0
		var base := Vector3(sin(ang) * 240.0, -6.0, -110.0 + cos(ang) * 270.0)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.0, 1.4),
				{"hill_forest": Color(0.62, 0.55, 0.5)})
	# Dry grass over the ash, thicker toward the living forest.
	var grass := []
	tries = 0
	while grass.size() < 6000 and tries < 60000:
		tries += 1
		var pz := rng.randf_range(-262.0, 30.0)
		var px := trail_x(pz) + rng.randf_range(-half_width(pz) - 4.0, half_width(pz) + 4.0)
		if pz < NEAR_LIP + 0.5 and pz > FAR_LIP - 0.5:
			continue
		if absf(px - trail_x(pz)) < 2.4 or (pz > -230.0 and rng.randf() < 0.45):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4))
		grass.append(Transform3D(basis, _on(px, pz, -0.05)))
	F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.86, 0.76, 0.52)}, false)
	F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.9, 0.78, 0.52)}, false)
	info["tall_grass"] = []
