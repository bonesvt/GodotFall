extends Node
## The side effects of Eco's relics on a run (hub/relics.gd) that play out
## over time, and the perks that need the world:
##   - Eye of the Builder: grunts within EYE_RANGE marked through walls, and
##     every so often a marker (and a whisper) that isn't anything;
##   - Sunless Mask: blackouts, the screen going dark for a second or two;
##   - Heartstone: her max health shrinking as the run goes on;
##   - Mom's Locket: Mom on the radio, and nearby grunts hearing it;
##   - Ophelia's Pocket Watch: a headshot slows the world for a moment;
##   - Colony Target Lens: the colony pings her, and grunts close in;
##   - Phase Harness: overheating on a long sprint;
##   - kills: Imani's sutures patch her up, the Idol's Tooth takes its price.
## Under Mature (relics.gd MATURE) some of these turn darker: the whispers
## are in her dad's voice and pull her aim, the mask's blackouts run longer
## and can leave her somewhere else, the lens's colony taunts her; and the
## Mature-only colony tech lives here too (the stim injector, the Glass core).
## The run manager ticks it on runs (run_tick), tells it about kills
## (on_kill) and stops it going home (stop).

const Relics := preload("res://scripts/hub/relics.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const SFX := preload("res://scripts/sfx.gd")

const EYE_RANGE := 30.0
const EYE := Color(0.35, 1.0, 0.85)
## Seconds between the Eye's false markers, and how long one stays.
const WHISPER_EVERY := Vector2(14.0, 26.0)
const WHISPER_TIME := 3.0
const WHISPERS := [
	"...behind you...",
	"...she isn't alone out here...",
	"...we see them. Do you?...",
	"...closer. Closer...",
	"...the eye opens...",
	"...that one. No. That one...",
]
## Mature: the Eye's whispers, in her dad's voice.
const DAD_WHISPERS := [
	"\"Put it down, kiddo. You were never built for this.\"",
	"\"They turned you away for a reason, Eco.\"",
	"\"I died so you wouldn't have to do this.\"",
	"\"Behind you. No. I'm kidding. Or am I.\"",
	"\"You hum when you reload. Like me. Stop it.\"",
	"\"Come sit with me a while. Just put the gun down.\"",
]
const BLACKOUT_EVERY := Vector2(35.0, 70.0)
const BLACKOUT_TIME := Vector2(1.2, 2.0)
const BLACKOUT_TIME_M := Vector2(2.0, 3.2)
## Mature: the chance a blackout leaves her back at her last checkpoint, and what it costs.
const LOST_TIME_CHANCE := 0.3
const LOST_TIME_HURT := 8.0
const LOST_TIME_LINE := "She comes to back down the trail, bruised, with no idea how she got here."
const RADIO_EVERY := Vector2(45.0, 80.0)
## How far Mom's crackle carries to grunts.
const RADIO_RANGE := 25.0
const MOM_LINES := [
	"Mom (radio): \"Sweetheart? Just checking in. Are you eating?\"",
	"Mom (radio): \"Eco, it's Mom. Is this thing on? EC-O?\"",
	"Mom (radio): \"I made stew. Come home safe and have some.\"",
	"Mom (radio): \"Are you wearing the locket? Good. I love you. Over.\"",
	"Mom (radio): \"Biggie says you're fine. I don't believe Biggie.\"",
]
const BEACON_EVERY := Vector2(55.0, 90.0)
const BEACON_RANGE := 45.0
const BEACON_LINE := "The target lens chirps. Colony network: target located. Grunts are closing in on her."
## Mature: the colony taunts her down her own radio.
const TAUNTS := [
	"Colony (radio): \"Found you, little pilot. Your father hid better than this.\"",
	"Colony (radio): \"We still have his titan's black box. Want to hear the end?\"",
	"Colony (radio): \"Turned away by your own people. Come work for us instead.\"",
	"Colony (radio): \"Squad's on the way. Say hello to Daddy for us.\"",
]
const INJECTOR_LINE := "The injector bites her thigh on its own. Ironskin. She didn't ask for that."
const CORE_LINE := "The Glass core cracks open in her. Everything slows. Her skin goes cold."
## The harness: sprinting longer than this (s) starts burning her, this much a second.
const HARNESS_GRACE := 3.0
const HARNESS_BURN := 5.0
const LOCKET_LINE := "Mom's locket goes warm against her chest. She stays standing. Somehow."
const JAM_LINE := "Click. Jammed. Sal's cheap parts."

var rm: Node
var rng := RandomNumberGenerator.new()
var _layer: CanvasLayer
var _dark: ColorRect
var _marks: Control
var _whisper_next := 0.0
var _blackout_next := 0.0
var _blackout_left := 0.0
var _blackout_len := 1.0
var _radio_next := 0.0
var _beacon_next := 0.0
var _sprint := 0.0
var _slow_left := 0.0
var _slowed := false
var _health_tick := 0.0
var _core_cooldown := 0.0
var _whisper_left := 0.0
## False markers on screen: {pos: Vector3, left: float}.
var fakes: Array = []


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "RelicFx"
	rng.randomize()


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_layer.add_child(_marks)
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_dark)
	_reset_timers()


