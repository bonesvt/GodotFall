extends Node
## The cheat box's Super Hush (cheat_screen.gd), played out: under the crate's
## false bottom Eco finds an injector of Hush, violet and warm, SUPER scrawled
## on the tape. She puts it to her neck (eco_model.gd inject), it hisses, the
## view floods violet, the spirals in her eyes spin up in a close-up, Marrow's
## voice finds her, and she comes to with his Hold full (vices.gd). Mature
## only, like the box's button. The run manager plays it when the box closes
## and keeps its own controls off while busy().

const Vices := preload("res://scripts/hub/vices.gd")
const SFX := preload("res://scripts/sfx.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")

const VIOLET := Color(0.72, 0.32, 1.0)
const VEIL := Color(0.16, 0.04, 0.24)

## The beats: [seconds from the start, what happens].
const LIFT := 0.3      # she lifts it to her neck
const HISS := 1.9      # it goes in
const EYES := 2.4      # the close-up on her eyes
const VOICE := 5.2     # Marrow
const FLOOD := 7.4     # the violet takes the view
const BACK := 8.6      # she comes to
const END := 9.6

const LINES := {
	"find": "Under the crate's false bottom: an injector, Hush-violet and warm to the touch. Someone's scrawled SUPER on the tape.",
	"hiss": "Eco: \"Just to see.\"",
	"rush": "Eco: \"Oh. Oh, that's... that's a lot. That's all of it.\"",
	"voice": "Marrow, from nowhere and everywhere: \"There you are. All of you, all at once. No more pretending you'll walk away, Eco.\"",
	"after": "Eco comes to on the loft floor, the empty injector still in her fist. Marrow's Hold is full.",
}

var rm: Node
var t := -1.0
var _cam: Camera3D
var _veil_layer: CanvasLayer
var _veil: ColorRect
var _prop: Node3D
var _said := {}


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "SuperHushScene"


func _ready() -> void:
	_veil_layer = CanvasLayer.new()
	_veil_layer.layer = 4
	add_child(_veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(VEIL, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


## Plays it from the top.
func play() -> void:
	t = 0.0
	_said.clear()
	var player: Node3D = rm.player
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	_set_view(true)
	_prop = _injector()
	_shot("wide")
	_say("find", 4.0)


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	var body := _body()
	if body != null:
		var lift := smoothstep(LIFT, LIFT + 1.1, t) * (1.0 - smoothstep(BACK - 0.6, BACK + 0.4, t))
		body.set("inject", lift)
	if t >= HISS and not _said.has("hiss"):
		_say("hiss", 2.0)
		SFX.play(self, "titan_hiss_short", -6.0, 1.6)
		SFX.play(self, "heartbeat", -4.0)
		Vices.entranced = true  # the spirals spin up
	if t >= EYES and not _said.has("eyes"):
		_said["eyes"] = true
		_shot("eyes")
		_say("rush", 2.6)
	if t >= VOICE and not _said.has("voice"):
		_say("voice", 4.0)
		SFX.play(self, "heartbeat", -2.0, 0.85)
	# the violet: a flash at the hiss, breathing while it takes hold, a flood, then gone
	var a := 0.0
	if t >= HISS:
		a = 0.45 * (1.0 - smoothstep(HISS, HISS + 0.5, t))
		a = maxf(a, 0.12 + 0.1 * sin(t * 6.0))
		a = maxf(a, smoothstep(FLOOD, BACK, t))
		a *= 1.0 - smoothstep(BACK, END, t)
	_veil.color.a = a
	if _cam != null and t >= EYES:
		_cam.fov = lerpf(22.0, 12.0, smoothstep(EYES, FLOOD, t))  # pushing in on her eyes
		_cam.h_offset = 0.004 * sin(t * 37.0) * smoothstep(VOICE, FLOOD, t)
	if t >= BACK and not _said.has("back"):
		_said["back"] = true
		_drop_camera()
		Vices.entranced = false
		if _prop != null:
			_prop.queue_free()
			_prop = null
	if t >= END:
		_finish()


func _finish() -> void:
	t = -1.0
	_veil.color.a = 0.0
	var body := _body()
	if body != null:
		body.set("inject", 0.0)
	rm.player.set("entranced", false)
	_set_view(false)
	var gifts := []
	if Vices.hush_finish_new:
		gifts.append("the Hush finish is at the gunsmith's bench")
	if Vices.hush_suit_new:
		gifts.append("his courier suit is in her wardrobe")
	Vices.hush_finish_new = false
	Vices.hush_suit_new = false
	var more := ("\nMarrow's gifts: " + " and ".join(gifts) + ".") if not gifts.is_empty() else ""
	rm.hud.toast(LINES["after"] + more, 6.0)


## Stops it where it is (the hub was left under it, say).
func reset() -> void:
	if t < 0.0:
		return
	_drop_camera()
	Vices.entranced = false
	if _prop != null:
		_prop.queue_free()
		_prop = null
	t = -1.0
	_veil.color.a = 0.0
	var body := _body()
	if body != null:
		body.set("inject", 0.0)
	rm.player.set("entranced", false)
	_set_view(false)


func _say(key: String, seconds: float) -> void:
	_said[key] = true
	rm.hud.toast(LINES[key], seconds)


## Her full-body model (eco_model.gd).
func _body() -> Node:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	return eco.get_node_or_null("Body") if eco != null else null


## The injector in her right hand: a glass barrel of glowing violet resin
## between a dark cap and a plunger, the tape round it.
func _injector() -> Node3D:
	var body := _body()
	var skeleton: Skeleton3D = body.get("skeleton") if body != null else null
	if skeleton == null:
		return null
	var hold := BoneAttachment3D.new()
	hold.bone_name = "J_Bip_R_Hand"
	skeleton.add_child(hold)
	var pen := Node3D.new()
	pen.position = Vector3(-0.07, 0.0, 0.02)
	pen.rotation_degrees = Vector3(0, 0, 90)
	hold.add_child(pen)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = VIOLET
	glow.emission_enabled = true
	glow.emission = VIOLET
	glow.emission_energy_multiplier = 2.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.07, 0.09)
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.9, 0.86, 0.7)
	for piece in [[0.0, 0.07, 0.011, glow], [0.045, 0.02, 0.013, dark], [-0.045, 0.02, 0.012, dark],
			[0.0, 0.025, 0.0125, tape], [0.065, 0.02, 0.002, dark]]:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.height = piece[1]
		c.top_radius = piece[2]
		c.bottom_radius = piece[2]
		c.radial_segments = 12
		m.mesh = c
		m.material_override = piece[3]
		m.position = Vector3(0, piece[0], 0)
		pen.add_child(m)
	return hold


## "wide": her from the chest up, the hand coming up; "eyes": tight on her eyes.
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
	if kind == "wide":
		_cam.fov = 34.0
		_cam.look_at_from_position(eyes + fwd * 1.5 + right * 0.45 - Vector3(0, 0.12, 0), eyes - Vector3(0, 0.22, 0))
	else:
		_cam.fov = 22.0
		_cam.look_at_from_position(eyes + fwd * 0.9 + Vector3(0, 0.02, 0), eyes)
	_cam.make_current()


func _drop_camera(back := true) -> void:
	if _cam != null:
		_cam.queue_free()
		_cam = null
	if back:
		var cam: Camera3D = rm.player.get("camera")
		if cam != null:
			cam.make_current()


## Third person while it plays, so her body is there to film; their own view after.
func _set_view(on: bool) -> void:
	var view: Node = rm.player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(on or ViewCamera.prefer_third_person)
