extends Node
## Level 2's opening (levels.gd "level2"): day one of Ophelia's trial in Trial
## Bay 7 (holding_cell.gd), nineteen days before Eco gets there, so the
## player knows who's in the cell and why before the level starts.
##   the bay dark and her frame empty
##   two colony orderlies walk her in from the screen, muddy from the night
##   she ran, and turn her round in the frame
##   the frame lifts her arms over her head and clamps her wrists together
##   the tracker band, the dose cuff, the headphones and last the visor go on
##   her one at a time (colony_gear.gd fittings), an orderly's hand at each
##   the orderlies walk back out, the bay powers up, the screen in front of
##   her face starts, and the words come
##   black, then day 19: the same frame, her head hung forward, a calm bridge
##   in her nose and comfort gloves to her shoulders now, smiling on the
##   chime, the screen on new words and the log recommending Solace
## Then black, and the level starts there. The camera drifts through each shot
## and eases from one to the next (SHOTS, CUTS); the lines play as subtitles
## in the letterbox (LINES). Everything is staged from the clock (_seek()), so
## it plays the same however it's stepped. Plays the first time she loads in
## (tutorial.gd seen, "trial_intro"); F skips it. The run manager plays it
## when the zone loads and keeps its own controls off while busy(), with the
## grunts in the yard held still till it's over.

const SFX := preload("res://scripts/sfx.gd")
const HoldingCell := preload("res://scripts/run/holding_cell.gd")
const Levels := preload("res://scripts/run/levels.gd")

