extends SceneTree
## The Hub Grip (hub_grip.gd) in stills: Mom taken with Eco and fitted beside
## her in the back room (top row), Ophelia the next time with her second piece
## (middle row), and the two of them at home in what the Shepherd put on them
## (bottom row: Mom with two pieces, Ophelia with four, Ophelia's face).
##   godot --path . --resolution 1280x720 -s res://tools/hub/hub_grip_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/hub_grip.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const CELL := Vector2i(640, 360)
const TIMES := [1.0, 4.0, 7.6]

var out := "user://hub_grip_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_grip_armory.cfg"
	run_node.npc_path = "user://shots_grip_npcs.cfg"
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(sheet: Image, col: int, row: int) -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL.x, CELL.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	Hymn.reset()
	HubGrip.reset()
	run_node.hush_pull.triggers._next = INF
	var sheet := Image.create(CELL.x * 3, CELL.y * 3, false, Image.FORMAT_RGBA8)
	var scene: Node = run_node.fitting_scene
	# Mom taken with her: Eco's headphones, Mom's headphones
	# Ophelia the next time: Eco's cuff, Ophelia's headphones and cuff
	var fits := [["headphones", "mom"], ["cuff", "ophelia"]]
	HubGrip.take("ophelia")
	for row in 2:
		var piece: String = fits[row][0]
		var who: String = fits[row][1]
		Hymn.gear.append(piece)
		var theirs := HubGrip.take(who)
		scene.play(piece, who, theirs)
		for col in 3:
			while scene.t < TIMES[col]:
				await process_frame
			_grab(sheet, col, row)
			print("shot ", who, " ", col)
		while scene.busy():
			await process_frame
	# at home in it
	HubGrip.gear = {"mom": ["headphones", "cuff"], "ophelia": ["headphones", "cuff", "visor", "bridge"]}
	run_node.enter_hub()
	await _frames(30)
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	for c in root.find_children("*", "Control", true, false):
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
			c.visible = false  # Eco's whispered thoughts
	var cam := Camera3D.new()
	run_node.add_child(cam)
	var mom: Node3D = run_node.hub_npcs["mom"]
	var oph: Node3D = run_node.hub_npcs["ophelia"]
	run_node.place_player(mom.global_position + Vector3(0, 0, 40))
	var shots := [[mom, 1.9, 0.9, 50], [oph, 3.0, 0.9, 40], [oph, 0.95, -0.05, 24]]
	for col in 3:
		var npc: Node3D = shots[col][0]
		var fwd: Vector3 = -npc.global_basis.z
		cam.fov = shots[col][3]
		if col < 2:
			cam.look_at_from_position(npc.global_position + fwd * shots[col][1] + Vector3(0, 1.3, 0), npc.global_position + Vector3(0, shots[col][2], 0))
		else:
			var face: Vector3 = npc.head_position()
			cam.look_at_from_position(face + fwd * 0.95 + Vector3(0.35, 0.05, 0), face + Vector3(0, -0.05, 0))
		cam.make_current()
		await _frames(12)
		_grab(sheet, col, 2)
	sheet.save_png(out.path_join("hub_grip.png"))
	print("wrote hub_grip.png")
	Hymn.reset()
	Hymn.save()
	HubGrip.reset()
	HubGrip.save()
	quit()