extends Node
## Eco's whispers. She can't answer the militia on their own net without
## giving herself away, so she talks back under her breath once an exchange
## goes off the air, and mutters to herself through the fight and the quiet
## stretches. Lines come from eco_whisper_lines.gd, picked by the dialogue
## rating (O key), and show as a soft caption under the crosshair
## (whisper_caption.gd) with a breathy whisper sound under it.
##
## The HUD creates this next to the radio. Other systems can call
##   say(category, delay)    e.g. run_manager: zone_start, part_installed,
##                           titanfall, boss_down, home
## Real voice lines can replace the breath sound later: drop
## res://assets/audio/voice/eco/<category>_<n>.ogg (or .wav), n = the line's
## index in the M bank (0-based), and line_started tells a VO system what to play.

signal line_started(text: String, category: String)

const Lines := preload("res://scripts/radio/eco_whisper_lines.gd")
const Caption := preload("res://scripts/radio/whisper_caption.gd")
const Rating := preload("res://scripts/radio/content_rating.gd")

const VOICE_DIR := "res://assets/audio/voice/eco/"
## No whisper starts within this many seconds of the last one ending.
const GAP := 4.0
## Seconds a caption stays up: base plus per character.
const LINE_BASE := 1.6
const LINE_PER_CHAR := 0.055
## A radio reaction that can't be said within this long after the exchange is dropped.
const REACT_EXPIRES := 6.0
## Pause between the net going quiet and Eco answering it.
const REACT_DELAY := 0.7
## Seconds of calm between quiet thoughts.
const QUIET_GAP := Vector2(45.0, 90.0)
## Below this fraction of max health, getting shot can make her whisper.
const HURT_FRACTION := 0.4

## Chance to whisper and per-category cooldown (s). Radio categories react to
## the exchange that just ended; categories not listed always speak.
const CHANCE := {
	"rumor_eco": 0.75, "rumor_salvage": 0.4, "idle": 0.15,
	"suspicious": 0.55, "stand_down": 0.5, "alerted": 0.6, "lost": 0.6,
	"man_down": 0.35, "last_man": 0.6, "no_answer": 0.7,
	"kill": 0.3, "headshot": 0.3, "takedown": 0.6, "hurt": 0.6, "dry": 0.35,
}
const COOLDOWN := {
	"idle": 40.0, "kill": 12.0, "headshot": 15.0, "takedown": 8.0,
	"hurt": 15.0, "dry": 25.0, "man_down": 10.0, "rumor_salvage": 20.0,
}
## Higher wins when several are waiting; 3+ also cut the GAP short.
const PRIORITY := {
	"quiet": 0, "idle": 0, "rumor_salvage": 1, "rumor_eco": 2, "stand_down": 1,
	"kill": 2, "headshot": 2, "dry": 1, "man_down": 2, "lost": 2,
	"suspicious": 3, "alerted": 3, "takedown": 3, "hurt": 3, "last_man": 3, "no_answer": 3,
	"downed": 4, "zone_start": 4, "part_installed": 4, "titanfall": 4, "boss_down": 4, "home": 4,
}

var player: Node
var weapon: Node
var knife: Node
var radio: Node
var caption: Control
var voice: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

## Waiting whispers: {"category", "at" (time to say it), "expires", "after_radio",
## "context" (what the radio said, for keyed lines)}
var pending: Array = []
var speaking := ""  # category on screen, "" when quiet
var speak_timer := 0.0
var gap_timer := 2.0
var quiet_timer := 0.0
var clock := 0.0
var cooldowns := {}  # category -> clock time it is usable again
var bags := {}
var last_entry := {}
var history: Array = []  # {"category", "text"} for tests and debugging
var always := false  # tests: skip the CHANCE rolls
var _last_ammo := -1
var _takedown_at := -10.0
var _radio_exchange := ""


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	quiet_timer = rng.randf_range(QUIET_GAP.x * 0.5, QUIET_GAP.y * 0.5)
	if caption == null:
		caption = Caption.new()
		caption.name = "WhisperCaption"
		# Its own layer, so she's still heard inside the titan, where the run
		# hides the pilot HUD this node lives on.
		var layer := CanvasLayer.new()
		layer.name = "WhisperLayer"
		layer.layer = 2
		add_child(layer)
		layer.add_child(caption)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voices"
	voice.volume_db = -14.0
	add_child(voice)
	if player != null:
		if player.has_signal("damaged"):
			player.damaged.connect(_on_damaged)
		if player.has_signal("died"):
			player.died.connect(func(): say("downed", 1.2))
	if weapon != null and weapon.has_signal("hit_confirmed"):
		weapon.hit_confirmed.connect(_on_hit)
	if knife != null and knife.has_signal("stabbed"):
		knife.stabbed.connect(_on_stabbed)
	if radio != null and radio.has_signal("line_started"):
		radio.line_started.connect(_on_radio_line)


