extends Node
## Enemy radio chatter. When Eco is near grunts she picks up their squad net:
## idle banter, gossip about her, salvage rumours, and calls that follow what
## the squad is doing (suspicious, contact, losing men, lost her).
## She only listens. Lines show in the radio popup (radio_popup.gd).
##
## Grunt interface (all optional, duck-typed so grunt.gd stays untouched):
##   signal awareness_changed(grunt, state)  state: Awareness enum (UNAWARE,
##                                           SUSPICIOUS, ALERTED) or the same names
##                                           as lowercase strings
##   signal died(grunt)
##   var awareness                           current state, same encoding
## Grunts without awareness_changed are polled through their `alerted` bool.

signal line_started(callsign: String, text: String, category: String)

const Lines := preload("res://scripts/radio/radio_lines.gd")
const RadioPopup := preload("res://scripts/radio/radio_popup.gd")
const TitanParts := preload("res://scripts/run/titan_parts.gd")
const Rating := preload("res://scripts/radio/content_rating.gd")
const SFX := preload("res://scripts/sfx.gd")

## Eco hears grunts within this many metres.
const RANGE := 45.0
## Signal starts breaking up past this fraction of RANGE.
const CLEAR_FRACTION := 0.6
const SCAN_INTERVAL := 0.4
## Seconds between ambient exchanges while the squad is calm, and while fighting.
const IDLE_GAP := Vector2(7.0, 13.0)
const COMBAT_GAP := Vector2(5.0, 9.0)
## Seconds each line stays up: base plus per character.
const LINE_BASE := 1.3
const LINE_PER_CHAR := 0.05
const LINE_PAUSE := 0.35
## Queued lines beyond this are dropped so a firefight doesn't back up the net.
const MAX_QUEUE := 8

## Higher interrupts lower. Equal or higher priority 2+ calls queue instead of dropping.
const PRIORITY := {
	"idle": 0, "rumor_eco": 0, "rumor_salvage": 0,
	"combat": 1, "pilot_moving": 1, "hurt": 1,
	"suspicious": 2, "stand_down": 2, "lost": 2,
	"alerted": 3, "man_down": 3, "last_man": 3, "no_answer": 3,
}

var player: Node3D
var popup: Control
var rng := RandomNumberGenerator.new()

## grunt -> {"callsign", "state", "polled"}
var known := {}
## Pending lines: {"callsign", "text", "category", "speaker"}
var queue: Array = []
var playing := ""  # category of the exchange on air, "" when quiet
var line_timer := 0.0
var ambient_timer := 4.0
var scan_timer := 0.0
var bags := {}  # category -> shuffled entry indices still to use
var last_entry := {}  # category -> index of the last entry used
var history: Array = []  # every line put on air, for tests and debugging
var _callsigns_used := {}

var squelch: AudioStreamPlayer


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if popup == null:
		popup = RadioPopup.new()
		popup.name = "RadioPopup"
		var host: Node = get_parent() if get_parent() is CanvasLayer else self
		host.add_child.call_deferred(popup)
	squelch = AudioStreamPlayer.new()
	squelch.bus = "Voices"
	# The recorded walkie-talkie squelch when there is one (assets/audio/sfx).
	squelch.stream = SFX.stream("radio_squelch_on") if SFX.has_recording("radio_squelch_on") else _make_squelch()
	squelch.volume_db = -16.0
	add_child(squelch)
	if player != null and player.has_signal("damaged"):
		player.damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	if player == null:
		return
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL
		_scan()

	if playing != "":
		line_timer -= delta
		if line_timer <= 0.0:
			_next_line()
		return

	ambient_timer -= delta
	if ambient_timer <= 0.0:
		_ambient()


# --- Who's on the net ------------------------------------------------------

func _scan() -> void:
	for g in get_tree().get_nodes_in_group("enemies"):
		if g.get("on_radio") == false:
			continue  # the Choir and the wildlife aren't on the colony net
		if not known.has(g):
			_track(g)
	for g in known.keys():
		if not is_instance_valid(g):
			known.erase(g)
			continue
		var info: Dictionary = known[g]
		if info["polled"] and not g.dead:
			var now := "alerted" if g.alerted else "unaware"
			if now != info["state"]:
				_on_awareness(g, now)


