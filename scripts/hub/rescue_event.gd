extends Node
## A rescue, live in the hub (rescue.gd has the rules): the roll, Biggie
## running in with it, the marker and the countdown, the captor waiting with
## them at the place (rescue_sites.gd), and the two endings:
##   in time   Eco knocks the captor down ([F] at him) and gets them out
##   too late  the countdown runs out: what happened, where it happened
## And afterwards, Cutter's Wiring on whoever he had (red veins, a shake) and
## Marrow's quiet in them, while his hold is past Rescue.SHOWS_AT.
## The run manager calls tick() from the hub, knock() from [F] at the captor,
## and keeps its controls off while busy().

const Rescue := preload("res://scripts/hub/rescue.gd")
const RescueSites := preload("res://scripts/hub/rescue_sites.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const ShepherdModel := preload("res://scripts/hub/shepherd_model.gd")
const CutterModel := preload("res://scripts/hub/cutter_model.gd")
const EcoRest := preload("res://scripts/ps2/eco_rest.gd")
const Family := preload("res://scripts/hub/family.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")

enum Step { IDLE, ALERT, RUNNING, SAVED, LATE }

const SPOT := "rescue_captor"
const RED := Color(1.0, 0.25, 0.2)
## Biggie's run in.
const A_ARRIVE := 1.4
const A_END := 5.2
## In time.
const S_HIT := 0.45
const S_KNOCK := 1.3
const S_FREE := 2.8
const S_DARK := 6.0
const S_END := 7.0
## Too late.
const L_SECOND := 4.2
const L_DARK := 8.0
const L_END := 9.0

const KNOCK := {
	"marrow": "Eco hits him with her whole weight. He comes apart like smoke round her shoulder and pools on the floor, and from everywhere at once: \"Take her, then. She'll find her own way back.\"",
	"colony": "Eco slams into the Shepherd shoulder first. It goes over backwards and lies there, its calm voice still going: \"Please remain calm. Please remain calm. Please remain\"",
	"cutter": "Eco takes Cutter from behind, low and hard. He goes down in the dirt, laughing even now: \"Okay! Okay. She's all yours. For now.\"",
}
const FREED := {
	"mom": "Mom takes Eco's face in both hands. \"You came. Oh, baby. You came for me.\"",
	"ophelia": "Ophelia throws her arms round Eco's neck and doesn't let go. \"I knew it'd be you. I knew it.\"",
}
## Too late: [first shot, second shot] (%s: Mom or Ophelia; the colony's: the piece).
const LATE := {
	"marrow": ["Marrow's basement. %s's sunk deep in the armchair, violet curling off her breath, smiling at nothing. His hand rests on the back of the chair.",
		"%s comes home after dark. Calm. Quiet. She smiles at Eco like she's someone she used to know, and goes to bed without a word."],
	"colony": ["The colony van. The door slides open on %s, sat very straight on the white bench while the arm comes down with the colony's %s.",
		"It's on. %s blinks, and smiles, and doesn't stop. \"I feel so calm.\""],
	"cutter": ["Cutter's stash. %s's on a crate, shaking so hard it rattles. Red lines glow up her arms and her neck, under the skin. Wiring.",
		"Cutter, grinning: \"Tell Eco she's next. Tell her mine's better than Marrow's.\""],
}
const QUIET := "%s smiles when Eco says her name, and doesn't say much back. She doesn't say much at all any more."
## Cutter's Wiring: red veins lit under the skin of their body texture (where it's skin-coloured).
const VEINS := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float strength = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float skin = step(0.32, c.r) * step(c.b + 0.06, c.r) * step(c.b, c.g + 0.02) * step(c.g, c.r);
	float n = noise(UV * 70.0) * 0.65 + noise(UV * 160.0) * 0.35;
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * 6.5);
	ALBEDO = vec3(1.0, 0.07, 0.04) * vein * skin * pulse * strength * 1.4;
}"

