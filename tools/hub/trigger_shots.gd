extends SceneTree
## Stills of the craving and Marrow's trigger words in the hub (craving_screen.gd,
## trigger_words.gd), with the HUD on: the craving just started, the craving
## near the end of the pull clock, a trigger word landing, and two taps from
## shaking it off.
##   godot --path . --resolution 1280x720 -s res://tools/hub/trigger_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/trigger_craving.png.

const Vices := preload("res://scripts/hub/vices.gd")
const SIZE := Vector2i(640, 360)

var out := "user://trigger_shots"
var sheet: Image
var shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	Vices.save_path = "user://shots_vices.cfg"
	root.size = Vector2i(1280, 720)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_armory.cfg"
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE.x, SIZE.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * (shot % 2), SIZE.y * (shot / 2)))
	print("shot ", shot)
	shot += 1


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	sheet = Image.create(SIZE.x * 2, SIZE.y * 2, false, Image.FORMAT_RGBA8)
	var pull: Node = run_node.hush_pull
	var tw: Node = pull.triggers
	var view: Node = run_node.player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(true)
	# Full Hold, nothing in her: the clock runs and the craving builds.
	Vices.hold = Vices.MAX_HOLD
	pull.roam = 20.0
	await _frames(45)
	_grab()
	pull.roam = 275.0
	await _frames(45)
	_grab()
	# One of his words lands.
	Vices.errand = "x"  # the clock off: just the word
	pull.roam = 0.0
	tw.fire(false)
	await _frames(25)
	_grab()
	for i in 3:
		tw.tap()
	await _frames(10)
	_grab()
	sheet.save_png(out.path_join("trigger_craving.png"))
	print("wrote trigger_craving.png")
	quit()
