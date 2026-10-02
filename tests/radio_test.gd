extends SceneTree
## Headless test for the enemy radio chatter.
## Run: godot --headless --path . -s res://tests/radio_test.gd

const Lines := preload("res://scripts/radio/radio_lines.gd")

var level
var player
var radio
var failures := 0

# Open ground west of the slide ramp, far from the grunt arena.
const SPOT := Vector3(-40, 0.1, 20)
const UNAWARE := 0
const SUSPICIOUS := 1
const ALERTED := 2


func _initialize() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	_run.call_deferred()


func _run() -> void:
	await _ticks(30)
	player = root.get_node("TestLevel/Player")
	radio = level.hud.radio
	_check("HUD has a radio", radio != null, radio)
	_check("radio popup is on the HUD", radio.popup != null and radio.popup.is_inside_tree(), "")
	_bank_checks()
	_pick_checks()

	# Nobody in earshot: silence.
	_place(SPOT)
	await _ticks(10)
	radio.ambient_timer = 0.0
	await _ticks(5)
	_check("silent with no grunts nearby", radio.history.is_empty(), radio.history.size())

	# A calm squad of three, 15-20 m away.
	var squad := []
	for p in [Vector3(-15, 0, 0), Vector3(-17, 0, 3), Vector3(-17, 0, -3)]:
		squad.append(level.spawn_grunt(SPOT + p + Vector3(0, -0.1, 0), true))
	await _ticks(5)
	radio.scan_timer = 0.0
	await _ticks(2)
	_check("squad tracked with callsigns", squad.all(func(g): return radio.callsign_of(g) != ""), squad.map(func(g): return radio.callsign_of(g)))
	radio.ambient_timer = 0.0
	await _ticks(2)
	var calm: String = radio.playing
	_check("calm squad chats", calm in ["idle", "rumor_eco", "rumor_salvage"], calm)
	_check("popup shows the line", radio.popup.current_text() != "", radio.popup.current_text())
	_check("speakers are squad or HQ", _speakers_ok(squad), _last_signs())
	await _ticks(30)
	_check("popup visible", radio.popup.is_showing(), radio.popup.alpha)
	await _drain()

	# One spots her (grunt.gd's awareness_changed signal): contact call.
	squad[0]._set_awareness(ALERTED)
	await _ticks(2)
	_check("contact call", radio.playing == "alerted", radio.playing)
	_check("contact made by the spotter", _category_has_speaker("alerted", squad[0]), _last_signs())
	# The others joining in don't repeat the contact call.
	await _drain()
	var before: int = radio.history.size()
	squad[1]._set_awareness(ALERTED)
	squad[2]._set_awareness(ALERTED)
	await _ticks(2)
	_check("one contact call per squad", radio.history.size() == before, radio.playing)

	# Fighting banter while alerted.
	radio.ambient_timer = 0.0
	await _ticks(2)
	_check("combat banter", radio.playing in ["combat", "pilot_moving"], radio.playing)

	# A kill interrupts banter with a man-down call naming the dead.
	var dead_sign: String = radio.callsign_of(squad[2])
	squad[2].take_damage(999.0, squad[2].global_position)
	await _ticks(2)
	_check("man down call", radio.playing == "man_down", radio.playing)
	await _drain()
	var named: Array = radio.history.filter(func(l): return l["category"] == "man_down")
	_check("man down lines spoken by survivors", named.all(func(l): return l["speaker"] != squad[2]), "")
	_check("dead grunt named or skipped cleanly", named.all(func(l): return not l["text"].contains("{")), named.map(func(l): return l["text"]))

	# Losing her: alerted drops to searching, then gives up.
	squad[1]._set_awareness(SUSPICIOUS)
	squad[0]._set_awareness(SUSPICIOUS)
	await _ticks(2)
	_check("lost her call", radio.playing == "lost", radio.playing)
	_check("squad losing her is one call", radio.queue.all(func(l): return l["category"] == "lost") and radio.queue.size() < 4, radio.queue.size())
	await _drain()
	squad[1]._set_awareness(UNAWARE)
	await _ticks(2)
	_check("stand down after searching", radio.playing == "stand_down", radio.playing)
	await _drain()

	# Down to the last man, then nobody.
	squad[1].take_damage(999.0, squad[1].global_position)
	await _ticks(2)
	_check("last man panics", radio.playing == "last_man", radio.playing)
	await _drain()
	squad[0].take_damage(999.0, squad[0].global_position)
	await _ticks(2)
	_check("HQ calls into silence", radio.playing == "no_answer", radio.playing)
	await _drain()
	_check("HQ lines styled as HQ", radio.history.filter(func(l): return l["category"] == "no_answer").all(func(l): return l["callsign"] == Lines.HQ_CALLSIGN), "")

	# A grunt without the awareness signal is polled through its alerted flag.
	var old_style = _fake_grunt(false)
	level.add_child(old_style)
	old_style.global_position = SPOT + Vector3(-12, 0, 4)
	await _ticks(2)
	radio.scan_timer = 0.0
	await _ticks(2)
	old_style.alerted = true
	radio.scan_timer = 0.0
	await _ticks(2)
	_check("contact call from a polled grunt", radio.playing == "alerted", radio.playing)
	await _drain()
	old_style.dead = true
	old_style.remove_from_group("enemies")
	old_style.died.emit(old_style)
	await _drain()

	# A grunt that reports awareness as strings through the signal interface.
	var fake = _fake_grunt(true)
	level.add_child(fake)
	fake.global_position = SPOT + Vector3(-10, 0, 0)
	await _ticks(2)
	radio.scan_timer = 0.0
	await _ticks(2)
	fake.awareness_changed.emit(fake, "suspicious")
	await _ticks(2)
	_check("suspicious call from signal", radio.playing == "suspicious", radio.playing)
	await _drain()
	fake.awareness_changed.emit(fake, "unaware")
	await _ticks(2)
	_check("stand down from signal", radio.playing == "stand_down", radio.playing)
	await _drain()
	fake.awareness_changed.emit(fake, "alerted")
	await _ticks(2)
	_check("contact from signal", radio.playing == "alerted", radio.playing)
	await _drain()

	# Far away: the net goes out of range.
	_place(SPOT + Vector3(200, 0, 0))
	await _ticks(5)
	before = radio.history.size()
	fake.awareness_changed.emit(fake, "unaware")
	radio.ambient_timer = 0.0
	await _ticks(5)
	_check("out of range is silent", radio.history.size() == before, radio.history.size() - before)

	_check("no placeholder left unfilled", radio.history.all(func(l): return not l["text"].contains("{")), "")
	var consecutive := 0
	for i in range(1, radio.history.size()):
		if radio.history[i]["text"] == radio.history[i - 1]["text"]:
			consecutive += 1
	_check("no line repeats back to back", consecutive == 0, consecutive)
	await create_timer(radio.popup.HOLD + radio.popup.FADE + 0.5).timeout
	_check("popup fades after the net goes quiet", not radio.popup.is_showing(), [radio.popup.alpha, radio.playing, radio.popup.on_air, radio.popup.quiet_time, radio.queue.size()])

	print("radio lines heard: %d" % radio.history.size())
	for l in radio.history.slice(0, 6):
		print("   %s: %s" % [l["callsign"], l["text"]])
	print("RADIO TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func _bank_checks() -> void:
	var bad := []
	for cat in Lines.LINES:
		_check("priority set for %s" % cat, radio.PRIORITY.has(cat), cat)
		for entry in Lines.LINES[cat]:
			for line in Lines.parse(entry):
				if not line[0] in ["a", "b", "c", "hq"] or line[1].strip_edges() == "":
					bad.append(entry)
			if cat == "no_answer" and not Lines.roles(entry).is_empty():
				bad.append(entry)
	_check("every line parses", bad.is_empty(), bad)


func _pick_checks() -> void:
	var last := ""
	var repeats := 0
	for i in 300:
		var e: String = str(radio._pick("combat", 3))
		if e == last:
			repeats += 1
		last = e
	_check("picker never repeats back to back", repeats == 0, repeats)
	var solo := 0
	for i in 50:
		var lines: Array = radio._pick("idle", 1)
		if lines.is_empty() or Lines.roles(" | ".join(lines.map(func(l): return "%s: %s" % l))).size() <= 1:
			solo += 1
	_check("lone grunt only gets one-grunt exchanges", solo == 50, solo)


func _speakers_ok(squad: Array) -> bool:
	var signs := squad.map(func(g): return radio.callsign_of(g))
	signs.append(Lines.HQ_CALLSIGN)
	return radio.history.all(func(l): return l["callsign"] in signs)


func _category_has_speaker(cat: String, g: Node) -> bool:
	return radio.history.filter(func(l): return l["category"] == cat).any(func(l): return l["speaker"] == g) \
		or radio.queue.any(func(l): return l["speaker"] == g)


func _last_signs() -> Array:
	return radio.history.slice(-4).map(func(l): return "%s: %s" % [l["callsign"], l["text"]])


## Plays out whatever is on air.
func _drain() -> void:
	for i in 40:
		if radio.playing == "":
			return
		radio.line_timer = 0.0
		await _ticks(1)


func _fake_grunt(with_signal: bool) -> Node3D:
	var s := GDScript.new()
	s.source_code = """extends Node3D
%s
signal died(grunt)
var dead := false
var alerted := false
var awareness := "unaware"
func _ready():
	add_to_group("enemies")
""" % ("signal awareness_changed(grunt, state)" if with_signal else "")
	s.reload()
	var n := Node3D.new()
	n.set_script(s)
	return n


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
