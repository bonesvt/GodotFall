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
## dispensary. Built well below the hub on its own (SET), with its own copy of
## her in what she's wearing. The run manager plays it and keeps its own
## controls off while busy().

const Hymn := preload("res://scripts/hub/hymn.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

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
	"crown": ["The room goes quiet. Something white and thin comes down out of the ceiling, slow, to her head.",
		"It settles on her brow. Every piece on her lights up at once: her ears, her eyes, her nose, her hands, her back.",
		"Calm voice, from everywhere: \"Welcome home, citizen.\""],
	"spine": ["Something long and white comes down behind her, to her back.",
		"She stands in the frame while it clicks onto her spine segment by segment, shoulders to waist, each node lighting as it locks.",
		"Her back straightens on its own. Calm voice: \"Walk with everyone. Never alone.\""],
}
const AFTER := "Eco wakes on the bench outside the dispensary. Her %s won't come off. She's tried."

var rm: Node
var t := -1.0
var piece := ""
## The visor's orders flash up at the end of its fitting (visor_screen.gd reads it).
var visor_flash := false
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


## Plays the fitting of `p` (a Hymn.GEAR piece), from white.
func play(p: String) -> void:
	piece = p
	t = 0.0
	_said.clear()
	visor_flash = false
	_veil.color.a = 1.0
	rm.player.set("entranced", true)
	rm.player.set("trance_dir", Vector3.ZERO)
	_show_hud(false)
	_build()
	_shot("wide")
	rm.hud.toast(INTRO, 3.0)
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
	if _eco != null:
		ColonyGear.fit_model(_eco, piece, k)
		if _gear != null and piece in ["headphones", "cuff"]:  # the others' fit() brings them down
			_gear.position = Vector3(0, 0.45 * (1.0 - smoothstep(LOWER, ON, t)), 0)
	_place_arm(down)
	if t >= ON and not _said.has("on"):
		_said["on"] = true
		_shot("close")
		rm.hud.toast(_lines()[0], 2.5)
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
	if _cam != null and t >= ON:
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
	rm.fitted(piece)
	if Hymn.GEAR_NAMES.has(piece):
		rm.hud.toast(AFTER % Hymn.GEAR_NAMES[piece], 6.0)


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
	# the fitting frame behind her: two posts and a top bar
	for s in [-1.0, 1.0]:
		_box(Vector3(0.55 * s, 1.1, 0.35), Vector3(0.1, 2.2, 0.1), trim)
	_box(Vector3(0, 2.2, 0.35), Vector3(1.2, 0.1, 0.1), trim)
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
	# the arm from the ceiling: a rod and a white clamp head
	_arm = Node3D.new()
	_set.add_child(_arm)
	_arm_rod = MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.035
	rod.height = 1.0
	_arm_rod.mesh = rod
	_arm_rod.material_override = trim
	_arm.add_child(_arm_rod)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.24, 0.07, 0.14)
	head.mesh = hb
	head.material_override = wall
	head.name = "Clamp"
	_arm.add_child(head)
	var eye := MeshInstance3D.new()
	var eb := BoxMesh.new()
	eb.size = Vector3(0.16, 0.012, 0.01)
	eye.mesh = eb
	eye.material_override = lit
	eye.position = Vector3(0, 0, -0.075)
	head.add_child(eye)


## Where on her the piece goes, in the room's space.
func _target() -> Vector3:
	var skel := _eco.find_child("Skeleton3D", true, false) as Skeleton3D if _eco != null else null
	if skel == null:
		return SET + Vector3(0, 1.5, 0)
	var bone: String = {"cuff": ColonyGear.WRIST, "gloves": "J_Bip_L_LowerArm", "spine": "J_Bip_C_Chest"}.get(piece, ColonyGear.HEAD)
	var i := skel.find_bone(bone)
	var at := skel.global_transform * skel.get_bone_global_pose(i).origin
	match piece:
		"cuff":
			return at + Vector3(0.04, 0, 0)
		"gloves":
			return at
		"spine":
			return at + Vector3(0, 0, 0.12)
		"bridge":
			return at + Vector3(0, 0.02, -0.06)  # her nose
		"crown":
			return at + Vector3(0, 0.12, 0)  # her brow and crown
	return at + Vector3(0, 0.06, 0)


## The arm, `down` of the way from the ceiling to just above the piece.
func _place_arm(down: float) -> void:
	if _arm == null:
		return
	var lift: float = {"cuff": 0.24, "spine": 0.5, "gloves": 0.35}.get(piece, 0.16)
	var tip := _target() + Vector3(0, lift, 0)
	_arm.get_node("Clamp").scale = Vector3.ONE * (0.5 if piece in ["cuff", "gloves", "spine"] else 1.0)
	var top := SET.y + 3.15
	var y := lerpf(top - 0.1, tip.y, down)
	_arm.global_position = Vector3(tip.x, y, tip.z)
	var len := maxf(top - y, 0.05)
	(_arm_rod.mesh as CylinderMesh).height = len
	_arm_rod.position = Vector3(0, len * 0.5, 0)


func _shot(which: String) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_set.add_child(_cam)
	var at := _target()
	match which:
		"wide":
			_cam.fov = 48.0
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


func _lines() -> Array:
	return LINES[piece] if LINES.has(piece) else MORE_LINES[piece]


func _teardown() -> void:
	if _set != null and is_instance_valid(_set):
		_set.queue_free()
	_set = null
	_eco = null
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
