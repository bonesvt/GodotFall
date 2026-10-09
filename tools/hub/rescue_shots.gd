extends SceneTree
## Rescues (rescue_event.gd) in the hub, a 4 x 4 sheet:
##   row 1  Biggie running in, Biggie with it, the countdown and the marker,
##          the colony van by the dispensary
##   row 2  Marrow has Mom: in time (him knocked to smoke, the two of them),
##          too late (his vial at her lips, then sunk in his chair)
##   row 3  the colony has Ophelia: in time, too late (the Shepherd putting the piece on, then on)
##   row 5  their eyes after (Marrow's violet, the colony's white, Cutter's red),
##          and Mom walking off to Cutter, Eco seeing her go
##   row 4  Cutter has Mom: in time, too late (his needle at her eye, then Wiring)
##   godot --path . --resolution 1280x720 -s res://tools/hub/rescue_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/rescue.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Rescue := preload("res://scripts/hub/rescue.gd")
const RescueSites := preload("res://scripts/hub/rescue_sites.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)
const ARMORY := "user://shots_rescue_armory.cfg"

var out := "user://rescue_shots"
var run_node: Node
var ev: Node
var sheet: Image


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	# Ophelia's been rescued, so she's home too
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "cleared", ["tutorial", "level2"])
	cfg.save(ARMORY)
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = ARMORY
	run_node.npc_path = "user://shots_rescue_npc.cfg"
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(i: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * (i % 4), CELL.y * (i / 4)))


func _at(time: float) -> void:
	while ev.t < time and ev.busy():
		await process_frame


## Close on their eyes, after: what the captor left in them.
func _eyes(i: int) -> void:
	var v: Node3D = ev._victim
	if v == null or ev._cam == null:
		return
	var fwd := -v.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var head: Vector3 = v.head_position() + Vector3(0, 0.0, 0)
	ev._cam.fov = 22.0
	ev._cam.look_at_from_position(head + fwd * 0.55 + Vector3(0, 0.03, 0), head)
	await _frames(4)
	_grab(i)


func _running(who: String, captor: String) -> void:
	ev.start(who, captor)
	while not ev.running():
		await process_frame
	await _frames(4)


func _go() -> void:
	await _frames(90)
	ev = run_node.rescue_event
	run_node.hush_pull.triggers._next = INF
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	HubGrip.reset()
	Vices.hold = 10.0
	Redline.catches = 1
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false
	sheet = Image.create(CELL.x * 4, CELL.y * 5, false, Image.FORMAT_RGBA8)
	var p: Node3D = run_node.player
	# out in Solace's street, by the dispensary
	run_node.place_player(Vector3(1.5, 0.1, 141.0))
	p.rotation.y = PI  # facing up the street, into town
	await _frames(20)

	# row 1: Biggie, the countdown, the van
	ev.start("mom", "marrow")
	await _at(0.8)
	_grab(0)
	await _at(2.6)
	_grab(1)
	while not ev.running():
		await process_frame
	var to_cellar: Vector3 = ev.target() - p.global_position
	p.rotation.y = atan2(-to_cellar.x, -to_cellar.z)
	p.head.rotation.x = 0.05
	await _frames(12)
	_grab(2)
	# row 2: Marrow, in time
	run_node.place_player(ev._site["captor"] + Vector3(0.7, 0.1, -1.0))
	await _frames(10)
	ev.knock()
	await _at(0.85)
	_grab(4)
	await _at(3.6)
	_grab(5)
	while ev.busy():
		await process_frame
	# Marrow, too late
	await _running("mom", "marrow")
	ev.left = 0.05
	while not ev.busy():
		await process_frame
	await _at(2.7)
	_grab(6)
	await _at(5.4)
	_grab(7)
	await _eyes(16)
	while ev.busy():
		await process_frame

	# row 3: the colony has Ophelia
	await _running("ophelia", "colony")
	var van: Vector3 = RescueSites.VAN
	run_node.place_player(van + Vector3(4.6, 0.1, -3.4))
	var to_van := van + Vector3(0, 0, 0.3) - p.global_position
	p.rotation.y = atan2(-to_van.x, -to_van.z)
	p.head.rotation.x = -0.05
	await _frames(14)
	_grab(3)
	run_node.place_player(ev._site["captor"] + Vector3(1.3, 0.1, 0.0))
	await _frames(10)
	ev.knock()
	await _at(0.85)
	_grab(8)
	await _at(3.6)
	_grab(9)
	while ev.busy():
		await process_frame
	await _running("ophelia", "colony")
	ev.left = 0.05
	while not ev.busy():
		await process_frame
	await _at(2.7)
	_grab(10)
	await _at(5.4)
	_grab(11)
	await _eyes(17)
	while ev.busy():
		await process_frame

	# row 4: Cutter has Mom
	await _running("mom", "cutter")
	run_node.place_player(ev._site["captor"] + Vector3(-1.3, 0.1, 0.0))
	await _frames(10)
	ev.knock()
	await _at(0.85)
	_grab(12)
	await _at(3.6)
	_grab(13)
	while ev.busy():
		await process_frame
	await _running("mom", "cutter")
	ev.left = 0.05
	while not ev.busy():
		await process_frame
	await _at(2.7)
	_grab(14)
	await _at(5.4)
	_grab(15)
	await _eyes(18)
	while ev.busy():
		await process_frame
	# afterwards: Mom, walking off to Cutter, and Eco seeing her go
	run_node.place_player(Vector3(-0.5, 0.1, 131.5))
	ev.draw_off("mom", 0.01)
	while ev._walker == null:
		await process_frame
	await _frames(70)
	var to_her: Vector3 = ev._walker.global_position - p.global_position
	p.rotation.y = atan2(-to_her.x, -to_her.z)
	p.head.rotation.x = -0.12
	await _frames(6)
	_grab(19)
	ev._end_walk()
	sheet.save_png(out.path_join("rescue.png"))
	print("wrote rescue.png")
	Vices.reset()
	Hymn.reset()
	Redline.reset()
	Rescue.reset()
	Rescue.save()
	HubGrip.reset()
	HubGrip.save()
	ViceLooks.reset()
	ViceLooks.save()
	quit()