func _reset_timers() -> void:
	_whisper_next = rng.randf_range(WHISPER_EVERY.x, WHISPER_EVERY.y)
	_blackout_next = rng.randf_range(BLACKOUT_EVERY.x, BLACKOUT_EVERY.y)
	_radio_next = rng.randf_range(RADIO_EVERY.x, RADIO_EVERY.y) * 0.5
	_beacon_next = rng.randf_range(BEACON_EVERY.x, BEACON_EVERY.y)


## A blackout, the watch's slow-mo or a false marker is on now.
func active() -> bool:
	return _blackout_left > 0.0 or _slowed or not fakes.is_empty()


## A run's tick (delta is game time). `free`: she's on foot and nothing else has her.
func run_tick(delta: float, free: bool) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	Relics.tick(delta)
	_flags()
	if _slowed:
		_slow_left -= real
		if _slow_left <= 0.0:
			_set_slow(false)
	_blackout(real)
	_core_cooldown -= delta
	_whisper_left = maxf(_whisper_left - delta, 0.0)
	Relics.whispering = clampf(_whisper_left / 1.5, 0.0, 1.0)
	if Relics.auto_jab(rm.player.health / maxf(rm.player.max_health, 1.0)):
		rm.hud.toast(INJECTOR_LINE, 2.5)
		SFX.play(rm.player, "titan_hiss_short", -8.0, 2.0)
	if Relics.dark("glass_core") and not rm.player.damaged.is_connected(_on_hit):
		rm.player.damaged.connect(_on_hit)
	_health_tick -= delta
	if _health_tick <= 0.0:
		_health_tick = 1.0
		if Relics.active("heartstone"):
			rm.player.refresh_glass()
	if not free:
		_marks.queue_redraw()
		return
	if Relics.active("builder_eye"):
		_whispers(delta)
	elif not fakes.is_empty():
		fakes.clear()
	if Relics.active("moms_locket"):
		_radio(delta)
	if Relics.active("target_lens"):
		_beacon(delta)
	if Relics.active("phase_harness"):
		_harness(delta)
	_marks.queue_redraw()


func _flags() -> void:
	if Relics.locket_saved:
		Relics.locket_saved = false
		rm.hud.toast(LOCKET_LINE, 3.0)
	if Relics.jammed:
		Relics.jammed = false
		rm.hud.toast(JAM_LINE, 1.5)
		SFX.play(rm.player, "dry_click", -2.0)
	if Relics.headshot:
		Relics.headshot = false
		if not _slowed and is_equal_approx(Engine.time_scale, 1.0) and not Glass.focusing():
			_slow_left = Relics.WATCH_TIME
			_set_slow(true)


func _set_slow(on: bool) -> void:
	if on == _slowed:
		return
	_slowed = on
	Engine.time_scale = Relics.WATCH_SLOW if on else 1.0


func _blackout(real: float) -> void:
	if _blackout_left > 0.0:
		_blackout_left -= real
		var t := clampf(_blackout_left / _blackout_len, 0.0, 1.0)
		# snaps dark, then the world bleeds back in at the end
		_dark.color.a = clampf(t * 4.0, 0.0, 1.0) * 0.97
		return
	_dark.color.a = 0.0
	if not Relics.active("sunless_mask"):
		return
	_blackout_next -= real
	if _blackout_next <= 0.0:
		_blackout_next = rng.randf_range(BLACKOUT_EVERY.x, BLACKOUT_EVERY.y)
		var span := BLACKOUT_TIME_M if Relics.mature() else BLACKOUT_TIME
		_blackout_len = rng.randf_range(span.x, span.y)
		_blackout_left = _blackout_len
		if Relics.mature() and rng.randf() < LOST_TIME_CHANCE and rm.get("checkpoint") != null and rm.phase == rm.Phase.ZONE:
			# lost time: she walked somewhere in the dark
			var p: Node3D = rm.player
			p.global_position = rm.checkpoint
			p.velocity = Vector3.ZERO
			p.health = maxf(p.health - LOST_TIME_HURT, 1.0)
			rm.hud.toast(LOST_TIME_LINE, 3.0)