## Queues a whisper. Categories with a CHANCE roll it here; cooldowns apply.
## Returns true when something was queued.
func say(category: String, delay := 0.0, after_radio := false, context := "") -> bool:
	if clock < cooldowns.get(category, -1.0):
		return false
	if not always and rng.randf() > CHANCE.get(category, 1.0):
		return false
	if not Lines.bank(Rating.current()).has(category):
		return false  # this rating has nothing for it
	pending = pending.filter(func(p): return p["category"] != category)
	pending.append({
		"category": category, "at": clock + delay, "after_radio": after_radio, "context": context,
		"expires": clock + delay + (REACT_EXPIRES if after_radio else 3.0 + REACT_EXPIRES),
	})
	return true


func _process(delta: float) -> void:
	clock += delta
	if speaking != "":
		speak_timer -= delta
		if speak_timer <= 0.0:
			speaking = ""
			gap_timer = GAP
			if caption != null:
				caption.end_line()
		return
	gap_timer -= delta
	pending = pending.filter(func(p): return clock < p["expires"])
	var radio_busy: bool = radio != null and radio.get("playing") != ""
	if _in_danger() or radio_busy:
		quiet_timer = maxf(quiet_timer, QUIET_GAP.x * 0.5)
	else:
		quiet_timer -= delta
		if quiet_timer <= 0.0:
			quiet_timer = rng.randf_range(QUIET_GAP.x, QUIET_GAP.y)
			if pending.is_empty():
				say("quiet")

	if not radio_busy:
		_radio_exchange = ""
	var best := {}
	for p in pending:
		if p["after_radio"] and radio_busy:
			# Hold her answer until the whole exchange has played.
			p["at"] = clock + REACT_DELAY
			p["expires"] = p["at"] + REACT_EXPIRES
			continue
		if clock < p["at"]:
			continue
		if best.is_empty() or PRIORITY.get(p["category"], 0) > PRIORITY.get(best["category"], 0):
			best = p
	if best.is_empty():
		return
	if gap_timer > 0.0 and PRIORITY.get(best["category"], 0) < 3:
		return
	pending.erase(best)
	_speak(best["category"], best.get("context", ""))


func _physics_process(_delta: float) -> void:
	# The magazine running dry (no signal for it on the pistol).
	if weapon == null or weapon.get("ammo") == null:
		return
	var ammo: int = weapon.ammo
	if ammo == 0 and _last_ammo > 0:
		say("dry", 0.3)
	_last_ammo = ammo


func is_speaking() -> bool:
	return speaking != ""


# --- Triggers --------------------------------------------------------------

## An exchange started on the net: queue her answer for when it's off the air.
func _on_radio_line(_callsign: String, text: String, category: String) -> void:
	if category == _radio_exchange:
		# Later lines of the same exchange: remember what they said.
		for p in pending:
			if p["category"] == category:
				p["context"] += " " + text
		return
	_radio_exchange = category
	say(category, REACT_DELAY, true, text)


func _on_hit(kind: String) -> void:
	match kind:
		"kill":
			if clock - _takedown_at > 0.2:  # the knife reports its takedowns as kills too
				say("kill", 0.5)
		"head":
			say("headshot", 0.3)


func _on_stabbed(kind: String) -> void:
	if kind == "takedown":
		_takedown_at = clock
		say("takedown", 0.6)


func _on_damaged(_amount: float, _from: Vector3) -> void:
	if player.health > 0.0 and player.health < player.max_health * HURT_FRACTION:
		say("hurt", 0.4)


## A grunt nearby is hunting or fighting her: no quiet thoughts.
func _in_danger() -> bool:
	if radio == null or not radio.has_method("nearby"):
		return false
	for g in radio.nearby():
		if radio.known[g]["state"] in ["alerted", "suspicious"]:
			return true
	return false


