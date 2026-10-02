extends SceneTree
## Headless test for Eco's armory and the hub workbenches, and the materials
## that pay for them: the rules (prices, upgrades, attachments, titan parts,
## refits, what a run banks), the bench screens changing what you carry, and
## collecting scrap, alloy and circuits out in a run.
## Run: godot --headless --path . -s res://tests/armory_test.gd

const Armory := preload("res://scripts/hub/armory.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const WeaponScript := preload("res://scripts/weapon.gd")

const PATH := "user://test_armory.cfg"

var run_node
var player
var failures := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_rules()
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4242
	run_node.armory_path = PATH
	root.add_child(run_node)
	_run.call_deferred()


func _rules() -> void:
	var a = Armory.open(PATH)
	_check("starts with Eco's stash", a.stash == Armory.STARTING_STASH and a.equipped == "smart_pistol", a.stash)

	# The default pistol is weapon.gd's own numbers, untouched.
	var w = WeaponScript.new()
	var stock: Dictionary = a.weapon_profile("smart_pistol")["stats"]
	var same := true
	for key in stock:
		if not is_equal_approx(float(w.get(key)), float(stock[key])):
			same = false
	w.free()
	_check("stock smart pistol matches weapon.gd", same, stock)

	# Upgrades: modest, capped, paid for.
	_check("can't buy a gun you can't afford", not a.buy_weapon("rivet_cannon") and not a.owns_weapon("rivet_cannon"), a.stash)
	a.stash = {"scrap": 2000, "alloy": 2000, "circuits": 200}
	for i in 4:
		a.buy_upgrade("smart_pistol", "calibre")
	var up: Dictionary = a.weapon_profile("smart_pistol")
	_check("calibre caps at level 3", a.upgrade_level("smart_pistol", "calibre") == Armory.MAX_LEVEL, a.upgrade_level("smart_pistol", "calibre"))
	_check("maxed calibre is +18%", is_equal_approx(up["stats"]["damage"], 20.0 * 1.18), up["stats"]["damage"])
	_check("upgrades move the look tier", up["tier"] == 2, up["tier"])
	for track in ["action", "magazine"]:
		for i in 3:
			a.buy_upgrade("smart_pistol", track)
	up = a.weapon_profile("smart_pistol")
	_check("a maxed gun is the top model tier", up["tier"] == Armory.MODEL_TIERS, up["tier"])
	_check("magazine +3 rounds when maxed", up["stats"]["magazine_size"] == 11, up["stats"]["magazine_size"])

	# Attachments: trade-offs, and mags round to whole rounds.
	var before: int = a.amount("scrap")
	_check("fitting a locked attachment buys it", a.fit("smart_pistol", "mag", "extended") and a.amount("scrap") < before, a.stash)
	var ext: Dictionary = a.weapon_profile("smart_pistol")["stats"]
	_check("extended mag: more rounds, slower reload", ext["magazine_size"] == 15 and ext["reload_time"] > up["stats"]["reload_time"], ext)
	a.fit("smart_pistol", "muzzle", "long_barrel")
	var lb: Dictionary = a.weapon_profile("smart_pistol")["stats"]
	_check("long barrel: more range, slower shots", lb["falloff_end"] > ext["falloff_end"] and lb["fire_interval"] > ext["fire_interval"], lb)
	_check("owned attachments are free to refit elsewhere", a.buy_weapon("machine_pistol") and a.fit("machine_pistol", "mag", "extended"), a.fitted)

	# Titan: starting parts are Mk I, refits scale every copy, scrap included.
	_check("buy a starting chassis", a.set_start_part("chassis", "ogre") and a.start_parts()["chassis"]["tier"] == 1, a.titan_loadout)
	var plain: float = TitanParts.assemble(a.start_parts(), a.refit_bonus())["hp"]
	a.buy_refit("chassis", "ogre")
	a.buy_refit("weapon", "scrap")
	var stats: Dictionary = TitanParts.assemble(a.start_parts(), a.refit_bonus())
	_check("refit adds armour", is_equal_approx(stats["hp"], plain * (1.0 + Armory.REFIT_STEP)), stats["hp"])
	_check("scrap weapon can be refitted", is_equal_approx(stats["dps"], TitanParts.SCRAP["weapon"]["dps"] * (1.0 + Armory.REFIT_STEP)), stats["dps"])

	# What a run banks.
	_check("lost run banks half", Armory.run_haul({"scrap": 11, "alloy": 4, "circuits": 1}, false) == {"scrap": 5, "alloy": 2, "circuits": 0}, "")
	_check("won run banks it all plus titan salvage", Armory.run_haul({"scrap": 10}, true)["scrap"] == 10 + Armory.WIN_BONUS["scrap"], "")

	# It all survives a save and load.
	a.equip("machine_pistol")
	var b = Armory.open(PATH)
	_check("armory saves and loads", b.equipped == "machine_pistol" and b.upgrade_level("smart_pistol", "magazine") == 3 \
			and b.fitted_attachment("smart_pistol", "muzzle") == "long_barrel" and b.titan_loadout["chassis"] == "ogre" and b.stash == a.stash, b.stash)


func _run() -> void:
	await _ticks(30)
	player = run_node.player
	var weapon = player.get_node("Head/Camera3D/Weapon")
	_check("the gun picked at the rack is in hand", weapon.weapon_id == "machine_pistol" and weapon.automatic and weapon.viewmodel.get_child(0).name == "MachinePistol", weapon.weapon_id)

	# Weapon rack: switch back to the smart pistol.
	run_node.open_bench("rack")
	await _ticks(2)
	var bench = run_node.bench
	bench.select(0)
	_check("rack: pick the smart pistol", bench.confirm() and run_node.armory.equipped == "smart_pistol", run_node.armory.equipped)
	run_node.close_bench()
	await _ticks(2)
	_check("closing the rack puts it in hand", weapon.weapon_id == "smart_pistol" and weapon.smart and not weapon.automatic, weapon.weapon_id)
	_check("upgrades and attachments carried into the hand", weapon.magazine_size == 15 and is_equal_approx(weapon.damage, 20.0 * 1.18), [weapon.magazine_size, weapon.damage])
	_check("the long barrel is on the gun", weapon.viewmodel.find_child("Attachment_muzzle", true, false) != null, "")

	# Gunsmith: browse a grip on and finish.
	run_node.open_bench("gunsmith")
	await _ticks(2)
	bench = run_node.bench
	bench.switch_tab(1)
	bench.select(2)
	bench.step(1)  # wrap (locked) -> shown, not fitted
	var locked: bool = run_node.armory.fitted_attachment("smart_pistol", "grip") == "stock"
	_check("gunsmith: a locked grip needs buying", locked and bench.confirm() and run_node.armory.fitted_attachment("smart_pistol", "grip") == "wrap", run_node.armory.fitted)
	bench.select(3)
	bench.step(1)
	_check("gunsmith: finish changes", run_node.armory.finish_of("smart_pistol") != "dads", run_node.armory.finish_of("smart_pistol"))
	run_node.close_bench()

	# Workshop: the titan on the gantry is the one you'd start with.
	var stand: Node3D = run_node.zone_info["workshop_titan"]
	_check("workshop shows the starting titan", stand.get_child_count() == 1, stand.get_child_count())

	# Out on a run: start parts are installed, loot is laid out.
	run_node.armory.stash = {"scrap": 0, "alloy": 0, "circuits": 0}
	run_node.start_run(4242)
	await _ticks(10)
	var run = run_node.run
	_check("run starts with the ogre chassis", run.parts.get("chassis", {}).get("id", "") == "ogre", run.parts.keys())
	var loot: Array = run_node.zone_info["loot"].filter(func(n): return is_instance_valid(n))
	var crates := loot.filter(func(n): return n.has_method("open"))
	var nodes := loot.filter(func(n): return n.has_method("mine"))
	_check("forest has crates and alloy nodes", crates.size() >= 4 and nodes.size() >= 2, [crates.size(), nodes.size()])

	# A crate: F pries it open, the pickups come to her.
	var crate: Node3D = crates[0]
	await _stand_at(crate.global_position + Vector3(1.5, 0, 0))
	_check("crate prompt", run_node.hud.prompt_label.text == crate.prompt(), run_node.hud.prompt_label.text)
	await _press("interact")
	await _ticks(90)
	_check("crate opened and its scrap collected", crate.opened and run.materials["scrap"] >= 6, run.materials)

	# A node: hold F to mine it out.
	var node: Node3D = nodes[0]
	await _stand_at(node.global_position + Vector3(2.0, 0, 0))
	_check("node prompt", run_node.hud.prompt_label.text == node.prompt(), run_node.hud.prompt_label.text)
	Input.action_press("interact")
	await _ticks(260)  # 120 physics ticks a second: a bit over MINE_TIME
	Input.action_release("interact")
	await _ticks(90)
	_check("node mined and its alloy collected", node.depleted and run.materials["alloy"] >= 8, run.materials)

	# A grunt: dies, drops scrap.
	var grunt = run_node.zone_info["grunts"][0]
	var scrap_before: int = run.materials["scrap"]
	await _stand_at(grunt.global_position + Vector3(2.0, 0, 0))
	grunt.take_damage(9999.0, grunt.global_position, false)
	await _ticks(90)
	_check("a dead grunt drops scrap", run.materials["scrap"] > scrap_before and run.kills == 1, run.materials)

	# Lose the run: half of it is banked.
	var carried: Dictionary = run.materials.duplicate()
	run_node.end_run("PILOT KIA", "Test.")
	var banked: Dictionary = Armory.run_haul(carried, false)
	_check("lost run banks half of what she carried", run_node.armory.stash == banked, [run_node.armory.stash, carried])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _stand_at(pos: Vector3) -> void:
	player.global_position = pos + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	await _ticks(6)


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
