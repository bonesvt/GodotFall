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
const RescueLooks := preload("res://scripts/hub/rescue_looks.gd")
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
## Too late: the captor puts it in them (the drug to her lips, the needle to her
## eye, the piece on her: L_IN), then what it's done, then what comes after.
const L_CLOSE := 2.0
const L_IN := 3.4
const L_AFTER := 4.6
const L_SECOND := 7.6
const L_DARK := 11.0
const L_END := 12.0

const KNOCK := {
	"marrow": "Eco hits him with her whole weight. He comes apart like smoke round her shoulder and pools on the floor, and from everywhere at once: \"Take her, then. She'll find her own way back.\"",
	"colony": "Eco slams into the Shepherd shoulder first. It goes over backwards and lies there, its calm voice still going: \"Please remain calm. Please remain calm. Please remain\"",
	"cutter": "Eco takes Cutter from behind, low and hard. He goes down in the dirt, laughing even now: \"Okay! Okay. She's all yours. For now.\"",
}
const FREED := {
	"mom": "Mom takes Eco's face in both hands. \"You came. Oh, baby. You came for me.\"",
	"ophelia": "Ophelia throws her arms round Eco's neck and doesn't let go. \"I knew it'd be you. I knew it.\"",
}
## Too late, as they do it (%s: Mom or Ophelia; the colony's: the piece, then her).
const APPLY := {
	"marrow": "Marrow, bent over the armchair, a vial of violet in his long fingers. \"Shh. Just a little. You'll feel so much better.\" He tips it to %s's lips.",
	"colony": "The Shepherd leans in over the white bench. \"Hold still, citizen.\" It brings the colony's %s up to %s.",
	"cutter": "Cutter's got %s's chin in one hand and a needle of Redline in the other. \"Eyes open. You'll love it.\"",
}
## Too late, after: [what it's done, what comes after] (%s: Mom or Ophelia; the colony's: the piece).
const LATE := {
	"marrow": ["%s sinks deep into the armchair, violet curling off her breath, smiling at nothing. His hand rests on the back of the chair.",
		"%s comes home after dark. Calm. Quiet. She smiles at Eco like she's someone she used to know, and goes to bed without a word."],
	"colony": ["The colony van. %s sits very straight on the white bench, the colony's %s on her now.",
		"It's on. %s blinks, and smiles, and doesn't stop. \"I feel so calm.\""],
	"cutter": ["%s's on the crate, shaking so hard it rattles. Red lines glow up her arms and her neck, under the skin. Wiring.",
		"Cutter, grinning: \"Tell Eco she's next. Tell her mine's better than Marrow's.\""],
}
## The eyes they come away with, like Eco's own under the same thing: Marrow's
## violet swirl, the colony's white, Cutter's red (eco_toon's iris swirl),
## strong as it goes in, fainter after while his hold on them shows.
const EYE_TINT := {"marrow": Color(0.72, 0.32, 1.0), "colony": Color(0.55, 0.78, 1.0), "cutter": Color(1.0, 0.12, 0.08)}
const EYES_IN := 0.9
const EYES_AFTER := 0.5
## Afterwards: now and then, a stay, one of them who's been had walks off to
## whoever had her, and Eco can see her going: DRAWN_CHANCE a stay, once Eco's
## been out in Solace DRAWN_DELAY s. The way she walks (town.gd's streets).
const DRAWN_CHANCE := 0.5
const DRAWN_DELAY := Vector2(15.0, 40.0)
const WALK_SPEED := 1.1
const SPOT_RANGE := 8.0
const ROUTES := {
	"marrow": [Vector3(-1.5, 0, 191.0), Vector3(2.0, 0, 204.0), Vector3(4.6, 0, 213.3)],
	"colony": [Vector3(1.5, 0, 133.0), Vector3(-0.5, 0, 141.0), Vector3(-4.4, 0, 146.8)],
	"cutter": [Vector3(0.5, 0, 131.0), Vector3(1.0, 0, 124.0), Vector3(5.4, 0, 116.5)],
}
const SPOTTED := {
	"marrow": "%s, walking down Low Row toward the cinema's cellar door. Eco calls her name. She doesn't turn. Her eyes are violet at the edges.",
	"colony": "%s, walking up Lantern Row to the colony kiosk like she's late for it. Eco calls her. She smiles back, white-eyed, and keeps walking.",
	"cutter": "%s, out past the town gate, heading for the pilgrim road and Cutter's tarp. Shaking. Red in her eyes. She doesn't hear Eco at all.",
}
const GONE := "%s's not at home. Someone saw her heading into Solace."
## Once she's there: where she settles, taking more every TAKE_EVERY s, and
## what Eco sees when she finds her.
const TAKE_EVERY := 7.0
const FOUND := {
	"marrow": "%s, sunk in the armchair in Marrow's basement, tipping another vial of violet to her lips. Marrow stands back by the shelves, watching. She doesn't look up.",
	"colony": "%s, in the fitting chair in the colony's back room, eyes swirling white, taking another film while a Shepherd runs its scanner over her gear. \"Good morning, citizen,\" it says. She says it back.",
	"cutter": "%s, on the crate under Cutter's tarp, a vial of Redline in her shaking hand. Cutter's leaning on a post, grinning at Eco. \"She came on her own.\"",
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
## when she left the hub was lost: lose() first.) And maybe, this stay, one
## who's been had goes back to whoever had her.
func reset() -> void:
	lose()
	_rolled = false
	_roll = Rescue.ROLL_EVERY
	_quiet_said.clear()
	_shaders.clear()
	_end_walk()
	_drawn_who = ""
	_drawn_at = -1.0
	if Rescue.allowed() and rm.get("hub_npcs") != null and randf() < DRAWN_CHANCE:
		var held: Array = Rescue.WHO.filter(func(w): return rm.hub_npcs.has(w) and Rescue.held_by(w) != "")
		if not held.is_empty():
			draw_off(held[randi() % held.size()], randf_range(DRAWN_DELAY.x, DRAWN_DELAY.y))


## `p_who` will go to whoever's got her, once Eco's been out in Solace `after` s.
func draw_off(p_who: String, after: float) -> void:
	_drawn_who = p_who
	_drawn_captor = Rescue.held_by(p_who)
	_drawn_at = after if _drawn_captor != "" else -1.0


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
	if _drawn_at >= 0.0 and roaming and rm.player.global_position.z > 120.0 and step == Step.IDLE:
		_drawn_at -= delta
		if _drawn_at < 0.0:
			_start_walk()


## Takes one of them, by one of the captors who've started on Eco. False if
## nobody could be.
func start_random() -> bool:
	var captors := Rescue.active_captors()
	var people: Array = Rescue.WHO.filter(func(w): return rm.hub_npcs.has(w) and not (w == _drawn_who and (_walker != null or _hang != null)))
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
	_victim.mood(["sad"])
	rm.player.visible = false  # she isn't there: this is what she missed
	_late_set()
	rm.hud.toast(_apply_line(), 3.4)
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
	_apply_tick()
	if captor == "colony" and piece != "" and _victim != null:
		ColonyGear.fit_model(_victim, piece, smoothstep(0.8, L_IN, t))
	if captor == "cutter" and _victim != null and t >= L_IN:
		_shake(_victim, 1.0)
	if t >= L_AFTER and not _said.has("after"):
		_said["after"] = true
		_drop_prop()
		_step_back()
		_victim.mood(["plain"] if captor == "colony" else (["smile"] if captor == "marrow" else ["sad"]))  # eyes open: what's in them shows
		_look(_site["cam"], _victim.head_position() + Vector3(0, -0.25, 0), 40.0)
		rm.hud.toast(_late_line(0), 3.6)
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


## Too late, as it happens: the captor brought in close to them, facing them,
## and what they're putting in or on them in his hand.
var _prop: Node3D
var _prop_from := Vector3.ZERO
var _rod: MeshInstance3D


func _late_set() -> void:
	var seat: Vector3 = _site["seat"]
	var at := seat
	match captor:
		"marrow":
			at = seat + Vector3(0.42, 0, -0.55)
		"colony":
			at = seat + Vector3(0.85, 0, 0)
		"cutter":
			at = seat + Vector3(-0.7, 0, 0)
	if is_instance_valid(_captor):
		_captor.position = at
		var d := _flat(_victim.global_position - at)
		_captor.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
		_captor.scale = Vector3.ONE
	var toward := _flat(_victim.global_position - at)
	_prop_from = at + Vector3(0, 1.2, 0) + toward * 0.32
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	match captor:
		"marrow":  # a vial of Hush, glowing violet
			glow.albedo_color = Color(0.72, 0.32, 1.0)
			glow.emission = glow.albedo_color
			glow.emission_energy_multiplier = 2.5
			_prop = Node3D.new()
			var vial := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.012
			c.bottom_radius = 0.014
			c.height = 0.07
			vial.mesh = c
			vial.material_override = glow
			_prop.add_child(vial)
			var light := OmniLight3D.new()
			light.light_color = glow.albedo_color
			light.light_energy = 1.2
			light.omni_range = 1.6
			_prop.add_child(light)
		"cutter":  # his needle of Redline
			glow.albedo_color = Color(1.0, 0.1, 0.08)
			glow.emission = glow.albedo_color
			glow.emission_energy_multiplier = 2.0
			_prop = Node3D.new()
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.8, 0.82, 0.85)
			steel.metallic = 0.9
			for part in [[0.0075, 0.07, 0.0, glow], [0.0007, 0.05, -0.06, steel], [0.002, 0.04, 0.055, steel]]:
				var mi := MeshInstance3D.new()
				var cy := CylinderMesh.new()
				cy.top_radius = part[0]
				cy.bottom_radius = part[0]
				cy.height = part[1]
				mi.mesh = cy
				mi.material_override = part[3]
				mi.rotation_degrees = Vector3(90, 0, 0)
				mi.position = Vector3(0, 0, part[2])
				_prop.add_child(mi)
		"colony":  # its arm: a white rod from its hand to the piece going on
			_rod = MeshInstance3D.new()
			var rod := CylinderMesh.new()
			rod.top_radius = 0.012
			rod.bottom_radius = 0.016
			rod.height = 1.0
			_rod.mesh = rod
			var white := StandardMaterial3D.new()
			white.albedo_color = Color(0.92, 0.94, 0.97)
			_rod.material_override = white
			_set.add_child(_rod)
	if _prop != null:
		_set.add_child(_prop)
		_prop.global_position = _prop_from
	# the two of them, from the side
	var mid: Vector3 = (_prop_from + _victim.head_position()) * 0.5
	var side := toward.cross(Vector3.UP)
	if captor == "colony":
		side = Vector3(1, 0, 0.6).normalized() * 2.4  # from the street, in through the door
	elif captor == "cutter":
		side = Vector3(0, 0, 1)  # from the open side of the tarp
	_look(mid + side * 1.5 + Vector3(0, 0.15, 0), mid - Vector3(0, 0.1, 0), 40.0)


