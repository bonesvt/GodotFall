extends SceneTree
## Screenshots of Lucky Lantern's shop screen (gift_screen.gd) with a few
## different gifts picked, on a made-up stash.
##   xvfb-run -a godot --path . --audio-driver Dummy -s res://tools/hub/gift_shots.gd -- [out_dir]
## Needs a renderer (not --headless). Writes <out_dir>/gift_screen_<id>.png.

const GiftScreen := preload("res://scripts/hub/gift_screen.gd")
const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const GiftBag := preload("res://scripts/hub/gift_bag.gd")
const Armory := preload("res://scripts/hub/armory.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Romance := preload("res://scripts/hub/romance.gd")

var out := "user://gift_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	_go.call_deferred()


func _go() -> void:
	var armory: Armory = Armory.open("user://gift_shots_armory.cfg")
	armory.stash = {"scrap": 85, "alloy": 22, "circuits": 1, "lock_cores": 0}
	var bag := GiftBag.new("user://gift_shots_bag.cfg")
	bag.items = {"candles": 1}
	var f := FileAccess.open("res://dialogue/npc/ophelia.txt", FileAccess.READ)
	var taste := Romance.settings(NpcTalk.parse(f.get_as_text()))
	var screen := GiftScreen.new(armory, bag, [{"who": "ophelia", "name": "Ophelia", "likes": taste["likes"], "dislikes": taste["dislikes"], "affection": 30}])
	root.add_child(screen)
	var ids := GiftShop.ids()
	for id in ids:
		screen.select(ids.find(id))
		for i in 30:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("gift_screen_%s.png" % id))
		print("saved ", id)
	quit()
