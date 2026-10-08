extends SceneTree
## Stills of Ophelia's obsession (obsession.gd): Ophelia upset when Eco comes
## back without having seen her, Eco's eyes with Keepsake in her (rose
## spirals), the rose pull home on screen, and having it out in her tent
## (obsession_screen.gd).
##   godot --path . --resolution 1280x720 -s res://tools/hub/obsession_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/obsession.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(960, 540)

var out := "user://obsession_shots"
var sheet: Image
var shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_obsession_armory.cfg"
	run_node.npc_path = "user://shots_obsession_npcs.cfg"
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])  # Ophelia's been rescued
	progress.save(run_node.armory_path)
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
	Obsession.reset()
	run_node.hush_pull.triggers._next = INF
	sheet = Image.create(CELL.x * 2, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var oph: Node3D = run_node.hub_npcs["ophelia"]
	oph.wear("hoodie")
	run_node.npc_talk.state.set_value("ophelia", "met", true)
	var player: Node3D = run_node.player
	# Eco walks in, back from a run she didn't say goodbye before
	oph.mood(["angry"])
	var face: Vector3 = oph.head_position()
	var fwd: Vector3 = -oph.global_basis.z  # the way she faces
	run_node.place_player(oph.global_position + fwd * 2.2 + fwd.cross(Vector3.UP) * 1.2)
	player.look_at(Vector3(oph.global_position.x, player.global_position.y, oph.global_position.z), Vector3.UP)
	Obsession.skips = 2
	Obsession.upset = true
	run_node.talk_to("ophelia")
	var cam := Camera3D.new()
	run_node.add_child(cam)
	cam.fov = 30
	cam.look_at_from_position(face + fwd * 0.9 + Vector3(0, 0.02, 0), face + Vector3(0, -0.06, 0))
	run_node.pilot_hud.visible = false
	await _frames(30)
	cam.make_current()
	await _frames(10)
	_grab()
	# Keepsake in her: rose spirals
	Obsession.keepsake = 80.0
	run_node.pilot_hud.visible = false
	cam.queue_free()
	var view: Node = player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(true)
	await _frames(5)
	run_node.hush_pull._close_up(player)
	await _frames(40)
	_grab()
	run_node.hush_pull._drop_close_up()
	# the pull home, rose, in her tent
	Obsession.crave = 0.85
	run_node.pilot_hud.visible = true
	await _frames(40)
	_grab()
	Obsession.crave = 0.0
	# having it out
	Obsession.found = true
	run_node.talk_to("ophelia")
	await _frames(20)
	_grab()
	sheet.save_png(out.path_join("obsession.png"))
	print("wrote obsession.png")
	Obsession.reset()
	Obsession.save()
	quit()
