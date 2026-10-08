extends SceneTree
## Concept: the Precursor's gem (an idea for the Faith path's gear, not in the
## game). A faceted gold-clear crystal set over her navel, sitting on top of
## whatever she wears (it passes through the cloth, no bare skin), with glyph
## lines of light spreading from it over her suit in three stages.
##   godot --path . --resolution 1280x720 -s res://tools/eco/precursor_gem_concept.gd -- <out_dir>
## Needs a renderer (not --headless). Writes <out_dir>/precursor_gem.png.

const ECO := preload("res://assets/models/eco.tscn")
const GOLD := Color(1.0, 0.78, 0.32)
const CELL := Vector2i(420, 720)

var out := "user://precursor_gem"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.15, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1.0, 0.92, 0.75)
	env.environment.ambient_light_energy = 0.6
	env.environment.glow_enabled = true
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 165, 0)
	sun.light_color = Color(1.0, 0.92, 0.75)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var win := Vector2(root.get_texture().get_size())
	var cw := int(win.y * CELL.x / CELL.y)
	var sheet := Image.create(CELL.x * 4, CELL.y, false, Image.FORMAT_RGBA8)
	for i in 4:
		var eco := ECO.instantiate()
		eco.rotation_degrees.y = 20.0 if i < 3 else 0.0
		root.add_child(eco)
		await _frames(3)
		eco.wear("suit")
		var stage := mini(i + 1, 3)
		_gem(eco, stage)
		if i < 3:
			cam.fov = 36
			cam.look_at_from_position(Vector3(0.0, 1.0, -3.6), Vector3(0, 0.9, 0))
		else:
			cam.fov = 18
			cam.look_at_from_position(Vector3(0.0, 1.15, -1.6), Vector3(0, 1.12, 0))
		cam.make_current()
		await _frames(14)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img = img.get_region(Rect2i(int((win.x - cw) * 0.5), 0, cw, int(win.y)))
		img.resize(CELL.x, CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
		eco.queue_free()
		await _frames(2)
	sheet.save_png(out.path_join("precursor_gem.png"))
	print("wrote precursor_gem.png")
	quit()


## The gem on her spine bone, out in front of her suit at the navel, and
## glyph lines over her suit: stage 1 the gem alone, 2 a ring of glyph light
## round it, 3 lines branching up her ribs and down her hips.
func _gem(eco: Node, stage: int) -> void:
	var skel := eco.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("J_Bip_C_Spine")
	var att := BoneAttachment3D.new()
	att.bone_name = "J_Bip_C_Spine"
	skel.add_child(att)
	var root := Node3D.new()
	root.transform = skel.get_bone_global_rest(bone).affine_inverse()
	att.add_child(root)
	var navel := Vector3(0, 1.0, -0.125)
	var gem := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.05, 0.07, 0.03)
	gem.mesh = prism
	gem.material_override = _glass()
	gem.position = navel
	gem.rotation_degrees = Vector3(0, 0, 180)
	root.add_child(gem)
	var cap := MeshInstance3D.new()
	var top := PrismMesh.new()
	top.size = Vector3(0.05, 0.03, 0.03)
	cap.mesh = top
	cap.material_override = _glass()
	cap.position = navel + Vector3(0, 0.05, 0)
	root.add_child(cap)
	var setting := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.034
	ring.outer_radius = 0.042
	setting.mesh = ring
	setting.material_override = _gold()
	setting.position = navel + Vector3(0, 0.02, 0.004)
	setting.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(setting)
	if stage >= 2:
		for k in 12:
			var a := TAU * k / 12.0
			_glyph(root, navel + Vector3(cos(a) * 0.07, 0.02 + sin(a) * 0.07, 0.006), Vector3(0.012, 0.004, 0.004), a)
	if stage >= 3:
		# glyph veins up her ribs, curving out to the sides (none run below the gem)
		for side in [-1.0, 1.0]:
			for k in 6:
				var t := float(k) / 6.0
				var at := navel + Vector3(side * (0.05 + 0.06 * t), 0.08 + 0.14 * t, 0.004 + 0.01 * t)
				_glyph(root, at, Vector3(0.014, 0.004, 0.004), side * (0.6 + 0.5 * t))

func _glyph(root: Node3D, at: Vector3, size: Vector3, roll: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _light()
	mi.position = at
	mi.rotation.z = roll
	root.add_child(mi)


func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.88, 0.55, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 1.0
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = GOLD
	m.emission_energy_multiplier = 1.6
	return m


func _gold() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD
	m.metallic = 1.0
	m.roughness = 0.25
	return m


func _light() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD
	m.emission_enabled = true
	m.emission = GOLD
	m.emission_energy_multiplier = 2.5
	return m
