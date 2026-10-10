extends SceneTree
## What going back to whoever had them does to Mom and Ophelia (rescue_looks.gd),
## once they've walked to the same captor three times: Marrow's long dark coat,
## the colony's white jumpsuit, Cutter's hoodie and ripped jeans. Top row Mom,
## bottom row Ophelia.
##   godot --path . --resolution 1280x720 -s res://tools/hub/rescue_looks_shots.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/rescue_looks.png.

const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const RescueLooks := preload("res://scripts/hub/rescue_looks.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const CELL := Vector2i(420, 600)
const LOOKS := ["marrow", "colony", "cutter"]

var out := "user://rescue_looks_shots"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	ContentRating.set_rating("M", false)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.19, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.6, 0.64)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.3, 0.31)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var sheet := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	var row := 0
	for who in ["mom", "ophelia"]:
		for i in LOOKS.size():
			var npc: Node3D = HubNpc.create(who, Vector3.ZERO, 0.0)
			npc.posed = true
			world.add_child(npc)
			await _frames(6)
			RescueLooks.apply(npc, who, LOOKS[i])
			await _frames(10)
			cam.fov = 36
			cam.look_at_from_position(Vector3(0.9, 1.25, -2.9), Vector3(0, 0.88, 0))
			await _frames(6)
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.convert(Image.FORMAT_RGBA8)
			img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, CELL.y * row))
			npc.queue_free()
			await _frames(2)
		row += 1
	sheet.save_png(out.path_join("rescue_looks.png"))
	print("wrote rescue_looks.png")
	quit()