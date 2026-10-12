extends SceneTree
## Headless test for Eco's whispers.
## Run: godot --headless --path . -s res://tests/whisper_test.gd

const Lines := preload("res://scripts/radio/eco_whisper_lines.gd")
const Bank := preload("res://scripts/radio/dialogue_bank.gd")

var level
var player
var radio
var whispers
var failures := 0

# Open ground west of the slide ramp, far from the grunt arena.
const SPOT := Vector3(-40, 0.1, 20)


func _initialize() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	radio = level.hud.radio
	whispers = level.hud.whispers
	_check("HUD has whispers", whispers != null, whispers)
	_check("caption is on screen", whispers.caption != null and whispers.caption.is_inside_tree(), "")
	_check("whispers hear the radio", whispers.radio == radio, "")
	_check("whispers have the pistol and knife", whispers.weapon != null and whispers.knife != null, "")
	whispers.always = true
	_bank_checks()
	_place(SPOT)
	await _secs(0.08)
	await _hush()

	# A kill gets a whisper, shown in the caption, with a breath under it.
	whispers.weapon.hit_confirmed.emit("kill")
	await _secs(0.75)
	_check("kill whisper", _last() == "kill", _last())
	_check("caption shows the line", whispers.caption.current_text() == whispers.history[-1]["text"], whispers.caption.current_text())
	_check("whisper has a voice", whispers.voice.stream != null and whispers.voice.stream.data.size() > 2000, "")
	await _secs(0.33)
	_check("caption fades in", whispers.caption.is_showing(), whispers.caption.alpha)
	await _hush()

	# Cooldown: a second kill straight after stays quiet.
	var before: int = whispers.history.size()
	whispers.weapon.hit_confirmed.emit("kill")
	await _secs(1.00)
	_check("kill cooldown", whispers.history.size() == before, _last())
	whispers.cooldowns.clear()
	await _hush()

	# A knife takedown is one whisper, not a takedown and a kill.
	before = whispers.history.size()
	whispers.knife.stabbed.emit("takedown")
	whispers.weapon.hit_confirmed.emit("kill")
	await _secs(1.00)
	await _hush()
	await _secs(1.00)
	_check("takedown whisper", whispers.history.size() == before + 1 and _last() == "takedown", whispers.history.slice(before))
	whispers.cooldowns.clear()
	await _hush()

	# Radio: she answers the gossip, but only once the exchange is off the air.
	var squad := []
	for p in [Vector3(-15, 0, 0), Vector3(-17, 0, 3), Vector3(-17, 0, -3)]:
		squad.append(level.spawn_grunt(SPOT + p + Vector3(0, -0.1, 0), true))
	await _secs(0.08)
	radio.scan_timer = 0.0
	await _secs(0.03)
	before = whispers.history.size()
	radio.ambient_timer = 999.0  # no banter of its own while we test
	_check("radio gossip plays", radio._call("rumor_eco", null), radio.playing)
	await _secs(0.67)
	_check("quiet while the net is on air", radio.playing == "" or whispers.history.size() == before, whispers.history.slice(before))
	await _drain_radio()
	await _secs(1.50)
	_check("answers the gossip after", _last() == "rumor_eco", whispers.history.slice(before))
	_check("answer fits the gossip", _fits(radio.history.filter(func(l): return l["category"] == "rumor_eco").map(func(l): return l["text"]), whispers.history[-1]["text"]), whispers.history[-1]["text"] if not whispers.history.is_empty() else "")
	await _hush()

	# Spotted: the contact call gets a sharp whisper.
	squad[0]._set_awareness(2)
	await _drain_radio()
	await _secs(1.50)
	_check("reacts to being spotted", _last() == "alerted", _last())
	await _hush()
	_check("no quiet thoughts in a fight", whispers._in_danger(), "")
	for g in squad:
		g.take_damage(1000.0, g.global_position, false)
	await _drain_radio()
	await _hush()

	# Run beats always speak.
	whispers.say("zone_start")
	await _secs(0.08)
	_check("run beat speaks", _last() == "zone_start", _last())
	await _hush()

	# Getting badly hurt, then going down.
	player.health = player.max_health * 0.5
	player.take_damage(player.max_health * 0.3, SPOT)
	await _secs(0.75)
	_check("hurt whisper", _last() == "hurt", _last())
	await _hush()
	player.take_damage(1000.0, SPOT)
	await _secs(2.00)
	_check("downed whisper", _last() == "downed", _last())
	await _hush()

	# Quiet stretch: a thought about her father, the titan, the temple.
	_place(SPOT + Vector3(200, 0, 0))
	await _secs(0.08)
	whispers.quiet_timer = 0.0
	await _secs(0.08)
	_check("quiet thought", _last() == "quiet", _last())
	await _hush()

	# Categories the bank leaves out stay silent.
	_check("a category with no lines stays silent", not whispers.say("no_such_moment"), "")

	# Keyed answers: she answers what was actually said.
	for i in 10:
		var t: String = whispers._pick("rumor_eco", "Commander wants her in a cage for the parade.")["text"]
		if not "cage" in t:
			_check("cage talk gets the cage answer", false, t)
			break
	var plain_ok := true
	for i in 40:
		var t: String = whispers._pick("rumor_eco", "Nothing in particular.")["text"]
		var raw: Array = Lines.bank()["rumor_eco"].filter(func(e): return e.ends_with(t))
		if raw.is_empty() or ">" in raw[0]:
			plain_ok = false
	_check("unrelated gossip gets a plain answer", plain_ok, "")
	_check("no keyword markup in captions", whispers.history.all(func(h): return not ">" in h["text"]), "")

	# No line repeats back to back.
	var last := ""
	var repeats := 0
	for i in 30:
		var t: String = whispers._pick("kill")["text"]
		if t == last:
			repeats += 1
		last = t
	_check("no back-to-back repeats", repeats == 0, repeats)

	print("WHISPER TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _bank_checks() -> void:
	# The dialogue files: every speaker has its file.
	for speaker in ["radio", "eco"]:
		var known: Array = Bank.bank(speaker).keys()
		_check("%s M file has lines" % speaker, known.size() > 5, known.size())
	var parsed: Dictionary = Bank.parse("# note\n[kill]\n  Stay down.  \n\n[empty]\n# gone\n[kill]\nNext!\n")
	_check("file format parses", parsed == {"kill": ["Stay down.", "Next!"]}, parsed)
	_check("keys trim and lowercase", whispers._keys("Goggles | old man > Hi") == ["goggles", "old man"] and whispers._text("Goggles | old man > Hi") == "Hi", "")
	_check("keywords match whole words", whispers._mentions("whole tent was staring", "tent") and not whispers._mentions("pay attention", "tent"), "")
	var bank: Dictionary = Lines.bank()
	_check("the bank has the run beats", ["zone_start", "part_installed", "titanfall", "boss_down", "home", "quiet"].all(func(c): return bank.has(c) and not bank[c].is_empty()), "")
	for cat in Lines.bank():
		for line in Lines.bank()[cat]:
			var low := String(line).to_lower()
			if "cunt" in low or "rape" in low:
				_check("M line keeps house rules: %s" % line, false, "")


## A keyed line only answers gossip that mentions one of its keywords.
func _fits(said: Array, answer: String) -> bool:
	var context := " ".join(said).to_lower()
	for e in Lines.bank()["rumor_eco"]:
		if e.ends_with(answer):
			var keys: Array = whispers._keys(e)
			return keys.is_empty() or keys.any(func(k): return whispers._mentions(context, k))
	return false


func _last() -> String:
	return "" if whispers.history.is_empty() else whispers.history[-1]["category"]


## Ends the line on screen and the gap after it.
func _hush() -> void:
	await _ticks(1)
	whispers.speak_timer = 0.0
	await _ticks(2)
	whispers.gap_timer = 0.0
	whispers.pending.clear()
	await _ticks(1)


func _drain_radio() -> void:
	for i in 60:
		if radio.playing == "":
			return
		radio.line_timer = 0.0
		await _ticks(1)


## Waits until the whispers' own clock has moved on this far (process frames
## run less often than physics frames headless).
func _secs(t: float) -> void:
	var until: float = whispers.clock + t
	for i in 2000:
		if whispers.clock >= until:
			return
		await process_frame


func _place(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, value) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", what, str(value)])
	if not ok:
		failures += 1
