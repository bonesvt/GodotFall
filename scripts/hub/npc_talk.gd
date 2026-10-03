extends CanvasLayer
## Conversations between Eco and the people in the hub. Press F by one of them
## (run_manager.gd) and they talk: each line is voiced (assets/audio/voice/npc/,
## made by tools/npc/voices.py) and captioned at the bottom of the screen.
## F skips to the next line; walking away ends it.
##
## The words live in dialogue/npc/<who>.txt: [intro] the first time Eco talks
## to them, [won] / [lost] once after each run that ended that way, otherwise
## the [any] conversations in turn. Who has met whom and where each of them is
## in their [any] list is saved to `save_path`.
##
## Romance (romance.gd) rides on the same talks: for anyone with a [romance]
## section a heart meter sits by their name, their [heart N] scenes come
## before their everyday talks once affection is high enough, and a
## "choice" line stops the talk until Eco answers with 1-3:
##   choice +6: eco: what Eco says        (+6 affection if she picks it)
##   > ophelia: their answer to that      (plays only after that pick)
##   choice -4 !friends: eco: ...         (a flag: see Romance.apply_flag)
## Choices in a row form one question; the talk goes on after the answer.

signal finished(who: String)
signal affection_changed(who: String, value: int, delta: int)

const DIALOGUE_DIR := "res://dialogue/npc/"
const VOICE_DIR := "res://assets/audio/voice/npc/"
const DEFAULT_PATH := "user://hub_npcs.cfg"
const Romance := preload("res://scripts/hub/romance.gd")
## Pause after each line, and how long a line with no voice file stays up.
const GAP := 0.35
const WORDS_PER_SEC := 2.6
## Walk this far (m) from whoever you're talking to and the talk ends.
const LEAVE_RANGE := 5.5

const NAMES := {"mom": "MOM", "ophelia": "OPHELIA", "biggie": "BIGGIE", "eco": "ECO"}
const COLORS := {"mom": Color(0.6, 0.85, 0.6), "ophelia": Color(0.78, 0.55, 1.0), "biggie": Color(0.95, 0.75, 0.4), "eco": Color(1.0, 0.45, 0.45)}

var save_path := DEFAULT_PATH
var state := ConfigFile.new()
## The conversation playing: its NPC node, lines [[speaker, text], ...] and the line on now.
var npc: Node3D
var lines: Array = []
var index := -1
var line_left := 0.0
var _eco_voice: AudioStreamPlayer
var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _banks := {}
## Waiting on Eco's answer: the question's options, else [].
var options: Array = []
## The [heart N] scene playing (its N), or -1.
var beat := -1
var _answered := false
var _hearts: HeartMeter
var _stage: Label
var _options: VBoxContainer
var _reaction: Label
var _reaction_left := 0.0


func _ready() -> void:
	layer = 6
	state.load(save_path)
	_eco_voice = AudioStreamPlayer.new()
	add_child(_eco_voice)
	_build_caption()


func active() -> bool:
	return npc != null


## Parses dialogue/npc/<who>.txt: {"intro": [...], "won": [...], "lost": [...],
## "any": [[...], ...], "together": [[...], ...], "heart": [{at, lines}, ...],
## "date": {place: [...]}, "gift": {item: [...]}, "romance": [[key, value], ...]},
## each conversation a list of [speaker, text] lines and {"choice": [{delta,
## flag, lines}, ...]} questions.
static func parse(text: String) -> Dictionary:
	var bank := {"any": [], "together": [], "heart": [], "date": {}, "gift": {}}
	var cur: Array = []
	var choice_re := RegEx.create_from_string("^choice\\s*([+-]?\\d+)?\\s*(?:!(\\w+))?\\s*:\\s*(\\w+)\\s*:\\s*(.+)$")
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			cur = []
			var tag := line.substr(1, line.length() - 2).strip_edges()
			var parts := tag.split(" ", false)
			match parts[0]:
				"any", "together":
					bank[parts[0]].append(cur)
				"heart":
					bank["heart"].append({"at": int(parts[1]) if parts.size() > 1 else 0, "lines": cur})
				"date", "gift":
					bank[parts[0]][parts[1] if parts.size() > 1 else "any"] = cur
				_:
					bank[tag] = cur
			continue
		var m := choice_re.search(line)
		if m != null:
			if cur.is_empty() or not cur.back() is Dictionary:
				cur.append({"choice": []})
			cur.back()["choice"].append({
				"delta": int(m.get_string(1)) if m.get_string(1) != "" else 0,
				"flag": m.get_string(2),
				"lines": [[m.get_string(3), m.get_string(4).strip_edges()]],
			})
			continue
		if line.begins_with(">"):
			line = line.substr(1).strip_edges()
			var c := line.find(":")
			if c > 0 and not cur.is_empty() and cur.back() is Dictionary:
				cur.back()["choice"].back()["lines"].append([line.substr(0, c).strip_edges(), line.substr(c + 1).strip_edges()])
			continue
		var colon := line.find(":")
		if colon > 0:
			cur.append([line.substr(0, colon).strip_edges(), line.substr(colon + 1).strip_edges()])
	bank["heart"].sort_custom(func(a, b): return a["at"] < b["at"])
	return bank


