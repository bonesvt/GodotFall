extends Node3D
## Movement test level, built in code so it is easy to tweak.
## Spawn faces -Z. Ahead: wallrun corridor. Right: wall-jump course.
## Left: slide ramp. Behind: grapple towers. Far right: grunt arena.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const GRUNT_SCRIPT := preload("res://scripts/grunt.gd")

## Grunt arena, well away from the movement courses.
const ARENA_CENTER := Vector3(75, 0, 25)
const GRUNT_SPAWNS := [
	Vector3(-8, 0, -14), Vector3(8, 0, -16), Vector3(0, 0, -6),
	Vector3(-14, 0, 2), Vector3(14, 0, 4), Vector3(0, 0, 14),
]

const GREY := Color(0.55, 0.57, 0.6)
const BLUE := Color(0.25, 0.5, 0.9)
const ORANGE := Color(0.95, 0.55, 0.2)
const RED := Color(0.85, 0.25, 0.25)
const GREEN := Color(0.3, 0.75, 0.4)

var checker: ImageTexture
var player: CharacterBody3D
var hud: CanvasLayer
var grunts: Array[Node] = []


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

	_build_arena()

	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.spawn_transform = player.global_transform

	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	hud.name = "HUD"
	hud.player = player
	hud.level = self
	add_child(hud)

	player.died.connect(_on_player_died)
	reset_arena()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		reset_arena()
		hud.flash_message("Arena reset")


# --- Grunt arena --------------------------------------------------------------

func _build_arena() -> void:
	var c := ARENA_CENTER
	_sign(c + Vector3(-28, 5, 0), "GRUNT ARENA (G resets it)")
	# Cover
	_box(c + Vector3(-6, 0.6, -2), Vector3(3, 1.2, 1), GREEN)
	_box(c + Vector3(6, 0.6, 0), Vector3(3, 1.2, 1), GREEN)
	_box(c + Vector3(0, 1, 6), Vector3(2, 2, 2), GREEN)
	_box(c + Vector3(-10, 1, -10), Vector3(2, 2, 2), GREEN)
	_box(c + Vector3(10, 1, -8), Vector3(2, 2, 2), GREEN)
	_box(c + Vector3(-4, 0.6, 10), Vector3(1, 1.2, 4), GREEN)
	# Wallrun walls along both sides, and a high perch to grapple to
	_box(c + Vector3(0, 4, -20), Vector3(36, 8, 1), BLUE)
	_box(c + Vector3(0, 4, 20), Vector3(36, 8, 1), BLUE)
	_box(c + Vector3(22, 3, 0), Vector3(1, 6, 16), BLUE)
	_box(c + Vector3(28, 9, 0), Vector3(6, 1, 8), GREEN)


func spawn_grunt(pos: Vector3, passive := false) -> Node:
	var g := CharacterBody3D.new()
	g.set_script(GRUNT_SCRIPT)
	g.passive = passive
	g.target = player
	add_child(g)
	g.global_position = pos
	g.died.connect(_on_grunt_died)
	grunts.append(g)
	return g


func reset_arena() -> void:
	for g in grunts:
		if is_instance_valid(g):
			g.queue_free()
	grunts.clear()
	for p in GRUNT_SPAWNS:
		var g := spawn_grunt(ARENA_CENTER + p + Vector3(0, 0.1, 0))
		g.rotation.y = PI / 2.0  # face the arena entrance (-X)


func grunts_alive() -> int:
	return grunts.filter(func(g): return is_instance_valid(g) and not g.dead).size()


func _on_grunt_died(_g: Node) -> void:
	if grunts_alive() == 0:
		hud.flash_message("Arena clear. Press G for another round", 4.0)


func _on_player_died() -> void:
	player.respawn()
	reset_arena()
	hud.flash_message("You died. Arena reset", 3.0)


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