## Where on them it's going: her lips (Marrow), her eye (Cutter).
func _apply_target() -> Vector3:
	var fwd := _flat(-_victim.global_basis.z)
	var right := fwd.cross(Vector3.UP)
	if captor == "cutter":
		return _victim.head_position() + Vector3(0, 0.02, 0) + fwd * 0.075 + right * 0.032
	return _victim.head_position() - Vector3(0, 0.045, 0) + fwd * 0.08


func _apply_tick() -> void:
	var k := smoothstep(0.8, L_IN, t)
	if _prop != null and is_instance_valid(_prop):
		var to := _apply_target()
		_prop.global_position = _prop_from.lerp(to + (_prop_from - to).normalized() * 0.03, k)
		if captor == "cutter":
			_prop.look_at(to, Vector3.UP)
	if _rod != null and is_instance_valid(_rod) and piece != "":
		var node := ColonyGear.piece_node(_victim, piece)
		var a := _prop_from
		var b: Vector3 = node.global_position if node != null else _victim.head_position()
		_rod.global_position = (a + b) * 0.5
		var dir := b - a
		_rod.scale = Vector3(1, maxf(dir.length(), 0.01), 1)
		if dir.length() > 0.01:
			_rod.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
	if captor == "cutter" and t >= L_CLOSE and not _said.has("close"):
		_said["close"] = true  # close on her eye as it comes in
		var fwd := _flat(-_victim.global_basis.z)
		var eye := _apply_target() - fwd * 0.075
		_look(eye + fwd * 0.4 + Vector3(0, 0, 0.22) - Vector3(0, 0.02, 0), eye, 22.0)
	if t >= L_IN and not _said.has("in"):
		_said["in"] = true
		match captor:
			"marrow":
				_victim.mood(["closed", "smile"])
				rm.hud.toast("She drinks. Her eyes go soft and violet at the edges.", 2.0)
			"colony":
				SFX.play(self, "cache_unlock", -4.0, 0.7)
				_victim.mood(["plain"])  # a blank, open stare
			"cutter":
				_veil.color = Color(0.85, 0.05, 0.05, 0.85)  # red, at contact, and nothing more
				veins(_victim, true)
				SFX.play(self, "heartbeat", 0.0, 1.2)
		eyes(_victim, EYES_IN, EYE_TINT[captor])  # the same in her eyes as Eco gets
	if captor == "cutter" and t >= L_IN and t < L_AFTER:
		_veil.color.a = 0.85 * (1.0 - smoothstep(L_IN, L_IN + 0.8, t))


