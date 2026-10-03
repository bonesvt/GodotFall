extends SceneTree
## Headless test for the Scrap Titan run loop.
## Run: godot --headless --path . -s res://tests/run_loop_test.gd

const TitanParts := preload("res://scripts/run/titan_parts.gd")
const ZoneBuilder := preload("res://scripts/run/zone_builder.gd")

const SEED := 1234

var run_node
var player
var failures := 0


func _initialize() -> void:
	# Hints go to their own settings file, so these runs never mark them seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = SEED
	run_node.start_in_hub = false
	run_node.armory_path = "user://test_run_armory.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(10)
	player = run_node.player
	_parts_checks()
	_generator_checks()

	# Zone 1 layout
	var info: Dictionary = run_node.zone_info
	_check("zone 1 loaded", run_node.run.zone == 0 and run_node.phase == run_node.Phase.ZONE, run_node.run.zone)
	_check("zone has two caches", info["caches"].size() == 2, info["caches"].size())
	_check("one cache is guarded", info["objectives"].size() == 1 and info["objectives"][0].cache.locked, info["objectives"].size())
	_check("zone has grunts", info["grunts"].size() >= 2, info["grunts"].size())
	_check("grunts hunt the pilot", info["grunts"].all(func(g): return g.target == player), "")
	_check("zone 1 is the forest", info.get("name", "") == "THE PINEWOODS" and info["checkpoints"].size() >= 5, info.get("name", ""))
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("forest grunts stand on something", floating.is_empty(), floating)
	var kinds: Array = info["routes"].map(func(r): return r["kind"])
	_check("forest has a loud, a quiet and a high route", kinds == ["loud", "quiet", "high"], kinds)
	var blockers: int = run_node.zone_root.get_children().filter(func(n): return n.is_in_group("sight_blocker")).size()
	_check("forest has tall grass to hide in, some of it blocking sight", info["stealth_cover"].size() >= 40 and blockers >= 15, [info["stealth_cover"].size(), blockers])

	# The hardest gaps the generator makes, flown by the pilot: sprint, jump at the edge, double jump.
	var jump: Vector2 = ZoneBuilder.GAPS["jump"]
	var climb: Vector2 = ZoneBuilder.GAPS["climb"]
	await _fly_gap("widest jump", jump.y, 0.5, 3.0, 30)
	await _fly_gap("widest climb", climb.y, ZoneBuilder.CLIMB_RISE, 3.0, 12)
	await _fly_gap("widest wallrun", ZoneBuilder.GAPS["wallrun"].y, 1.0, 3.0, 0, "wallrun")
	await _fly_gap("widest grapple", ZoneBuilder.GAPS["grapple"].y, 3.0, 3.0, 0, "grapple")
	await _forest_crossings()
	await _forest_flanks()

	# Open salvage, pick the first part
	var open_cache: Node3D = info["caches"][0] if not info["caches"][0].locked else info["caches"][1]
	await _use_cache(open_cache)
	_check("salvage pauses for the choice", run_node.phase == run_node.Phase.CHOOSING and paused, run_node.phase)
	_check("salvage offers three parts", run_node.offer.size() == 3, run_node.offer.size())
	var picked: Dictionary = run_node.offer[0]
	await _press("choice_1")
	await _ticks(2)
	_check("part installed", run_node.run.parts.get(picked["slot"]) == picked, run_node.run.parts.keys())
	_check("choice resumes the run", run_node.phase == run_node.Phase.ZONE and not paused and open_cache.opened, run_node.phase)

	# Guarded cache is locked until its squad is dead
	var objective: Node3D = info["objectives"][0]
	await _use_cache(objective.cache)
	_check("guarded cache stays locked", run_node.phase == run_node.Phase.ZONE and not objective.cache.opened, run_node.phase)
	_check("guard squad posted", objective.alive() >= 2, objective.alive())
	# The pilot is behind the squad, so they haven't noticed yet. One of them
	# spots the pilot and calls the rest in; they fight for a few seconds,
	# hold their cover and stay on the platform.
	for i in objective.grunts.size():
		objective.grunts[i].rng.seed = 11 + i  # their hit rolls are random; keep this deterministic
	objective.grunts[0].alert()
	_check("one guard's callout alerts the squad", objective.grunts.all(func(g): return g.alerted), "")
	await _ticks(600)
	var stayed: bool = objective.grunts.all(func(g): return g.alerted and g.global_position.distance_to(g.post) < g.leash + 0.6)
	_check("guards engage and hold their cover", stayed, objective.grunts.map(func(g): return g.global_position.distance_to(g.post)))
	_check("guards shoot the pilot", player.health < player.max_health or run_node.run.downs > 0, player.health)
	for g in objective.grunts:
		g.take_damage(1000.0, g.global_position)
	await _ticks(2)
	_check("clearing the guards unlocks the cache", objective.done and not objective.cache.locked, objective.alive())
	await _use_cache(objective.cache)
	await _press("choice_2")
	await _ticks(2)
	_check("second part installed", run_node.run.caches_opened == 2 and run_node.run.parts.size() >= 1, run_node.run.parts.size())

	# Getting gunned down costs integrity and respawns on a platform
	run_node.run.pilot_hp = 100
	run_node.run.downs = 0
	player.take_damage(1000.0)
	await _ticks(2)
	_check("downed costs integrity", run_node.run.pilot_hp == 75 and run_node.run.downs == 1 and player.health == player.max_health, run_node.run.pilot_hp)
	run_node.run.pilot_hp = 100

	# Falling into the ravine costs integrity and respawns at the last checkpoint
	_place(Vector3(0, run_node.kill_y() - 20.0, ZoneBuilder.ForestBuilder.RAVINE_Z))
	await _ticks(3)
	_check("fall costs integrity", run_node.run.pilot_hp == 75 and run_node.run.falls == 1, run_node.run.pilot_hp)
	_check("fall respawns above the ravine", player.global_position.y > run_node.kill_y() + 5.0, player.global_position)

	# Extract through the zones, taking a part from every cache
	for zone in range(0, 3):
		info = run_node.zone_info
		if zone > 0:
			await _laid_out_checks(zone)
		for cache in info["caches"]:
			if cache.opened:
				continue
			if cache.locked:
				for o in info["objectives"]:
					for g in o.grunts:
						g.take_damage(1000.0, g.global_position)
				await _ticks(2)
			await _use_cache(cache)
			await _press("choice_1")
			await _ticks(2)
		_place(info["beacon"].global_position + Vector3(0, 0.5, 0))
		await _ticks(3)
		_check("extract from zone %d" % (zone + 1), run_node.run.zone == zone + 1, run_node.run.zone)
	_check("arena after the last zone", run_node.phase == run_node.Phase.ARENA, run_node.phase)
	_check("six caches opened", run_node.run.caches_opened == 6, run_node.run.caches_opened)

	# Titanfall, embark, fight
	await _call_and_embark()
	var titan = run_node.titan
	var stats: Dictionary = run_node.run.titan_stats()
	_check("titan built from salvage", titan.max_hp == stats["hp"] and titan.stats["dps"] == stats["dps"], stats)
	_check("embark puts you in the titan", run_node.phase == run_node.Phase.FIGHT and titan.camera.current and not player.visible, run_node.phase)
	var boss = run_node.boss
	var hp0: float = boss.hp
	Input.action_press("titan_fire")
	await _ticks(60)
	_check("titan weapon damages the boss", boss.hp < hp0 - stats["dps"] * 0.3, boss.hp)
	var dashes: int = titan.dashes
	await _press("titan_dash")
	await _ticks(2)
	_check("titan dash", titan.dashes == dashes - 1 and titan.dash_timer > 0.0, titan.dashes)
	await _ticks(240)
	_check("boss fights back", titan.hp < titan.max_hp, titan.hp)
	boss.hp = 1.0
	await _ticks(120)  # the slowest gun (40mm Tracker) fires about every 0.4 s
	Input.action_release("titan_fire")
	_check("killing the boss opens the evac", run_node.phase == run_node.Phase.FIGHT and run_node.evac_open and run_node.zone_info["evac_node"].visible, run_node.phase)
	titan.global_position = run_node.zone_info["evac"] + Vector3(0, 0.5, 0)
	await _ticks(3)
	_check("titan on the evac pad completes the run", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)

	# New run
	await _press("run_restart")
	await _ticks(3)
	_check("restart starts a fresh run", run_node.phase == run_node.Phase.ZONE and run_node.run.zone == 0 and run_node.run.parts.is_empty() and player.visible, run_node.phase)

	# Losing: titan destroyed
	run_node.load_zone(3)
	await _call_and_embark()
	run_node.titan.take_damage(1.0e9)
	await _ticks(2)
	_check("titan destroyed ends the run", run_node.result == "TITAN DESTROYED", run_node.result)

	# Losing: pilot integrity runs out
	run_node.start_run(SEED)
	await _ticks(2)
	run_node.run.pilot_hp = 25
	_place(Vector3(0, -60, 0))
	await _ticks(3)
	_check("pilot KIA ends the run", run_node.result == "PILOT KIA", run_node.result)

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _parts_checks() -> void:
	var scrap := TitanParts.assemble({})
	_check("empty build is scrap", scrap["hp"] == 1500.0 and scrap["core"] == "none", scrap)
	var xo := TitanParts.make_part("weapon", TitanParts.CATALOG["weapon"][0], 3)
	_check("tier scales stats", is_equal_approx(xo["dps"], 390.0) and xo["display"] == "XO-16 Chaingun Mk III", xo["dps"])
	var plated := TitanParts.assemble({
		"chassis": TitanParts.make_part("chassis", TitanParts.CATALOG["chassis"][0], 1),
		"kit": TitanParts.make_part("kit", TitanParts.CATALOG["kit"][1], 1),
	})
	_check("kit modifies chassis", is_equal_approx(plated["hp"], 3000.0), plated["hp"])
	var rng := RandomNumberGenerator.new()
	var top_tier := 0
	for i in 200:
		rng.seed = i
		for part in TitanParts.roll_offer(rng, 0, 3):
			top_tier = maxi(top_tier, part["tier"])
	_check("zone 1 never rolls Mk III", top_tier == 2, top_tier)


