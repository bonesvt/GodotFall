extends SceneTree
## A picture of every generated-zone set piece (set_pieces.gd), for checking
## the models.
##   godot --path . -s res://tools/procgen/kit_shots.gd -- <out_dir> [biome] [id ...]
## Needs a renderer (not --headless). Writes <out_dir>/<biome>-<id>.png, the
## piece on a patch of ground seen from its front-left, and a sheet of all of
## them, <out_dir>/<biome>-sheet.png. For "city" or "military" the pieces are
## that kit's own (tools/procgen/build_kits.py), on paving or tarmac.

const SetPieces := preload("res://scripts/run/procgen/set_pieces.gd")
const Shapes := preload("res://scripts/run/procgen/prop_shapes.gd")
const KitShapes := preload("res://scripts/run/procgen/kit_shapes.gd")
const B := preload("res://scripts/run/procgen/biome.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")

var out := "user://kit_shots"
var biome := "forest"
var only := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["forest", "marsh", "boneyard", "city", "military"]:
			biome = a
		elif SetPieces.has(a):
			only.append(a)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(800, 600)
	_go.call_deferred()


func _go() -> void:
	var world := Node3D.new()
	world.set_meta("biome", biome)
	root.add_child(world)
	B.environment(world, biome)
	for env in world.find_children("*", "WorldEnvironment", true, false):
		env.environment.fog_enabled = false
		env.environment.volumetric_fog_enabled = false
	var ids: Array = only if not only.is_empty() else Shapes.SHAPES.keys()
	if only.is_empty() and biome in ["city", "military"]:
		ids = KitShapes.SHAPES.keys().filter(func(id): return KitShapes.SHAPES[id]["kit"] == biome)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 600.0
	world.add_child(cam)
	cam.make_current()
	var images := []
	var k := 0
	for id in ids:
		var at := Vector3(k * 60.0, 0, 0)
		k += 1
		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 40)
		ground.mesh = pm
		ground.material_override = Art.material({"city": "pavers", "military": "tarmac"}.get(biome, "dirt"))
		ground.position = at
		world.add_child(ground)
		var placed := SetPieces.place(world, id, at, 0.0)
		var aabb := AABB()
		for mi in (placed["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(mi.global_transform * mi.get_aabb()) if aabb.size != Vector3.ZERO else mi.global_transform * mi.get_aabb()
		var r := aabb.size.length() * 0.5
		var center := aabb.get_center()
		var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.1
		cam.global_position = center + Vector3(-0.55, 0.45, 0.7).normalized() * dist
		cam.look_at(center, Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("%s-%s.png" % [biome, id]))
		print("shot ", id)
		img.resize(320, 240)
		images.append(img)
	# A sheet of them all, six across.
	var cols := 6
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(320 * cols, 240 * rows, false, images[0].get_format())
	for i in images.size():
		sheet.blit_rect(images[i], Rect2i(0, 0, 320, 240), Vector2i((i % cols) * 320, (i / cols) * 240))
	sheet.save_png(out.path_join("%s-sheet.png" % biome))
	quit()
