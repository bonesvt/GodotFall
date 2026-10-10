extends Node
## A rescue, live in the hub (rescue.gd has the rules): the roll, Biggie
## running in with it, the marker and the countdown, the captor waiting with
## them at the place (rescue_sites.gd), and the two endings:
##   in time   Eco knocks the captor down ([F] at him) and gets them out
##   too late  the countdown runs out: what happened, where it happened
## And afterwards, Cutter's Wiring on whoever he had (red veins, a shake) and
## Marrow's quiet in them, while his hold is past Rescue.SHOWS_AT; and [F] at
## one of them on her way back to them (stop_walker()): she comes round, or,
## once she's theirs, a quick-time event to hold on to her, and if Eco loses
## her, she gives Eco what they gave her.
## The run manager calls tick() from the hub, knock() from [F] at the captor,
## stop_walker() from [F] at her, and keeps its controls off while busy().

const Rescue := preload("res://scripts/hub/rescue.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")
const RescueSites := preload("res://scripts/hub/rescue_sites.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const ShepherdModel := preload("res://scripts/hub/shepherd_model.gd")
const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const Townsfolk := preload("res://scripts/hub/townsfolk.gd")
const RescueLooks := preload("res://scripts/hub/rescue_looks.gd")
const CutterModel := preload("res://scripts/hub/cutter_model.gd")
const EcoRest := preload("res://scripts/ps2/eco_rest.gd")
const Family := preload("res://scripts/hub/family.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")

enum Step { IDLE, ALERT, RUNNING, SAVED, LATE, STOP }

const SPOT := "rescue_captor"
const RED := Color(1.0, 0.25, 0.2)
## Biggie's run in: slowing to a stop by A_RUN_IN, saying it at A_TALK, off
## again at A_END while the view eases back to hers over A_HOME.
const A_RUN_IN := 2.0
const A_TALK := 2.1
const A_END := 6.4
const A_HOME := 1.0
## In time: she runs at him (CHARGE_SPEED) till she's within HIT_RANGE; then,
## from the hit, his line (S_KNOCK), them up and over to her (S_FREE), and
## S_HOLD after they meet, black.
const CHARGE_SPEED := 7.0
const HIT_RANGE := 0.9
const S_KNOCK := 0.8
const S_FREE := 1.7
const S_HOLD := 2.6
## Too late: down to black (L_SET) and up on them (L_FADE); the captor walks in
## (L_WALK), reaches (L_REACH), puts it in them (L_IN: the drug to her lips, the
## needle to her eye, the piece on her), steps back (L_AFTER), then what comes
## after (L_SECOND), black (L_DARK), and the game again (L_END).
const L_SET := 0.45
const L_FADE := 0.55
const L_WALK := 0.7
const L_REACH := 2.1
const L_CLOSE := 2.8
const L_IN := 4.3
const L_AFTER := 5.5
const L_SECOND := 8.6
const L_DARK := 12.0
const L_END := 12.8
## Back up out of black into the game.
const FADE_UP := 0.7

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
var _hit_dir := Vector3.FORWARD
var _hit_t := -1.0
var _fall_from := Vector3.ZERO
var _fall_yaw := 0.0
var _meet_t := -1.0
var _shaders := {}
var _biggie_ap: AnimationPlayer
var _biggie_exit := 0.0
var _victim_anim_speed := 1.0
var _fade_up := -1.0
var _home := 0.0
## The camera: where it's easing from and to (a point it's at and a point it
## looks at), over how long; or following a Callable([from, at]) live.
var _cam_from_pos := Vector3.ZERO
var _cam_from_at := Vector3.ZERO
var _fov_from := 60.0
var _to_pos := Vector3.ZERO
var _to_at := Vector3.ZERO
var _fov_to := 60.0
var _glide := 0.0
var _glide_t := 0.0
var _aim := Callable()
var _jolt := 0.0
var _defer_body := false
## Hard cuts while it could be seen (the motion test wants none).
var cuts := 0
## People and captors moving: {node, from, to, t0, t1, face, keep} on _mt's clock.
var _moves: Array = []
var _mt := 0.0


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
	_q_ui = Control.new()
	_q_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_q_ui.draw.connect(_draw_qte)
	_q_ui.visible = false
	_layer.add_child(_q_ui)
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
	if step == Step.STOP:
		_stop_over()
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
	_begin_cam()
	_hold(true)
	# Biggie, at a jog, from up ahead of her and a little to the side
	var p: Node3D = rm.player
	var fwd := _flat(-p.global_basis.z)
	var side := fwd.cross(Vector3.UP)
	var from := p.global_position + fwd * 9.0 + side * 1.2
	var to := p.global_position + fwd * 1.7 + side * 0.15
	_end_biggie()
	_biggie = _npc("biggie", from, 0.0)
	var d := _flat(to - from)
	_biggie.rotation.y = atan2(-d.x, -d.z)
	_borrow_walk(_biggie)
	_biggie_ap = _biggie.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_moves.clear()
	_move(_biggie, from, to, 0.0, A_RUN_IN, "", 2.4)
	# over her shoulder, the street ahead: the view eases there out of her own
	_look(p.global_position + Vector3(0, 1.65, 0) - fwd * 1.2 + side * 0.55, p.global_position + fwd * 4.0 + Vector3(0, 1.25, 0), 46.0, 1.0)
	rm.hud.toast("Running feet. Somebody's shouting her name.", 1.6)
	SFX.play(self, "step_concrete_2", -2.0, 1.3)
	return true


## [F] at the captor while there's time: she runs at him and down he goes.
func knock() -> void:
	if step != Step.RUNNING:
		return
	step = Step.SAVED
	t = 0.0
	_said.clear()
	_remove_spot()
	_clock.visible = false
	_begin_cam()
	_hold(true)
	_hit_t = -1.0
	_moves.clear()
	var p: Node3D = rm.player
	var at: Vector3 = _site["captor"]
	var dir := _flat(at - p.global_position)
	_hit_from = p.global_position
	_hit_dir = dir
	# from the side of the line she runs along, whichever side has room, the
	# camera easing out to it and keeping the two of them in as she closes
	var span := Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length()
	var side := dir.cross(Vector3.UP) * (2.0 + span * 0.5)
	var mid0 := (p.global_position + at) * 0.5 + Vector3(0, 1.0, 0)
	if not _clear(mid0 + side + Vector3(0, 0.35, 0), mid0) and _clear(mid0 - side + Vector3(0, 0.35, 0), mid0):
		side = -side
	var c: Node3D = _captor
	_follow(func():
		var a: Vector3 = rm.player.global_position
		var b: Vector3 = c.global_position if is_instance_valid(c) else at
		var mid: Vector3 = (a + b) * 0.5
		return [mid + side + Vector3(0, 1.35, 0), mid + Vector3(0, 0.95, 0)], 48.0, 1.3)
	# she goes, flat out
	p.set("trance_speed", CHARGE_SPEED)
	p.set("trance_dir", dir)


## Too late: what happened.
func play_late() -> void:
	step = Step.LATE
	t = 0.0
	_said.clear()
	_remove_spot()
	_clock.visible = false
	_begin_cam()
	_hold(true)
	_moves.clear()
	piece = ""
	if captor == "colony":
		piece = _next_piece()
		ColonyGear.apply(_victim, HubGrip.gear_of(who) + ([piece] if piece != "" else []))
		if piece != "":
			ColonyGear.fit_model(_victim, piece, 0.0)
	_victim.mood(["sad"])
	SFX.play(self, "heartbeat", -8.0, 0.8)
	# somewhere else: down to black first (L_SET), and up again on them there


func _process(delta: float) -> void:
	_aftermath(delta)
	Townsfolk.hush = busy()  # nobody talks over a scene
	if not busy() and _key != null and _key_level > 0.0:
		_key_light(_key.global_position - Vector3(0, 0.7, 0) + Vector3(0, 0, 0.01), _key.global_position - Vector3(0, 0.7, 0), delta)
	if step == Step.RUNNING:
		_clock.text = "%s: %s   %d:%02d" % [Rescue.NAMES[who].to_upper(), Rescue.PLACES[captor], int(left) / 60, int(left) % 60]
		_clock.add_theme_color_override("font_color", RED if left < 20.0 and fmod(left, 1.0) > 0.5 else Color(1.0, 0.85, 0.8))
		_clock.modulate.a = minf(_clock.modulate.a + delta * 2.0, 1.0)  # fading in, not popping
		_marker.queue_redraw()
	if _victim != null and is_instance_valid(_victim):
		if _victim_anim != null:
			_victim_anim.advance(delta * _victim_anim_speed)
		if _victim_rest != null:
			_victim_rest.step(delta, _victim_pose)
	_biggie_tick(delta)
	if _fade_up >= 0.0:  # back to the game, up out of black
		_fade_up += delta
		_veil.color.a = maxf(0.0, 1.0 - _smoother(_fade_up / FADE_UP))
		if _fade_up >= FADE_UP:
			_fade_up = -1.0
			_veil.color.a = 0.0
	if t < 0.0:
		return
	t += delta
	_moves_tick(delta)
	_cam_tick(delta)
	if _home > 0.0:  # gliding back to her own view
		_home -= delta
		if _home <= 0.0:
			_home_done()
		return
	match step:
		Step.ALERT:
			_alert_tick(delta)
		Step.SAVED:
			_saved_tick(delta)
		Step.LATE:
			_late_tick(delta)
		Step.STOP:
			_stop_tick(delta)


func _alert_tick(delta: float) -> void:
	var p: Node3D = rm.player
	if is_instance_valid(_biggie):
		# he slows to a stop in front of her; his stride slows with him
		var speed: float = _biggie.get_meta("speed", 0.0)
		if _biggie_ap != null:
			_biggie_ap.speed_scale = clampf(speed / 1.25, 0.0, 2.2)
		if t >= A_RUN_IN and not _said.has("stopped"):
			_said["stopped"] = true
			if _biggie_ap != null and _biggie_ap.has_animation("talk"):
				_biggie_ap.speed_scale = 1.0
				_biggie_ap.play("talk", 0.35)
			_biggie.mood(["sad"])
		# she turns to him
		var to_him := _flat(_biggie.global_position - p.global_position)
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-to_him.x, -to_him.z), 1.0 - exp(-4.0 * delta))
	if t >= A_TALK and not _said.has("alert"):
		_said["alert"] = true
		rm.hud.toast(Rescue.ALERT[captor] % ("your mom" if who == "mom" else "Ophelia"), 4.0)
		if is_instance_valid(_biggie):  # round onto him, over her shoulder
			_follow(func():
				var b: Node3D = _biggie if is_instance_valid(_biggie) else rm.player
				var h: Vector3 = b.head_position() if b.has_method("head_position") else b.global_position + Vector3(0, 1.6, 0)
				var back := _flat(rm.player.global_position - b.global_position)
				return [h + back * 1.5 + back.cross(Vector3.UP) * 0.45 + Vector3(0, 0.08, 0), h - Vector3(0, 0.12, 0)], 38.0, 1.2)
	if t >= A_END and not _said.has("off"):
		_said["off"] = true
		if is_instance_valid(_biggie):  # off again the way he came, at a run
			var away := _flat(_biggie.global_position - p.global_position)
			_move(_biggie, _biggie.global_position, _biggie.global_position + away * 9.0 + away.cross(Vector3.UP) * 1.5, t + 0.35, t + 4.2, "", 2.6, true)
			if _biggie_ap != null:
				_biggie_ap.play("rescue/walk", 0.3)
		_glide_home(A_HOME)


