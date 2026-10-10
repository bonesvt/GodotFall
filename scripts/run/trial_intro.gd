extends Node
## Level 2's opening (levels.gd "level2"): day one of Ophelia's trial in Trial
## Bay 7 (holding_cell.gd), nineteen days before Eco gets there, so the
## player knows who's in the cell and why before the level starts.
##   the bay dark and her frame empty
##   two colony orderlies stand her in the frame, muddy from the night she ran
##   the frame lifts her arms over her head and clamps her wrists together
##   the tracker band, the dose cuff, the headphones and last the visor go on
##   her, one at a time (colony_gear.gd fittings)
##   the orderlies step back, the bay powers up, the screen in front of her
##   face starts, and the words come
##   out on the street, through the screen: nineteen days, and nobody came
## Then black, and the level starts where the trial's got to. Plays the first
## time she loads in (tutorial.gd seen, "trial_intro"); F skips it. The run
## manager plays it when the zone loads and keeps its own controls off while
## busy(), with the grunts in the yard held still till it's over.

const SFX := preload("res://scripts/sfx.gd")
const HoldingCell := preload("res://scripts/run/holding_cell.gd")
const Levels := preload("res://scripts/run/levels.gd")

const SEEN := "trial_intro"
const BLACK := Color(0, 0, 0)
## The beats (s from the start).
const IN := 0.0
const BROUGHT := 3.4
const NAMED := 6.6
const ARMS := 10.2
const ARMS_TIME := 1.6
const BAND := 13.4
const CUFF := 16.2
const PHONES := 19.4
const VISOR := 22.6
const FIT_TIME := 2.2
const BACK := 26.0
const POWER := 27.4
const STREET := 32.0
const OUT := 36.4
const END := 37.4
## Each piece in the order it goes on her.
const GEAR := [["band", BAND], ["cuff", CUFF], ["headphones", PHONES], ["visor", VISOR]]
const LINES := [
	[IN + 0.4, "Nineteen days ago. Trial Bay 7, in the colony's holding block.", 3.0],
	[BROUGHT + 0.3, "Ophelia: \"Get OFF me. I can stand on my own.\"", 3.0],
	[NAMED, "Orderly: \"Subject seven. Ran on night two, picked up in the rain. Intake resumes.\"", 3.4],
	[NAMED + 3.4, "Ophelia: \"I wasn't running. I was going home.\"", 2.4],
	[ARMS + ARMS_TIME, "The frame takes her wrists over her head and locks them together.", 3.0],
	[BAND + 0.5, "Orderly: \"Tracker.\"", 2.0],
	[CUFF + 0.6, "Ophelia: \"Ow. Ow, what is that? What's in my arm?\"", 2.6],
	[PHONES + 0.4, "Orderly: \"Hymn, stage one. Audio.\"", 2.6],
	[VISOR, "Ophelia: \"No. Not my eyes. Please, not my eyes...\"", 2.8],
	[BACK + 0.2, "Orderly: \"Subject is fitted. Begin trial.\"", 2.0],
	[POWER + 1.2, "The screen: CALM.", 2.2],
	[POWER + 3.0, "Ophelia, very quietly: \"...I don't want to be calm.\"", 2.0],
	[STREET + 0.4, "The trial ran nineteen days. Nobody came for her.", 3.6],
]

