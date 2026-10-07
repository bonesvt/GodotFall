extends SceneTree
## Clip of walls pushing Eco's soft parts (eco_model.gd jiggle_collide): the
## walls are see-through, and the camera swings round behind her for the
## first wall and in front of her for the second. She backs into a wall (glutes pressed), walks off it (they spring
## loose), walks up to a second wall, leans her chest into it and steps back.
## Full body jiggle is on. --deep=2 presses her twice as far in (to show
## contact_give and jiggle_squish). --lean instead shows her off duty: she
## stops where her capsule meets the wall, then leans back on it (wall_lean).
## --press: off duty she walks chest first into a wall and keeps pushing; her
## soft layer slows her as she sinks in (player.gd soft_press), then she lets
## up and it eases her back out.
##   godot --path . --fixed-fps 60 --write-movie <dir>/frame.png -s res://tools/eco/collide_clips.gd [-- --deep=2]
## Needs a renderer (not --headless).

const ECO := preload("res://assets/models/eco.tscn")
const Player := preload("res://scripts/player.gd")
const FRONT_WALL := -1.45  # the second wall's face (z); the first one's is at 0.1

var walker: Walker
var cam: Camera3D
var caption: Label
## Where the camera sits from her (eases towards `cam_goal` each frame).
var cam_offset := Vector3(1.9, 0.15, 2.0)
var cam_goal := Vector3(1.9, 0.15, 2.0)
var deep := 1.0
var lean := false
var pressing := false


class Walker extends CharacterBody3D:
	var state := 0
	var crouching := false
	var strolling := false
	var third_person := true


func _initialize() -> void:
	root.size = Vector2i(1280, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--deep="):
			deep = a.trim_prefix("--deep=").to_float()
		elif a == "--lean":
			lean = true
		elif a == "--press":
			pressing = true
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
	if lean:
		await _lean_scene()
		quit()
		return
	if pressing:
		await _press_scene()
		quit()
		return

	walker.position.z = -0.06
	_say("Standing by a wall")
	await _frames(40)
	_say("Backs into it")
	await _glide(0.06 * deep, 24)
	await _frames(40)
	_say("Steps away")
	await _glide(-0.25 - 0.06 * (deep - 1.0), 12)
	await _frames(50)
	_say("Walks to the next wall")
	cam_goal = Vector3(1.9, 0.0, -2.0)
	var target := FRONT_WALL + 0.21
	while walker.position.z > target + 0.02:
		var left := walker.position.z - target
		walker.velocity = Vector3(0, 0, -minf(1.3, 1.3 * left / 0.4 + 0.2))
		walker.position += walker.velocity / 60.0
		await _frames(1)
	walker.velocity = Vector3.ZERO
	await _frames(30)
	_say("Leans into it")
	await _glide(-0.09 * deep, 30)
	await _frames(40)
	_say("Steps back")
	await _glide(0.27 + 0.09 * (deep - 1.0), 12)
	await _frames(60)
	quit()


## Off duty: she walks chest first into the far wall at a stroll and keeps
## pushing into it, then lets up.
func _press_scene() -> void:
	walker.strolling = true
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	(shape.shape as CapsuleShape3D).radius = Player.STROLL_RADIUS
	(shape.shape as CapsuleShape3D).height = 1.8
	shape.position.y = 0.9
	walker.add_child(shape)
	walker.position.z = FRONT_WALL + 1.3
	cam_offset = Vector3(2.0, 0.1, -0.4)
	cam_goal = Vector3(1.6, 0.1, -2.0)
	_say("Off duty, walking into a wall")
	var pressed := 0.0
	var spread := 0.0
	for f in 450:
		if f == 70:
			_say("She slows as her soft parts meet it")
		elif f == 130:
			_say("Still pushing: she spreads against it and sinks in further")
		elif f == 370:
			_say("Lets up: it eases her back out")
		var want := Vector3(0, 0, -1.9) if f < 370 else Vector3.ZERO
		var cap := shape.shape as CapsuleShape3D
		var out := Player.soft_press_at(walker.get_world_3d().direct_space_state, shape.global_transform, 1.8, want, [walker.get_rid()], walker.collision_mask, cap.radius)
		walker.velocity = out[0]
		pressed = out[1]
		# as player.gd soft_press: pushing on at full press, her core gives a little more
		var on: bool = out[2] and pressed > 0.85
		spread = move_toward(spread, 1.0 if on else 0.0, (1.0 / 60.0) / (Player.SPREAD_TIME if on else 0.5))
		cap.radius = lerpf(Player.STROLL_RADIUS, Player.DEEP_RADIUS, spread)
		walker.move_and_slide()
		await _frames(1)
	print("last press %.2f, at z %.3f" % [pressed, walker.position.z])
	await _frames(30)


## Off duty: she stands with her back to the wall where her slim capsule
## (0.15 m, player.gd STROLL_RADIUS) stops her, leans back on it, and walks off.
func _lean_scene() -> void:
	walker.strolling = true
	cam_offset = Vector3(2.2, 0.1, 0.6)
	cam_goal = cam_offset
	walker.position.z = 0.1 - 0.15
	_say("Off duty, her slim capsule lets her stand right by the wall")
	await _frames(40)
	_say("Standing still, she leans back on it")
	await _frames(120)
	cam_goal = Vector3(1.6, 0.1, 1.9)
	_say("From behind (the wall is see-through)")
	await _frames(150)
	cam_goal = Vector3(2.2, 0.1, -1.0)
	_say("Leaning")
	await _frames(110)
	_say("Walks off")
	for f in 55:
		walker.velocity = Vector3(0, 0, -minf(1.0, f / 20.0))
		walker.position += walker.velocity / 60.0
		await _frames(1)
	walker.velocity = Vector3.ZERO
	await _frames(50)


## Moves her `dz` metres along z over `n` frames, slowly enough that she stays in her idle.
func _glide(dz: float, n: int) -> void:
	walker.velocity = Vector3.ZERO
	for f in n:
		walker.position.z += dz / n
		await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		cam_offset = cam_offset.lerp(cam_goal, 0.04)
		var c := Vector3(0, 1.0, walker.position.z)
		cam.look_at_from_position(c + cam_offset, c)
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
	# see-through, so the camera can look at her from either side of it
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
