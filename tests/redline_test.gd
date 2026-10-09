extends SceneTree
## Cutter, Redline and the Rig (cutter.gd, redline.gd, redline_body.gd, cutter_scene.gd, rig_screen.gd):
## he catches her, the needle scene plays and she's high; when it's out, the
## crash; from the second catch a change a time (wiring, heavy body, long
## legs, forced posture), in order, on her own bones;
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
	_check("a charge, and her body's her own", Redline.charges == 1 and Redline.mods.is_empty(), [Redline.charges, Redline.mods])
	_check("and he's gone", run_node.get_tree().get_nodes_in_group("cutter").is_empty() or not player.entranced, "")
	# the high runs out: the crash
	Redline.high_left = 0.05
	await _until(func(): return scene.busy(), 2.0)
	_check("the high's out: the crash", scene.busy() and scene.kind == "crash", scene.kind)
	await _until(func(): return not scene.busy(), 12.0)
	await _ticks(3)
	_check("the crash over: hers again", not Redline.crash_owed and not player.entranced, Redline.crash_owed)


	# the second catch: another charge, still nothing on her
	run_node.cutter_now()
	await _ticks(4)
	await _until(func(): return not scene.busy(), 12.0)
	await _ticks(3)
	_check("the second time: two charges, no change", Redline.charges == 2 and Redline.mods.is_empty(), Redline.charges)
	Redline.high_left = 0.0
	Redline.crash_owed = false

	# the Rig, in Biggie's den: her pick, for a charge
	var rig_spot := {}
	for s in run_node.zone_info["interactables"]:
		if s["id"] == "rig":
			rig_spot = s
	_check("the Rig's in Biggie's den", not rig_spot.is_empty() and rig_spot.get("shop", "") == "rig", rig_spot.get("pos"))
	run_node.open_bench("rig")
	var rig: Node = run_node.bench
	_check("sat in it: the Rig's screen", rig != null and rig.has_method("install"), rig)
	_check("seventeen mods to pick from", Redline.ORDER.size() == 17 and Redline.ORDER.all(func(m): return Redline.MODS.has(m) and Redline.FEEL.has(m)), Redline.ORDER.size())
	_check("wiring, for a charge", rig.install("wiring") and Redline.charges == 1 and Redline.mods == ["wiring"], Redline.mods)
	_check("heavy body, for the other", rig.install("heavy") and Redline.charges == 0, Redline.mods)
	_check("no charge left: no more", not rig.install("legs") and Redline.mods.size() == 2, Redline.mods)
	Redline.charges = 20
	_check("heavy and compact can't share her", not rig.install("compact") and Redline.blocked("compact").begins_with("not with"), Redline.blocked("compact"))
	_check("taking one off is free", rig.remove("heavy") and Redline.charges == 20 and not Redline.has("heavy"), Redline.charges)
	_check("then compact goes on", rig.install("compact"), Redline.mods)
	run_node.close_bench()
	await _ticks(4)
	var body: Node = player.get_node("EcoBody/Body")
	var skel: Skeleton3D = body.get("skeleton")
	var mod: Node = skel.get_node("RedlineBody")
	_check("on her: veins up her arms and neck", player.find_child("RedlineBody_Veins_J_Bip_C_Neck", true, false) != null, "")
	_check("compact: all of her a size down, evenly", skel.scale.x < 0.95 and is_equal_approx(skel.scale.x, skel.scale.z), skel.scale)

	# every mod, all at once (as far as they go together)
	Redline.mods = []
	for m in Redline.ORDER:
		if Redline.blocked(m) == "":
			Redline.install(m)
	_check("all but the clashing three", Redline.mods.size() == 14, Redline.mods)
	run_node.cutter_scene._redress_copies()
	await _ticks(4)
	mod = skel.get_node("RedlineBody")
	_check("reshaping her every frame", mod.runs > 0, mod.runs)
	_check("heavy: a size up, evenly", skel.scale.x > 1.03 and skel.scale.x < 1.06, skel.scale)
	_check("long legs: lifted so her feet reach the floor", skel.position.y > 0.05, skel.position.y)
	_check("long arms", mod.last.get("J_Bip_L_Hand:length", 1.0) > 1.2, mod.last)
	_check("locked core: held straight", mod.last.get("core", false), mod.last)
	for part in ["RedlineBody_Head", "RedlineBody_Tail", "RedlineBody_Wings", "RedlineBody_Vents", "RedlineBody_Spurs_L", "RedlineBody_Scales_L_LowerLeg", "RedlineBody_Freckles_L"]:
		_check("on her: " + part, player.find_child(part, true, false) != null, "")
	player._set_crouch(true)
	_check("locked core: she can't crouch", not player.crouching, player.crouching)
	_check("what they do", Redline.damage_scale() < 1.0 and Redline.jump_scale() > 1.0 and Redline.spread_scale() < 1.0 and Redline.reach_scale() > 1.0 \
			and Redline.melee_scale() > 1.0 and Redline.fall_scale() < 1.0 and Redline.can_glide() and Redline.breaks_locks() and Redline.hearing()[0] > 0.0, "")
	Redline.high_left = 10.0
	_check("high: wiring heals faster, red eyes see through walls", Redline.regen_scale() > 1.0 and Redline.xray(), "")
	Redline.high_left = 0.0
	player._glide(true)
	await _ticks(10)
	_check("the wings spread to glide", mod.last.get("wings", 0.0) > 0.5, mod.last.get("wings"))
	player._glide(false)

	# off again: her own size and height
	Redline.mods = []
	run_node.cutter_scene._redress_copies()
	await _ticks(3)
	_check("all off: her own size and height again", skel.scale.is_equal_approx(Vector3.ONE) and skel.position.y < 0.02, [skel.scale, skel.position.y])

	# old saves: what Redline did to her before the Rig stays on as her mods
	var cfg := ConfigFile.new()
	cfg.set_value("redline", "changes", ["wiring", "posture"])
	cfg.set_value("redline", "catches", 3)
	cfg.save("user://test_redline_old.cfg")
	Redline.open("user://test_redline_old.cfg")
	_check("old changes become her mods", Redline.mods == ["wiring", "core"], Redline.mods)
	Redline.open(run_node.armory_path.get_basename() + "_redline.cfg")

	# Teen: none of it
	ContentRating.set_rating("T", false)
	_check("teen: no Redline", not Redline.allowed() and not Redline.has("wiring") and Redline.speed_scale() == 1.0, "")
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