func _generator_checks() -> void:
	var bad := []
	for s in range(1, 41):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for zone in range(1, 3):
			var tmp := Node3D.new()
			var info := ZoneBuilder.build_chain(tmp, rng, zone)
			for seg in info["segments"]:
				var limits: Vector2 = ZoneBuilder.GAPS[seg["type"]]
				if seg["gap"] < limits.x or seg["gap"] > limits.y:
					bad.append([s, zone, seg["type"], seg["gap"]])
				if seg["type"] == "jump" and seg["rise"] > 0.5:
					bad.append([s, zone, "jump rise", seg["rise"]])
			if info["caches"].size() != 2 or info["segments"].size() != 5 + zone:
				bad.append([s, zone, "layout"])
			for g in info["grunts"]:
				if not _on_a_platform(g.post, info["platforms"], 0.8):
					bad.append([s, zone, "grunt off platform", g.post])
			tmp.free()
	_check("generated gaps stay clearable, grunts stand on platforms", bad.is_empty(), bad)

	# Zones 1-3 are laid out by hand; their crossings still have to fit the movement.
	for zone in range(0, 3):
		bad = []
		var names := []
		for s in range(1, 7):
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			var tmp := Node3D.new()
			var info := ZoneBuilder.build_zone(tmp, rng, zone)
			names.append(info.get("name", ""))
			for seg in info["segments"]:
				var limits: Vector2 = ZoneBuilder.GAPS[seg["type"]]
				if seg["gap"] > limits.y or (seg["type"] == "jump" and seg["rise"] > 0.5):
					bad.append([s, seg])
			if info["caches"].size() != 2 or info["objectives"].size() != 1 or info["grunts"].size() < 6:
				bad.append([s, "layout", info["caches"].size(), info["objectives"].size(), info["grunts"].size()])
			var kinds: Array = info["routes"].map(func(r): return r["kind"])
			if kinds != ["loud", "quiet", "high"] or info["checkpoints"].size() < 8:
				bad.append([s, "routes", kinds, info["checkpoints"].size()])
			tmp.free()
		_check("zone %d (%s): crossings stay clearable, one guarded cache, three routes" % [zone + 1, names[0]], bad.is_empty(), bad)

	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var ta := Node3D.new()
	var tb := Node3D.new()
	var pa: Array = ZoneBuilder.build_chain(ta, a, 1)["platforms"]
	var pb: Array = ZoneBuilder.build_chain(tb, b, 1)["platforms"]
	_check("same seed, same zone", str(pa) == str(pb), pa.size())
	ta.free()
	tb.free()


