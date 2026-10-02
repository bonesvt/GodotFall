extends Node3D
## Movement test level, built in code so it is easy to tweak.
## Spawn faces -Z. Ahead: wallrun corridor. Right: wall-jump course.
## Left: slide ramp. Behind: grapple towers.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCRIPT := preload("res://scripts/hud.gd")

const GREY := Color(0.55, 0.57, 0.6)
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const RED := Color(0.85, 0.25, 0.25)
const GREEN := Color(0.3, 0.75, 0.4)

var checker: ImageTexture


func _ready() -> void:
	checker = _make_checker()
	_build_environment()

	# Ground
	_box(Vector3(0, -0.5, 0), Vector3(240, 1, 240), GREY)

	# Crates near spawn for general messing about
	_box(Vector3(6, 0.75, -4), Vector3(1.5, 1.5, 1.5), GREEN)
	_box(Vector3(8, 1.5, 2), Vector3(3, 3, 3), GREEN)
	_box(Vector3(-7, 1, 3), Vector3(2, 2, 6), GREEN)

	# A: straight wallrun corridor (walls on both sides)
	_box(Vector3(-4, 4, -40), Vector3(1, 8, 50), BLUE)
	_box(Vector3(4, 4, -40), Vector3(1, 8, 50), BLUE)
	_sign(Vector3(0, 9.5, -15), "WALLRUN CORRIDOR")

	# B: wall-jump course, alternating panels between two raised platforms
	_box(Vector3(25, 2, -8), Vector3(8, 4, 8), GREEN)
	_box(Vector3(21.5, 6, -22), Vector3(1, 6, 12), BLUE)
	_box(Vector3(28.5, 6, -32), Vector3(1, 6, 12), BLUE)
	_box(Vector3(21.5, 6, -42), Vector3(1, 6, 12), BLUE)
	_box(Vector3(28.5, 6, -52), Vector3(1, 6, 12), BLUE)
	_box(Vector3(25, 2, -64), Vector3(8, 4, 8), GREEN)
	var lava := _box(Vector3(25, 0.02, -36), Vector3(12, 0.04, 48), RED)  # visual only
	lava.get_child(0).disabled = true
	_box(Vector3(25, 1, -3.5), Vector3(4, 2, 1), GREEN)  # step up to the start
	_sign(Vector3(25, 6, -4), "WALL-JUMP COURSE")

	# C: slide ramp (walk up, crouch at the top, slide down)
	var ramp_deg := 15.0
	_box(Vector3(-25, 5.2, -30), Vector3(8, 1, 40), ORANGE, Vector3(ramp_deg, 0, 0))
	_box(Vector3(-25, 5.45, -54.2), Vector3(10, 10.9, 10), ORANGE)
	_sign(Vector3(-25, 3, -8), "SLIDE RAMP")

	# D: grapple towers and floating platforms behind spawn
	_box(Vector3(0, 12, 30), Vector3(3, 24, 3), RED)
	_box(Vector3(-15, 16, 48), Vector3(3, 32, 3), RED)
	_box(Vector3(15, 20, 62), Vector3(3, 40, 3), RED)
	_box(Vector3(0, 18, 45), Vector3(6, 1, 6), GREEN)
	_box(Vector3(-8, 26, 62), Vector3(6, 1, 6), GREEN)
	_box(Vector3(0, 30, 80), Vector3(12, 1, 12), GREEN)
	_sign(Vector3(0, 4, 14), "GRAPPLE TOWERS (look up, hold Q)")

	# Tall freestanding wall for wallrun practice
	_box(Vector3(-14, 5, 12), Vector3(1, 10, 30), BLUE)

	var player := PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.spawn_transform = player.global_transform

	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	hud.name = "HUD"
	hud.player = player
	add_child(hud)


func _box(pos: Vector3, size: Vector3, color: Color, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = checker
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body


func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 96
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 16
	add_child(l)


func _make_checker() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var light := ((x >> 5) + (y >> 5)) % 2 == 0
			img.set_pixel(x, y, Color(1, 1, 1) if light else Color(0.82, 0.82, 0.82))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.45, 0.7)
	sky_mat.sky_horizon_color = Color(0.75, 0.8, 0.85)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
