extends Node
## Marrow's trigger words (vices.gd, Mature only). Once his Hold is deep
## (TRANCE_HOLD and up), his phrases turn up in the world: on the radio, from a
## townsperson in passing, and on runs in his earpiece. Hearing one locks her
## up: the phrase flashes violet, the spirals spin, and the player has WINDOW
## seconds to tap F TAPS times to shake it off. Fail and it costs her: in the
## hub his Hold deepens and, at full Hold, the pull clock (hush_pull.gd) jumps a
## minute; on a run she stands there with her guard down a few seconds more.
## The deeper his Hold, the more often they come.
##
## The colony's compliance headphones (hymn.gd) bring their own words, from any
## Hold: twice as often, with less time to shake them, in a calm colony voice.
## The Shepherd's sonic pulse (shepherd.gd) fires one on the spot.
##
## hush_pull.gd owns one, ticks it while she's free, and counts it in busy().

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")

enum Step { IDLE, LOCKED, DAZED }

const WINDOW := 3.0
const TAPS := 5
## Seconds between triggers: at TRANCE_HOLD, and at full Hold.
const GAP_LIGHT := 150.0
const GAP_DEEP := 60.0
## The first one waits at least this long once she's free.
const FIRST_AFTER := 25.0
## What a failure costs: Hold in the hub, seconds of guard down on a run.
const FAIL_HOLD := 2.0
const FAIL_DAZE := 2.5

## His phrases, and where she hears them (hub / run).
const PHRASES := ["Come home, Eco", "Hush now", "Right on time", "Look at me", "Sit down", "There you are"]
const HUB_SOURCES := [
	"The radio, between songs, in a voice like his: \"...%s...\"",
	"A townsperson walks past, humming, and says it without looking at her: \"%s.\"",
	"Someone's chalked it on the wall in violet: %s",
	"A kid at the corner, copying something they heard: \"%s!\"",
]
const RUN_SOURCES := [
	"His voice, right in her ear, through the static: \"%s.\"",
	"A dead grunt's radio crackles: \"...%s...\"",
	"Under the gunfire, soft as anything: \"%s.\"",
]
## The colony's words, through the headphones or the Shepherd's pulse.
const COLONY_PHRASES := ["Obey", "Take your dose", "You are safe", "Comply", "Good citizen", "Stop running"]
const COLONY_SOURCES := [
	"The headphones, calm and close, under everything: \"%s.\"",
	"A soft chime in the headphones, then: \"%s.\"",
]
const PULSE_SOURCE := "The Shepherd's pulse goes right through her skull: \"%s.\""
const SHOOK := ["Eco: \"Not today.\"", "Eco: \"No. You don't get that.\"", "Eco: \"Shut up. Shut up. ...Okay.\"", "Eco shakes her head hard, and the violet goes."]
const LOST := ["The word sinks all the way in. For a second there's nothing in her but his voice.", "She doesn't fight it. It's easier not to."]

var pull: Node
var step := Step.IDLE
var taps := 0
## What she just heard, for the HUD.
var phrase := ""
var rng := RandomNumberGenerator.new()
var _t := 0.0
## Seconds until the next one.
var _next := FIRST_AFTER
var _on_run := false
var _lines := 0


func _init(owner_pull: Node) -> void:
	pull = owner_pull
	name = "TriggerWords"
	rng.randomize()


func busy() -> bool:
	return step != Step.IDLE


## Can his words get to her at all right now.
static func can_trigger() -> bool:
	return Vices.allowed() and (Vices.hold >= Vices.TRANCE_HOLD or Hymn.has("headphones")) and not Vices.entranced


## Seconds between triggers at his current Hold.
static func gap() -> float:
	var deep := clampf((Vices.hold - Vices.TRANCE_HOLD) / (Vices.MAX_HOLD - Vices.TRANCE_HOLD), 0.0, 1.0)
	return lerpf(GAP_LIGHT, GAP_DEEP, deep) * (0.5 if Hymn.has("headphones") else 1.0)


