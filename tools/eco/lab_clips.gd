extends SceneTree
## Clips of the physics experiments, one scene each, captioned:
##   rest     on a bench: sits, lies on her back, face down, on her side (_support_y squash)
##   brace    walks into a wall, braces her hands on it, pushes off; then a wall at her side
##   squeeze  side-on through a 30 cm gap, then a 27 cm one with a snag jutting
##            out that she gets stuck on and wriggles past
##   crowd    brushes past Mom, then bumps into her (soft bodies, bumped(), npc_springs)
##   jolt     a blast goes off nearby, then a hit from the front (eco_model.gd jolt)
##   weather  a fan's wind streams her hair, then she wades into chest-deep water
##   cling    two Ecos in the y2k skirt hopping: cling off (left), on (right)
## Walls and water are see-through. Full body jiggle is on.
##   godot --path . --fixed-fps 60 --write-movie <dir>/frame.png -s res://tools/eco/lab_clips.gd -- --scene=rest
## No --scene runs them all, one after another. Needs a renderer (not --headless).

const ECO := preload("res://assets/models/eco.tscn")
const Player := preload("res://scripts/player.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const LaidOut := preload("res://scripts/run/laid_out.gd")
const FX := preload("res://scripts/fx.gd")
const SCENES := ["rest", "brace", "squeeze", "crowd", "jolt", "weather", "cling"]
const STEP := 1.0 / 60.0

var cam: Camera3D
var caption: Label
## The scene's things (freed between scenes).
var set_piece: Node3D
var walker: Walker
var eco
var cam_offset := Vector3(2.2, 0.2, 1.2)
var cam_goal := Vector3(2.2, 0.2, 1.2)
## What the camera looks at (follows the walker unless a scene pins it).
var focus_override := Vector3(INF, 0, 0)


## Stands in for the player: everything eco_model.gd reads off her body.
class Walker extends CharacterBody3D:
	var state := 0
	var crouching := false
	var strolling := true
	var third_person := true
	var backpedalling := false
	var brace := 0.0
	var press_normal := Vector3.ZERO
	var squeeze := 0.0
	var spread := 0.0
	var pinch := 0.0
	var sidling := false
	var sidle_face := Vector3.ZERO
	var sidle_clear := 0.0


func _initialize() -> void:
	root.size = Vector2i(1280, 900)
	_go.call_deferred()


func _go() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			only = a.trim_prefix("--scene=")
	_stage()
	cam = Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	_caption()
	for scene: String in SCENES:
		if only != "" and scene != only:
			continue
		_reset()
		await call("_" + scene)
	quit()


# --- scenes -------------------------------------------------------------------

func _rest() -> void:
	_box(Vector3(0, 0.225, 0), Vector3(2.0, 0.45, 0.55), Color(0.5, 0.45, 0.4), false)
	eco.rest_seat_height = 0.45
	_aim(Vector3(2.6, 0.3, 0.2))
	for p: Array in [["sit", 0.0, Vector3(0, 0, 0.1), "Sits on a hard bench: her glutes flatten on it"],
			["back", PI / 2.0, Vector3.ZERO, "Lies on her back"],
			["prone", -PI / 2.0, Vector3.ZERO, "Face down: her chest squashes on the bench"],
			["sleep", 0.0, Vector3.ZERO, "Curls up on her side"]]:
		_say(p[3])
		walker.rotation.y = p[1]
		walker.position = p[2]
		eco.rest_pose = p[0]
		await _frames(200)
	cam_goal = Vector3(0.3, 1.0, 2.2)
	_say("From above")
	eco.rest_pose = "back"
	walker.rotation.y = PI / 2.0
	await _frames(160)
	eco.rest_pose = ""
	_say("Gets up")
	await _frames(100)


func _brace() -> void:
	_box(Vector3(0, 1.2, -1.1), Vector3(2.0, 2.4, 0.2), Color(0.6, 0.85, 1.0, 0.12), true)
	_aim(Vector3(2.0, 0.1, 0.4))
	_say("Walks into a wall and keeps pushing")
	for f in 260:
		if f == 110:
			_say("Held at full press: she braces her hands on it")
		_press(Vector3(0, 0, -1.3), 1)
		await _frames(1)
	_say("Turns away: pushes herself off it")
	walker.velocity += walker.press_normal * Player.BRACE_PUSH_OFF * walker.brace
	walker.brace = 0.0
	for f in 70:
		walker.velocity = walker.velocity.move_toward(Vector3.ZERO, 4.0 * STEP)
		walker.position += walker.velocity * STEP
		await _frames(1)
	walker.velocity = Vector3.ZERO
	_say("A wall at her side: the near hand goes up")
	walker.rotation.y = PI / 2.0
	_aim(Vector3(-1.6, 0.1, 1.6))
	for f in 220:
		_press(Vector3(0, 0, -1.3), 1)
		await _frames(1)
	walker.brace = 0.0
	await _frames(60)


func _squeeze() -> void:
	for snag: float in [0.0, 0.06]:
		var gap := 0.30 if snag == 0.0 else 0.27
		for side in [-1.0, 1.0]:
			_box(Vector3(side * (gap * 0.5 + 0.45), 1.2, -1.1), Vector3(0.9, 2.4, 1.2), Color(0.6, 0.85, 1.0, 0.14), true)
		if snag > 0.0:
			# a knob jutting out of the left wall, as in the lab
			_box(Vector3(-(gap * 0.5 - snag * 0.5), 1.2, -1.1), Vector3(snag, 0.22, 0.16), Color(0.85, 0.45, 0.2), false)
		walker.position = Vector3.ZERO
		walker.rotation.y = 0.0
		walker.sidling = false
		_aim(Vector3(1.6, 0.6, 0.9))
		_say("A 30 cm gap: she turns side-on and shuffles through" if snag == 0.0 else "A 27 cm gap with a snag jutting out...")
		var stuck_for := 0
		for f in 480:
			var stuck := walker.pinch > Player.STUCK_PINCH
			stuck_for = stuck_for + 1 if stuck else 0
			if stuck and stuck_for > 70 and f % 12 == 0:
				walker.squeeze = minf(walker.squeeze + Player.SQUEEZE_MASH, 1.0)
				if stuck_for == 72:
					_say("...stuck on it: mash jump to wriggle past")
			walker.squeeze = move_toward(walker.squeeze, 0.0, Player.SQUEEZE_FADE * STEP)
			_press(Vector3(0, 0, -1.2), 1)
			var face := walker.sidle_face if walker.sidling and walker.sidle_face != Vector3.ZERO else Vector3(0, 0, -1)
			walker.rotation.y = lerp_angle(walker.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * STEP))
			await _frames(1)
			if walker.position.z < -2.2:
				break
		await _frames(40)
		for c in set_piece.get_children():
			if c is StaticBody3D:
				c.queue_free()
		await _frames(1)


