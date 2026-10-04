extends RefCounted
## Zone 1, the Pinewoods, and the end-of-run arena at the forest's edge.
##
## Zone 1 is a laid-out level rather than a platform chain: a valley of pines
## heading north (-Z) with three ways through most of it.
##   The trail (loud): straight up the middle, past the picket, through the
##     breach in the wall, across the outpost yard, over the blown bridge, into
##     the logging camp's yard.
##   The creek (quiet): a dry gully down the left with tall grass on its banks,
##     a drainage culvert under the wall behind the watchtower's back, the
##     outpost's tent row, a giant fallen pine across the ravine out of the far
##     picket's view, and the woods along the camp's left past a hunter's blind.
##   The ridge (high): a rocky shelf up the right that meets the top of the
##     wall, hut roofs, the crane over the ravine, log piles up to the sawmill roof.
## Sections, in order: a picket behind a fallen log; the enemy's wall (gate,
## watchtower, a breach a falling pine made, the culvert); the outpost; the
## ravine with the bridge blown (wallrun the hanging blast shield, grapple the
## crane, hop the rock pillars, or walk the fallen pine); the logging camp on
## the rise; the extraction beacon in a clearing.
## One salvage cache is guarded (the outpost's or the camp's squad holds it,
## picked by the run seed) and the other is up a climb: a hut roof or the
## sawmill roof. Squad sizes and the picket vary with the seed too.
## Tall grass marks where you can hide (Area3D in group "stealth_cover"), and
## the densest of it blocks grunts' sight (forest_kit.gd SIGHT_LAYER).
##
## The forest's edge is the titan arena: you step out of the treeline onto a
## meadow where the enemy was building a forward base, call in your titan, and
## fight theirs. Then the evac dropship comes in over the pad past it.

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const F := preload("res://scripts/run/forest_kit.gd")
const Terrain := preload("res://scripts/run/terrain.gd")
const SalvageCache := preload("res://scripts/run/salvage_cache.gd")
const SquadObjective := preload("res://scripts/run/squad_objective.gd")
const GruntScript := preload("res://scripts/grunt.gd")
const ExtractBeacon := preload("res://scripts/run/extract_beacon.gd")
const Boss := preload("res://scripts/run/boss.gd")
const Ambience := preload("res://scripts/ambience.gd")

const NAME := "THE PINEWOODS"
const CELL := 2.0
const GRID_X := Vector2(-140.0, 140.0)
const GRID_Z := Vector2(-300.0, 70.0)

const WALL_Z := -60.0
const OUTPOST_Z := -88.0
## The ravine runs across the whole valley between these lips (both on grid lines).
const NEAR_LIP := -124.0
const FAR_LIP := -144.0
const RAVINE_FLOOR := -16.0
const RAVINE_Z := (NEAR_LIP + FAR_LIP) * 0.5
## The broken bridge decks reach 2 m out over the ravine from each lip.
const BRIDGE_REACH := 2.0
## Rock pillars across the ravine, right of the bridge: [front edge z, top y], PILLAR m square.
const PILLAR_X := 16.0
const PILLAR := 5.0
const PILLARS := [[-127.3, -0.4], [-135.7, -0.2]]
## The blast shield to wallrun hangs this far left of the bridge; the grapple
## anchor hangs this far right of it, ANCHOR_Y up.
const SHIELD_X := -4.5
const ANCHOR_X := 4.5
const ANCHOR_Y := 11.0
## The fallen pine across the ravine lies this far left of the bridge.
const LOG_X := -26.0
const CAMP_Z := -190.0
const CAMP_Y := 4.0
const END_Z := -248.0
## Below this you fell into the ravine.
const KILL_Y := -8.0
## The dry creek: from CREEK_START down to the culvert under the wall and a
## little past it, CREEK_DEPTH deep.
const CREEK_START := 16.0
const CREEK_END := -70.0
const CREEK_DEPTH := 1.8
## The wall slab the culvert replaces sits this far left of the trail.
const CULVERT_X := -14.0
## The ridge shelf: this far right of the trail, RIDGE_H high, until RIDGE_END
## (just short of the wall, whose top is about 2 m above it).
const RIDGE_X := 24.0
const RIDGE_H := 4.0
const RIDGE_END := -58.0
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const GREEN := Color(0.3, 0.75, 0.4)
const CONCRETE := Color(0.55, 0.56, 0.55)


# --- the valley's shape --------------------------------------------------------

## The trail's x at depth z: a lazy meander.
static func trail_x(z: float) -> float:
	return 7.0 * sin((z + 30.0) / 38.0)


## The dry creek's x: wanders down the left and reaches the culvert at the wall.
static func creek_x(z: float) -> float:
	return trail_x(z) + CULVERT_X - 3.0 * sin((z - WALL_Z) / 13.0)


## The ridge shelf's centre line.
static func ridge_x(z: float) -> float:
	return trail_x(z) + RIDGE_X


## 1 inside [lo, hi] (z, with hi > lo), ramping to 0 over `ramp` metres outside.
static func _plateau(z: float, lo: float, hi: float, ramp: float) -> float:
	if z > hi:
		return clampf(1.0 - (z - hi) / ramp, 0.0, 1.0)
	if z < lo:
		return clampf(1.0 - (lo - z) / ramp, 0.0, 1.0)
	return 1.0


## Half the width of the walkable valley floor at depth z.
static func half_width(z: float) -> float:
	var w := 30.0
	w += 6.0 * maxf(maxf(_plateau(z, -112.0, -62.0, 10.0), _plateau(z, -216.0, -160.0, 10.0)), _plateau(z, -156.0, -112.0, 6.0))
	return w


## The valley floor's height along the trail, before bumps.
static func base_height(z: float) -> float:
	if z >= -150.0:
		return 0.0
	if z >= -170.0:
		return CAMP_Y * smoothstep(-150.0, -170.0, z)
	if z >= -214.0:
		return CAMP_Y
	return CAMP_Y + 2.5 * smoothstep(-214.0, -240.0, z)


static func _bumps(x: float, z: float) -> float:
	return 0.7 * sin(x * 0.19 + z * 0.11) * sin(z * 0.23 - x * 0.08) + 0.35 * sin(x * 0.47 + 1.3) * sin(z * 0.41 + 0.7)


## How deep the creek cuts at (x, z): a flat 5 m bed with walkable banks.
static func creek_depth(x: float, z: float) -> float:
	if z > CREEK_START or z < CREEK_END:
		return 0.0
	var fade := clampf((CREEK_START - z) / 6.0, 0.0, 1.0) * clampf((z - CREEK_END) / 6.0, 0.0, 1.0)
	return CREEK_DEPTH * fade * clampf((5.0 - absf(x - creek_x(z))) / 2.5, 0.0, 1.0)