## Biggie, after the scene: still running off; gone once he's well away.
func _biggie_tick(delta: float) -> void:
	if not is_instance_valid(_biggie):
		return
	if t < 0.0:
		_moves_tick(delta)  # he finishes his run out of sight
		var speed: float = _biggie.get_meta("speed", 0.0)
		if _biggie_ap != null:
			_biggie_ap.speed_scale = clampf(speed / 1.25, 0.0, 2.2)
		_biggie_exit += delta
		if _biggie_exit > 4.5:
			_end_biggie()


func _end_biggie() -> void:
	if is_instance_valid(_biggie):
		_biggie.queue_free()
	_biggie = null
	_biggie_ap = null
	_biggie_exit = 0.0


## Biggie's said it: the place is set, the clock's running, she's hers again.
func _go() -> void:
	_build_site()
	left = Rescue.time()
	step = Step.RUNNING
	_clock.modulate.a = 0.0
	_clock.visible = true


func _saved_tick(delta: float) -> void:
	var p: Node3D = rm.player
	if _hit_t < 0.0:
		# the captor sees her coming and turns to her
		if is_instance_valid(_captor) and t > 0.15:
			var to_her := _flat(p.global_position - _captor.global_position)
			_captor.rotation.y = lerp_angle(_captor.rotation.y, atan2(-to_her.x, -to_her.z), 1.0 - exp(-7.0 * delta))
		var gap := Vector2(_captor.global_position.x - p.global_position.x, _captor.global_position.z - p.global_position.z).length() if is_instance_valid(_captor) else 0.0
		if gap < HIT_RANGE or t > 3.0:
			_hit_t = t
			p.set("trance_speed", 0.0)
			p.set("trance_dir", Vector3.ZERO)
			_veil.color = Color(1, 1, 1, 0.45)
			_jolt = 1.0
			SFX.play(self, "hit_body", 0.0, 0.8)
			if is_instance_valid(_captor):
				_fall_from = _captor.position
				_fall_yaw = _captor.rotation.y
		return
	var h := t - _hit_t
	if h < 0.35:  # the flash of the hit, easing off
		_veil.color.a = 0.45 * (1.0 - _smoother(h / 0.35))
	elif not _said.has("results"):
		_veil.color.a = 0.0
	if is_instance_valid(_captor):
		var k := clampf(h / 0.6, 0.0, 1.0)
		if captor == "marrow":  # he comes apart into smoke and pools, wavering as he goes
			var s := _smoother(clampf(h / 0.9, 0.0, 1.0))
			_captor.scale = Vector3(1.0 + s * 0.7, maxf(1.0 - s, 0.03) * (1.0 + 0.06 * sin(h * 20.0) * (1.0 - s)), 1.0 + s * 0.7)
		else:  # over backwards: slow to start, falling faster, a little bounce where he lands
			var ang := k * k * PI * 0.5
			if h > 0.6:
				ang += -0.07 * sin((h - 0.6) * 16.0) * exp(-(h - 0.6) * 7.0)
			_captor.rotation = Vector3(ang, _fall_yaw, 0)
			_captor.position = _fall_from + _hit_dir * 0.35 * _smoother(clampf(h / 0.7, 0.0, 1.0))
	if h >= S_KNOCK and not _said.has("knock"):
		_said["knock"] = true
		rm.hud.toast(KNOCK[captor], 3.5)
	if h >= S_FREE and not _said.has("free"):
		_said["free"] = true
		_victim_pose = ""  # up out of the seat (the pose eases off)
		_victim.mood(["smile"])
		# then over to Eco: out of the van first, if that's where she is
		var meet := p.global_position + _flat(_victim.global_position - p.global_position) * 0.75
		var path: Array = [_victim.global_position]
		if _site.has("out"):
			path.append(_site["out"])
		path.append(meet)
		var at := S_FREE + 0.7
		for i in path.size() - 1:
			var a: Vector3 = path[i]
			var b: Vector3 = path[i + 1]
			var dur := maxf(Vector2(b.x - a.x, b.z - a.z).length() / 1.1, 0.5)
			_move(_victim, a, b, _hit_t + at, _hit_t + at + dur, "eco" if i == path.size() - 2 else "", 1.1)
			at += dur
		_meet_t = _hit_t + at
		_borrow_walk(_victim)
		if _victim_anim != null:
			_victim_anim.play("idle", 0.5)  # stood, till she walks
		# the camera eases round onto the two of them, keeping them both in
		_follow(func():
			var v: Node3D = _victim if is_instance_valid(_victim) else rm.player
			var me: Vector3 = rm.player.global_position
			var mid: Vector3 = (me + v.global_position) * 0.5
			var across: Vector3 = _flat(v.global_position - me)
			var gap2: float = Vector2(v.global_position.x - me.x, v.global_position.z - me.z).length()
			var side: Vector3 = across.cross(Vector3.UP) * (1.6 + gap2 * 0.55)
			if _site.has("out") and side.x < 0.0:  # from the street, never from inside the van
				side = -side
			return [mid + side + Vector3(0, 1.45, 0), mid + Vector3(0, 1.15, 0)], 42.0, 1.4)
	if _said.has("free") and is_instance_valid(_victim):
		var walking: bool = _victim.get_meta("speed", 0.0) > 0.05
		if walking and not _said.has("walk"):
			_said["walk"] = true
			if _victim_anim != null and _victim_anim.has_animation("rescue/walk"):
				_victim_anim.play("rescue/walk", 0.3)
		elif not walking and _said.has("walk") and not _said.has("stood"):
			_said["stood"] = true
			if _victim_anim != null:
				_victim_anim.play("idle", 0.4)
		# Eco turns to her as she comes
		var to_them := _flat(_victim.global_position - p.global_position)
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-to_them.x, -to_them.z), 1.0 - exp(-4.0 * delta))
	if _meet_t > 0.0 and t >= _meet_t and not _said.has("met"):
		_said["met"] = true
		rm.hud.toast(FREED[who], 3.4)
		SFX.play(self, "heartbeat", -10.0, 1.0)
	if _meet_t > 0.0 and t >= _meet_t + S_HOLD:
		var k2 := clampf((t - _meet_t - S_HOLD) / 0.6, 0.0, 1.0)
		_veil.color = Color(0, 0, 0, _smoother(k2))
		if not _said.has("results"):
			_said["results"] = true
			_saved_results()
		if k2 >= 1.0 and t >= _meet_t + S_HOLD + 1.0:
			_finish()


