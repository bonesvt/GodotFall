extends Node
## The cheat box's control items (cheat_screen.gd), each played out as its own
## scene on Eco in third person, like Super Hush (super_hush_scene.gd), then
## the system it's for jumps to full. Mature only, like the systems.
##   hymn     Super Hymn: a white colony ampoule she snaps under her nose. The
##            view whites out in rings, her eyes go white, the calm voice
##            welcomes her: Hymn to full.
##   set      The Full Set: a white case with the colony seal. Every piece of
##            the Shepherd's gear clicks onto her in turn, a word for each,
##            and the Crown last: OBEY.
##   glass    Glass Rush: three of Marrow's vials cracked at once. Violet glass
##            creeps up her arm and over her skin while he talks in her ear:
##            fully crystallised, three spare vials and his earpiece.
##   keepsake Keepsake: a Night Owls pack with a heart on it from Ophelia. Rose
##            smoke, her eyes going rose, Ophelia's voice in it: Keepsake full
##            and Ophelia's obsession with it.
##   family   Family Plan: a white envelope with the colony seal. Mom and
##            Ophelia come to her side wearing the whole set, piece by piece,
##            and say it together: the Hub Grip full for both of them.
## The run manager plays it when the box closes and keeps its own controls off
## while busy().

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")
const SFX := preload("res://scripts/sfx.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")

## The beats, as in the Super Hush scene.
const LIFT := 0.3      # she lifts it
const USE := 1.9       # it goes in, on, or open
const CLOSE := 2.4     # the close shot
const VOICE := 5.2     # the voice
const FLOOD := 7.4     # the colour takes the view
const BACK := 8.6      # she comes to
const END := 9.6

## Each item: its colour, the shot after USE ("eyes", "arm" or "three"),
## and its lines (find, use, rush, voice, after).
const ITEMS := {
	"hymn": {
		"name": "Super Hymn", "color": Color(0.92, 0.96, 1.0), "close": "eyes",
		"find": "In the crate, packed in foam like a medal: a white ampoule with the colony seal. SUPER, in the colony's neat print.",
		"use": "She snaps it under her nose. Lavender. Linen. Clean.",
		"rush": "Eco: \"Oh. It's so quiet. Why is everything so quiet?\"",
		"voice": "Calm voice, from every direction: \"Welcome home, citizen. You don't have to try any more.\"",
		"after": "Eco comes to humming the town's tune. Her Hymn is full.",
	},
	"set": {
		"name": "The Full Set", "color": Color(0.85, 0.94, 1.0), "close": "wide",
		"find": "A white case with the colony's ringed seal. It opens on its own.",
		"use": "Something clicks onto her. Then something else.",
		"rush": "Eco: \"Wait. Wait, I didn't...\"",
		"voice": "Calm voice: \"There. All of you, where you belong.\"",
		"after": "Every piece of the Shepherd's gear is on her. Biggie's going to need a bigger table.",
		"words": ["LISTEN", "DOSE", "SEE", "BREATHE", "FEEL", "STAND", "TRACK", "OBEY"],
	},
	"glass": {
		"name": "Glass Rush", "color": Color(0.62, 0.3, 0.95), "close": "arm",
		"find": "Three of Marrow's vials, taped together. Glass, by the colour. Someone's written ALL OF IT on the tape.",
		"use": "She cracks all three at once. The world slows down to listen.",
		"rush": "Eco: \"My arm. Why is my arm ringing?\"",
		"voice": "Marrow, in her ear, though there's nothing in it yet: \"There it goes. Hold still while you set.\"",
		"after": "Eco comes to glittering. The glass is all over her. There's an earpiece in her ear and three spare vials in her pocket.",
	},
	"keepsake": {
		"name": "Keepsake", "color": Color(1.0, 0.45, 0.7), "close": "eyes",
		"find": "A Night Owls pack with a little heart drawn on it in pen. Ophelia's handwriting: \"for you. only you.\"",
		"use": "She lights one. The smoke comes out rose.",
		"rush": "Eco: \"It smells like her. Why does it smell like her?\"",
		"voice": "Ophelia, close, from inside the smoke: \"There you are. Now you'll always come back to me.\"",
		"after": "Eco comes to with the taste of roses. Her Keepsake is full, and Ophelia's never been so sure of her.",
	},
	"family": {
		"name": "Family Plan", "color": Color(0.9, 0.95, 1.0), "close": "three",
		"find": "A white envelope with the colony seal: FAMILY PLAN. ALL MEMBERS.",
		"use": "She opens it. Footsteps behind her. Mom's, and Ophelia's.",
		"rush": "Eco: \"Mom? Ophelia? What are you wearing?\"",
		"voice": "Mom and Ophelia, together, smiling the same smile: \"Welcome home, citizen.\"",
		"after": "Mom and Ophelia are wearing the Shepherd's whole set. Biggie or Doc Imani can still get it off them, one piece at a time.",
	},
}