var rm: Node
var step := Step.IDLE
## Who's taken, by which captor.
var who := ""
var captor := ""
## Seconds left to get there.
var left := 0.0
## Scene time (-1: none playing).
var t := -1.0
## The colony's piece the van put on them, when she was too late.
var piece := ""
var _roll := Rescue.ROLL_EVERY
var _rolled := false
var _site := {}
var _set: Node3D
var _victim: Node3D
var _victim_anim: AnimationPlayer
var _victim_rest: EcoRest
var _victim_pose := "chair"
var _captor: Node3D
var _biggie: Node3D
var _hidden: Array = []
var _cam: Camera3D
var _said := {}
var _layer: CanvasLayer
var _veil: ColorRect
var _clock: Label
var _marker: Control
var _quiet_said := {}
var _hit_from := Vector3.ZERO
var _hit_to := Vector3.ZERO
var _shaders := {}


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "RescueEvent"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_marker)
	_layer.add_child(_marker)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.position.y = 54.0
	_clock.add_theme_font_size_override("font_size", 26)
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_clock.add_theme_constant_override("outline_size", 6)
	_clock.visible = false
	_layer.add_child(_clock)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


func running() -> bool:
	return step == Step.RUNNING


## A new stay in the hub: nobody's taken, the roll starts over. (Someone taken
## when she left the hub was lost: lose() first.)
func reset() -> void:
	lose()
	_rolled = false
	_roll = Rescue.ROLL_EVERY
	_quiet_said.clear()
	_shaders.clear()


## She left the hub with someone taken: too late, without the scene.
func lose() -> void:
	if step == Step.RUNNING and who != "":
		_late_results()
	_teardown()
	step = Step.IDLE


## From the hub each frame: the roll while she's out and about, the countdown
## while someone's taken.
func tick(delta: float, roaming: bool) -> void:
	if not Rescue.allowed():
		return
	if step == Step.IDLE and roaming and not _rolled:
		_roll -= delta
		if _roll <= 0.0:
			_roll = Rescue.ROLL_EVERY
			if randf() < Rescue.CHANCE:
				start_random()
	elif step == Step.RUNNING:
		left -= delta
		if left <= 0.0:
			play_late()


## Takes one of them, by one of the captors who've started on Eco. False if
## nobody could be.
func start_random() -> bool:
	var captors := Rescue.active_captors()
	var people: Array = Rescue.WHO.filter(func(w): return rm.hub_npcs.has(w))
	if captors.is_empty() or people.is_empty():
		return false
	return start(people[randi() % people.size()], captors[randi() % captors.size()])


## `p_who` is taken by `p_captor`: Biggie runs in with it.
func start(p_who: String, p_captor: String) -> bool:
	if step != Step.IDLE or not Rescue.allowed() or not rm.hub_npcs.has(p_who) or rm.get("zone_root") == null:
		return false
	_rolled = true
	who = p_who
	captor = p_captor
	step = Step.ALERT
	t = 0.0
	_said.clear()
	_hold(true)
	# Biggie, at a run, from in front of her
	var p: Node3D = rm.player
	var fwd := _flat(-p.global_basis.z)
	_biggie = _npc("biggie", p.global_position + fwd * 6.0, rad_to_deg(atan2(fwd.x, fwd.z)))
	_biggie.set_meta("from", p.global_position + fwd * 6.0)
	_biggie.set_meta("to", p.global_position + fwd * 1.5)
	_look(p.global_position + Vector3(0, 1.6, 0) - fwd * 1.1 + fwd.cross(Vector3.UP) * 0.6, p.global_position + fwd * 3.0 + Vector3(0, 1.3, 0), 45.0)
	rm.hud.toast("Running feet. Somebody's shouting her name.", 1.6)
	SFX.play(self, "step_concrete_2", -2.0, 1.3)
	return true


## [F] at the captor while there's time: down he goes.
func knock() -> void:
	if step != Step.RUNNING:
		return
	step = Step.SAVED
	t = 0.0
	_said.clear()
	_remove_spot()
	_clock.visible = false
	_hold(true)
	var p: Node3D = rm.player
	var at: Vector3 = _site["captor"]
	var dir := _flat(at - p.global_position)
	_hit_from = at - dir * 1.3
	_hit_to = at - dir * 0.5
	rm.place_player(_hit_from)
	p.rotation.y = atan2(-dir.x, -dir.z)
	var side := dir.cross(Vector3.UP)
	_look(at - dir * 0.9 + side * 2.6 + Vector3(0, 1.3, 0), at - dir * 0.4 + Vector3(0, 0.95, 0), 48.0)