## Done: the captor steps back out of the way (Marrow to behind her chair, a
## hand on it; the Shepherd out of the van; Cutter off to the side).
func _step_back() -> void:
	if not is_instance_valid(_captor):
		return
	var seat: Vector3 = _site["seat"]
	match captor:
		"marrow":
			_captor.position = seat + Vector3(0.35, 0, 0.55)
		"colony":
			_captor.position = seat + Vector3(1.6, -RescueSites.VAN_FLOOR, -1.1)
		"cutter":
			_captor.position = seat + Vector3(-0.85, 0, -0.85)
	var d := _flat(_victim.global_position - _captor.position)
	_captor.rotation = Vector3(0, atan2(-d.x, -d.z), 0)


func _drop_prop() -> void:
	if _prop != null and is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	if _rod != null and is_instance_valid(_rod):
		_rod.queue_free()
	_rod = null


func _apply_line() -> String:
	var name_: String = Rescue.NAMES[who]
	if captor == "colony":
		return APPLY[captor] % [Hymn.GEAR_NAMES.get(piece, "gear"), name_]
	return APPLY[captor] % name_


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
	_drop_prop()
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

## Cutter's Wiring on whoever's still got it in them (veins, a shake), and the
## eyes whoever's had them left them with, each frame; and one of them walking off.
func _aftermath(_delta: float) -> void:
	_walk_tick(_delta)
	_hang_tick(_delta)
	if rm.get("hub_npcs") == null:
		return
	for w in Rescue.WHO:
		var got = rm.hub_npcs.get(w)  # (freed when she's left the hub: untyped till checked)
		if got == null or not is_instance_valid(got):
			continue
		var npc: Node3D = got
		var look := Rescue.changed_by(w)  # walked to them VISITS times: dressed like theirs
		if String(npc.get_meta("rescue_look", "")) != look:
			RescueLooks.apply(npc, w, look)
		var by := Rescue.held_by(w)
		if String(npc.get_meta("rescue_eyes", "")) != by:
			npc.set_meta("rescue_eyes", by)
			eyes(npc, EYES_AFTER if by != "" else 0.0, EYE_TINT.get(by, Color.WHITE))
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