var rm: Node
var t := -1.0
var cell: Node3D
var _cam: Camera3D
var _veil: ColorRect
var _bars: Array = []
var _orderlies: Array = []
var _said := {}
var _shot := ""
var _held: Array = []


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "TrialIntro"


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	# a letterbox while it plays
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.89
		bar.anchor_bottom = 0.11 if top else 1.0
		bar.visible = false
		layer.add_child(bar)
		_bars.append(bar)
	_veil = ColorRect.new()
	_veil.color = Color(BLACK, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


## Whether she's seen it on this save.
func seen() -> bool:
	return rm.tutorial.seen.has(SEEN)


## Plays it on the zone's holding cell.
func play(p_cell: Node3D) -> void:
	cell = p_cell
	t = 0.0
	_said.clear()
	_shot = ""
	_veil.color.a = 1.0
	for bar in _bars:
		bar.visible = true
	_show_hud(false)
	rm.player.set("entranced", true)
	rm.player.set("trance_dir", Vector3.ZERO)
	rm.player.velocity = Vector3.ZERO
	# the yard holds still till it's over
	_held.clear()
	for g in rm.zone_info.get("grunts", []):
		if is_instance_valid(g):
			_held.append([g, g.process_mode])
			g.process_mode = Node.PROCESS_MODE_DISABLED
	cell.begin_intake()
	cell.ophelia.visible = false
	_cam = Camera3D.new()
	_cam.name = "IntroCam"
	cell.add_child(_cam)
	_build_orderlies()
	_set_shot("empty")


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if t > 0.5 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel")):
		_finish()
		return
	# black in, a dip to black when they bring her in, black out at the end
	var dip := smoothstep(BROUGHT - 0.5, BROUGHT - 0.1, t) * (1.0 - smoothstep(BROUGHT, BROUGHT + 0.5, t))
	_veil.color.a = maxf(maxf(1.0 - smoothstep(IN, IN + 1.4, t), dip), smoothstep(OUT, OUT + 0.8, t))
	if t >= BROUGHT - 0.1 and not _said.has("brought"):
		_said["brought"] = true
		cell.ophelia.visible = true
		for o in _orderlies:
			o.visible = true
		SFX.play_at(cell, cell.to_global(Vector3(0, 1.4, 0)), "door_metal_close", -6.0, 0.9)
		_set_shot("her")
	_struggle()
	if t >= NAMED and _shot == "her":
		_set_shot("face")
	# her arms up into the clamp, the orderlies lifting them
	if t >= ARMS:
		var k := smoothstep(ARMS, ARMS + ARMS_TIME, t)
		cell.intake_arms(k)
		for o in _orderlies:
			(o.get_node("Arm") as Node3D).rotation.x = lerpf(0.4, 2.6, k) * (1.0 - smoothstep(ARMS + ARMS_TIME + 0.4, ARMS + ARMS_TIME + 1.2, t))
		if not _said.has("arms"):
			_said["arms"] = true
			_set_shot("arms")
			SFX.play(self, "titan_servo_2", -10.0, 1.5)
			cell.ophelia.mood(["surprised"])
		if k >= 1.0 and not _said.has("clamped"):
			_said["clamped"] = true
			SFX.play(self, "cache_unlock", -4.0, 0.7)
			cell.ophelia.mood(["angry", "down"])
	# the gear, a piece at a time
	var on := []
	for g in GEAR:
		if t < g[1]:
			break
		on.append(g[0])
		cell.intake_gear(on.duplicate(), g[0], smoothstep(g[1], g[1] + FIT_TIME, t))
		if not _said.has(g[0]):
			_said[g[0]] = true
			_fitting(g[0])
	if t >= BACK and not _said.has("back"):
		_said["back"] = true
		_set_shot("wide")
		for o in _orderlies:
			var tw := create_tween()
			tw.tween_property(o, "position", o.position + Vector3(0, 0, 1.6), 1.2)
	if t >= POWER and not _said.has("power"):
		_said["power"] = true
		cell.power(true)
		SFX.play(self, "titan_boot", -6.0, 0.8)
		SFX.play(self, "chime_2", -10.0)
		cell.ophelia.mood(["closed"])
		_set_shot("feed")
	if t >= STREET and not _said.has("street"):
		_said["street"] = true
		for o in _orderlies:
			o.visible = false
		_set_shot("street")
	for line in LINES:
		if t >= line[0] and not _said.has(line[1]):
			_said[line[1]] = true
			rm.hud.toast(line[1], line[2])
	if t >= END:
		_finish()


## A piece going on her: where the camera goes and how she takes it.
func _fitting(piece: String) -> void:
	match piece:
		"band":
			_set_shot("neck")
			SFX.play(self, "workbench_ratchet", -8.0, 1.2)
		"cuff":
			_set_shot("arms")
			SFX.play(self, "titan_hiss_short", -8.0, 2.0)
			cell.ophelia.mood(["sad", "shake"])
		"headphones":
			_set_shot("face")
			SFX.play(self, "titan_servo_3", -10.0, 1.6)
			cell.ophelia.mood(["angry", "lookaway"])
		"visor":
			_set_shot("close")
			SFX.play(self, "titan_hiss_short", -8.0, 2.4)
			SFX.play(self, "heartbeat", -6.0)
			cell.ophelia.mood(["sad"])


## Pulling against them till the clamp's on her.
func _struggle() -> void:
	if t < BROUGHT or t >= ARMS + ARMS_TIME or cell.ophelia == null:
		return
	var o: Node3D = cell.ophelia
	o.rotation.y = o.home_yaw + sin(t * 7.0) * 0.08 * (1.0 - smoothstep(ARMS, ARMS + ARMS_TIME, t))


## The camera, in the cell's space (it opens toward +z, she faces the street).
func _set_shot(which: String) -> void:
	_shot = which
	var c: Vector3 = HoldingCell.COLUMN
	match which:
		"empty":
			_look(c + Vector3(-1.9, 1.7, 2.2), c + Vector3(0, 1.2, -0.2), 55.0)
		"her":
			_look(c + Vector3(-1.5, 1.6, 2.0), c + Vector3(0, 1.25, 0), 50.0)
		"face":
			_look(c + Vector3(0.95, 1.55, 1.05), c + Vector3(0, 1.45, 0), 42.0)
		"arms":
			_look(c + Vector3(1.25, 1.8, 1.25), c + Vector3(0, 1.85, -0.1), 48.0)
		"neck":
			_look(c + Vector3(0.6, 1.45, 0.6), c + Vector3(0, 1.38, 0), 38.0)
		"close":
			_look(c + Vector3(0.5, 1.55, 0.55), c + Vector3(0, 1.52, 0), 34.0)
		"wide":
			_look(c + Vector3(-1.9, 1.7, 2.4), c + Vector3(0, 1.3, 0), 58.0)
		"feed":
			_look(c + Vector3(0.28, 1.62, -0.12), c + HoldingCell.FEED_AT, 52.0)
		"street":
			_look(Vector3(0.4, 1.6, 4.4), Vector3(0, 1.3, -2.2), 55.0)


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(cell.to_global(from), cell.to_global(at))
	_cam.make_current()


## Two colony orderlies in white, faceless behind black visors, one each side
## of her frame just outside its posts. Arm swings up as they lift her arms.
func _build_orderlies() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.9, 0.91, 0.93)
	white.roughness = 0.6
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.03, 0.03, 0.04)
	black.metallic = 0.4
	black.roughness = 0.2
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.4, 0.42, 0.46)
	for s in [-1.0, 1.0]:
		var o := Node3D.new()
		o.name = "Orderly"
		o.visible = false
		cell.add_child(o)
		o.position = HoldingCell.COLUMN + Vector3(0.88 * s, 0.0, 0.05)
		o.rotation.y = s * PI * 0.5   # facing her
		for leg in [-0.08, 0.08]:
			_part(o, Vector3(leg, 0.44, 0), _capsule(0.07, 0.9), white)
		_part(o, Vector3(0, 1.18, 0), _capsule(0.17, 0.66), white)          # body
		_part(o, Vector3(0, 0.98, 0), _capsule(0.175, 0.36), grey).scale = Vector3(1, 0.18, 1)   # belt
		_part(o, Vector3(0, 1.62, 0), _sphere(0.115), white)                # hood
		_part(o, Vector3(0, 1.63, -0.085), _sphere(0.07), black).scale = Vector3(1.3, 0.6, 0.6)  # visor
		var arm := Node3D.new()
		arm.name = "Arm"
		o.add_child(arm)
		arm.position = Vector3(0.2 * -s, 1.42, 0)   # the arm toward the street
		arm.rotation.x = 0.4
		_part(arm, Vector3(0, -0.3, 0), _capsule(0.05, 0.6), white)
		_part(arm, Vector3(0, -0.62, 0), _sphere(0.05), grey)              # glove
		_orderlies.append(o)


