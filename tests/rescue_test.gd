extends SceneTree
## Rescues (rescue.gd, rescue_event.gd, rescue_sites.gd): once a captor's
## started on Eco, Mom can be taken; Biggie runs in, the place is set and the
## clock runs. In time she knocks the captor down: bond up, Town's Grip and his
## hold down. Too late: what happened, bond down, Town's Grip and his hold up:
## Cutter's Wiring on her, the colony's next piece. Leaving for a run with her
## taken is too late too. Mature only.
##   godot --headless --path . -s res://tests/rescue_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const Family := preload("res://scripts/hub/family.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var ev: Node
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_rescue_armory.cfg"
	run_node.npc_path = "user://test_rescue_npc.cfg"
	for f in ["user://test_rescue_armory.cfg", "user://test_rescue_npc.cfg", "user://test_rescue_armory_vices.cfg", "user://test_rescue_armory_rescue.cfg",
			"user://test_rescue_armory_hub_grip.cfg", "user://test_rescue_armory_looks.cfg", "user://test_rescue_armory_redline.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	HubGrip.reset()
	ViceLooks.reset()
	_check("its own save", Rescue.save_path.ends_with("test_rescue_armory_rescue.cfg"), Rescue.save_path)
	_check("Mom's home", run_node.hub_npcs.has("mom"), run_node.hub_npcs.keys())

	# nobody's started on Eco: nobody comes for Mom
	_check("no captor yet: none", Rescue.active_captors().is_empty() and not ev.start_random(), Rescue.active_captors())
	Vices.hold = 10.0
	Hymn.level = 40.0
	Redline.catches = 1
	Redline.mods = ["wiring", "tail"]
	_check("Marrow, the colony and Cutter all started on her", Rescue.active_captors() == ["marrow", "colony", "cutter"], Rescue.active_captors())
	_check("less time with Hymn and Redline in her", is_equal_approx(Rescue.time(), Rescue.TIME - Rescue.HYMN_CUT * 0.4 - Rescue.REDLINE_CUT * 2), Rescue.time())
	Hymn.level = 0.0
	Redline.mods = []

	# Marrow takes her: Biggie, then the clock
	ViceLooks.town_grip = 30.0
	Rescue.hooks = {"mom": {"marrow": 30.0}}
	var state: ConfigFile = run_node.npc_talk.state
	Family.add(state, "mom", 40 - Family.bond(state, "mom"))
	_check("taken", ev.start("mom", "marrow") and ev.busy() and player.entranced, ev.step)
	await _until(func(): return ev.running(), 8.0)
	_check("Biggie's said it: the clock's running", ev.running() and not ev.busy() and not player.entranced and ev.left > 80.0, ev.left)
	_check("Mom's gone from home", not run_node.hub_npcs["mom"].visible, "")
	_check("the marker: the cellar door, from up in town", ev.target().distance_to(HushDen.CELLAR) < 0.1, ev.target())
	var spot := _spot()
	_check("him, down there, by her chair", not spot.is_empty() and (spot["pos"] as Vector3).distance_to(HushDen.WAKE) < 2.0, spot.get("pos"))
	var left_was: float = ev.left
	await _ticks(30)
	_check("the clock's counting", ev.left < left_was, ev.left)
	run_node.place_player(spot["pos"] + Vector3(0.7, 0.1, -1.0))  # from the stairs
	await _ticks(4)
	_check("down there: the marker's on him", ev.target().distance_to(spot["pos"]) < 0.1, ev.target())
	_check("[F] Knock him down", run_node.nearest_hub_spot().get("id", "") == ev.SPOT, run_node.nearest_hub_spot().get("id", ""))
	ev.knock()
	_check("in time: the scene", ev.busy() and player.entranced, ev.step)
	await _until(func(): return not ev.busy(), 10.0)
	await _ticks(3)
	_check("Mom's back home", run_node.hub_npcs["mom"].visible and ev.step == ev.Step.IDLE, "")
	_check("bond +15", Family.bond(state, "mom") == 40 + Rescue.BOND_SAVED, Family.bond(state, "mom"))
	_check("Town's Grip -10", is_equal_approx(ViceLooks.town_grip, 20.0), ViceLooks.town_grip)
	_check("Marrow's hold on her -20", is_equal_approx(Rescue.hook("mom", "marrow"), 10.0), Rescue.hook("mom", "marrow"))
	_check("once a stay: no more rolls", ev._rolled, ev._rolled)

	# Cutter, too late: Wiring
	ev.step = ev.Step.IDLE
	var bond_was := Family.bond(state, "mom")
	ev.start("mom", "cutter")
	await _until(func(): return ev.running(), 8.0)
	_check("Cutter's stash", ev.target().distance_to(preload("res://scripts/hub/rescue_sites.gd").STASH) < 3.0, ev.target())
	ev.left = 0.05
	await _until(func(): return ev.busy(), 2.0)
	_check("the clock's out: too late", ev.busy() and ev.step == ev.Step.LATE, ev.step)
	await _until(func(): return not ev.busy(), 16.0)
	await _ticks(3)
	_check("bond -10", Family.bond(state, "mom") == bond_was + Rescue.BOND_LATE, Family.bond(state, "mom"))
	_check("Town's Grip +10", is_equal_approx(ViceLooks.town_grip, 30.0), ViceLooks.town_grip)
	_check("Cutter's hold on her +20", is_equal_approx(Rescue.hook("mom", "cutter"), 20.0), Rescue.hook("mom", "cutter"))
	await _ticks(2)
	_check("Wiring: on her, at home", run_node.hub_npcs["mom"].get_meta("wired", false), "")
	_check("Cutter's had her: his red in her eyes, at home", Rescue.held_by("mom") == "cutter" and run_node.hub_npcs["mom"].get_meta("rescue_eyes", "") == "cutter", Rescue.held_by("mom"))

	# afterwards: she walks off to him, and Eco can see her going
	run_node.place_player(Vector3(0.5, 0.1, 127.0))
	await _ticks(4)
	ev.draw_off("mom", 0.05)
	await _until(func(): return ev._walker != null, 3.0)
	_check("off to Cutter: walking out of Solace", ev._walker != null and not run_node.hub_npcs["mom"].visible, ev._walker)
	var was: Vector3 = ev._walker.global_position if ev._walker != null else Vector3.ZERO
	await _ticks(60)
	_check("walking his way", ev._walker != null and ev._walker.global_position.distance_to(was) > 0.5, ev._walker.global_position if ev._walker != null else null)
	_check("Eco sees her go", ev._spotted and run_node.hud.toast_label.text.contains("pilgrim road"), run_node.hud.toast_label.text)
	ev._end_walk()

	# the colony, too late: the next piece
	var pieces := HubGrip.gear_of("mom").size()
	ev.start("mom", "colony")
	await _until(func(): return ev.running(), 8.0)
	_check("the van by the dispensary", run_node.zone_root.find_child("RescueVan", true, false) != null, "")
	ev.left = 0.05
	await _until(func(): return ev.busy(), 2.0)
	await _until(func(): return not ev.busy(), 16.0)
	await _ticks(3)
	_check("the colony's next piece on her", HubGrip.gear_of("mom").size() == pieces + 1, HubGrip.gear_of("mom"))
	_check("the van's gone", run_node.zone_root.find_child("RescueVan", true, false) == null, "")

	# off on a run with her taken: too late
	var lost_was := Rescue.lost
	ev.start("mom", "marrow")
	await _until(func(): return ev.running(), 8.0)
	ev.lose()
	_check("left her: too late", Rescue.lost == lost_was + 1 and is_equal_approx(Rescue.hook("mom", "marrow"), 30.0) and ev.step == ev.Step.IDLE, Rescue.lost)
	_check("and she's back at her spot", run_node.hub_npcs["mom"].visible, "")

	# a run fades Marrow's and Cutter's hold
	Rescue.run_over()
	_check("a run fades it", is_equal_approx(Rescue.hook("mom", "cutter"), 20.0 - Rescue.FADE), Rescue.hook("mom", "cutter"))

	# Teen: none of it
	ContentRating.set_rating("T", false)
	_check("teen: no rescues", not ev.start("mom", "marrow") and Rescue.active_captors().is_empty(), "")
	ContentRating.set_rating("M", false)
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	Rescue.save()
	HubGrip.reset()
	HubGrip.save()
	ViceLooks.reset()
	ViceLooks.save()
	print("rescue_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _spot() -> Dictionary:
	for s in run_node.zone_info.get("interactables", []):
		if s["id"] == ev.SPOT:
			return s
	return {}


func _until(ok: Callable, seconds: float) -> void:
	var left := int(Engine.physics_ticks_per_second * seconds)
	while left > 0 and not ok.call():
		await physics_frame
		left -= 1


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