func _crowd() -> void:
	var mom: Node3D = HubNpc.create("mom", Vector3(0.28, 0, -1.6), 180.0)
	set_piece.add_child(mom)
	mom.look_target = walker
	walker.add_to_group("eco_player")
	_aim(Vector3(2.2, 0.3, 0.6))
	_say("Brushes past Mom")
	for f in 160:
		_press(Vector3(0, 0, -1.1), 1)
		await _frames(1)
	walker.position = Vector3(0.28, 0, -0.4)
	walker.rotation.y = 0.0
	_say("Bumps right into her: both give, Mom's taken by surprise")
	for f in 200:
		_press(Vector3(0, 0, -1.0), 1)
		await _frames(1)
	_say("Steps back")
	for f in 60:
		walker.position.z += 0.6 * STEP
		await _frames(1)
	await _frames(60)


func _jolt() -> void:
	_aim(Vector3(2.4, 0.2, 1.0))
	_say("Standing")
	await _frames(60)
	_say("A blast goes off nearby: the shock jolts her")
	FX.blast(set_piece, Vector3(-2.4, 0.5, -1.5), Color(1.0, 0.55, 0.2), 2.0, 0.4)
	await _frames(120)
	_say("A hit from the front")
	eco.jolt(Vector3(0, 0, 1.2))
	await _frames(100)
	cam_goal = Vector3(-1.4, 0.2, -2.0)
	_say("Another blast, seen from the front")
	FX.blast(set_piece, Vector3(2.0, 0.5, 2.0), Color(1.0, 0.55, 0.2), 2.0, 0.4)
	await _frames(140)


func _weather() -> void:
	var fan := Node3D.new()
	fan.add_to_group("wind_zone")
	fan.set_meta("half", Vector3(1.5, 1.5, 1.5))
	fan.set_meta("wind", Vector3(-9, 0, 0))
	fan.position = Vector3(0, 1.0, 0)
	set_piece.add_child(fan)
	_box(Vector3(2.0, 1.1, 0), Vector3(0.2, 1.8, 1.8), Color(0.3, 0.32, 0.35), false)
	_aim(Vector3(0.4, 0.2, 2.6))
	_say("A fan blowing from her left: wind streams her hair")
	await _frames(240)
	cam_goal = Vector3(-1.6, 0.2, 1.8)
	await _frames(120)
	fan.queue_free()
	_say("Wind drops")
	await _frames(90)
	var water := LaidOut.water(set_piece, Vector3(0, 1.0, -2.5), Vector2(4, 3), Color(0.25, 0.55, 0.7, 0.45))
	water.name = "Pool"
	_say("Wades in up to her waist")
	_aim(Vector3(2.4, 0.4, 0.8))
	for f in 140:
		walker.position.z -= 0.9 * STEP
		await _frames(1)
	await _frames(90)
	_say("Chest-deep: her chest floats up")
	water.position.y = 1.4
	await _frames(200)
	_say("Out of the water")
	water.queue_free()
	await _frames(120)