func _late_tick(delta: float) -> void:
	# down to black, the place set while it's dark, and up on them there
	if t < L_SET:
		_veil.color = Color(0, 0, 0, _smoother(t / L_SET))
		return
	if not _said.has("set"):
		_said["set"] = true
		rm.player.visible = false  # she isn't there: this is what she missed
		_late_set()
		rm.hud.toast(_apply_line(), 3.6)
	if t < L_SET + L_FADE:
		_veil.color = Color(0, 0, 0, 1.0 - _smoother((t - L_SET) / L_FADE))
	elif not _said.has("in"):
		_veil.color.a = 0.0
	_apply_tick(delta)
	if captor == "colony" and piece != "" and _victim != null:
		ColonyGear.fit_model(_victim, piece, _smoother(clampf((t - L_REACH) / (L_IN - L_REACH), 0.0, 1.0)))
	if captor == "cutter" and _victim != null and t >= L_IN:
		_shake(_victim, 1.0)
	if t >= L_AFTER and not _said.has("after"):
		_said["after"] = true
		_drop_prop()
		_step_back()
		_victim.mood(["plain"] if captor == "colony" else (["smile"] if captor == "marrow" else ["sad"]))  # eyes open: what's in them shows
		_victim.set("look_target", null)
		var v := _victim
		_follow(func(): return [_site["cam"], v.head_position() + Vector3(0, -0.25, 0)], 40.0, 1.5)
		rm.hud.toast(_late_line(0), 3.6)
	if t >= L_SECOND - 0.45 and captor == "marrow" and not _said.has("dip"):
		_said["dip"] = true  # home's somewhere else: through black
	if _said.has("dip") and not _said.has("second"):
		_veil.color = Color(0, 0, 0, _smoother(clampf((t - (L_SECOND - 0.45)) / 0.45, 0.0, 1.0)))
	if t >= L_SECOND and not _said.has("second"):
		_said["second"] = true
		rm.hud.toast(_late_line(1), 3.8)
		if captor == "marrow":  # home: the real them, back at their spot
			_show_real(true)
			var real: Node3D = rm.hub_npcs.get(who)
			if real != null:
				real.mood(["closed", "smile"])
				var face := _flat(-real.global_basis.z)
				_look(real.head_position() + face * 1.6 + Vector3(0, 0.05, 0), real.head_position() - Vector3(0, 0.08, 0), 34.0)
				_look(real.head_position() + face * 1.3 + Vector3(0, 0.04, 0), real.head_position() - Vector3(0, 0.08, 0), 32.0, 3.0)  # a slow push in
		elif captor == "colony":
			_victim.mood(["smile"])
			var v2 := _victim
			_follow(func(): return [v2.head_position() + _flat(-v2.global_basis.z) * 1.1 + Vector3(0, 0.05, 0), v2.head_position() - Vector3(0, 0.06, 0)], 32.0, 1.6)
		else:
			_turn_to(_captor, _captor.global_position + Vector3(-3, 0, 0.6), 0.7)  # he turns to the road, grinning
			var c := _captor
			_follow(func(): return [c.global_position + Vector3(-1.7, 1.5, 0.6), c.global_position + Vector3(0, 1.35, 0.15)], 40.0, 1.3)
			SFX.play(self, "impact", -10.0, 0.6)
	if _said.has("dip") and t >= L_SECOND and t < L_SECOND + 0.5:
		_veil.color.a = 1.0 - _smoother((t - L_SECOND) / 0.5)
	if t >= L_DARK:
		_veil.color = Color(0, 0, 0, _smoother(clampf((t - L_DARK) / 0.6, 0.0, 1.0)))
		if not _said.has("results"):
			_said["results"] = true
			_late_results()
	if t >= L_END:
		_finish()


## Too late, as it happens: the captor stands back from them, then comes in
## close, facing them, with what they're putting in or on them in his hand.
var _prop: Node3D
var _prop_from := Vector3.ZERO
var _rod: MeshInstance3D
var _look_point: Node3D


func _late_set() -> void:
	var seat: Vector3 = _site["seat"]
	var at := _apply_spot()
	var back := _back_spot()
	if is_instance_valid(_captor):
		_captor.scale = Vector3.ONE
		_captor.position = back
		var d0 := _flat(_victim.global_position - back)
		_captor.rotation = Vector3(0, atan2(-d0.x, -d0.z), 0)
		_move(_captor, back, at, L_WALK, L_WALK + 1.2, "victim", 1.3)
		# where her eyes go: his face, then what's in his hand
		_look_point = Node3D.new()
		_captor.add_child(_look_point)
		_look_point.position = Vector3(0, 1.6, 0)
		_victim.set("look_target", _look_point)
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
			_rod.visible = false
			_set.add_child(_rod)
	if _prop != null:
		_set.add_child(_prop)
		_prop.visible = false  # in his hand once he's there
	# the two of them, from the side: set while it's dark, then a slow push in
	var mid: Vector3 = (_prop_from + _victim.head_position()) * 0.5
	var side := toward.cross(Vector3.UP)
	if captor == "colony":
		side = Vector3(1, 0, 0.6).normalized() * 2.4  # from the street, in through the door
	elif captor == "cutter":
		side = Vector3(0, 0, 1)  # from the open side of the tarp
	_look(mid + side * 1.75 + Vector3(0, 0.2, 0), mid - Vector3(0, 0.1, 0), 42.0)
	_look(mid + side * 1.45 + Vector3(0, 0.15, 0), mid - Vector3(0, 0.1, 0), 40.0, L_IN - L_SET)