const SEEN := "trial_intro"
const BLACK := Color(0, 0, 0)
## The beats (s from the start).
const IN := 0.0
const WALK := 2.4
const WALK_TIME := 3.4
const TURN := WALK + WALK_TIME
const TURN_TIME := 0.9
const NAMED := 7.4
const ARMS := 11.0
const ARMS_TIME := 1.8
const BAND := 14.4
const CUFF := 17.4
const PHONES := 20.6
const VISOR := 23.8
const FIT_TIME := 2.2
## An orderly's hand comes up this long before a piece and goes down after.
const REACH := 0.7
const BACK := 27.4
const BACK_TIME := 2.0
const POWER := 29.0
const DAY19 := 34.0
const FACE19 := DAY19 + 3.6
const FEED19 := DAY19 + 7.2
const OUT := DAY19 + 10.4
const END := OUT + 1.0
## Each piece in the order it goes on her, and how high the orderly's arm
## comes up for it (rad: 0 hanging, PI straight up).
const GEAR := [["band", BAND, 1.55], ["cuff", CUFF, 2.7], ["headphones", PHONES, 1.95], ["visor", VISOR, 1.85]]
## The camera, in the cell's space from her column (it opens toward +z, she
## faces the street): [from, at, fov] at the start of a shot and at its end;
## it drifts between them for as long as the shot runs.
const SHOTS := {
	"empty": [Vector3(-2.0, 1.75, 2.4), Vector3(0, 1.2, -0.2), 56.0, Vector3(-1.6, 1.6, 1.9), Vector3(0, 1.25, -0.1), 52.0],
	"walk": [Vector3(-1.6, 1.55, 2.3), Vector3(0, 1.3, 1.6), 52.0, Vector3(-1.4, 1.5, 1.7), Vector3(0, 1.25, 0.2), 50.0],
	"face": [Vector3(1.05, 1.55, 1.2), Vector3(0, 1.45, 0), 42.0, Vector3(0.85, 1.52, 0.95), Vector3(0, 1.46, 0), 38.0],
	"arms": [Vector3(1.35, 1.65, 1.35), Vector3(0, 1.7, -0.1), 50.0, Vector3(1.15, 1.85, 1.15), Vector3(0, 1.9, -0.1), 46.0],
	"neck": [Vector3(0.5, 1.6, 0.5), Vector3(0, 1.49, 0), 30.0, Vector3(0.42, 1.58, 0.42), Vector3(0, 1.49, 0), 27.0],
	"cuff": [Vector3(1.0, 1.95, 0.9), Vector3(0, 2.0, -0.1), 40.0, Vector3(0.8, 2.0, 0.75), Vector3(0, 2.02, -0.1), 36.0],
	"close": [Vector3(0.6, 1.56, 0.62), Vector3(0, 1.52, 0), 36.0, Vector3(0.48, 1.54, 0.5), Vector3(0, 1.52, 0), 32.0],
	"wide": [Vector3(-1.7, 1.6, 2.0), Vector3(0, 1.3, 0), 56.0, Vector3(-2.0, 1.75, 2.5), Vector3(0, 1.3, 0.2), 58.0],
	"feed": [Vector3(0.3, 1.62, -0.1), HoldingCell.FEED_AT, 56.0, Vector3(0.26, 1.6, -0.14), HoldingCell.FEED_AT, 46.0],
	"wide19": [Vector3(1.7, 1.3, 1.9), Vector3(0, 1.3, 0), 48.0, Vector3(1.35, 1.35, 1.45), Vector3(0, 1.35, 0), 44.0],
	"close19": [Vector3(0.55, 1.28, 0.6), Vector3(0, 1.46, 0), 38.0, Vector3(0.45, 1.32, 0.48), Vector3(0, 1.47, 0), 33.0],
	"log": [Vector3(1.0, 1.6, 1.4), Vector3(-2.8, 1.9, 0.6), 52.0, Vector3(1.2, 1.75, 1.7), Vector3(-2.8, 1.9, 0.6), 48.0],
}
## When each shot starts and how long the camera takes to ease into it from
## wherever it was (0: a cut).
const CUTS := [
	[IN, "empty", 0.0],
	[WALK + 0.6, "walk", 1.8],
	[NAMED - 0.4, "face", 1.4],
	[ARMS - 0.3, "arms", 1.2],
	[BAND - 0.5, "neck", 1.0],
	[CUFF - 0.5, "cuff", 1.0],
	[PHONES - 0.5, "face", 1.0],
	[VISOR - 0.5, "close", 0.9],
	[BACK, "wide", 1.6],
	[POWER, "feed", 0.0],
	[DAY19, "wide19", 0.0],
	[FACE19, "close19", 1.6],
	[FEED19, "log", 1.8],
]
## [start, line, seconds on screen]
const LINES := [
	[IN + 0.8, "Nineteen days ago. Trial Bay 7, the colony's holding block.", 3.4],
	[WALK + 0.8, "Ophelia: \"Get OFF me. I can walk on my own.\"", 2.8],
	[NAMED, "Orderly: \"Subject seven. Ran on night two, picked up in the rain. Intake resumes.\"", 3.4],
	[NAMED + 3.5, "Ophelia: \"I wasn't running. I was going home.\"", 2.3],
	[ARMS + ARMS_TIME + 0.2, "The frame takes her wrists over her head and locks them together.", 2.6],
	[BAND + 0.6, "Orderly: \"Tracker.\"", 1.8],
	[CUFF + 0.7, "Ophelia: \"Ow. Ow, what is that? What's in my arm?\"", 2.4],
	[PHONES + 0.5, "Orderly: \"Hymn, stage one. Audio.\"", 2.4],
	[VISOR, "Ophelia: \"No. Not my eyes. Please, not my eyes...\"", 2.8],
	[BACK + 0.4, "Orderly: \"Subject is fitted. Begin trial.\"", 2.2],
	[POWER + 1.4, "The screen: CALM.", 1.8],
	[POWER + 3.0, "Ophelia, very quietly: \"...I don't want to be calm.\"", 2.0],
	[DAY19 + 0.8, "Day 19.", 2.4],
	[FACE19 + 0.9, "The chime. Under the visor, she smiles.", 2.2],
	[FACE19 + 2.7, "Ophelia, softly: \"Thank you.\"", 1.8],
	[FEED19 + 0.5, "The wall log: D19  RESPONDS TO PRAISE. RECOMMEND WIDER ROLLOUT: SOLACE.", 3.4],
]
## Where she and the orderlies come in from (just inside the screen), and
## where the orderlies stand by her frame (cell space, from her column).
const ENTRY := Vector3(0, 0, 2.0)
const BESIDE := Vector3(0.88, 0, 0.05)
const ESCORT := Vector3(0.48, 0, 0.12)