## Too late: what happened.
func play_late() -> void:
	step = Step.LATE
	t = 0.0
	_said.clear()
	_remove_spot()
	_clock.visible = false
	_hold(true)
	piece = ""
	if captor == "colony":
		piece = _next_piece()
		ColonyGear.apply(_victim, HubGrip.gear_of(who) + ([piece] if piece != "" else []))
		if piece != "":
			ColonyGear.fit_model(_victim, piece, 0.0)
	elif captor == "cutter":
		veins(_victim, true)
	_victim.mood(["closed", "smile"] if captor != "cutter" else ["sad"])
	rm.player.visible = false  # she isn't there: this is what she missed
	_look(_site["cam"], _victim.head_position() + Vector3(0, -0.25, 0), 40.0)
	rm.hud.toast(_late_line(0), 4.0)
	SFX.play(self, "heartbeat", -8.0, 0.8)


func _process(delta: float) -> void:
	_aftermath(delta)
	if step == Step.RUNNING:
		_clock.text = "%s: %s   %d:%02d" % [Rescue.NAMES[who].to_upper(), Rescue.PLACES[captor], int(left) / 60, int(left) % 60]
		_clock.add_theme_color_override("font_color", RED if left < 20.0 and fmod(left, 1.0) > 0.5 else Color(1.0, 0.85, 0.8))
		_marker.queue_redraw()
	if _victim != null and is_instance_valid(_victim):
		if _victim_anim != null:
			_victim_anim.advance(delta)
		if _victim_rest != null:
			_victim_rest.step(delta, _victim_pose)
	if t < 0.0:
		return
	t += delta
	if _cam != null and not _cam.current:
		_cam.make_current()
	match step:
		Step.ALERT:
			_alert_tick()
		Step.SAVED:
			_saved_tick()
		Step.LATE:
			_late_tick()


func _alert_tick() -> void:
	if is_instance_valid(_biggie):
		var k := smoothstep(0.0, A_ARRIVE, t)
		_biggie.global_position = (_biggie.get_meta("from") as Vector3).lerp(_biggie.get_meta("to"), k)
		_biggie.position.y += absf(sin(t * 11.0)) * 0.05 * (1.0 - k)
	if t >= A_ARRIVE and not _said.has("alert"):
		_said["alert"] = true
		rm.hud.toast(Rescue.ALERT[captor] % ("your mom" if who == "mom" else "Ophelia"), 4.0)
		if is_instance_valid(_biggie):
			_biggie.mood(["sad"])
		var p: Node3D = rm.player
		_look(_biggie.head_position() + _flat(p.global_position - _biggie.global_position) * 1.4 + Vector3(0, 0.05, 0), _biggie.head_position() - Vector3(0, 0.1, 0), 38.0)
	if t >= A_END:
		_go()


## Biggie's said it: the place is set, the clock's running, she's hers again.
func _go() -> void:
	t = -1.0
	if is_instance_valid(_biggie):
		_biggie.queue_free()
	_biggie = null
	_build_site()
	left = Rescue.time()
	step = Step.RUNNING
	_clock.visible = true
	_hold(false)


func _saved_tick() -> void:
	var p: Node3D = rm.player
	if t < S_HIT + 0.3:
		p.global_position = _hit_from.lerp(_hit_to, smoothstep(S_HIT - 0.15, S_HIT + 0.1, t))
	if t >= S_HIT and not _said.has("hit"):
		_said["hit"] = true
		_veil.color = Color(1, 1, 1, 0.7)
		SFX.play(self, "hit_body", 0.0, 0.8)
	if _said.has("hit"):
		var k := smoothstep(S_HIT, S_HIT + 0.7, t)
		if is_instance_valid(_captor):
			if captor == "marrow":  # he comes apart into smoke and pools
				_captor.scale = Vector3(1.0 + k * 0.6, maxf(1.0 - k, 0.04), 1.0 + k * 0.6)
			else:  # over backwards
				_captor.rotation.x = k * PI * 0.5
		if t < S_FREE:
			_veil.color.a = maxf(0.0, 0.7 - (t - S_HIT) * 3.0)
	if t >= S_KNOCK and not _said.has("knock"):
		_said["knock"] = true
		rm.hud.toast(KNOCK[captor], 3.5)
	if t >= S_FREE and not _said.has("free"):
		_said["free"] = true
		_victim_pose = ""  # up on her feet
		if _site.has("out"):  # and out of the van
			_victim.global_position = _site["out"]
		_victim.mood(["smile"])
		var to_them := _flat(_victim.global_position - p.global_position)
		p.rotation.y = atan2(-to_them.x, -to_them.z)
		var mid := (p.global_position + _victim.global_position) * 0.5
		var gap := Vector2(p.global_position.x - _victim.global_position.x, p.global_position.z - _victim.global_position.z).length()
		var side := to_them.cross(Vector3.UP) * (1.4 + gap * 0.6)
		if _site.has("out"):  # from the street, not from inside the van
			side = side if side.x > 0.0 else -side
		_look(mid + side + Vector3(0, 1.45, 0), mid + Vector3(0, 1.2, 0), 42.0)
		rm.hud.toast(FREED[who], 3.2)
		SFX.play(self, "heartbeat", -10.0, 1.0)
	if t >= S_DARK:
		_veil.color = Color(0, 0, 0, smoothstep(S_DARK, S_DARK + 0.5, t) * (1.0 - smoothstep(S_END - 0.4, S_END, t)))
		if not _said.has("results"):
			_said["results"] = true
			_saved_results()
	if t >= S_END:
		_finish()