## Their irises swirling in `tint`, `strength` 0..1 (0: their own eyes again).
static func eyes(npc: Node3D, strength: float, tint: Color) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	for mi in npc.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		var has := false
		for i in m3.mesh.get_surface_count():
			var base := m3.mesh.surface_get_material(i) as ShaderMaterial
			if base == null or not String(base.resource_name).ends_with("_iris"):
				continue
			has = true
			var mine := m3.get_surface_override_material(i) as ShaderMaterial
			if mine == null or not mine.has_meta("rescue_iris"):
				mine = (mine if mine != null else base).duplicate()
				mine.set_meta("rescue_iris", true)
				m3.set_surface_override_material(i, mine)
			mine.set_shader_parameter("iris_swirl", strength > 0.0)
		if has:
			m3.set_instance_shader_parameter("hypno", strength)
			m3.set_instance_shader_parameter("swirl_tint", tint)


# --- drawn back to them -------------------------------------------------------------

var _drawn_who := ""
var _drawn_captor := ""
var _drawn_at := -1.0
var _walker: Node3D
var _walk_route: Array = []
var _walk_leg := 1
var _spotted := false


## She's off to them: gone from home, and walking through Solace.
func _start_walk() -> void:
	_drawn_at = -1.0
	if _drawn_who == "" or not rm.hub_npcs.has(_drawn_who):
		return
	_walk_route = ROUTES[_drawn_captor]
	var real: Node3D = rm.hub_npcs[_drawn_who]
	_walker = HubNpc.create(_drawn_who, _walk_route[0], 0.0)
	_walker.name = "Drawn_" + _drawn_who
	rm.zone_root.add_child(_walker)
	_walker.posed = true
	if is_instance_valid(_walker.soft_body):
		_walker.soft_body.queue_free()
	if real.get("outfit") != null and String(real.outfit) != "":
		_walker.wear(String(real.outfit))
	ColonyGear.apply(_walker, HubGrip.gear_of(_drawn_who))
	_walker.mood(["plain"])
	eyes(_walker, EYES_IN, EYE_TINT[_drawn_captor])
	if _drawn_captor == "cutter":
		veins(_walker, true)
	RescueLooks.apply(_walker, _drawn_who, Rescue.changed_by(_drawn_who))
	_borrow_walk(_walker)
	_walk_leg = 1
	_spotted = false
	real.visible = false
	if is_instance_valid(real.get("soft_body")):
		(real.soft_body as CollisionObject3D).collision_layer = 0
	_walker_spot(true)