var rm: Node
var t := -1.0
var cell: Node3D
var _cam: Camera3D
var _veil: ColorRect
var _bars: Array = []
var _sub: Label
var _orderlies: Array = []
var _said := {}
var _shot := ""
var _held: Array = []
## The camera when the current shot began, for easing out of it.
var _from_pose: Array = []
var _cut := -1


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "TrialIntro"


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(BLACK, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)
	# a letterbox while it plays, the lines in the bottom bar
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.87
		bar.anchor_bottom = 0.13 if top else 1.0
		bar.visible = false
		layer.add_child(bar)
		_bars.append(bar)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.offset_left = 80.0
	_sub.offset_right = -80.0
	(_bars[1] as Control).add_child(_sub)


func busy() -> bool:
	return t >= 0.0


## Whether she's seen it on this save.
func seen() -> bool:
	return rm.tutorial.seen.has(SEEN)


## Plays it on the zone's holding cell.
func play(p_cell: Node3D) -> void:
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
	stage(p_cell)
	t = 0.0
	_seek(0.0)


## Sets the bay up for it: back to day one, the camera and the orderlies.
func stage(p_cell: Node3D) -> void:
	cell = p_cell
	_said.clear()
	_shot = ""
	_cut = -1
	for bar in _bars:
		bar.visible = true
	cell.begin_intake()
	cell.ophelia.position = HoldingCell.COLUMN + ENTRY + Vector3.UP * HoldingCell.PAD_TOP
	_cam = Camera3D.new()
	_cam.name = "IntroCam"
	cell.add_child(_cam)
	_build_orderlies()


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if t > 0.5 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel")):
		_finish()
		return
	_seek(t)
	if t >= END:
		_finish()


## Everything at `at` seconds in.
func _seek(at: float) -> void:
	# black in, a dip to black into day 19, black out at the end
	var dip := smoothstep(DAY19 - 1.2, DAY19 - 0.3, at) * (1.0 - smoothstep(DAY19 + 0.3, DAY19 + 1.5, at))
	_veil.color.a = maxf(maxf(1.0 - smoothstep(IN, IN + 1.6, at), dip), smoothstep(OUT, OUT + 0.9, at))
	if at < DAY19:
		_day_one(at)
	elif not _said.has("day19"):
		_said["day19"] = true
		for o in _orderlies:
			o.visible = false
		cell.end_intake()
	if at >= FACE19 and not _said.has("chime"):
		_said["chime"] = true
		SFX.play(self, "chime_2", -8.0)
	_camera(at)
	_subtitle(at)


func _day_one(at: float) -> void:
	var oph: Node3D = cell.ophelia
	var c: Vector3 = HoldingCell.COLUMN
	# walked in from the screen, backwards into the frame, then turned round
	var walk := smoothstep(WALK, WALK + WALK_TIME, at)
	var turn := smoothstep(TURN, TURN + TURN_TIME, at)
	var bob := absf(sin(at * 9.0)) * 0.02 * float(walk > 0.0 and walk < 1.0)
	oph.position = c + ENTRY.lerp(Vector3.ZERO, walk) + Vector3.UP * (HoldingCell.PAD_TOP + bob)
	var pull := sin(at * 6.5) * 0.12 * (1.0 - smoothstep(ARMS, ARMS + ARMS_TIME, at)) * smoothstep(WALK, WALK + 0.4, at)
	oph.home_yaw = lerpf(0.0, PI, turn) + pull
	if walk > 0.0 and walk < 1.0 and not _said.has("steps"):
		_said["steps"] = true
		for i in 6:
			get_tree().create_timer(i * 0.55, false).timeout.connect(_step)
	for i in _orderlies.size():
		var o: Node3D = _orderlies[i]
		var s := -1.0 if i == 0 else 1.0
		var back := smoothstep(BACK, BACK + BACK_TIME, at)
		var side := Vector3(ESCORT.x * s, 0, ESCORT.z).lerp(Vector3(BESIDE.x * s, 0, BESIDE.z), turn)
		var pos := ENTRY.lerp(Vector3.ZERO, walk) + side
		pos = pos.lerp(ENTRY + Vector3(BESIDE.x * s * 0.6, 0, 0.2), back)
		o.position = c + pos
		# facing in as they walk, then her, then the way out
		o.rotation.y = lerp_angle(lerp_angle(0.0, s * PI * 0.5, turn), PI, smoothstep(BACK, BACK + 0.5, at))
		var moving := walk > 0.0 and walk < 1.0 or back > 0.0 and back < 1.0
		_stride(o, at, 1.0 if moving else 0.0)
		_reach(o, at, s)
	# her arms up into the clamp, the orderlies lifting them
	var k := smoothstep(ARMS, ARMS + ARMS_TIME, at)
	if at >= ARMS:
		cell.intake_arms(k)
		if not _said.has("arms"):
			_said["arms"] = true
			SFX.play(self, "titan_servo_2", -10.0, 1.5)
			oph.mood(["surprised"])
		if k >= 1.0 and not _said.has("clamped"):
			_said["clamped"] = true
			SFX.play(self, "cache_unlock", -4.0, 0.7)
			oph.mood(["angry", "down"])
	elif at >= NAMED and not _said.has("named"):
		_said["named"] = true
		oph.mood(["angry", "lookaway"])
	# the gear, a piece at a time
	var on := []
	for g in GEAR:
		if at < g[1]:
			break
		on.append(g[0])
		cell.intake_gear(on.duplicate(), g[0], smoothstep(g[1], g[1] + FIT_TIME, at))
		if not _said.has(g[0]):
			_said[g[0]] = true
			_fitting(g[0])
	if at >= POWER and not _said.has("power"):
		_said["power"] = true
		cell.power(true)
		SFX.play(self, "titan_boot", -6.0, 0.8)
		SFX.play(self, "chime_2", -10.0)
		oph.mood(["closed"])