## How high the ridge shelf lifts (x, z): ramps up from the clearing, a 6 m
## wide top, rocky sides.
static func ridge_height(x: float, z: float) -> float:
	if z < RIDGE_END:
		return 0.0
	var along := clampf((18.0 - z) / 12.0, 0.0, 1.0)
	return RIDGE_H * along * clampf((4.5 - absf(x - ridge_x(z))) / 1.5, 0.0, 1.0)


## Ground height anywhere in the zone.
static func ground(x: float, z: float) -> float:
	if z < NEAR_LIP and z > FAR_LIP:
		return RAVINE_FLOOR + 0.8 * sin(x * 0.3) * sin(z * 0.7)
	var d := absf(x - trail_x(z))
	var w := half_width(z)
	var h := base_height(z)
	# Rolling forest floor, except where the enemy levelled it, and calmer on the trail.
	var rough := 1.0 - maxf(maxf(_plateau(z, -114.0, -52.0, 6.0), _plateau(z, -218.0, -112.0, 6.0)), 0.0)
	rough = maxf(rough, clampf((d - w) / 8.0, 0.0, 1.0))
	h += _bumps(x, z) * rough * (0.35 if d < 6.0 else 1.0)
	h += ridge_height(x, z) - creek_depth(x, z)
	# Hills close the valley in on both sides.
	if d > w:
		var o := d - w
		h += minf(o * 0.5 + o * o * 0.015, 16.0) + (0.5 + 0.5 * sin(z * 0.05 + x * 0.03)) * minf(o / 12.0, 1.0) * 4.0
	return h


static func _on(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, ground(x, z) + up, z)


# --- zone 1 --------------------------------------------------------------------