func _capsule(r: float, h: float) -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


func _sphere(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _part(parent: Node3D, at: Vector3, mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	return mi


## Over (or skipped): the trial's running, and the level starts.
func _finish() -> void:
	if t < 0.0:
		return
	t = -1.0
	_teardown()
	rm.tutorial.seen[SEEN] = true
	rm.tutorial._save()
	rm.tutorial.start_level(rm.run.level)
	rm.hud.toast(Levels.title(rm.run.level) + "\nGet her out of Trial Bay 7.", 4.0)


func _teardown() -> void:
	_veil.color.a = 0.0
	for bar in _bars:
		bar.visible = false
	for o in _orderlies:
		if is_instance_valid(o):
			o.queue_free()
	_orderlies.clear()
	if is_instance_valid(cell):
		cell.ophelia.visible = true
		cell.ophelia.rotation.y = cell.ophelia.home_yaw
		cell.end_intake()
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	for h in _held:
		if is_instance_valid(h[0]):
			h[0].process_mode = h[1]
	_held.clear()
	rm.player.set("entranced", false)
	if rm.player.camera != null:
		rm.player.camera.make_current()
	_show_hud(true)


## Stops it where it is, without starting the level (a new zone's loading).
func reset() -> void:
	if t < 0.0:
		return
	t = -1.0
	_teardown()


func _show_hud(on: bool) -> void:
	rm.hud.corners_hidden = not on
	if rm.get("pilot_hud") != null:
		rm.pilot_hud.visible = on
	rm.hud.status_label.visible = on
