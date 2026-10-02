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
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = SEED
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

	# The hardest gaps the generator makes, flown by the pilot: sprint, jump at the edge, double jump.
	var jump: Vector2 = ZoneBuilder.GAPS["jump"]
	var climb: Vector2 = ZoneBuilder.GAPS["climb"]
	await _fly_gap("widest jump", jump.y, 0.5, 3.0, 30)
	await _fly_gap("widest climb", climb.y, ZoneBuilder.CLIMB_RISE, 3.0, 12)
	await _fly_gap("widest wallrun", ZoneBuilder.GAPS["wallrun"].y, 1.0, 3.0, 0, "wallrun")
	await _fly_gap("widest grapple", ZoneBuilder.GAPS["grapple"].y, 3.0, 3.0, 0, "grapple")

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

	# Guarded cache is locked until the uplink is held
	var objective: Node3D = info["objectives"][0]
	await _use_cache(objective.cache)
	_check("guarded cache stays locked", run_node.phase == run_node.Phase.ZONE and not objective.cache.opened, run_node.phase)
	_place(objective.global_position + Vector3(0, 0.1, 0))
	await _ticks(int((objective.hold_time + 0.5) * 120.0))
	_check("holding the uplink unlocks the cache", objective.done and not objective.cache.locked, objective.progress)
	await _use_cache(objective.cache)
	await _press("choice_2")
	await _ticks(2)
	_check("second part installed", run_node.run.caches_opened == 2 and run_node.run.parts.size() >= 1, run_node.run.parts.size())

	# Falling costs integrity and respawns on a platform
	_place(Vector3(0, float(info["floor_y"]) - 30.0, 0))
	await _ticks(3)
	_check("fall costs integrity", run_node.run.pilot_hp == 75 and run_node.run.falls == 1, run_node.run.pilot_hp)
	_check("fall respawns above the void", player.global_position.y > float(info["floor_y"]) - 1.0, player.global_position)

	# Extract through the zones, taking a part from every cache
	for zone in range(0, 3):
		info = run_node.zone_info
		for cache in info["caches"]:
			if cache.opened:
				continue
			if cache.locked:
				for o in info["objectives"]:
					o.progress = o.hold_time
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
	await _ticks(10)
	Input.action_release("titan_fire")
	_check("killing the boss completes the run", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)

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
		for zone in 3:
			var tmp := Node3D.new()
			var info := ZoneBuilder.build_zone(tmp, rng, zone)
			for seg in info["segments"]:
				var limits: Vector2 = ZoneBuilder.GAPS[seg["type"]]
				if seg["gap"] < limits.x or seg["gap"] > limits.y:
					bad.append([s, zone, seg["type"], seg["gap"]])
				if seg["type"] == "jump" and seg["rise"] > 0.5:
					bad.append([s, zone, "jump rise", seg["rise"]])
			if info["caches"].size() != 2 or info["segments"].size() != 5 + zone:
				bad.append([s, zone, "layout"])
			tmp.free()
	_check("generated gaps stay clearable", bad.is_empty(), bad)

	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var ta := Node3D.new()
	var tb := Node3D.new()
	var pa: Array = ZoneBuilder.build_zone(ta, a, 1)["platforms"]
	var pb: Array = ZoneBuilder.build_zone(tb, b, 1)["platforms"]
	_check("same seed, same zone", str(pa) == str(pb), pa.size())
	ta.free()
	tb.free()


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
	_place(start)
	var aim := Vector3(to.x, 0.0, edge_z) - start
	if kind == "wallrun":
		aim = Vector3(mid.x - 4.0, 0.0, edge_z - 3.0) - start  # run at the wall
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
				if player.state_name() != "WALLRUN" or player.global_position.z < to.z + size.y * 0.5 + 2.0:
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
	var landed := false
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
		if player.is_on_floor() and absf(p.y - to.y) < 0.3 and absf(p.z - to.z) < to_size.y * 0.5 + 0.4:
			landed = true
			break
	Input.action_release("move_forward")
	_check("pilot clears the %s (%.1f m, rise %.1f)" % [what, gap, rise], landed, player.global_position)
	holder.queue_free()
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