## Returns the same dictionary shape as ZoneBuilder.build_zone, plus
## checkpoints (Vector3s), kill_y, name, segments describing the ravine's jump,
## wallrun and grapple crossings ({type, gap, rise}) so tests can hold them to
## the movement limits, routes ({name, kind: loud/quiet/high, points}) and
## stealth_cover (the hiding areas).
static func build_zone(root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	Kit.environment(root, Color(0.3, 0.46, 0.6), Color(0.78, 0.82, 0.7))
	Ambience.start(root, {"forest_day": -10.0, "forest_wind": -17.0, "forest_birds": -19.0})
	var info := {
		"name": NAME,
		"spawn": _on(trail_x(4.0), 4.0, 0.1), "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": RAVINE_FLOOR,
		"kill_y": KILL_Y, "grunts": [], "checkpoints": [], "routes": [],
		"stealth_cover": [], "grass": [], "tall_grass": [],
	}
	var guard_outpost := rng.randf() < 0.5
	var dress := RandomNumberGenerator.new()
	dress.seed = rng.randi()

	_terrain(root)
	_fences(root)
	_trail(root)
	var keep_out: Array = []
	_creek(root, dress, info)
	_ridge(root, dress, info)
	_picket(root, rng, info, keep_out)
	_wall(root, info, keep_out)
	_outpost(root, rng, dress, info, keep_out, guard_outpost)
	_ravine(root, rng, dress, info, keep_out)
	_camp(root, rng, dress, info, keep_out, not guard_outpost)
	_end(root, info, keep_out)
	_forest(root, dress, info, keep_out)
	_routes(info)
	for area in root.get_children():
		if area is Area3D and area.is_in_group("stealth_cover"):
			info["stealth_cover"].append(area)
	# The first alloy node and supply crate sit in the clearing at the start, in
	# plain view, so the tutorial (tutorial.gd) can point them out before any grunt is near.
	info["first_loot"] = {"node": _on(trail_x(-4.0) - 4.0, -4.0), "crate": _on(trail_x(-1.0) + 4.5, -1.0)}

	for z in [4.0, -46.0, OUTPOST_Z, NEAR_LIP + 10.0, FAR_LIP - 12.0, -182.0, -232.0]:
		info["checkpoints"].append(_on(trail_x(z), z, 0.1))
	var c1 := trail_x(OUTPOST_Z)
	var cr := trail_x(RAVINE_Z)
	var c2 := trail_x(CAMP_Z)
	for p in [Vector2(creek_x(-30.0), -30.0), Vector2(ridge_x(-30.0), -30.0), Vector2(c1 - 25.0, -102.0),
			Vector2(cr + LOG_X, NEAR_LIP + 8.0), Vector2(cr + LOG_X, FAR_LIP - 8.0), Vector2(c2 - 24.0, -188.0)]:
		info["checkpoints"].append(_on(p.x, p.y, 0.1))
	return info


static func _terrain(root: Node3D) -> void:
	var nx := int((GRID_X.y - GRID_X.x) / CELL) + 1
	var nz := int((GRID_Z.y - GRID_Z.x) / CELL) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		var z := GRID_Z.x + iz * CELL
		for ix in nx:
			heights[iz * nx + ix] = ground(GRID_X.x + ix * CELL, z)
	Terrain.build(root, heights, nx, nz, GRID_X.x, GRID_Z.x, CELL, Color(0.58, 0.72, 0.48), Color(0.8, 0.8, 0.74))
	# A river at the bottom of the ravine.
	var water := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(GRID_X.y - GRID_X.x, 0.1, FAR_LIP - NEAR_LIP + 30.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.42, 0.45)
	mat.roughness = 0.15
	mat.metallic_specular = 0.8
	plane.material = mat
	water.mesh = plane
	water.position = Vector3(0, RAVINE_FLOOR + 0.9, RAVINE_Z)
	root.add_child(water)


## Invisible walls just up the hillsides, and across both ends of the valley.
static func _fences(root: Node3D) -> void:
	var z := 60.0
	while z > -290.0:
		var z2 := z - 10.0
		for side in [-1.0, 1.0]:
			var a := Vector3(trail_x(z) + side * (half_width(z) + 6.0), 0, z)
			var b := Vector3(trail_x(z2) + side * (half_width(z2) + 6.0), 0, z2)
			var mid := (a + b) * 0.5
			var yaw := rad_to_deg(atan2(b.x - a.x, b.z - a.z))
			F.solid(root, mid + Vector3(0, 20, 0), Vector3(1, 80, a.distance_to(b) + 1.5), yaw)
		z = z2
	F.solid(root, Vector3(trail_x(26.0), 20, 26), Vector3(140, 80, 1))
	F.solid(root, Vector3(trail_x(-262.0), 20, -262), Vector3(140, 80, 1))


## A dirt trail following the meander: you always know which way is forward.
static func _trail(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 1.8
	var z := 20.0
	while z > END_Z - 6.0:
		var z2 := z - 2.0
		var skip := (z <= NEAR_LIP + 8.0 and z2 >= FAR_LIP - 8.0) or absf(z - WALL_Z) < 1.5
		if not skip:
			var quad := []
			for zz in [z, z2]:
				var x := trail_x(zz)
				var wob := 0.4 * sin(zz * 0.3)
				for s in [-1.0, 1.0]:
					var px: float = x + s * (half + wob * s)
					quad.append(Vector3(px, ground(px, zz) + 0.06, zz))
			# quad: z left, z right, z2 left, z2 right
			for i in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(quad[i])
		z = z2
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Art.material("dirt")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A grunt standing at `pos` looking toward `facing`, holding within `leash`.
static func _grunt(root: Node3D, info: Dictionary, pos: Vector3, facing: Vector3, leash := 2.5) -> Node:
	var g := CharacterBody3D.new()
	g.set_script(GruntScript)
	g.leash = leash
	g.sight_range = 35.0
	g.damage = 8.0
	root.add_child(g)
	g.position = pos + Vector3(0, 0.1, 0)
	g.post = g.position
	g.rotation.y = atan2(-facing.x, -facing.z)
	info["grunts"].append(g)
	return g


static func _cache(root: Node3D, info: Dictionary, pos: Vector3) -> Node3D:
	var cache := SalvageCache.new()
	root.add_child(cache)
	cache.position = pos
	info["caches"].append(cache)
	return cache


static func _guard(root: Node3D, info: Dictionary, cache: Node3D, squad: Array) -> void:
	cache.set_locked(true)
	var objective := SquadObjective.new()
	root.add_child(objective)
	objective.position = cache.position
	objective.cache = cache
	objective.set_squad(squad)
	info["objectives"].append(objective)


## Tall grass you can hide in at (x, z), `size` across; dense patches block sight too.
static func _hide(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, x: float, z: float, size: Vector2, dense := false, yaw := 0.0) -> void:
	info["tall_grass"].append_array(F.grass_patch(root, ground, Vector2(x, z), size, rng, dense, yaw))


# --- the flanks ----------------------------------------------------------------

## The dry creek: stones in the bed, tall grass and ferns crowding both banks.
static func _creek(root: Node3D, rng: RandomNumberGenerator, info: Dictionary) -> void:
	var z := CREEK_START - 6.0
	var i := 0
	while z > WALL_Z + 4.0:
		var x := creek_x(z)
		for side in [-1.0, 1.0]:
			if (i + int(side > 0)) % 2 == 0:
				_hide(root, rng, info, x + side * 4.2, z - rng.randf_range(0, 3), Vector2(3.0, 7.0), true)
			else:
				_hide(root, rng, info, x + side * 3.6, z - rng.randf_range(0, 3), Vector2(2.4, 5.0))
		# The bed itself: crouch here and you're under the banks.
		F.stealth_cover(root, _on(x, z, 0.8), Vector3(5.0, 2.0, 8.5))
		if rng.randf() < 0.7:
			F.spawn(root, "rock_c", _on(x + rng.randf_range(-1.8, 1.8), z), rng.randf_range(0, 360), rng.randf_range(0.5, 0.9))
		z -= 8.0
		i += 1
	# A boulder and a fallen trunk half across the bed for something to duck behind.
	F.rock(root, "rock_b", _on(creek_x(-8.0) + 1.5, -8.0), 40.0, 1.3)
	F.fallen_log(root, _on(creek_x(-40.0), -40.0, -0.3), 60.0)


## The ridge: rocks along its rim, a few pines, and the odd bush on the shelf.
static func _ridge(root: Node3D, rng: RandomNumberGenerator, info: Dictionary) -> void:
	var z := 10.0
	while z > RIDGE_END + 2.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				F.rock(root, ["rock_a", "rock_b", "rock_c"][rng.randi() % 3], _on(ridge_x(z) + side * 3.6, z + rng.randf_range(-2, 2)),
						rng.randf_range(0, 360), rng.randf_range(0.8, 1.4), false)
		if rng.randf() < 0.35:
			F.tree(root, _on(ridge_x(z) + rng.randf_range(2.5, 4.0), z, -0.2), rng, 1.1)
		z -= 7.0
	_hide(root, rng, info, ridge_x(-20.0) - 1.5, -20.0, Vector2(3.0, 4.0))
	_hide(root, rng, info, ridge_x(-44.0) + 1.0, -44.0, Vector2(3.0, 4.0))


# --- 1. the picket -------------------------------------------------------------

static func _picket(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var z := -34.0
	var x := trail_x(z)
	F.fallen_log(root, _on(x + 2.0, z), 4.0)
	F.rock(root, "rock_b", _on(x - 7.5, z - 1.0), 30.0, 1.4)
	F.sandbags(root, _on(x - 7.5, z + 1.6), 0.0)
	F.barrels(root, _on(x + 7.5, z - 2.5), 20.0)
	F.pallet(root, _on(x + 9.5, z - 0.5), -15.0)
	keep_out.append(Rect2(x - 12, z - 6, 24, 12))
	var count := rng.randi_range(1, 2)
	for k in count:
		var gx := x + (2.5 if k == 0 else -7.5)
		_grunt(root, info, _on(gx, z - 1.4), Vector3(0, 0, 1))


# --- 2. the wall ---------------------------------------------------------------

static func _wall(root: Node3D, info: Dictionary, keep_out: Array) -> void:
	var c := trail_x(WALL_Z)
	# Slabs from hillside to hillside, sunk into the slope where the ground rises.
	for k in 26:
		var x := c - 50.0 + 4.0 * k
		if x > c - 4.0 and x < c + 4.0:
			continue  # the gate
		if x > c + 8.0 and x < c + 16.0:
			continue  # the breach
		if absf(x - (c + CULVERT_X)) < 0.1:
			F.culvert(root, _on(x, WALL_Z))
			continue
		var y := minf(minf(ground(x - 2.0, WALL_Z), ground(x + 2.0, WALL_Z)), ground(x, WALL_Z)) - 0.3
		F.wall_slab(root, Vector3(x, y, WALL_Z))
	F.gate(root, _on(c, WALL_Z))
	# The breach: a pine came down through two slabs. Rubble and the trunk to hop.
	var b := c + 12.0
	F.fallen_log(root, _on(b, WALL_Z + 0.5), 28.0)
	for spec in [[Vector3(-2.6, 0.5, 1.2), Vector3(2.4, 1.0, 1.6), Vector3(8, 25, 6)],
			[Vector3(2.8, 0.45, -1.4), Vector3(2.0, 0.9, 1.4), Vector3(-6, -30, 10)],
			[Vector3(-3.4, 1.4, -0.2), Vector3(1.0, 2.8, 0.8), Vector3(0, 0, 12)],
			[Vector3(3.5, 1.1, 0.0), Vector3(1.0, 2.2, 0.8), Vector3(0, 0, -9)]]:
		Kit.box(root, _on(b, WALL_Z) + spec[0], spec[1], CONCRETE, spec[2], Art.material("concrete"))
	# Sandbags outside the gate, crates, and a lamp over the breach.
	F.sandbags(root, _on(c - 6.0, WALL_Z + 5.0), 10.0)
	F.sandbags(root, _on(c + 6.5, WALL_Z + 6.0), -15.0)
	F.crate_stack(root, _on(c - 9.0, WALL_Z + 2.0), 20.0)
	F.pallet(root, _on(c + 4.0, WALL_Z + 3.0), 5.0)
	F.floodlight(root, _on(c + 18.0, WALL_Z - 2.0), 10.0)
	keep_out.append(Rect2(c - 60, WALL_Z - 6, 120, 13))
	# Watchtower behind the wall, left of the gate, looking out. The culvert comes up behind it.
	var deck := F.watchtower(root, _on(c - 9.0, WALL_Z - 6.5))
	_grunt(root, info, deck + Vector3(0, 0, 0.6), Vector3(0, 0, 1), 0.6)


# --- 3. the outpost ------------------------------------------------------------

static func _outpost(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var c := trail_x(OUTPOST_Z)
	keep_out.append(Rect2(c - 30, -113, 60, 47))
	F.hut(root, _on(c - 14.0, -80.0), 0.0)
	var roof := F.hut(root, _on(c + 15.0, -96.0), -90.0)
	F.hut(root, _on(c - 13.0, -103.0), 90.0)
	F.antenna(root, _on(c + 14.0, -73.0))
	F.fuel_tank(root, _on(c + 4.0, -110.0), 0.0)
	F.floodlight(root, _on(c - 3.0, -67.5), 0.0)
	F.floodlight(root, _on(c + 9.0, -105.0), 200.0)
	F.crate_stack(root, _on(c - 8.5, -77.0), 15.0)
	F.crate_stack(root, _on(c + 9.0, -79.0), -10.0)
	Kit.box(root, _on(c + 11.6, -91.0, 0.6), Vector3(1.2, 1.2, 1.2), GREEN)  # a step up to the hut roof
	Kit.box(root, _on(c - 8.6, -81.0, 0.6), Vector3(1.2, 1.2, 1.2), GREEN)
	F.generator(root, _on(c - 6.5, -84.0), 90.0)
	F.barrels(root, _on(c + 10.0, -84.0), 30.0)
	F.barrels(root, _on(c - 4.0, -106.0), -20.0)
	F.pallet(root, _on(c + 18.0, -84.0), 80.0)
	F.pallet(root, _on(c + 20.0, -106.0), 10.0)
	F.pallet(root, _on(c - 3.0, -72.0), 0.0)
	# The quiet side: a tent row under camo netting along the left, supplies, tall grass by the fence line.
	F.camo_net(root, _on(c - 24.5, -90.0), 90.0)
	F.tent(root, _on(c - 25.0, -87.0), 90.0)
	F.tent(root, _on(c - 25.0, -93.0), 90.0)
	F.pallet(root, _on(c - 21.0, -75.0), 90.0)
	F.pallet(root, _on(c - 20.5, -98.5), 70.0)
	F.barrels(root, _on(c - 19.5, -69.0), 0.0)
	F.wreck_truck(root, _on(c - 17.5, -92.0), 80.0)
	for z in [-70.0, -80.0, -100.0, -109.0]:
		_hide(root, dress, info, c - 29.0, z, Vector2(3.5, 7.0), true)
	_hide(root, dress, info, c + CULVERT_X - 3.0, -64.0, Vector2(3.0, 3.0))
	# The yard: sandbags and crates the squad holds, facing the gate.
	var posts := [Vector3(c - 4.0, 0, -86.0), Vector3(c + 3.5, 0, -87.5), Vector3(c + 0.5, 0, -93.0), Vector3(c - 9.0, 0, -95.0)]
	F.sandbags(root, _on(posts[0].x, posts[0].z), 6.0)
	F.sandbags(root, _on(posts[1].x, posts[1].z), -8.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].z), 5.0)
	F.sandbags(root, _on(posts[3].x, posts[3].z), 20.0)
	var squad := []
	for k in rng.randi_range(2, 3):
		var p: Vector3 = posts[k]
		squad.append(_grunt(root, info, _on(p.x, p.z - (1.1 if k != 2 else 1.3)), Vector3(0, 0, 1), 2.0))
	if guarded:
		_guard(root, info, _cache(root, info, _on(c + 2.0, -101.0)), squad)
	else:
		_cache(root, info, roof)


# --- 4. the ravine -------------------------------------------------------------

static func _ravine(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var c := trail_x(RAVINE_Z)
	# No trees on the bridge, the pillars or the fallen pine's ends.
	keep_out.append(Rect2(c - 9.0, FAR_LIP - 12.0, 31.0, NEAR_LIP - FAR_LIP + 24.0))
	keep_out.append(Rect2(c + LOG_X - 2.5, FAR_LIP - 6.0, 5.0, NEAR_LIP - FAR_LIP + 12.0))
	var gap := (NEAR_LIP - FAR_LIP) - BRIDGE_REACH * 2.0
	var near_end := NEAR_LIP - BRIDGE_REACH
	var far_end := FAR_LIP + BRIDGE_REACH
	# The blown bridge: a deck stub on each side.
	F.bridge_stub(root, Vector3(c, 0, near_end + 5.0), 0.0)
	F.bridge_stub(root, Vector3(c, 0, far_end - 5.0), 180.0)
	# Route 1: a blast shield still hangs on the bridge's left girder. Wallrun it.
	var mid := (near_end + far_end) * 0.5
	# What the tutorial points at (tutorial.gd): each crossing's pieces.
	var crossing := {"lip": _on(c, NEAR_LIP + 14.0), "wallrun": [], "grapple": [], "pillars": [], "log": []}
	info["crossing"] = crossing
	crossing["wallrun"].append(Kit.box(root, Vector3(c + SHIELD_X, 0, mid), Vector3(1, 12, gap), BLUE))
	Kit.box(root, Vector3(c + SHIELD_X, 6.4, mid), Vector3(0.7, 0.8, NEAR_LIP - FAR_LIP + 4.0), CONCRETE, Vector3.ZERO, Art.material("gunmetal"))
	info["segments"].append({"type": "wallrun", "gap": gap, "rise": 0.0})
	# Route 2: the crane pylon on the far side. Its arm holds a grapple anchor over the gap.
	var anchor_z := near_end - gap * 0.6
	F.pylon(root, Vector3(c + ANCHOR_X, 0, anchor_z - 9.0), 0.0)
	crossing["grapple"].append(Kit.box(root, Vector3(c + ANCHOR_X, ANCHOR_Y, anchor_z), Vector3(3, 2, 3), ORANGE))
	info["segments"].append({"type": "grapple", "gap": gap, "rise": 0.0})
	# Route 3: rock pillars off to the right. Short hops, longer way round.
	var px := c + PILLAR_X
	var last_edge := NEAR_LIP
	var last_top := 0.0
	for p in PILLARS:
		var front: float = p[0]
		var top: float = p[1]
		var back := front - PILLAR
		var h := top - RAVINE_FLOOR + 1.0
		crossing["pillars"].append(Kit.box(root, Vector3(px, top - h * 0.5, (front + back) * 0.5), Vector3(PILLAR, h, PILLAR), CONCRETE, Vector3.ZERO, F.HubProps.material("rock")))
		F.spawn(root, "rock_c", Vector3(px + PILLAR * 0.5 - 0.6, top, back + 0.5), rng.randf_range(0, 360), 0.8)
		info["segments"].append({"type": "jump", "gap": last_edge - front, "rise": top - last_top})
		last_edge = back
		last_top = top
	info["segments"].append({"type": "jump", "gap": last_edge - FAR_LIP, "rise": -last_top})
	# Route 4: a giant pine fell across upstream, out of the far picket's view. Walk it.
	var before := root.get_child_count()
	F.log_bridge(root, Vector3(c + LOG_X, -0.3, RAVINE_Z), 90.0)
	crossing["log"] = root.get_children().slice(before)
	_hide(root, dress, info, c + LOG_X - 3.0, NEAR_LIP + 5.0, Vector2(3.0, 5.0), true)
	_hide(root, dress, info, c + LOG_X + 3.5, FAR_LIP - 5.0, Vector2(3.0, 6.0), true)
	_hide(root, dress, info, c + LOG_X - 3.5, FAR_LIP - 9.0, Vector2(3.0, 5.0))
	# Rocks along both lips.
	for z in [NEAR_LIP + 1.0, FAR_LIP - 1.0]:
		for i in 12:
			var x := c - 48.0 + i * 8.5 + rng.randf_range(-2, 2)
			if absf(x - c) < 5.0 or absf(x - px) < 3.5 or absf(x - (c + LOG_X)) < 3.0:
				continue
			F.rock(root, ["rock_a", "rock_b", "rock_c"][i % 3], _on(x, z), rng.randf_range(0, 360), rng.randf_range(1.0, 1.8))
	# Grunts dug in on the far lip, watching the bridge.
	var picket := [Vector3(c - 9.0, 0, FAR_LIP - 8.0), Vector3(c + 10.0, 0, FAR_LIP - 9.0)]
	for k in picket.size():
		var p: Vector3 = picket[k]
		F.sandbags(root, _on(p.x, p.z), rng.randf_range(-10, 10))
		if k == 0 or rng.randf() < 0.5:
			_grunt(root, info, _on(p.x, p.z - 1.1), Vector3(0, 0, 1), 2.0)
	F.floodlight(root, _on(c + 6.0, FAR_LIP - 14.0), 180.0)
	F.barrels(root, _on(c - 4.0, FAR_LIP - 12.0), 40.0)
	F.pallet(root, _on(c + 14.0, FAR_LIP - 13.0), -10.0)


# --- 5. the logging camp -------------------------------------------------------

static func _camp(root: Node3D, rng: RandomNumberGenerator, dress: RandomNumberGenerator, info: Dictionary, keep_out: Array, guarded: bool) -> void:
	var c := trail_x(CAMP_Z)
	keep_out.append(Rect2(c - 19, -214, 47, 48))
	var roof := F.sawmill(root, _on(c + 6.0, -192.0), 0.0)
	# Steps up to the sawmill roof: a log pile, then a double pile beside it.
	F.log_pile(root, _on(c - 2.0, -185.5), 0.0)
	F.log_pile(root, _on(c + 3.5, -185.5), 0.0)
	F.log_pile(root, _on(c + 3.5, -185.5, 1.8), 0.0)
	var deck := F.watchtower(root, _on(c - 14.0, -175.0), 10.0)
	_grunt(root, info, deck + Vector3(0, 0, 0.6), Vector3(0, 0, 1), 0.6)
	F.hut(root, _on(c - 14.0, -200.0), 90.0)
	F.floodlight(root, _on(c - 5.0, -170.0), 0.0)
	F.floodlight(root, _on(c + 15.0, -184.0), -60.0)
	F.log_pile(root, _on(c + 14.0, -200.0), 80.0)
	F.crate_stack(root, _on(c - 7.0, -192.0), 30.0)
	F.generator(root, _on(c + 1.0, -197.5), 0.0)
	F.barrels(root, _on(c + 12.0, -181.0), 10.0)
	F.pallet(root, _on(c - 6.0, -169.0), 20.0)
	F.tent(root, _on(c - 6.0, -206.0), 0.0)
	F.tent(root, _on(c + 0.5, -207.0), 0.0)
	# The right flank: lumber stacked for hauling, and a truck under netting. Plenty to hide behind.
	F.log_pile(root, _on(c + 22.0, -176.0), 90.0)
	F.log_pile(root, _on(c + 24.0, -186.0), 85.0)
	F.log_pile(root, _on(c + 22.5, -197.0), 95.0)
	F.camo_net(root, _on(c + 19.0, -207.0), 0.0)
	F.wreck_truck(root, _on(c + 19.0, -207.0), 5.0)
	# The left flank: woods, tall grass and a hunter's blind looking into the camp.
	F.deer_stand(root, _on(c - 26.0, -182.0), 90.0)
	for z in [-166.0, -176.0, -192.0, -202.0, -211.0]:
		_hide(root, dress, info, c - 23.0 + dress.randf_range(-2, 2), z, Vector2(4.0, 7.0), true)
	# The yard in front of the mill.
	var posts := [Vector3(c + 2.0, 0, -176.0), Vector3(c - 4.0, 0, -179.5), Vector3(c + 9.0, 0, -178.5)]
	F.sandbags(root, _on(posts[0].x, posts[0].z), -5.0)
	F.sandbags(root, _on(posts[1].x, posts[1].z), 12.0)
	F.crate_stack(root, _on(posts[2].x, posts[2].z), 0.0)
	var squad := []
	for k in rng.randi_range(2, 3):
		var p: Vector3 = posts[k]
		squad.append(_grunt(root, info, _on(p.x, p.z - (1.1 if k != 2 else 1.3)), Vector3(0, 0, 1), 2.0))
	if guarded:
		_guard(root, info, _cache(root, info, _on(c + 2.5, -189.6)), squad)
	else:
		_cache(root, info, roof)
	# Stumps: they've been cutting.
	for i in 50:
		var p := Vector2(rng.randf_range(c - 34, c + 34), rng.randf_range(-216, -160))
		if absf(p.x - trail_x(p.y)) < 3.0 or Rect2(c - 2, -197, 16, 12).has_point(p) or Rect2(c - 6, -188, 12, 5).has_point(p):
			continue
		F.spawn(root, "stump", _on(p.x, p.y), rng.randf_range(0, 360), rng.randf_range(0.8, 1.3))


# --- 6. the clearing -----------------------------------------------------------

static func _end(root: Node3D, info: Dictionary, keep_out: Array) -> void:
	var x := trail_x(END_Z)
	var beacon := ExtractBeacon.new()
	beacon.text = "EXTRACT"
	root.add_child(beacon)
	beacon.position = _on(x, END_Z)
	info["beacon"] = beacon
	keep_out.append(Rect2(x - 12, END_Z - 12, 24, 24))
	F.spawn(root, "rock_b", _on(x - 6.0, END_Z - 4.0), 40.0, 1.8)
	F.spawn(root, "rock_a", _on(x + 7.0, END_Z + 2.0), 10.0, 1.5)


# --- the routes ----------------------------------------------------------------

## The three ways through, as points along each (for the map, and for tests).
static func _routes(info: Dictionary) -> void:
	var c1 := trail_x(OUTPOST_Z)
	var cr := trail_x(RAVINE_Z)
	var c2 := trail_x(CAMP_Z)
	var cw := trail_x(WALL_Z)
	var trail := PackedVector3Array()
	var z := 8.0
	while z > END_Z:
		var x := cr if (z < NEAR_LIP + 8.0 and z > FAR_LIP - 8.0) else trail_x(z)
		trail.append(Vector3(x, 0.3, z) if (z < NEAR_LIP and z > FAR_LIP) else _on(x, z, 0.3))
		z -= 4.0
	var quiet := PackedVector3Array()
	z = CREEK_START - 6.0
	while z > WALL_Z - 4.0:
		quiet.append(_on(creek_x(z), z, 0.3))
		z -= 4.0
	for p in [Vector2(c1 - 22.0, -72.0), Vector2(c1 - 22.0, -84.0), Vector2(c1 - 22.0, -100.0), Vector2(cr + LOG_X, -114.0)]:
		quiet.append(_on(p.x, p.y, 0.3))
	quiet.append(Vector3(cr + LOG_X, 0.3, NEAR_LIP))
	quiet.append(Vector3(cr + LOG_X, 0.3, FAR_LIP))
	for p in [Vector2(cr + LOG_X, -156.0), Vector2(c2 - 22.0, -168.0), Vector2(c2 - 23.0, -182.0), Vector2(c2 - 22.0, -200.0),
			Vector2(c2 - 20.0, -214.0), Vector2(trail_x(-230.0) - 10.0, -230.0), Vector2(trail_x(END_Z), END_Z)]:
		quiet.append(_on(p.x, p.y, 0.3))
	var high := PackedVector3Array()
	z = 14.0
	while z > RIDGE_END:
		high.append(_on(ridge_x(z), z, 0.3))
		z -= 6.0
	high.append(Vector3(ridge_x(RIDGE_END), 6.0, WALL_Z))
	for p in [Vector3(c1 + 18.0, 0.3, -76.0), Vector3(c1 + 15.0, 3.8, -96.0), Vector3(c1 + 10.0, 0.3, -114.0),
			Vector3(cr + ANCHOR_X, 0.3, NEAR_LIP + 2.0), Vector3(cr + ANCHOR_X, ANCHOR_Y - 1.0, NEAR_LIP - 11.6),
			Vector3(cr + 1.0, 0.3, FAR_LIP - 6.0), Vector3(c2 - 2.0, CAMP_Y + 2.1, -185.5),
			Vector3(c2 + 3.5, CAMP_Y + 3.9, -185.5), Vector3(c2 + 6.0, CAMP_Y + 5.3, -192.0),
			Vector3(c2 + 8.0, CAMP_Y + 0.3, -214.0), Vector3(trail_x(END_Z) + 2.0, CAMP_Y + 2.8, END_Z)]:
		high.append(p)
	info["routes"] = [
		{"name": "The trail", "kind": "loud", "points": trail},
		{"name": "The creek", "kind": "quiet", "points": quiet},
		{"name": "The ridge and rooftops", "kind": "high", "points": high},
	]


# --- the forest itself ---------------------------------------------------------

## True where nothing should grow: the trail, the creek bed, the ridge top, the
## camps (`keep_out`), and round the spawn.
static func _bare(x: float, z: float, keep_out: Array) -> bool:
	if absf(x - trail_x(z)) < 4.5 or Vector2(x, z).distance_to(Vector2(trail_x(4.0), 4.0)) < 10.0:
		return true
	if z < CREEK_START + 2.0 and z > CREEK_END and absf(x - creek_x(z)) < 3.0:
		return true
	if z < 12.0 and z > RIDGE_END and absf(x - ridge_x(z)) < 2.4:
		return true
	for r in keep_out:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


static func _forest(root: Node3D, rng: RandomNumberGenerator, info: Dictionary, keep_out: Array) -> void:
	var cr := trail_x(RAVINE_Z)
	# Solid trees on the valley floor, close together.
	var z := 34.0
	while z > -262.0:
		var w := half_width(z) + 3.0
		var x := trail_x(z) - w
		while x < trail_x(z) + w:
			var p := Vector2(x + rng.randf_range(-1.8, 1.8), z + rng.randf_range(-1.8, 1.8))
			var in_ravine := p.y < NEAR_LIP + 1.5 and p.y > FAR_LIP - 1.5
			if rng.randf() < 0.72 and not _bare(p.x, p.y, keep_out) and not (in_ravine and absf(p.x - cr) < 32.0):
				F.tree(root, _on(p.x, p.y, -0.2), rng, rng.randf_range(0.9, 1.45))
			x += 4.6
		z -= 4.6
	# A few trees inside the camps' edges and the outpost so they sit in the forest.
	for p in [Vector2(-31, -70), Vector2(26, -104), Vector2(-31, -112), Vector2(32, -166), Vector2(-26, -210), Vector2(24, -212)]:
		var tx: float = p.x + trail_x(p.y)
		F.tree(root, _on(tx, p.y, -0.2), rng, 1.2)
	# Fallen logs and boulders through the woods, for cover.
	var logs := 0
	var tries := 0
	while logs < 14 and tries < 400:
		tries += 1
		var lz := rng.randf_range(-258.0, 20.0)
		var lx := trail_x(lz) + rng.randf_range(-26.0, 26.0)
		if _bare(lx, lz, keep_out) or (lz < NEAR_LIP + 8.0 and lz > FAR_LIP - 8.0) or absf(lx - trail_x(lz)) < 7.0:
			continue
		F.fallen_log(root, _on(lx, lz, -0.1), rng.randf_range(0, 360))
		logs += 1
	var rocks := 0
	tries = 0
	while rocks < 40 and tries < 600:
		tries += 1
		var rz := rng.randf_range(-258.0, 30.0)
		var rx := trail_x(rz) + rng.randf_range(-28.0, 28.0)
		if _bare(rx, rz, keep_out) or (rz < NEAR_LIP + 3.0 and rz > FAR_LIP - 3.0):
			continue
		F.rock(root, ["rock_a", "rock_b", "rock_c"][rocks % 3], _on(rx, rz), rng.randf_range(0, 360), rng.randf_range(1.0, 2.4))
		rocks += 1
	# Patches of tall grass out in the woods: somewhere to drop out of sight between trees.
	var patches := 0
	tries = 0
	while patches < 26 and tries < 600:
		tries += 1
		var gz := rng.randf_range(-258.0, 20.0)
		var gx := trail_x(gz) + rng.randf_range(-27.0, 27.0) * (1.0 if rng.randf() < 0.5 else 0.6)
		if _bare(gx, gz, keep_out) or (gz < NEAR_LIP + 3.0 and gz > FAR_LIP - 3.0):
			continue
		_hide(root, rng, info, gx, gz, Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(3.0, 6.0)), rng.randf() < 0.3, rng.randf_range(0, 180))
		patches += 1
	# Far forest beyond the hillsides: batched, no collision.
	var far := {}
	for id in ["pine_a", "pine_b", "pine_c", "tree_a", "snag"]:
		far[id] = []
	z = 66.0
	while z > -296.0:
		for side in [-1.0, 1.0]:
			var d := half_width(z) + 4.0
			while d < half_width(z) + 80.0:
				var px: float = trail_x(z) + side * (d + rng.randf_range(-2.0, 2.0))
				var pz := z + rng.randf_range(-2.5, 2.5)
				var id: String = ["pine_a", "pine_b", "pine_c", "pine_a", "pine_b", "tree_a", "snag"][rng.randi() % 7]
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
				far[id].append(Transform3D(basis, _on(px, pz, -0.3)))
				d += rng.randf_range(4.5, 7.0)
		z -= 5.0
	# Trees across both ends of the valley too.
	for zz in [[30.0, 66.0], [-296.0, -262.0]]:
		for i in 300:
			var pz := rng.randf_range(zz[0], zz[1])
			var px := trail_x(pz) + rng.randf_range(-70.0, 70.0)
			if pz < 0.0 and pz > -268.0:
				continue
			var id: String = ["pine_a", "pine_b", "pine_c"][i % 3]
			far[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), _on(px, pz, -0.3)))
	for id in far:
		var tint: Color = F.NEEDLE_TINTS[0] if id.begins_with("pine") else F.LEAF_TINTS[0]
		F.scatter(root, id, far[id], {"leaves": tint})
	# Hills on the horizon.
	for i in 16:
		var ang := TAU * i / 16.0
		var base := Vector3(sin(ang) * 240.0, -6.0, -110.0 + cos(ang) * 270.0)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.0, 1.4),
				{"hill_forest": Color(0.7, 0.85, 0.75)})
	# Undergrowth: grass, ferns and bushes off the trail and out of the camps.
	var grass := []
	var ferns := []
	var bushes := {"bush_a": [], "bush_b": []}
	tries = 0
	while grass.size() < 9000 and tries < 60000:
		tries += 1
		var pz := rng.randf_range(-262.0, 30.0)
		var px := trail_x(pz) + rng.randf_range(-half_width(pz) - 4.0, half_width(pz) + 4.0)
		if pz < NEAR_LIP + 0.5 and pz > FAR_LIP - 0.5:
			continue
		if absf(px - trail_x(pz)) < 2.2:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6))
		var t := Transform3D(basis, _on(px, pz, -0.05))
		var roll := rng.randf()
		var in_camp := false
		for r in keep_out:
			if (r as Rect2).has_point(Vector2(px, pz)):
				in_camp = true
				break
		if roll < 0.12 and not in_camp:
			ferns.append(Transform3D(basis.scaled(Vector3.ONE * 1.1), t.origin))
		elif roll < 0.17 and not in_camp and not _bare(px, pz, keep_out):
			bushes["bush_a" if roll < 0.145 else "bush_b"].append(Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), t.origin))
		else:
			grass.append(t)
	F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.68, 0.8, 0.58)}, false)
	F.scatter(root, "fern", ferns, {"leaves": Color(0.55, 0.75, 0.5)}, false)
	for id in bushes:
		F.scatter(root, id, bushes[id], {"leaves": F.LEAF_TINTS[2]})
	F.scatter(root, "tall_grass", info["tall_grass"], {"grass_blade": Color(0.75, 0.8, 0.55)}, false)
	info["tall_grass"] = []


