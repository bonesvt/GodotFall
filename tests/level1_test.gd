extends SceneTree
## Headless test for the first real level (levels.gd "level1", The Deepwood).
## Run: godot --headless --path . -s res://tests/level1_test.gd
## Plans many seeds and checks each has the level's beats (the salvage depot,
## the titan clearing at the end, forest, its name); builds one and checks the
## depot crate, the boss, the evac and that no Choir or wildlife got in; then
## plays it: the hub board is locked until the tutorial run is won, opens a
## level run, the depot crate stays shut until its squad is down and offers
## top grade parts, walking into the clearing starts the titan fight, and the
## evac completes the level and marks it cleared.

const Levels := preload("res://scripts/run/levels.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")

var failures := 0
var run_node
var player


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	_plan_checks()
	await _play_checks()
	print("level1 test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _plan_checks() -> void:
	var spec := Levels.spec("level1")
	var bad := []
	var lanes := {}
	for s in range(1, 41):
		var plan = LevelPlan.make_level(s, spec)
		lanes[plan.lanes.size()] = true
		var kinds: Array = plan.sections.map(func(x): return x["kind"])
		if plan.zone_name != "THE DEEPWOOD" or plan.biome != "forest":
			bad.append([s, "name/biome", plan.zone_name, plan.biome])
		if kinds.count("depot") != 1 or kinds[-1] != "finale" or "end" in kinds:
			bad.append([s, "sections", kinds])
		for need in ["start", "outpost", "camp", "wall", "chasm"]:
			if not need in kinds:
				bad.append([s, "missing", need])
		var depot: Dictionary = plan.sections_of("depot")[0]
		if depot.get("cache", "") != "guarded":
			bad.append([s, "depot cache", depot.get("cache", "")])
		# The clearing is flat from where the fight starts to the far end, wall to wall.
		var f: Dictionary = plan.finale()
		var z: float = f["z0"] - 16.0
		var lumpy := 0.0
		while z > f["z1"] + 4.0:
			var x: float = plan.center_x(f["mid"]) - plan.half_width(z) + 6.0
			while x < plan.center_x(f["mid"]) + plan.half_width(z) - 6.0:
				lumpy = maxf(lumpy, absf(plan.ground(x, z) - f["level"]))
				x += 4.0
			z -= 4.0
		if lumpy > 0.35:
			bad.append([s, "clearing not flat", lumpy])
		if f["level"] < plan.kill_y + 3.0:
			bad.append([s, "clearing below kill height"])
	_check("40 level plans: The Deepwood, forest, one guarded depot, the clearing last and flat", bad.is_empty(), bad.slice(0, 6))
	_check("level plans still use 3 to 5 lanes", lanes.size() == 3, lanes.keys())
	_check("same seed, same level", LevelPlan.make_level(9, spec).describe() == LevelPlan.make_level(9, spec).describe()
			and LevelPlan.make_level(9, spec).describe() != LevelPlan.make_level(10, spec).describe(), LevelPlan.make_level(9, spec).describe())


func _play_checks() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 5150
	run_node.armory_path = "user://test_level1_armory.cfg"
	run_node.npc_path = "user://test_level1_npcs.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.npc_path))
	root.add_child(run_node)
	await _ticks(5)
	player = run_node.player
	run_node.tutorial.set_enabled(false)

	# The hub's level board: locked on a fresh save, open once the tutorial run is won.
	_check("game opens in the hub with a level board", run_node.phase == run_node.Phase.HUB and run_node.zone_info.has("level_board"), run_node.phase)
	var spot: Dictionary = run_node.zone_info["interactables"].filter(func(i): return i["id"] == "level_board")[0]
	_check("board locked on a fresh save", spot["prompt"].contains("first") and run_node.zone_info["level_board"]["label"].text.contains("locked"), spot["prompt"])
	await _use_spot(spot)
	_check("locked board doesn't start a run", run_node.phase == run_node.Phase.HUB, run_node.phase)
	run_node.armory.mark_cleared("tutorial")
	run_node.dress_hub()
	_check("board opens once the tutorial run is won", spot["prompt"].contains("LEVEL 1: THE DEEPWOOD"), spot["prompt"])
	await _use_spot(spot)
	_check("board starts a level run", run_node.phase == run_node.Phase.ZONE and run_node.run.level == "level1" and run_node.run.zone_count == 1, [run_node.phase, run_node.run.level])
	run_node.tutorial.set_enabled(false)

	var info: Dictionary = run_node.zone_info
	_check("it's The Deepwood, generated", info.get("name", "") == "THE DEEPWOOD" and info.has("plan") and run_node.hud.toast_label.text.contains("LEVEL 1"), [info.get("name", ""), run_node.hud.toast_label.text])
	_check("no beacon, a clearing with their titan and an evac", info["beacon"] == null and info.has("arena") and info.has("boss") and info.has("evac_node"), info.keys())
	_check("grunts only: no Choir or wildlife", not info.has("threat_counts") and info.get("wildlife", []).is_empty(), info.get("threat_counts", {}))
	_check("three caches: outpost, camp and the depot's titan part", info["caches"].size() == 3 and info.has("depot_cache"), info["caches"].size())
	var arena: Dictionary = info["arena"]
	var boss: Node3D = info["boss"]
	var r: Rect2 = arena["rect"]
	_check("boss and evac stand in the clearing", r.has_point(Vector2(boss.position.x, boss.position.z)) and r.has_point(Vector2(info["evac"].x, info["evac"].z)), [r, boss.position, info["evac"]])
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("%d grunts, all standing on something" % info["grunts"].size(), info["grunts"].size() >= 14 and floating.is_empty(), floating)

	# The depot: locked behind its squad (bigger than the yards'), then a top grade offer.
	var crate: Node3D = info["depot_cache"]
	var objective = info["objectives"].filter(func(o): return o.cache == crate)[0]
	_check("depot squad of at least 4 guards the part", crate.locked and objective.alive() >= 4, objective.alive())
	await _use_cache(crate)
	_check("depot crate stays locked with guards up", run_node.phase == run_node.Phase.ZONE and not crate.opened, run_node.phase)
	for g in objective.grunts:
		if is_instance_valid(g) and not g.dead:
			g.take_damage(9999.0, g.global_position)
	await _ticks(3)
	await _use_cache(crate)
	_check("depot opens once its squad is down", run_node.phase == run_node.Phase.CHOOSING, run_node.phase)
	var tiers: Array = run_node.offer.map(func(p): return p["tier"])
	_check("the depot's parts are top grade", tiers.size() == 3 and tiers.all(func(t): return t == 3), tiers)
	await _press("choice_1")
	await _ticks(2)
	_check("part installed, run goes on", run_node.phase == run_node.Phase.ZONE and crate.opened and run_node.run.parts.size() > 0, run_node.phase)

	# Out into the clearing: titanfall.
	var into: Vector3 = arena["center"] + Vector3(0, 1.0, 0)
	_place(Vector3(into.x, into.y, arena["enter_z"] - 4.0))
	await _ticks(3)
	_check("walking into the clearing starts the titan fight", run_node.phase == run_node.Phase.ARENA and run_node.boss == boss, run_node.phase)
	await _press("titan_core")
	await _ticks(2)
	var titan = run_node.titan
	_check("titan called", titan != null, titan)
	if titan == null:
		return
	var drop := Vector2(titan.global_position.x, titan.global_position.z)
	_check("titan drops inside the clearing", r.has_point(drop), drop)
	for i in 300:
		await _ticks(1)
		if not titan.dropping:
			break
	_check("titan lands on the clearing floor", not titan.dropping and absf(titan.global_position.y - into.y) < 2.0, titan.global_position)
	_place(titan.global_position + Vector3(3, 0.5, 0))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)
	_check("embark", run_node.phase == run_node.Phase.FIGHT, run_node.phase)
	boss.active = true
	boss.take_damage(boss.hp + 1.0)
	await _ticks(3)
	_check("their titan down opens the evac", run_node.evac_open and info["evac_node"].visible, run_node.evac_open)
	titan.global_position = info["evac"] + Vector3(0, 0.5, 0)
	await _ticks(3)
	_check("evac completes the level", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
	_check("level 1 marked cleared and saved", "level1" in run_node.armory.cleared and "level1" in load("res://scripts/hub/armory.gd").open(run_node.armory_path).cleared, run_node.armory.cleared)
	await _press("run_restart")
	await _ticks(3)
	_check("back to the temple", run_node.phase == run_node.Phase.HUB, run_node.phase)


func _use_spot(spot: Dictionary) -> void:
	_place(spot["pos"] + Vector3(0, 0.2, 0.6))
	await _ticks(2)
	await _press("interact")
	await _ticks(3)


func _use_cache(cache: Node3D) -> void:
	_place(cache.global_position + Vector3(0, 0.3, 1.5))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "interact"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


func _ground_below(pos: Vector3, skip: RID) -> bool:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.5, 0), 1)
	q.exclude = [skip]
	return not run_node.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _press(action: String) -> void:
	await physics_frame
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
