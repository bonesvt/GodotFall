extends Node
## Cutter's scenes (cutter.gd, redline.gd), on Eco in third person:
##   the catch  he has the back of her head; through her eyes, his needle of
##              Redline comes in slow at the camera, then red (a flash at contact, nothing
##              more); her heart, her eyes swirling red; from the second time
##              the change it brings, coming on (redline_body.gd); and Cutter,
##              off and laughing
##   the crash  when the high runs out: the colour goes out of everything, she
##              sinks to the floor, shaking, and swears never again
## And while she's high, her view pulses red with her heart. The run manager plays the scenes and keeps
## its controls off while busy().
## The needle is only ever seen through her own eyes: no shot of her eye from
## outside.

const Redline := preload("res://scripts/hub/redline.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const SFX := preload("res://scripts/sfx.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")
const RedlineBody := preload("res://scripts/hub/redline_body.gd")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")

const RED := Color(0.85, 0.05, 0.05)
## The catch's beats.
const GRAB := 0.0
const EYE := 1.4        # through her eyes: the needle coming
const IN := 3.6         # the needle's in: red
const RUSH := 4.4
const CHANGE := 5.4     # the change coming on (a wider shot of her)
const GOES := 8.2       # he's off
const END := 9.4
## The crash's.
const C_DRAIN := 0.0
const C_DOWN := 1.2
const C_SHAKE := 3.0
const C_SWEAR := 5.6
const C_END := 8.6

const LINES := {
	"grab": "A hand clamps the back of her head. Cutter, grinning in his hood: \"Eyes open, Eco. This won't take a second.\"",
	"eye": "The needle comes in slow. Red, all the way down the glass. She can't blink. She can't look away from it.",
	"in": "Red.",
	"rush": "Her heart's going like a drum. Everything's red and loud and fast and she loves it and she hates that she loves it.",
	"goes": "Cutter, walking off backwards, laughing: \"That's Redline. Nobody does it like me. Ask Ophelia.\"",
	"drain": "The red drains out of everything at once. It takes the colour with it.",
	"down": "Eco's legs go. She's on the floor. Her hands won't stop shaking. Her teeth are chattering and she isn't cold.",
	"swear": "Eco: \"Never again. Never again.\" She means it. She meant it last time, too.",
}

var rm: Node
var t := -1.0
## "catch" or "crash".
var kind := ""
## The change this catch brought ("" for none).
var change := ""
var _cutter: Node3D
var _syringe: Node3D
var _cam: Camera3D
var _layer: CanvasLayer
var _veil: ColorRect
var _grey: ColorRect
var _said := {}
var _pulse := 0.0
var _beat := 0.0


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "CutterScene"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_grey = ColorRect.new()
	_grey.color = Color(0.5, 0.5, 0.52, 0.0)
	_grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var desat := Shader.new()
	desat.code = "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear;\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec3 c = texture(screen_tex, SCREEN_UV).rgb;\n\tfloat l = dot(c, vec3(0.3, 0.59, 0.11));\n\tCOLOR = vec4(mix(c, vec3(l) * 0.8, amount), 1.0);\n}\n"
	var dm := ShaderMaterial.new()
	dm.shader = desat
	_grey.material = dm
	_grey.visible = false
	_layer.add_child(_grey)
	_veil = ColorRect.new()
	_veil.color = Color(RED, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


## He has her (cutter.gd catch): the needle, the high, the change if it's due.
func play_catch(cutter: Node3D) -> void:
	_cutter = cutter
	kind = "catch"
	t = 0.0
	_said.clear()
	_hold(true)
	var p: Node3D = rm.player
	# him in front of her, his hand at her head
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	if is_instance_valid(cutter):
		cutter.global_position = p.global_position + fwd * 0.75
		cutter.look_at(p.global_position, Vector3.UP)
		cutter.rotation.x = 0.0
		cutter.rotation.z = 0.0
	_shot("two")
	_say("grab", 2.5)
	SFX.play(self, "hit_body", -6.0, 0.8)


## The high's run out: the crash.
func play_crash() -> void:
	kind = "crash"
	t = 0.0
	_said.clear()
	_hold(true)
	_grey.visible = true
	_shot("low")
	_say("drain", 2.5)
	SFX.play(self, "titan_powerdown", -8.0, 0.8)


func _process(delta: float) -> void:
	if t < 0.0:
		_high_overlay(delta)
		return
	t += delta
	if _cam != null and not _cam.current:  # her view camera takes itself back while it turns third person
		_cam.make_current()
	if kind == "catch":
		_catch_tick(delta)
	else:
		_crash_tick(delta)


func _catch_tick(_delta: float) -> void:
	if t >= EYE and not _said.has("eye"):
		_said["eye"] = true
		_shot("eye")
		_say("eye", 2.4)
		_syringe = _make_syringe()
		SFX.play(self, "heartbeat", -6.0, 0.8)
	if _syringe != null:
		# in toward her eye, slow, then stopping at it
		var k := smoothstep(EYE, IN, t)
		var eye := _eye_pos()
		var from: Vector3 = _syringe.get_meta("from")
		_syringe.global_position = from.lerp(eye + (from - eye).normalized() * 0.05, k)
		_syringe.look_at(eye, Vector3.UP)
	if t >= IN and not _said.has("in"):
		_said["in"] = true
		change = Redline.caught()
		_say("in", 1.0)
		SFX.play(self, "heartbeat", 0.0, 1.2)
		if _syringe != null:
			_syringe.queue_free()
			_syringe = null
	if t >= RUSH and not _said.has("rush"):
		_say("rush", 3.0)
	if t >= CHANGE and not _said.has("change"):
		_said["change"] = true
		if change != "":
			Wardrobe.dress_eco(rm.player, true)  # her body, as it is now
			_redress_copies()
			rm.hud.toast(Redline.FEEL[change], 4.0)
			_shot("change")
		SFX.play(self, "heartbeat", -2.0, 1.3)
	if t >= GOES and not _said.has("goes"):
		_say("goes", 3.0)
		if is_instance_valid(_cutter):
			_cutter.leave()
	# red: a flash at the needle, then pounding
	var a := 0.0
	if t >= IN:
		a = 0.85 * (1.0 - smoothstep(IN, IN + 0.6, t))
		a = maxf(a, 0.18 + 0.12 * sin(t * 9.0))
		a *= 1.0 - smoothstep(GOES, END, t)
	_veil.color = Color(RED, a)
	if _cam != null and t >= EYE and t < IN:
		_cam.fov = lerpf(60.0, 48.0, smoothstep(EYE, IN, t))  # her view narrowing on it
	if t >= END:
		_finish()


func _crash_tick(_delta: float) -> void:
	var k := smoothstep(C_DRAIN, C_DOWN, t) * (1.0 - smoothstep(C_END - 0.8, C_END, t))
	(_grey.material as ShaderMaterial).set_shader_parameter("amount", k)
	_veil.color = Color(0.02, 0.02, 0.03, 0.25 * k)
	if t >= C_DOWN and not _said.has("down"):
		_say("down", 3.0)
		for body in _bodies():
			body.set("rest_seat_height", 0.02)
			body.set("rest_pose", "sit")  # down on the floor
	if t >= C_SHAKE and _cam != null:
		_cam.h_offset = 0.012 * sin(t * 47.0)
		_cam.v_offset = 0.008 * sin(t * 61.0)
	if t >= C_SWEAR and not _said.has("swear"):
		_say("swear", 3.0)
	if t >= C_END:
		_finish()


func _finish() -> void:
	t = -1.0
	_veil.color.a = 0.0
	_grey.visible = false
	if kind == "crash":
		Redline.crashed()
		for body in _bodies():
			body.set("rest_pose", "")
	if _syringe != null:
		_syringe.queue_free()
		_syringe = null
	if kind == "catch" and is_instance_valid(_cutter):
		_cutter.leave()
	_cutter = null
	_hold(false)


## Stops it where it is (the hub was left under it, say).
func reset() -> void:
	if t < 0.0:
		return
	_finish()


## While she's high: her view pulses red with her heart.
func _high_overlay(delta: float) -> void:
	var a := 0.0
	if Redline.high():
		_beat -= delta
		if _beat <= 0.0:
			_beat = 0.7
			_pulse = 1.0
		_pulse = maxf(_pulse - delta * 2.5, 0.0)
		a = 0.06 + 0.12 * _pulse
	if rm.get("bench") != null:
		a = 0.0
	_veil.color = Color(RED, a)


func _say(key: String, seconds: float) -> void:
	_said[key] = true
	rm.hud.toast(LINES[key], seconds)


## Her held still, third person, HUD off, while it plays (on), and back (off).
func _hold(on: bool) -> void:
	var p: Node = rm.player
	p.set("entranced", on)
	p.set("trance_dir", Vector3.ZERO)
	var view: Node = p.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(on or ViewCamera.prefer_third_person)
	if rm.get("pilot_hud") != null:
		rm.pilot_hud.visible = not on
	rm.hud.status_label.visible = not on
	if not on:
		if _cam != null:
			_cam.queue_free()
			_cam = null
		var cam: Camera3D = p.get("camera")
		if cam != null:
			cam.make_current()


func _bodies() -> Array:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	if eco == null:
		return []
	return ["Body", "Shadow"].map(func(n): return eco.get_node_or_null(n)).filter(func(b): return b != null)


## Every copy of her (her gun's first-person arms too) in her body as it is now.
func _redress_copies() -> void:
	var models: Array = rm.player.find_children("*", "Node3D", true, false).filter(func(m): return m.get_script() == EcoModel)
	for m in models:
		if is_instance_valid(m):
			RedlineBody.apply(m)


## Her right eye, in the world (her head bone, forward and to her right).
func _eye_pos() -> Vector3:
	var p: Node3D = rm.player
	var body = _bodies()[0] if not _bodies().is_empty() else null
	var skel: Skeleton3D = body.get("skeleton") if body != null else null
	if skel != null:
		var i := skel.find_bone("J_Bip_C_Head")
		if i >= 0:
			var head := skel.global_transform * skel.get_bone_global_pose(i).origin
			return head + p.global_basis * Vector3(0.032, 0.066, -0.066)
	return p.global_position + Vector3(0, 1.53, 0) + p.global_basis * Vector3(0.032, 0, -0.07)


## His syringe, out in front of her face, to come in at her eye.
func _make_syringe() -> Node3D:
	var p: Node3D = rm.player
	var s := Node3D.new()
	add_child(s)
	var eye := _eye_pos()
	var from := eye + p.global_basis * Vector3(0.05, 0.03, -0.4)  # out in front of her, coming at her view
	s.set_meta("from", from)
	s.global_position = from
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.9, 0.95, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.1, 0.08)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.1, 0.08)
	red.emission_energy_multiplier = 2.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.85)
	steel.metallic = 0.9
	steel.roughness = 0.2
	# along -Z (look_at points -Z at her eye): needle first, then the barrel, the plunger
	for part in [[0.0075, 0.07, 0.0, glass], [0.0058, 0.062, 0.0, red], [0.0007, 0.05, -0.06, steel], [0.002, 0.04, 0.055, steel], [0.01, 0.004, 0.075, steel]]:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = part[0]
		c.bottom_radius = c.top_radius
		c.height = part[1]
		mi.mesh = c
		mi.material_override = part[3]
		mi.rotation_degrees = Vector3(90, 0, 0)
		mi.position = Vector3(0, 0, part[2])
		s.add_child(mi)
	return s