## Her walk: the townsfolk's walk loop, borrowed (their rigs are the same).
static func _borrow_walk(npc: Node3D) -> void:
	var ap := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var path := "res://assets/models/npc/town_bram.glb"
	if ap == null or not ResourceLoader.exists(path):
		return
	var src: Node = load(path).instantiate()
	var sap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sap != null and sap.has_animation("walk"):
		ap.stop()  # (adding a library to a playing player reads freed memory: hub_npc.gd)
		var lib := AnimationLibrary.new()
		var walk: Animation = sap.get_animation("walk").duplicate()
		walk.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("walk", walk)
		if not ap.has_animation_library("rescue"):
			ap.add_animation_library("rescue", lib)
		ap.play("rescue/walk")
	src.free()


func _walk_tick(delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		return
	if rm.get("bench") != null or busy():
		return
	var to: Vector3 = _walk_route[_walk_leg]
	var at := _walker.global_position
	var d := Vector3(to.x - at.x, 0, to.z - at.z)
	if d.length() < 0.15:
		_walk_leg += 1
		if _walk_leg >= _walk_route.size():
			_settle()  # there: with them, for the rest of the stay
			return
		return
	var step_ := d.normalized() * minf(WALK_SPEED * delta, d.length())
	_walker.global_position += step_
	_walker.rotation.y = atan2(-d.x, -d.z)
	if _drawn_captor == "cutter":
		_shake(_walker, 0.6)
	if not _spotted and rm.player.global_position.distance_to(_walker.global_position) < SPOT_RANGE:
		_spotted = true
		rm.hud.toast(SPOTTED[_drawn_captor] % Rescue.NAMES[_drawn_who], 5.0)


func _end_walk() -> void:
	if _walker != null and is_instance_valid(_walker):
		_walker.queue_free()
	_walker = null
	if _hang != null and is_instance_valid(_hang):
		_hang.queue_free()
	_hang = null
	_hanger = null
	_hang_prop = null
	for f in _hang_hidden:
		if is_instance_valid(f):
			f.visible = true
	_hang_hidden.clear()
	_hang_spots(false)
	_walker_spot(false)


# --- there, taking more ----------------------------------------------------------

## The colony's back room, behind the kiosk: built out of sight while she's in
## it (a door at the kiosk and one back out).
const BACK_ROOM := Vector3(40.0, -60.0, 150.0)
const KIOSK_DOOR := Vector3(-5.6, 0, 148.3)
const KIOSK_OUT := Vector3(-4.4, 0.1, 148.6)
const ROOM_MODELS := "res://assets/models/fitting_room/fitting_room.glb"
const SEAT := 0.46
## What [F] at her gets: she won't come home.
const HANG_LINES := {
	"marrow": ["%s doesn't look up from the vial. \"Not now, Eco. Go home. I'll be along.\" She won't come.",
		"%s: \"I'm resting. That's all this is. Let me rest.\" She won't get up."],
	"colony": ["%s, very politely: \"Please wait outside, citizen. I'm being looked after.\" She won't get up.",
		"%s: \"They're checking my fit. It won't take long. You shouldn't be back here.\""],
	"cutter": ["%s, too fast: \"I'm fine, I'm fine, go home, Eco, I'm fine.\" She won't come.",
		"%s: \"Don't. Don't. I'll come back when it's gone. Promise.\" She won't come."],
}

## Where she ends up: a node holding her (and for Cutter, his stash and him).
var _hang: Node3D
var _hanger: Node3D
var _hang_prop: Node3D
var _hang_anim: AnimationPlayer
var _hang_rest: EcoRest
var _hang_pose := ""
var _hang_t := 0.0
var _found := false
var _hang_hidden: Array = []


## She's got there: sat at the captor's place for the rest of the stay,
## taking more now and then; and one more visit counted (rescue_looks.gd).
func _settle() -> void:
	if _walker != null and is_instance_valid(_walker):
		_walker.queue_free()
	_walker = null
	Rescue.visited(_drawn_who, _drawn_captor)
	_hang = Node3D.new()
	_hang.name = "RescueHangout"
	rm.zone_root.add_child(_hang)
	var at := Vector3.ZERO
	var yaw := 0.0
	var seat := 0.0
	match _drawn_captor:
		"marrow":  # her armchair in his basement's main room, him stood back by the shelves
			var site := RescueSites.marrow()
			at = site["seat"]
			yaw = site["seat_yaw"]
			seat = site["seat_height"]
			for f in rm.zone_info.get("marrow_figures", []):
				if is_instance_valid(f) and (f as Node3D).global_position.y < HushDen.BASEMENT.y + 5.0 and f.visible:
					f.visible = false
					_hang_hidden.append(f)
			var by_shelves := HushDen.BASEMENT + Vector3(-2.2, 0, -1.9)
			var d := _flat(at - by_shelves)
			HushDen.figure(_hang, by_shelves, rad_to_deg(atan2(-d.x, -d.z)))
		"colony":  # the fitting chair in the back room, a Shepherd checking her gear
			at = _back_room()
			yaw = 180.0  # facing the door
			seat = SEAT
		"cutter":  # on his crate under his tarp, him leaning on a post
			var site := RescueSites.cutter(_hang)
			at = site["seat"]
			yaw = site["seat_yaw"]
			seat = site["seat_height"]
			var him := Node3D.new()
			him.add_child(CutterModel.build())
			_hang.add_child(him)
			var post := RescueSites.STASH + Vector3(-0.9, 0, 1.3)
			him.position = post + Vector3(0.22, 0, -0.18)
			var d := _flat(at - him.position)
			him.rotation = Vector3(0, atan2(-d.x, -d.z), deg_to_rad(-7.0))  # leant on the post
	_hanger = HubNpc.create(_drawn_who, at, yaw)
	_hang.add_child(_hanger)
	_hanger.posed = true
	if is_instance_valid(_hanger.soft_body):
		_hanger.soft_body.queue_free()
	var real: Node3D = rm.hub_npcs.get(_drawn_who)
	if real != null and real.get("outfit") != null and String(real.outfit) != "":
		_hanger.wear(String(real.outfit))
	ColonyGear.apply(_hanger, HubGrip.gear_of(_drawn_who))
	RescueLooks.apply(_hanger, _drawn_who, Rescue.changed_by(_drawn_who))
	_hanger.mood(["plain"] if _drawn_captor == "colony" else (["smile"] if _drawn_captor == "marrow" else ["sad"]))
	eyes(_hanger, EYES_IN if _drawn_captor == "colony" else EYES_AFTER, EYE_TINT[_drawn_captor])
	if _drawn_captor == "cutter":
		veins(_hanger, true)
	_hang_anim = null
	_hang_rest = null
	_hang_pose = ""
	if seat > 0.0:
		var skel := _hanger.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null:
			_hang_anim = _hanger.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if _hang_anim != null:
				_hang_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			_hang_rest = EcoRest.new(skel)
			_hang_rest.seat_height = seat
			_hang_pose = "chair"
			if not _hang_rest.usable():
				_hang_rest = null
	_hang_prop = _take_prop(_drawn_captor)
	_hang.add_child(_hang_prop)
	_hang_t = TAKE_EVERY - 2.0
	_found = false
	_hang_spots(true)


## The colony's back room: white walls, a lit seam, the fitting chair, and a
## Shepherd beside it running a scanner over her gear. Returns where she sits.
func _back_room() -> Vector3:
	var r := BACK_ROOM
	var K := preload("res://scripts/hub/hub_kit.gd")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.9, 0.92, 0.95)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.55, 0.6, 0.68)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.85, 0.95, 1.0)
	lit.emission_enabled = true
	lit.emission = lit.albedo_color
	lit.emission_energy_multiplier = 2.5
	for spec in [[Vector3(0, -0.05, 0), Vector3(4.4, 0.1, 4.4)], [Vector3(0, 2.85, 0), Vector3(4.4, 0.1, 4.4)],
			[Vector3(0, 1.4, -2.2), Vector3(4.4, 2.9, 0.1)], [Vector3(0, 1.4, 2.2), Vector3(4.4, 2.9, 0.1)],
			[Vector3(-2.2, 1.4, 0), Vector3(0.1, 2.9, 4.4)], [Vector3(2.2, 1.4, 0), Vector3(0.1, 2.9, 4.4)]]:
		K.Kit.box(_hang, r + spec[0], spec[1], K.STONE, Vector3.ZERO, white)
	for x in [-1.0, 1.0]:
		RescueSites._box(_hang, r + Vector3(x, 2.79, -0.3), Vector3(0.8, 0.02, 2.0), lit)
	RescueSites._box(_hang, r + Vector3(0, 1.0, -2.14), Vector3(2.4, 0.04, 0.02), lit)
	var light := OmniLight3D.new()
	light.light_color = Color(0.92, 0.96, 1.0)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = r + Vector3(0, 2.4, 0.4)
	_hang.add_child(light)
	# the fitting chair (the modelled one, else a white seat on a post), facing the door
	var chair := Node3D.new()
	chair.position = r + Vector3(0, 0, -0.6)
	chair.rotation.y = PI  # facing the door
	_hang.add_child(chair)
	var mats := {"shell": white, "trim": trim, "lit": lit, "dark": RescueLooks._mat(Color(0.12, 0.13, 0.16)), "chrome": RescueLooks._mat(Color(0.75, 0.78, 0.82), 0.2, 0.9)}
	if not _room_part(chair, "chair", mats):
		RescueSites._box(chair, Vector3(0, SEAT - 0.04, -0.12), Vector3(0.5, 0.08, 0.5), white)
		RescueSites._box(chair, Vector3(0, (SEAT - 0.08) * 0.5, -0.1), Vector3(0.12, SEAT - 0.08, 0.12), trim)
		RescueSites._box(chair, Vector3(0, SEAT + 0.2, 0.17), Vector3(0.46, 0.34, 0.06), white)
	# the Shepherd beside her, its scanner on her gear, a thin white line of light
	var shepherd := Node3D.new()
	shepherd.add_child(ShepherdModel.build())
	_hang.add_child(shepherd)
	shepherd.position = r + Vector3(0.7, 0, -0.15)
	var d := _flat(chair.position - shepherd.position)
	shepherd.rotation.y = atan2(-d.x, -d.z)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.003
	bm.bottom_radius = 0.003
	bm.height = 1.0
	beam.mesh = bm
	beam.material_override = lit
	beam.name = "ScanBeam"
	beam.set_meta("from", shepherd.position + Vector3(0, 1.18, 0) + d * 0.38)
	_hang.add_child(beam)
	return chair.position