## Where the captor stands to do it, and where he stands back to before and after.
func _apply_spot() -> Vector3:
	var seat: Vector3 = _site["seat"]
	match captor:
		"marrow":
			return seat + Vector3(0.42, 0, -0.55)
		"colony":
			return seat + Vector3(0.85, 0, 0)
	return seat + Vector3(-0.7, 0, 0)


func _back_spot() -> Vector3:
	var seat: Vector3 = _site["seat"]
	match captor:
		"marrow":
			return seat + Vector3(0.35, 0, 0.55)  # behind her chair, a hand on it
		"colony":
			return seat + Vector3(1.6, -RescueSites.VAN_FLOOR, -1.1)  # out of the van
	return seat + Vector3(-0.85, 0, -0.85)  # off to the side


## Where on them it's going: her lips (Marrow), her eye (Cutter).
func _apply_target() -> Vector3:
	var fwd := _flat(-_victim.global_basis.z)
	var right := fwd.cross(Vector3.UP)
	if captor == "cutter":
		return _victim.head_position() + Vector3(0, 0.02, 0) + fwd * 0.075 + right * 0.032
	return _victim.head_position() - Vector3(0, 0.045, 0) + fwd * 0.08


## His hand, now (where he stands, at chest height, toward her).
func _hand() -> Vector3:
	if not is_instance_valid(_captor):
		return _prop_from
	var toward := _flat(_victim.global_position - _captor.global_position)
	return _captor.global_position + Vector3(0, 1.2, 0) + toward * 0.32


func _apply_tick(_delta: float) -> void:
	# up from his hand in an arc, slow at the start, slower still as it gets to her
	var u := clampf((t - L_REACH) / (L_IN - L_REACH), 0.0, 1.0)
	var k := _smoother(u)
	k = lerpf(k, 1.0 - pow(1.0 - u, 3.0), 0.35)  # a touch of hesitation before it lands
	if _prop != null and is_instance_valid(_prop):
		_prop.visible = t >= L_REACH - 0.25
		var from := _hand()
		var to := _apply_target()
		var stop := to + (from - to).normalized() * 0.03
		var lift := (from + stop) * 0.5 + Vector3(0, 0.12, 0)
		_prop.global_position = from.lerp(lift, k).lerp(lift.lerp(stop, k), k)  # a quadratic arc
		if captor == "cutter" and _prop.global_position.distance_to(to) > 0.01:
			_prop.look_at(to, Vector3.UP)
		if t >= L_REACH - 0.25 and _look_point != null and _look_point.get_parent() != _prop:
			_look_point.reparent(_prop, false)  # her eyes go to it
			_look_point.position = Vector3.ZERO
	if _rod != null and is_instance_valid(_rod) and piece != "":
		_rod.visible = t >= L_REACH - 0.2
		var node := ColonyGear.piece_node(_victim, piece)
		var a := _hand()
		var b: Vector3 = node.global_position if node != null else _victim.head_position()
		b = a.lerp(b, _smoother(clampf((t - (L_REACH - 0.2)) / 0.6, 0.0, 1.0)))  # reaching out to it
		var dir := b - a
		if dir.length() > 0.01:
			_rod.global_position = (a + b) * 0.5
			_rod.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
	if captor == "cutter" and t >= L_CLOSE and not _said.has("close"):
		_said["close"] = true  # easing in close on her eye as it comes
		var v := _victim
		_follow(func():
			var fwd := _flat(-v.global_basis.z)
			var eye := _apply_target() - fwd * 0.075
			return [eye + fwd * 0.4 + Vector3(0, 0, 0.22) - Vector3(0, 0.02, 0), eye], 22.0, L_IN - L_CLOSE - 0.1)
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
		_veil.color.a = 0.85 * (1.0 - _smoother(clampf((t - L_IN) / 0.9, 0.0, 1.0)))


## Done: the captor steps back out of the way, walking it.
func _step_back() -> void:
	if not is_instance_valid(_captor):
		return
	_move(_captor, _captor.position, _back_spot(), t + 0.1, t + 1.3, "victim", 1.2)

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
	if _veil.color.a > 0.5:  # it ends in black: up again into the game, not a snap
		_veil.color = Color(0, 0, 0, 1)
		_fade_up = 0.0
	else:
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


func _bond(by: int, p_who := "") -> void:
	var state: ConfigFile = rm.npc_talk.state
	var w := p_who if p_who != "" else who
	if w == "mom":
		Family.add(state, "mom", by)
	else:
		Romance.add(state, w, by)
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


## A model in a holder that can fall over at its feet, on the threats' biped
## puppet (threat_model.gd) so its legs walk when it moves.
func _holder(model: Node3D) -> Node3D:
	var h := Node3D.new()
	var puppet := Node3D.new()
	puppet.name = "Puppet"
	puppet.set_script(ThreatModel)
	puppet.gait = "biped"
	puppet.stride_len = 1.6
	puppet.swing = 24.0
	puppet.cycle_speed = 0.0
	puppet.add_child(model)
	h.add_child(puppet)
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
	p.set("trance_speed", 0.0)
	var view: Node = p.get_node_or_null("ViewCam")
	if view != null and not (on and _defer_body):
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


# --- the camera: it eases, it doesn't cut -------------------------------------

## The scene's camera, put exactly where her view is now, so the first move
## starts from what she was seeing (call before _hold(true) turns her view).
func _begin_cam() -> void:
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
	var now := get_viewport().get_camera_3d()
	if now != null and now != _cam:
		_cam.global_transform = now.global_transform
		_cam.fov = now.fov
		# from her own eyes: her body only shows once the camera's clear of her
		# head (_cam_tick turns her view third person then)
		var p: Node3D = rm.player
		_defer_body = _cam.global_position.distance_to(p.global_position + Vector3(0, 1.5, 0)) < 0.6
	_cam_from_pos = _cam.global_position
	_cam_from_at = _cam.global_position - _cam.global_basis.z * 4.0
	_to_pos = _cam_from_pos
	_to_at = _cam_from_at
	_fov_from = _cam.fov
	_fov_to = _cam.fov
	_aim = Callable()
	_glide = 0.0
	_cam.make_current()


## The camera to `from`, looking at `at`: eased there over `glide` s (0: a cut,
## which the scenes only make where it's dark).
func _look(from: Vector3, at: Vector3, fov: float, glide := 0.0) -> void:
	_aim = Callable()
	_aim_to(from, at, fov, glide)


## The camera following `aim` (a Callable returning [from, at]) as it moves,
## eased onto it over `glide` s.
func _follow(aim: Callable, fov: float, glide: float) -> void:
	var r: Array = aim.call()
	_aim = aim
	_aim_to(r[0], r[1], fov, glide)


func _aim_to(from: Vector3, at: Vector3, fov: float, glide: float) -> void:
	if _cam == null:
		_begin_cam()
	_cam_from_pos = _cam.global_position
	_cam_from_at = _cam.global_position - _cam.global_basis.z * maxf(_cam.global_position.distance_to(at), 0.5)
	_fov_from = _cam.fov
	_to_pos = from
	_to_at = at
	_fov_to = fov
	_glide = glide
	_glide_t = 0.0
	if glide <= 0.0:
		if _veil.color.a < 0.9 and t >= 0.0 and _cam.current:
			cuts += 1
		_cam.fov = fov
		_cam.look_at_from_position(from, at)
	_cam.make_current()


