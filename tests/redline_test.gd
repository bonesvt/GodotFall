extends SceneTree
## Cutter and Redline (cutter.gd, redline.gd, redline_body.gd, cutter_scene.gd):
## he catches her, the needle scene plays and she's high; when it's out, the
## crash; from the second catch a change a time, in order, on her own bones;
## Doc Imani takes the newest back for scrap; Biggie's toolkit takes the lot.
## Mature only.
##   godot --headless --path . -s res://tests/redline_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const RedlineBody := preload("res://scripts/hub/redline_body.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_redline_armory.cfg"
	for f in ["user://test_redline_armory.cfg", "user://test_redline_armory_vices.cfg", "user://test_redline_armory_redline.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Redline.reset()
	_check("its own save", Redline.save_path.ends_with("test_redline_armory_redline.cfg"), Redline.save_path)

	# the first catch: the needle, the high, no change yet
	var scene: Node = run_node.cutter_scene
	run_node.cutter_now()
	await _ticks(4)
	_check("Cutter has her: the needle scene", scene.busy() and scene.kind == "catch" and player.entranced, scene.kind)
	_check("he's there", not run_node.get_tree().get_nodes_in_group("cutter").is_empty(), "")
	await _until(func(): return not scene.busy(), 12.0)
	await _ticks(3)
	_check("high: red, faster", Redline.high() and Redline.speed_scale() > 1.0 and Redline.catches == 1, Redline.high_left)
	_check("the first time: no change", Redline.changes.is_empty(), Redline.changes)
	_check("and he's gone", run_node.get_tree().get_nodes_in_group("cutter").is_empty() or not player.entranced, "")
	# the high runs out: the crash
	Redline.high_left = 0.05
	await _until(func(): return scene.busy(), 2.0)
	_check("the high's out: the crash", scene.busy() and scene.kind == "crash", scene.kind)
	await _until(func(): return not scene.busy(), 12.0)
	await _ticks(3)
	_check("the crash over: hers again", not Redline.crash_owed and not player.entranced, Redline.crash_owed)

	# the second catch: wrong ears
	run_node.cutter_now()
	await _ticks(4)
	await _until(func(): return not scene.busy(), 12.0)
	await _ticks(3)
	_check("the second time: wrong ears", Redline.changes == ["ears"], Redline.changes)
	_check("on her: the ears", player.find_child("RedlineBody_Ears", true, false) != null, "")
	Redline.high_left = 0.0
	Redline.crash_owed = false

	# the rest, in order, on her bones
	for i in 7:
		Redline.caught()
	Redline.high_left = 0.0
	Redline.crash_owed = false
	_check("they stack, in order", Redline.changes == Redline.CHANGES.slice(0, 8), Redline.changes)
	run_node.cutter_scene._redress_copies()  # as the catch scene does
	await _ticks(4)
	var body: Node = player.get_node("EcoBody/Body")
	var skel: Skeleton3D = body.get("skeleton")
	var mod: Node = skel.get_node("RedlineBody")
	_check("reshaping her every frame", mod.runs > 0, mod.runs)
	_check("a heavy body: all of her, evenly", mod.last.get("body:scale", 1.0) > 1.1 and skel.scale.x > 1.1 and is_equal_approx(skel.scale.x, skel.scale.y), skel.scale)
	_check("forced posture: chin up", mod.last.get("posture:chin", 0.0) > 0.0, mod.last)
	_check("forced posture: she can't look down far", Redline.pitch_min() > -1.0, Redline.pitch_min())
	_check("a stretched neck, long forearms", mod.last.get("J_Bip_C_Head:length", 1.0) > 1.8 and mod.last.get("J_Bip_R_Hand:length", 1.0) > 1.2, mod.last)
	_check("long legs: lifted so her feet reach the floor", skel.position.y > 0.05, skel.position.y)
	_check("a tail", player.find_child("RedlineBody_Tail", true, false) != null, "")
	_check("heavy on her feet, long legs", Redline.speed_scale() < 1.0 and Redline.jump_scale() > 1.0, [Redline.speed_scale(), Redline.jump_scale()])

	# Doc Imani: the newest one back, for scrap
	run_node.armory.stash["scrap"] = 100
	run_node._doc_redline()
	await _ticks(3)
	_check("Doc Imani takes the newest back", not "tail" in Redline.changes and Redline.changes.size() == 7 and run_node.armory.amount("scrap") == 100 - Redline.DOC_COST, Redline.changes)
	_check("and it's gone from her", player.find_child("RedlineBody_Tail", true, false) == null, "")
	# all of it gone: her own size again
	Redline.changes = []
	run_node.cutter_scene._redress_copies()
	await _ticks(2)
	_check("her own size back", is_equal_approx(skel.scale.x, 1.0) or skel.scale.x < 1.05, skel.scale)

	# Teen: none of it
	ContentRating.set_rating("T", false)
	_check("teen: no Redline", not Redline.allowed() and not Redline.has("ears") and Redline.speed_scale() == 1.0, "")
	ContentRating.set_rating("M", false)
	Redline.reset()
	Redline.save()
	print("redline_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
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
