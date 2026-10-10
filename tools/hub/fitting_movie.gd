extends SceneTree
## A fitting (fitting_scene.gd) played straight from the hub, for recording
## with Godot's movie writer:
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <out.avi> -s res://tools/hub/fitting_movie.gd -- <piece> [<who> <their piece>]
## Prints "fitting starts at frame N" so the hub's load can be trimmed off.

const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

var run_node: Node
var piece := "cuff"
var with := ""
var with_piece := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		piece = args[0]
	if args.size() >= 3:
		with = args[1]
		with_piece = args[2]
	preload("res://scripts/run/tutorial.gd").settings_path = "user://movie_settings.cfg"
	ContentRating.set_rating("M", false)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://movie_fitting_armory.cfg"
	run_node.npc_path = "user://movie_fitting_npc.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _go() -> void:
	for i in 60:
		await process_frame
	Hymn.reset()
	HubGrip.reset()
	run_node.hush_pull.triggers._next = INF
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	print("fitting starts at frame %d" % Engine.get_frames_drawn())
	run_node.fitting_scene.play(piece, with, with_piece)
	await process_frame
	while run_node.fitting_scene.busy():
		await process_frame
	for i in 30:  # the wake outside the dispensary
		await process_frame
	print("fitting ends at frame %d" % Engine.get_frames_drawn())
	Hymn.reset()
	Hymn.save()
	HubGrip.reset()
	HubGrip.save()
	quit()