func _late_tick() -> void:
	if captor == "colony" and piece != "" and _victim != null:
		ColonyGear.fit_model(_victim, piece, smoothstep(0.8, 3.4, t))
	if captor == "cutter" and _victim != null:
		_shake(_victim, 1.0)
	if t >= L_SECOND and not _said.has("second"):
		_said["second"] = true
		rm.hud.toast(_late_line(1), 3.8)
		if captor == "marrow":  # home: the real them, back at their spot
			_show_real(true)
			var real: Node3D = rm.hub_npcs.get(who)
			if real != null:
				real.mood(["closed", "smile"])
				var face := _flat(-real.global_basis.z)
				_look(real.head_position() + face * 1.5 + Vector3(0, 0.05, 0), real.head_position() - Vector3(0, 0.08, 0), 34.0)
		elif captor == "colony":
			_victim.mood(["smile"])
			_look(_victim.head_position() + _flat(-_victim.global_basis.z) * 1.1 + Vector3(0, 0.05, 0), _victim.head_position() - Vector3(0, 0.06, 0), 32.0)
		else:
			if is_instance_valid(_captor):  # he turns to the road, grinning, her behind him
				_captor.rotation_degrees.y = 90.0
				_look(_captor.global_position + Vector3(-1.7, 1.5, 0.6), _captor.global_position + Vector3(0, 1.35, 0.15), 40.0)
			SFX.play(self, "impact", -10.0, 0.6)
	if t >= L_DARK:
		_veil.color = Color(0, 0, 0, smoothstep(L_DARK, L_DARK + 0.5, t) * (1.0 - smoothstep(L_END - 0.4, L_END, t)))
		if not _said.has("results"):
			_said["results"] = true
			_late_results()
	if t >= L_END:
		_finish()


func _late_line(i: int) -> String:
	var line: String = LATE[captor][i]
	var name_: String = Rescue.NAMES[who]
	if captor == "colony" and i == 0:
		return line % [name_, Hymn.GEAR_NAMES.get(piece, "gear")]
	if captor == "cutter" and i == 1:
		return line
	return line % name_


func _finish() -> void:
	t = -1.0
	rm.player.visible = true
	_veil.color.a = 0.0
	_teardown()
	step = Step.IDLE
	_hold(false)


## In time: closer, and the town's grip on Eco and the captor's on them ease.
func _saved_results() -> void:
	_bond(Rescue.BOND_SAVED)
	ViceLooks.add("town_grip", Rescue.GRIP_SAVED)
	Rescue.rescued(who, captor)
	rm.hud.toast("%s's home safe.  Bond +%d.  Town's Grip %d.  %s's hold on her -%d." % [Rescue.NAMES[who], Rescue.BOND_SAVED, int(Rescue.GRIP_SAVED),
			{"marrow": "Marrow", "colony": "The colony", "cutter": "Cutter"}[captor], int(-Rescue.HOOK_SAVED)], 5.0)


## Too late: further apart, the town's grip tighter, the captor's deeper.
func _late_results() -> void:
	_bond(Rescue.BOND_LATE)
	ViceLooks.add("town_grip", Rescue.GRIP_LATE)
	var got := Rescue.too_late(who, captor)
	var real: Node3D = rm.hub_npcs.get(who)
	if real != null and captor == "colony":
		ColonyGear.apply(real, HubGrip.gear_of(who))
	rm.hud.toast("Too late for %s.  Bond %d.  Town's Grip +%d.%s" % [Rescue.NAMES[who], Rescue.BOND_LATE, int(Rescue.GRIP_LATE),
			("  The colony's %s is on her." % Hymn.GEAR_NAMES.get(got, got)) if got != "" else ""], 5.0)