func _ground_below(pos: Vector3, exclude: RID) -> bool:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos - Vector3(0, 1.0, 0))
	query.exclude = [exclude]
	return not run_node.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_a_platform(pos: Vector3, platforms: Array, margin: float) -> bool:
	for p in platforms:
		var top: Vector3 = p["top"]
		var size: Vector2 = p["size"]
		if absf(pos.x - top.x) < size.x * 0.5 - margin and absf(pos.z - top.z) < size.y * 0.5 - margin and absf(pos.y - top.y) < 0.5:
			return true
	return false


## Builds a gap like the generator's off to the side of the zone and flies the pilot over it.
func _fly_gap(what: String, gap: float, rise: float, drift: float, double_jump_after: int, kind := "jump") -> void:
	var holder := Node3D.new()
	run_node.add_child(holder)
	var Kit = load("res://scripts/run/level_kit.gd")
	var size := Vector2(8, 8)
	var to_size := Vector2(8, 12) if kind != "jump" else size
	var from := Vector3(400, 0, 0)
	var to := Vector3(from.x + drift, rise, from.z - size.y * 0.5 - gap - to_size.y * 0.5)
	Kit.box(holder, from - Vector3(0, 0.5, 0), Vector3(size.x, 1, size.y), Color.GRAY)
	Kit.box(holder, to - Vector3(0, 0.5, 0), Vector3(to_size.x, 1, to_size.y), Color.GRAY)
	var mid := Vector3((from.x + to.x) * 0.5, maxf(from.y, to.y), from.z - size.y * 0.5 - gap * 0.5)
	var anchor := Vector3(mid.x, mid.y + 10.0, from.z - size.y * 0.5 - gap * 0.6)
	if kind == "wallrun":
		Kit.box(holder, Vector3(mid.x - 4.5, mid.y, mid.z), Vector3(1, 12, gap), Color.BLUE)
	elif kind == "grapple":
		Kit.box(holder, anchor, Vector3(4, 2, 4), Color.ORANGE)
	await _ticks(2)
	var edge_z := from.z - size.y * 0.5
	var start := Vector3(from.x, 0.1, from.z + size.y * 0.5 - 0.5)
	var landed := await _cross(start, edge_z, to, to_size.y * 0.5, kind, mid.x - 4.5, anchor, double_jump_after, to.z + size.y * 0.5 + 2.0)
	_check("pilot clears the %s (%.1f m, rise %.1f)" % [what, gap, rise], landed, player.global_position)
	holder.queue_free()
	await _reset_after_flight()


