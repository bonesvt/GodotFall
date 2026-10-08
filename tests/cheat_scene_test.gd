extends SceneTree
## The cheat box's control items played out (cheat_scene.gd) in the hub: each
## one's scene runs with her held and the HUD off, the Full Set puts the gear
## on her piece by piece, the Family Plan brings Mom and Ophelia over and back,
## and each leaves its system full. Mature only.
##   godot --headless --path . -s res://tests/cheat_scene_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const CheatScene := preload("res://scripts/hub/cheat_scene.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_cheatscene_armory.cfg"
	run_node.npc_path = "user://test_cheatscene_npcs.cfg"
	for f in ["user://test_cheatscene_armory.cfg", "user://test_cheatscene_armory_vices.cfg", "user://test_cheatscene_armory_hymn.cfg",
			"user://test_cheatscene_armory_hub_grip.cfg", "user://test_cheatscene_armory_glass.cfg", "user://test_cheatscene_armory_obsession.cfg", "user://test_cheatscene_npcs.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])  # Ophelia's home
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
	var scene: Node = run_node.cheat_scene
	for id in ["hymn", "set", "glass", "keepsake", "family"]:
		run_node.open_bench("cheats")
		await _ticks(2)
		run_node.bench.control_item(id)
		await _ticks(4)
		_check("%s: the box closes on its scene" % id, run_node.bench == null and scene.busy() and player.entranced, scene.item)
		if id == "set":
			await _until(func(): return scene._shown >= 4, 8.0)
			_check("the Full Set: piece by piece on her", player.find_child("headphones", true, false) != null and scene._shown < Hymn.GEAR.size(), scene._shown)
		if id == "family":
			await _ticks(10)
			var mom: Node3D = run_node.hub_npcs["mom"]
			_check("the Family Plan: Mom by her side", mom.global_position.distance_to(player.global_position) < 1.5, mom.global_position.distance_to(player.global_position))
		await _until(func(): return not scene.busy(), 14.0)
		await _ticks(3)
		_check("%s: over, she's hers again" % id, not scene.busy() and not player.entranced, scene.busy())
	_check("Super Hymn: full", Hymn.level == Hymn.MAX, Hymn.level)
	_check("the Full Set: all of it", Hymn.gear == Hymn.GEAR and player.find_child("crown", true, false) != null, Hymn.gear)
	_check("Glass Rush: crystallised, vials, earpiece", Glass.glass == Glass.MAX_GLASS and Glass.vials == Glass.MAX_VIALS and Glass.earpiece, [Glass.glass, Glass.vials])
	_check("Keepsake: full", Obsession.keepsake == Obsession.MAX and Obsession.meter == Obsession.MAX, Obsession.keepsake)
	var mom: Node3D = run_node.hub_npcs["mom"]
	_check("the Family Plan: both in the whole set", HubGrip.gear_of("mom") == Hymn.GEAR and HubGrip.gear_of("ophelia") == Hymn.GEAR and HubGrip.level("mom") == HubGrip.MAX, HubGrip.gear)
	_check("and Mom's back where she was, in it", mom.global_position.distance_to(player.global_position) > 1.5 and mom.find_child("crown", true, false) != null, mom.global_position)
	Vices.reset()
	Vices.save()
	Hymn.reset()
	Hymn.save()
	HubGrip.reset()
	HubGrip.save()
	Glass.reset()
	Glass.save()
	Obsession.reset()
	Obsession.save()
	print("cheat_scene_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
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