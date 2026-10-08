extends Node
## The fitting (hymn.gd): after the Shepherd brings Eco in, the dispensary's
## back room, white and humming. She stands in the fitting frame while an arm
## comes down from the ceiling with the next piece of its gear
## (colony_gear.gd) and puts it on her, in a close-up:
##   headphones  the cups come in open, a pin slides out of each into her
##               ear, and they clamp shut
##   cuff        needles slide into her wrist and the cuff closes round them
##   visor       it stops just in front of her face, glass suction cups reach
##               out of it and seal onto her eyes, it seats over them, a prong
##               into each temple, and its first orders flash up (visor_screen.gd)
## Then the arm goes back up, the room whites out, and she wakes outside at the
## dispensary. With someone taken with her (hub_grip.gd) they're sat in two
## fitting chairs facing each other (standing for the spine), and the fitting
## plays in first person: Eco watching them get theirs while hers goes on. Built well below the hub on its own (SET), with its own copy of
## her in what she's wearing. The run manager plays it and keeps its own
## controls off while busy().

const Hymn := preload("res://scripts/hub/hymn.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const EcoRest := preload("res://scripts/ps2/eco_rest.gd")

## Where the back room is built (out of sight under the hub).
const SET := Vector3(0, -160, 0)
const WHITE := Color(0.95, 0.97, 1.0)
## The salon cut (hair.gd) her hair's pulled back into for the headphones' fitting.
const HAIR_BACK := "undercut"  # her left side buzzed: that ear clear for the close-up

## The beats, in seconds.
const IN := 0.8        # the white-out clears on the room
const LOWER := 1.0     # the arm comes down with it
const ON := 3.4        # it's on her: the close-up
const FIT := 4.0       # the fitting itself, ON..FIT+FIT_TIME
const FIT_TIME := 3.2
const LOCK := 7.4      # locked
const UP := 8.6        # the arm goes back up
const OUT := 10.0      # white
const END := 11.2

const INTRO := "The dispensary's back room. White walls, a hum, a frame that holds her up. Something comes down from the ceiling."
const INTRO_ACROSS := "The dispensary's back room. Two white chairs, facing. Eco can't move. Across from her, %s can't either. Something comes down from the ceiling."
const LINES := {
	"headphones": ["Clippers buzz her left side short to the skin. The arm sets a pair of white headphones round her head, cups open.",
		"Thin pins slide out of the cups and into her ears. She can't flinch. Click. Click.",
		"Calm voice, inside her head now: \"Compliance audio engaged. You will hear us everywhere.\""],
	"cuff": ["A white cuff, open like a jaw, comes down to her left wrist.",
		"Four needles find the veins first. Then the cuff closes over them and locks.",
		"Calm voice: \"Dose cuff fitted. Miss the line and the line will come to you.\""],
	"visor": ["A white visor comes down and stops a breath from her face.",
		"Two soft glass cups reach out of its inside and settle over her eyes. They seal with a wet click. She can't blink.",
		"It seats over them, prongs into her temples, and lights up. OBEY. OBEY. OBEY. Calm voice: \"See only what is true.\""],
}
const MORE_LINES := {
	"bridge": ["A white clip comes down to the bridge of her nose and snaps on.",
		"Two thin tubes feed up into her nostrils and lock with a hiss. Lavender. Linen. Clean.",
		"Calm voice: \"The colony smells like home now.\""],
	"gloves": ["Two long white gloves come down to her hands.",
		"They slide up her arms to the shoulder and seal. Lines of light run down to every fingertip.",
		"She can't feel her own hands. Calm voice: \"Warmth when you're good. Cold when you're not.\""],
	"band": ["A heavy grey band comes down, open, and closes round her throat.",
		"Bolts drive home at the back of her neck. A small speaker under her chin crackles, and a light beside it starts to blink.",
		"Calm voice, from her own throat now: \"Tracking engaged. Wherever you run, you'll tell us.\""],
	"crown": ["The room goes quiet. Something white and thin comes down out of the ceiling, slow, to her head.",
		"It settles on her brow. Every piece on her lights up at once: her ears, her eyes, her wrist, her back, her throat.",
		"Calm voice, from everywhere: \"Welcome home, citizen.\""],
	"spine": ["Something long and white comes down behind her, to her back.",
		"She stands in the frame while it clicks onto her spine segment by segment, shoulders to waist, each node lighting as it locks.",
		"Her back straightens on its own. Calm voice: \"Walk with everyone. Never alone.\""],
}
const BESIDE := "  Across from her, %s gets the same. Eco can't look away."
## The fitting chairs: seat height, and how far apart they face each other.
const SEAT := 0.46
const ACROSS := 2.1
## Eco's own copy goes on this render layer, which the first-person camera leaves out.
const ECO_LAYER := 1 << 19
const AFTER := "Eco wakes on the bench outside the dispensary. Her %s won't come off. She's tried."

var rm: Node
var t := -1.0
var piece := ""
## The visor's orders flash up at the end of its fitting (visor_screen.gd reads it).
var visor_flash := false
## Someone she loves, taken with her (hub_grip.gd), and the piece going on them.
var with := ""
var with_piece := ""
var _with_model: Node3D
var _with_rest: EcoRest
var _with_anim: AnimationPlayer
var _with_gear: Node3D
var _with_arm: Node3D
var _with_rod: MeshInstance3D
var _pov := false
var _set: Node3D
var _eco: Node3D
var _gear: Node3D
var _arm: Node3D
var _arm_rod: MeshInstance3D
var _cam: Camera3D
var _veil_layer: CanvasLayer
var _veil: ColorRect
var _obey: Label
var _said := {}


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "FittingScene"


func _ready() -> void:
	_veil_layer = CanvasLayer.new()
	_veil_layer.layer = 4
	add_child(_veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(WHITE, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_layer.add_child(_veil)
	_obey = Label.new()
	_obey.text = "OBEY"
	_obey.add_theme_font_size_override("font_size", 160)
	_obey.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	_obey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_obey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obey.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_obey.visible = false
	_veil_layer.add_child(_obey)


func busy() -> bool:
	return t >= 0.0


## Plays the fitting of `p` (a Hymn.GEAR piece), from white; `p_with` (hub_grip.gd)
## was taken with her and gets `p_with_piece` in the next frame over.
func play(p: String, p_with := "", p_with_piece := "") -> void:
	piece = p
	with = p_with
	with_piece = p_with_piece
	t = 0.0
	_said.clear()
	visor_flash = false
	_veil.color.a = 1.0
	rm.player.set("entranced", true)
	rm.player.set("trance_dir", Vector3.ZERO)
	_show_hud(false)
	_build()
	_shot("wide")
	rm.hud.toast(INTRO_ACROSS % HubGrip.NAMES[with] if with != "" and with_piece != "" else INTRO, 3.0)
	SFX.play(self, "titan_powerdown", -14.0, 1.6)


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	# the white-out clearing, and coming back at the end
	_veil.color.a = maxf(1.0 - smoothstep(0.0, IN, t), smoothstep(OUT, OUT + 0.8, t))
	# the Crown: every piece lights at once, then white, and one word
	var crowned := piece == "crown" and t >= LOCK and t < UP
	_obey.visible = crowned
	if crowned:
		_veil.color.a = maxf(_veil.color.a, smoothstep(LOCK, LOCK + 0.25, t) * (1.0 - smoothstep(UP - 0.5, UP, t)))
	# the arm: down with it, holding still, back up
	var down := smoothstep(LOWER, ON, t) * (1.0 - smoothstep(UP, UP + 1.2, t))
	var k := clampf((t - FIT) / FIT_TIME, 0.0, 1.0)
	# their animation first, then their chair pose over it (eco_rest.gd)
	if _with_anim != null:
		_with_anim.advance(delta)
	if _with_rest != null:
		_with_rest.step(delta, "chair")
	if _eco != null:
		ColonyGear.fit_model(_eco, piece, k)
		if _with_model != null:
			ColonyGear.fit_model(_with_model, with_piece, k)
		var drop := Vector3(0, 0.45 * (1.0 - smoothstep(LOWER, ON, t)), 0)
		if _gear != null and piece in ["headphones", "cuff"]:  # the others' fit() brings them down
			_gear.position = drop
		if _with_gear != null and with_piece in ["headphones", "cuff"]:
			_with_gear.position = drop
	_place_arm(_arm, _arm_rod, _eco, piece, down)
	_place_arm(_with_arm, _with_rod, _with_model, with_piece, down)
	if t >= ON and not _said.has("on"):
		_said["on"] = true
		_shot("pov" if _with_model != null else "close")
		rm.hud.toast(_lines()[0] + (BESIDE % HubGrip.NAMES[with] if _with_model != null else ""), 3.0)
		SFX.play(self, "titan_servo_2", -8.0, 1.4)
	if t >= FIT + FIT_TIME * 0.35 and not _said.has("fit"):
		_said["fit"] = true
		rm.hud.toast(_lines()[1], 3.0)
		SFX.play(self, "titan_hiss_short", -8.0, 2.2)
	if t >= LOCK and not _said.has("lock"):
		_said["lock"] = true
		rm.hud.toast(_lines()[2], 3.0)
		SFX.play(self, "cache_unlock", -4.0, 0.7)
		SFX.play(self, "heartbeat", -6.0)
		visor_flash = piece == "visor"
		if _with_model != null:
			_with_model.mood(["smile"])  # calm, all at once
	if _cam != null and _pov:
		_aim_pov()
		_cam.fov = lerpf(52.0, 34.0, smoothstep(ON, LOCK, t))
	elif _cam != null and t >= ON:
		_cam.fov = lerpf(32.0, 24.0, smoothstep(ON, LOCK, t))
	if t >= UP and not _said.has("up"):
		_said["up"] = true
		visor_flash = false
		_shot("wide")
		SFX.play(self, "titan_servo_3", -8.0, 1.3)
	if t >= END:
		_finish()


func _finish() -> void:
	t = -1.0
	_veil.color.a = 0.0
	visor_flash = false
	_teardown()
	_show_hud(true)
	rm.player.set("entranced", false)
	if Hymn.GEAR_NAMES.has(piece):
		rm.hud.toast(AFTER % Hymn.GEAR_NAMES[piece], 6.0)
	rm.fitted(piece)  # after: who was taken with her says so over it


## Stops it where it is (the hub was left under it, say).
func reset() -> void:
	if t < 0.0:
		return
	t = -1.0
	_veil.color.a = 0.0
	visor_flash = false
	_teardown()
	_show_hud(true)


func _show_hud(on: bool) -> void:
	rm.hud.corners_hidden = not on
	if rm.get("pilot_hud") != null:
		rm.pilot_hud.visible = on
	rm.hud.status_label.visible = on


# --- the set ---------------------------------------------------------------------

func _build() -> void:
	_teardown()
	_set = Node3D.new()
	_set.name = "FittingRoom"
	_set.position = SET
	rm.add_child(_set)
	var wall := _mat(Color(0.9, 0.92, 0.95), 0.0)
	var trim := _mat(Color(0.55, 0.6, 0.68), 0.0)
	var lit := _mat(Color(0.85, 0.95, 1.0), 2.5)
	_box(Vector3(0, -0.05, 0), Vector3(7, 0.1, 7), wall)          # floor
	_box(Vector3(0, 3.2, 0), Vector3(7, 0.1, 7), wall)            # ceiling
	_box(Vector3(0, 1.6, 2.2), Vector3(7, 3.3, 0.1), wall)        # back wall
	_box(Vector3(-3.0, 1.6, 0), Vector3(0.1, 3.3, 7), wall)       # side walls
	_box(Vector3(3.0, 1.6, 0), Vector3(0.1, 3.3, 7), wall)
	_box(Vector3(0, 1.6, -3.4), Vector3(7, 3.3, 0.1), wall)
	for x in [-1.6, 0.0, 1.6]:
		_box(Vector3(x, 3.13, -0.6), Vector3(1.0, 0.03, 2.4), lit)  # light panels
	_box(Vector3(0, 1.0, 2.14), Vector3(2.4, 0.04, 0.02), lit)     # a lit seam on the back wall
	var light := OmniLight3D.new()
	light.light_color = Color(0.92, 0.96, 1.0)
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.position = Vector3(0, 2.8, -1.2)
	_set.add_child(light)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.8, 0.88, 1.0)
	fill.light_energy = 0.8
	fill.omni_range = 5.0
	fill.position = Vector3(-1.5, 1.6, -1.8)
	_set.add_child(fill)
	var across := with != "" and with_piece != ""
	# her, in what she has on, with the gear she had plus this piece, its parts open
	_eco = ECO.instantiate()
	_set.add_child(_eco)
	var body: Node = rm.player.get_node_or_null("EcoBody/Body")
	if body != null and body.get("outfit") != null:
		_eco.wear(String(body.outfit))
	# for the headphones the frame pulls her hair back and ties it, so you see the pins go in
	Hair.apply(_eco, "eco", HAIR_BACK if piece == "headphones" else "")
	var gear: Array = Hymn.gear.duplicate()
	if not piece in gear:
		gear.append(piece)
	ColonyGear.apply(_eco, gear)
	_gear = ColonyGear.piece_node(_eco, piece)
	ColonyGear.fit_model(_eco, piece, 0.0)
	# sat in her chair facing them, or stood in the frame (the spine's fitted standing)
	if across and piece != "spine":
		_eco.rest_pose = "chair"
		_eco.rest_seat_height = SEAT
		_chair(Vector3.ZERO, 1.0, trim, wall)
	else:
		_frame(Vector3.ZERO, 1.0, trim)
	# whoever was taken with her, across from her
	if across:
		_with_model = HubNpc.create(with, Vector3(0, 0, -ACROSS), 180.0)
		_set.add_child(_with_model)
		_with_model.posed = true
		if is_instance_valid(_with_model.soft_body):
			_with_model.soft_body.queue_free()
		ColonyGear.apply(_with_model, HubGrip.gear_of(with))
		_with_gear = ColonyGear.piece_node(_with_model, with_piece)
		ColonyGear.fit_model(_with_model, with_piece, 0.0)
		_with_model.mood(["sad"])
		var skel := _with_model.find_child("Skeleton3D", true, false) as Skeleton3D
		if with_piece != "spine" and skel != null:
			_with_anim = _with_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if _with_anim != null:  # stepped here, so the chair pose goes on after it
				_with_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			_with_rest = EcoRest.new(skel)
			_with_rest.seat_height = SEAT
			if not _with_rest.usable():
				_with_rest = null
			_chair(Vector3(0, 0, -ACROSS), -1.0, trim, wall)
		else:
			_frame(Vector3(0, 0, -ACROSS), -1.0, trim)
		var arm2: Array = _make_arm(trim, wall, lit)
		_with_arm = arm2[0]
		_with_rod = arm2[1]
		# Eco's own copy stays out of her eyes' view
		for v in _eco.find_children("*", "VisualInstance3D", true, false):
			(v as VisualInstance3D).layers = ECO_LAYER
	var arm: Array = _make_arm(trim, wall, lit)
	_arm = arm[0]
	_arm_rod = arm[1]


## The fitting frame behind someone at `at` facing -Z (`face` -1: facing +Z).
func _frame(at: Vector3, face: float, trim: Material) -> void:
	for s in [-1.0, 1.0]:
		_box(at + Vector3(0.55 * s, 1.1, 0.35 * face), Vector3(0.1, 2.2, 0.1), trim)
	_box(at + Vector3(0, 2.2, 0.35 * face), Vector3(1.2, 0.1, 0.1), trim)


## A fitting chair under someone sat at `at` facing -Z (`face` -1: facing +Z):
## a white seat on a grey post, and a low back that leaves the spine clear.
func _chair(at: Vector3, face: float, trim: Material, wall: Material) -> void:
	_box(at + Vector3(0, SEAT - 0.04, -0.12 * face), Vector3(0.5, 0.08, 0.5), wall)
	_box(at + Vector3(0, (SEAT - 0.08) * 0.5, -0.1 * face), Vector3(0.12, SEAT - 0.08, 0.12), trim)
	_box(at + Vector3(0, 0.02, -0.1 * face), Vector3(0.5, 0.04, 0.5), trim)
	_box(at + Vector3(0, SEAT + 0.2, 0.17 * face), Vector3(0.46, 0.34, 0.06), wall)


## An arm from the ceiling: a rod and a white clamp head. [arm, rod]
func _make_arm(trim: Material, wall: Material, lit: Material) -> Array:
	var arm := Node3D.new()
	_set.add_child(arm)
	var rod_mi := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.035
	rod.height = 1.0
	rod_mi.mesh = rod
	rod_mi.material_override = trim
	arm.add_child(rod_mi)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.24, 0.07, 0.14)
	head.mesh = hb
	head.material_override = wall
	head.name = "Clamp"
	arm.add_child(head)
	var eye := MeshInstance3D.new()
	var eb := BoxMesh.new()
	eb.size = Vector3(0.16, 0.012, 0.01)
	eye.mesh = eb
	eye.material_override = lit
	eye.position = Vector3(0, 0, -0.075)
	head.add_child(eye)
	return [arm, rod_mi]


## Where on `model` the piece `p` goes, in the room's space (offsets in their
## own facing: they face -Z).
func _target(model: Node3D = _eco, p: String = piece) -> Vector3:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D if model != null else null
	if skel == null:
		return SET + Vector3(0, 1.5, 0)
	var bone: String = {"cuff": ColonyGear.WRIST, "gloves": "J_Bip_L_LowerArm", "spine": "J_Bip_C_Chest"}.get(p, ColonyGear.HEAD)
	var i := skel.find_bone(bone)
	var at := skel.global_transform * skel.get_bone_global_pose(i).origin
	var turn := model.global_basis.orthonormalized()
	match p:
		"cuff":
			return at + turn * Vector3(0.04, 0, 0)
		"gloves":
			return at
		"spine":
			return at + turn * Vector3(0, 0, 0.12)
		"bridge":
			return at + turn * Vector3(0, 0.02, -0.06)  # the nose
		"band":
			return at + turn * Vector3(0, -0.05, -0.03)  # the throat
		"crown":
			return at + Vector3(0, 0.12, 0)  # brow and crown
	return at + Vector3(0, 0.06, 0)


## `arm` `down` of the way from the ceiling to just above `p` on `model`.
func _place_arm(arm: Node3D, rod_mi: MeshInstance3D, model: Node3D, p: String, down: float) -> void:
	if arm == null or model == null:
		return
	var lift: float = {"cuff": 0.24, "spine": 0.5, "gloves": 0.35}.get(p, 0.16)
	var tip := _target(model, p) + Vector3(0, lift, 0)
	arm.get_node("Clamp").scale = Vector3.ONE * (0.5 if p in ["cuff", "gloves", "spine"] else 1.0)
	arm.global_rotation.y = model.global_rotation.y
	# it hangs from the ceiling off to one side, not straight over them, so
	# from across the room it doesn't cross their face: from behind for the
	# head, from their left for the wrist and arm (they face -Z)
	var off := Vector3(0, 0, 0.75)
	if p in ["cuff", "gloves"]:
		off = Vector3(-1.4, 0, 0.5)
	elif p == "spine":
		off = Vector3(0, 0, 0.9)
	var top := tip + model.global_basis.orthonormalized() * off
	top.y = SET.y + 3.15
	var head := top.lerp(tip, maxf(down, 0.03))
	arm.global_position = head
	var span := top - head
	var len := maxf(span.length(), 0.05)
	(rod_mi.mesh as CylinderMesh).height = len
	# the rod from the clamp back up to its mount
	var up := span.normalized() if span.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	rod_mi.global_transform = Transform3D(Basis(side, up, side.cross(up)), head + span * 0.5)


func _shot(which: String) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_set.add_child(_cam)
	_pov = which == "pov"
	_cam.cull_mask = 0xFFFFF & ~ECO_LAYER if _pov else 0xFFFFF
	var at := _target()
	match which:
		"pov":
			_aim_pov()
		"wide":
			_cam.fov = 48.0
			if _with_model != null:  # the two of them face to face, from the side
				_cam.look_at_from_position(SET + Vector3(2.7, 1.55, -ACROSS * 0.5 + 0.3), SET + Vector3(0, 0.95, -ACROSS * 0.5))
			else:
				_cam.look_at_from_position(SET + Vector3(1.2, 1.6, -2.6), SET + Vector3(0, 1.25, 0))
		"close":
			_cam.fov = 26.0
			match piece:
				"headphones":
					# her left ear, from the side and a little in front
					_cam.look_at_from_position(at + Vector3(-0.36, -0.06, -0.36), at + Vector3(-0.08, -0.04, 0.0))
				"cuff":
					_cam.look_at_from_position(at + Vector3(-0.5, 0.3, -0.7), at)
				"crown":
					_cam.look_at_from_position(at + Vector3(0.22, -0.04, -0.62), at + Vector3(0, -0.07, 0))
				"band":
					# from in front and a little to her left: the speaker and its light
					_cam.look_at_from_position(at + Vector3(-0.2, 0.06, -0.4), at + Vector3(-0.01, 0.0, 0))
				"bridge":
					_cam.look_at_from_position(at + Vector3(0.2, -0.02, -0.34), at + Vector3(0, -0.01, 0))
				"gloves":
					_cam.look_at_from_position(at + Vector3(-0.75, 0.25, -0.85), at + Vector3(0, -0.05, 0))
				"spine":
					_cam.look_at_from_position(at + Vector3(0.45, 0.42, 0.85), at + Vector3(0, 0.14, -0.05))
				_:
					# from the side, to see the cups cross the gap onto her eyes
					_cam.look_at_from_position(at + Vector3(0.42, 0.0, -0.4), at + Vector3(0, -0.04, -0.07))
	_cam.make_current()


## Through Eco's eyes, at them across the room.
func _aim_pov() -> void:
	if _eco == null or _with_model == null:
		return
	var skel := _eco.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := SET + Vector3(0, 1.3, 0)
	if skel != null:
		head = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(ColonyGear.HEAD)).origin
	var eyes := head + Vector3(0, 0.07, -0.06)
	_cam.look_at_from_position(eyes, _with_model.head_position() + Vector3(0, -0.12, 0))


func _lines() -> Array:
	return LINES[piece] if LINES.has(piece) else MORE_LINES[piece]


func _teardown() -> void:
	if _set != null and is_instance_valid(_set):
		_set.queue_free()
	_set = null
	_eco = null
	_with_model = null
	_with_rest = null
	_with_anim = null
	_with_gear = null
	_with_arm = null
	_with_rod = null
	_pov = false
	_gear = null
	_arm = null
	_cam = null
	var cam: Camera3D = rm.player.get("camera")
	if cam != null:
		cam.make_current()


func _mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _box(at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	_set.add_child(mi)