func _cam_tick(delta: float) -> void:
	if _cam == null:
		return
	var to_pos := _to_pos
	var to_at := _to_at
	if _aim.is_valid():
		var r: Array = _aim.call()
		to_pos = r[0]
		to_at = r[1]
	var pos := to_pos
	var at := to_at
	var fov := _fov_to
	if _glide > 0.0:
		_glide_t += delta
		var k := _smoother(clampf(_glide_t / _glide, 0.0, 1.0))
		pos = _cam_from_pos.lerp(to_pos, k)
		at = _cam_from_at.lerp(to_at, k)
		fov = lerpf(_fov_from, _fov_to, k)
		if _glide_t >= _glide:
			_glide = 0.0
	# held by hand: a slow drift, and a jolt when something hits
	var tt := _mt
	var basis := Basis.looking_at(at - pos, Vector3.UP) if (at - pos).length() > 0.001 else _cam.global_basis
	pos += basis * Vector3(sin(tt * 0.71) * 0.006, sin(tt * 0.53 + 1.3) * 0.005, 0.0)
	if _jolt > 0.0:
		var j := _smoother(_jolt)  # in hard, settling soft: a knock, not a snap
		pos += basis * Vector3(sin(tt * 23.0), sin(tt * 19.0 + 0.7), 0.0) * 0.014 * j
		_jolt = maxf(_jolt - delta * 2.2, 0.0)
	_cam.global_transform = Transform3D(Basis.looking_at(at - pos, Vector3.UP) if (at - pos).length() > 0.001 else basis, pos)
	_cam.fov = fov
	if not _cam.current:
		_cam.make_current()
	_key_light(pos, at, delta)
	if _defer_body and (_cam.global_position.distance_to(rm.player.global_position + Vector3(0, 1.5, 0)) > 0.7 or t > 1.5):
		_defer_body = false  # clear of her head: her body can show now
		var view: Node = rm.player.get_node_or_null("ViewCam")
		if view != null:
			view.set_third_person(true)


## A soft key light on whoever the camera's on (the town's dark under its
## canopy, and its shop fronts bright behind them): from the camera's side,
## above, easing up while a scene plays and away after.
var _key: OmniLight3D
var _key_level := 0.0


func _key_light(pos: Vector3, at: Vector3, delta: float) -> void:
	if _key == null:
		_key = OmniLight3D.new()
		_key.light_color = Color(1.0, 0.93, 0.86)
		_key.omni_range = 4.5
		_key.shadow_enabled = false
		add_child(_key)
	var want := 1.0 if busy() and _home <= 0.0 else 0.0
	_key_level = move_toward(_key_level, want, delta * 1.5)
	_key.light_energy = 0.9 * _smoother(_key_level)
	_key.visible = _key_level > 0.0
	var toward := (pos - at)
	toward.y = 0.0
	_key.global_position = at + (toward.normalized() * 1.3 if toward.length() > 0.01 else Vector3.ZERO) + Vector3(0, 0.7, 0)


## Easing back to her own view over `dur` s; the scene's over when it gets there.
func _glide_home(dur: float) -> void:
	var p: Node = rm.player
	var view: Node = p.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(ViewCamera.prefer_third_person)
	var pc: Camera3D = p.get("camera")
	if pc == null:
		_home = 0.01
		return
	_follow(func(): return [pc.global_position, pc.global_position - pc.global_basis.z * 4.0], pc.fov, dur)
	_home = dur


func _home_done() -> void:
	_home = 0.0
	t = -1.0
	_hold(false)
	if step == Step.ALERT:
		_go()
	elif step == Step.STOP:
		_stop_over()


## Nothing solid between `a` and `b` (a camera's view of what it's on).
func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [rm.player.get_rid()]
	return rm.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Smootherstep: eases in and out with no jolt at either end.
static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


# --- people moving -----------------------------------------------------------

## `node` walks from `from` to `to` between scene times t0 and t1 (eased in and
## out, its legs going with its speed), facing where it goes and then `face`
## ("victim", "eco", or "" for where it went). `speed` is its walking pace, for
## its stride; `keep` lets it finish after the scene's over.
func _move(node: Node3D, from: Vector3, to: Vector3, t0: float, t1: float, face := "", speed := 1.2, keep := false) -> void:
	var now := maxf(t, 0.0)
	_moves = _moves.filter(func(m): return m["node"] != node)
	_moves.append({"node": node, "from": from, "to": to, "t0": _mt + (t0 - now), "t1": _mt + (t1 - now), "face": face, "speed": speed, "keep": keep, "last": from})


## `node` turns to face `point` over `dur` s, where it stands.
func _turn_to(node: Node3D, point: Vector3, dur: float) -> void:
	if not is_instance_valid(node):
		return
	_moves.append({"node": node, "from": node.global_position, "to": node.global_position, "t0": _mt, "t1": _mt + dur, "face": point, "speed": 0.0, "keep": false, "last": node.global_position})


func _moves_tick(delta: float) -> void:
	_mt += delta
	var left: Array = []
	for m in _moves:
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			continue
		if _mt < m["t0"]:
			left.append(m)
			continue
		var span: float = maxf(m["t1"] - m["t0"], 0.001)
		var k := _smoother((_mt - m["t0"]) / span)
		var pos: Vector3 = (m["from"] as Vector3).lerp(m["to"], k)
		var step_ := pos - (m["last"] as Vector3)
		step_.y = 0.0
		var speed := step_.length() / maxf(delta, 0.0001)
		m["last"] = pos
		node.global_position = pos
		node.set_meta("speed", speed)
		var puppet := node.get_node_or_null("Puppet")
		if puppet != null:
			puppet.set("cycle_speed", speed)
		# facing: where it's going while it goes, then what it's turning to
		var want := INF
		if speed > 0.15 and step_.length() > 0.0001:
			want = atan2(-step_.x, -step_.z)
		else:
			var face = m["face"]
			var point := Vector3.INF
			if face is Vector3:
				point = face
			elif face == "victim" and is_instance_valid(_victim):
				point = _victim.global_position
			elif face == "eco":
				point = rm.player.global_position
			if point != Vector3.INF:
				var d := _flat(point - node.global_position)
				want = atan2(-d.x, -d.z)
		if want != INF:
			node.rotation.y = lerp_angle(node.rotation.y, want, 1.0 - exp(-8.0 * delta))
		if _mt < m["t1"] + 0.8:
			left.append(m)
		else:
			node.set_meta("speed", 0.0)
			if puppet != null:
				puppet.set("cycle_speed", 0.0)
	_moves = left


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


## She's off to them: gone from home, and walking through Solace (from
## `from` first, if it's given: the cheat box's, by Eco).
func _start_walk(from := Vector3.INF) -> void:
	_drawn_at = -1.0
	if _drawn_who == "" or not rm.hub_npcs.has(_drawn_who):
		return
	_walk_route = ROUTES[_drawn_captor]
	if from != Vector3.INF:
		_walk_route = [from] + _walk_route
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
	_stop_done = false
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
	_stop_spot(true)
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
	_stop_spot(false)


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
	_stop_spot(false)
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


# --- stopping her on her way back to them ---------------------------------------

