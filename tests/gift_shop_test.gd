extends SceneTree
## Headless test for Lucky Lantern, Solace's gift shop (gift_shop.gd,
## gift_screen.gd, gift_bag.gd): every gift has a model and a price in real
## materials, Ophelia's dialogue knows every gift she loves, the cheap gifts
## cost only scrap and the ones she loves most cost rarer materials, buying
## spends the stash and fills the bag (which saves), a gift you can't afford
## isn't sold, and the taste notes only show once Eco knows someone well.
## Run: godot --headless --path . -s res://tests/gift_shop_test.gd

const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const GiftScreen := preload("res://scripts/hub/gift_screen.gd")
const GiftBag := preload("res://scripts/hub/gift_bag.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const ARMORY_PATH := "user://test_gift_armory.cfg"
const BAG_PATH := "user://test_gifts.cfg"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for p in [ARMORY_PATH, BAG_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	# Catalogue: models, prices, Ophelia's tastes.
	var f := FileAccess.open("res://dialogue/npc/ophelia.txt", FileAccess.READ)
	var taste := Romance.settings(NpcTalk.parse(f.get_as_text()))
	var loved := 0
	for id in GiftShop.ids():
		var g := GiftShop.model(id)
		var meshes := g.find_children("*", "MeshInstance3D", true, false)
		_check("%s has a model" % id, meshes.size() > 0, meshes.size())
		var painted := meshes.all(func(mi): return mi.material_override != null)
		_check("%s is painted" % id, painted, id)
		g.free()
		var cost := GiftShop.cost(id)
		_check("%s costs real materials" % id, not cost.is_empty() and cost.keys().all(func(m): return m in Armory.MATERIALS and m != "lock_cores"), cost)
		_check("%s is a gift Ophelia has an opinion on" % id, taste["likes"].has(id) or taste["dislikes"].has(id), id)
		if taste["likes"].has(id):
			loved += 1
		if cost.keys() == ["scrap"]:
			continue
		_check("%s (rare) is one Ophelia loves" % id, taste["likes"].has(id), id)
	_check("most of the shop is for Ophelia", loved >= 8, loved)
	var rare := GiftShop.ids().filter(func(id): return not GiftShop.cost(id).keys() == ["scrap"])
	_check("a few rarer gifts", rare.size() >= 3 and rare.size() <= 5, rare)

	# Buying.
	var armory: Armory = Armory.open(ARMORY_PATH)
	armory.stash = {"scrap": 50, "alloy": 20, "circuits": 1, "lock_cores": 0}
	var bag := GiftBag.new(BAG_PATH)
	var screen := GiftScreen.new(armory, bag, [{"who": "ophelia", "name": "Ophelia", "likes": taste["likes"], "dislikes": taste["dislikes"], "affection": 5}])
	root.add_child(screen)
	await process_frame
	_check("buy black candles", screen.buy("candles"), armory.stash)
	_check("candles cost 25 scrap", armory.amount("scrap") == 25, armory.stash)
	_check("candles in the bag", bag.count("candles") == 1, bag.items)
	_check("can't buy what you can't afford", not screen.buy("book") and bag.count("book") == 0 and armory.amount("scrap") == 25, armory.stash)
	_check("buy black lipstick (alloy + circuits)", screen.buy("black_lipstick") and armory.amount("alloy") == 0 and armory.amount("circuits") == 0, armory.stash)
	_check("purchase saved the stash", Armory.open(ARMORY_PATH).amount("scrap") == 25, ARMORY_PATH)
	var reopened := GiftBag.new(BAG_PATH)
	_check("the bag is saved", reopened.count("candles") == 1 and reopened.count("black_lipstick") == 1, reopened.items)
	_check("taking a gift out", reopened.take("candles") and reopened.count("candles") == 0 and not reopened.take("candles"), reopened.items)
	_check("bought list for the toast", screen.bought == ["candles", "black_lipstick"], screen.bought)

	# Taste notes: hidden until they're friends, then honest.
	_check("taste hidden while strangers", screen.taste_lines("candles")[0].contains("get to know"), screen.taste_lines("candles"))
	screen.partners[0]["affection"] = 30
	_check("she'd love candles", screen.taste_lines("candles")[0] == "Ophelia would love this.", screen.taste_lines("candles"))
	_check("she'd hate flowers", screen.taste_lines("flowers")[0] == "Ophelia would hate this.", screen.taste_lines("flowers"))
	screen.select(3)
	_check("screen shows the picked gift", screen._preview_key == GiftShop.ids()[3], screen._preview_key)

	for p in [ARMORY_PATH, BAG_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool, detail = null) -> void:
	if not ok:
		failures += 1
	print("%s  %s  (%s)" % ["ok   " if ok else "FAIL ", label, detail])