## One of the modelled fitting room's parts (tools/hub/build_fitting_room.py).
static func _room_part(root: Node3D, part: String, mats: Dictionary) -> bool:
	if not ResourceLoader.exists(ROOM_MODELS):
		return false
	var inst := (load(ROOM_MODELS) as PackedScene).instantiate()
	var found := false
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var bits := String(mi.name).split("__")
		if bits.size() < 2 or bits[0] != part:
			continue
		var key := ""
		for ch in bits[1]:
			if ch < "a" or ch > "z":
				break
			key += ch
		var m := MeshInstance3D.new()
		m.mesh = (mi as MeshInstance3D).mesh
		m.transform = (mi as Node3D).transform
		m.material_override = mats.get(key, mats["shell"])
		root.add_child(m)
		found = true
	inst.free()
	return found


## [F] at her (she won't come home), and the colony back room's doors.
func _hang_spots(on: bool) -> void:
	if rm.get("zone_info") == null or not rm.zone_info.has("interactables"):
		return
	rm.zone_info["interactables"] = rm.zone_info["interactables"].filter(func(s): return not s["id"] in ["rescue_hangout", "rescue_backroom", "rescue_backroom_out"])
	if not on or _hanger == null:
		return
	var K := preload("res://scripts/hub/hub_kit.gd")
	var name_: String = Rescue.NAMES[_drawn_who]
	K.interactable(rm.zone_info, "rescue_hangout", _hanger.global_position, "[F] %s" % name_,
			(HANG_LINES[_drawn_captor] as Array).map(func(l): return l % name_), 1.6)
	if _drawn_captor == "colony":
		K.interactable(rm.zone_info, "rescue_backroom", KIOSK_DOOR, "[F] The door behind the kiosk", [""], 1.2)
		rm.zone_info["interactables"].back()["teleport"] = BACK_ROOM + Vector3(0, 0.1, 1.5)
		K.interactable(rm.zone_info, "rescue_backroom_out", BACK_ROOM + Vector3(0, 0, 1.9), "[F] Back out to the street", [""], 1.2)
		rm.zone_info["interactables"].back()["teleport"] = KIOSK_OUT

