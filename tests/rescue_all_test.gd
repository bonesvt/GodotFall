extends SceneTree
## Every rescue for both of them (rescue_event.gd): Mom and Ophelia each taken
## by Marrow, the colony and Cutter, too late every time (the scene plays, it
## lands on her); Ophelia saved from each in time; and of two captors who've
## had her three times, she dresses like the one who had her last.
## (Stopping her on her way back: tests/rescue_stop_test.gd.)
##   godot --headless --path . -s res://tests/rescue_all_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const ARMORY := "user://test_rescue_all_armory.cfg"

var run_node: Node
var ev: Node
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	for f in [ARMORY, "user://test_rescue_all_npc.cfg", "user://test_rescue_all_armory_vices.cfg", "user://test_rescue_all_armory_rescue.cfg",
			"user://test_rescue_all_armory_hub_grip.cfg", "user://test_rescue_all_armory_looks.cfg", "user://test_rescue_all_armory_redline.cfg",
			"user://test_rescue_all_armory_hymn.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var cfg := ConfigFile.new()  # Ophelia's been rescued, so she's home too
	cfg.set_value("progress", "cleared", ["tutorial", "level2"])
	cfg.save(ARMORY)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = ARMORY
	run_node.npc_path = "user://test_rescue_all_npc.cfg"
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	for s in [Vices, Hymn, Redline, Rescue, HubGrip, ViceLooks]:
		s.reset()
	Vices.hold = 10.0
	Redline.catches = 1
	_check("both of them home", run_node.hub_npcs.has("mom") and run_node.hub_npcs.has("ophelia"), run_node.hub_npcs.keys())

	# too late, both of them, every captor
	for who in ["mom", "ophelia"]:
		for captor in ["marrow", "colony", "cutter"]:
			var lost: int = Rescue.lost
			_check("%s taken by %s" % [who, captor], ev.start(who, captor), ev.step)
			await _until(func(): return ev.running(), 10.0)
			ev.left = 0.05
			await _until(func(): return ev.busy(), 2.0)
			_check("  %s/%s: the scene of it" % [who, captor], ev.step == ev.Step.LATE, ev.step)
			await _until(func(): return not ev.busy(), 16.0)
			await _ticks(3)
			_check("  %s/%s: it's on her" % [who, captor], Rescue.lost == lost + 1 and captor in Rescue.lost_to.get(who, []), Rescue.lost_to.get(who))
			_check("  %s/%s: home again after" % [who, captor], run_node.hub_npcs[who].visible and ev.step == ev.Step.IDLE, "")

	# in time, Ophelia, every captor
	for captor in ["marrow", "colony", "cutter"]:
		var saved: int = Rescue.saved
		ev.start("ophelia", captor)
		await _until(func(): return ev.running(), 10.0)
		var at: Vector3 = ev._site["captor"]
		var off := Vector3(1.0, 0.1, -1.6) if captor != "colony" else Vector3(1.6, 0.1, 0.0)
		run_node.place_player(at + off)
		await _ticks(4)
		ev.knock()
		await _until(func(): return not ev.busy(), 16.0)
		await _ticks(3)
		_check("ophelia saved from %s" % captor, Rescue.saved == saved + 1 and ev.step == ev.Step.IDLE, Rescue.saved)

	# two captors who've had her three times: she's the newest's
	Rescue.visits["ophelia"] = {"marrow": 3, "colony": 3}
	Rescue.hooks["ophelia"] = {"marrow": 30.0}
	HubGrip.levels["ophelia"] = 40.0
	Rescue.lost_to["ophelia"] = ["colony", "marrow"]
	_check("dressed like whoever had her last", Rescue.changed_by("ophelia") == "marrow", Rescue.changed_by("ophelia"))
	Rescue.lost_to["ophelia"] = ["marrow", "colony"]
	_check("  (either way round)", Rescue.changed_by("ophelia") == "colony", Rescue.changed_by("ophelia"))

	for s in [Vices, Hymn, Redline, Rescue, HubGrip, ViceLooks]:
		s.reset()
		s.save()
	print("rescue_all_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


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
