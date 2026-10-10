extends SceneTree
## Filmstrips of the rescue scenes (rescue_event.gd), to see them move: frames
## across Biggie's alert (row 1), the knockdown in time (row 2), and Cutter's
## too-late scene (rows 3 and 4), left to right in time.
##   godot --path . --resolution 1280x720 -s res://tools/hub/rescue_motion_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/rescue_motion.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(480, 270)
const COLS := 5

var out := "user://rescue_motion_shots"
var run_node: Node
var ev: Node
var sheet: Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_rescue_motion_armory.cfg"
	run_node.npc_path = "user://shots_rescue_motion_npc.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _grab(i: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % COLS), CELL.y * (i / COLS)))


## Frames at the scene times in `times`, into cells from `first`.
func _strip(times: Array, first: int) -> void:
	for i in times.size():
		while ev.busy() and ev.t < float(times[i]):
			await process_frame
		_grab(first + i)


func _go() -> void:
	for i in 90:
		await process_frame
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Redline.reset()
	Rescue.reset()
	HubGrip.reset()
	Vices.hold = 10.0
	Redline.catches = 1
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	sheet = Image.create(CELL.x * COLS, CELL.y * 4, false, Image.FORMAT_RGBA8)
	var p: Node3D = run_node.player
	run_node.place_player(Vector3(1.5, 0.1, 141.0))
	p.rotation.y = PI
	for i in 20:
		await process_frame
	# row 1: Biggie
	ev.start("mom", "marrow")
	await _strip([0.15, 1.0, 1.9, 3.3, 6.9], 0)
	while not ev.running():
		await process_frame
	# row 2: in time
	var at: Vector3 = ev._site["captor"]
	run_node.place_player(at + Vector3(1.2, 0.1, -2.6))
	var to_him := at - p.global_position
	p.rotation.y = atan2(-to_him.x, -to_him.z)  # facing him, as she would be to get his [F]
	for i in 10:
		await process_frame
	ev.knock()
	var marks := [0.25, 0.55, 0.0, 0.0, 0.0]
	for i in 2:
		while ev.busy() and ev.t < marks[i]:
			await process_frame
		_grab(5 + i)
	while ev._hit_t < 0.0:
		await process_frame
	var h0: float = ev._hit_t
	await _strip([h0 + 0.35, h0 + 2.4, h0 + 4.4], 7)
	while ev.busy() or ev._fade_up >= 0.0:
		await process_frame
	# rows 3-4: too late, Cutter
	ev.start("mom", "cutter")
	while not ev.running():
		await process_frame
	ev.left = 0.05
	while not ev.busy():
		await process_frame
	await _strip([0.8, 1.6, 2.4, 3.1, 3.8, 4.4, 5.0, 5.9, 7.0, 9.0], 10)
	while ev.busy() or ev._fade_up >= 0.0:
		await process_frame
	sheet.save_png(out.path_join("rescue_motion.png"))
	print("wrote rescue_motion.png")
	Vices.reset()
	Redline.reset()
	Rescue.reset()
	Rescue.save()
	HubGrip.reset()
	HubGrip.save()
	quit()
