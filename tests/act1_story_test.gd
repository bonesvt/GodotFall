extends SceneTree
## Headless test for the act 1 story levels (levels.gd "level3" Blackwater
## Line and "level4" The Boneyard, their set pieces in scripts/run/story/).
## Run: godot --headless --path . -s res://tests/act1_story_test.gd
## Plans many seeds of each and checks the biome and the story yard last;
## then plays them:
##   Blackwater, clean: the beacon won't let her go until the fuel line's cut
##     and the sealed crates are burned, then it clears the level.
##   Blackwater, hooked on Marrow: his voice at the crates; leaving them
##     ships them to Solace (the Chorus comes on sooner) and tightens his Hold.
##   Blackwater, his: marking the crates for his drop is the mission.
##   The Boneyard, clean: the recorder and the arm, then out at the spawn.
##   The Boneyard, his: she comes to at the crater with the recorder already
##     in her pack.
##   Biggie's talk after each level plays once.

const Levels := preload("res://scripts/run/levels.gd")
const LevelPlan := preload("res://scripts/run/procgen/level_plan.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Story := preload("res://scripts/run/story/level_story.gd")

var failures := 0
var run_node
var player


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	_run.call_deferred()


func _run() -> void:
	_plan_checks()
	await _play_checks()
	print("act1 story test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _plan_checks() -> void:
	_check("four levels in order", Levels.ORDER == ["level1", "level2", "level3", "level4"], Levels.ORDER)
	_check("Blackwater needs the Glass District, the Boneyard needs Blackwater",
			Levels.spec("level3")["needs"] == "level2" and Levels.spec("level4")["needs"] == "level3", "")
	for id in ["level3", "level4"]:
		var spec := Levels.spec(id)
		var bad := []
		for s in range(1, 31):
			var plan = LevelPlan.make_level(s, spec)
			var kinds: Array = plan.sections.map(func(x): return x["kind"])
			if plan.zone_name != spec["name"] or plan.biome != spec["biome"]:
				bad.append([s, plan.zone_name, plan.biome])
			if kinds.count("story") != 1 or kinds[-2] != "story" or kinds[-1] != "end" or "finale" in kinds:
				bad.append([s, kinds])
		_check("30 plans of %s: %s, the story yard last" % [spec["name"], spec["biome"]], bad.is_empty(), bad.slice(0, 4))


func _play_checks() -> void:
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 5151
	run_node.armory_path = "user://test_act1_armory.cfg"
	run_node.npc_path = "user://test_act1_npcs.cfg"
	for p in [run_node.armory_path, run_node.npc_path, "user://test_act1_armory_vices.cfg", "user://test_act1_armory_vices_glass.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	root.add_child(run_node)
	await _ticks(5)
	player = run_node.player
	run_node.tutorial.set_enabled(false)
	Vices.reset()
	Glass.reset()

	# The board: Level 3 opens once Level 2 is cleared.
	var spot: Dictionary = run_node.zone_info["interactables"].filter(func(i): return i.get("level", "") == "level3")[0]
	for id in ["tutorial", "level1"]:
		run_node.armory.mark_cleared(id)
	run_node.dress_hub()
	_check("level 3 locked until level 2", spot["prompt"].contains("clear LEVEL 2"), spot["prompt"])
	run_node.armory.mark_cleared("level2")
	run_node.dress_hub()
	await _use_spot(spot)
	_check("the board starts Blackwater Line", run_node.phase == run_node.Phase.ZONE and run_node.run.level == "level3", [run_node.phase, run_node.run.level])
	run_node.tutorial.set_enabled(false)
	await _blackwater_clean()

	await _restart()
	Vices.hold = 40.0
	await _start("level3")
	await _blackwater_hooked()

	await _restart()
	Vices.hold = 70.0
	await _start("level3")
	await _blackwater_his()

	await _restart()
	Vices.hold = 0.0
	await _start("level4")
	await _boneyard_clean()

	await _restart()
	Vices.hold = 70.0
	await _start("level4")
	await _boneyard_his()
	Vices.hold = 0.0

	# Biggie, back home: the joint op, once.
	await _restart()
	var talk = run_node.npc_talk
	talk.cleared = run_node.armory.cleared_levels()
	talk.pick("biggie", 98, true)   # his intro comes first
	var said: Array = talk.pick("biggie", 99, true)
	_check("Biggie tells the joint-op story after the Boneyard", said.any(func(l): return l is Array and String(l[1]).contains("Warsong")), said.slice(0, 2))
	var again: Array = talk.pick("biggie", 99, true)
	var first: Array = talk.pick("biggie", 100, true)
	_check("and the cellar after Blackwater, each once", (again + first).any(func(l): return l is Array and String(l[1]).contains("cellar")) \
			and not talk.pick("biggie", 101, true).any(func(l): return l is Array and String(l[1]).contains("Warsong")), "")
	Vices.reset()
	Glass.reset()


func _blackwater_clean() -> void:
	var info: Dictionary = run_node.zone_info
	var story: Node3D = info.get("story")
	_check("Blackwater: a marsh level with its story set piece", info["plan"].biome == "marsh" and story != null and story.stage == Story.CLEAN, info.keys())
	_check("the crates are addressed to Solace", story.find_child("CrateLabel", false, false).text.contains("SOLACE"), "")
	var beacon: Node3D = info["beacon"]
	_check("the way out is past the far end", beacon.global_position.distance_to(info["spawn"]) > 100.0, beacon.global_position)
	_quiet(info)
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("can't leave with the fuel line running", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("fuel line"), run_node.hud.toast_label.text)
	await _use(story, "valve")
	_check("F at the valve cuts the fuel line", story.fuel_cut, "")
	run_node._rescue_nag = 0.0
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("clean: the crates have to burn too", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("crates"), run_node.hud.toast_label.text)
	await _use(story, "crates")
	_check("F at the crates burns them", story.crates_burned, "")
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("then the beacon clears the level", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
	_check("level 3 cleared, nothing shipped", "level3" in run_node.armory.cleared and Glass.shipped == 0, Glass.shipped)


func _blackwater_hooked() -> void:
	var story: Node3D = run_node.zone_info["story"]
	_check("hooked on Marrow at Blackwater", story.stage == Story.HOOKED, story.stage)
	_quiet(run_node.zone_info)
	await _use(story, "valve")
	_check("not at the valve", not story.ordered, story.ordered)
	await create_timer(4.0, false, true).timeout   # the valve's line clears
	_place(story.to_global(story.spots["crates"]["at"] + Vector3(-4.0, 0.4, 0)))
	await _ticks(3)
	_check("his voice at the crates: let them through", story.ordered and run_node.hud.toast_label.text.contains("Marrow"), run_node.hud.toast_label.text)
	var hold_before: float = Vices.hold
	_place(run_node.zone_info["beacon"].global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("leaving them clears it", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE", run_node.result)
	_check("the crates go on to Solace: the Chorus comes sooner, his Hold tightens", Glass.shipped == 1 and Glass.chorus_stage() >= 0 and is_equal_approx(Vices.hold, hold_before - Vices.HOLD_CLEAN_RUN + Glass.OBEY_HOLD), [Glass.shipped, hold_before, Vices.hold])
	var used_before := Glass.used
	Glass.used = Glass.CHORUS_AT[0] - Glass.CRATE_VIALS
	_check("a shipment counts toward the Chorus", Glass.chorus_stage() == 1, Glass.chorus_stage())
	Glass.used = used_before


func _blackwater_his() -> void:
	var story: Node3D = run_node.zone_info["story"]
	_check("his at Blackwater", story.stage == Story.HIS, story.stage)
	_check("the crate prompt is his errand", story.prompt(story.to_global(story.spots["crates"]["at"])).contains("his drop"), "")
	_quiet(run_node.zone_info)
	_place(run_node.zone_info["beacon"].global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("his: can't leave before marking his crates", run_node.phase == run_node.Phase.ZONE, run_node.phase)
	await _use(story, "crates")
	run_node._rescue_nag = 0.0
	_place(run_node.zone_info["beacon"].global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("his: marked, she can go with the fuel still running", story.crates_sent and not story.fuel_cut and run_node.phase == run_node.Phase.OVER, run_node.result)


func _boneyard_clean() -> void:
	var info: Dictionary = run_node.zone_info
	var story: Node3D = info.get("story")
	_check("the Boneyard: its story set piece", info["plan"].biome == "boneyard" and story != null and story.stage == Story.CLEAN, info.keys())
	var beacon: Node3D = info["beacon"]
	_check("the way out is back at the spawn", beacon.global_position.distance_to(info["spawn"]) < 10.0, beacon.global_position)
	_quiet(info)
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("can't leave before the crater", run_node.phase == run_node.Phase.ZONE and run_node.hud.toast_label.text.contains("crater"), run_node.hud.toast_label.text)
	await _use(story, "recorder")
	_check("the recorder plays his last call", story.recorder and run_node.hud.toast_label.text.contains("RECORDER"), run_node.hud.toast_label.text)
	await _use(story, "arm")
	_check("the arm's hooked for the dropship", story.arm, "")
	run_node._rescue_nag = 0.0
	_place(beacon.global_position + Vector3(0, 0.5, 0))
	await _ticks(3)
	_check("out at the spawn clears the Boneyard", run_node.phase == run_node.Phase.OVER and run_node.result == "RUN COMPLETE" and "level4" in run_node.armory.cleared, run_node.result)


func _boneyard_his() -> void:
	var info: Dictionary = run_node.zone_info
	var story: Node3D = info["story"]
	var arm_at: Vector3 = story.to_global(story.spots["arm"]["at"])
	_check("his: she comes to at the crater, the recorder already in her pack", story.stage == Story.HIS and story.recorder
			and player.global_position.distance_to(arm_at) < 15.0, player.global_position.distance_to(arm_at))
	_check("his: no recorder left to find", story.prompt(story.to_global(story.spots["recorder"]["at"])) == "" or story.near(story.to_global(story.spots["recorder"]["at"])) == "arm", "")


func _start(id: String) -> void:
	run_node.start_run(9000 + id.length(), 0, id)
	await _ticks(5)
	run_node.tutorial.set_enabled(false)


func _restart() -> void:
	if run_node.phase == run_node.Phase.ZONE:
		run_node.end_run("RUN OVER", "test")
		await _ticks(2)
	await _press("run_restart")
	await _ticks(3)


## Grunts left alone for the test.
func _quiet(info: Dictionary) -> void:
	for g in info["grunts"]:
		g.passive = true
		g.alerted = false


func _use(story: Node3D, id: String) -> void:
	_place(story.to_global(story.spots[id]["at"]) + Vector3(0, 0.4, 0))
	await _ticks(3)
	await _press("interact")
	await _ticks(3)


func _use_spot(spot: Dictionary) -> void:
	_place(spot["pos"] + Vector3(0, 0.2, 0.3))
	await _ticks(2)
	await _press("interact")
	await _ticks(3)


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