## How each piece lands on her.
func _fitting(piece: String) -> void:
	match piece:
		"band":
			SFX.play(self, "workbench_ratchet", -8.0, 1.2)
		"cuff":
			SFX.play(self, "titan_hiss_short", -8.0, 2.0)
			cell.ophelia.mood(["sad", "shake"])
		"headphones":
			SFX.play(self, "titan_servo_3", -10.0, 1.6)
			cell.ophelia.mood(["angry", "lookaway"])
		"visor":
			SFX.play(self, "titan_hiss_short", -8.0, 2.4)
			SFX.play(self, "heartbeat", -6.0)
			cell.ophelia.mood(["sad"])


func _step() -> void:
	if t >= 0.0 and is_instance_valid(cell):
		SFX.play_at(cell, cell.to_global(HoldingCell.COLUMN + ENTRY * 0.5), "step_concrete_%d" % (randi() % 5 + 1), -12.0)


## Legs swinging and a bob while they walk (0 standing .. 1 walking).
func _stride(o: Node3D, at: float, walking: float) -> void:
	var swing := sin(at * 9.0) * 0.45 * walking
	(o.get_node("LegL") as Node3D).rotation.x = swing
	(o.get_node("LegR") as Node3D).rotation.x = -swing
	(o.get_node("Body") as Node3D).position.y = absf(sin(at * 9.0)) * 0.025 * walking


## Their hands: holding her arm on the way in, lifting her arms into the
## clamp, then one at each piece of gear (GEAR) as it goes on.
func _reach(o: Node3D, at: float, s: float) -> void:
	var lift := 0.5 * smoothstep(WALK - 0.3, WALK, at) * (1.0 - smoothstep(TURN, TURN + TURN_TIME, at))
	lift = maxf(lift, 2.6 * smoothstep(ARMS - 0.4, ARMS + ARMS_TIME * 0.6, at) * (1.0 - smoothstep(ARMS + ARMS_TIME + 0.3, ARMS + ARMS_TIME + 1.1, at)))
	for i in GEAR.size():
		var g: Array = GEAR[i]
		if (i % 2 == 0) == (s < 0.0):   # they take turns
			var up := smoothstep(g[1] - REACH, g[1], at) * (1.0 - smoothstep(g[1] + FIT_TIME, g[1] + FIT_TIME + REACH, at))
			lift = maxf(lift, float(g[2]) * up)
	(o.get_node("Body/Arm") as Node3D).rotation.x = 0.2 + lift