## Zones 2 and 3 once loaded: what they're made of, and their crossings flown for real.
func _laid_out_checks(zone: int) -> void:
	var info: Dictionary = run_node.zone_info
	var B = ZoneBuilder.MarshBuilder if zone == 1 else ZoneBuilder.BoneyardBuilder
	_check("zone %d is %s" % [zone + 1, B.NAME], info.get("name", "") == B.NAME and run_node.run.zone == zone, info.get("name", ""))
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("%s: grunts stand on something" % B.NAME, floating.is_empty(), floating)
	var blockers: int = run_node.zone_root.get_children().filter(func(n): return n.is_in_group("sight_blocker")).size()
	_check("%s: places to hide, some blocking sight" % B.NAME, info["stealth_cover"].size() >= 40 and blockers >= 15, [info["stealth_cover"].size(), blockers])
	_check("%s: loot laid out" % B.NAME, info["loot"].size() >= 9, info["loot"].size())
	var deck_y: float = B.ROAD_Y if zone == 1 else 0.0
	var mid_z: float = (B.NEAR_LIP + B.FAR_LIP) * 0.5
	await _gap_crossings(B, mid_z, deck_y)
	# The quiet crossing: walk the drowned titan's back, or the fallen obelisk.
	var c: float = B.trail_x(mid_z)
	_place(B._on(c + B.LOG_X, B.NEAR_LIP + 8.0, 0.1))
	await _ticks(2)
	var ok: bool = await _walk(B._on(c + B.LOG_X, B.FAR_LIP - 8.0), func(p): return p.z < B.FAR_LIP - 4.0)
	_check("%s: walk the quiet crossing" % B.NAME, ok and run_node.run.falls == 0, player.global_position)
	await _reset_after_flight()


