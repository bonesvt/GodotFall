extends SceneTree
## The Hub Grip's scenes at home (hub_grip.gd SCENES): Mom's and Ophelia's at
## 30, 60, 90 and on the way back, each in what the Shepherd's put on them by
## then. One row a scene, its first and last line.
##   godot --path . --resolution 1280x720 -s res://tools/hub/hub_grip_scene_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/hub_grip_scenes.png.

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(640, 360)
## What they're wearing by each scene.
const WORN := {30: ["headphones"], 60: ["headphones", "cuff", "visor"],
	90: ["headphones", "cuff", "visor", "bridge", "gloves"], "clean": []}
const STEPS := [30, 60, 90, "clean"]

var out := "user://hub_grip_scene_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	ContentRating.set_rating("M", false)
	var run_node: Node = load("res://scenes/run.tscn").instantiate()
	run_node.armory_path = "user://shots_grips_armory.cfg"
	run_node.npc_path = "user://shots_grips_npcs.cfg"
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
	Hymn.reset()
	run_node.hush_pull.triggers._next = INF
	var sheet := Image.create(CELL.x * 2, CELL.y * 8, false, Image.FORMAT_RGBA8)
	var cam := Camera3D.new()
	run_node.add_child(cam)
	var talk: Node = run_node.npc_talk
	var row := 0
	for who in HubGrip.WHO:
		for s in STEPS:
			HubGrip.reset()
			HubGrip.gear[who] = WORN[s]
			HubGrip.pending = [[who, s]]
			run_node.enter_hub()
			await _frames(20)
			run_node.pilot_hud.visible = false
			for c in root.find_children("*", "Control", true, false):
				if c.get_script() != null and String(c.get_script().resource_path).ends_with("whisper_caption.gd"):
					c.visible = false  # Eco's whispered thoughts
			run_node._grip_scene()
			var npc: Node3D = run_node.hub_npcs[who]
			var fwd: Vector3 = -npc.global_basis.z
			var side: Vector3 = fwd.cross(Vector3.UP)
			var face: Vector3 = npc.head_position()
			cam.fov = 38
			cam.look_at_from_position(face + fwd * 1.7 + side * 0.55 + Vector3(0, 0.05, 0), face + Vector3(0, -0.35, 0))
			cam.make_current()
			var last: int = talk.lines.size() - 1
			for col in 2:
				var want := 0 if col == 0 else last
				talk.index = want - 1
				talk._next()
				# the whole line up, and held there for the shot
				for f in 6:
					talk.line_left = 999.0
					talk._text.visible_characters = -1
					await process_frame
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				img.resize(CELL.x, CELL.y)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * col, CELL.y * row))
				print("shot ", who, " ", s, " ", col)
			talk.stop()
			row += 1
	sheet.save_png(out.path_join("hub_grip_scenes.png"))
	print("wrote hub_grip_scenes.png")
	HubGrip.reset()
	HubGrip.save()
	quit()