# --- the forest's edge (the titan arena) -----------------------------------------

const EDGE_HALF := 38.0
const EVAC := Vector3(6.0, 0.0, -42.0)


static func edge_ground(x: float, z: float) -> float:
	var h := 0.0
	var out := maxf(absf(x) - 34.0, 0.0) + maxf(z - 34.0, 0.0)
	h += _bumps(x, z) * clampf(out / 8.0, 0.0, 1.0)
	# Behind you, the forest floor climbs back into the trees.
	if z > 36.0:
		h += (z - 36.0) * 0.18
	# Ahead, past the evac pad, the meadow rolls down to the plains.
	if z < -52.0:
		h -= (-52.0 - z) * 0.14
	if absf(x) > 46.0:
		var o := absf(x) - 46.0
		h += minf(o * 0.45 + o * o * 0.015, 16.0)
	return h


## The end-of-run arena. Same keys as before (spawn, half_size, boss, ...), plus
## evac (where the dropship picks your titan up) and evac_node (the dropship and
## its beam, hidden until the enemy titan is down).
static func build_edge(root: Node3D) -> Dictionary:
	Kit.environment(root, Color(0.3, 0.38, 0.58), Color(0.92, 0.74, 0.58))
	Ambience.start(root, {"forest_wind": -13.0, "forest_night": -21.0})
	var info := {
		"name": "THE FOREST'S EDGE",
		"spawn": Vector3(0, 0.1, 30.0), "platforms": [], "segments": [],
		"caches": [], "objectives": [], "beacon": null, "floor_y": 0.0,
		"half_size": EDGE_HALF, "evac": EVAC,
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var nx := 111
	var nz := 111
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = edge_ground(-110.0 + ix * 2.0, -150.0 + iz * 2.0)
	Terrain.build(root, heights, nx, nz, -110.0, -150.0, 2.0, Color(0.78, 0.82, 0.52), Color(0.85, 0.8, 0.74))
	# Fences: the meadow and a strip of treeline.
	for spec in [[Vector3(-48, 20, -10), Vector3(1, 80, 120)], [Vector3(48, 20, -10), Vector3(1, 80, 120)],
			[Vector3(0, 20, 44), Vector3(100, 80, 1)], [Vector3(0, 20, -62), Vector3(100, 80, 1)]]:
		F.solid(root, spec[0], spec[1])
	var on := func(x: float, z: float) -> Vector3:
		return Vector3(x, edge_ground(x, z), z)
	# The treeline you walk out of, wrapping round both flanks.
	var near := {"pine_a": [], "pine_b": [], "pine_c": [], "tree_a": []}
	for i in 900:
		var px := rng.randf_range(-110.0, 110.0)
		var pz := rng.randf_range(-40.0, 70.0)
		var edge_line := 36.0 - maxf(absf(px) - 30.0, 0.0) * 2.2
		if pz < edge_line + rng.randf_range(-3.0, 3.0) or (absf(px) < 6.0 and pz < 44.0):
			continue
		var id: String = ["pine_a", "pine_b", "pine_c", "pine_a", "tree_a"][i % 5]
		if Vector2(px, pz).distance_to(Vector2(0, 30)) < 16.0 or absf(px) < 44.0 and pz < 44.0:
			F.tree(root, on.call(px, pz) - Vector3(0, 0.2, 0), rng, 1.2, id)
		else:
			near[id].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), on.call(px, pz) - Vector3(0, 0.3, 0)))
	for id in near:
		F.scatter(root, id, near[id], {"leaves": F.NEEDLE_TINTS[0] if id.begins_with("pine") else F.LEAF_TINTS[0]})
	# Hills over the plains.
	for i in 10:
		var base := Vector3(-240.0 + i * 53.0, -20.0, -230.0 - absf(i - 4.5) * 12.0)
		F.spawn(root, "hill_a" if i % 2 == 0 else "hill_b", base, rng.randf_range(0, 360), rng.randf_range(1.2, 1.8),
				{"hill_forest": Color(0.8, 0.85, 0.75)})
	# The forward base they were building: wall slabs (titan cover), wrecks, crates.
	for spec in [[Vector3(-15, 0, 5), 20.0, 3], [Vector3(-6, 0, -18), -10.0, 2], [Vector3(26, 0, -24), 60.0, 2]]:
		var at: Vector3 = spec[0]
		var yaw: float = spec[1]
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		for k in int(spec[2]):
			var p: Vector3 = at + basis * Vector3((k - (spec[2] - 1) * 0.5) * 4.0, 0, 0)
			F.wall_slab(root, on.call(p.x, p.z) - Vector3(0, 0.2, 0), yaw)
	for spec in [[Vector3(16, 0, -2), 1.0], [Vector3(-26, 0, -30), 0.8], [Vector3(30, 0, 12), 0.7]]:
		var p: Vector3 = spec[0]
		F.rock(root, "rock_b", on.call(p.x, p.z), rng.randf_range(0, 360), 3.2 * spec[1])
		F.rock(root, "rock_a", on.call(p.x + 3.0, p.z + 2.0), rng.randf_range(0, 360), 2.0 * spec[1])
	F.wreck_truck(root, on.call(20, 20), 35.0)
	F.wreck_truck(root, on.call(-24, 18), -70.0)
	F.fuel_tank(root, on.call(-30, -8), 80.0)
	for p in [Vector2(18, 23), Vector2(-9, -14), Vector2(4, 12), Vector2(-20, 26)]:
		F.sandbags(root, on.call(p.x, p.y), rng.randf_range(-30, 30))
	F.crate_stack(root, on.call(-2, -16), 10.0)
	F.crate_stack(root, on.call(8, 6), -20.0)
	F.floodlight(root, on.call(-10, -20), 160.0)
	# Their camp for the build crews: tents under netting, supplies, a generator.
	F.camo_net(root, on.call(-30, 4), 15.0)
	F.tent(root, on.call(-31, 2), 15.0)
	F.tent(root, on.call(-27, 7), 15.0)
	F.generator(root, on.call(-22, 0), 40.0)
	for p in [Vector2(-12, 10), Vector2(10, -10), Vector2(24, -12), Vector2(-18, -26), Vector2(30, -2)]:
		F.pallet(root, on.call(p.x, p.y), rng.randf_range(0, 180))
	for p in [Vector2(-28, -6), Vector2(14, 8), Vector2(22, -30)]:
		F.barrels(root, on.call(p.x, p.y), rng.randf_range(0, 180))
	for spec in [[Vector3(34, 0, -12), 100.0, 2], [Vector3(-36, 0, -22), 70.0, 2], [Vector3(12, 0, 26), 0.0, 1]]:
		var at: Vector3 = spec[0]
		var basis := Basis(Vector3.UP, deg_to_rad(spec[1]))
		for k in int(spec[2]):
			var p: Vector3 = at + basis * Vector3((k - (spec[2] - 1) * 0.5) * 4.0, 0, 0)
			F.wall_slab(root, on.call(p.x, p.z) - Vector3(0, 0.2, 0), spec[1])
	# Tall grass along the treeline, for the walk out before your titan lands.
	var tall := []
	for p in [Vector2(-38, 26), Vector2(-40, 10), Vector2(38, 24), Vector2(40, 6), Vector2(-20, 34), Vector2(22, 34)]:
		tall.append_array(F.grass_patch(root, func(x, z): return edge_ground(x, z), p, Vector2(5, 7), rng))
	F.scatter(root, "tall_grass", tall, {"grass_blade": Color(0.85, 0.85, 0.55)}, false)
	# Grass over the meadow.
	var grass := []
	for i in 6000:
		var px := rng.randf_range(-48.0, 48.0)
		var pz := rng.randf_range(-62.0, 44.0)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.8))
		grass.append(Transform3D(basis, on.call(px, pz) - Vector3(0, 0.05, 0)))
	F.scatter(root, "grass_tuft", grass, {"grass_blade": Color(0.8, 0.85, 0.6)}, false)
	# Evac pad, and the dropship that comes for your titan once theirs is down.
	evac_pad(root, info, EVAC)
	Kit.label(root, Vector3(0, 4, 22), "CALL IN YOUR TITAN", 96)
	var boss := Boss.new()
	root.add_child(boss)
	boss.position = Vector3(0, 0, -25)
	info["boss"] = boss
	return info


