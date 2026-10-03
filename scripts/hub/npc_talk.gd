extends CanvasLayer
## Conversations between Eco and the people in the hub. Press F by one of them
## (run_manager.gd) and they talk: each line is babbled in the speaker's voice,
## Animal Crossing style (babble.gd), while its caption types out at the
## bottom of the screen. F finishes the line, or skips to the next once it's
## all there; walking away ends it.
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

const Babble := preload("res://scripts/hub/babble.gd")
const DIALOGUE_DIR := "res://dialogue/npc/"
const DEFAULT_PATH := "user://hub_npcs.cfg"
const Romance := preload("res://scripts/hub/romance.gd")
const Gifts := preload("res://scripts/run/gifts.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
## Where the gift bag lives in the save file.
const BAG := "_bag"
## How long a line stays up after it's all been said.
const GAP := 0.9
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
## When each character of the line is said (Babble.make), and time into the line.
var _times := PackedFloat32Array()
var _line_t := 0.0
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
## The pose the heart scene playing asks for ([heart N <spot>], npc_idles.gd).
var scene_pose := ""
## A heart scene (or a date) gets its own camera, framed on them.
var _scene_cam: Camera3D
var _prev_cam: Camera3D
var _pilot := Vector3.INF
var _fade: ColorRect
var _fade_t := 0.0
var _fade_hold := 0.0
var _gift_run := 0
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
	var bank := {"any": [], "together": [], "flirt": [], "heart": [], "date": {}, "gift": {}}
	var cur: Array = []
	var choice_re := RegEx.create_from_string("^choice\\s*([+-]?\\d+)?\\s*(?:!(\\w+))?\\s*:\\s*(\\w+(?:\\s*\\([^)]*\\))?)\\s*:\\s*(.+)$")
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			cur = []
			var tag := line.substr(1, line.length() - 2).strip_edges()
			var parts := tag.split(" ", false)
			match parts[0]:
				"any", "together", "flirt":
					bank[parts[0]].append(cur)
				"heart":
					bank["heart"].append({"at": int(parts[1]) if parts.size() > 1 else 0, "lines": cur, "pose": parts[2] if parts.size() > 2 else ""})
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
				"lines": [_line(m.get_string(3), m.get_string(4))],
			})
			continue
		if line.begins_with(">"):
			line = line.substr(1).strip_edges()
			var c := line.find(":")
			if c > 0 and not cur.is_empty() and cur.back() is Dictionary:
				cur.back()["choice"].back()["lines"].append(_line(line.substr(0, c), line.substr(c + 1)))
			continue
		var colon := line.find(":")
		if colon > 0:
			cur.append(_line(line.substr(0, colon), line.substr(colon + 1)))
	bank["heart"].sort_custom(func(a, b): return a["at"] < b["at"])
	return bank


## One line: [speaker, text], or [speaker, text, moods] when the speaker has
## moods in brackets, "ophelia (shy, tilt): ...". Moods are always the face
## of the person Eco is talking to, whoever speaks (hub_npc.gd mood()), and
## hold until a line with other moods (or "plain").
static func _line(speaker: String, text: String) -> Array:
	speaker = speaker.strip_edges()
	text = text.strip_edges()
	var open := speaker.find("(")
	if open < 0:
		return [speaker, text]
	var moods := []
	for w in speaker.substr(open + 1).trim_suffix(")").split(",", false):
		moods.append(w.strip_edges())
	return [speaker.substr(0, open).strip_edges(), text, moods]


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
	scene_pose = ""
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
		scene_pose = scene.get("pose", "")
		Romance.mark_beat(state, who, beat)
		return scene["lines"]
	var list := Romance.talk_list(state, b, who)
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
	var l := pick(p_npc.who, run_id, won)
	if beat >= 0 and not l.is_empty():
		if scene_pose != "" and p_npc.has_method("calm"):
			NpcIdles.take(p_npc, scene_pose)
		_play(p_npc, l)
		_scene_start()
		return
	_play(p_npc, l)


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
	_scene_start()
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
	var reply: Array = [["eco", "Here. Found you something. %s." % Gifts.display_name(gift)]]
	reply.append_array(g.get(gift, g.get(taste, g.get("any", []))))
	_play(p_npc, reply)
	_refresh_hearts()
	state.save(save_path)
	return delta


## The gifts Eco is carrying (ids, oldest first), found on runs (gifts.gd).
func gifts() -> Array:
	return state.get_value(BAG, "gifts", []).duplicate()


func add_gift(id: String) -> void:
	var bag := gifts()
	bag.append(id)
	state.set_value(BAG, "gifts", bag)
	state.save(save_path)


## True when G by them would offer a gift: they can be romanced, Eco has
## something, and they haven't had one this run.
func can_give(who: String, run_id: int) -> bool:
	return romanceable(who) and not gifts().is_empty() and int(state.get_value(who, "gift_run", -1)) != run_id


## G: Eco picks which gift to hand over (up to three kinds, 1-3).
func offer_gifts(p_npc: Node3D, run_id: int) -> void:
	stop()
	var kinds := []
	for id in gifts():
		if not kinds.has(id):
			kinds.append(id)
	if kinds.is_empty():
		return
	var opts := []
	for id in kinds.slice(0, 3):
		opts.append({"delta": 0, "flag": "", "gift": id, "lines": [["eco", Gifts.display_name(id)]]})
	_gift_run = run_id
	_play(p_npc, [{"choice": opts}])


## F: finish the line if it's still being said, else on to the next (not
## while Eco has to answer).
func advance() -> void:
	if not active() or not options.is_empty():
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_text.visible_characters = -1
		_line_t = INF
		line_left = minf(line_left, GAP)
		return
	_next()


