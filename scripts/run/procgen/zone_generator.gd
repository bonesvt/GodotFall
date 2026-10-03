extends RefCounted
## Builds a generated run zone from a level plan (level_plan.gd): the ground,
## each section's set pieces lane by lane, the wilds between the lanes, the
## routes, the checkpoints and the grunts (posted, and patrolling on the
## navmesh: nav.gd). Returns the same dictionary as the handmade zones
## (ZoneBuilder.build_zone, laid_out.gd info()) plus:
##   plan: the LevelPlan
##   patrols: each patrol's loop of points
##   structures: building footprints (Rect2 in x, z) for the map
##   loot_spots: {"node": [...], "crate": [...]} where loot.gd puts loot first
##   loot_counts: {"node": n, "crate": n} for this zone
## How every lane gets through each kind of section is in level_plan.gd.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const B := preload("res://scripts/run/procgen/biome.gd")
const Nav := preload("res://scripts/run/procgen/nav.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const L := preload("res://scripts/run/laid_out.gd")

const CELL := 2.0
const THREAT_SPAWNER := "res://scripts/threats/threat_spawner.gd"
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const GREEN := Color(0.3, 0.75, 0.4)
const CONCRETE := Color(0.55, 0.56, 0.55)
## The road's crossing at a chasm, from the Pinewoods' ravine: the blast
## shield hangs this far to one side of the road, the crane's anchor this far
## to the other, ANCHOR_Y above the lip.
const SHIELD_X := 4.5
const ANCHOR_X := 4.5
const ANCHOR_Y := 11.0
## The ridge's rock pillars: [front edge past the near lip, height below the ridge top], PILLAR square.
const PILLAR := 5.0
const PILLARS := [[3.3, 0.2], [11.7, 0.0]]
## Gap left between buildings on a rooftop run (m).
const ROOF_GAP := 3.0
const WALL_H := 6.0


## A generated zone for the run: planned from the run's rng, so a run seed
## always gets the same zones.
static func build_zone(root: Node3D, rng: RandomNumberGenerator, zone_index: int) -> Dictionary:
	var plan = LevelPlan.make(rng.randi_range(1, 2147483646), zone_index)
	return build_from_plan(root, plan, zone_index)


static func build_from_plan(root: Node3D, plan, zone_index: int) -> Dictionary:
	root.set_meta("biome", plan.biome)
	var rng := RandomNumberGenerator.new()
	rng.seed = plan.seed_value * 7 + 1
	var dress := RandomNumberGenerator.new()
	dress.seed = plan.seed_value * 13 + 5
	var ground: Callable = plan.ground
	var loud: int = plan.lane_of("loud")

	B.environment(root, plan.biome)
	var info := L.info(plan.zone_name, _on(plan, plan.lane_x(loud, plan.spawn_z), plan.spawn_z, 0.1), plan.floor_y, plan.kill_y)
	info["plan"] = plan
	info["patrols"] = []
	info["structures"] = []
	info["loot_spots"] = {"node": [], "crate": []}
	info["loot_counts"] = {"node": 3 + mini(zone_index - 3, 2), "crate": 7 + plan.lanes.size() - 3}
	info["perches"] = {}
	info["catwalks"] = []
	info["crossings"] = []

	var hw: float = plan.half_width(0.0)
	var gx := snappedf(hw + 70.0, CELL)
	var style := B.ground_style(plan.biome)
	L.terrain(root, ground, Vector2(-gx, gx), Vector2(snappedf(plan.z_bottom - 50.0, CELL), snappedf(plan.z_top + 50.0, CELL)), CELL,
			style[0], style[1], style[2], style[3])
	if plan.biome == "marsh":
		L.water(root, Vector3(0, B.WATER_Y, (plan.z_top + plan.z_bottom) * 0.5), Vector2(gx * 2.0 + 200.0, plan.z_top - plan.z_bottom + 220.0),
				Color(0.09, 0.12, 0.08, 0.93))
	L.fences(root, func(z): return Vector2(plan.center_x(z) - plan.half_width(z) - 6.0, plan.center_x(z) + plan.half_width(z) + 6.0),
			plan.z_top - 2.0, plan.z_bottom + 2.0)
	L.strip(root, ground, func(z): return plan.lane_x(loud, z), plan.spawn_z + 6.0, plan.end_z - 4.0, 2.0, B.road_material(plan.biome),
			func(z): return _near_cut(plan, z))

	var keep_out: Array = []
	for s in plan.sections:
		match s["kind"]:
			"start":
				_start(root, plan, info, keep_out, s, dress)
			"field":
				_field(root, plan, info, keep_out, s, rng, dress, zone_index)
			"picket":
				_picket(root, plan, info, keep_out, s, rng, dress, zone_index)
			"wall":
				_wall(root, plan, info, keep_out, s, rng, dress, zone_index)
			"outpost", "camp":
				_yard(root, plan, info, keep_out, s, rng, dress, zone_index)
			"resource":
				_resource(root, plan, info, keep_out, s, rng, dress, zone_index)
			"chasm":
				_chasm(root, plan, info, keep_out, s, rng, dress, zone_index)
			"end":
				_end(root, plan, info, keep_out, s)
	_lanes(root, plan, info, keep_out, dress)
	_wilds(root, plan, info, keep_out, dress)
	_routes(plan, info)
	_checkpoints(plan, info)
	_crate_spots(plan, info, keep_out, dress)
	L.collect_cover(root, info)
	B.far_scenery(root, dress, plan, ground)
	_spawn_hooks(plan, info)
	# The Choir and wildlife (scripts/threats/threat_spawner.gd), when that's in.
	if ResourceLoader.exists(THREAT_SPAWNER):
		load(THREAT_SPAWNER).populate(root, rng, info, zone_index)
	Nav.setup(root, info)
	return info


## Places other spawners can put things: open ground in each field, the
## water in marsh gullies, the sky over each yard. [{pos, section, facing}].
static func _spawn_hooks(plan, info: Dictionary) -> void:
	var hooks := []
	var loud: int = plan.lane_of("loud")
	for s in plan.sections:
		var z: float = s["mid"]
		var x: float = plan.lane_x(loud, z)
		match s["kind"]:
			"field", "resource":
				hooks.append({"pos": _on(plan, (x + _patrol_x(plan, mini(loud + 1, plan.lanes.size() - 1), z)) * 0.5, z), "section": s["kind"], "facing": Vector3(0, 0, 1)})
			"outpost", "camp":
				hooks.append({"pos": _on(plan, x, z, 18.0), "section": "sky", "facing": Vector3(0, 0, 1)})
		if plan.biome == "marsh":
			for i in plan.lanes_of("quiet"):
				if plan.gully_on(z) > 0.9 and plan.clearing(plan.lane_x(i, z), z) < 0.1:
					hooks.append({"pos": _on(plan, plan.lane_x(i, z), z), "section": "water", "facing": Vector3(0, 0, 1)})
	info["spawn_hooks"] = hooks


# --- helpers -------------------------------------------------------------------

static func _on(plan, x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, plan.ground(x, z) + up, z)


## Near a chasm's gap or a wall: no road strip there.
static func _near_cut(plan, z: float) -> bool:
	for s in plan.sections:
		if s["kind"] == "chasm" and z < s["near_lip"] + 1.0 and z > s["far_lip"] - 1.0:
			return true
		if s["kind"] == "wall" and absf(z - s["wall_z"]) < 1.5:
			return true
	return false


## Notes a footprint (centre x, z; size x, z) so nothing else is put there.
static func _occupy(info: Dictionary, keep_out: Array, center: Vector2, size: Vector2) -> void:
	var r := Rect2(center - size * 0.5, size)
	keep_out.append(r)
	info["structures"].append(r)


static func _free(keep_out: Array, center: Vector2, size: Vector2) -> bool:
	var r := Rect2(center - size * 0.5, size)
	for k in keep_out:
		if (k as Rect2).intersects(r):
			return false
	return true


## Distance from x to the nearest lane centre at z.
static func _lane_dist(plan, x: float, z: float) -> float:
	var d := 999.0
	for i in plan.lanes.size():
		d = minf(d, absf(x - plan.lane_x(i, z)))
	return d


static func _grunt(root: Node3D, info: Dictionary, pos: Vector3, zone_index: int, leash := 2.0, facing := Vector3(0, 0, 1)) -> Node:
	return L.grunt(root, info, pos, facing, zone_index, leash)


## Two grunts walking a loop (points on the ground), starting opposite each other.
static func _patrol(root: Node3D, plan, info: Dictionary, loop: Array, zone_index: int, count := 2) -> void:
	var pts := PackedVector3Array()
	for p in loop:
		pts.append(_on(plan, p.x, p.y, 0.0))
	info["patrols"].append(pts)
	for k in count:
		var start := int(k * pts.size() / float(count))
		var g := _grunt(root, info, pts[start], zone_index, 0.0)
		g.set("patrol", pts)
		g.set("patrol_index", (start + 1) % pts.size())


## The lane beside the road a patrol loops through: a quiet one if there is
## one beside it (the patrol walks its gully), else whichever is there.
static func _patrol_lane(plan, rng: RandomNumberGenerator) -> int:
	var loud: int = plan.lane_of("loud")
	var sides := []
	for i in [loud - 1, loud + 1]:
		if i >= 0 and i < plan.lanes.size():
			sides.append(i)
	for i in sides:
		if plan.lanes[i]["kind"] == "quiet" and rng.randf() < 0.75:
			return i
	return sides[rng.randi() % sides.size()]


## Where a patrol walks at z on `lane`: in a gully itself, or on the flat
## below a ridge (halfway to the road).
static func _patrol_x(plan, lane: int, z: float) -> float:
	if plan.lanes[lane]["kind"] == "quiet":
		return plan.lane_x(lane, z)
	return (plan.lane_x(lane, z) + plan.lane_x(plan.lane_of("loud"), z)) * 0.5


# --- sections ------------------------------------------------------------------

static func _start(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, dress: RandomNumberGenerator) -> void:
	var c: float = plan.lane_x(plan.lane_of("loud"), plan.spawn_z)
	keep_out.append(Rect2(c - 9, plan.spawn_z - 9, 18, 18))
	F.rock(root, "rock_b", _on(plan, c - 7.0, plan.spawn_z - 3.0), 40.0, 1.6)
	F.rock(root, "rock_a", _on(plan, c + 6.5, plan.spawn_z + 2.0), 10.0, 1.3)
	B.cover_low(root, _on(plan, c + 3.5, s["z1"] + 6.0), dress.randf_range(-15, 15), dress)


## Open wilds with a two-grunt patrol looping from the road through the lane beside it.
static func _field(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var loud: int = plan.lane_of("loud")
	var z0: float = s["z0"] - 8.0
	var z1: float = s["z1"] + 8.0
	var side := _patrol_lane(plan, rng)
	var loop := [
		Vector2(plan.lane_x(loud, z0), z0), Vector2(_patrol_x(plan, side, z0), z0),
		Vector2(_patrol_x(plan, side, z1), z1), Vector2(plan.lane_x(loud, z1), z1),
	]
	_patrol(root, plan, info, loop, zone_index, 2 + int(zone_index >= 5))
	# Something to duck behind on the road.
	for k in 2:
		var z: float = lerpf(s["z0"], s["z1"], 0.3 + 0.4 * k)
		var x: float = plan.lane_x(loud, z) + (4.0 if k == 0 else -4.0)
		B.wild_cover(root, _on(plan, x, z), dress)
		keep_out.append(Rect2(x - 2, z - 2, 4, 4))


## A small post on the road; sometimes a lookout up on a ridge.
static func _picket(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var loud: int = plan.lane_of("loud")
	var z: float = s["mid"]
	var c: float = plan.lane_x(loud, z)
	keep_out.append(Rect2(c - 11, z - 6, 22, 12))
	if plan.biome == "boneyard":
		B.cover_tall(root, _on(plan, c + 2.0, z), 0.0, dress)
	else:
		F.fallen_log(root, _on(plan, c + 2.0, z), 4.0)
	B.cover_low(root, _on(plan, c - 6.5, z + 0.5), 0.0, dress)
	F.barrels(root, _on(plan, c + 7.5, z - 2.5), 20.0)
	F.floodlight(root, _on(plan, c - 9.0, z - 3.0), 20.0)
	var count := rng.randi_range(1, 2 + int(zone_index >= 4))
	for k in count:
		var gx: float = c + [2.5, -6.5, 6.0][k]
		_grunt(root, info, _on(plan, gx, z - 1.4), zone_index)
	var highs: Array = plan.lanes_of("high")
	if not highs.is_empty() and rng.randf() < 0.6:
		var h: int = highs[rng.randi() % highs.size()]
		var hx: float = plan.lane_x(h, z - 4.0)
		B.cover_low(root, _on(plan, hx, z - 2.8), 0.0, dress)
		_grunt(root, info, _on(plan, hx, z - 4.0), zone_index, 1.0)


## The militia's wall across the valley: a breach on the road, a gate beside
## it, a culvert under it in each gully, a catwalk over it on each ridge.
static func _wall(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var wz: float = s["wall_z"]
	var c: float = plan.center_x(wz)
	var hw: float = plan.half_width(wz)
	var loud: int = plan.lane_of("loud")
	var lx: float = plan.lane_x(loud, wz)
	# Openings across the wall, left to right: [x0, x1, kind, lane x].
	var openings := [[lx - 4.0, lx + 4.0, "breach", lx]]
	var gate_side := -1.0 if rng.randf() < 0.5 else 1.0
	var gx := lx + gate_side * 10.0
	if _lane_dist(plan, gx, wz) < 7.0:
		gate_side = -gate_side
		gx = lx + gate_side * 10.0
	openings.append([gx - 4.0, gx + 4.0, "gate", gx])
	for i in plan.lanes_of("quiet"):
		var qx: float = plan.lane_x(i, wz)
		openings.append([qx - 2.0, qx + 2.0, "culvert", qx])
	openings.sort_custom(func(a, b): return a[0] < b[0])
	var x := c - hw - 10.0
	for o in openings:
		_wall_run(root, plan, x, o[0], wz)
		match o[2]:
			"culvert":
				F.culvert(root, _on(plan, o[3], wz))
			"gate":
				F.gate(root, Vector3(o[3], minf(plan.ground(o[3] - 4.0, wz), plan.ground(o[3] + 4.0, wz)), wz))
			"breach":
				_breach(root, plan, o[3], wz)
		x = o[1]
	_wall_run(root, plan, x, c + hw + 10.0, wz)
	keep_out.append(Rect2(c - hw - 12.0, wz - 6.0, hw * 2.0 + 24.0, 12.0))
	info["structures"].append(Rect2(c - hw - 8.0, wz - 0.6, hw * 2.0 + 16.0, 1.2))
	# Catwalks on the ridges: a deck on the wall's top to land on.
	for i in plan.lanes_of("high"):
		var hx: float = plan.lane_x(i, wz)
		var top := _wall_y(plan, hx, wz) + WALL_H
		Kit.box(root, Vector3(hx, top + 0.15, wz), Vector3(6.0, 0.3, 4.4), CONCRETE, Vector3.ZERO, Art.material("gunmetal"))
		info["catwalks"].append(Vector3(hx, top + 0.3, wz))
		if rng.randf() < 0.5:
			_grunt(root, info, Vector3(hx + 1.5, top + 0.3, wz - 0.8), zone_index, 0.6)
	# Outside: sandbags at the breach. Inside: a watchtower with a lookout.
	B.cover_low(root, _on(plan, lx - 6.0, wz + 5.0), 10.0, dress)
	B.cover_low(root, _on(plan, lx + 6.5, wz + 6.0), -15.0, dress)
	var tx := lx - gate_side * 9.0
	if _lane_dist(plan, tx, wz - 7.0) < 5.0:
		tx = lx - gate_side * 6.0
	var deck := F.watchtower(root, _on(plan, tx, wz - 7.0))
	_grunt(root, info, deck + Vector3(0, 0, 0.6), zone_index, 0.6)
	_grunt(root, info, _on(plan, lx + 2.0, wz - 5.0), zone_index)
	F.floodlight(root, _on(plan, lx + gate_side * 4.5, wz - 2.5), 10.0)
	# Grass up to the culverts so you can get there unseen.
	for i in plan.lanes_of("quiet"):
		var qx: float = plan.lane_x(i, wz)
		B.hide(root, plan.ground, dress, info, qx - 3.5, wz + 5.0, Vector2(3.0, 5.0), true)
		B.hide(root, plan.ground, dress, info, qx + 3.5, wz - 5.0, Vector2(3.0, 5.0))


static func _wall_y(plan, x: float, wz: float) -> float:
	return minf(minf(plan.ground(x - 2.0, wz), plan.ground(x + 2.0, wz)), plan.ground(x, wz)) - 0.3


## Wall slabs from x0 to x1, with a cut-down slab to fill what's left.
static func _wall_run(root: Node3D, plan, x0: float, x1: float, wz: float) -> void:
	var x := x0
	while x1 - x >= 4.0:
		F.wall_slab(root, Vector3(x + 2.0, _wall_y(plan, x + 2.0, wz), wz))
		x += 4.0
	var rest := x1 - x
	if rest > 0.1:
		var mid := x + rest * 0.5
		var y := _wall_y(plan, mid, wz)
		Kit.box(root, Vector3(mid, y + WALL_H * 0.5, wz), Vector3(rest, WALL_H, 0.8), CONCRETE, Vector3.ZERO, Art.material("concrete"))


## A tree came down through the wall: rubble and the trunk to hop.
static func _breach(root: Node3D, plan, x: float, wz: float) -> void:
	F.fallen_log(root, _on(plan, x, wz + 0.5), 28.0)
	for spec in [[Vector3(-2.6, 0.5, 1.2), Vector3(2.4, 1.0, 1.6), Vector3(8, 25, 6)],
			[Vector3(2.8, 0.45, -1.4), Vector3(2.0, 0.9, 1.4), Vector3(-6, -30, 10)],
			[Vector3(-3.4, 1.4, -0.2), Vector3(1.0, 2.8, 0.8), Vector3(0, 0, 12)],
			[Vector3(3.5, 1.1, 0.0), Vector3(1.0, 2.2, 0.8), Vector3(0, 0, -9)]]:
		Kit.box(root, _on(plan, x, wz) + spec[0], spec[1], CONCRETE, spec[2], Art.material("concrete"))


## An outpost or a camp: a flat yard across the valley. The road runs through
## the squad's cover; the quiet lanes past tents and grass along the yard's
## side; the high lanes over a row of rooftops. Holds one salvage cache.
static func _yard(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var loud: int = plan.lane_of("loud")
	var z0: float = s["z0"]
	var z1: float = s["z1"]
	var mid: float = s["mid"]
	var c: float = plan.lane_x(loud, mid)
	var camp: bool = s["kind"] == "camp"
	# The rooftop runs first: they set where the high lanes go.
	var high_cache := Vector3.INF
	for i in plan.lanes_of("high"):
		var roof := _rooftops(root, plan, info, keep_out, i, s, dress)
		if high_cache == Vector3.INF:
			high_cache = roof
	# Which side of the road the big buildings go: away from the nearest quiet lane.
	var side := 1.0
	var q := -1
	for i in plan.lanes_of("quiet"):
		if q < 0 or absf(plan.lanes[i]["offset"]) < absf(plan.lanes[q]["offset"]):
			q = i  # the quiet lane nearest the road
	if q >= 0 and plan.lane_x(q, mid) > c:
		side = -1.0
	if camp:
		var at := Vector2(c + side * 12.0, mid + 2.0)
		var size := B.centrepiece(root, _on(plan, at.x, at.y))
		_occupy(info, keep_out, at, size)
	else:
		for k in 2:
			var at := Vector2(c + (side if k == 0 else -side) * 10.5, mid + (6.0 if k == 0 else -8.0))
			if _lane_dist(plan, at.x, at.y) < 7.5:
				continue
			var size := B.barracks(root, _on(plan, at.x, at.y), dress)
			_occupy(info, keep_out, at, size)
		F.antenna(root, _on(plan, c + side * 6.0, z0 - 6.0))
		keep_out.append(Rect2(c + side * 6.0 - 1.5, z0 - 7.5, 3, 3))
	# The landmark in the back corner, and a watchtower at the front.
	var lm := Vector2(c + side * 9.0, z1 + 7.0)
	if _free(keep_out, lm, Vector2(8, 8)) and _lane_dist(plan, lm.x, lm.y) > 6.0:
		_occupy(info, keep_out, lm, B.landmark(root, _on(plan, lm.x, lm.y)))
	var tw := Vector2(c - side * 7.5, z0 - 7.0)
	if _lane_dist(plan, tw.x, tw.y) < 5.0:
		tw.x = c - side * 5.0
	var deck := F.watchtower(root, _on(plan, tw.x, tw.y), 0.0)
	_occupy(info, keep_out, tw, Vector2(5, 5))
	_grunt(root, info, deck + Vector3(0, 0, 0.6), zone_index, 0.6)
	F.floodlight(root, _on(plan, c + side * 3.5, z0 - 3.0), 0.0)
	F.floodlight(root, _on(plan, c - side * 4.0, z1 + 4.0), 180.0)
	# The squad's cover across the road, facing the way the pilot comes in.
	var posts := [Vector2(c - 4.0, mid + 3.0), Vector2(c + 3.5, mid + 1.5), Vector2(c + 0.5, mid - 4.0), Vector2(c - 7.0, mid - 5.0)]
	var squad := []
	var size_n := rng.randi_range(2, 3) + mini(zone_index - 3, 1)
	for k in posts.size():
		var p: Vector2 = posts[k]
		if k == 2:
			B.cover_tall(root, _on(plan, p.x, p.y), dress.randf_range(-10, 10), dress)
		else:
			B.cover_low(root, _on(plan, p.x, p.y), dress.randf_range(-15, 15), dress)
		keep_out.append(Rect2(p.x - 1.5, p.y - 1.5, 3, 3))
		if k < size_n:
			squad.append(_grunt(root, info, _on(plan, p.x, p.y - (1.3 if k == 2 else 1.1)), zone_index))
	if s["cache"] == "guarded":
		L.guard(root, info, L.cache(root, info, _on(plan, c + 2.0, z1 + 6.0)), squad)
	elif high_cache != Vector3.INF:
		L.cache(root, info, high_cache)
	else:
		L.cache(root, info, _on(plan, c - side * 3.0, z1 + 5.0))
	# Quiet lanes: tents under netting and tall grass along the yard's edge.
	for i in plan.lanes_of("quiet"):
		var qz := mid
		var qx: float = plan.lane_x(i, qz)
		var out := signf(qx - c)
		F.camo_net(root, _on(plan, qx + out * 4.5, qz), 90.0)
		F.tent(root, _on(plan, qx + out * 4.5, qz + 3.0), 90.0)
		F.tent(root, _on(plan, qx + out * 4.5, qz - 3.0), 90.0)
		_occupy(info, keep_out, Vector2(qx + out * 4.5, qz), Vector2(4, 9))
		var z: float = z0 - 4.0
		while z > z1 + 3.0:
			B.hide(root, plan.ground, dress, info, plan.lane_x(i, z) - out * 2.6, z, Vector2(2.6, 6.0), true)
			z -= 9.0
		# Someone left on watch by the tents, looking into the yard.
		if rng.randf() < 0.5 + 0.1 * (zone_index - 3):
			_grunt(root, info, _on(plan, qx + out * 1.5, qz + 6.5), zone_index, 1.0, Vector3(-out, 0, 0))
	# A sentry walking the yard's front from the road to the quiet side and back.
	if q >= 0:
		var qx: float = plan.lane_x(q, mid)
		var inner := qx + signf(c - qx) * 4.0
		_patrol(root, plan, info, [Vector2(c - signf(c - qx) * 1.5, z0 - 3.0), Vector2(inner, z0 - 3.0), Vector2(inner, mid - 6.0)], zone_index, 1)
	# Clutter round the yard, off the lanes.
	var placed := 0
	for tries in 60:
		if placed >= 9:
			break
		var p := Vector2(c + dress.randf_range(-plan.half_width(mid), plan.half_width(mid)), dress.randf_range(z1 + 3.0, z0 - 3.0))
		if _lane_dist(plan, p.x, p.y) < 4.5 or not _free(keep_out, p, Vector2(3.4, 3.4)):
			continue
		B.yard_clutter(root, _on(plan, p.x, p.y), dress)
		keep_out.append(Rect2(p - Vector2(1.7, 1.7), Vector2(3.4, 3.4)))
		placed += 1


## A row of rooftops along a high lane through a yard, from the ridge's end to
## where it starts again. Returns the middle roof's top (for a cache).
static func _rooftops(root: Node3D, plan, info: Dictionary, keep_out: Array, lane: int, s: Dictionary, dress: RandomNumberGenerator) -> Vector3:
	var span: float = s["z0"] - s["z1"]
	# Fit as many as leave gaps of about ROOF_GAP, ends included.
	var length := 8.2
	match plan.biome:
		"marsh":
			length = 6.1
		"boneyard":
			length = 6.0
	var n := roundi((span - ROOF_GAP) / (length + ROOF_GAP))
	var gap := (span - n * length) / (n + 1)
	var roofs := []
	var z: float = s["z0"] - gap - length * 0.5
	for k in n:
		var x: float = plan.lane_x(lane, z)
		var r := B.perch(root, _on(plan, x, z), dress)
		roofs.append(r["roof"])
		_occupy(info, keep_out, Vector2(x, z), Vector2(r["width"] + 1.0, length))
		z -= length + gap
	info["perches"][lane] = {"roofs": roofs, "length": length, "gap": gap}
	return roofs[int(roofs.size() / 2.0)]


## A titan wreck between two lanes with alloy to mine, and two grunts picking
## it over with their backs to the road.
static func _resource(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var loud: int = plan.lane_of("loud")
	var z: float = s["mid"]
	var pairs := []
	for i in plan.lanes.size() - 1:
		pairs.append(i)
	var i0: int = pairs[rng.randi() % pairs.size()]
	var x: float = (plan.lane_x(i0, z) + plan.lane_x(i0 + 1, z)) * 0.5
	var size := B.wreck(root, _on(plan, x, z), dress)
	_occupy(info, keep_out, Vector2(x, z), size * Vector2(0.8, 0.8))
	for k in 3:
		var a := TAU * (k / 3.0) + rng.randf() * 0.5
		var p := Vector2(x + cos(a) * (size.x * 0.5 + 2.5), z + sin(a) * minf(size.y * 0.5 + 1.0, 9.0))
		info["loot_spots"]["node"].append(_on(plan, p.x, p.y))
	info["loot_spots"]["crate"].append(_on(plan, x + size.x * 0.5 + 3.0, z + 5.0))
	for k in 2:
		var gp := Vector2(x + (-1.0 if k == 0 else 1.0) * (size.x * 0.5 + 1.6), z + (3.0 if k == 0 else -4.0))
		_grunt(root, info, _on(plan, gp.x, gp.y), zone_index, 1.5, Vector3(signf(x - gp.x), 0, -0.5).normalized())
	# Grass round it to creep up through.
	for k in 3:
		B.hide(root, plan.ground, dress, info, x + dress.randf_range(-9, 9), z + 12.0 - k * 4.0 + dress.randf_range(-1, 1), Vector2(3.5, 3.5), k == 1)
	B.cover_low(root, _on(plan, plan.lane_x(loud, z) + 3.0, z + 6.0), 0.0, dress)


## A chasm across the valley. The road: the blown bridge with a shield to
## wallrun and a crane to grapple (the Pinewoods' ravine, which the run loop
## test flies). The quiet lanes: something fallen across to walk. The ridges:
## rock pillars to hop at ridge height.
static func _chasm(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary, rng: RandomNumberGenerator,
		dress: RandomNumberGenerator, zone_index: int) -> void:
	var near: float = s["near_lip"]
	var far: float = s["far_lip"]
	var y: float = s["level"]
	var mid := (near + far) * 0.5
	var hw: float = plan.half_width(mid)
	B.chasm_floor(root, Vector3(plan.center_x(mid), y - LevelPlan.CHASM_DEPTH + 0.9, mid), Vector2(hw * 2.0 + 160.0, LevelPlan.CHASM_GAP + 4.0))
	keep_out.append(Rect2(plan.center_x(mid) - hw - 20.0, far - 1.5, hw * 2.0 + 40.0, near - far + 3.0))
	var crossing := {"near_lip": near, "far_lip": far, "level": y, "lanes": []}
	info["crossings"].append(crossing)
	for i in plan.lanes.size():
		var x: float = plan.lane_x(i, mid)
		match plan.lanes[i]["kind"]:
			"loud":
				_bridge(root, plan, info, keep_out, x, near, far, y, rng, crossing)
			"quiet":
				B.quiet_crossing(root, x, y, mid)
				keep_out.append(Rect2(x - 2.5, far - 6.0, 5.0, near - far + 12.0))
				crossing["lanes"].append({"lane": i, "kind": "walk", "x": x})
				B.hide(root, plan.ground, dress, info, x - 3.2, near + 5.0, Vector2(3.0, 5.0), true)
				B.hide(root, plan.ground, dress, info, x + 3.4, far - 5.0, Vector2(3.0, 6.0), true)
			"high":
				var top: float = y + LevelPlan.RIDGE_H
				var last_edge := near
				var last_top := top
				var pillars := []
				for p in PILLARS:
					var front: float = near - p[0]
					var back := front - PILLAR
					var ptop: float = top - p[1]
					var h := ptop - (y - LevelPlan.CHASM_DEPTH) + 1.0
					Kit.box(root, Vector3(x, ptop - h * 0.5, (front + back) * 0.5), Vector3(PILLAR, h, PILLAR), CONCRETE, Vector3.ZERO, F.HubProps.material("rock"))
					F.spawn(root, "rock_c", Vector3(x + PILLAR * 0.5 - 0.6, ptop, back + 0.5), rng.randf_range(0, 360), 0.8)
					info["segments"].append({"type": "jump", "gap": last_edge - front, "rise": ptop - last_top})
					pillars.append(Vector3(x, ptop, (front + back) * 0.5))
					last_edge = back
					last_top = ptop
				info["segments"].append({"type": "jump", "gap": last_edge - far, "rise": top - last_top})
				crossing["lanes"].append({"lane": i, "kind": "pillars", "x": x, "pillars": pillars})
	# A picket on the far lip watching the bridge.
	var c: float = plan.lane_x(plan.lane_of("loud"), far)
	for k in 2:
		var px := c + (-9.0 if k == 0 else 10.0)
		if _lane_dist(plan, px, far - 8.0) < 4.0:
			px = c + (-7.0 if k == 0 else 7.0)
		B.cover_low(root, _on(plan, px, far - 8.0), rng.randf_range(-10, 10), dress)
		if k == 0 or rng.randf() < 0.4 + 0.15 * (zone_index - 3):
			_grunt(root, info, _on(plan, px, far - 9.1), zone_index)
	F.floodlight(root, _on(plan, c + 6.0, far - 14.0), 180.0)


## The blown bridge at x: decks out from both lips, the blast shield on one
## side and the crane's grapple anchor on the other.
static func _bridge(root: Node3D, plan, info: Dictionary, keep_out: Array, x: float, near: float, far: float, y: float,
		rng: RandomNumberGenerator, crossing: Dictionary) -> void:
	var near_end := near - LevelPlan.BRIDGE_REACH
	var far_end := far + LevelPlan.BRIDGE_REACH
	var gap := near_end - far_end
	var mid := (near_end + far_end) * 0.5
	F.bridge_stub(root, Vector3(x, y, near_end + 5.0), 0.0)
	F.bridge_stub(root, Vector3(x, y, far_end - 5.0), 180.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var shield := Kit.box(root, Vector3(x + side * SHIELD_X, y, mid), Vector3(1, 12, gap), BLUE)
	Kit.box(root, Vector3(x + side * SHIELD_X, y + 6.4, mid), Vector3(0.7, 0.8, near - far + 4.0), CONCRETE, Vector3.ZERO, Art.material("gunmetal"))
	info["segments"].append({"type": "wallrun", "gap": gap, "rise": 0.0})
	var anchor_z := near_end - gap * 0.6
	F.pylon(root, Vector3(x - side * ANCHOR_X, y, anchor_z - 9.0), 0.0)
	var anchor := Kit.box(root, Vector3(x - side * ANCHOR_X, y + ANCHOR_Y, anchor_z), Vector3(3, 2, 3), ORANGE)
	info["segments"].append({"type": "grapple", "gap": gap, "rise": 0.0})
	keep_out.append(Rect2(x - 9.0, far - 12.0, 18.0, near - far + 24.0))
	crossing["lanes"].append({"lane": plan.lane_of("loud"), "kind": "bridge", "x": x, "shield_x": x + side * SHIELD_X,
			"anchor": anchor.position, "near_end": near_end, "far_end": far_end, "shield": shield})


static func _end(root: Node3D, plan, info: Dictionary, keep_out: Array, s: Dictionary) -> void:
	var x: float = plan.lane_x(plan.lane_of("loud"), plan.end_z)
	L.beacon(root, info, _on(plan, x, plan.end_z), "EXTRACT")
	keep_out.append(Rect2(x - 12, plan.end_z - 12, 24, 24))
	F.spawn(root, "rock_b", _on(plan, x - 6.0, plan.end_z - 4.0), 40.0, 1.8)
	F.spawn(root, "rock_a", _on(plan, x + 7.0, plan.end_z + 2.0), 10.0, 1.5)


# --- along the lanes -------------------------------------------------------------

## Grass down the gullies' banks, rocks along the ridges' rims, and steps up
## onto each ridge from the lane beside it.
static func _lanes(root: Node3D, plan, info: Dictionary, keep_out: Array, dress: RandomNumberGenerator) -> void:
	var loud: int = plan.lane_of("loud")
	for i in plan.lanes.size():
		var kind: String = plan.lanes[i]["kind"]
		if kind == "quiet":
			var z: float = plan.spawn_z - 10.0
			var k := 0
			while z > plan.end_z + 10.0:
				if plan.gully_on(z) > 0.9 and plan.clearing(plan.lane_x(i, z), z) < 0.1 and plan.in_chasm(z).is_empty():
					var x: float = plan.lane_x(i, z)
					for side in [-1.0, 1.0]:
						if (k + int(side > 0)) % 2 == 0:
							B.hide(root, plan.ground, dress, info, x + side * 4.2, z - dress.randf_range(0, 3), Vector2(3.0, 7.0), true)
						else:
							B.hide(root, plan.ground, dress, info, x + side * 3.6, z - dress.randf_range(0, 3), Vector2(2.4, 5.0))
					# The bed itself: crouch in it and you're under the banks.
					F.stealth_cover(root, _on(plan, x, z, 0.8), Vector3(5.0, 2.0, 8.5))
					if dress.randf() < 0.5:
						F.spawn(root, "rock_c", _on(plan, x + dress.randf_range(-1.6, 1.6), z), dress.randf_range(0, 360), dress.randf_range(0.5, 0.9))
				z -= 8.0
				k += 1
		elif kind == "high":
			var z: float = plan.spawn_z - 12.0
			while z > plan.end_z + 14.0:
				if plan.ridge_on(z) > 0.95:
					var x: float = plan.lane_x(i, z)
					for side in [-1.0, 1.0]:
						if dress.randf() < 0.45:
							F.rock(root, ["rock_a", "rock_b", "rock_c"][dress.randi() % 3], _on(plan, x + side * 2.8, z + dress.randf_range(-2, 2)),
									dress.randf_range(0, 360), dress.randf_range(0.7, 1.1), false)
					if dress.randf() < 0.18:
						B.hide(root, plan.ground, dress, info, x + dress.randf_range(-1.0, 1.0), z, Vector2(2.4, 3.5))
				z -= 7.0
			# Steps up from the road's side at the start of each cliff-ended stretch.
			var toward := signf(plan.lane_x(loud, 0.0) - plan.lane_x(i, 0.0))
			for span in plan.ridge_spans():
				if span[2] > 0.0:
					continue
				var sz: float = span[0] - 5.0
				if sz - span[1] < 10.0:
					continue
				# A crate stack at the cliff's foot and a lower one beside it: 1.2 m, 2.4 m, then the top.
				var edge: float = LevelPlan.RIDGE_TOP + LevelPlan.RIDGE_SIDE
				var x: float = plan.lane_x(i, sz) + toward * (edge + 0.9)
				var x2: float = x + toward * 1.8
				var base := minf(plan.ground(x - 0.9, sz), plan.ground(x + 0.9, sz))
				var base2 := minf(plan.ground(x2 - 0.9, sz), plan.ground(x2 + 0.9, sz))
				Kit.box(root, Vector3(x, base + 1.2 - 0.3, sz), Vector3(1.8, 3.0, 1.8), GREEN)
				Kit.box(root, Vector3(x2, base2 + 0.6 - 0.3, sz), Vector3(1.8, 1.8, 1.8), GREEN)
				keep_out.append(Rect2(x - 3.0, sz - 2.0, 6.0, 4.0))


## Trees, cover and hiding grass between the lanes, and undergrowth.
static func _wilds(root: Node3D, plan, info: Dictionary, keep_out: Array, dress: RandomNumberGenerator) -> void:
	var density := B.tree_density(plan.biome)
	var spawn := Vector2(plan.lane_x(plan.lane_of("loud"), plan.spawn_z), plan.spawn_z)
	var bare := func(x: float, z: float) -> bool:
		if Vector2(x, z).distance_to(spawn) < 12.0:
			return true
		if not plan.in_chasm(z).is_empty() or not plan.in_chasm(z + 1.5).is_empty() or not plan.in_chasm(z - 1.5).is_empty():
			return true
		for i in plan.lanes.size():
			var d := absf(x - plan.lane_x(i, z))
			if d < (6.5 if plan.lanes[i]["kind"] == "high" else 5.0):
				return true
		if plan.clearing(x, z) > 0.5:
			return true
		for r in keep_out:
			if (r as Rect2).has_point(Vector2(x, z)):
				return true
		return false
	var z: float = plan.z_top - 4.0
	while z > plan.z_bottom + 4.0:
		var w: float = plan.half_width(z) + 3.0
		var x: float = plan.center_x(z) - w
		while x < plan.center_x(z) + w:
			var p := Vector2(x + dress.randf_range(-1.8, 1.8), z + dress.randf_range(-1.8, 1.8))
			if dress.randf() < density and not bare.call(p.x, p.y):
				B.tree(root, _on(plan, p.x, p.y, -0.2), dress, dress.randf_range(0.9, 1.45))
			x += 4.6
		z -= 4.6
	var placed := 0
	for tries in 600:
		if placed >= 18 + plan.lanes.size() * 3:
			break
		var pz := dress.randf_range(plan.z_bottom + 6.0, plan.z_top - 6.0)
		var px: float = plan.center_x(pz) + dress.randf_range(-plan.half_width(pz), plan.half_width(pz))
		if bare.call(px, pz):
			continue
		B.wild_cover(root, _on(plan, px, pz), dress)
		placed += 1
	placed = 0
	for tries in 800:
		if placed >= 14 + plan.lanes.size() * 4:
			break
		var pz := dress.randf_range(plan.z_bottom + 6.0, plan.z_top - 6.0)
		var px: float = plan.center_x(pz) + dress.randf_range(-plan.half_width(pz), plan.half_width(pz))
		if bare.call(px, pz):
			continue
		B.hide(root, plan.ground, dress, info, px, pz, Vector2(dress.randf_range(3.0, 5.0), dress.randf_range(3.0, 6.0)), dress.randf() < 0.3, dress.randf_range(0, 180))
		placed += 1
	var grass := []
	for tries in 40000:
		if grass.size() >= 7000:
			break
		var pz := dress.randf_range(plan.z_bottom + 2.0, plan.z_top - 2.0)
		var px: float = plan.center_x(pz) + dress.randf_range(-plan.half_width(pz) - 4.0, plan.half_width(pz) + 4.0)
		if not plan.in_chasm(pz).is_empty() or absf(px - plan.lane_x(plan.lane_of("loud"), pz)) < 2.2:
			continue
		var y: float = plan.ground(px, pz)
		if plan.biome == "marsh" and y < B.WATER_Y - 0.1:
			continue
		var basis := Basis(Vector3.UP, dress.randf_range(0, TAU)).scaled(Vector3.ONE * dress.randf_range(0.8, 1.6))
		grass.append(Transform3D(basis, Vector3(px, y - 0.05, pz)))
	B.finish_grass(root, info, grass)


## Places beside every lane for supply crates (loot.gd tries these first):
## on the gullies' banks, the ridges' tops and the road's verges, never over a
## chasm or inside a building.
static func _crate_spots(plan, info: Dictionary, keep_out: Array, dress: RandomNumberGenerator) -> void:
	var spots := []
	for i in plan.lanes.size():
		var kind: String = plan.lanes[i]["kind"]
		var z: float = plan.spawn_z - 16.0 - dress.randf_range(0.0, 8.0)
		while z > plan.end_z + 8.0:
			var near_gap: bool = not plan.in_chasm(z).is_empty() or not plan.in_chasm(z + 5.0).is_empty() or not plan.in_chasm(z - 5.0).is_empty()
			var side := -1.0 if dress.randf() < 0.5 else 1.0
			var x: float = plan.lane_x(i, z)
			match kind:
				"quiet":
					x += side * (LevelPlan.GULLY_BED + LevelPlan.GULLY_BANK + 1.0)
				"high":
					x += side * 1.4
					if plan.ridge_on(z) < 0.95:
						near_gap = true
				_:
					x += side * dress.randf_range(3.0, 4.5)
			if not near_gap and _free(keep_out, Vector2(x, z), Vector2(1.6, 1.6)):
				spots.append(_on(plan, x, z, 0.2))
			z -= dress.randf_range(11.0, 16.0)
	for k in range(spots.size() - 1, 0, -1):
		var j := dress.randi_range(0, k)
		var t = spots[k]
		spots[k] = spots[j]
		spots[j] = t
	info["loot_spots"]["crate"].append_array(spots)


# --- routes and checkpoints -------------------------------------------------------

## Each lane as a route of points ({name, kind, points}), the way loot.gd,
## the map and the tests read the handmade zones' routes. High lanes run over
## the rooftops and catwalks; every route ends at the beacon.
static func _routes(plan, info: Dictionary) -> void:
	var beacon: Vector3 = info["beacon"].position
	var routes := []
	for i in plan.lanes.size():
		var kind: String = plan.lanes[i]["kind"]
		var pts := PackedVector3Array()
		var z: float = plan.spawn_z
		while z > plan.end_z + 6.0:
			var x: float = plan.lane_x(i, z)
			var y: float = plan.ground(x, z) + 0.3
			var chasm: Dictionary = plan.in_chasm(z)
			if not chasm.is_empty():
				y = chasm["level"] + 0.3 + (LevelPlan.RIDGE_H if kind == "high" else 0.0)
			elif kind == "high":
				var roof := _roof_at(info, i, z)
				if roof != INF:
					y = roof + 0.3
				for cw in info["catwalks"]:
					if absf(cw.x - x) < 4.0 and absf(cw.z - z) < 2.5:
						y = cw.y + 0.3
			pts.append(Vector3(x, y, z))
			z -= 4.0
		pts.append(beacon + Vector3(0, 0.3, 0))
		routes.append({"name": plan.lanes[i]["name"], "kind": kind, "points": pts, "lane": i})
	info["routes"] = routes


## The roof height over z on a high lane's rooftop run, or INF.
static func _roof_at(info: Dictionary, lane: int, z: float) -> float:
	if not info["perches"].has(lane):
		return INF
	var p: Dictionary = info["perches"][lane]
	for roof in p["roofs"]:
		if absf(roof.z - z) <= p["length"] * 0.5 + p["gap"] * 0.5:
			return roof.y
	return INF


## On the road at each section's start, and on every lane past each wall and chasm.
static func _checkpoints(plan, info: Dictionary) -> void:
	var loud: int = plan.lane_of("loud")
	for s in plan.sections:
		var z: float = s["z0"] - 4.0 if s["kind"] != "start" else plan.spawn_z
		if not plan.in_chasm(z).is_empty():
			z = s["near_lip"] + 6.0
		info["checkpoints"].append(_on(plan, plan.lane_x(loud, z), z, 0.1))
		var after := INF
		if s["kind"] == "chasm":
			after = s["far_lip"] - 6.0
		elif s["kind"] == "wall":
			after = s["wall_z"] - 6.0
		if after == INF:
			continue
		for i in plan.lanes.size():
			if i != loud:
				info["checkpoints"].append(_on(plan, plan.lane_x(i, after), after, 0.1))