func _whispers(delta: float) -> void:
	for f in fakes:
		f["left"] -= delta
	fakes = fakes.filter(func(f): return f["left"] > 0.0)
	_whisper_next -= delta
	if _whisper_next > 0.0:
		return
	_whisper_next = rng.randf_range(WHISPER_EVERY.x, WHISPER_EVERY.y)
	var p: Node3D = rm.player
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(8.0, EYE_RANGE * 0.8)
	fakes.append({"pos": p.global_position + Vector3(cos(ang) * dist, 1.2, sin(ang) * dist), "left": WHISPER_TIME})
	if Relics.mature():
		rm.hud.toast(DAD_WHISPERS[rng.randi() % DAD_WHISPERS.size()], 3.0)
		_whisper_left = WHISPER_TIME
	else:
		rm.hud.toast(WHISPERS[rng.randi() % WHISPERS.size()], 2.0)


func _radio(delta: float) -> void:
	_radio_next -= delta
	if _radio_next > 0.0:
		return
	_radio_next = rng.randf_range(RADIO_EVERY.x, RADIO_EVERY.y)
	rm.hud.toast(MOM_LINES[rng.randi() % MOM_LINES.size()], 3.0)
	SFX.play(rm.player, "radio_squelch_on", -4.0)
	var at: Vector3 = rm.player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.has_method("hear_gunshot") and (e as Node3D).global_position.distance_to(at) <= RADIO_RANGE:
			e.hear_gunshot(at)


func _beacon(delta: float) -> void:
	_beacon_next -= delta
	if _beacon_next > 0.0:
		return
	_beacon_next = rng.randf_range(BEACON_EVERY.x, BEACON_EVERY.y)
	rm.hud.toast(TAUNTS[rng.randi() % TAUNTS.size()] if Relics.mature() else BEACON_LINE, 3.0)
	SFX.play(rm.player, "lock_on", -4.0)
	var at: Vector3 = rm.player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.has_method("alert") and (e as Node3D).global_position.distance_to(at) <= BEACON_RANGE:
			e.alert(false)


func _harness(delta: float) -> void:
	var p: Node = rm.player
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	var sprinting: bool = p.state == p.State.GROUND and hv.length() > float(p.run_speed) * 1.1
	_sprint = _sprint + delta if sprinting else maxf(_sprint - delta * 2.0, 0.0)
	if _sprint > HARNESS_GRACE and p.health > 1.0:
		p.health = maxf(p.health - HARNESS_BURN * delta, 1.0)
		p.regen_timer = maxf(p.regen_timer, 0.5)
		if _sprint - delta <= HARNESS_GRACE:
			rm.hud.toast("The phase harness is cooking her. Ease off.", 1.5)


## The Glass core: a hit cracks a second of Glass open in her.
func _on_hit(_amount: float, _from: Vector3) -> void:
	if not Relics.dark("glass_core") or _core_cooldown > 0.0 or Glass.focusing():
		return
	_core_cooldown = Relics.CORE_COOLDOWN
	Glass.focus_left = Relics.CORE_FOCUS
	Glass.glass = mini(Glass.glass + 1, Glass.MAX_GLASS)
	Glass.used_this_run = true
	Glass.save()
	rm.player.refresh_glass()
	rm.hud.toast(CORE_LINE, 2.0)


## A grunt went down: Imani's sutures, the Tooth's price.
func on_kill() -> void:
	var h := Relics.kill_health()
	if h == 0.0:
		return
	var p: Node = rm.player
	p.health = clampf(p.health + h, 1.0, p.max_health)


func _draw_marks() -> void:
	if not Relics.active("builder_eye"):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at: Vector3 = rm.player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and not e.get("dead") == true and (e as Node3D).global_position.distance_to(at) <= EYE_RANGE:
			_mark(cam, (e as Node3D).global_position + Vector3(0, 1.2, 0), 1.0)
	for f in fakes:
		_mark(cam, f["pos"], clampf(f["left"], 0.0, 1.0))


func _mark(cam: Camera3D, pos: Vector3, alpha: float) -> void:
	if cam.is_position_behind(pos):
		return
	var s := cam.unproject_position(pos)
	var c := Color(EYE, 0.75 * alpha)
	var r := 9.0
	_marks.draw_polyline(PackedVector2Array([s + Vector2(0, -r), s + Vector2(r, 0), s + Vector2(0, r), s + Vector2(-r, 0), s + Vector2(0, -r)]), c, 2.0)
	_marks.draw_circle(s, 2.5, c)


## Off the run: the world at speed, no blackout, no markers.
func stop() -> void:
	_set_slow(false)
	_blackout_left = 0.0
	if _dark != null:
		_dark.color.a = 0.0
	fakes.clear()
	_sprint = 0.0
	_whisper_left = 0.0
	_core_cooldown = 0.0
	Relics.whispering = 0.0
	_reset_timers()
	if _marks != null:
		_marks.queue_redraw()
