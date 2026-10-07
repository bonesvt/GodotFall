extends SceneTree
## Screenshots of Solace's shop counters (town_shop_screen.gd).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/ink/shop_shots.gd -- <out_dir> [--only=ink,noodles]
## Writes <out_dir>/shop_<kind>[_<tab>].png with a test stash and test saves.

const Screen := preload("res://scripts/hub/town_shop_screen.gd")
const Shops := preload("res://scripts/hub/town_shops.gd")
const Armory := preload("res://scripts/hub/armory.gd")

var out := "user://shop_shots"
var only: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	Shops.save_path = "user://shop_shots_town.cfg"
	preload("res://scripts/hub/wardrobe.gd").save_path = "user://shop_shots_wardrobe.cfg"
	_go.call_deferred()


func _go() -> void:
	var armory: Armory = Armory.open("user://shop_shots_armory.cfg")
	armory.stash = {"scrap": 240, "alloy": 45, "circuits": 4, "lock_cores": 0}
	for kind in Screen.SHOPS:
		if not only.is_empty() and not only.has(kind):
			continue
		var screen: Screen = Screen.new(kind, armory)
		root.add_child(screen)
		for t in screen.spec()["tabs"].size():
			if t > 0:
				screen.switch_tab(1)
			screen.select(2)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/shop_%s%s.png" % [out, kind, "" if t == 0 else "_" + screen.tab_kind()]
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
		screen.free()
	quit()