## "two": over her shoulder onto him; "eye": through her right eye, first
## person; "change": her whole self, to see what it's done; "low": low and in
## front of her, for the crash.
func _shot(which: String) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
	var p: Node3D = rm.player
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var eyes := p.global_position + Vector3(0, 1.5, 0)
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	_cam.near = 0.05
	match which:
		"two":
			_cam.fov = 40.0
			_cam.look_at_from_position(eyes - fwd * 0.9 + right * 0.55 + Vector3(0, 0.15, 0), eyes + fwd * 0.6)
		"eye":
			# through her right eye, looking out: the needle comes at the camera
			_cam.fov = 60.0
			_cam.near = 0.005
			var eye := _eye_pos()
			_cam.look_at_from_position(eye + fwd * 0.02, eye + fwd)  # just past her face, so it's not in shot
		"change":
			_cam.fov = 42.0
			_cam.look_at_from_position(eyes + fwd * 2.2 + right * 0.7 + Vector3(0, 0.1, 0), eyes - Vector3(0, 0.45, 0))
		"low":
			_cam.fov = 45.0
			_cam.look_at_from_position(p.global_position + fwd * 1.6 + right * 0.4 + Vector3(0, 0.55, 0), p.global_position + Vector3(0, 0.5, 0))
	_cam.make_current()