## A laid-out zone's gap (the forest's ravine, the marsh's channel, the
## Boneyard's rift) by its wallrun, grapple and stepping-stone routes.
func _gap_crossings(B, mid_z: float, deck_y: float) -> void:
	var c: float = B.trail_x(mid_z)
	var near_end: float = B.NEAR_LIP - B.BRIDGE_REACH
	var far_end: float = B.FAR_LIP + B.BRIDGE_REACH
	var far_deck := Vector3(c, deck_y, far_end - 5.0)
	var anchor := Vector3(c + B.ANCHOR_X, B.ANCHOR_Y, near_end - (near_end - far_end) * 0.6)
	var ok: bool = await _cross(Vector3(c, deck_y + 0.1, near_end + 8.0), near_end, far_deck, 5.0, "wallrun", c + B.SHIELD_X, Vector3.ZERO, 0, far_end)
	_check("%s: wallrun over the gap" % B.NAME, ok, player.global_position)
	await _reset_after_flight()
	ok = await _cross(Vector3(c + 2.0, deck_y + 0.1, near_end + 8.0), near_end, far_deck, 5.0, "grapple", 0.0, anchor, 0, far_end)
	_check("%s: grapple the crane over the gap" % B.NAME, ok, player.global_position)
	await _reset_after_flight()
	var px: float = c + B.PILLAR_X
	var hops := []
	var edge: float = B.NEAR_LIP
	for p in B.PILLARS:
		hops.append([edge, Vector3(px, p[1], p[0] - B.PILLAR * 0.5), B.PILLAR * 0.5])
		edge = p[0] - B.PILLAR
	hops.append([edge, B._on(px, B.FAR_LIP - 6.0), 5.0])
	_place(B._on(px, B.NEAR_LIP + 8.0, 0.1))
	player.rotation.y = 0.0
	await _ticks(2)
	ok = true
	for hop in hops:
		ok = ok and await _hop(hop[0], hop[1], hop[2])
	Input.action_release("move_forward")
	_check("%s: hop the stepping stones over the gap" % B.NAME, ok, player.global_position)
	await _reset_after_flight()


## The real ravine in zone 1, by each of its three routes.
func _forest_crossings() -> void:
	var FB = ZoneBuilder.ForestBuilder
	var c: float = FB.trail_x(FB.RAVINE_Z)
	var near_end: float = FB.NEAR_LIP - FB.BRIDGE_REACH
	var far_end: float = FB.FAR_LIP + FB.BRIDGE_REACH
	var far_deck := Vector3(c, 0.0, far_end - 5.0)
	var anchor := Vector3(c + FB.ANCHOR_X, FB.ANCHOR_Y, near_end - (near_end - far_end) * 0.6)
	var ok: bool = await _cross(Vector3(c, 0.1, near_end + 8.0), near_end, far_deck, 5.0, "wallrun", c + FB.SHIELD_X, Vector3.ZERO, 0, far_end)
	_check("forest: wallrun the blast shield over the ravine", ok, player.global_position)
	await _reset_after_flight()
	ok = await _cross(Vector3(c + 2.0, 0.1, near_end + 8.0), near_end, far_deck, 5.0, "grapple", 0.0, anchor, 0, far_end)
	_check("forest: grapple the crane over the ravine", ok, player.global_position)
	await _reset_after_flight()
	# Pillar hops: keep running, jump at each edge.
	var px: float = c + FB.PILLAR_X
	var hops := []
	var edge: float = FB.NEAR_LIP
	for p in FB.PILLARS:
		hops.append([edge, Vector3(px, p[1], p[0] - FB.PILLAR * 0.5), FB.PILLAR * 0.5])
		edge = p[0] - FB.PILLAR
	hops.append([edge, FB._on(px, FB.FAR_LIP - 6.0), 5.0])
	_place(FB._on(px, FB.NEAR_LIP + 8.0, 0.1))
	player.rotation.y = 0.0
	await _ticks(2)
	ok = true
	for hop in hops:
		ok = ok and await _hop(hop[0], hop[1], hop[2])
	Input.action_release("move_forward")
	_check("forest: hop the rock pillars over the ravine", ok, player.global_position)
	await _reset_after_flight()