# --- Saying it -------------------------------------------------------------

func _speak(category: String, context := "") -> void:
	var pick := _pick(category, context)
	if pick.is_empty():
		return
	var text: String = pick["text"]
	speaking = category
	speak_timer = LINE_BASE + LINE_PER_CHAR * text.length()
	cooldowns[category] = clock + COOLDOWN.get(category, 0.0)
	quiet_timer = maxf(quiet_timer, QUIET_GAP.x * 0.5)
	history.append({"category": category, "text": text})
	if caption != null:
		caption.show_line(text)
	_play_voice(category, pick["index"], text)
	line_started.emit(text, category)


## Lines whose keywords the radio context mentions win; otherwise a plain
## line. Shuffled bag per rating and category: every line before any repeats,
## and never the same line twice in a row.
func _pick(category: String, context := "") -> Dictionary:
	var rating := Rating.current()
	var entries: Array = Lines.bank(rating).get(category, [])
	if entries.is_empty():
		return {}
	context = context.to_lower()
	var keyed := []
	var plain := []
	for i in entries.size():
		var keys := _keys(entries[i])
		if keys.is_empty():
			plain.append(i)
		elif keys.any(func(k): return context.contains(k)):
			keyed.append(i)
	var fits := keyed if not keyed.is_empty() else plain
	if fits.is_empty():
		return {}
	var key := rating + "/" + category
	var last: int = last_entry.get(key, -1)
	var bag: Array = bags.get(key, [])
	var choices := bag.filter(func(i): return fits.has(i))
	if choices.is_empty():
		bag = range(entries.size())
		bag.shuffle()
		bags[key] = bag
		choices = bag.filter(func(i): return fits.has(i) and i != last)
		if choices.is_empty():
			choices = fits  # only one line fits; a repeat beats silence
	var i: int = choices[0]
	bag.erase(i)
	last_entry[key] = i
	var index := i if rating in ["M", "AO"] else -1
	return {"text": _text(entries[i]), "index": index}


## "goggles|cage>Line" -> ["goggles", "cage"]; plain lines have none.
static func _keys(entry: String) -> Array:
	var cut := entry.find(">")
	return [] if cut < 0 else Array(entry.substr(0, cut).split("|"))


static func _text(entry: String) -> String:
	var cut := entry.find(">")
	return entry if cut < 0 else entry.substr(cut + 1)


func _play_voice(category: String, index: int, text: String) -> void:
	if voice == null or not voice.is_inside_tree():
		return
	var stream: AudioStream = null
	if index >= 0:
		for ext in ["ogg", "wav"]:
			var path := "%s%s_%d.%s" % [VOICE_DIR, category, index, ext]
			if ResourceLoader.exists(path):
				stream = load(path)
				break
	if stream == null:
		stream = _breath(text)
	voice.stream = stream
	voice.play()


## A breathy whisper bed: band-passed noise in soft syllable puffs, one per
## couple of letters, so the caption has a voice under it until there's VO.
func _breath(text: String) -> AudioStreamWAV:
	var rate := 22050
	var words := text.split(" ", false)
	var syllables := 0
	for w in words:
		syllables += maxi(1, int(ceil(w.length() / 3.0)))
	var syl_len := 0.13
	var n := int(rate * (syllables * syl_len + words.size() * 0.05 + 0.2))
	var data := PackedByteArray()
	data.resize(n * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = hash(text)
	var lp := 0.0
	var lp2 := 0.0
	var i := 0
	for w in words:
		var count := maxi(1, int(ceil(w.length() / 3.0)))
		for s in count:
			var len := int(rate * syl_len * noise.randf_range(0.75, 1.2))
			var amp := noise.randf_range(0.5, 1.0)
			var bright := noise.randf_range(0.25, 0.55)  # vowel-ish colour of the hiss
			for k in len:
				if i >= n:
					break
				var x := float(k) / len
				var env := sin(PI * x) * amp
				var raw := noise.randf_range(-1.0, 1.0)
				lp += (raw - lp) * bright
				lp2 += (lp - lp2) * 0.08
				var sample := (lp - lp2) * env * 0.7  # band-pass: hiss without rumble
				data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
				i += 1
		i = mini(i + int(rate * 0.05), n)  # breath between words
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