func bank(who: String) -> Dictionary:
	if not _banks.has(who):
		var f := FileAccess.open(DIALOGUE_DIR + who + ".txt", FileAccess.READ)
		_banks[who] = parse(f.get_as_text()) if f != null else {"any": []}
	return _banks[who]


## Which conversation they'd have now. `run_id` counts finished runs and
## `won` says how the last one went (run_id 0: no run yet).
func pick(who: String, run_id: int, won: bool) -> Array:
	var b := bank(who)
	beat = -1
	if not state.get_value(who, "met", false) and b.has("intro"):
		state.set_value(who, "met", true)
		state.set_value(who, "run_seen", run_id)
		state.set_value(who, "warm_run", run_id)
		return b["intro"]
	# Time together counts, once a hub stay.
	if Romance.romanceable(b) and int(state.get_value(who, "warm_run", -1)) != run_id:
		state.set_value(who, "warm_run", run_id)
		_add_affection(who, Romance.TALK_GAIN)
	if run_id > int(state.get_value(who, "run_seen", 0)):
		state.set_value(who, "run_seen", run_id)
		var tag := "won" if won else "lost"
		if b.has(tag):
			return b[tag]
	var scene := Romance.next_beat(state, b, who)
	if not scene.is_empty():
		beat = int(scene["at"])
		Romance.mark_beat(state, who, beat)
		return scene["lines"]
	var list := "any"
	if Romance.status(state, who) == "together" and not b["together"].is_empty():
		list = "together"
	var any: Array = b[list]
	if any.is_empty():
		return []
	var key := "next_" + list
	var n: int = state.get_value(who, key, 0)
	state.set_value(who, key, (n + 1) % any.size())
	return any[n % any.size()]


## True when talking to them now would open one of their [heart] scenes (the
## prompt hints at it).
func beat_waiting(who: String, run_id: int) -> bool:
	if not state.get_value(who, "met", false):
		return false
	var extra := Romance.TALK_GAIN if int(state.get_value(who, "warm_run", -1)) != run_id else 0
	return not Romance.next_beat(state, bank(who), who, extra).is_empty()


func romanceable(who: String) -> bool:
	return Romance.romanceable(bank(who))


func affection(who: String) -> int:
	return Romance.affection(state, who)


func _add_affection(who: String, delta: int) -> void:
	if delta == 0:
		return
	var v := Romance.add(state, who, delta)
	affection_changed.emit(who, v, delta)


func start(p_npc: Node3D, run_id: int, won: bool) -> void:
	stop()
	_play(p_npc, pick(p_npc.who, run_id, won))


## Plays `p_lines` with `p_npc` (any conversation: a scene, a date, a gift).
## Call stop() first.
func _play(p_npc: Node3D, p_lines: Array) -> void:
	lines = p_lines.duplicate()
	state.save(save_path)
	if lines.is_empty():
		return
	npc = p_npc
	index = -1
	_refresh_hearts()
	_next()


## A date with them at `place` (a hook for date spots outside the hub). Plays
## their [date <place>] lines, else [date any], and raises affection once per
## run. False if they won't go yet (see Romance.can_date).
func date(p_npc: Node3D, place: String, run_id: int) -> bool:
	stop()
	var who: String = p_npc.who
	var b := bank(who)
	if not Romance.can_date(state, b, who):
		return false
	if int(state.get_value(who, "date_run", -1)) != run_id:
		state.set_value(who, "date_run", run_id)
		_add_affection(who, Romance.DATE_GAIN)
	_play(p_npc, b["date"].get(place, b["date"].get("any", [])))
	return true


