extends SceneTree
## Downtown (downtown.gd): Pip's street, her slot machine at the Velvet Ace
## and the secrets she sells at the Undertow.
##   godot --headless --path . -s res://tests/downtown_test.gd

const Armory := preload("res://scripts/hub/armory.gd")
const Downtown := preload("res://scripts/hub/downtown.gd")
const TownShops := preload("res://scripts/hub/town_shops.gd")
const Town := preload("res://scripts/hub/town.gd")
const CasinoScreen := preload("res://scripts/hub/casino_screen.gd")
const ClubScreen := preload("res://scripts/hub/club_screen.gd")
const Below := preload("res://scripts/hub/downtown_below.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")

const ARMORY_PATH := "user://test_downtown_armory.cfg"
const DOWNTOWN_PATH := "user://test_downtown.cfg"
const TOWN_PATH := "user://test_downtown_town.cfg"

var failures := 0


func _initialize() -> void:
	for p in [ARMORY_PATH, DOWNTOWN_PATH, TOWN_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Downtown.save_path = DOWNTOWN_PATH
	TownShops.save_path = TOWN_PATH
	_run.call_deferred()


func _run() -> void:
	# Payouts.
	_check("three starlings pay 75x", Downtown.payout(["starling", "starling", "starling"], 10) == 750, "")
	_check("three cherries pay 4x", Downtown.payout(["cherry", "cherry", "cherry"], 5) == 20, "")
	_check("two cherries: bet back", Downtown.payout(["cherry", "bell", "cherry"], 15) == 15, "")
	_check("a mixed line pays nothing", Downtown.payout(["bell", "chip", "titan"], 15) == 0, "")
	# The house wins in the long run, but not by robbery.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var back := 0
	for i in 20000:
		back += Downtown.payout(Downtown.spin(rng), 1)
	var rtp := back / 20000.0
	_check("return to player between 60% and 95%", rtp > 0.6 and rtp < 0.95, rtp)

	# The slot screen spends and pays scrap.
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash["scrap"] = 200
	var casino := CasinoScreen.new(armory, 11)
	root.add_child(casino)
	await process_frame
	var paid := casino.spin()
	_check("a spin costs the bet and pays what it won", armory.amount("scrap") == 200 - Downtown.BETS[0] + paid, armory.amount("scrap"))
	_check("net tracks it", casino.net == paid - Downtown.BETS[0], casino.net)
	armory.stash["scrap"] = 2
	_check("broke: no spin", casino.spin() == -1 and armory.amount("scrap") == 2, armory.amount("scrap"))
	casino.queue_free()

	# Secrets: one at a time, a ledger page each, a boost for one run.
	armory.stash["scrap"] = 500
	armory.stash["alloy"] = 50
	armory.stash["circuits"] = 5
	var club := ClubScreen.new(armory)
	root.add_child(club)
	await process_frame
	_check("no secret, no ledger yet", Downtown.secret() == "" and Downtown.pages() == 0, "")
	_check("buys the patrol rota", club.buy() and Downtown.secret() == "patrol_rota", Downtown.secret())
	_check("costs 30 scrap", armory.amount("scrap") == 470, armory.amount("scrap"))
	_check("turns a page", Downtown.pages() == 1, Downtown.pages())
	club.move(1)
	_check("one at a time", not club.buy() and Downtown.secret() == "patrol_rota", Downtown.secret())
	var p: Dictionary = TownShops.boost({"notice_mult": 1.0})
	_check("the boost rides with the meals", is_equal_approx(float(p["notice_mult"]), 0.75), p)
	Downtown.finish_secret()
	_check("the run ends, the secret's spent", Downtown.secret() == "" and Downtown.boost().is_empty(), "")
	_check("the page stays turned", Downtown.pages() == 1, Downtown.pages())
	armory.stash["scrap"] = 0
	_check("short: no sale", not club.buy() and Downtown.secret() == "", "")
	club.queue_free()

	# Pip moves around and dresses for it; Teen trades the mesh for the waistcoat.
	var info := {"npcs": [], "interactables": []}
	var spec := Downtown.place_pip(info, 0, "M")
	_check("first stay: the casino door, in the warden fit", spec["spot"] == "casino" and spec["outfit"] == "warden", spec)
	_check("she has a talk spot", info["interactables"].any(func(i): return i.get("npc", "") == "pip"), "")
	_check("Teen: the waistcoat instead", Downtown.place_pip({"interactables": []}, 0, "T")["outfit"] == "crop", "")
	_check("next stay: the club, in the rave fit", Downtown.place_pip({"interactables": []}, 1, "M")["outfit"] == "rave", "")
	var late := Downtown.place_pip({"interactables": []}, 4, "M")
	_check("after hours: the high rollers' room", late["spot"] == "high_rollers" and late["outfit"] == "afterhours", late)
	var teen := Downtown.place_pip({"interactables": []}, 4, "T")
	_check("Teen keeps her upstairs", teen["spot"] == "arch" and teen["outfit"] == "crop", teen)
	var below := Downtown.place_pip({"interactables": []}, 5, "M")
	_check("and the corridor of rooms, with her ledger", below["spot"] == "rooms" and below["anim"] == "work_rooms" and below["props"] == ["ledger"], below)
	_check("Teen: not the rooms either", Downtown.place_pip({"interactables": []}, 5, "T")["spot"] == "arch", "")
	# She's working at each of her businesses: a loop for each in her poses file.
	var poses: Node = load("res://assets/models/npc/pip_poses.glb").instantiate()
	var ap := poses.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for s in Downtown.PIP_SPOTS:
		if s[4] != "":
			_check("she works the %s (%s)" % [s[0], s[4]], ap.has_animation(s[4]), ap.get_animation_list())
	poses.free()

	# She looks down at Eco when Eco comes close; Mom doesn't.
	var eco := Node3D.new()
	root.add_child(eco)
	var looks := {}
	for who in ["pip", "mom"]:
		var npc: Node3D = HubNpc.create(who, Vector3(0, 0, -30), 0.0)
		root.add_child(npc)
		npc.look_target = eco
		eco.position = Vector3(0, 0, -31.2)
		for i in 150:
			await process_frame
		looks[who] = npc.regard.y
		eco.position = Vector3(0, 0, -50)
		for i in 150:
			await process_frame
		looks[who + "_gone"] = npc.regard.y
		npc.queue_free()
	eco.queue_free()
	_check("Pip looks down at Eco up close", looks["pip"] > 0.12, looks)
	_check("and back up when she's gone", looks["pip_gone"] < 0.05, looks)
	_check("Mom doesn't", looks["mom"] == 0.0, looks)

	# The street's in the town, with both doors.
	var town_root := Node3D.new()
	root.add_child(town_root)
	var town_info := {"interactables": [], "sounds": []}
	Town.build(town_root, town_info)
	var ids: Array = town_info["interactables"].map(func(i): return i["id"])
	_check("the Velvet Ace and the Undertow have doors", "shop_casino" in ids and "shop_club" in ids, "")
	_check("the street is built", town_root.find_child("Downtown", true, false) != null, "")

	# Pip's own secrets under the Undertow: rooms, the gold door, her dirt.
	_check("the roped stair goes down", "undertow_down" in ids and "gold_door" in ids and "gold_door_back" in ids, "")
	_check("the stage door to the dressing room, both ways", "stage_door" in ids and "stage_door_back" in ids, "")
	var dirt_spots: Array = town_info["interactables"].filter(func(i): return i.has("dirt"))
	_check("six pieces of her dirt to find", dirt_spots.size() == Below.DIRT.size(), dirt_spots.size())
	_check("nothing found yet", Downtown.dirt().is_empty(), Downtown.dirt())
	var first := Downtown.find_dirt("mirror")
	_check("the mirror: the camera behind it", "lens" in first and Downtown.dirt() == ["mirror"], first)
	Downtown.find_dirt("mirror")
	_check("finding it twice counts once", Downtown.dirt().size() == 1, Downtown.dirt())
	var last := ""
	for id in Below.DIRT_ORDER:
		last = Downtown.find_dirt(id)
	_check("all of it: Eco's last word", Below.ALL_FOUND in last and Downtown.dirt().size() == Below.DIRT.size(), Downtown.dirt())

	# What the rooms are for, lying about to be read (nothing shown), and
	# Pip talking about them at her spots there (Mature only, like the rooms).
	var words := Below.hint_lines()
	for h in Below.HINTS:
		_check("something to read: %s" % h[0], h[0] in ids and not words.get(h[0], []).is_empty(), words.get(h[0], []).size())
	var cut := NpcTalk.parse(FileAccess.get_file_as_string("res://dialogue/npc/pip_M.txt"))
	_check("Pip talks about the rooms and the high rollers' room", cut["spot"].has("rooms") and cut["spot"].has("high_rollers"), cut["spot"].keys())
	var plain := NpcTalk.parse(FileAccess.get_file_as_string("res://dialogue/npc/pip.txt"))
	_check("not in the Teen lines", not plain["spot"].has("rooms") and not plain["spot"].has("high_rollers"), plain["spot"].keys())

	for path in [ARMORY_PATH, DOWNTOWN_PATH, TOWN_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("downtown_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