## [F] at her as she walks off to them (stop_walker()). Until she's walked
## there Rescue.VISITS times she stops, comes round, and lets Eco walk her home.
## Once she's theirs (rescue_looks.gd) she pulls away: a quick-time event, [F]
## again and again to hold on to her while the bar drains, faster the deeper
## their hold on her. Hold on and she comes home, their hold on her eased. Lose
## her and, there in the street, she gives Eco what they give her: his violet
## to her lips, the colony's next piece on her, Cutter's Redline in her arm.
## Eco isn't held for it: she just never thought it'd come from her. Then she
## walks on to them, and Eco can't make herself follow.
const STOP_SPOT := "rescue_stop"
const STOP_REACH := 2.2
## The pull: she turns, the camera eases round onto the two of them, and at
## Q_START she pulls away and the bar comes up, from Q_FROM. Each [F] is
## Q_PRESS; it drains Q_DRAIN a second, and Q_DRAIN_HOOK more at their full
## hold. Filled in Q_TIME s she's held; empty or out of time, she's gone.
const Q_START := 1.4
const Q_TIME := 4.5
const Q_FROM := 0.3
const Q_PRESS := 0.1
const Q_DRAIN := 0.2
const Q_DRAIN_HOOK := 0.2
## Held: her line, then down to black and home (from the moment she's held).
const H_DARK := 2.8
const H_END := 3.4
## Lost (from the moment she's lost): she steps in, it comes up from her hand
## at G_REACH and is in, or on, at G_IN; she steps back at G_AFTER, walks on at
## G_WALK, and the view eases back to Eco's own over G_HOME.
const G_STEP := 0.9
const G_REACH := 1.5
const G_IN := 3.0
const G_AFTER := 4.3
const G_WALK := 6.0
const G_HOME := 1.4
## The bond with her, held on to.
const BOND_HELD := 5
## Before she's theirs: she comes round.
const TALKED := {
	"mom": "Eco catches Mom's hand. Mom blinks at her like she's waking up. \"Where was I going? Oh, baby. Take me home.\"",
	"ophelia": "Eco steps in front of her. Ophelia stops, blinks, and the colour goes out of her eyes. \"Eco? I don't... Okay. Walk me back.\"",
}
## Once she's theirs: she pulls away.
const PULL := {
	"mom": "Mom pulls her hand out of Eco's. \"Let go, Eco. They're waiting for me.\"",
	"ophelia": "Ophelia twists out of Eco's grip. \"Let me go. You don't get it. Let me go.\"",
}
const HELD := {
	"mom": "Eco doesn't let go. Mom stops pulling all at once and leans on her. \"Okay. Okay. Take me home.\"",
	"ophelia": "Eco holds on. The fight runs out of Ophelia and she puts her forehead on Eco's shoulder. \"Don't let go, then.\"",
}
## Lost: what she does, as she does it ([who][captor]; the colony's: the piece).
const GIVE := {
	"mom": {
		"marrow": "Mom smiles, gentle as she ever was, and there's a vial of violet at Eco's lips before Eco sees it coming. \"Shh. He said you'd need this too. I'm your mother. Trust me.\"",
		"colony": "Mom takes the colony's %s out of her jumpsuit, already warm. \"Hold still, sweetheart. Calm is a kindness.\" It clicks on before Eco can pull back.",
		"cutter": "Mom's hand comes out of the hoodie with a needle of Redline. \"Just a little, baby. You'll see. You'll love it.\" It's in Eco's arm before she can pull away.",
	},
	"ophelia": {
		"marrow": "Ophelia's got a vial of violet out of her coat and at Eco's lips before Eco can stop her. \"Sorry. I'm sorry. You'll feel it, and then you'll get it.\"",
		"colony": "Ophelia has the colony's %s out of her pocket and on Eco before Eco understands what it is. \"It's for your own good. It is. It is.\"",
		"cutter": "Ophelia's got a needle of Redline in her shaking hand. \"Sorry, sorry, you'll thank me.\" It's in Eco's arm before Eco can stop her.",
	},
}
## The colony, when Eco's wearing all of it already: a film on her tongue.
const GIVE_FILM := {
	"mom": "Mom presses a Hymn film to Eco's lips with her thumb, the way she used to give her medicine. \"There. Calm is a kindness.\"",
	"ophelia": "Ophelia slips a Hymn film between Eco's lips. \"Just one. For me. It's for your own good.\"",
}
## After: she walks on (%s: where to).
const WALKS_ON := {
	"mom": "Mom won't look at her. She turns and walks on toward %s, and Eco's legs won't follow.",
	"ophelia": "Ophelia says something that might be sorry, and walks on toward %s. Eco can't make herself follow.",
}
const TOWARD := {"marrow": "the cinema's cellar", "colony": "the colony kiosk", "cutter": "the pilgrim road"}

var _stop_who := ""
## She's given it to Eco this walk: no stopping her again.
var _stop_done := false
var _stop_captor := ""
var _stop_side := Vector3.RIGHT
## The bar (0..1), and how it went: "" while it's on, "held" or "lost", and when.
var qte := 0.0
var qte_result := ""
var _q_at := 0.0
var _q_ui: Control
var _q_flash := 0.0
var _give_piece := ""
var _give_prop: Node3D
var _give_swirl := 0.0


## [F] at her on her way to them, or by Eco in the street (the stop spot moves with her).
func _stop_spot(on: bool) -> void:
	if rm.get("zone_info") == null or not rm.zone_info.has("interactables"):
		return
	var spots: Array = rm.zone_info["interactables"]
	for s in spots:
		if s["id"] == STOP_SPOT:
			if on and _walker != null and is_instance_valid(_walker):
				s["pos"] = _walker.global_position
				return
			rm.zone_info["interactables"] = spots.filter(func(x): return x["id"] != STOP_SPOT)
			return
	if on and _walker != null and is_instance_valid(_walker) and _drawn_who != "" and not _stop_done:
		var K := preload("res://scripts/hub/hub_kit.gd")
		K.interactable(rm.zone_info, STOP_SPOT, _walker.global_position, "[F] Stop %s" % Rescue.NAMES[_drawn_who], [""], STOP_REACH)


## Whether one of them's on her way to them now (so there's someone to stop).
func walking() -> bool:
	return _walker != null and is_instance_valid(_walker)


## The cheat box: `p_who` is theirs, three visits in, and off to them now from
## a few steps ahead of Eco.
func walk_off_now(p_who: String) -> void:
	if step != Step.IDLE or busy():
		return
	_end_walk()
	draw_off(p_who, 0.0)
	if _drawn_captor == "":
		return
	var p: Node3D = rm.player
	var fwd := _flat(-p.global_basis.z)
	_start_walk(p.global_position + fwd * 5.0)


## [F] at her as she walks.
func stop_walker() -> void:
	if not walking() or step != Step.IDLE or busy():
		return
	_stop_who = _drawn_who
	_stop_captor = _drawn_captor
	if Rescue.changed_by(_stop_who) == "":
		rm.hud.toast(TALKED[_stop_who], 4.5)  # not theirs yet: she comes round
		_walk_home()
		return
	step = Step.STOP
	t = 0.0
	_said.clear()
	qte = Q_FROM
	qte_result = ""
	_give_piece = ""
	_give_swirl = 0.0
	_stop_spot(false)
	_begin_cam()
	_hold(true)
	_moves.clear()
	_walker_anim("idle")
	_walker.mood(["sad"])
	_turn_to(_walker, rm.player.global_position, 0.7)
	# from the side of the two of them, whichever side has room
	var a := _eco_point("J_Bip_C_Head", 1.5)
	var d := _flat(_walker.global_position - rm.player.global_position)
	_stop_side = d.cross(Vector3.UP)
	var mid: Vector3 = (a + _walker.head_position()) * 0.5
	if not _clear(mid + _stop_side * 1.9, mid) and _clear(mid - _stop_side * 1.9, mid):
		_stop_side = -_stop_side
	_follow(_two_shot.bind(1.9, 0.12), 40.0, 1.2)


## The two of them, from the side, `out` m off, `up` above their eyes.
func _two_shot(out: float, up: float) -> Array:
	var a := _eco_point("J_Bip_C_Head", 1.5)
	var b: Vector3 = _walker.head_position() if walking() else a
	var mid := (a + b) * 0.5
	return [mid + _stop_side * out + Vector3(0, up, 0), mid - Vector3(0, 0.08, 0)]