## Eco gives them `gift` (an item id; a hook for shops and loot). Their taste
## ([romance] likes / dislikes) sets the affection, once per run; they answer
## with [gift <item>], else [gift like|dislike|other], else [gift any].
## Returns the affection change.
func give_gift(p_npc: Node3D, gift: String, run_id: int) -> int:
	stop()
	var who: String = p_npc.who
	var b := bank(who)
	var taste := Romance.gift_taste(b, gift)
	var delta := 0
	if Romance.romanceable(b) and int(state.get_value(who, "gift_run", -1)) != run_id:
		state.set_value(who, "gift_run", run_id)
		delta = Romance.gift_delta(taste)
		_add_affection(who, delta)
	var g: Dictionary = b["gift"]
	_play(p_npc, g.get(gift, g.get(taste, g.get("any", []))))
	return delta


## F: on to the next line now (not while Eco has to answer).
func advance() -> void:
	if active() and options.is_empty():
		_next()


## Eco's answer to the question on screen (0-based). Its lines play next.
func choose(i: int) -> void:
	if not active() or i < 0 or i >= options.size():
		return
	var opt: Dictionary = options[i]
	var who: String = npc.who
	_answered = true
	options = []
	_options.visible = false
	var rest := lines.slice(index + 1)
	lines = lines.slice(0, index) + opt["lines"] + rest
	index -= 1
	if Romance.romanceable(bank(who)):
		_add_affection(who, int(opt["delta"]))
		if opt["flag"] != "":
			Romance.apply_flag(state, who, opt["flag"], beat)
		_react(who, int(opt["delta"]), opt["flag"])
		_refresh_hearts()
	state.save(save_path)
	_next()


func stop() -> void:
	if npc != null:
		var who: String = npc.who
		# Walked off a heart scene before answering anything: it waits for next time.
		if beat >= 0 and index < lines.size() and not _answered:
			Romance.apply_flag(state, who, "later", beat)
			state.save(save_path)
		npc.hush()
		npc = null
		_eco_voice.stop()
		_panel.visible = false
		finished.emit(who)
	lines = []
	index = -1
	options = []
	beat = -1
	_answered = false
	if _options != null:
		_options.visible = false


static func voice_path(speaker: String, text: String) -> String:
	return VOICE_DIR + ("%s|%s" % [speaker, text]).sha1_text() + ".ogg"


func _next() -> void:
	index += 1
	if index >= lines.size():
		stop()
		return
	if lines[index] is Dictionary:
		_ask(lines[index]["choice"])
		return
	var speaker: String = lines[index][0]
	var text: String = lines[index][1]
	var path := voice_path(speaker, text)
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	var length := float(text.split(" ", false).size()) / WORDS_PER_SEC + 0.6
	if stream != null:
		length = stream.get_length()
	_eco_voice.stop()
	if speaker == "eco":
		npc.hush()
		npc.talking = true   # still facing her
		if stream != null:
			_eco_voice.stream = stream
			_eco_voice.play()
	else:
		npc.say(stream)
	line_left = length + GAP
	_name.text = NAMES.get(speaker, speaker.to_upper())
	_name.add_theme_color_override("font_color", COLORS.get(speaker, Color.WHITE))
	_text.text = text
	_text.visible = true
	_hint.text = "[F] next"
	_panel.visible = true


## Called every frame by the run manager while the hub runs. `pilot` is where
## Eco is, so walking off ends it.
func tick(delta: float, pilot: Vector3) -> void:
	if not active():
		return
	if not is_instance_valid(npc) or pilot.distance_to(npc.global_position) > LEAVE_RANGE:
		stop()
		return
	if not options.is_empty():
		return   # waiting on Eco's answer
	line_left -= delta
	if line_left <= 0.0:
		_next()


## The line on screen, for tests: "speaker: text", "choice: a | b" while Eco
## has to answer, or "".
func current_line() -> String:
	if not active() or index < 0 or index >= lines.size():
		return ""
	if not options.is_empty():
		return "choice: " + " | ".join(PackedStringArray(options.map(func(o): return o["lines"][0][1])))
	return "%s: %s" % lines[index]