## The flank routes' key moves: under the wall through the culvert, along the
## fallen pine over the ravine, and off the end of the ridge over the wall.
func _forest_flanks() -> void:
	var FB = ZoneBuilder.ForestBuilder
	var cw: float = FB.trail_x(FB.WALL_Z)
	var cr: float = FB.trail_x(FB.RAVINE_Z)
	_place(FB._on(FB.creek_x(-50.0), -50.0, 0.1))
	await _ticks(2)
	var ok: bool = await _walk(FB._on(cw + FB.CULVERT_X, FB.WALL_Z - 6.0), func(p): return p.z < FB.WALL_Z - 3.0)
	_check("forest: walk the creek through the culvert under the wall", ok, player.global_position)
	await _reset_after_flight()
	_place(FB._on(cr + FB.LOG_X, FB.NEAR_LIP + 8.0, 0.1))
	await _ticks(2)
	ok = await _walk(FB._on(cr + FB.LOG_X, FB.FAR_LIP - 8.0), func(p): return p.z < FB.FAR_LIP - 4.0)
	_check("forest: walk the fallen pine over the ravine", ok and run_node.run.falls == 0, player.global_position)
	await _reset_after_flight()
	_place(FB._on(FB.ridge_x(-46.0), -46.0, 0.1))
	await _ticks(2)
	var jumped := [false]
	ok = await _walk(FB._on(FB.ridge_x(FB.RIDGE_END), FB.WALL_Z - 8.0), func(p):
		if not jumped[0] and p.z < FB.RIDGE_END + 0.6:
			jumped[0] = true
			_press("jump")
			create_timer(0.15).timeout.connect(func(): _press("jump"))
		return p.z < FB.WALL_Z - 1.0 and player.is_on_floor())
	_check("forest: run the ridge and jump over the wall", ok and run_node.run.falls == 0, player.global_position)
	await _reset_after_flight()


## Holds forward toward `to` until done(position) is true, a fall, or a timeout.
func _walk(to: Vector3, done: Callable) -> bool:
	for i in 900:
		var err: Vector3 = to - player.global_position
		err.y = 0.0
		if err.length() > 0.5:
			player.rotation.y = atan2(-err.x, -err.z)
		Input.action_press("move_forward")
		await _ticks(1)
		if done.call(player.global_position):
			Input.action_release("move_forward")
			return true
		if run_node.run.falls > 0:
			break
	Input.action_release("move_forward")
	return false


## Runs forward from where the pilot stands, jumps at edge_z, lands on `to`.
func _hop(edge_z: float, to: Vector3, half_z: float) -> bool:
	var jumped := false
	for i in 360:
		var err: Vector3 = to - player.global_position
		err.y = 0.0
		player.rotation.y = atan2(-err.x, -err.z) if err.length() > 0.5 else player.rotation.y
		Input.action_press("move_forward")
		if not jumped and player.is_on_floor() and player.global_position.z < edge_z + 0.6:
			await _press("jump")
			jumped = true
		await _ticks(1)
		var p: Vector3 = player.global_position
		if jumped and player.is_on_floor() and absf(p.y - to.y) < 0.4 and absf(p.z - to.z) < half_z + 0.3:
			return true
		if p.y < -6.0:
			return false
	return false