## The camera through its shot, eased out of the last one.
func _camera(at: float) -> void:
	var i := 0
	while i + 1 < CUTS.size() and at >= float(CUTS[i + 1][0]):
		i += 1
	var start := float(CUTS[i][0])
	var stop := float(CUTS[i + 1][0]) if i + 1 < CUTS.size() else END
	var shot: Array = SHOTS[CUTS[i][1]]
	var p := smoothstep(0.0, 1.0, clampf((at - start) / maxf(stop - start, 0.01), 0.0, 1.0))
	var pose := [(shot[0] as Vector3).lerp(shot[3], p), (shot[1] as Vector3).lerp(shot[4], p), lerpf(shot[2], shot[5], p)]
	if i != _cut:
		_from_pose = _pose_now() if _cut >= 0 else pose
		_cut = i
		_shot = CUTS[i][1]
	var blend := float(CUTS[i][2])
	if blend > 0.0 and at - start < blend and not _from_pose.is_empty():
		var b := smoothstep(0.0, blend, at - start)
		pose = [(_from_pose[0] as Vector3).lerp(pose[0], b), (_from_pose[1] as Vector3).lerp(pose[1], b), lerpf(_from_pose[2], pose[2], b)]
	_look(pose[0], pose[1], pose[2])


## Where the camera is looking from and at now (column space) and its fov.
func _pose_now() -> Array:
	var c: Vector3 = HoldingCell.COLUMN
	var from := cell.to_local(_cam.global_position) - c
	var ahead := cell.to_local(_cam.global_position - _cam.global_basis.z) - c
	return [from, from + (ahead - from) * 1.5, _cam.fov]


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	var c: Vector3 = HoldingCell.COLUMN
	_cam.fov = fov
	_cam.look_at_from_position(cell.to_global(c + from), cell.to_global(c + at))
	_cam.make_current()


## The line on now, faded in and out in the letterbox.
func _subtitle(at: float) -> void:
	var text := ""
	var alpha := 0.0
	for line in LINES:
		var a := float(line[0])
		var b := a + float(line[2])
		if at >= a and at < b:
			text = line[1]
			alpha = smoothstep(a, a + 0.25, at) * (1.0 - smoothstep(b - 0.3, b, at))
	_sub.text = text
	_sub.modulate.a = alpha


## Two colony orderlies in white, faceless behind black visors. Their legs,
## body and the arm toward her swing (_stride, _reach).
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
		cell.add_child(o)
		for leg in [["LegL", -0.08], ["LegR", 0.08]]:
			var hip := Node3D.new()
			hip.name = leg[0]
			o.add_child(hip)
			hip.position = Vector3(leg[1], 0.88, 0)
			_part(hip, Vector3(0, -0.44, 0), _capsule(0.07, 0.9), white)
		var body := Node3D.new()
		body.name = "Body"
		o.add_child(body)
		_part(body, Vector3(0, 1.18, 0), _capsule(0.17, 0.66), white)
		_part(body, Vector3(0, 0.98, 0), _capsule(0.175, 0.36), grey).scale = Vector3(1, 0.18, 1)   # belt
		_part(body, Vector3(0, 1.62, 0), _sphere(0.115), white)                # hood
		_part(body, Vector3(0, 1.63, -0.085), _sphere(0.07), black).scale = Vector3(1.3, 0.6, 0.6)  # visor
		var arm := Node3D.new()
		arm.name = "Arm"
		body.add_child(arm)
		arm.position = Vector3(0.2 * -s, 1.42, 0)   # the arm toward her
		_part(arm, Vector3(0, -0.3, 0), _capsule(0.05, 0.6), white)
		_part(arm, Vector3(0, -0.62, 0), _sphere(0.05), grey)              # glove
		var other := Node3D.new()
		body.add_child(other)
		other.position = Vector3(0.2 * s, 1.42, 0)
		other.rotation.x = 0.1
		_part(other, Vector3(0, -0.3, 0), _capsule(0.05, 0.6), white)
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
	_sub.text = ""
	for bar in _bars:
		bar.visible = false
	for o in _orderlies:
		if is_instance_valid(o):
			o.queue_free()
	_orderlies.clear()
	if is_instance_valid(cell):
		var oph: Node3D = cell.ophelia
		oph.position = HoldingCell.COLUMN + Vector3.UP * HoldingCell.PAD_TOP
		oph.home_yaw = PI
		oph.rotation.y = PI
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