func _track(g: Node) -> void:
	var info := {"callsign": _new_callsign(), "state": _current_state(g), "polled": true}
	known[g] = info
	if g.has_signal("awareness_changed"):
		info["polled"] = false
		g.awareness_changed.connect(_on_awareness)
	if g.has_signal("died"):
		g.died.connect(_on_died)


const STATES := ["unaware", "suspicious", "alerted"]


func _current_state(g: Node) -> String:
	var a = g.get("awareness")
	if a != null:
		return _state_name(a)
	return "alerted" if g.get("alerted") else "unaware"


## Awareness enum value (grunt.gd's Awareness order) or name, as a lowercase name.
func _state_name(a) -> String:
	if a is int:
		return STATES[clampi(a, 0, STATES.size() - 1)]
	return String(a).to_lower()


func _new_callsign() -> String:
	for i in 20:
		var stem: String = Lines.CALLSIGNS[rng.randi() % Lines.CALLSIGNS.size()]
		var sign := "%s-%d" % [stem, rng.randi_range(1, 9)]
		if not _callsigns_used.has(sign):
			_callsigns_used[sign] = true
			return sign
	return "UNIT-%d" % known.size()


func callsign_of(g: Node) -> String:
	return known[g]["callsign"] if known.has(g) else ""


func in_range(g) -> bool:
	return is_instance_valid(g) and g.global_position.distance_to(player.global_position) <= RANGE


## Grunts Eco can hear right now (alive, tracked, in range).
func nearby() -> Array:
	return known.keys().filter(func(g): return in_range(g) and not g.dead)


# --- Events ----------------------------------------------------------------

func _on_awareness(g: Node, value) -> void:
	if not known.has(g):
		_track(g)
	var state := _state_name(value)
	var old: String = known[g]["state"]
	known[g]["state"] = state
	if state == old or not in_range(g):
		return
	match state:
		"suspicious":
			# Alerted grunts drop to suspicious (searching) when they lose sight of her.
			_call("lost" if old == "alerted" else "suspicious", g)
		"alerted":
			# Only the first grunt to spot her makes the contact call.
			var others_fighting := nearby().any(func(o): return o != g and known[o]["state"] == "alerted")
			if not others_fighting:
				_call("alerted", g)
		"unaware":
			_call("lost" if old == "alerted" else "stand_down", g)


func _on_died(g: Node) -> void:
	if not known.has(g) or not in_range(g):
		return
	var dead_sign: String = known[g]["callsign"]
	known[g]["state"] = "dead"
	var left := nearby().filter(func(o): return o != g)
	if left.is_empty():
		_call("no_answer", null, {"dead": dead_sign})
	elif left.size() == 1:
		_call("last_man", left[0], {"dead": dead_sign})
	else:
		_call("man_down", left[rng.randi() % left.size()], {"dead": dead_sign})


func _on_player_damaged(_amount: float, from: Vector3) -> void:
	if rng.randf() > 0.4:
		return
	var shooter: Node = null
	var best := 2.0
	for g in nearby():
		var d: float = g.global_position.distance_to(from)
		if d < best:
			best = d
			shooter = g
	if shooter != null:
		_call("hurt", shooter)


func _ambient() -> void:
	var near := nearby()
	if near.is_empty():
		ambient_timer = 1.0
		return
	var fighting := near.any(func(g): return known[g]["state"] == "alerted")
	if fighting:
		ambient_timer = rng.randf_range(COMBAT_GAP.x, COMBAT_GAP.y)
		var fancy: bool = player.get("state") != null and player.state != 0  # not on the ground
		_call("pilot_moving" if fancy and rng.randf() < 0.5 else "combat", null)
		return
	if near.any(func(g): return known[g]["state"] == "suspicious"):
		ambient_timer = 2.0
		return
	ambient_timer = rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
	var roll := rng.randf()
	_call("idle" if roll < 0.45 else ("rumor_eco" if roll < 0.75 else "rumor_salvage"), null)


# --- Putting lines on air --------------------------------------------------