func _bond(by: int) -> void:
	var state: ConfigFile = rm.npc_talk.state
	if who == "mom":
		Family.add(state, "mom", by)
	else:
		Romance.add(state, who, by)
	state.save(rm.npc_talk.save_path)


## The colony's next piece for them (what take() will put on).
func _next_piece() -> String:
	for g in Hymn.GEAR:
		if not g in HubGrip.gear_of(who):
			return g
	return ""


# --- the place --------------------------------------------------------------------

func _build_site() -> void:
	_set = Node3D.new()
	_set.name = "RescueSite"
	rm.zone_root.add_child(_set)
	match captor:
		"marrow":
			_site = RescueSites.marrow()
			for f in rm.zone_info.get("marrow_figures", []):  # him at his table: he's up, by her chair, instead
				if is_instance_valid(f) and (f as Node3D).global_position.y < HushDen.BASEMENT.y + 5.0 and f.visible:
					f.visible = false
					_hidden.append(f)
			_captor = HushDen.figure(_set, _site["captor"], _site["captor_yaw"])
		"colony":
			_site = RescueSites.colony(_set)
			_captor = _holder(ShepherdModel.build())
		"cutter":
			_site = RescueSites.cutter(_set)
			_captor = _holder(CutterModel.build())
	_captor.position = _site["captor"]
	# light on them, so they're seen
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.85, 0.6, 1.0) if captor == "marrow" else Color(1.0, 0.85, 0.7)
	lamp.light_energy = 1.6 if captor == "marrow" else 0.8
	lamp.omni_range = 4.0
	lamp.position = (_site["seat"] as Vector3).lerp(_site["captor"], 0.5) + Vector3(0, 1.9, 0) + (Vector3(0.6, 0, -0.9) if captor == "marrow" else Vector3.ZERO)
	_set.add_child(lamp)
	_captor.rotation_degrees.y = _site["captor_yaw"]
	# them, in the seat they've been put in
	_victim = _npc(who, _site["seat"], _site["seat_yaw"])
	var real: Node3D = rm.hub_npcs[who]
	if real.get("outfit") != null and String(real.outfit) != "":
		_victim.wear(String(real.outfit))
	ColonyGear.apply(_victim, HubGrip.gear_of(who))
	_victim.mood(["sad"])
	_seat(_victim, float(_site["seat_height"]))
	_show_real(false)
	var K := preload("res://scripts/hub/hub_kit.gd")
	K.interactable(rm.zone_info, SPOT, _site["captor"], "[F] Knock him down", [""], 2.6)


## A model in a holder that can fall over at its feet.
func _holder(model: Node3D) -> Node3D:
	var h := Node3D.new()
	h.add_child(model)
	_set.add_child(h)
	return h


