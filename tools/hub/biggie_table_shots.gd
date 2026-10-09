extends SceneTree
## Stills of Biggie's table in his tent (gear_off_screen.gd): the list of what
## the Shepherd put on her, his hand shaking along the bar on the visor, and a
## piece coming off.
##   godot --path . --resolution 1280x720 -s res://tools/hub/biggie_table_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/biggie_table.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const CELL := Vector2i(960, 540)

var out := "user://biggie_table_shots"
var sheet: Image
var shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_biggie_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (shot % 2), CELL.y * (shot / 2)))
	shot += 1


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	Hymn.gear = ["headphones", "cuff", "visor", "bridge"]
	Hymn.level = 40.0
	run_node.hush_pull.triggers._next = INF
	sheet = Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var at := Vector3.ZERO
	for spot in run_node.zone_info.get("interactables", []):
		if spot["id"] == "biggie_table":
			at = spot["pos"]
	run_node.place_player(at)
	run_node.player.rotation.y = 0.0  # facing -Z, at the table
	run_node.Wardrobe.dress_eco(run_node.player, true)
	await _frames(20)
	_grab()  # standing at his table in the gear
	run_node.open_bench("gear_off")
	await _frames(10)
	_grab()  # what's on her
	var table: CanvasLayer = run_node.bench
	table.pick("visor")
	table._holds = 1
	await _frames(40)
	_grab()  # his hand on the bar, the visor's narrow band
	for i in Hymn.HOLDS:
		table._at = 0.5
		table.hold_now()
	await _frames(10)
	_grab()  # off
	sheet.save_png(out.path_join("biggie_table.png"))
	print("wrote biggie_table.png")
	Hymn.reset()
	Hymn.save()
	quit()