## The evac pad at `pos` and the dropship over it, hidden until the enemy
## titan is down (info["evac_node"]; run_manager brings the ship in). The
## generated levels' finales use it too.
static func evac_pad(root: Node3D, info: Dictionary, pos: Vector3) -> void:
	F.spawn(root, "evac_pad", pos - Vector3(0, 0.14, 0), 0.0, 1.0, {}, Color(0.4, 1.0, 0.6))
	var evac := Node3D.new()
	evac.name = "Evac"
	evac.position = pos
	evac.visible = false
	root.add_child(evac)
	var ship := F.spawn(evac, "dropship", Vector3(0, 16.0, 0), 200.0, 1.0, {"titan_armor": Color(0.7, 0.8, 0.95)}, Color(0.5, 0.9, 1.0))
	ship.name = "Dropship"
	var beam := CylinderMesh.new()
	beam.top_radius = 6.0
	beam.bottom_radius = 6.0
	beam.height = 16.0
	beam.material = Kit.glow(Color(0.3, 0.9, 0.6, 0.18))
	var beam_mi := MeshInstance3D.new()
	beam_mi.mesh = beam
	beam_mi.position.y = 8.0
	evac.add_child(beam_mi)
	Kit.label(evac, Vector3(0, 6.0, 0), "EVAC", 128)
	info["evac_node"] = evac
	info["evac"] = pos