func _stop_tick(delta: float) -> void:
	var p: Node3D = rm.player
	if walking():  # Eco turns to her
		var to_her := _flat(_walker.global_position - p.global_position)
		p.rotation.y = lerp_angle(p.rotation.y, atan2(-to_her.x, -to_her.z), 1.0 - exp(-5.0 * delta))
	if t >= Q_START - 0.5 and not _said.has("pull"):
		_said["pull"] = true
		rm.hud.toast(PULL[_stop_who], 3.0)
		SFX.play(self, "step_concrete_2", -6.0, 0.9)
	if qte_result == "":
		_qte_tick(delta)
	elif qte_result == "held":
		_held_tick()
	else:
		_give_tick(delta)
	if _give_swirl > 0.0:
		EcoModel.swirl_override = _give_swirl
		EcoModel.swirl_override_tint = EYE_TINT[_stop_captor]


## The bar: up with each [F], draining, and her pulling against it.
func _qte_tick(delta: float) -> void:
	_tug(delta)
	if t < Q_START:
		return
	_q_ui.visible = true
	_q_flash = maxf(_q_flash - delta * 4.0, 0.0)
	var hold := clampf(Rescue.hook(_stop_who, _stop_captor) / Rescue.MAX, 0.0, 1.0)
	qte -= (Q_DRAIN + Q_DRAIN_HOOK * hold) * delta
	if Input.is_action_just_pressed("interact"):
		qte_press()
	if walking():
		_shake(_walker, 0.25 + 0.35 * (1.0 - qte))  # pulling
	if qte_result == "" and (qte <= 0.0 or t >= Q_START + Q_TIME):
		_qte_lost()
	_q_ui.queue_redraw()


## The pull, in their bodies: Eco steps in and gets hold of her; she leans and
## backs away from Eco as the bar drains and comes in closer as Eco wins.
func _tug(delta: float) -> void:
	if not walking():
		return
	var p: Node3D = rm.player
	var d := _flat(_walker.global_position - p.global_position)
	var gap := Vector2(_walker.global_position.x - p.global_position.x, _walker.global_position.z - p.global_position.z).length()
	# Eco closes to arm's length first
	if t < Q_START and gap > 1.0:
		p.set("trance_speed", 1.6)
		p.set("trance_dir", d)
	else:
		p.set("trance_speed", 0.0)
		p.set("trance_dir", Vector3.ZERO)
	if t < Q_START:
		return
	var pull := clampf(1.0 - qte, 0.0, 1.0)
	var want: Vector3 = p.global_position + d * lerpf(0.8, 1.35, pull)
	want.y = _walker.global_position.y
	_walker.global_position = _walker.global_position.lerp(want, 1.0 - exp(-5.0 * delta))
	var m := _walker.get_node_or_null("Model") as Node3D
	if m != null:  # leaning back away from her, tugging in jerks
		var lean := 0.16 * pull * (0.65 + 0.35 * sin(t * 7.5))
		m.rotation.x = lerpf(m.rotation.x, lean, 1.0 - exp(-10.0 * delta))


## Her model upright again (after the tug).
func _untug() -> void:
	if walking():
		var m := _walker.get_node_or_null("Model") as Node3D
		if m != null:
			var tw := create_tween()
			tw.tween_property(m, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rm.player.set("trance_speed", 0.0)
	rm.player.set("trance_dir", Vector3.ZERO)


## One [F] while the bar's up.
func qte_press() -> void:
	if step != Step.STOP or qte_result != "" or t < Q_START:
		return
	qte = minf(qte + Q_PRESS, 1.0)
	_q_flash = 1.0
	_jolt = maxf(_jolt, 0.25)
	if qte >= 1.0:
		_qte_held()


func _draw_qte() -> void:
	if qte_result != "" or step != Step.STOP:
		return
	var size := _q_ui.size
	var w := minf(size.x * 0.4, 420.0)
	var at := Vector2((size.x - w) * 0.5, size.y * 0.74)
	var font := ThemeDB.fallback_font
	_q_ui.draw_string(font, at + Vector2(0, -14), "HOLD ON TO %s" % Rescue.NAMES[_stop_who].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(1, 0.95, 0.9))
	_q_ui.draw_rect(Rect2(at, Vector2(w, 18)), Color(0, 0, 0, 0.6))
	_q_ui.draw_rect(Rect2(at + Vector2(2, 2), Vector2((w - 4) * clampf(qte, 0.0, 1.0), 14)), Color(1.0, 0.85, 0.8).lerp(Color.WHITE, _q_flash))
	_q_ui.draw_rect(Rect2(at, Vector2(w, 18)), Color(1, 1, 1, 0.85), false, 2.0)
	var pulse := 0.6 + 0.4 * sin(t * 14.0)
	_q_ui.draw_string(font, at + Vector2(0, 46), "[F]  [F]  [F]", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 1, 1, pulse))


## Held on to: she comes round, and home.
func _qte_held() -> void:
	qte_result = "held"
	_untug()
	_q_at = t
	_q_ui.visible = false
	rm.hud.toast(HELD[_stop_who], 4.0)
	if walking():
		_walker.mood(["closed", "smile"])
		var m := _walker.get_node_or_null("Model") as Node3D
		if m != null and _stop_captor != "cutter":  # still (Cutter's Wiring keeps her shaking)
			m.position = Vector3.ZERO
	Rescue.held_on(_stop_who, _stop_captor)
	_bond(BOND_HELD, _stop_who)
	_follow(_two_shot.bind(1.45, 0.08), 36.0, 2.2)  # a slow push in on them


func _held_tick() -> void:
	var h := t - _q_at
	if h >= H_DARK:
		_veil.color = Color(0, 0, 0, _smoother((h - H_DARK) / (H_END - H_DARK)))
	if h >= H_END:
		var name_: String = Rescue.NAMES[_stop_who]
		_walk_home()
		rm.hud.toast("Eco walks %s home.  Bond +%d.  %s's hold on her eases." % [name_, BOND_HELD,
				{"marrow": "Marrow", "colony": "The colony", "cutter": "Cutter"}[_stop_captor]], 5.0)
		_finish()


## Lost her: she steps in close, and gives it to Eco.
func _qte_lost() -> void:
	qte_result = "lost"
	_untug()
	_stop_done = true
	_q_at = t
	_q_ui.visible = false
	if not walking():
		_stop_over()
		return
	var p: Node3D = rm.player
	var d := _flat(p.global_position - _walker.global_position)
	var close := p.global_position - d * 0.6
	_move(_walker, _walker.global_position, close, t, t + G_STEP, "eco", 0.8)
	_walker.mood(["sad"] if _stop_captor == "cutter" else ["smile"])
	if _stop_captor == "colony":
		for g in Hymn.GEAR:
			if not g in Hymn.gear:
				_give_piece = g
				break
	var line: String = GIVE[_stop_who][_stop_captor]
	if _stop_captor == "colony":
		line = line % Hymn.GEAR_NAMES.get(_give_piece, "gear") if _give_piece != "" else GIVE_FILM[_stop_who]
	rm.hud.toast(line, 4.6)
	if _give_piece != "":
		for body in _eco_bodies():
			ColonyGear.apply(body, Hymn.gear + [_give_piece])
			ColonyGear.fit_model(body, _give_piece, 0.0)
	else:
		_give_prop = _needle() if _stop_captor == "cutter" else _take_prop("colony" if _stop_captor == "colony" else "marrow")
		_give_prop.scale = Vector3.ONE * 1.6  # big enough to read in the shot
		rm.zone_root.add_child(_give_prop)
		_give_prop.visible = false
	# over Eco's shoulder onto her face as she steps in and says it
	var w := _walker
	_follow(func():
		var eco_head := _eco_point("J_Bip_C_Head", 1.5)
		var her: Vector3 = w.head_position() if is_instance_valid(w) else eco_head
		var back := _flat(eco_head - her)
		return [eco_head + back * 0.9 + back.cross(Vector3.UP) * 0.5 + Vector3(0, 0.14, 0), her - Vector3(0, 0.05, 0)], 32.0, 1.0)