## Eco's answer to the question on screen (0-based). Its lines play next.
func choose(i: int) -> void:
	if not active() or i < 0 or i >= options.size():
		return
	var opt: Dictionary = options[i]
	var who: String = npc.who
	if opt.has("gift"):
		var to := npc
		var bag := gifts()
		bag.erase(opt["gift"])
		state.set_value(BAG, "gifts", bag)
		var delta := give_gift(to, opt["gift"], _gift_run)
		if Romance.romanceable(bank(who)):
			_react(who, delta, "")
		return
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
		if npc.has_method("calm"):
			npc.calm()
		npc = null
		_eco_voice.stop()
		_panel.visible = false
		finished.emit(who)
	lines = []
	index = -1
	options = []
	beat = -1
	scene_pose = ""
	_answered = false
	_scene_end()
	if _options != null:
		_options.visible = false


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
	if lines[index].size() > 2 and npc.has_method("mood"):
		npc.mood(lines[index][2])
		if "kiss" in lines[index][2]:
			fade_through_black(1.8)
	var babble := Babble.make(speaker, text)
	var stream: AudioStream = babble["stream"]
	_times = babble["times"]
	_line_t = 0.0
	var length: float = babble["length"]
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
	_text.visible_characters = 0
	_hint.text = "[F] next"
	_panel.visible = true


## Called every frame by the run manager while the hub runs. `pilot` is where
## Eco is, so walking off ends it.
func tick(delta: float, pilot: Vector3) -> void:
	if not active():
		return
	_pilot = pilot
	if not is_instance_valid(npc) or pilot.distance_to(npc.global_position) > LEAVE_RANGE:
		stop()
		return
	if not options.is_empty():
		return   # waiting on Eco's answer
	line_left -= delta
	_line_t += delta
	if _text.visible_characters >= 0:
		var shown := 0
		while shown < _times.size() - 1 and _times[shown] <= _line_t:
			shown += 1
		_text.visible_characters = -1 if shown >= _text.text.length() else shown
	if line_left <= 0.0:
		_next()


## The line on screen, for tests: "speaker: text", "choice: a | b" while Eco
## has to answer, or "".
func current_line() -> String:
	if not active() or index < 0 or index >= lines.size():
		return ""
	if not options.is_empty():
		return "choice: " + " | ".join(PackedStringArray(options.map(func(o): return o["lines"][0][1])))
	return "%s: %s" % [lines[index][0], lines[index][1]]


## The screen goes black for `hold` seconds then comes back (a kiss, a cut).
func fade_through_black(hold: float) -> void:
	_fade_hold = hold
	_fade_t = 0.0


func in_scene() -> bool:
	return _scene_cam != null


func _scene_start() -> void:
	if npc == null or not npc.is_inside_tree() or _scene_cam != null:
		return
	_prev_cam = get_viewport().get_camera_3d()
	_scene_cam = Camera3D.new()
	_scene_cam.fov = 38.0
	npc.get_parent().add_child(_scene_cam)
	_frame_scene()
	_scene_cam.current = true
	fade_through_black(0.15)


func _scene_end() -> void:
	if _scene_cam == null:
		return
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_scene_cam.queue_free()
	_scene_cam = null


## Frames their face from Eco's side, a little off to one side.
func _frame_scene() -> void:
	if _scene_cam == null or npc == null:
		return
	var head: Vector3 = npc.head_position() if npc.has_method("head_position") else npc.global_position + Vector3(0, 1.45, 0)
	var toward := (-npc.global_basis.z)
	if _pilot != Vector3.INF:
		toward = _pilot - head
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var side := toward.cross(Vector3.UP).normalized()
	var at := head + toward * 1.55 + side * 0.55 + Vector3(0, 0.08, 0)
	_scene_cam.global_position = _scene_cam.global_position.lerp(at, 0.08) if _scene_cam.is_inside_tree() and _scene_cam.global_position != Vector3.ZERO else at
	_scene_cam.look_at(head - side * 0.12 - Vector3(0, 0.05, 0))


func _process(delta: float) -> void:
	if _scene_cam != null:
		_frame_scene()
	if _fade_hold > 0.0 or _fade_t > 0.0:
		_fade_t += delta
		var a := 0.0
		if _fade_t < 0.35:
			a = _fade_t / 0.35
		elif _fade_t < 0.35 + _fade_hold:
			a = 1.0
		elif _fade_t < 0.35 + _fade_hold + 0.6:
			a = 1.0 - (_fade_t - 0.35 - _fade_hold) / 0.6
		else:
			_fade_t = 0.0
			_fade_hold = 0.0
		_fade.color.a = a
		_fade.visible = a > 0.0
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
	var giving: bool = options[0].has("gift")
	_name.text = "GIVE %s A GIFT" % NAMES.get(npc.who, npc.who.to_upper()) if giving else "ECO"
	_name.add_theme_color_override("font_color", COLORS["eco"])
	_text.text = ""
	_text.visible = false
	_hint.text = "[1-%d] %s" % [options.size(), "give" if giving else "answer"]
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
	if npc.has_method("mood"):
		match flag:
			"together":
				npc.mood(["fluster", "joy"])
			"friends":
				npc.mood(["sad", "down"])
			"later":
				npc.mood(["shy"])
			_:
				if delta >= 6:
					npc.mood(["blush", "smile"])
				elif delta > 0:
					npc.mood(["smile"])
				elif delta <= -5:
					npc.mood(["angry"])
				elif delta < 0:
					npc.mood(["sad"])
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
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
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
