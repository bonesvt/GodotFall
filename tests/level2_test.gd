extends SceneTree
## Headless test for Level 2 (levels.gd "level2", The Glass District): a
## night stealth run where Eco gets Ophelia out of the colony's holding block.
## Run: godot --headless --path . -s res://tests/level2_test.gd
## Plans many seeds and checks each is a city level with the holding block
## last and no titan clearing; builds one and checks the night (grunts with
## torches and shorter sight), the exfil back at the spawn, the cell with
## Ophelia chained inside in her prison rags; then plays it: the board stays
## locked until Level 1 is cleared, the exfil does nothing without her, F at
## the screen breaks her chains and she follows Eco, crouches with her, waits
## when told, grunts can spot her, and walking into the exfil with her close
## clears the level.

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
	print("level2 test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _plan_checks() -> void:
	var spec := Levels.spec("level2")
	_check("level 2 needs level 1, rescues Ophelia at night", spec["needs"] == "level1" and spec["rescue"] == "ophelia" and spec["night"] and Levels.ORDER == ["level1", "level2"], spec.get("needs", ""))
	var bad := []
	for s in range(1, 41):
		var plan = LevelPlan.make_level(s, spec)
		var kinds: Array = plan.sections.map(func(x): return x["kind"])
		if plan.zone_name != "THE GLASS DISTRICT" or plan.biome != "city":
			bad.append([s, "name/biome", plan.zone_name, plan.biome])
		if kinds.count("holding") != 1 or kinds[-2] != "holding" or kinds[-1] != "end" or "finale" in kinds or "depot" in kinds:
			bad.append([s, "sections", kinds])
		if kinds[-3] in LevelPlan.YARDS:
			bad.append([s, "yards side by side", kinds])
	_check("40 level plans: The Glass District, city, the holding block last, no clearing", bad.is_empty(), bad.slice(0, 6))


func _play_checks() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4242
	run_node.armory_path = "user://test_level2_armory.cfg"
	run_node.npc_path = "user://test_level2_npcs.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.armory_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_node.npc_path))
	root.add_child(run_node)
	await _ticks(5)
	player = run_node.player
	run_node.tutorial.set_enabled(false)

	# The mission table's Level 2 pin: locked until Level 1 is cleared.
	var spot: Dictionary = run_node.zone_info["interactables"].filter(func(i): return i.get("level", "") == "level2")[0]
	run_node.armory.mark_cleared("tutorial")
	run_node.dress_hub()
	_check("level 2 locked with only the tutorial won", spot["prompt"].contains("clear LEVEL 1") and run_node.zone_info["level_boards"][1]["label"].text.contains("locked"), spot["prompt"])
	await _use_spot(spot)
	_check("locked board doesn't start a run", run_node.phase == run_node.Phase.HUB, run_node.phase)
	run_node.armory.mark_cleared("level1")
	run_node.dress_hub()
	_check("level 2 opens once level 1 is cleared", spot["prompt"].contains("LEVEL 2: THE GLASS DISTRICT"), spot["prompt"])
	await _use_spot(spot)
	_check("board starts the level 2 run", run_node.phase == run_node.Phase.ZONE and run_node.run.level == "level2", [run_node.phase, run_node.run.level])
	run_node.tutorial.set_enabled(false)

	var info: Dictionary = run_node.zone_info
	_check("it's The Glass District, in the city", info.get("name", "") == "THE GLASS DISTRICT" and info["plan"].biome == "city" and run_node.hud.toast_label.text.contains("LEVEL 2"), info.get("name", ""))
	_check("a holding cell, no depot, no titan clearing", info.has("holding_cell") and not info.has("depot_cache") and not info.has("boss") and not info.has("arena"), info.keys())
	var beacon: Node3D = info["beacon"]
	_check("the exfil is back by the spawn", beacon != null and beacon.global_position.distance_to(info["spawn"]) < 10.0, beacon.global_position if beacon else null)
	var city: Array = info["set_pieces"].filter(func(p): return String(p["id"]).begins_with("city_"))
	_check("built from the city kit (%d pieces)" % city.size(), city.size() >= 10, city.size())
	var g0: Node = info["grunts"][0]
	_check("night: grunts carry torches and see less far", g0.get_node_or_null("Torch") != null and g0.sight_range < 40.0, g0.sight_range)
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("%d grunts, all standing on something" % info["grunts"].size(), info["grunts"].size() >= 14 and floating.is_empty(), floating)
	var cell: Node3D = info["holding_cell"]
	var oph: Node3D = cell.ophelia
	await _ticks(3)
	_check("Ophelia's in the cell in her prison rags, chained", oph != null and oph.who == "ophelia" and oph.outfit == "prison" and oph.posed and cell._chains.size() == 2, [oph.outfit, cell._chains.size()])
	_check("calm radio gossips about the prisoner", run_node.pilot_hud.radio.extra_rumor == "prisoner", run_node.pilot_hud.radio.extra_rumor)
	_check("the screen is solid", _screen_blocks(cell), true)

	# The exfil does nothing without her.
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("exfil without her doesn't end the run", run_node.phase == run_node.Phase.ZONE, run_node.phase)

	# Into the cell: chains off, she follows.
	await _use_cell(cell)
	_check("F breaks her out", cell.opened and run_node.rescued and cell._chains.is_empty() and not _screen_blocks(cell), cell.opened)
	_check("they talk", run_node.hud.toast_label.text.begins_with("OPHELIA"), run_node.hud.toast_label.text)
	_check("radio stops gossiping about her", run_node.pilot_hud.radio.extra_rumor == "", run_node.pilot_hud.radio.extra_rumor)
	var escort = run_node.escort
	_check("she's following", escort != null and escort.npc == oph and not escort.waiting, escort)
	if escort == null:
		return
	# Walk off up the street: she comes after. (Grunts held passive for this,
	# so nobody shoots Eco back to a checkpoint mid-check.)
	for g in info["grunts"]:
		g.passive = true
		g.alerted = false
	var away: Vector3 = cell.global_transform * Vector3(0, 0.5, 12.0)
	_place(away)
	var start := oph.global_position.distance_to(player.global_position)
	await _ticks(int(6.0 * Engine.physics_ticks_per_second))
	var now := oph.global_position.distance_to(player.global_position)
	_check("she catches up (%.1f m -> %.1f m)" % [start, now], now < 5.0 and now < start, [start, now])
	Input.action_press("crouch")
	await _ticks(4)
	_check("she crouches when Eco does", escort.crouched, escort.crouched)
	Input.action_release("crouch")
	await _ticks(4)
	# Told to wait, she stays put.
	_place(oph.global_position + Vector3(0, 0.3, 1.5))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)
	_check("[F] by her: she waits", escort.waiting and run_node.hud.toast_label.text.begins_with("OPHELIA"), run_node.hud.toast_label.text)
	var held := oph.global_position
	_place(held + Vector3(12, 0.5, 0))
	await _ticks(int(2.0 * Engine.physics_ticks_per_second))
	_check("waiting, she stays put", oph.global_position.distance_to(held) < 0.5, oph.global_position.distance_to(held))
	# A grunt looking right at her notices her.
	var watcher: Node = null
	var spot_at := Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = run_node.get_world_3d().direct_space_state
	for g in info["grunts"]:
		if g.dead or g.patrol.size() >= 2:
			continue
		var ahead: Vector3 = -g.global_basis.z
		ahead.y = 0.0
		var at: Vector3 = g.global_position + ahead.normalized() * 5.0
		var q := PhysicsRayQueryParameters3D.create(g.global_position + g.EYE, at + Vector3.UP * 0.6, 1 | g.SIGHT_LAYER)
		q.exclude = [g.get_rid(), player.get_rid()]
		if space.intersect_ray(q).is_empty():
			watcher = g
			spot_at = at
			break
	watcher.passive = false
	var fwd: Vector3 = -watcher.global_basis.z
	fwd.y = 0.0
	oph.global_position = spot_at
	_place(watcher.global_position - fwd.normalized() * 30.0 + Vector3(0, 40, 0))
	watcher.detection = 0.0
	await _ticks(int(1.5 * Engine.physics_ticks_per_second))
	_check("a grunt facing her picks her up (%.2f)" % watcher.detection, watcher.detection > 0.15 or watcher.alerted, watcher.detection)

	# Out through the exfil together.
	escort.waiting = false
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	oph.global_position = beacon.global_position + Vector3(30, 0, 0)
	escort.set_physics_process(false)
	await _ticks(3)
	_check("exfil with her far behind doesn't end it", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("Not without Ophelia"), run_node.hud.toast_label.text)
	oph.global_position = beacon.global_position + Vector3(2, 0, 2)
	await _ticks(3)
	_check("exfil with her close clears the level", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
	_check("level 2 marked cleared and saved", "level2" in load("res://scripts/hub/armory.gd").open(run_node.armory_path).cleared, run_node.armory.cleared)
	await _press("run_restart")
	await _ticks(3)
	_check("back to the temple", run_node.phase == run_node.Phase.HUB, run_node.phase)


## Whether a ray from the street into the cell stops at the screen.
func _screen_blocks(cell: Node3D) -> bool:
	var from := cell.global_transform * Vector3(0, 1.2, 1.5)
	var to := cell.global_transform * Vector3(0, 1.2, -1.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = run_node.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and (cell.global_transform.affine_inverse() * hit["position"]).z > -0.3


func _use_spot(spot: Dictionary) -> void:
	_place(spot["pos"] + Vector3(0, 0.2, 0.3))
	await _ticks(2)
	await _press("interact")
	await _ticks(3)


func _use_cell(cell: Node3D) -> void:
	_place(cell.global_transform * Vector3(0, 0.3, 1.6))
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
