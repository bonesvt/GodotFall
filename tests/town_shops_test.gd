extends SceneTree
## Headless test for Solace's open shops (town_shops.gd, town_shop_screen.gd,
## eco_extras.gd, town.gd): every shop has its screen and every date spot a
## place Ophelia has date lines for; meals last one run, implants for good,
## and both reach the player's stats; Sal's trades swap materials without
## counting as salvage; piercings, tattoos and accessories are bought, worn and
## taken off (one accessory per slot), and show on Eco's model: head pieces
## on her head bone, the tattoo texture on her body material, no goggles
## under a beanie; every shop screen opens and sells. Mature-only things
## (tattoos, piercings, the choker, firewater, the Rusted Halo date and the
## Mature cuts of Ophelia's dates) only show and sell under the Mature rating.
## Run: godot --headless --path . -s res://tests/town_shops_test.gd

const Shops := preload("res://scripts/hub/town_shops.gd")
const Screen := preload("res://scripts/hub/town_shop_screen.gd")
const Extras := preload("res://scripts/hub/eco_extras.gd")
const Town := preload("res://scripts/hub/town.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const ECO := preload("res://assets/models/eco.tscn")
const ARMORY_PATH := "user://test_town_armory.cfg"
const SHOP_PATH := "user://test_town.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for p in [ARMORY_PATH, SHOP_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Shops.save_path = SHOP_PATH
	preload("res://scripts/hub/wardrobe.gd").save_path = "user://test_town_wardrobe.cfg"

	# The town: screens and date spots.
	var town := Node3D.new()
	root.add_child(town)
	var info := {"interactables": []}
	Town.build(town, info)
	var screens := {}
	var dates := {}
	for spot in info["interactables"]:
		if spot.has("screen"):
			screens[spot["screen"]] = spot["id"]
		if spot.has("date"):
			dates[spot["date"]] = spot["id"]
	for kind in Screen.SHOPS:
		_check("%s has a counter in town" % kind, screens.has(kind), screens.keys())
	_check("Ink & Iron is on the plaza", screens.get("ink", "") == "shop_ink", screens)
	var f := FileAccess.open("res://dialogue/npc/ophelia.txt", FileAccess.READ)
	var bank := NpcTalk.parse(f.get_as_text())
	# the date cuts live in ophelia_M.txt, laid over ophelia.txt
	var fm := FileAccess.open("res://dialogue/npc/ophelia_M.txt", FileAccess.READ)
	NpcTalk.overlay(bank, NpcTalk.parse(fm.get_as_text()))
	for place in Shops.DATES:
		_check("date spot in town: %s" % place, dates.has(place), dates.keys())
		_check("Ophelia has lines for a date at %s" % place, (bank["date_m"] as Dictionary).has(place), place)
	var cues := []
	for l in bank["date_m"].get("smoke", []):
		if l is Array and l.size() > 2:
			cues.append_array((l[2] as Array).filter(func(w): return String(w).begins_with("@")))
		elif l is Dictionary:
			for c in l["choice"]:
				for cl in c["lines"]:
					if cl.size() > 2:
						cues.append_array((cl[2] as Array).filter(func(w): return String(w).begins_with("@")))
	_check("the back step date is staged: every cue is a beat", not cues.is_empty() and cues.all(func(w): return preload("res://scripts/hub/smoke_date.gd").BEATS.has(String(w).substr(1))), cues)
	_check("and it gets to the kiss", cues.has("@kiss") and cues.find("@last_drag") < cues.find("@kiss"), cues)
	_check("narration lines have no name", NpcTalk.NAMES.get("narrator", "x") == "", "")
	for spot in info["interactables"]:
		_check("%s isn't 'coming soon' any more" % spot["id"], not String(spot["prompt"]).contains("coming soon") or spot["id"] in ["job_board", "shop_bar"], spot["prompt"])
	town.free()

	# Meals: one run.
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash = {"scrap": 400, "alloy": 120, "circuits": 12, "lock_cores": 1}
	_check("buy a meal", Shops.buy_meal(armory, "seven_suns"), armory.stash)
	_check("it cost scrap", armory.amount("scrap") == 400 - 12, armory.stash)
	_check("meal waits for the next run", Shops.meal() == "seven_suns", Shops.meal())
	var p := Shops.boost(armory.suit_profile())
	_check("meal adds max health", is_equal_approx(float(p.get("max_health_bonus", 0.0)), 25.0), p)
	Shops.finish_meal()
	_check("meal is gone after the run", Shops.meal() == "" and not Shops.boost(armory.suit_profile()).has("max_health_bonus"), Shops.meal())

	# Implants: for good, once.
	_check("install an implant", Shops.buy(armory, "implants", "reflex_lace"), armory.stash)
	_check("not twice", not Shops.buy(armory, "implants", "reflex_lace"), "")
	_check("implant boosts speed", is_equal_approx(float(Shops.boost(armory.suit_profile())["speed_mult"]), 1.05), Shops.boost(armory.suit_profile()))
	Shops.buy_meal(armory, "sticky_parcels")
	_check("meal and implant stack", Shops.boost(armory.suit_profile())["regen_delay"] < armory.suit_profile()["regen_delay"], Shops.boost(armory.suit_profile()))
	Shops.finish_meal()

	# The player takes the boosts.
	var player: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.apply_suit({"max_health_bonus": 25.0})
	_check("max health boosted", is_equal_approx(player.max_health, 125.0) and is_equal_approx(player.health, 125.0), player.max_health)
	player.apply_suit({})
	_check("and back", is_equal_approx(player.max_health, 100.0), player.max_health)
	player.queue_free()

	# Trades.
	var before := armory.stash.duplicate()
	var life: Dictionary = armory.lifetime.duplicate()
	_check("trade scrap for alloy", Shops.trade(armory, "scrap_alloy"), armory.stash)
	_check("scrap down, alloy up", armory.amount("scrap") == int(before["scrap"]) - 40 and armory.amount("alloy") == int(before["alloy"]) + 6, armory.stash)
	_check("trades aren't salvage", armory.lifetime == life, armory.lifetime)
	armory.stash["lock_cores"] = 0
	_check("can't trade what she hasn't got", not Shops.trade(armory, "core_haul"), armory.stash)

	# Ink & Iron and Stitch & Steel.
	for id in Extras.TATTOOS:
		var tex := load(Extras.TATTOO_DIR + id + ".png") as Texture2D
		_check("tattoo %s is baked" % id, tex != null, id)
		_check("tattoo %s has a price" % id, not Shops.price("tattoos", id).is_empty(), id)
		if tex != null:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			_check("tattoo %s has ink on it" % id, img.get_used_rect().size.x > 4, img.get_used_rect())
	for id in Extras.PIERCINGS:
		_check("piercing %s has a price" % id, not Shops.price("piercings", id).is_empty(), id)
	for id in Extras.ACCESSORIES:
		_check("accessory %s has a price" % id, not Shops.price("accessories", id).is_empty(), id)
	armory.stash = {"scrap": 600, "alloy": 100, "circuits": 0, "lock_cores": 0}
	_check("pierce", Shops.buy(armory, "piercings", "septum") and Shops.buy(armory, "piercings", "lobes"), Shops.owned("piercings"))
	_check("ink", Shops.buy(armory, "tattoos", "cry_anyway") and Shops.buy(armory, "tattoos", "fern_band"), Shops.owned("tattoos"))
	_check("shades", Shops.buy(armory, "accessories", "shades"), Shops.owned("accessories"))
	_check("visor takes the shades' place", Shops.buy(armory, "accessories", "visor") and not Shops.wearing("accessories", "shades"), Shops.worn())
	_check("beanie", Shops.buy(armory, "accessories", "beanie") and Shops.wearing("accessories", "visor"), Shops.worn())
	Shops.set_worn("piercings", "lobes", false)
	_check("take one off", not Shops.wearing("piercings", "lobes") and Shops.owns("piercings", "lobes"), Shops.worn())
	Shops.set_worn("accessories", "shades", true)
	_check("shades back on, visor off", Shops.wearing("accessories", "shades") and not Shops.wearing("accessories", "visor"), Shops.worn())

	# On her model.
	var eco: Node3D = ECO.instantiate()
	root.add_child(eco)
	await process_frame
	var skel: Skeleton3D = eco.find_child("Skeleton3D", true, false)
	var extras := skel.get_node_or_null(Extras.NODE)
	_check("extras ride her head bone", extras is BoneAttachment3D and extras.bone_name == Extras.HEAD, extras)
	_check("piercings and accessories are on", extras != null and extras.find_children("*", "MeshInstance3D", true, false).size() >= 6, extras)
	var goggles := eco.find_children("Goggles*", "MeshInstance3D", true, false)
	_check("no goggles under the beanie", goggles.all(func(g): return not g.visible), goggles.size())
	var body := eco.find_child("Body", true, false) as MeshInstance3D
	var inked := false
	for i in body.mesh.get_surface_count():
		var m := body.get_active_material(i) as ShaderMaterial
		if m != null and Extras._is_body(m):
			inked = m.get_shader_parameter("tattoo_tex") != null
	_check("tattoos on her body material", inked, "")
	Extras.apply(eco, {"piercings": [], "tattoos": [], "accessories": []})
	_check("all off", skel.get_node(Extras.NODE).find_children("*", "MeshInstance3D", true, false).is_empty(), "")
	eco.free()

	# Mature-only things.
	var m_ids := {"piercings": ["snakebites", "bridge", "navel"], "tattoos": ["tally", "lower_back", "hip_moth", "thigh_snake"], "accessories": ["choker"]}
	_check("Mature date lines are the Mature cut", NpcTalk.date_lines(bank, "cafe") == bank["date_m"]["cafe"], "")
	for k in m_ids:
		for id in m_ids[k]:
			_check("sold under Mature: %s" % id, Shops.buy(armory, k, id), armory.stash)
	_check("firewater under Mature", Shops.buy_meal(armory, "firewater") and is_equal_approx(float(Shops.boost(armory.suit_profile())["damage_mult"]), 1.1), Shops.meal())
	Shops.finish_meal()
	var m_worn := {"piercings": ["navel", "snakebites"], "tattoos": ["tally", "stars"], "accessories": ["choker"]}
	var eco2: Node3D = ECO.instantiate()
	root.add_child(eco2)
	await process_frame
	eco2.wear("y2k")
	Extras.apply(eco2, m_worn)
	var skel2: Skeleton3D = eco2.find_child("Skeleton3D", true, false)
	_check("belly ring on her bare stomach (Y2K top)", skel2.get_node_or_null(Extras.NODE + "_navel") != null, "")
	_check("choker on her neck", skel2.get_node_or_null(Extras.NODE + "_choker") != null, "")
	_check("Mature ink stacked in", _body_tattoo(eco2) == Extras.tattoo_texture(["tally", "stars"]), "")
	eco2.wear("suit")
	Extras.apply(eco2, m_worn)
	_check("no belly ring through her bodysuit", skel2.get_node_or_null(Extras.NODE + "_navel") == null, "")
	eco2.free()

	# Every screen opens and sells.
	for kind in Screen.SHOPS:
		armory.stash = {"scrap": 500, "alloy": 100, "circuits": 10, "lock_cores": 0}
		var screen: Screen = Screen.new(kind, armory)
		root.add_child(screen)
		await process_frame
		_check("%s screen lists things" % kind, screen.rows.size() > 0, screen.rows)
		for t in screen.spec()["tabs"].size():
			for i in screen.rows.size():
				screen.selected = i
				screen.confirm()
			screen.switch_tab(1)
		_check("%s screen sold or changed something" % kind, not screen.bought.is_empty() or screen.changed, screen.bought)
		screen.free()

	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _body_tattoo(eco: Node) -> Texture2D:
	var body := eco.find_child("Body", true, false) as MeshInstance3D
	for i in body.mesh.get_surface_count():
		var m := body.get_active_material(i) as ShaderMaterial
		if m != null and Extras._is_body(m):
			return m.get_shader_parameter("tattoo_tex")
	return null


func _check(label: String, ok: bool, detail: Variant) -> void:
	if not ok:
		failures += 1
	print("%s  %s  (%s)" % ["ok   " if ok else "FAIL ", label, str(detail)])
