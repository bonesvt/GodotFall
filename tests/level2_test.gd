extends SceneTree
## Headless test for Level 2 (levels.gd "level2", The Glass District), where
## Eco gets Ophelia out of the colony's holding block.
## Run: godot --headless --path . -s res://tests/level2_test.gd
## Plans many seeds and checks each is a city level with one holding block
## and the clearing last; builds one and checks the cell, Ophelia in it, the
## city kit round it and no salvage depot; then plays it: the board stays
## locked until Level 1 is cleared, the screen holds while its guards are up,
## the clearing won't start the titan fight until she's out, the screen drops
## once they're down, she runs for the evac and is waiting there when their
## titan falls, and the evac clears the level.

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
	_check("level 2 needs level 1, rescues Ophelia", spec["needs"] == "level1" and spec["rescue"] == "ophelia" and Levels.ORDER == ["level1", "level2"], spec.get("needs", ""))
	var bad := []
	for s in range(1, 41):
		var plan = LevelPlan.make_level(s, spec)
		var kinds: Array = plan.sections.map(func(x): return x["kind"])
		if plan.zone_name != "THE GLASS DISTRICT" or plan.biome != "city":
			bad.append([s, "name/biome", plan.zone_name, plan.biome])
		if kinds.count("holding") != 1 or "depot" in kinds or kinds[-1] != "finale" or "end" in kinds:
			bad.append([s, "sections", kinds])
		var i: int = kinds.find("holding")
		if i >= 0 and (kinds[i - 1] in LevelPlan.YARDS or kinds[i + 1] in LevelPlan.YARDS):
			bad.append([s, "yards side by side", kinds])
	_check("40 level plans: The Glass District, city, one holding block, the clearing last", bad.is_empty(), bad.slice(0, 6))


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
	_check("a holding cell, no depot, a clearing with their titan and an evac", info.has("holding_cell") and not info.has("depot_cache") and info.has("boss") and info.has("evac_node"), info.keys())
	var city: Array = info["set_pieces"].filter(func(p): return String(p["id"]).begins_with("city_"))
	_check("built from the city kit (%d pieces)" % city.size(), city.size() >= 10, city.size())
	var cell: Node3D = info["holding_cell"]
	var oph: Node3D = cell.ophelia
	_check("Ophelia's in the cell, sat on the floor", oph != null and oph.visible and oph.who == "ophelia" and oph.posed, oph)
	var floating := []
	for g in info["grunts"]:
		if not _ground_below(g.post, g.get_rid()):
			floating.append(g.post)
	_check("%d grunts, all standing on something" % info["grunts"].size(), info["grunts"].size() >= 14 and floating.is_empty(), floating)
	_check("calm radio gossips about the prisoner", run_node.pilot_hud.radio.extra_rumor == "prisoner", run_node.pilot_hud.radio.extra_rumor)

	# The screen holds while the squad is up.
	var objective = info["objectives"].filter(func(o): return o.cache == cell)[0]
	_check("holding squad of at least 5 guards her", cell.locked and objective.alive() >= 5, objective.alive())
	await _use_cell(cell)
	_check("screen holds with guards up", not cell.opened and run_node.rescue_pending() and run_node.hud.toast_label.text.contains("LOCKED"), run_node.hud.toast_label.text)
	var screen := _screen_blocks(cell)
	_check("the screen is solid", screen, screen)

	# The clearing won't start without her.
	var arena: Dictionary = info["arena"]
	var into: Vector3 = arena["center"] + Vector3(0, 1.0, 0)
	_place(Vector3(into.x, into.y, arena["enter_z"] - 4.0))
	await _ticks(3)
	_check("no titan fight while she's still inside", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("Not leaving without Ophelia"), [run_node.phase, run_node.hud.toast_label.text])

	for g in objective.grunts:
		if is_instance_valid(g) and not g.dead:
			g.take_damage(9999.0, g.global_position)
	await _ticks(3)
	await _use_cell(cell)
	_check("screen drops once the squad's down", cell.opened and run_node.rescued and not run_node.rescue_pending(), cell.opened)
	_check("the way in is open", not _screen_blocks(cell), cell.opened)
	_check("she stands up and they talk", not oph.posed and run_node.hud.toast_label.text.begins_with("OPHELIA"), run_node.hud.toast_label.text)
	_check("radio stops gossiping about her", run_node.pilot_hud.radio.extra_rumor == "", run_node.pilot_hud.radio.extra_rumor)
	var talk: float = Levels.spec("level2")["rescue_lines"].size() * 3.4 + 2.0
	await _ticks(int(talk * Engine.physics_ticks_per_second) + 10)
	_check("then she runs for the evac, out of sight", not oph.visible and run_node.hud.toast_label.text.contains("MAKING FOR THE EVAC"), [oph.visible, run_node.hud.toast_label.text])

	# Now the clearing: titanfall, their titan down, she's at the pad.
	_place(Vector3(into.x, into.y, arena["enter_z"] - 4.0))
	await _ticks(3)
	_check("walking into the clearing starts the titan fight now", run_node.phase == run_node.Phase.ARENA, run_node.phase)
	await _press("titan_core")
	await _ticks(2)
	var titan = run_node.titan
	_check("titan called", titan != null, titan)
	if titan == null:
		return
	for i in 300:
		await _ticks(1)
		if not titan.dropping:
			break
	_place(titan.global_position + Vector3(3, 0.5, 0))
	await _ticks(2)
	await _press("interact")
	await _ticks(2)
	_check("embark", run_node.phase == run_node.Phase.FIGHT, run_node.phase)
	var boss: Node3D = info["boss"]
	boss.active = true
	boss.take_damage(boss.hp + 1.0)
	await _ticks(3)
	var pad: Vector3 = info["evac"]
	_check("their titan down: evac open, Ophelia waiting at the pad", run_node.evac_open and oph.visible and oph.global_position.distance_to(pad) < 8.0
			and run_node.hud.toast_label.text.contains("OPHELIA'S AT THE EVAC PAD"), [oph.global_position, pad])
	titan.global_position = pad + Vector3(0, 0.5, 0)
	await _ticks(3)
	_check("evac completes the level with her", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
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