## Someone from the hub, a copy for the scene (no body to bump into).
func _npc(p_who: String, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = HubNpc.create(p_who, pos, yaw)
	(_set if _set != null else rm.zone_root).add_child(n)
	n.posed = true
	if is_instance_valid(n.soft_body):
		n.soft_body.queue_free()
	return n


## Sat down `height` up, the chair pose over their idle (eco_rest.gd), stepped here.
func _seat(n: Node3D, height: float) -> void:
	var skel := n.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	_victim_anim = n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _victim_anim != null:
		_victim_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_victim_rest = EcoRest.new(skel)
	_victim_rest.seat_height = height
	_victim_pose = "chair"
	if not _victim_rest.usable():
		_victim_rest = null


func _show_real(on: bool) -> void:
	var got = rm.hub_npcs.get(who)
	if got == null or not is_instance_valid(got):
		return
	var real: Node3D = got
	real.visible = on
	if is_instance_valid(real.get("soft_body")):
		real.soft_body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		(real.soft_body as CollisionObject3D).collision_layer = 1 if on else 0


func _remove_spot() -> void:
	if rm.zone_info.has("interactables"):
		rm.zone_info["interactables"] = rm.zone_info["interactables"].filter(func(s): return s["id"] != SPOT)


func _teardown() -> void:
	_remove_spot()
	if is_instance_valid(_biggie):
		_biggie.queue_free()
	_biggie = null
	if is_instance_valid(_set):
		_set.queue_free()
	_set = null
	_victim = null
	_victim_anim = null
	_victim_rest = null
	_captor = null
	for f in _hidden:
		if is_instance_valid(f):
			f.visible = true
	_hidden.clear()
	if who != "" and rm.get("hub_npcs") != null and rm.hub_npcs.has(who):
		_show_real(true)
	_clock.visible = false
	_marker.queue_redraw()
	if _cam != null:
		_cam.queue_free()
		_cam = null


## The players' view held for a scene (on), and handed back (off).
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


func _look(from: Vector3, at: Vector3, fov: float) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
	_cam.fov = fov
	_cam.look_at_from_position(from, at)
	_cam.make_current()


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD


# --- the marker ---------------------------------------------------------------------

## Where the marker points: the captor, or the cellar door while she's up in
## town and they're down Marrow's basement.
func target() -> Vector3:
	var at: Vector3 = _site.get("captor", Vector3.ZERO)
	if captor == "marrow" and rm.player.global_position.y > HushDen.BASEMENT.y + 5.0:
		return HushDen.CELLAR
	return at


func _draw_marker() -> void:
	if step != Step.RUNNING or busy():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := target() + Vector3(0, 2.2, 0)
	var size := _marker.get_rect().size
	if size.x < 200.0 or size.y < 200.0:
		return
	var p := cam.unproject_position(at)
	var behind := cam.is_position_behind(at)
	if behind:
		p = size - p
	var edge := 40.0
	var inside := Rect2(Vector2(edge, edge), size - Vector2(edge, edge) * 2.0)
	if behind or not inside.has_point(p):
		var c := size * 0.5
		var d := (p - c)
		if behind and d.length() < 1.0:
			d = Vector2(0, 1)
		var k := minf((size.x * 0.5 - edge) / maxf(absf(d.x), 0.001), (size.y * 0.5 - edge) / maxf(absf(d.y), 0.001))
		p = c + d * minf(k, 1.0)
	var r := 11.0
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	_marker.draw_colored_polygon(pts, Color(RED, 0.85))
	_marker.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.9), 2.0)
	var dist: float = rm.player.global_position.distance_to(target())
	_marker.draw_string(ThemeDB.fallback_font, p + Vector2(-30, r + 18), "%d m" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color(1, 0.9, 0.85))


# --- afterwards -------------------------------------------------------------------

## Cutter's Wiring on whoever's still got it in them (veins, a shake), each frame.
func _aftermath(_delta: float) -> void:
	if rm.get("hub_npcs") == null:
		return
	for w in Rescue.WHO:
		var got = rm.hub_npcs.get(w)  # (freed when she's left the hub: untyped till checked)
		if got == null or not is_instance_valid(got):
			continue
		var npc: Node3D = got
		var wired := Rescue.shows(w, "cutter")
		if wired != bool(npc.get_meta("wired", false)):
			veins(npc, wired)
		if wired:
			_shake(npc, 0.5)


## Their body shaking (their model, jittered in place).
func _shake(npc: Node3D, amount: float) -> void:
	var m := npc.get_node_or_null("Model") as Node3D
	if m != null:
		m.position = Vector3(randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)) * 0.006 * amount


## Red veins lit under their skin (on), or gone (off).
static func veins(npc: Node3D, on: bool) -> void:
	npc.set_meta("wired", on)
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			var base := (mi as MeshInstance3D).mesh.surface_get_material(i) as ShaderMaterial
			if base == null or not String(base.resource_name).ends_with("_body"):
				continue
			var mine := (mi as MeshInstance3D).get_surface_override_material(i) as ShaderMaterial
			if mine == null:
				mine = base.duplicate()
				mi.set_surface_override_material(i, mine)
			var pass_ := mine.next_pass as ShaderMaterial
			var ours := pass_ != null and pass_.has_meta("veins")
			if on and not ours:
				var v := ShaderMaterial.new()
				var sh := Shader.new()
				sh.code = VEINS
				v.shader = sh
				v.set_meta("veins", true)
				v.set_shader_parameter("albedo_tex", mine.get_shader_parameter("albedo_tex"))
				v.next_pass = mine.next_pass
				mine.next_pass = v
			elif not on and ours:
				mine.next_pass = pass_.next_pass
	if not on:
		var m := npc.get_node_or_null("Model") as Node3D
		if m != null:
			m.position = Vector3.ZERO


## Marrow's quiet in them: said once a stay, before they talk. "" if not.
func quiet_line(p_who: String) -> String:
	if not Rescue.shows(p_who, "marrow") or _quiet_said.has(p_who):
		return ""
	_quiet_said[p_who] = true
	return QUIET % Rescue.NAMES.get(p_who, p_who)