## Flies the pilot from `start` over a gap that begins at edge_z onto `to`.
## kind is jump, wallrun (along a wall at wall_x, kicking off at kick_z) or grapple (to `anchor`).
func _cross(start: Vector3, edge_z: float, to: Vector3, to_half_z: float, kind: String, wall_x: float, anchor: Vector3, double_jump_after: int, kick_z := 0.0) -> bool:
	_place(start)
	await _ticks(2)
	var aim := Vector3(to.x, start.y, edge_z) - start
	if kind == "wallrun":
		aim = Vector3(wall_x + 0.5, start.y, edge_z - 3.0) - start  # run at the wall
	player.rotation.y = atan2(-aim.x, -aim.z)
	Input.action_press("move_forward")
	for i in 240:
		await _ticks(1)
		if player.global_position.z < edge_z + 0.4:
			break
	match kind:
		"jump":
			await _press("jump")
			await _ticks(double_jump_after)
			await _press("jump")
		"wallrun":
			# Jump at the wall, run along it, kick off near the end.
			await _press("jump")
			for i in 90:
				await _ticks(1)
				if player.state_name() == "WALLRUN":
					break
			_check("wallrun gap: pilot reaches the wall", player.state_name() == "WALLRUN", player.state_name())
			player.rotation.y = 0.0
			for i in 240:
				await _ticks(1)
				if player.state_name() != "WALLRUN" or player.global_position.z < kick_z:
					break
			await _press("jump")
			await _ticks(20)
			await _press("jump")
		"grapple":
			# Look at the anchor, reel in, let go past it and double jump forward.
			await _press("jump")
			var look: Vector3 = anchor - player.get_node("Head/Camera3D").global_position
			player.rotation.y = atan2(-look.x, -look.z)
			player.get_node("Head").rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
			Input.action_press("grapple")
			await _ticks(3)
			_check("grapple gap: hook reaches the anchor", player.state_name() == "GRAPPLE", player.state_name())
			for i in 240:
				await _ticks(1)
				if player.state_name() != "GRAPPLE":
					break
			Input.action_release("grapple")
			var ahead: Vector3 = to - player.global_position
			player.rotation.y = atan2(-ahead.x, -ahead.z)
			player.get_node("Head").rotation.x = 0.0
			await _press("jump")
	# Steer onto the platform like a player would: air-strafe toward its middle.
	for i in 300:
		await _ticks(1)
		var err: Vector3 = to - player.global_position
		err.y = 0.0
		if err.length() > 1.0:
			player.rotation.y = atan2(-err.x, -err.z)
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		if OS.get_environment("RUN_TEST_DEBUG") != "" and i % 10 == 0:
			print("  ", i, " ", player.state_name(), " ", player.global_position, " ", player.velocity)
		var p: Vector3 = player.global_position
		if player.is_on_floor() and absf(p.y - to.y) < 0.3 and absf(p.z - to.z) < to_half_z + 0.4:
			Input.action_release("move_forward")
			return true
	Input.action_release("move_forward")
	return false


func _reset_after_flight() -> void:
	_place(run_node.zone_info["spawn"])
	run_node.run.pilot_hp = 100
	run_node.run.falls = 0
	await _ticks(2)


func _call_and_embark() -> void:
	_place(run_node.zone_info["spawn"])
	await _ticks(2)
	await _press("titan_core")
	await _ticks(2)
	var titan = run_node.titan
	for i in 240:
		await _ticks(1)
		if not titan.dropping:
			break
	_check("titan lands", not titan.dropping and titan.global_position.y < 0.5, titan.global_position)
	_place(titan.global_position + Vector3(3, 0.1, 0))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)


func _use_cache(cache: Node3D) -> void:
	_place(cache.global_position + Vector3(0, 0.1, 1.5))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)


func _place(pos: Vector3) -> void:
	for a in ["move_forward", "crouch", "jump", "grapple", "interact"]:
		Input.action_release(a)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.AIR


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
