extends SceneTree
## Headless test for Eco's suit upgrades: the tiers' rules (bought in order,
## paid for, saved), armour soaking hits before health and coming back, the
## passives (loot magnet, quicker regen, slower grunt notice, longer wallruns,
## the second wind), the armour pieces showing on her model tier by tier, and
## the suit locker in the hub.
## Run: godot --headless --path . -s res://tests/suit_test.gd

const Armory := preload("res://scripts/hub/armory.gd")
const ECO := preload("res://assets/models/eco.tscn")

const PATH := "user://test_suit.cfg"

var run_node
var failures := 0


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_rules()
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 77
	run_node.armory_path = PATH
	root.add_child(run_node)
	_run.call_deferred()


func _rules() -> void:
	var a = Armory.open(PATH)
	_check("starts in the bare suit", a.suit_tier == 0 and a.suit_profile()["max_armor"] == 0.0, a.suit_tier)
	a.stash = {"scrap": 0, "alloy": 0, "circuits": 0, "lock_cores": 0}
	_check("can't buy a tier you can't afford", not a.buy_suit_tier() and a.suit_tier == 0, a.stash)
	a.stash = {"scrap": 5000, "alloy": 5000, "circuits": 500, "lock_cores": 0}
	for i in 4:
		a.buy_suit_tier()
	_check("tiers buy in order", a.suit_tier == 4, a.suit_tier)
	_check("Dad's Colours needs a lock core", not a.buy_suit_tier() and a.suit_tier == 4, a.stash)
	a.stash["lock_cores"] = 1
	_check("top tier", a.buy_suit_tier() and a.suit_tier == 5 and not a.buy_suit_tier(), a.suit_tier)
	var spent := 0
	for t in Armory.SUIT_TIERS:
		spent += int(t["cost"].get("scrap", 0))
	_check("every tier paid for", a.amount("scrap") == 5000 - spent, a.stash)
	var armour := []
	for t in Armory.SUIT_TIERS:
		armour.append(t["armor"])
	_check("each tier adds armour", armour == [20, 40, 60, 80, 100], armour)
	var p0 := Armory.suit_profile_for(0)
	var p5: Dictionary = a.suit_profile()
	_check("bare suit has no passives", p0["loot_magnet"] == 1.0 and p0["regen_delay"] == 3.0 and p0["notice_mult"] == 1.0 and not p0["second_wind"], p0)
	var light := Armory.suit_profile_for(5, "light")
	var heavy := Armory.suit_profile_for(5, "heavy")
	_check("weights scale armour", light["max_armor"] == 50.0 and heavy["max_armor"] == 160.0, [light["max_armor"], heavy["max_armor"]])
	_check("weight bonuses", light["speed_mult"] == 1.1 and heavy["speed_mult"] == 0.9 and heavy["damage_mult"] == 0.85 \
			and p5["armor_regen_mult"] == 2.0 and is_equal_approx(light["notice_mult"], 0.7 * 0.85), [light, heavy])
	_check("the bare suit has no weight bonus", Armory.suit_profile_for(0, "heavy")["speed_mult"] == 1.0, "")
	_check("weight saves", a.set_suit_weight("heavy") and Armory.open(PATH).suit_weight == "heavy", "")
	a.set_suit_weight("medium")
	_check("tier 5 has every passive", p5["loot_magnet"] == 2.0 and p5["regen_delay"] == 2.0 and p5["notice_mult"] == 0.7 \
			and p5["wallrun_time_mult"] == 1.4 and p5["grapple_cooldown_mult"] == 0.7 and p5["second_wind"] and p5["max_armor"] == 100.0, p5)
	var b = Armory.open(PATH)
	_check("suit tier saves and loads", b.suit_tier == 5, b.suit_tier)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _model() -> void:
	var eco = ECO.instantiate()
	root.add_child(eco)
	await process_frame
	var pieces: Array = eco.find_children("suit_t*", "MeshInstance3D", true, false)
	var tiers := {}
	for p in pieces:
		tiers[eco.piece_tier(String(p.name))] = true
	_check("armour pieces for all 5 tiers in the model", tiers.keys().size() == 5 and pieces.size() >= 20, tiers.keys())
	_check("bare suit hides all armour", pieces.all(func(p): return not p.visible), "")
	eco.suit_tier = 3
	var shown: Array = pieces.filter(func(p): return p.visible)
	_check("tier 3 shows tiers 1-3 only", not shown.is_empty() and shown.all(func(p): return eco.piece_tier(String(p.name)) <= 3) \
			and shown.size() == pieces.filter(func(p): return eco.piece_tier(String(p.name)) <= 3 and eco.piece_worn(String(p.name), "medium")).size(), shown.size())
	_check("tier 3 plates are gunmetal", pieces[0].get_surface_override_material(0) == null, "")
	eco.suit_tier = 5
	var worn_by := func() -> Array:
		return pieces.filter(func(p): return p.visible).map(func(p): return String(p.name).substr(7, 1))
	for w in ["light", "medium", "heavy"]:
		eco.suit_weight = w
		var marks: Array = worn_by.call()
		_check("%s wears its own pieces and the shared ones only" % w, w[0] in marks and "_" in marks \
				and marks.all(func(c): return c == w[0] or not c in ["l", "m", "h"]), marks)
	eco.suit_weight = "medium"
	_check("medium has its own mechanic's rig", eco.find_child("suit_t2m_scarf", true, false).visible \
			and eco.find_child("suit_t1m_wristcomp", true, false).visible and eco.find_child("suit_t4m_bedroll", true, false).visible, "")
	eco.suit_weight = "light"
	_check("light wears a brow bar and a low belt", eco.find_child("suit_t1l_brow", true, false).visible \
			and eco.find_child("suit_t1l_belt", true, false).visible and not eco.find_child("suit_t1m_belt", true, false).visible, "")
	var body_mesh: MeshInstance3D = null
	var body_surface := -1
	for mi in eco.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i) != null and mi.mesh.surface_get_material(i).resource_name == "eco_v_body":
				body_mesh = mi
				body_surface = i
	var face: MeshInstance3D = eco.find_child("Face", true, false)
	var makeup := func() -> Material:
		for i in face.mesh.get_surface_count():
			var m := face.mesh.surface_get_material(i)
			if m != null and m.resource_name == "eco_v_face":
				return face.get_surface_override_material(i)
		return null
	for w in ["light", "medium", "heavy"]:
		eco.suit_weight = w
		var kit: Material = body_mesh.get_surface_override_material(body_surface) if body_mesh != null else null
		_check("%s changes her suit over its own" % w, kit != null and kit.get_shader_parameter("use_kit") \
				and kit.get_shader_parameter("kit_tex") == eco.KIT_TEX[w][0] \
				and kit.get_shader_parameter("albedo_tex") == eco.GWEN_BODY.get_shader_parameter("albedo_tex"), body_surface)
		_check("%s has its own makeup" % w, makeup.call() == eco.KIT_FACE[w], makeup.call())
		var squeeze := body_mesh.find_blend_shape_by_name(&"kit_squeeze")
		_check("%s %s her thighs" % [w, "squeezes" if w == "light" else "leaves"], squeeze >= 0 \
				and body_mesh.get_blend_shape_value(squeeze) == (1.0 if w == "light" else 0.0), squeeze)
	_check("heavy has its breastplate and core", eco.find_child("suit_t1h_breastplate", true, false).visible \
			and eco.find_child("suit_t5h_core", true, false).visible, "")
	eco.suit_tier = 0
	_check("the bare suit wears the plain bodysuit and makeup", body_mesh.get_surface_override_material(body_surface) == null \
			and makeup.call() == null, "")
	eco.suit_tier = 5
	var plate: MeshInstance3D = eco.find_child("suit_t1h_bracer_l", true, false)
	_check("tier 5 repaints the plates in Dad's colours", plate.get_surface_override_material(0) == eco.LEGACY_PLATE, "")
	_check("tier 5 turns the trims gold", plate.get_instance_shader_parameter("trim_gold") == 1.0, "")
	eco.free()