## What she takes: a vial of Hush, a Hymn film, a needle of Redline.
func _take_prop(kind: String) -> Node3D:
	var p := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	var mi := MeshInstance3D.new()
	match kind:
		"marrow":
			glow.albedo_color = Color(0.72, 0.32, 1.0)
			var c := CylinderMesh.new()
			c.top_radius = 0.012
			c.bottom_radius = 0.014
			c.height = 0.07
			mi.mesh = c
		"colony":
			glow.albedo_color = Color(0.92, 0.96, 1.0)
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 0.002, 0.045)
			mi.mesh = b
		_:  # a vial of Redline
			glow.albedo_color = Color(1.0, 0.1, 0.08)
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.012
			c2.bottom_radius = 0.014
			c2.height = 0.07
			mi.mesh = c2
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.2
	mi.material_override = glow
	p.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = glow.albedo_color
	light.light_energy = 0.5
	light.omni_range = 1.2
	p.add_child(light)
	return p


## Each frame: her pose, the prop in her lap and up to her lips (Marrow's, the
## colony's) or her arm (Cutter's) every TAKE_EVERY s, her eyes flaring as it
## goes in; and Eco finding her.
func _hang_tick(delta: float) -> void:
	if _hanger == null or not is_instance_valid(_hanger):
		return
	if _hang_anim != null:
		_hang_anim.advance(delta)
	if _hang_rest != null:
		_hang_rest.step(delta, _hang_pose)
	_hang_t += delta
	var c := fmod(_hang_t, TAKE_EVERY)
	var k := smoothstep(0.0, 1.4, c) * (1.0 - smoothstep(2.6, 3.6, c))  # up, a moment, down
	var fwd := _flat(-_hanger.global_basis.z)
	var right := fwd.cross(Vector3.UP)
	var head: Vector3 = _hanger.head_position()
	var lap := _hanger.global_position + Vector3(0, 0.62 if _hang_pose != "" else 1.0, 0) + fwd * 0.28 + right * 0.08
	var to := head - Vector3(0, 0.045, 0) + fwd * 0.08  # her lips
	if _hang_prop != null and is_instance_valid(_hang_prop):
		_hang_prop.global_position = lap.lerp(to, k)
	var flare := smoothstep(1.2, 1.6, c) * (1.0 - smoothstep(3.0, 5.0, c))
	_hanger.set_meta("rescue_eyes", _drawn_captor)
	eyes(_hanger, EYES_IN if _drawn_captor == "colony" else lerpf(EYES_AFTER, EYES_IN, flare), EYE_TINT[_drawn_captor])
	var beam := _hang.get_node_or_null("ScanBeam") as MeshInstance3D if _hang != null else null
	if beam != null:  # the Shepherd's scanner, sweeping over her gear
		var a: Vector3 = beam.get_meta("from")
		var b: Vector3 = head + Vector3(0.05 * sin(_hang_t * 2.3), -0.02 + 0.05 * sin(_hang_t * 1.1), 0)
		var dir := b - a
		beam.global_position = (a + b) * 0.5
		beam.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
	if _drawn_captor == "cutter":
		_shake(_hanger, 0.6 + flare)
	if not _found and rm.player.global_position.distance_to(_hanger.global_position) < 6.0 \
			and absf(rm.player.global_position.y - _hanger.global_position.y) < 3.0:
		_found = true
		rm.hud.toast(FOUND[_drawn_captor] % Rescue.NAMES[_drawn_who], 5.0)


