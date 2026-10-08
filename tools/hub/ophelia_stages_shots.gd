extends SceneTree
## Ophelia through her obsession (obsession_look.gd), in the hub: upset, clingy
## on her doorstep in the hoodie, obsessed with the rose streak and eyes. One
## column a stage, her whole self and her face.
##   godot --path . --resolution 1280x720 -s res://tools/hub/ophelia_stages_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/ophelia_stages.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const ObsessionLook := preload("res://scripts/hub/obsession_look.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(480, 540)

var out := "user://ophelia_stages_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_oph_armory.cfg"
	run_node.npc_path = "user://shots_oph_npcs.cfg"
	var progress := ConfigFile.new()
	progress.set_value("progress", "cleared", ["level2"])
	progress.save(run_node.armory_path)
	root.add_child(run_node)
	_go.call_deferred(run_node)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(run_node: Node) -> void:
	await _frames(90)
	Vices.reset()
	run_node.hush_pull.triggers._next = INF
	run_node.hud.visible = false
	run_node.pilot_hud.visible = false
	var sheet := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var cam := Camera3D.new()
	run_node.add_child(cam)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	for col in 3:
		Obsession.reset()
		match col:
			0:
				Obsession.upset = true
			1:
				Obsession.meter = 30.0
			2:
				Obsession.meter = 70.0
		run_node.enter_hub()
		await _frames(30)
		var oph: Node3D = run_node.hub_npcs["ophelia"]
		run_node.place_player(oph.global_position + Vector3(0, 0, 40))  # Eco out of the shot
		var fwd: Vector3 = -oph.global_basis.z
		var face: Vector3 = oph.head_position()
		for row in 2:
			if row == 0:
				cam.fov = 40
				cam.look_at_from_position(oph.global_position + fwd * 3.4 + Vector3(0.6, 1.1, 0), oph.global_position + Vector3(0, 0.85, 0))
			else:
				cam.fov = 24
				cam.look_at_from_position(face + fwd * 0.95 + Vector3(0.12, 0.02, 0), face + Vector3(0, -0.05, 0))
			cam.make_current()
			await _frames(12)
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
	sheet.save_png(out.path_join("ophelia_stages.png"))
	print("wrote ophelia_stages.png")
	Obsession.reset()
	Obsession.save()
	quit()
