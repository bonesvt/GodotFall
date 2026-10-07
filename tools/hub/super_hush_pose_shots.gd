extends SceneTree
## Light stills of the Super Hush scene's look (super_hush_scene.gd) without
## the hub: Eco alone lifting the injector, it at her neck, then the close-up
## on her spiralling eyes under the violet flood. Quicker than
## super_hush_shots.gd, which plays the real scene in the hub.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/hub/super_hush_pose_shots.gd -- <out_dir>
## Writes <out_dir>/super_hush_pose.png.

const ECO := preload("res://assets/models/eco.tscn")
const Vices := preload("res://scripts/hub/vices.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const VIOLET := Color(0.72, 0.32, 1.0)
const VEIL := Color(0.16, 0.04, 0.24)

var out := "user://super_hush_pose"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	ContentRating.set_rating("M", false)
	root.size = Vector2i(1200, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.1, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	env.environment.glow_enabled = true
	root.add_child(env)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.8, 2.2, 1.2)
	lamp.light_color = Color(1.0, 0.8, 0.6)
	lamp.omni_range = 6.0
	root.add_child(lamp)
	var cam := Camera3D.new()
	root.add_child(cam)
	var eco := ECO.instantiate()
	root.add_child(eco)
	eco.rotation_degrees.y = 180.0
	await _frames(10)
	var model: Node = eco
	var skeleton: Skeleton3D = model.get("skeleton")
	var prop := _injector(skeleton)
	var veil_layer := CanvasLayer.new()
	root.add_child(veil_layer)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(VEIL, 0.0)
	veil_layer.add_child(veil)
	var eyes := Vector3(0, 1.48, 0)
	var shots := [
		{"inject": 0.55, "hold": 0.0, "swirl": false, "veil": 0.0, "fov": 34.0, "from": eyes + Vector3(-0.45, -0.12, 1.5), "at": eyes - Vector3(0, 0.22, 0)},
		{"inject": 1.0, "hold": 60.0, "swirl": false, "veil": 0.4, "fov": 34.0, "from": eyes + Vector3(-0.45, -0.12, 1.5), "at": eyes - Vector3(0, 0.22, 0)},
		{"inject": 1.0, "hold": 100.0, "swirl": true, "veil": 0.18, "fov": 18.0, "from": eyes + Vector3(0, 0.02, 0.9), "at": eyes},
		{"inject": 0.6, "hold": 100.0, "swirl": true, "veil": 0.7, "fov": 12.0, "from": eyes + Vector3(0, 0.02, 0.9), "at": eyes},
	]
	var sheet := Image.create(1200, 900, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s: Dictionary = shots[i]
		model.set("inject", s["inject"])
		Vices.hold = s["hold"]
		Vices.entranced = s["swirl"]
		prop.visible = s["inject"] > 0.5
		veil.color.a = s["veil"]
		cam.fov = s["fov"]
		cam.look_at_from_position(s["from"], s["at"])
		print("shot ", i)
		await _frames(20)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(600, 450)
		sheet.blit_rect(img, Rect2i(0, 0, 600, 450), Vector2i(600 * (i % 2), 450 * (i / 2)))
	var path := out.path_join("super_hush_pose.png")
	sheet.save_png(path)
	print("wrote ", path)
	Vices.reset()
	quit()


func _injector(skeleton: Skeleton3D) -> Node3D:
	var hold := BoneAttachment3D.new()
	hold.bone_name = "J_Bip_R_Hand"
	skeleton.add_child(hold)
	var pen := Node3D.new()
	pen.position = Vector3(-0.07, 0.0, 0.02)
	pen.rotation_degrees = Vector3(0, 0, 90)
	hold.add_child(pen)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = VIOLET
	glow.emission_enabled = true
	glow.emission = VIOLET
	glow.emission_energy_multiplier = 2.5
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.height = 0.11
	c.top_radius = 0.012
	c.bottom_radius = 0.012
	m.mesh = c
	m.material_override = glow
	pen.add_child(m)
	return hold