var rm: Node
var t := -1.0
var item := ""
var _cam: Camera3D
var _veil_layer: CanvasLayer
var _veil: ColorRect
var _word: Label
var _prop: Node3D
var _said := {}
var _layers: Array = []
var _gun: Node3D
var _shown := 0
## For the family plan: Mom and Ophelia's places before they came over.
var _family: Array = []


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "CheatScene"


func _ready() -> void:
	_veil_layer = CanvasLayer.new()
	_veil_layer.layer = 4
	add_child(_veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(1, 1, 1, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_layer.add_child(_veil)
	_word = Label.new()
	_word.add_theme_font_size_override("font_size", 120)
	_word.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	_word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.visible = false
	_veil_layer.add_child(_word)


func busy() -> bool:
	return t >= 0.0


## Plays item `p` (an ITEMS key) from the top.
func play(p: String) -> void:
	if not ITEMS.has(p):
		return
	item = p
	t = 0.0
	_said.clear()
	_shown = 0
	var player: Node3D = rm.player
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	_set_view(true)
	_hold_layers(true)
	_show_hud(false)
	_prop = _make_prop()
	_shot("wide")
	_say("find", 4.0)
	if item == "family":
		_bring_family()


func _spec() -> Dictionary:
	return ITEMS[item]


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	var spec := _spec()
	var color: Color = spec["color"]
	var lift := smoothstep(LIFT, LIFT + 1.1, t) * (1.0 - smoothstep(BACK - 0.6, BACK + 0.4, t))
	for body in _bodies():
		body.set("inject", lift)
	if t >= USE and not _said.has("use"):
		_say("use", 2.0)
		_use_sound()
	if t >= CLOSE and not _said.has("close"):
		_said["close"] = true
		_shot(String(spec["close"]))
		_say("rush", 2.6)
	if t >= VOICE and not _said.has("voice"):
		_say("voice", 4.0)
		SFX.play(self, "heartbeat", -2.0, 0.85)
	var k := smoothstep(USE, FLOOD, t)
	_build_up(k)
	# its colour: a flash when it goes in, breathing while it takes hold, a flood, then gone
	var a := 0.0
	if t >= USE:
		a = 0.45 * (1.0 - smoothstep(USE, USE + 0.5, t))
		a = maxf(a, 0.1 + 0.08 * sin(t * 6.0))
		a = maxf(a, smoothstep(FLOOD, BACK, t))
		a *= 1.0 - smoothstep(BACK, END, t)
	_veil.color = Color(color, a)
	if _cam != null and t >= CLOSE:
		match String(spec["close"]):
			"eyes":
				_cam.fov = lerpf(22.0, 12.0, smoothstep(CLOSE, FLOOD, t))
			"arm":
				_cam.fov = lerpf(30.0, 20.0, smoothstep(CLOSE, FLOOD, t))
			_:
				_orbit(delta)
	if t >= BACK and not _said.has("back"):
		_said["back"] = true
		_word.visible = false
		_drop_camera()
		if _prop != null:
			_prop.queue_free()
			_prop = null
	if t >= END:
		_finish()


## What the item does to her (or them) as it takes hold, k 0..1.
func _build_up(k: float) -> void:
	match item:
		"hymn":
			EcoModel.swirl_override = k
			EcoModel.swirl_override_tint = Color(0.95, 0.97, 1.0)
		"glass":
			RenderingServer.global_shader_parameter_set("eco_glass", maxf(Glass.look(), k))
			EcoModel.swirl_override = k * 0.7
			EcoModel.swirl_override_tint = Color(0.72, 0.32, 1.0)
		"keepsake":
			EcoModel.swirl_override = k
			EcoModel.swirl_override_tint = Color(1.0, 0.45, 0.7)
		"set":
			_snap_pieces(k)
		"family":
			_dress_family(k)


## The Full Set: a piece on her every so often, a word on the screen with each.
func _snap_pieces(k: float) -> void:
	var n := clampi(int(floor(k * Hymn.GEAR.size() + 0.001)), 0, Hymn.GEAR.size())
	if n == _shown:
		return
	_shown = n
	var on: Array = Hymn.GEAR.slice(0, n)
	for body in _bodies():
		ColonyGear.apply(body, on)
	var words: Array = _spec()["words"]
	_word.text = String(words[n - 1]) if n > 0 else ""
	_word.visible = n > 0
	SFX.play(self, "cache_unlock", -6.0, 0.8 + 0.06 * n)


## The family plan: Mom and Ophelia's pieces going on them as they stand by her.
func _dress_family(k: float) -> void:
	var n := clampi(int(floor(k * Hymn.GEAR.size() + 0.001)), 0, Hymn.GEAR.size())
	if n == _shown:
		return
	_shown = n
	var on: Array = Hymn.GEAR.slice(0, n)
	for f in _family:
		ColonyGear.apply(f[0], on)
		if n == Hymn.GEAR.size():
			f[0].mood(["smile"])
	SFX.play(self, "cache_unlock", -8.0, 0.9 + 0.05 * n)


func _use_sound() -> void:
	match item:
		"hymn":
			SFX.play(self, "chime_3", -4.0, 0.7)
		"set":
			SFX.play(self, "titan_servo_2", -6.0, 1.3)
		"glass":
			SFX.play(self, "glass_break", -4.0, 1.2)
		"keepsake":
			SFX.play(self, "dry_click", -4.0, 1.4)  # the lighter
		"family":
			SFX.play(self, "paper_2", -4.0)
	SFX.play(self, "heartbeat", -4.0)


func _finish() -> void:
	t = -1.0
	_veil.color.a = 0.0
	_word.visible = false
	_apply()
	EcoModel.swirl_override = -1.0
	_send_family_home()
	_let_go()
	rm.hud.toast(String(_spec()["after"]), 6.0)


## The system it's for, to full.
func _apply() -> void:
	match item:
		"hymn":
			Hymn.level = Hymn.MAX
			Hymn.save()
		"set":
			Hymn.gear = Hymn.GEAR.duplicate()
			Hymn.save()
		"glass":
			Glass.glass = Glass.MAX_GLASS
			Glass.vials = Glass.MAX_VIALS
			Glass.earpiece = true
			Glass.save()
		"keepsake":
			Obsession.keepsake = Obsession.MAX
			Obsession.meter = Obsession.MAX
			Obsession.save()
		"family":
			for who in HubGrip.WHO:
				HubGrip.gear[who] = Hymn.GEAR.duplicate()
				HubGrip.levels[who] = HubGrip.MAX
			HubGrip.save()
	if rm.has_method("dress_hub"):
		rm.dress_hub()
	if rm.player != null:
		for body in _bodies():
			ColonyGear.apply(body)


## Stops it where it is (the hub was left under it, say).
func reset() -> void:
	if t < 0.0:
		return
	_drop_camera()
	if _prop != null:
		_prop.queue_free()
		_prop = null
	t = -1.0
	_veil.color.a = 0.0
	_word.visible = false
	EcoModel.swirl_override = -1.0
	_send_family_home()
	for body in _bodies():
		ColonyGear.apply(body)
	_let_go()


func _let_go() -> void:
	for body in _bodies():
		body.set("inject", 0.0)
	_hold_layers(false)
	_show_hud(true)
	rm.player.set("entranced", false)
	_set_view(false)


func _say(key: String, seconds: float) -> void:
	_said[key] = true
	rm.hud.toast(String(_spec()[key]), seconds)


# --- the family plan ----------------------------------------------------------

## Mom and Ophelia (whoever's home) come to stand either side of her.
func _bring_family() -> void:
	_family = []
	var player: Node3D = rm.player
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var side := -1.0
	for who in HubGrip.WHO:
		var npc: Node3D = rm.hub_npcs.get(who)
		if npc == null or not is_instance_valid(npc):
			continue
		_family.append([npc, npc.global_transform, npc.get("home_yaw")])
		npc.global_position = player.global_position + right * 0.85 * side + fwd * 0.15
		npc.global_rotation.y = player.global_rotation.y
		if npc.get("home_yaw") != null:
			npc.home_yaw = player.global_rotation.y
		ColonyGear.apply(npc, [])
		side = 1.0


## Back where they were, in what they're wearing now (HubGrip).
func _send_family_home() -> void:
	for f in _family:
		var npc: Node3D = f[0]
		if not is_instance_valid(npc):
			continue
		npc.global_transform = f[1]
		if f[2] != null:
			npc.home_yaw = f[2]
		ColonyGear.apply(npc, HubGrip.gear_of(npc.who))
	_family = []


# --- her, the camera -----------------------------------------------------------

func _body() -> Node:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	if eco == null:
		return null
	var shadow := eco.get_node_or_null("Shadow")
	return shadow if shadow != null else eco.get_node_or_null("Body")


func _bodies() -> Array:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	if eco == null:
		return []
	return ["Body", "Shadow"].map(func(n): return eco.get_node_or_null(n)).filter(func(b): return b != null)


func _hold_layers(on: bool) -> void:
	if on:
		_layers = []
		var body := _body()
		var skeleton: Skeleton3D = body.get("skeleton") if body != null else null
		if skeleton != null:
			for c in skeleton.get_children():
				if c is SkeletonModifier3D and c.active:
					c.active = false
					_layers.append(c)
			_gun = skeleton.find_child("GunHold", true, false) as Node3D
			if _gun != null:
				_gun.visible = false
		return
	for c in _layers:
		if is_instance_valid(c):
			c.active = true
	_layers = []
	if _gun != null and is_instance_valid(_gun):
		_gun.visible = true
	_gun = null


func _show_hud(on: bool) -> void:
	if rm.get("pilot_hud") != null:
		rm.pilot_hud.visible = on
	rm.hud.status_label.visible = on


func _mat(c: Color, glow := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _part(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation_degrees = rot
	parent.add_child(mi)


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	_part(parent, b, at, m)


func _cyl(parent: Node3D, r: float, h: float, at: Vector3, m: Material, rot := Vector3.ZERO) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	_part(parent, c, at, m, rot)


## The item in her right hand.
func _make_prop() -> Node3D:
	var body := _body()
	var skeleton: Skeleton3D = body.get("skeleton") if body != null else null
	if skeleton == null:
		return null
	var hold := BoneAttachment3D.new()
	hold.bone_name = "J_Bip_R_Hand"
	skeleton.add_child(hold)
	var p := Node3D.new()
	p.position = Vector3(-0.07, 0.0, 0.02)
	hold.add_child(p)
	var white := _mat(Color(0.93, 0.95, 0.98))
	var dark := _mat(Color(0.1, 0.1, 0.12))
	match item:
		"hymn":  # a white ampoule, glowing at its neck
			_cyl(p, 0.012, 0.06, Vector3.ZERO, white, Vector3(0, 0, 90))
			_cyl(p, 0.006, 0.02, Vector3(0.04, 0, 0), _mat(Color(0.85, 0.95, 1.0), 3.0), Vector3(0, 0, 90))
		"set":  # the white case with the seal
			_box(p, Vector3(0.14, 0.03, 0.1), Vector3.ZERO, white)
			_cyl(p, 0.025, 0.004, Vector3(0, 0.016, 0), _mat(Color(0.8, 0.94, 1.0), 2.5))
		"glass":  # three violet vials taped together
			for i in 3:
				_cyl(p, 0.01, 0.07, Vector3(0, 0, (i - 1) * 0.022), _mat(Color(0.62, 0.3, 0.95), 2.5, 0.8), Vector3(0, 0, 90))
			_cyl(p, 0.036, 0.02, Vector3.ZERO, _mat(Color(0.9, 0.86, 0.7)), Vector3(90, 0, 0))
		"keepsake":  # a Night Owls pack with a heart on it
			_box(p, Vector3(0.09, 0.055, 0.022), Vector3.ZERO, _mat(Color(0.12, 0.1, 0.16)))
			_box(p, Vector3(0.02, 0.018, 0.002), Vector3(0.0, 0.0, 0.012), _mat(Color(1.0, 0.4, 0.65), 1.5))
		"family":  # the white envelope, its seal
			_box(p, Vector3(0.16, 0.004, 0.1), Vector3.ZERO, white)
			_cyl(p, 0.014, 0.003, Vector3(0, 0.003, 0), _mat(Color(0.8, 0.94, 1.0), 2.0))
	return hold


## "wide": her from the chest up; "eyes": tight on her eyes; "arm": on her
## right arm and hand; "three": wider, her and whoever's beside her.
func _shot(kind: String) -> void:
	_drop_camera(false)
	var player: Node3D = rm.player
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var eyes := player.global_position + Vector3(0, 1.48, 0)
	_cam = Camera3D.new()
	add_child(_cam)
	match kind:
		"eyes":
			_cam.fov = 22.0
			_cam.look_at_from_position(eyes + fwd * 0.9 + Vector3(0, 0.02, 0), eyes)
		"arm":
			# from in front and to her right, on the hand she's raised and the arm under it
			_cam.fov = 30.0
			_cam.look_at_from_position(eyes + fwd * 0.95 + right * 0.45 - Vector3(0, 0.1, 0), eyes + right * 0.12 - Vector3(0, 0.22, 0))
		"three":
			_cam.fov = 45.0
			_cam.look_at_from_position(eyes + fwd * 3.0 + Vector3(0, 0.1, 0), eyes - Vector3(0, 0.45, 0))
		_:
			_cam.fov = 34.0
			_cam.look_at_from_position(eyes + fwd * 1.5 + right * 0.45 - Vector3(0, 0.12, 0), eyes - Vector3(0, 0.22, 0))
	_cam.make_current()


## A slow turn round her (the Full Set): to see each piece go on.
func _orbit(delta: float) -> void:
	if item != "set":
		return
	var player: Node3D = rm.player
	var centre := player.global_position + Vector3(0, 1.3, 0)
	var off := _cam.global_position - centre
	off = off.rotated(Vector3.UP, delta * 0.45)
	_cam.look_at_from_position(centre + off, centre)


func _drop_camera(back := true) -> void:
	if _cam != null:
		_cam.queue_free()
		_cam = null
	if back:
		var cam: Camera3D = rm.player.get("camera")
		if cam != null:
			cam.make_current()


func _set_view(on: bool) -> void:
	var view: Node = rm.player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(on or ViewCamera.prefer_third_person)