func _cling() -> void:
	walker.queue_free()
	var pair := []
	for i in 2:
		var w := Walker.new()
		w.position = Vector3(-0.45 + 0.9 * i, 0, 0)
		w.rotation.y = PI
		set_piece.add_child(w)
		var e = ECO.instantiate()
		e.jiggle_style = "classic"
		e.body_jiggle = true
		e.outfit = "y2k"
		e.cloth_cling = i == 1
		w.add_child(e)
		pair.append([w, e])
	walker = pair[1][0]
	focus_override = Vector3(0, 0.8, 0)
	cam_goal = Vector3(0.0, 0.3, 2.8)
	cam_offset = cam_goal
	_say("Skirt, hopping: cling off (left), on (right)")
	await _frames(40)
	for hop in 8:
		for f in 24:
			var y := 0.12 * sin(PI * f / 24.0)
			for p: Array in pair:
				p[0].position.y = y
			await _frames(1)
		for p: Array in pair:
			p[1].jolt(Vector3.DOWN * 0.8)
		await _frames(8)
		if hop == 3:
			cam_goal = Vector3(0.6, 0.3, 2.0)
	await _frames(80)


# --- helpers ------------------------------------------------------------------

## Soft press for the walker, as player.gd soft_press does it (spread, brace, pinch drag).
func _press(want: Vector3, _sub: int) -> void:
	var shape := walker.get_node("Core") as CollisionShape3D
	var out := Player.soft_press_at(walker.get_world_3d().direct_space_state, shape.global_transform, 1.6, want, [walker.get_rid()], 0xFFFFFFFF, walker.spread, 1.0, STEP, walker.squeeze)
	var v: Vector3 = out[0]
	var press: float = out[1]
	walker.pinch = out[4]
	if out[3] != Vector3.ZERO:
		walker.press_normal = out[3]
	var on: bool = out[2] and press > 0.85
	walker.spread = move_toward(walker.spread, 1.0 if on else 0.0, STEP / (Player.SPREAD_TIME if on else 0.5))
	# in a gap she turns side-on to a wall (player.gd soft_press)
	if walker.pinch > 0.02:
		walker.sidle_clear = Player.SIDLE_HOLD
		if not walker.sidling:
			var n: Vector3 = out[6]
			walker.sidle_face = n if n.dot(walker.global_basis.x) > 0.0 else -n
			walker.sidling = true
	elif walker.sidling:
		walker.sidle_clear -= STEP
		walker.sidling = walker.sidle_clear > 0.0
	if on and walker.pinch < 0.3 and not walker.sidling:
		walker.brace = move_toward(walker.brace, 1.0, STEP / Player.BRACE_TIME)
	else:
		walker.brace = move_toward(walker.brace, 0.0, STEP / 0.3)
	var drag := clampf((walker.pinch - 0.3) / 0.6, 0.0, 1.0) * (1.0 - 0.85 * walker.squeeze)
	v.x *= 1.0 - Player.PINCH_DRAG * drag
	v.z *= 1.0 - Player.PINCH_DRAG * drag
	for body: Node in out[5]:
		var person := body.get_parent()
		if person != null and person.has_method("bumped"):
			person.bumped(walker.global_position)
	walker.velocity = v
	walker.position += Vector3(v.x, 0, v.z) * STEP


func _reset() -> void:
	if set_piece != null:
		set_piece.queue_free()
	set_piece = Node3D.new()
	root.add_child(set_piece)
	walker = Walker.new()
	var core := CollisionShape3D.new()
	core.name = "Core"
	core.shape = CapsuleShape3D.new()
	(core.shape as CapsuleShape3D).radius = Player.STROLL_RADIUS
	(core.shape as CapsuleShape3D).height = 1.6
	core.position.y = 0.8
	walker.add_child(core)
	set_piece.add_child(walker)
	eco = ECO.instantiate()
	eco.jiggle_style = "classic"
	eco.body_jiggle = true
	walker.add_child(eco)
	focus_override = Vector3(INF, 0, 0)


func _aim(offset: Vector3) -> void:
	cam_goal = offset


func _frames(n: int) -> void:
	for i in n:
		cam_offset = cam_offset.lerp(cam_goal, 0.04)
		var c := focus_override if focus_override.x != INF else walker.global_position + Vector3(0, 0.9, 0)
		cam.look_at_from_position(c + cam_offset, c)
		await process_frame


func _box(at: Vector3, size: Vector3, color: Color, see_through: bool) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if see_through:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = at
	set_piece.add_child(body)


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
