extends SceneTree
## Stopping her on her way back to them (rescue_event.gd), played straight from
## the hub for Godot's movie writer: one of them, already theirs, walks off from
## just ahead of Eco; Eco catches her up and stops her; then either she's held
## (a few [F]s, fast) or she's lost (no [F]) and gives Eco what they gave her.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <out.avi> -s res://tools/hub/stop_movie.gd -- <who> <captor> <held|lost>
## Prints "scene starts at frame N" so the hub's load can be trimmed off.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const ARMORY := "user://movie_stop_armory.cfg"

var run_node: Node
var who := "mom"
var captor := "marrow"
var how := "lost"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3:
		who = args[0]
		captor = args[1]
		how = args[2]
	preload("res://scripts/run/tutorial.gd").settings_path = "user://movie_settings.cfg"
	ContentRating.set_rating("M", false)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "cleared", ["tutorial", "level2"])
	cfg.save(ARMORY)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = ARMORY
	run_node.npc_path = "user://movie_stop_npc.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await _frames(60)
	var ev: Node = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	for s in [Vices, Hymn, Redline, Rescue, HubGrip]:
		s.reset()
	Vices.hold = 10.0
	Redline.catches = 1
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	Rescue.lost_to[who] = [captor]
	Rescue.visits[who] = {captor: Rescue.VISITS}
	if captor == "colony":
		HubGrip.levels[who] = 50.0
	else:
		Rescue.hooks[who] = {captor: 50.0}
	# out in the street, Lantern Row, her a few steps ahead
	var p: Node3D = run_node.player
	run_node.place_player(Vector3(0.5, 0.1, 150.0))
	p.rotation.y = PI
	await _frames(10)
	ev.walk_off_now(who)
	await _frames(45)
	# Eco catches her up, and stops her
	var w: Node3D = ev._walker
	var behind := (w.global_position - p.global_position)
	behind.y = 0.0
	run_node.place_player(w.global_position - behind.normalized() * 1.4 + Vector3(0, 0.1, 0))
	p.rotation.y = atan2(-behind.x, -behind.z)
	await _frames(3)
	print("scene starts at frame %d" % Engine.get_frames_drawn())
	ev.stop_walker()
	while ev.busy():
		await process_frame
		if how == "held" and ev.t > ev.Q_START + 0.1 and ev.qte_result == "" and Engine.get_frames_drawn() % 3 == 0:
			ev.qte_press()
	await _frames(45)
	print("scene ends at frame %d" % Engine.get_frames_drawn())
	for s in [Vices, Hymn, Redline, Rescue, HubGrip]:
		s.reset()
		s.save()
	quit()
