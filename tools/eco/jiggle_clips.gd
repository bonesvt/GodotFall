extends SceneTree
## Side-by-side clip of Eco's jiggle styles (eco_model.gd jiggle_style): the
## same run, jump, landing and quick turn played by three copies of her, left
## to right classic, anime, realistic (labelled on screen). She really moves through the world, so
## her speed and landings drive the springs as in game.
##   godot --path . --fixed-fps 60 --write-movie <dir>/frame.png -s res://tools/eco/jiggle_clips.gd -- [--view=front|back|side] [--styles=anime,realistic]
## A style ending "+body" also turns on full body jiggle (eco_flesh.gd), so
## --styles=classic,classic+body compares it off and on; "@1.25" after a
## style shows her glutes swinging 25% further (eco_model.gd glute_swing). --close frames them
## nearer.
## --write-movie writes numbered PNGs (or an .avi); join them with ffmpeg at 60
## fps for real time, 30 for half speed. Needs a renderer (not --headless).

const ECO := preload("res://assets/models/eco.tscn")
const SPACING := 1.9  # wide enough that each copy sits under her label column
const LABEL := {"classic": "Classic (now)", "anime": "Smooth anime", "realistic": "Realistic",
	"classic+body": "Full body jiggle", "classic+body@1": "Glutes now", "classic+body@1.25": "Glutes +25%", "classic+body@1.5": "Glutes +50%"}

var view := "front"
var close := false  # --close: nearer, following her up into the jump
var styles: PackedStringArray = ["classic", "anime", "realistic"]
var walkers: Array[Walker] = []
var cam: Camera3D
var caption: Label


class Walker extends CharacterBody3D:
	var state := 0  # player.gd State: 0 GROUND, 1 AIR
	var crouching := false
	var strolling := false
	var airborne := false  # eco_model reads state, so is_on_floor() is never asked


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			view = a.get_slice("=", 1)
		elif a == "--close":
			close = true
		elif a.begins_with("--styles="):
			styles = a.get_slice("=", 1).split(",", false)
	root.size = Vector2i(400 * styles.size() + 200, 900)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		_follow()
		await process_frame


func _go() -> void:
	_stage()
	for i in styles.size():
		var w := Walker.new()
		# from the front +x is on screen left, so mirror there to keep the first style on the left
		var side := 1.0 if view == "back" else -1.0
		w.position = Vector3(side * (i - (styles.size() - 1) * 0.5) * SPACING, 0, 0)
		root.add_child(w)
		var eco = ECO.instantiate()
		# "<style>[+body][@<glute swing>]", e.g. classic+body@1.25
		var spec := styles[i].get_slice("@", 0)
		eco.jiggle_style = spec.trim_suffix("+body")
		eco.body_jiggle = spec.ends_with("+body")
		if "@" in styles[i]:
			eco.glute_swing = styles[i].get_slice("@", 1).to_float()
		w.add_child(eco)
		walkers.append(w)
	_labels()
	cam = Camera3D.new()
	cam.fov = 38
	root.add_child(cam)

	_say("Idle")
	await _frames(45)
	# run: speed up over a third of a second, hold 6 m/s
	_say("Run")
	for f in 100:
		var speed := 6.0 * minf(f / 20.0, 1.0)
		_move(Vector3(0, 0, -speed), 1.0 / 60.0)
		await _frames(1)
	# jump out of the run: up at 5.5 m/s, gravity 14 m/s²
	_say("Jump")
	var vy := 5.5
	for w in walkers:
		w.state = 1
		w.airborne = true
	while true:
		vy -= 14.0 / 60.0
		_move(Vector3(0, vy, -6.0), 1.0 / 60.0)
		if walkers[0].position.y <= 0.0:
			break
		await _frames(1)
	# land and stop dead
	_say("Landing")
	for w in walkers:
		w.position.y = 0.0
		w.state = 0
		w.airborne = false
		w.velocity = Vector3.ZERO
	await _frames(70)
	# quick 180 on the spot, then run back a few steps and stop
	_say("Turn")
	for f in 10:
		for w in walkers:
			w.rotation.y = PI * smoothstep(0.0, 1.0, (f + 1) / 10.0)
		await _frames(1)
	await _frames(30)
	_say("Run back, stop")
	for f in 45:
		_move(Vector3(0, 0, 6.0 * minf(f / 15.0, 1.0)), 1.0 / 60.0)
		await _frames(1)
	for w in walkers:
		w.velocity = Vector3.ZERO
	await _frames(70)
	quit()


## Moves every copy by velocity for one frame (the velocity also picks her animation).
func _move(velocity: Vector3, dt: float) -> void:
	for w in walkers:
		w.velocity = velocity
		w.position += velocity * dt


## Keeps the camera on the group from a fixed angle.
func _follow() -> void:
	if cam == null or walkers.is_empty():
		return
	# high enough that her head stays in frame at the top of the jump
	var centre := Vector3(0, 1.2, walkers[0].position.z)
	var width := SPACING * styles.size()
	var dist := 2.4 + width * 0.5
	if close:
		centre.y = 1.0 + walkers[0].position.y * 0.8
		dist = 1.0 + width * 0.42
		if view == "side":
			dist = maxf(dist, 2.9)  # one copy side on: wide enough for her whole stride
	var offset: Vector3
	match view:
		"back":
			offset = Vector3(0.0, 0.45, dist)
		"side":
			offset = Vector3(dist * 1.1, 0.2, dist * 0.15)
		_:
			offset = Vector3(dist * 0.18, 0.25, -dist)
	cam.look_at_from_position(centre + offset, centre)


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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	# a long checkered runway so her speed reads
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color(0.45, 0.46, 0.48))
	img.set_pixel(0, 0, Color(0.36, 0.37, 0.4))
	img.set_pixel(1, 1, Color(0.36, 0.37, 0.4))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(20, 80, 1)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 80)
	plane.material = mat
	floor_mesh.mesh = plane
	floor_mesh.position.z = -25
	root.add_child(floor_mesh)


func _labels() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_top = 16
	layer.add_child(row)
	for s in styles:
		var l := Label.new()
		l.text = LABEL.get(s, s)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		row.add_child(l)
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