func _run() -> void:
	await _model()
	await _ticks(20)
	var player = run_node.player
	var armory = run_node.armory
	armory.stash = {"scrap": 5000, "alloy": 5000, "circuits": 500, "lock_cores": 5}

	# The suit locker in the hub.
	var spot: Dictionary = {}
	for s in run_node.zone_info["interactables"]:
		if s.get("screen", "") == "suit":
			spot = s
	_check("hub has a suit locker", not spot.is_empty(), "")
	run_node.open_bench("suit")
	await _ticks(2)
	var bench = run_node.bench
	_check("locker shows the kit and its 5 sessions", bench.weight == "medium" and bench._cards.get_child_count() == 6, bench._cards.get_child_count())
	bench.set_kit("heavy")
	_check("no refit without a suit tier", armory.suit_weight == "medium" and bench.weight == "heavy", armory.suit_weight)
	bench.set_kit("medium")
	bench.select(3)
	_check("can't skip ahead to tier 3", not bench.confirm() and armory.suit_tier == 0, armory.suit_tier)
	_check("tier 3 closes in on her legs", bench.focus()["part"] == "KNEES AND THIGH" and bench.focus()["dist"] < 3.0, bench.focus())
	bench.select(1)
	_check("buy tier 1", bench.confirm() and armory.suit_tier == 1, armory.suit_tier)
	bench.select(2)
	_check("buy tier 2", bench.confirm() and armory.suit_tier == 2, armory.suit_tier)
	await _ticks(2)
	_check("the preview wears the browsed tier", bench.eco.suit_tier == 2, bench.eco.suit_tier)
	bench.switch_kit(1)
	_check("weight: heavy", armory.suit_weight == "heavy", armory.suit_weight)
	await _ticks(2)
	_check("the preview wears the kit", bench.eco.suit_weight == "heavy" and bench.eco.suit_tier == 2, bench.eco.suit_weight)
	bench.select(0)
	_check("the kit's overview shows all of her", bench.focus()["dist"] > 3.0 and bench.eco.suit_tier == 2, bench.focus())
	run_node.close_bench()
	await _ticks(2)
	_check("heavy: more armour, softer hits, slower", player.max_armor == 64.0 and player.damage_mult == 0.85 and player.suit_speed == 0.9, [player.max_armor, player.damage_mult])
	armory.set_suit_weight("light")
	run_node.equip_loadout()
	_check("light: less armour, faster", player.max_armor == 20.0 and player.suit_speed == 1.1 and is_equal_approx(player.notice_mult, 0.85), [player.max_armor, player.suit_speed])
	armory.set_suit_weight("medium")
	run_node.equip_loadout()
	_check("closing the locker puts the suit on", player.max_armor == 40.0 and player.armor == 40.0 and player.regen_delay == 2.0 and player.loot_magnet == 2.0, [player.max_armor, player.armor])
	var fp = player.get_node("EcoBody")
	_check("her own body wears it too", fp.shadow == null or fp.shadow.suit_tier == 2, "")

	# Armour soaks hits before health, then comes back after health.
	player.take_damage(30.0)
	_check("armour takes the hit", player.armor == 10.0 and player.health == player.max_health, [player.armor, player.health])
	player.take_damage(30.0)
	_check("the rest goes to health", player.armor == 0.0 and is_equal_approx(player.health, player.max_health - 20.0), [player.armor, player.health])
	await _ticks(int(120 * 4.5))
	_check("health then armour come back", player.health == player.max_health and player.armor > 0.0, [player.health, player.armor])

	# Up to Dad's Colours: dampers, jump kit, second wind.
	for i in 3:
		armory.buy_suit_tier()
	run_node.equip_loadout()
	_check("dampers and jump kit", is_equal_approx(player.notice_mult, 0.7) and is_equal_approx(player.wallrun_max_time, 1.8 * 1.4) and is_equal_approx(player.grapple_cooldown, 2.5 * 0.7), [player.notice_mult, player.wallrun_max_time])
	run_node.equip_loadout()
	_check("equipping again doesn't stack", is_equal_approx(player.wallrun_max_time, 1.8 * 1.4), player.wallrun_max_time)
	var downed := [false]
	player.died.connect(func(): downed[0] = true)
	player.second_wind_ready = true
	player.take_damage(1000.0)
	_check("second wind keeps her up", not downed[0] and player.health == 1.0 and player.untouchable_timer > 0.0, player.health)
	player.take_damage(50.0)
	_check("untouchable right after", player.health == 1.0, player.health)
	player.untouchable_timer = 0.0
	player.armor = 0.0
	player.take_damage(1000.0)
	_check("only once", downed[0], player.health)

	# Out on a run the second wind is ready again in each zone.
	run_node.start_run(77)
	await _ticks(10)
	_check("second wind ready in the zone", run_node.player.second_wind_ready, "")
	var grunt = run_node.zone_info["grunts"][0]
	_check("grunts see the dampers", grunt.target.get("notice_mult") == 0.7, "")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(failures)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	if not ok:
		failures += 1
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, value])