## While she's out, her spot at home says so.
func _walker_spot(on: bool) -> void:
	if rm.get("zone_info") == null or not rm.zone_info.has("interactables"):
		return
	rm.zone_info["interactables"] = rm.zone_info["interactables"].filter(func(s): return s["id"] != "rescue_gone")
	if on and _drawn_who != "" and rm.hub_npcs.has(_drawn_who):
		var K := preload("res://scripts/hub/hub_kit.gd")
		K.interactable(rm.zone_info, "rescue_gone", (rm.hub_npcs[_drawn_who] as Node3D).global_position, "[F] Where's %s?" % Rescue.NAMES[_drawn_who], [GONE % Rescue.NAMES[_drawn_who]], 2.0)


## Theirs now (rescue_looks.gd): what they say instead of talking with her. "" if not.
var _changed_n := {}
func changed_line(p_who: String) -> String:
	var c := Rescue.changed_by(p_who)
	if c == "":
		return ""
	var n: int = _changed_n.get(p_who, 0)
	_changed_n[p_who] = n + 1
	return RescueLooks.line(p_who, c, n)


## Marrow's quiet in them: said once a stay, before they talk. "" if not.
func quiet_line(p_who: String) -> String:
	if not Rescue.shows(p_who, "marrow") or _quiet_said.has(p_who):
		return ""
	_quiet_said[p_who] = true
	return QUIET % Rescue.NAMES.get(p_who, p_who)