## Seconds she has to shake one off (less with the headphones on).
static func window() -> float:
	return WINDOW * (0.75 if Hymn.has("headphones") else 1.0)


## Each physics tick while she's free (hub or run); `on_run` picks the sources.
func tick(delta: float, free: bool, on_run: bool) -> void:
	if step != Step.IDLE:
		_advance(delta)
		return
	if not free or not can_trigger():
		return
	_next -= delta
	if _next <= 0.0:
		fire(on_run)


## His words reach her, now (colony: the Shepherd's pulse).
func fire(on_run: bool, colony := false) -> void:
	var rm: Node = pull.rm
	_on_run = on_run
	step = Step.LOCKED
	_t = 0.0
	taps = 0
	# the headphones' words win half the time (all the time below his trance Hold)
	var theirs := Hymn.has("headphones") and (Vices.hold < Vices.TRANCE_HOLD or rng.randf() < 0.5)
	var list: Array = COLONY_PHRASES if colony or theirs else PHRASES
	phrase = list[rng.randi() % list.size()]
	var line: String
	if colony:
		line = PULSE_SOURCE % phrase
	elif theirs:
		line = COLONY_SOURCES[rng.randi() % COLONY_SOURCES.size()] % phrase
	else:
		var sources: Array = RUN_SOURCES if on_run else HUB_SOURCES
		line = sources[rng.randi() % sources.size()] % phrase
	rm.hud.toast(line, window() + 1.0)
	_hold(true)
	_show()


## One tap of F against it.
func tap() -> void:
	if step != Step.LOCKED:
		return
	taps += 1
	_show()
	if taps >= TAPS:
		_shook()


func _advance(delta: float) -> void:
	_t += delta
	if step == Step.LOCKED:
		if Input.is_action_just_pressed("interact"):
			tap()
			return
		if _t >= window():
			_lost()
	elif step == Step.DAZED and _t >= FAIL_DAZE:
		_release()


func _shook() -> void:
	pull.rm.hud.toast(SHOOK[_lines % SHOOK.size()], 2.5)
	_lines += 1
	_release()


func _lost() -> void:
	pull.rm.hud.toast(LOST[_lines % LOST.size()], 3.0)
	_lines += 1
	if _on_run:
		step = Step.DAZED
		_t = 0.0
		_show()
		return
	if phrase in COLONY_PHRASES:
		# the colony's word: Hymn sinks in, not Marrow's Hold
		Hymn.level = minf(Hymn.level + Hymn.DART, Hymn.MAX)
		Hymn.save()
		_release()
		return
	if Vices.hold >= Vices.MAX_HOLD:
		pull.roam = minf(pull.roam + Vices.ROLL_EVERY, Vices.PULL_DEADLINE - 1.0)
	Vices.hold = minf(Vices.hold + FAIL_HOLD, Vices.MAX_HOLD)
	Vices.save()
	_release()


func _release() -> void:
	step = Step.IDLE
	_next = gap() * rng.randf_range(0.75, 1.25)
	_hold(false)
	_show()


## Locks her up (or lets her go): no moving, no guns, the spirals spin.
func _hold(on: bool) -> void:
	var player: Node = pull.rm.player
	Vices.entranced = on
	player.set("entranced", on)
	player.set("trance_dir", Vector3.ZERO)
	if _on_run:
		pull._arms(not on)


## Lets go of her whatever it was doing (the run ended, say).
func reset() -> void:
	if step != Step.IDLE:
		step = Step.IDLE
		_hold(false)
	_next = maxf(_next, FIRST_AFTER)
	_show()


## The phrase and the taps left, big in the middle of the screen.
func prompt_text() -> String:
	match step:
		Step.LOCKED:
			return "%s\n[F] Shake it off  %s" % [phrase.to_upper(), "●".repeat(taps) + "○".repeat(TAPS - taps)]
		Step.DAZED:
			return phrase.to_upper()
	return ""


func _show() -> void:
	var hud: Node = pull.rm.hud
	if hud == null or hud.trigger_label == null:
		return
	hud.trigger_label.text = prompt_text()
	hud.trigger_label.visible = step != Step.IDLE
