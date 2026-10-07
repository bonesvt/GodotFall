extends SceneTree
## Marrow, part 2 (glass.gd): Glass sold at his screen once his Hold has been
## deep, cracked on a run for slow-mo focus that crystallises her (less max
## health, violet glass in her shader); his orders in her ear (tether.gd),
## paid when she obeys and punished when she doesn't; the Chorus dosing the
## townsfolk, his ledger and vats, and holding out against him to break it
## (chorus_scene.gd). Teen sees none of it.
##   godot --headless --path . -s res://tests/glass_test.gd

const Vices := preload("res://scripts/hub/vices.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var player: CharacterBody3D
var failures := 0


func _initialize() -> void:
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 7
	run_node.armory_path = "user://test_glass_armory.cfg"
	for f in ["user://test_glass_armory.cfg", "user://test_glass_armory_vices.cfg", "user://test_glass_armory_vices_glass.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(run_node)
	_run.call_deferred()


func _run() -> void:
	await _ticks(60)
	player = run_node.player
	var armory = run_node.armory
	Vices.reset()
	Glass.reset()

	# Not on sale until his Hold has been deep.
	_check("no Glass for a taste of Hush", not Glass.on_sale(), Vices.hold)
	Vices.hold = Vices.TRANCE_HOLD
	_check("on sale once he's got her", Glass.on_sale(), Vices.hold)
	ContentRating.set_rating("T", false)
	_check("Teen: never", not Glass.on_sale() and Glass.look() == 0.0 and Glass.health_scale() == 1.0, "")
	ContentRating.set_rating("M", false)

	# Buying at his screen.
	armory.stash["scrap"] = 500
	armory.stash["circuits"] = 10
	run_node.open_bench("hush")
	await _ticks(2)
	var screen: Node = run_node.bench
	_check("first vial comes with his earpiece", screen.buy_glass() and Glass.vials == 1 and Glass.earpiece and screen._talk.text == screen.MARROW_GLASS_FIRST, screen._talk.text)
	screen.buy_glass()
	screen.buy_glass()
	_check("three at most", not screen.buy_glass() and Glass.vials == Glass.MAX_VIALS, Glass.vials)
	_check("paid for", armory.amount("scrap") == 500 - 3 * Glass.VIAL_COST["scrap"], armory.amount("scrap"))
	run_node.close_bench()
	await _ticks(2)

	# On a run: L cracks one. Slow-mo, harder hits, and the glass spreads.
	run_node.start_run(11)
	await _ticks(3)
	var tether: Node = run_node.tether
	var full_health: float = player.max_health
	var hold_before := Vices.hold
	_check("a vial cracked", tether.focus() and Glass.vials == 2 and Glass.glass == 1, Glass.vials)
	await _ticks(2)
	_check("the world slows", is_equal_approx(Engine.time_scale, Glass.FOCUS_SCALE), Engine.time_scale)
	_check("her shots hit harder", Glass.damage_out() == Glass.FOCUS_DAMAGE, Glass.damage_out())
	_check("it costs her max health", is_equal_approx(player.max_health, full_health * (1.0 - Glass.HEALTH_PER_GLASS)), [player.max_health, full_health])
	_check("his Hold tightens", Vices.hold > hold_before, Vices.hold)
	_check("violet glass in her shader", is_equal_approx(float(RenderingServer.global_shader_parameter_get("eco_glass")), 1.0 / Glass.MAX_GLASS),
			RenderingServer.global_shader_parameter_get("eco_glass"))
	_check("HUD shows it", run_node._vices_text().contains("FOCUS") and run_node._vices_text().contains("[L] Glass x2"), run_node._vices_text())
	await _ticks(int(Glass.FOCUS_TIME * Engine.physics_ticks_per_second) + 10)
	_check("focus wears off in real seconds", not Glass.focusing() and Engine.time_scale == 1.0, Engine.time_scale)

	# His orders. Obeyed: paid, patched up, his Hold a notch tighter.
	tether.give_order("kills")
	_check("an order in her ear", run_node.hud.toast_label.text.contains("Three of them") and tether.hud_text().contains("kill 3 more"), tether.hud_text())
	var scrap: int = run_node.run.materials.get("scrap", 0)
	hold_before = Vices.hold
	run_node.run.kills += 3
	await _ticks(2)
	_check("obeyed: scrap and his approval", tether.order == "" and int(run_node.run.materials.get("scrap", 0)) == scrap + Glass.OBEY_SCRAP
			and is_equal_approx(Vices.hold, hold_before + Glass.OBEY_HOLD), [run_node.run.materials, Vices.hold])
	# Failed: the swirls take her where she stands, and his Hold loosens.
	tether.give_order("untouched")
	player.set("untouchable_timer", 0.0)
	hold_before = Vices.hold
	player.take_damage(5.0)
	await _ticks(2)
	_check("hit: punished", tether.busy() and player.entranced and Vices.entranced and is_equal_approx(Vices.hold, hold_before + Glass.REFUSE_HOLD), Vices.hold)
	await _ticks(int(Glass.PUNISH_TIME * Engine.physics_ticks_per_second) + 10)
	_check("then hers again", not tether.busy() and not player.entranced and not Vices.entranced, player.entranced)
	tether.give_order("moving")
	await _ticks(int(1.4 * Engine.physics_ticks_per_second))
	_check("standing still on 'keep moving' is refusing him", tether.busy(), tether.order)
	await _ticks(int(Glass.PUNISH_TIME * Engine.physics_ticks_per_second) + 10)
	_check("orders come on their own", tether._next > 0.0 and tether._next <= Glass.ORDER_EVERY, tether._next)

	# Runs: one with Glass keeps it on her, one without wears a level off.
	run_node.end_run("RUN FAILED", "test")
	_check("a Glass run keeps it", Glass.glass == 1, Glass.glass)
	run_node.enter_hub()
	await _ticks(3)
	_check("home: the world at speed, no order", Engine.time_scale == 1.0 and tether.order == "" and not tether.busy(), Engine.time_scale)
	run_node.start_run(11)
	await _ticks(3)
	run_node.end_run("RUN FAILED", "test")
	_check("a clean run wears it down", Glass.glass == 0, Glass.glass)
	run_node.enter_hub()
	await _ticks(3)
	_check("her health back", is_equal_approx(player.max_health, full_health), player.max_health)

	# The Chorus: as she uses Glass he doses the town.
	_check("no Chorus yet", Glass.chorus_stage() == 0 and not _glass_node("ledger").visible, Glass.used)
	Glass.used = Glass.CHORUS_AT[0]
	run_node.enter_hub()
	await _ticks(5)
	var folk: Node = run_node.zone_root.get_node("Townsfolk")
	_check("three townsfolk are his", folk.dosed.size() == 3 and folk.dosed.has("kit"), folk.dosed.keys())
	_check("violet in Kit's eyes", _iris_swirl(folk.people["kit"]), "")
	_check("Pell's eyes still hers", not _iris_swirl(folk.people["pell"]), "")
	_check("his ledger and vats are there", _glass_node("ledger").visible and _glass_node("vat_a").visible, "")
	var vat := _spot("glass_vat_a")
	run_node._glass_spot(vat)
	_check("she won't smash what she doesn't understand", Glass.vats.is_empty(), Glass.vats)
	run_node._glass_spot(_spot("glass_ledger"))
	_check("the ledger: the colony's buying the town", Glass.ledger and run_node.hud.toast_label.text.contains("colony seal"), run_node.hud.toast_label.text)
	for id in Glass.VAT_IDS:
		run_node._glass_spot(_spot("glass_" + id))
	_check("three vats smashed", Glass.vats_left() == 0 and not _glass_node("vat_b").get_node("Tank").visible and _glass_node("vat_b").get_node("Shards").visible, Glass.vats)
	_check("time to face him", Glass.can_confront(), "")

	# Holding out, and not: he pulls her back under, deeper, vats brewing again.
	Vices.hold = 70.0
	var scene: Node = run_node.chorus_scene
	scene.play()
	await _seconds(scene.LEAD + 0.2)
	_check("a pull: the window's open", scene.window_open() and Vices.entranced, scene._window)
	await _seconds(Glass.resist_window() + 0.2)
	_check("missed: lost", scene.outcome == "lost" and not scene.busy() and Glass.vats.is_empty() and is_equal_approx(Vices.hold, 70.0 + Glass.RESIST_FAIL_HOLD), [scene.outcome, Vices.hold])
	_check("the vats brewing again", _glass_node("vat_a").get_node("Tank").visible, "")
	for id in Glass.VAT_IDS:
		Glass.smash(id)
	scene.play()
	for i in Glass.RESIST_BEATS:
		while not scene.window_open():
			await _ticks(1)
		scene.hold_on()
		await _ticks(2)
	_check("held on: free", scene.outcome == "free" and Glass.broken and Vices.hold == 0.0 and Glass.glass == 0, [scene.outcome, Vices.hold])
	_check("the town wakes up", folk.dosed.is_empty() and not _iris_swirl(folk.people["kit"]), folk.dosed.keys())
	_check("Marrow's gone", run_node.zone_info["marrow_figures"].all(func(f): return not f.visible), "")
	_check("no more Glass, no more earpiece", not Glass.on_sale() and not Glass.tethered(), "")
	player.global_position = _spot("hush_alley")["pos"]
	await _ticks(2)
	_check("the alley's empty", run_node._prompt() == "Nobody here anymore", run_node._prompt())

	# It saves.
	Glass.used = 7
	Glass.save()
	Glass.reset()
	Glass.open(Glass.save_path)
	_check("saved", Glass.broken and Glass.used == 7 and Glass.ledger and Glass.earpiece, Glass.used)

	Vices.reset()
	Glass.reset()
	print("glass_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _glass_node(id: String) -> Node3D:
	return run_node.zone_info["glass_nodes"][id]


func _spot(id: String) -> Dictionary:
	for spot in run_node.zone_info["interactables"]:
		if spot["id"] == id:
			return spot
	return {}


func _iris_swirl(p: Node) -> bool:
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name.ends_with("_iris"):
				var mine := mi.get_surface_override_material(i) as ShaderMaterial
				return mine != null and mine.get_shader_parameter("iris_swirl") == true
	return false


func _seconds(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
