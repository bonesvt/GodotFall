extends SceneTree
## Headless test for generated zones (scripts/run/procgen/).
## Run: godot --headless --path . -s res://tests/procgen_test.gd
## Plans many seeds and checks their shape; builds a few (every biome, 3 to 5
## lanes) and checks what's in them can be played: crossings inside the
## movement limits, rooftop runs you can jump, grunts standing on something,
## a navmesh their patrols can walk; then plays a long run into an uncharted
## zone and watches a patrol walk.

const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const ZoneGenerator := preload("res://scripts/run/procgen/zone_generator.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")
const Loot := preload("res://scripts/run/loot.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const SetPieces := preload("res://scripts/run/procgen/set_pieces.gd")
## How far the grapple reaches (player.gd grapple_range).
const GRAPPLE_RANGE := 45.0

## Widest gap and biggest step up between roofs a pilot can jump (m).
const ROOF_JUMP := 4.5
const ROOF_RISE := 1.6

var failures := 0
## Every set piece id the built zones used, to check they vary.
var kinds_seen := {}


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	_plan_checks()
	for spec in [[11, 3, "forest"], [12, 4, "marsh"], [13, 5, "boneyard"], [14, 5, "forest"], [15, 3, "marsh"], [16, 4, "boneyard"]]:
		await _zone_checks(spec[0], spec[1], spec[2])
	_check("the built zones use %d of the %d set pieces" % [kinds_seen.size(), SetPieces.Shapes.SHAPES.size()],
			kinds_seen.size() >= 20, kinds_seen.keys())
	await _run_checks()
	print("procgen test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# --- plans -----------------------------------------------------------------------

func _plan_checks() -> void:
	var bad := []
	var lane_counts := {}
	var biomes := {}
	var fillers := {}
	for s in range(1, 61):
		var plan = LevelPlan.make(s, 3 + s % 3)
		lane_counts[plan.lanes.size()] = true
		biomes[plan.biome] = true
		for x in plan.sections:
			fillers[x["kind"]] = true
		var kinds: Array = plan.lanes.map(func(l): return l["kind"])
		if plan.lanes.size() < 3 or plan.lanes.size() > 5 or kinds.count("loud") != 1 or not "quiet" in kinds or not "high" in kinds:
			bad.append([s, "lanes", kinds])
		var sec: Array = plan.sections.map(func(x): return x["kind"])
		for need in ["start", "outpost", "camp", "wall", "chasm", "end"]:
			if not need in sec:
				bad.append([s, "missing", need])
		var caches: Array = plan.sections.filter(func(x): return x.has("cache")).map(func(x): return x["cache"])
		caches.sort()
		if caches != ["guarded", "high"]:
			bad.append([s, "caches", caches])
		for c in plan.sections_of("chasm"):
			if fmod(absf(c["near_lip"]), LevelPlan.CELL) > 0.01 or absf(c["near_lip"] - c["far_lip"] - LevelPlan.CHASM_GAP) > 0.01:
				bad.append([s, "chasm lips", c["near_lip"], c["far_lip"]])
		# Nowhere you can walk counts as a fall, and the chasm floors all do.
		var z: float = plan.spawn_z
		while z > plan.end_z:
			if plan.in_chasm(z).is_empty():
				for i in plan.lanes.size():
					if plan.ground(plan.lane_x(i, z), z) < plan.kill_y + 1.0:
						bad.append([s, "lane below kill_y", i, z])
						break
			z -= 4.0
		if plan.floor_y > plan.kill_y - 4.0:
			bad.append([s, "chasm floor above kill_y", plan.floor_y, plan.kill_y])
		# Lanes keep apart.
		z = plan.spawn_z
		while z > plan.end_z:
			for i in plan.lanes.size() - 1:
				if plan.lane_x(i + 1, z) - plan.lane_x(i, z) < 14.0:
					bad.append([s, "lanes too close", i, z])
			z -= 8.0
	_check("60 plans: 3-5 lanes with a loud, quiet and high one, every set piece, one guarded and one high cache, safe kill height",
			bad.is_empty(), bad.slice(0, 6))
	_check("plans use 3, 4 and 5 lanes and every biome", lane_counts.size() == 3 and biomes.size() == 3, [lane_counts.keys(), biomes.keys()])
	_check("plans use every kind of section, ruins included", fillers.size() == LevelPlan.SECTION_LEN.size(), fillers.keys())
	_check("same seed, same plan", LevelPlan.make(77, 4).describe() == LevelPlan.make(77, 4).describe() and LevelPlan.make(77, 4).describe() != LevelPlan.make(78, 4).describe(),
			LevelPlan.make(77, 4).describe())


# --- built zones ---------------------------------------------------------------------

func _zone_checks(seed_value: int, lanes: int, biome: String) -> void:
	var plan = LevelPlan.make(seed_value, 3, lanes, biome)
	var world := Node3D.new()
	root.add_child(world)
	var t := Time.get_ticks_msec()
	var info := ZoneGenerator.build_from_plan(world, plan, 3)
	var build_ms := Time.get_ticks_msec() - t
	var region: NavigationRegion3D = info["nav_region"]
	if region.is_baking():
		await region.bake_finished
	var bake_ms := Time.get_ticks_msec() - t - build_ms
	await _nav_synced(world, info["spawn"])
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = seed_value
	Loot.scatter(world, info, loot_rng, 3)
	await physics_frame
	await physics_frame
	var tag := "%s %d lanes (seed %d)" % [biome, lanes, seed_value]
	var bad := []

	if info["caches"].size() != 2 or info["objectives"].size() != 1 or not info["objectives"][0].cache.locked:
		bad.append(["caches", info["caches"].size(), info["objectives"].size()])
	var kinds: Array = info["routes"].map(func(r): return r["kind"])
	if kinds != plan.lanes.map(func(l): return l["kind"]):
		bad.append(["routes", kinds])
	var beacon: Vector3 = info["beacon"].position
	for r in info["routes"]:
		if (r["points"] as PackedVector3Array)[-1].distance_to(beacon) > 1.0:
			bad.append(["route misses the beacon", r["name"]])
	if info["checkpoints"].size() < plan.sections.size():
		bad.append(["checkpoints", info["checkpoints"].size()])
	_check("%s: two caches (one guarded), a route per lane to the beacon, checkpoints" % tag, bad.is_empty(), bad)

	bad = []
	for seg in info["segments"]:
		var limits: Vector2 = ZoneBuilder.GAPS[seg["type"]]
		if seg["gap"] > limits.y or (seg["type"] == "jump" and seg["rise"] > 0.5):
			bad.append(seg)
	var chasms: int = plan.sections_of("chasm").size()
	if info["crossings"].size() != chasms or info["segments"].size() < chasms * 2:
		bad.append(["crossings", info["crossings"].size(), chasms])
	_check("%s: %d chasm crossings inside the movement limits" % [tag, chasms], bad.is_empty(), bad)

	# Rooftop runs: from the ridge onto the first roof, roof to roof, and off the last.
	bad = []
	for lane in info["perches"]:
		var p: Dictionary = info["perches"][lane]
		var roofs: Array = p["roofs"]
		if p["gap"] > ROOF_JUMP:
			bad.append(["gap", lane, p["gap"]])
		for k in roofs.size() - 1:
			if roofs[k + 1].y - roofs[k].y > ROOF_RISE:
				bad.append(["step up", lane, roofs[k].y, roofs[k + 1].y])
		var first: Vector3 = roofs[0]
		var ridge_y: float = plan.ground(first.x, first.z + p["length"] * 0.5 + p["gap"] + 1.0)
		if first.y - ridge_y > ROOF_RISE:
			bad.append(["ridge to roof", lane, ridge_y, first.y])
		var last: Vector3 = roofs[-1]
		var next_y: float = plan.ground(last.x, last.z - p["length"] * 0.5 - p["gap"] - 1.0)
		if next_y - last.y > ROOF_RISE:
			bad.append(["roof to ridge", lane, last.y, next_y])
	_check("%s: rooftop runs jumpable (%d runs)" % [tag, info["perches"].size()], bad.is_empty(), bad)

	# Everyone stands on something.
	bad = []
	var space := world.get_world_3d().direct_space_state
	for g in info["grunts"]:
		if g.get("gait") == "hover":
			continue  # Choir spotters float on purpose (scripts/threats/seraph.gd)
		var q := PhysicsRayQueryParameters3D.create(g.post + Vector3(0, 0.5, 0), g.post - Vector3(0, 1.2, 0))
		q.exclude = [g.get_rid()]
		if space.intersect_ray(q).is_empty():
			bad.append(g.post)
	for c in info["caches"]:
		var q := PhysicsRayQueryParameters3D.create(c.position + Vector3(0, 0.5, 0), c.position - Vector3(0, 1.0, 0))
		if space.intersect_ray(q).is_empty():
			bad.append(["cache", c.position])
	_check("%s: %d grunts and the caches stand on something" % [tag, info["grunts"].size()], bad.is_empty() and info["grunts"].size() >= 10, bad)

	# Set pieces: a spread of them, and every hook can be grappled from a lane.
	var ids := {}
	for p in info["set_pieces"]:
		ids[p["id"]] = true
		kinds_seen[p["id"]] = true
	bad = []
	for hook in info["grapple_spots"]:
		var seen := false
		for r in info["routes"]:
			for pt in r["points"]:
				var eye: Vector3 = pt + Vector3(0, 1.4, 0)
				if eye.distance_to(hook) > GRAPPLE_RANGE - 2.0 or eye.distance_to(hook) < 6.0:
					continue
				var q := PhysicsRayQueryParameters3D.create(eye, eye + (hook - eye) * 1.2)
				var hit := space.intersect_ray(q)
				if not hit.is_empty() and (hit["position"] as Vector3).distance_to(hook) < 1.6:
					seen = true
					break
			if seen:
				break
		if not seen:
			bad.append(hook)
	_check("%s: %d kinds of set piece, %d hooks all grappleable from a lane, %d walls to run" % [tag, ids.size(), info["grapple_spots"].size(), info["wallruns"].size()],
			ids.size() >= 7 and info["grapple_spots"].size() >= 2 and not info["wallruns"].is_empty() and bad.is_empty(), bad)

	var blockers: int = world.get_children().filter(func(n): return n.is_in_group("sight_blocker")).size()
	_check("%s: grass to hide in (%d patches, %d block sight)" % [tag, info["stealth_cover"].size(), blockers],
			info["stealth_cover"].size() >= 40 and blockers >= 12, "")
	var counts: Dictionary = info["loot_counts"]
	var kept: Array = info["loot"].filter(func(n): return is_instance_valid(n))
	var nodes: int = kept.filter(func(n): return "alloy" in n.loot).size()
	_check("%s: loot placed and settled on the ground (%d of %d, %d alloy)" % [tag, kept.size(), counts["node"] + counts["crate"], nodes],
			kept.size() == counts["node"] + counts["crate"] and nodes >= 1, "")

	# The navmesh: baked, and every patrol can walk its loop.
	var polys := region.navigation_mesh.get_polygon_count()
	_check("%s: navmesh baked (%d polygons; build %d ms, bake %d ms)" % [tag, polys, build_ms, bake_ms], polys > 500, polys)
	bad = []
	var map := world.get_world_3d().navigation_map
	for loop in info["patrols"]:
		for k in loop.size():
			var a: Vector3 = loop[k]
			var b: Vector3 = loop[(k + 1) % loop.size()]
			var path := NavigationServer3D.map_get_path(map, a, b, true)
			if path.is_empty() or Vector2(path[-1].x, path[-1].z).distance_to(Vector2(b.x, b.z)) > 2.0:
				bad.append([a, b, path.size()])
	var loud: int = plan.lane_of("loud")
	var first_z: float = plan.sections[1]["z1"] + 4.0
	var spawn_path := NavigationServer3D.map_get_path(map, info["spawn"], Vector3(plan.lane_x(loud, first_z), 0, first_z), true)
	if spawn_path.is_empty() or absf(spawn_path[-1].z - first_z) > 3.0:
		bad.append(["spawn to the road ahead", spawn_path.size()])
	_check("%s: %d patrol loops walkable on the navmesh" % [tag, info["patrols"].size()], bad.is_empty(), bad)
	world.queue_free()
	await process_frame


# --- in a run ------------------------------------------------------------------------

func _run_checks() -> void:
	var run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4242
	run_node.start_in_hub = false
	run_node.uncharted_zones = RunState.UNCHARTED_ZONES
	run_node.armory_path = "user://test_procgen_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	root.add_child(run_node)
	await physics_frame
	run_node.tutorial.set_enabled(false)
	_check("a long run has 3 + %d zones" % RunState.UNCHARTED_ZONES, run_node.run.zone_count == RunState.ZONE_COUNT + RunState.UNCHARTED_ZONES, run_node.run.zone_count)
	run_node.load_zone(3)
	var info: Dictionary = run_node.zone_info
	_check("zone 4 is uncharted", info.has("plan") and run_node.hud.toast_label.text.contains("UNCHARTED"), run_node.hud.toast_label.text)
	_check("its grunts hunt the pilot", info["grunts"].all(func(g): return g.target == run_node.player), "")
	var region: NavigationRegion3D = info["nav_region"]
	if region.is_baking():
		await region.bake_finished
	await _nav_synced(region, info["spawn"])
	# Find a patroller well away from the pilot and watch it walk.
	var walker = null
	for g in info["grunts"]:
		var loop = g.get("patrol") if g.get("patrol") != null and not g.get("patrol").is_empty() else g.get("route")
		if loop != null and not loop.is_empty() and g.global_position.distance_to(run_node.player.global_position) > 60.0:
			walker = g
			break
	if walker == null:
		_check("a patrol to watch", false, "none far from the spawn")
	else:
		var start: Vector3 = walker.global_position
		var moved := 0.0
		for i in 120 * 8:
			await physics_frame
			moved = maxf(moved, start.distance_to(walker.global_position))
		_check("a patrol walks its loop (%.1f m)" % moved, moved > 6.0 and not walker.get("alerted"), walker.global_position)
	run_node.load_zone(4)
	_check("zone 5 is uncharted too, and different", run_node.zone_info.has("plan") and run_node.zone_info["plan"].seed_value != info["plan"].seed_value, "")
	run_node.load_zone(5)
	_check("then the titan fight", run_node.phase == run_node.Phase.ARENA, run_node.phase)
	run_node.queue_free()
	await process_frame


## The navigation map takes a few frames to pick up a fresh bake.
func _nav_synced(node: Node3D, near: Vector3) -> void:
	var map := node.get_world_3d().navigation_map
	for i in 300:
		await physics_frame
		if NavigationServer3D.map_get_closest_point(map, near).distance_to(near) < 3.0:
			return


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