func _process(delta: float) -> void:
	if _reaction_left > 0.0:
		_reaction_left -= delta
		_reaction.modulate.a = clampf(_reaction_left / 0.6, 0.0, 1.0)
		_reaction.visible = _reaction_left > 0.0


## Shows Eco's possible answers and waits.
func _ask(p_options: Array) -> void:
	options = p_options
	npc.hush()
	npc.talking = true
	_eco_voice.stop()
	for c in _options.get_children():
		c.queue_free()
	for i in options.size():
		var l := Label.new()
		l.text = "%d   %s" % [i + 1, options[i]["lines"][0][1]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(716, 0)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", COLORS["eco"].lerp(Color.WHITE, 0.45))
		_options.add_child(l)
	_name.text = "ECO"
	_name.add_theme_color_override("font_color", COLORS["eco"])
	_text.text = ""
	_text.visible = false
	_hint.text = "[1-%d] answer" % options.size()
	_options.visible = true
	_panel.visible = true


## "Ophelia liked that." under the caption after an answer.
func _react(who: String, delta: int, flag: String) -> void:
	var name: String = NAMES.get(who, who.to_upper()).capitalize()
	var text := ""
	match flag:
		"together":
			text = "%s is with you now." % name
		"friends":
			text = "You and %s are just friends." % name
		"later":
			text = "%s will ask again." % name
		_:
			if delta >= 6:
				text = "%s really liked that." % name
			elif delta > 0:
				text = "%s liked that." % name
			elif delta < 0:
				text = "%s didn't like that." % name
	if text == "":
		return
	_reaction.text = text
	_reaction.add_theme_color_override("font_color", Color(1.0, 0.55, 0.7) if delta >= 0 else Color(0.6, 0.62, 0.7))
	_reaction.visible = true
	_reaction_left = 2.6


func _refresh_hearts() -> void:
	var show := npc != null and romanceable(npc.who)
	_hearts.visible = show
	_stage.visible = show
	if show:
		_hearts.fill = Romance.hearts(state, npc.who)
		_hearts.queue_redraw()
		_stage.text = Romance.stage(state, npc.who).to_upper()


func _build_caption() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.05, 0.72)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -260   # above the speed readout
	_panel.offset_bottom = -135
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	top.add_child(_name)
	_hearts = HeartMeter.new()
	_hearts.visible = false
	top.add_child(_hearts)
	_stage = Label.new()
	_stage.visible = false
	_stage.add_theme_font_size_override("font_size", 12)
	_stage.add_theme_color_override("font_color", Color(1.0, 0.6, 0.75, 0.8))
	top.add_child(_stage)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.92))
	_text.custom_minimum_size = Vector2(716, 0)
	box.add_child(_text)
	_options = VBoxContainer.new()
	_options.visible = false
	_options.add_theme_constant_override("separation", 6)
	box.add_child(_options)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	_reaction = Label.new()
	_reaction.visible = false
	_reaction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reaction.add_theme_font_size_override("font_size", 14)
	foot.add_child(_reaction)
	_hint = Label.new()
	_hint.text = "[F] next"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.72))
	foot.add_child(_hint)


## A row of hearts, `fill` of them full (halves allowed). Drawn, not a font
## glyph, so it shows the same everywhere.
class HeartMeter extends Control:
	var fill := 0.0
	const SIZE := 16.0
	const GAP := 5.0

	func _init() -> void:
		custom_minimum_size = Vector2(5 * (SIZE + GAP), SIZE + 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pink := Color(1.0, 0.36, 0.55)
		var dim := Color(1.0, 0.36, 0.55, 0.28)
		for i in 5:
			var at := Vector2(i * (SIZE + GAP) + SIZE / 2.0, SIZE / 2.0 + 2.0)
			var whole := _heart(at, false)
			draw_colored_polygon(whole, dim)
			if fill >= i + 1:
				draw_colored_polygon(whole, pink)
			elif fill > i:
				draw_colored_polygon(_heart(at, true), pink)

	## The classic heart curve, scaled to SIZE; `left` gives just its left half.
	func _heart(at: Vector2, left: bool) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 28
		for k in n + 1:
			var t := (PI if left else 0.0) + (PI if left else TAU) * k / n
			var x := 16.0 * pow(sin(t), 3)
			var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			pts.append(at + Vector2(x, -y - 2.5) * (SIZE / 34.0))
		if not left:
			pts.remove_at(pts.size() - 1)
		return pts
