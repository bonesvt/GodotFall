extends SceneTree
## The cheat box in Eco's loft (cheat_screen.gd): max materials, max
## relationships, every cosmetic owned (but not put on).
##   godot --headless --path . -s res://tests/cheat_test.gd

const Armory := preload("res://scripts/hub/armory.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const TownShops := preload("res://scripts/hub/town_shops.gd")
const Extras := preload("res://scripts/hub/eco_extras.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const Family := preload("res://scripts/hub/family.gd")
const CheatScreen := preload("res://scripts/hub/cheat_screen.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const ARMORY_PATH := "user://test_cheat_armory.cfg"
const TALK_PATH := "user://test_cheat_npcs.cfg"
const TOWN_PATH := "user://test_cheat_town.cfg"

var failures := 0


func _initialize() -> void:
	for p in [ARMORY_PATH, TALK_PATH, TOWN_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	TownShops.save_path = TOWN_PATH
	_run.call_deferred()


func _run() -> void:
	var armory: Armory = Armory.open(ARMORY_PATH)
	var talk := NpcTalk.new()
	talk.save_path = TALK_PATH
	root.add_child(talk)
	# She's bought the shades and has them on.
	armory.stash["scrap"] = 100
	TownShops.buy(armory, "accessories", "shades")
	var box := CheatScreen.new(armory, talk)
	root.add_child(box)
	await process_frame

	box.max_materials()
	var again: Armory = Armory.open(ARMORY_PATH)
	_check("max materials, saved", Armory.MATERIALS.all(func(m): return again.amount(m) == CheatScreen.MAX_MATERIAL), again.stash)

	box.max_relationships()
	_check("Ophelia at full affection", Romance.affection(talk.state, "ophelia") == Romance.MAX, Romance.affection(talk.state, "ophelia"))
	_check("Mom at full bond", Family.bond(talk.state, "mom") == Family.MAX, Family.bond(talk.state, "mom"))
	var saved := ConfigFile.new()
	saved.load(TALK_PATH)
	_check("relationships saved", int(saved.get_value("ophelia", "affection", 0)) == Romance.MAX, saved.get_value("ophelia", "affection", 0))

	var n := box.unlock_cosmetics_count()
	_check("every cosmetic owned", Extras.PIERCINGS.keys().all(func(id): return TownShops.owns("piercings", id))
			and Extras.TATTOOS.keys().all(func(id): return TownShops.owns("tattoos", id))
			and Extras.ACCESSORIES.keys().all(func(id): return TownShops.owns("accessories", id)), n)
	_check("new ones aren't put on", TownShops.worn_of("piercings").is_empty() and TownShops.worn_of("tattoos").is_empty(), TownShops.worn())
	_check("what she had on stays on", TownShops.worn_of("accessories") == ["shades"], TownShops.worn_of("accessories"))
	_check("twice: nothing new", TownShops.unlock_all() == 0, "")

	Vices.open("user://test_cheat_vices.cfg")
	ContentRating.set_rating("T", false)
	_check("super Hush: Mature only", not box.super_hush() and Vices.hold == 0.0, Vices.hold)
	ContentRating.set_rating("M", false)
	_check("super Hush: his Hold to full", box.super_hush() and Vices.hold == Vices.MAX_HOLD and Vices.can_pull(), Vices.hold)
	Vices.open("user://test_cheat_vices.cfg")
	_check("super Hush saved", Vices.hold == Vices.MAX_HOLD, Vices.hold)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_cheat_vices.cfg"))

	print("cheat_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