func _give_tick(_delta: float) -> void:
	var g := t - _q_at
	if g >= G_REACH - 0.35 and not _said.has("tight"):
		_said["tight"] = true  # round to the side, close, as it comes up to Eco
		_follow(_two_shot.bind(1.05, 0.0), 30.0, G_IN - G_REACH + 0.35)
	var u := clampf((g - G_REACH) / (G_IN - G_REACH), 0.0, 1.0)
	var k := _smoother(u)
	if _give_prop != null and is_instance_valid(_give_prop) and walking():
		_give_prop.visible = g >= G_REACH - 0.2 and g < G_AFTER
		var from: Vector3 = _walker.global_position + Vector3(0, 1.15, 0) + _flat(rm.player.global_position - _walker.global_position) * 0.3
		var to := _give_target()
		var stop := to + (from - to).normalized() * 0.03
		var lift := (from + stop) * 0.5 + Vector3(0, 0.1, 0)
		_give_prop.global_position = from.lerp(lift, k).lerp(lift.lerp(stop, k), k)
		if _stop_captor == "cutter" and _give_prop.global_position.distance_to(to) > 0.01:
			_give_prop.look_at(to, Vector3.UP)
	if _give_piece != "":
		for body in _eco_bodies():
			ColonyGear.fit_model(body, _give_piece, k)
	if g >= G_IN and not _said.has("in"):
		_said["in"] = true
		match _stop_captor:
			"marrow":
				SFX.play(self, "heartbeat", -6.0, 0.8)
			"colony":
				SFX.play(self, "cache_unlock", -4.0, 0.7)
			"cutter":
				_veil.color = Color(0.85, 0.05, 0.05, 0.85)  # red, at contact, and nothing more
				SFX.play(self, "heartbeat", 0.0, 1.2)
	if g >= G_IN:  # it's in her eyes too, like theirs
		_give_swirl = 0.85 * _smoother((g - G_IN) / 0.9)
		if _stop_captor == "cutter" and g < G_AFTER:
			_veil.color.a = 0.85 * (1.0 - _smoother((g - G_IN) / 0.9))
	if g >= G_AFTER and not _said.has("after"):
		_said["after"] = true
		if _give_prop != null and is_instance_valid(_give_prop):
			_give_prop.queue_free()
		_give_prop = null
		_give_results()
		rm.hud.toast(WALKS_ON[_stop_who] % TOWARD[_stop_captor], 4.0)
		var d := _flat(_walker.global_position - rm.player.global_position)
		_move(_walker, _walker.global_position, _walker.global_position + d * 0.7, t, t + 1.0, "eco", 0.7)
	if g >= G_WALK and not _said.has("walk"):
		_said["walk"] = true
		_around_eco()
		_walker_anim("rescue/walk")
		_walker.mood(["plain"])
		_glide_home(G_HOME)


## What she gave Eco, now Eco's: Marrow's Hold up, the colony's piece on her
## (or a film's worth of Hymn), a Redline charge and its high.
func _give_results() -> void:
	var got := ""
	match _stop_captor:
		"marrow":
			if Vices.dosed:
				Vices.hold = minf(Vices.hold + Vices.HOLD_PER_DOSE, 100.0)
				Vices.save()
			else:
				Vices._dose(null)
			got = "Marrow's Hold +%d." % int(Vices.HOLD_PER_DOSE)
		"colony":
			if _give_piece != "":
				if not _give_piece in Hymn.gear:
					Hymn.gear.append(_give_piece)
				Hymn.level = minf(Hymn.level + Hymn.DOSE, Hymn.MAX)
				Hymn.save()
				for body in _eco_bodies():
					ColonyGear.apply(body)
				got = "The colony's %s is on her.  Hymn +%d." % [Hymn.GEAR_NAMES.get(_give_piece, _give_piece), int(Hymn.DOSE)]
			else:
				Hymn.take_dose()
				got = "Hymn +%d." % int(Hymn.DOSE)
		"cutter":
			Redline.caught()
			got = "A Redline charge, burning in her. (%d)" % Redline.charges
	rm.hud.toast("%s did that.  %s" % [Rescue.NAMES[_stop_who], got], 5.0)


## Walking on, she goes round Eco, not through her: a step out to the side first.
func _around_eco() -> void:
	if not walking() or _walk_leg >= _walk_route.size():
		return
	var p: Vector3 = rm.player.global_position
	var at := _walker.global_position
	var to: Vector3 = _walk_route[_walk_leg]
	var line := to - at
	line.y = 0.0
	var rel := p - at
	rel.y = 0.0
	var k := clampf(rel.dot(line) / maxf(line.length_squared(), 0.001), 0.0, 1.0)
	var closest := at + line * k
	if Vector2(closest.x - p.x, closest.z - p.z).length() > 1.0:
		return
	var side := _flat(line).cross(Vector3.UP)
	if side.dot(at - p) < 0.0:
		side = -side
	_walk_route = _walk_route.duplicate()
	_walk_route.insert(_walk_leg, Vector3(p.x, to.y, p.z) + side * 1.3 + _flat(line) * 0.6)


## Where it goes on Eco: her lips, or her left forearm (Cutter's).
func _give_target() -> Vector3:
	if _stop_captor == "cutter":
		return _eco_point("J_Bip_L_LowerArm", 1.1).lerp(_eco_point("J_Bip_L_Hand", 0.95), 0.5)
	var fwd := _flat(-rm.player.global_basis.z)
	return _eco_point("J_Bip_C_Head", 1.5) + Vector3(0, 0.035, 0) + fwd * 0.08


## A needle of Redline, pointing along -Z.
func _needle() -> Node3D:
	var p := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.albedo_color = Color(1.0, 0.1, 0.08)
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.0
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
		p.add_child(mi)
	return p


## A bone of Eco's (her body's skeleton), or `fallback` m up from her feet.
func _eco_point(bone: String, fallback: float) -> Vector3:
	for body in _eco_bodies():
		var skel := (body as Node).find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null:
			var i := skel.find_bone(bone)
			if i >= 0:
				return skel.global_transform * skel.get_bone_global_pose(i).origin
	return rm.player.global_position + Vector3(0, fallback, 0)


func _eco_bodies() -> Array:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	if eco == null:
		return []
	return ["Body", "Shadow"].map(func(n): return eco.get_node_or_null(n)).filter(func(b): return b != null)


func _walker_anim(anim: String) -> void:
	if not walking():
		return
	var ap := _walker.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(anim):
		ap.play(anim, 0.35)


## She's not off to them after all: home, the real her back at her spot.
func _walk_home() -> void:
	var w := _drawn_who
	_end_walk()
	_drawn_at = -1.0
	var got = rm.hub_npcs.get(w)
	if got == null or not is_instance_valid(got):
		return
	var real: Node3D = got
	real.visible = true
	if is_instance_valid(real.get("soft_body")):
		(real.soft_body as CollisionObject3D).collision_layer = 1


## The scene's over (or cut short): her own eyes back, the bar gone.
func _stop_over() -> void:
	if _give_prop != null and is_instance_valid(_give_prop):
		_give_prop.queue_free()
	_give_prop = null
	_q_ui.visible = false
	_give_swirl = 0.0
	EcoModel.swirl_override = -1.0
	if step == Step.STOP:
		step = Step.IDLE
	if t >= 0.0:
		t = -1.0
		_hold(false)
