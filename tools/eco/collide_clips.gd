extends SceneTree
## Clip of walls pushing Eco's soft parts (eco_model.gd jiggle_collide): seen
## side on, she backs into a wall (glutes pressed), walks off it (they spring
## loose), walks up to a second wall, leans her chest into it and steps back.
## Full body jiggle is on.
##   godot --path . --fixed-fps 60 --write-movie <dir>/frame.png -s res://tools/eco/collide_clips.gd
## Needs a renderer (not --headless).

const ECO := preload("res://assets/models/eco.tscn")
const FRONT_WALL := -1.45  # the second wall's face (z); the first one's is at 0.1

var walker: Walker
var cam: Camera3D
var caption: Label


class Walker extends CharacterBody3D:
	var state := 0
	var crouching := false
	var strolling := false


func _initialize() -> void:
	root.size = Vector2i(1280, 900)
	_go.call_deferred()


func _go() -> void:
	_stage()
	_wall(0.1, 1.0)
	_wall(FRONT_WALL, -1.0)
	walker = Walker.new()
	root.add_child(walker)
	var eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	eco.body_jiggle = true
	walker.add_child(eco)
	cam = Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	_caption()

	walker.position.z = -0.06
	_say("Standing by a wall")
	await _frames(40)
	_say("Backs into it")
	await _glide(0.06, 24)
	await _frames(40)
	_say("Steps away")
	await _glide(-0.25, 12)
	await _frames(50)
	_say("Walks to the next wall")
	var target := FRONT_WALL + 0.21
	while walker.position.z > target + 0.02:
		var left := walker.position.z - target
		walker.velocity = Vector3(0, 0, -minf(1.3, 1.3 * left / 0.4 + 0.2))
		walker.position += walker.velocity / 60.0
		await _frames(1)
	walker.velocity = Vector3.ZERO
	await _frames(30)
	_say("Leans into it")
	await _glide(-0.07, 30)
	await _frames(40)
	_say("Steps back")
	await _glide(0.25, 12)
	await _frames(60)
	quit()


## Moves her `dz` metres along z over `n` frames, slowly enough that she stays in her idle.
func _glide(dz: float, n: int) -> void:
	walker.velocity = Vector3.ZERO
	for f in n:
		walker.position.z += dz / n
		await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		var c := Vector3(0, 1.05, walker.position.z)
		cam.look_at_from_position(c + Vector3(3.2, 0.1, 0.0), c)
		await process_frame


func _wall(face_z: float, back: float) -> void:
	# a panel 0.7 m wide, its face at face_z, the rest of it on the `back` side
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.7, 2.4, 0.2)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = Vector3(0.7, 2.4, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.42)
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = Vector3(0, 1.2, face_z + 0.1 * back)
	root.add_child(body)


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.43, 0.46)
	plane.material = mat
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)


func _caption() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -60
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(caption)


func _say(text: String) -> void:
	caption.text = text
