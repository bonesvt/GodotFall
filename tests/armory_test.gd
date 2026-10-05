extends SceneTree
## Headless test for Eco's armory and the hub workbenches, and the materials
## that pay for them: the rules (prices, upgrades, attachments, titan parts,
## refits, what a run banks), the bench screens changing what you carry (the
## knife case included: the picked knife is saved and is the one in her hand),
## and collecting scrap, alloy and circuits out in a run.
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
	# Hints go to their own settings file, so these runs never mark them seen on your save.
	preload("res://scripts/run/tutorial.gd").settings_path = "user://test_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 4242
	run_node.armory_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
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
	var sp_s: Dictionary = Armory.WEAPONS["smart_pistol"]["stats"]
	var rv_s: Dictionary = Armory.WEAPONS["rivet_cannon"]["stats"]
	var ah_s: Dictionary = Armory.WEAPONS["machine_pistol"]["stats"]
	_check("guns keep their spread character", rv_s["base_spread"] < sp_s["base_spread"] and sp_s["base_spread"] < ah_s["base_spread"] \
			and rv_s["bloom_per_shot"] > sp_s["bloom_per_shot"] and sp_s["bloom_per_shot"] > ah_s["bloom_per_shot"] \
			and sp_s["max_bloom"] <= 3.0 and rv_s["max_bloom"] <= 4.0 and ah_s["max_bloom"] <= 3.7, [sp_s, rv_s, ah_s])

	# Upgrades: each gun its own, capped, paid for.
	_check("starts at level 1", a.pilot_level() == 1 and a.next_unlock() == "rivet_cannon", a.pilot_level())
	_check("hand cannon is locked below level 3", not a.buy_weapon("rivet_cannon") and not a.owns_weapon("rivet_cannon") and not a.equip("rivet_cannon"), a.stash)
	a.stash = {"scrap": 2000, "alloy": 2000, "circuits": 200, "lock_cores": 0}
	_check("smart pistol's only upgrade is smart rounds", Armory.upgrade_tracks("smart_pistol") == ["smart_rounds"] and Armory.max_level("smart_rounds") == 8, Armory.upgrade_tracks("smart_pistol"))
	_check("no hand cannon upgrades on the smart pistol", not a.buy_upgrade("smart_pistol", "rivet_heads"), a.upgrades)
	_check("smart rounds need lock cores", not a.buy_upgrade("smart_pistol", "smart_rounds"), a.stash)
	a.stash["lock_cores"] = 20
	for i in 4:
		a.buy_upgrade("smart_pistol", "smart_rounds")
	var up: Dictionary = a.weapon_profile("smart_pistol")
	_check("level 5: hand cannon unlocked, auto handgun not yet", a.pilot_level() == 5 and a.owns_weapon("rivet_cannon") and not a.owns_weapon("machine_pistol"), a.pilot_level())
	_check("4 levels: half the mag is smart", is_equal_approx(up["stats"]["smart_fraction"], 0.5), up["stats"]["smart_fraction"])
	_check("smart rounds move the look tier", up["tier"] == 3, up["tier"])
	_check("lock cores spent", a.amount("lock_cores") == 16, a.stash)
	for i in 6:
		a.buy_upgrade("smart_pistol", "smart_rounds")
	up = a.weapon_profile("smart_pistol")
	_check("every upgrade raises Eco's level", a.pilot_level() == 1 + 8, a.pilot_level())
	_check("level 6+ unlocks the hand cannon and auto handgun", a.owns_weapon("rivet_cannon") and a.owns_weapon("machine_pistol") and a.next_unlock() == "", [a.owns_weapon("rivet_cannon"), a.owns_weapon("machine_pistol")])
	_check("unlocks between levels", Armory.unlocks_between(2, 6) == ["rivet_cannon", "machine_pistol"] and Armory.unlocks_between(1, 2).is_empty(), Armory.unlocks_between(2, 6))
	_check("smart rounds cap at 8", a.upgrade_level("smart_pistol", "smart_rounds") == 8 and is_equal_approx(up["stats"]["smart_fraction"], 1.0), a.upgrade_level("smart_pistol", "smart_rounds"))
	_check("a maxed gun is the top model tier", up["tier"] == Armory.MODEL_TIERS, up["tier"])
	_check("smart rounds add no damage or rounds", is_equal_approx(up["stats"]["damage"], 20.0) and up["stats"]["magazine_size"] == 8, up["stats"])
	_check("all 8 levels cost 13 lock cores", a.amount("lock_cores") == 7, a.stash)
	a.stash["lock_cores"] = 0
	# Each gun's own set.
	_check("every gun has its own upgrades", Armory.upgrade_tracks("rivet_cannon") == ["rivet_heads", "punch_through", "stagger_coils", "speed_loader"] \
			and Armory.upgrade_tracks("machine_pistol") == ["drum_feed", "recoil_buffer", "overclock", "hot_streak"], "")
	_check("no auto handgun upgrades on the hand cannon", not a.buy_upgrade("rivet_cannon", "drum_feed"), a.upgrades)
	for track in ["rivet_heads", "punch_through", "punch_through", "stagger_coils"]:
		a.buy_upgrade("rivet_cannon", track)
	var rv: Dictionary = a.weapon_profile("rivet_cannon")["stats"]
	_check("hand cannon: heavier rounds, two through, stagger", is_equal_approx(rv["damage"], 42.0 * 1.1) and is_equal_approx(rv["headshot_multiplier"], 2.2) \
			and is_equal_approx(rv["pierce"], 2.0) and is_equal_approx(rv["stagger"], 0.35) and rv["smart_fraction"] == 0.0, rv)
	for track in ["drum_feed", "overclock", "recoil_buffer", "hot_streak"]:
		a.buy_upgrade("machine_pistol", track)
	var ah: Dictionary = a.weapon_profile("machine_pistol")["stats"]
	_check("auto handgun: more rounds, faster, softer, hot streak", ah["magazine_size"] == 30 and ah["fire_interval"] < 0.066 \
			and ah["recoil_kick"] < 0.55 and is_equal_approx(ah["streak_bonus"], 0.025) and ah["pierce"] == 0.0, ah)

	# Attachments: trade-offs, and mags round to whole rounds.
	var before: int = a.amount("scrap")
	_check("fitting a locked attachment buys it", a.fit("smart_pistol", "mag", "extended") and a.amount("scrap") < before, a.stash)
	var ext: Dictionary = a.weapon_profile("smart_pistol")["stats"]
	_check("extended mag: more rounds, slower reload", ext["magazine_size"] == 11 and ext["reload_time"] > up["stats"]["reload_time"], ext)
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
	_check("lost run banks half, but keeps lock cores", Armory.run_haul({"scrap": 11, "alloy": 4, "circuits": 1, "lock_cores": 1}, false) == {"scrap": 5, "alloy": 2, "circuits": 0, "lock_cores": 1}, "")
	_check("won run banks it all plus titan salvage", Armory.run_haul({"scrap": 10}, true)["scrap"] == 10 + Armory.WIN_BONUS["scrap"], "")

	# Knives: all three hers, the Needle by default; the pick is free and saved.
	_check("carries the Needle by default", a.knife == "needle" and Armory.DEFAULT_KNIFE == "needle" and Armory.KNIVES.keys() == ["needle", "kunai", "butterfly"], a.knife)
	_check("picks the Plate Kunai", a.set_knife("kunai") and a.knife == "kunai" and a.stash == Armory.open(PATH).stash, a.knife)
	_check("no knife that doesn't exist", not a.set_knife("spork") and a.knife == "kunai", a.knife)
	var odd := ConfigFile.new()
	odd.set_value("weapons", "knife", "spork")
	odd.save("user://test_armory_knife.cfg")
	_check("an unknown saved knife falls back to the Needle", Armory.open("user://test_armory_knife.cfg").knife == "needle", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_armory_knife.cfg"))

	# It all survives a save and load.
	a.equip("machine_pistol")
	var b = Armory.open(PATH)
	_check("armory saves and loads", b.equipped == "machine_pistol" and b.upgrade_level("smart_pistol", "smart_rounds") == 8 \
			and b.fitted_attachment("smart_pistol", "muzzle") == "long_barrel" and b.titan_loadout["chassis"] == "ogre" and b.stash == a.stash and b.knife == "kunai", b.stash)


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
	_check("upgrades and attachments carried into the hand", weapon.magazine_size == 11 and weapon.smart_left == 11 and is_equal_approx(weapon.damage, 20.0), [weapon.magazine_size, weapon.smart_left, weapon.damage])
	_check("the long barrel is on the gun", weapon.viewmodel.find_child("Attachment_muzzle", true, false) != null, "")

	# Knife case: the saved knife is in her hand and on show; picking another
	# puts it in her hand and moves the tag.
	var knife = player.get_node("Head/Camera3D/Knife")
	_check("the saved knife is in her other hand", knife.model_id == "kunai" and knife.model != null and knife.model.name == "Knife_kunai" \
			and knife.model.find_child("Kunai", true, false) != null, knife.model_id)
	var slots: Array = run_node.zone_info.get("knife_slots", [])
	_check("the case shows all three knives", slots.size() == 3 and slots.all(func(s): return s != null and s.get_child_count() == 2), slots)
	run_node.open_bench("knives")
	await _ticks(2)
	bench = run_node.bench
	_check("knife case: lists the three, the carried one marked", bench.kind == "knives" and bench.rows.size() == 3 \
			and bench.rows[1]["state"] == "CARRIED" and bench.rows[0]["state"] == "" and bench.rows[2]["note"] != "", bench.rows.map(func(r): return r["state"]))
	bench.select(2)
	_check("knife case: shows the knife you're on", bench._preview_key == "knife/butterfly" and bench._turntable.get_child_count() == 1, bench._preview_key)
	_check("knife case: pick the Butterfly", bench.confirm() and run_node.armory.knife == "butterfly" and bench.rows[2]["state"] == "CARRIED", run_node.armory.knife)
	run_node.close_bench()
	await _ticks(2)
	_check("closing the case puts the Butterfly in her hand", knife.model_id == "butterfly" and knife.model.find_child("BiteHandle", true, false) != null \
			and knife.find_children("Knife_*", "", true, false).size() == 1, knife.model_id)
	_check("the trail comes off the Butterfly's shorter point", knife._tip.position.z < -0.2 and knife._tip.position.z > -0.3, knife._tip.position)
	_check("the case tags the Butterfly as carried", (slots[2].get_child(1) as Label3D).text == "CARRIED" and (slots[1].get_child(1) as Label3D).text != "CARRIED", "")
	_check("the pick is saved", Armory.open(PATH).knife == "butterfly", "")
	# The Butterfly comes out closed and flips open: its handles move on the
	# draw and are shut round the tang (the grip) again after.
	var bite: Node3D = knife.model.find_child("BiteHandle", true, false)
	var rest: Basis = bite.basis
	knife._play("draw")
	knife.anim_time = 0.2
	knife._process(0.0)
	var mid: Basis = bite.basis
	knife.anim_time = 10.0
	knife._process(0.0)
	_check("the Butterfly's handle swings on the draw and shuts after", not mid.is_equal_approx(rest) and bite.basis.is_equal_approx(rest) and knife.anim == "", "")

	# Gunsmith: the gun in 3D with clickable parts. Grip, then paint.
	run_node.open_bench("gunsmith")
	await _ticks(3)
	bench = run_node.bench
	_check("gunsmith: opens on the gun in hand", bench.weapon == "smart_pistol" and bench._model != null, bench.weapon)
	var spot = bench.spot_position("module")
	_check("gunsmith: part markers sit on screen", spot is Vector2 and Rect2(0, 0, 1600, 900).has_point(spot), spot)
	bench.select_part("grip")
	var wrap: int = bench.options.map(func(o): return o["id"]).find("wrap")
	_check("gunsmith: the first click on a locked grip only previews it", wrap >= 0 and not bench.choose(wrap) and run_node.armory.fitted_attachment("smart_pistol", "grip") == "stock", run_node.armory.fitted)
	_check("gunsmith: the second click buys and fits it", bench.choose(wrap) and run_node.armory.fitted_attachment("smart_pistol", "grip") == "wrap", run_node.armory.fitted)
	bench.select_part("shell")
	var paint: int = bench.options.map(func(o): return o["id"]).find(Armory.FINISHES[1]["id"])
	_check("gunsmith: finish changes", bench.choose(paint) and run_node.armory.finish_of("smart_pistol") != "dads", run_node.armory.finish_of("smart_pistol"))
	_check("gunsmith: locked guns can't be picked", not bench.select_weapon("machine_pistol") or run_node.armory.owns_weapon("machine_pistol"), bench.weapon)
	run_node.close_bench()

	# Workshop: the titan on the gantry is the one you'd start with.
	var stand: Node3D = run_node.zone_info["workshop_titan"]
	_check("workshop shows the starting titan", stand.get_child_count() == 1, stand.get_child_count())

	# Out on a run: start parts are installed, loot is laid out.
	run_node.armory.stash = {"scrap": 0, "alloy": 0, "circuits": 0, "lock_cores": 0}
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

	# Smart rounds: a dumb round aimed off a grunt misses; a smart one locks
	# on and hits it anyway.
	var mark = run_node.zone_info["grunts"][1]
	mark.passive = true
	# Somewhere open: the spawn, with the grunt brought over 9 m off.
	await _stand_at(run_node.zone_info["spawn"])
	mark.global_position = player.global_position + Vector3(9.0, 0, 0)
	await _ticks(10)
	_aim_near(mark, 8.0)
	var hp: float = mark.health
	weapon.smart_left = 0
	await _ticks(30)
	_check("dumb round: the lock only pretends", not weapon.is_locked(), weapon.lock_target)
	weapon.cooldown = 0.0
	weapon.fire()
	_check("dumb round aimed off the grunt misses", is_equal_approx(mark.health, hp), mark.health)
	weapon.refill()
	_aim_near(mark, 8.0)
	await _ticks(60)
	_check("smart round locks on", weapon.is_locked() and weapon.lock_target == mark, weapon.lock_target)
	weapon.cooldown = 0.0
	weapon.fire()
	_check("smart round homes in on the body", mark.health < hp and weapon.smart_left == weapon.magazine_size - 1, [mark.health, weapon.smart_left])
	run_node.hud.crosshair.queue_redraw()
	await process_frame

	# Hand cannon: punch-through goes on into the grunt behind, and a hit
	# knocks a grunt's wound-up shot away.
	var back = run_node.zone_info["grunts"][2]
	back.passive = true
	mark.global_position = player.global_position + Vector3(6.0, 0, 0)
	back.global_position = player.global_position + Vector3(10.0, 0, 0)
	run_node.armory.equip("rivet_cannon")
	run_node.equip_loadout()
	await _ticks(4)
	for g in [mark, back]:
		g.health = 9999.0
	weapon.base_spread = 0.0
	weapon.bloom = 0.0
	weapon.pierce = 1.0
	weapon.stagger = 0.35
	mark.windup_timer = 0.3
	_aim_near(mark, 0.0)
	weapon.cooldown = 0.0
	weapon.fire()
	_check("punch-through: one round hits both grunts", mark.health < 9999.0 and back.health < 9999.0 and 9999.0 - back.health < 9999.0 - mark.health, [mark.health, back.health])
	_check("stagger: the wound-up shot is lost", mark.windup_timer < 0.0 and mark.fire_timer >= 0.35, [mark.windup_timer, mark.fire_timer])
	weapon.pierce = 0.0
	back.health = 9999.0
	weapon.cooldown = 0.0
	weapon.fire()
	_check("no punch-through: the grunt behind is safe", back.health == 9999.0, back.health)

	# Auto handgun: hits in a row heat up, a miss cools it.
	run_node.armory.equip("machine_pistol")
	run_node.equip_loadout()
	await _ticks(4)
	weapon.base_spread = 0.0
	weapon.bloom_per_shot = 0.0
	weapon.recoil_kick = 0.0
	weapon.streak_bonus = 0.05
	mark.health = 9999.0
	_aim_near(mark, 0.0)
	var dealt := []
	for i in 4:
		var h: float = mark.health
		weapon.cooldown = 0.0
		weapon.fire()
		dealt.append(h - mark.health)
	_check("hot streak: each hit in a row hits harder", weapon.streak == 4 and dealt[3] > dealt[0] * 1.1, [weapon.streak, dealt])
	_aim_near(mark, 30.0)
	weapon.cooldown = 0.0
	weapon.fire()
	_check("hot streak: a miss resets it", weapon.streak == 0, weapon.streak)
	run_node.armory.equip("smart_pistol")
	run_node.equip_loadout()

	# A boss: beating it drops a lock core (kept even if the run is lost after).
	var cores_before: int = int(run.materials.get("lock_cores", 0))
	for m in Armory.BOSS_DROP:
		run_node.collect_material(m, Armory.BOSS_DROP[m])
	_check("a boss's drop is carried like any material", int(run.materials.get("lock_cores", 0)) == cores_before + 1, run.materials)

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
	_check("lost run banks half of what she carried", run_node.armory.stash == banked and banked["lock_cores"] == 1, [run_node.armory.stash, carried])

	# Beating the boss itself hands the lock core over.
	run_node.start_run(4243)
	await _ticks(10)
	run_node._on_boss_defeated()
	_check("beating a boss drops a lock core", int(run_node.run.materials.get("lock_cores", 0)) == 1, run_node.run.materials)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


## Points the pilot at `target`'s chest, `off` degrees to the side.
func _aim_near(target: Node3D, off: float) -> void:
	var d: Vector3 = (target.global_position + Vector3.UP * 1.0) - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z) + deg_to_rad(off)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


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
