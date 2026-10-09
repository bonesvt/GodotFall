extends SceneTree
## The Hub Grip (hub_grip.gd): Mom and Ophelia's own Hymn and gear. The
## Shepherd takes the closest of them within RANGE with Eco, the fitting shows
## them in the next frame, their gear shows on them in the hub, the headphones
## make them miss Eco's first word, their scenes play at 30/60/90 and on the
## way back, and Biggie or Doc Imani gets it off them. Mature only.
##   godot --headless --path . -s res://tests/hub_grip_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const Shepherd := preload("res://scripts/hub/shepherd.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_grip_armory.cfg"
	run_node.npc_path = "user://test_grip_npcs.cfg"
	for f in ["user://test_grip_armory.cfg", "user://test_grip_armory_vices.cfg", "user://test_grip_armory_hymn.cfg", "user://test_grip_armory_hub_grip.cfg", "user://test_grip_npcs.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])  # Ophelia's been rescued
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Hymn.reset()
	HubGrip.reset()
	_check("its own save", HubGrip.save_path.ends_with("test_grip_armory_hub_grip.cfg"), HubGrip.save_path)
	_check("Mom and Ophelia are home", run_node.hub_npcs.has("mom") and run_node.hub_npcs.has("ophelia"), run_node.hub_npcs.keys())

	# closest within range
	_check("closest within 8 m", HubGrip.closest(Vector3.ZERO, {"mom": Vector3(5, 0, 0), "ophelia": Vector3(3, 0, 0)}) == "ophelia", "")
	_check("nobody past 8 m", HubGrip.closest(Vector3.ZERO, {"mom": Vector3(9, 0, 0)}) == "", "")

	# the Shepherd brings Eco in standing next to Mom: Mom comes too
	var mom: Node3D = run_node.hub_npcs["mom"]
	player.global_position = mom.global_position + Vector3(1.5, 0.1, 0)
	await _ticks(5)
	Hymn.hunted = true
	run_node.spawn_shepherd()
	await _ticks(2)
	var shep: CharacterBody3D = get_nodes_in_group("shepherd")[0]
	shep._dart_t = INF
	shep._pulse_t = INF
	shep.global_position = player.global_position + Vector3(0.9, 0, 0)
	shep.take_her()
	await _until(func(): return run_node.fitting_scene.busy(), 4.0)
	_check("Mom taken with her: her first piece", HubGrip.gear_of("mom") == ["headphones"] and HubGrip.level("mom") == HubGrip.TAKEN, [HubGrip.gear_of("mom"), HubGrip.level("mom")])
	_check("in the next frame in the back room", run_node.fitting_scene._with_model != null and run_node.fitting_scene.with == "mom", run_node.fitting_scene.with)
	await _until(func(): return not run_node.fitting_scene.busy(), 14.0)
	await _ticks(3)
	_check("her gear shows on her in the hub", mom.find_child("ColonyGear", true, false) != null, mom.find_child("ColonyGear", true, false))
	_check("the toast says so", run_node.hud.toast_label.text.contains("Mom was taken with her"), run_node.hud.toast_label.text)

	# the headphones: she misses Eco's first word this stay
	HubGrip.heard.clear()
	run_node.talk_to("mom")
	await _ticks(2)
	_check("headphones: Mom doesn't hear her the first time", not run_node.npc_talk.active() and run_node.hud.toast_label.text.contains("doesn't look up"), run_node.hud.toast_label.text)
	_check("then she does", not HubGrip.deaf_now("mom"), HubGrip.heard)

	# her scenes: crossing 30 queues one, coming home plays it
	HubGrip.levels["mom"] = 29.0
	HubGrip.run_over()
	_check("past 30: a scene waiting", HubGrip.pending.size() > 0 and HubGrip.pending.back()[1] == 30, HubGrip.pending)
	run_node.npc_talk.stop()
	await _ticks(2)
	run_node._grip_scene()
	await _ticks(2)
	_check("it plays with her", run_node.npc_talk.active() and run_node.npc_talk.npc == mom, [run_node.npc_talk.npc, run_node.phase, HubGrip.pending])
	run_node.npc_talk.stop()

	# Biggie gets it off her
	Hymn.biggie_tried = false
	run_node.open_bench("gear_off")
	await _ticks(2)
	var table: CanvasLayer = run_node.bench
	_check("her gear on Biggie's list", table._rows.has(["mom", "headphones"]), table._rows)
	table.pick("headphones", "mom")
	for i in Hymn.HOLDS:
		table._at = 0.5
		table.hold_now()
	await _until(func(): return run_node.bench == null, 4.0)
	await _ticks(2)
	_check("off her", HubGrip.gear_of("mom").is_empty() and mom.find_child("ColonyGear", true, false) == null, HubGrip.gear_of("mom"))

	# Doc Imani: her own try, for scrap
	HubGrip.take("ophelia")
	run_node.armory.stash["scrap"] = 100
	run_node.open_bench("gear_off_doc")
	await _ticks(2)
	table = run_node.bench
	_check("Doc Imani's room", table.kind == "gear_off_doc" and table.can_try(), table.kind)
	table.pick("headphones", "ophelia")
	_check("it costs scrap", run_node.armory.stash["scrap"] == 100 - table.DOC_COST, run_node.armory.stash["scrap"])
	_check("a steadier hand than Biggie's", table._steady("headphones") > Hymn.steady("headphones"), table._steady("headphones"))
	for i in Hymn.HOLDS:
		table._at = 0.5
		table.hold_now()
	await _until(func(): return run_node.bench == null, 4.0)
	_check("off Ophelia", HubGrip.gear_of("ophelia").is_empty(), HubGrip.gear_of("ophelia"))

	HubGrip.reset()
	HubGrip.save()
	Hymn.reset()
	Hymn.save()

	print("hub_grip_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
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