## Starts an exchange of this category. `speaker` plays role a when given.
## Returns false when nothing could be said (busy with something more important,
## or not enough grunts in earshot for any entry).
func _call(category: String, speaker: Node, extra := {}) -> bool:
	var prio: int = PRIORITY.get(category, 0)
	if playing != "":
		var cur: int = PRIORITY.get(playing, 0)
		if prio <= cur and prio < 2:
			return false
		# A whole squad losing her at once is one call, not five.
		if prio <= cur and (playing == category or queue.any(func(l): return l["category"] == category)):
			return false
	var near := nearby()
	if speaker != null and not near.has(speaker):
		speaker = null
	var entry_lines := _pick(category, near.size())
	if entry_lines.is_empty():
		return false

	var cast := {}
	var pool := near.duplicate()
	pool.shuffle()
	if speaker != null:
		pool.erase(speaker)
		pool.push_front(speaker)
	for role in ["a", "b", "c"]:
		if not pool.is_empty():
			cast[role] = pool.pop_front()

	var subs := {"part": _random_part()}
	for role in cast:
		subs[role] = known[cast[role]]["callsign"]
	subs.merge(extra)

	var new_lines := []
	for line in entry_lines:
		var who: Node = cast.get(line[0])
		new_lines.append({
			"callsign": Lines.HQ_CALLSIGN if line[0] == "hq" else known[who]["callsign"],
			"text": String(line[1]).format(subs),
			"category": category,
			"speaker": who,
		})

	if playing == "" or prio > PRIORITY.get(playing, 0):
		queue = new_lines  # interrupt
		playing = category
		_next_line()
	elif queue.size() < MAX_QUEUE:
		queue.append_array(new_lines)
	return true


## Picks an entry there are enough grunts in earshot for. Entries come from a
## shuffled bag, so every entry plays before any repeats, and never the same
## entry twice in a row.
func _pick(category: String, grunts: int) -> Array:
	var rating := Rating.current()
	var entries: Array = Lines.bank(rating).get(category, [])
	category = rating + "/" + category  # bags and repeats are tracked per rating
	var fits := range(entries.size()).filter(func(i): return Lines.roles(entries[i]).size() <= grunts)
	if fits.is_empty():
		return []
	var last: int = last_entry.get(category, -1)
	var bag: Array = bags.get(category, [])
	var choices := bag.filter(func(i): return fits.has(i))
	if choices.is_empty():
		bag = range(entries.size())
		bag.shuffle()
		bags[category] = bag
		choices = bag.filter(func(i): return fits.has(i) and i != last)
		if choices.is_empty():
			choices = fits  # only one entry fits; a repeat beats silence
	var pick: int = choices[0]
	bag.erase(pick)
	last_entry[category] = pick
	return Lines.parse(entries[pick])


func _next_line() -> void:
	if queue.is_empty():
		playing = ""
		if popup != null:
			popup.end_transmission()
		_squelch(0.85)
		return
	var line: Dictionary = queue.pop_front()
	var speaker = line["speaker"]  # untyped: may have been freed (zone change)
	var hq: bool = line["callsign"] == Lines.HQ_CALLSIGN
	if not hq and (not is_instance_valid(speaker) or speaker.dead):
		_next_line()  # dead men tell no jokes
		return
	playing = line["category"]
	var clarity := 1.0
	if not hq:
		var d: float = speaker.global_position.distance_to(player.global_position)
		clarity = 1.0 - smoothstep(RANGE * CLEAR_FRACTION, RANGE * 1.6, d)
	line_timer = LINE_BASE + LINE_PER_CHAR * line["text"].length() + LINE_PAUSE
	history.append(line)
	if popup != null:
		popup.show_line(line["callsign"], line["text"], clarity, hq)
	_squelch(1.15)
	line_started.emit(line["callsign"], line["text"], line["category"])


func _random_part() -> String:
	var slot: String = TitanParts.SLOTS[rng.randi() % TitanParts.SLOTS.size()]
	var options: Array = TitanParts.CATALOG[slot]
	return options[rng.randi() % options.size()]["name"]


# --- Squelch sound ---------------------------------------------------------

func _squelch(pitch: float) -> void:
	if squelch != null and squelch.is_inside_tree():
		squelch.pitch_scale = pitch * rng.randf_range(0.95, 1.05)
		squelch.play()


## A short burst of band-passed static with a click, built once in code.
func _make_squelch() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	var lp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var raw := noise.randf_range(-1.0, 1.0)
		lp += (raw - lp) * 0.35
		var band := lp - prev * 0.6  # crude band-pass, radio-ish
		prev = lp
		var env := minf(t * 30.0, 1.0) * pow(1.0 - t, 1.6)
		var click := 0.8 if i < 40 else 0.0
		var s := clampf(band * env * 0.9 + click * (1.0 - i / 40.0), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
