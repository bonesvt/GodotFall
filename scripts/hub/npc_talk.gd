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
## in their [any] list is saved to `save_path`. Anyone with [excuse] talks
## (Mom: what she told the town this time) tacks the next one, in order, onto
## the first talk after each run. [about <who> <stage>] talks (Mom, as Eco
## and Ophelia fall for each other) come up once each, one a hub stay, as
## that romance reaches each stage (_about_talk).
##
## Romance (romance.gd) rides on the same talks: for anyone with a [romance]
## section a heart meter sits by their name, their [heart N] scenes come
## before their everyday talks once affection is high enough, and a
## "choice" line stops the talk until Eco answers with 1-3:
##   choice +6: eco: what Eco says        (+6 affection if she picks it)
##   > ophelia: their answer to that      (plays only after that pick)
##   choice -4 !friends: eco: ...         (a flag: see Romance.apply_flag)
## Choices in a row form one question; the talk goes on after the answer.
##
## Family (family.gd, "Motherly Love") rides on them too, for anyone with a
## [family] section: a bond meter instead of hearts, [bond N] scenes whose
## answers move the bond, [close] talks once close, and the cuddle() and
## care() talks staged by family_scene.gd. dialogue/family/<who>.txt is read
## on top of dialogue/npc/<who>.txt, so the family lines live apart from the
## everyday ones; its [soft] talks (Eco, gentler) join anyone's everyday talks
## once Eco has softened enough.

signal finished(who: String)
## A line carried a "@name" mood: a cue for a staged scene (smoke_date.gd).
signal cue(name: String)
signal affection_changed(who: String, value: int, delta: int)
signal bond_changed(who: String, value: int, delta: int)

const Babble := preload("res://scripts/hub/babble.gd")
const DIALOGUE_DIR := "res://dialogue/npc/"
const DEFAULT_PATH := "user://hub_npcs.cfg"
const Romance := preload("res://scripts/hub/romance.gd")
const Family := preload("res://scripts/hub/family.gd")
const FAMILY_DIR := "res://dialogue/family/"
const Gifts := preload("res://scripts/run/gifts.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const Obsession := preload("res://scripts/hub/obsession.gd")
const Vices := preload("res://scripts/hub/vices.gd")
## Where the gift bag lives in the save file.
const BAG := "_bag"
## How long a line stays up after it's all been said.
const GAP := 0.9
## Walk this far (m) from whoever you're talking to and the talk ends.
const LEAVE_RANGE := 5.5

const NAMES := {"mom": "MOM", "ophelia": "OPHELIA", "biggie": "BIGGIE", "eco": "ECO", "narrator": ""}
const COLORS := {"mom": Color(0.6, 0.85, 0.6), "ophelia": Color(0.78, 0.55, 1.0), "biggie": Color(0.95, 0.75, 0.4), "eco": Color(1.0, 0.45, 0.45),
	"narrator": Color(0.8, 0.8, 0.82)}

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
## The [bond N] scene playing (its N), or -1.
var bond_scene := -1
## A staged scene (family_scene.gd) holds the talk: walking off doesn't end it.
var hold := false
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
	_eco_voice.bus = "Voices"
	add_child(_eco_voice)
	_build_caption()


func active() -> bool:
	return npc != null


## Parses dialogue/npc/<who>.txt: {"intro": [...], "won": [...], "lost": [...],
## "any": [[...], ...], "together": [[...], ...], "heart": [{at, lines}, ...],
## "date": {place: [...]}, "date_m": {place: [...]} (the Mature cut of a date,
## [date <place> m]), "gift": {item: [...]}, "romance": [[key, value], ...]},
## each conversation a list of [speaker, text] lines and {"choice": [{delta,
## flag, lines}, ...]} questions.
static func parse(text: String) -> Dictionary:
	var bank := {"any": [], "together": [], "flirt": [], "heart": [], "date": {}, "date_m": {}, "gift": {}, "spot": {},
		"bond": [], "close": [], "soft": [], "cuddle": [], "sick": [], "excuse": [], "about": []}
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
				"any", "together", "flirt", "close", "soft", "cuddle", "sick", "excuse":
					bank[parts[0]].append(cur)
				"heart":
					bank["heart"].append({"at": int(parts[1]) if parts.size() > 1 else 0, "lines": cur, "pose": parts[2] if parts.size() > 2 else ""})
				"bond":
					bank["bond"].append({"at": int(parts[1]) if parts.size() > 1 else 0, "lines": cur})
				"about":
					# [about ophelia crush]: what they have to say about someone
					# else's romance with Eco once it gets that far
					bank["about"].append({"who": parts[1] if parts.size() > 1 else "", "stage": parts[2] if parts.size() > 2 else "", "lines": cur})
				"date", "gift":
					# [date cafe m]: the Mature cut of that date
					var key: String = parts[0] + ("_m" if parts[0] == "date" and parts.size() > 2 and parts[2] == "m" else "")
					bank[key][parts[1] if parts.size() > 1 else "any"] = cur
				"spot":
					# [spot yoga] / [spot yoga flirt]: talks about what they're
					# doing at that idle spot (npc_idles.gd), flirty ones once
					# Romance.flirty()
					var at: String = parts[1] if parts.size() > 1 else ""
					var tier: String = parts[2] if parts.size() > 2 else ""
					var tiers: Dictionary = bank["spot"].get_or_add(at, {})
					tiers.get_or_add(tier, []).append(cur)
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
	bank["bond"].sort_custom(func(a, b): return a["at"] < b["at"])
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


## Their parsed lines: dialogue/npc/<who>.txt (and dialogue/family/<who>.txt),
## with dialogue/npc/<who>_M.txt (and family's) read on top, the Mature cuts
## of the scenes they share: see overlay(). Cached.
func bank(who: String) -> Dictionary:
	var key := who
	if not _banks.has(key):
		var b := _read(DIALOGUE_DIR + who + ".txt")
		if Family.enabled:
			var extra := _read(FAMILY_DIR + who + ".txt")
			for k in extra:
				if not b.has(k):
					b[k] = extra[k]
				elif b[k] is Array:
					b[k] += extra[k]
				elif b[k] is Dictionary:
					b[k].merge(extra[k])
			b["bond"].sort_custom(func(x, y): return x["at"] < y["at"])
		overlay(b, _read(DIALOGUE_DIR + who + "_M.txt"))
		if Family.enabled:
			overlay(b, _read(FAMILY_DIR + who + "_M.txt"))
		_banks[key] = b
	return _banks[key]


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return parse(f.get_as_text()) if f != null else parse("")


## Lays a Mature cut over a bank: every kind of talk the cut has replaces that
## kind wholesale (all of [any], all of [flirt], all the [heart N] scenes...),
## and [date <place>], [gift <item>] and [spot <name> <tier>] replace one by
## one. Kinds the cut leaves out (like [romance]) stay as they were.
static func overlay(b: Dictionary, cut: Dictionary) -> void:
	for k in cut:
		var v = cut[k]
		if v is Array:
			if not v.is_empty():
				b[k] = v
		elif v is Dictionary:
			if not b.get(k) is Dictionary:
				b[k] = {}
			for sub in v:
				if v[sub] is Dictionary and b[k].get(sub) is Dictionary:
					b[k][sub] = (b[k][sub] as Dictionary).merged(v[sub], true)
				else:
					b[k][sub] = v[sub]
		else:
			b[k] = v


## Which conversation they'd have now. `run_id` counts finished runs and
## `won` says how the last one went (run_id 0: no run yet).
func pick(who: String, run_id: int, won: bool, spot := "") -> Array:
	var b := bank(who)
	beat = -1
	bond_scene = -1
	scene_pose = ""
	if not state.get_value(who, "met", false) and b.has("intro"):
		state.set_value(who, "met", true)
		state.set_value(who, "run_seen", run_id)
		state.set_value(who, "warm_run", run_id)
		state.set_value(who, "bond_run", run_id)
		return b["intro"]
	if Family.has_family(b) and int(state.get_value(who, "bond_run", -1)) != run_id:
		state.set_value(who, "bond_run", run_id)
		_add_bond(who, Family.TALK_GAIN)
	# Time together counts, once a hub stay.
	if Romance.romanceable(b) and int(state.get_value(who, "warm_run", -1)) != run_id:
		state.set_value(who, "warm_run", run_id)
		_add_affection(who, Romance.TALK_GAIN)
	if run_id > int(state.get_value(who, "run_seen", 0)):
		state.set_value(who, "run_seen", run_id)
		var tag := "won" if won else "lost"
		var excuse := _next_excuse(who)
		if b.has(tag):
			return b[tag] + excuse
		if not excuse.is_empty():
			return excuse
	var scene := Romance.next_beat(state, b, who)
	if not scene.is_empty():
		beat = int(scene["at"])
		scene_pose = scene.get("pose", "")
		Romance.mark_beat(state, who, beat)
		return scene["lines"]
	var fscene := Family.next_scene(state, b, who)
	if not fscene.is_empty():
		bond_scene = int(fscene["at"])
		Family.mark_scene(state, who, bond_scene)
		return fscene["lines"]
	var about := _about_talk(who, run_id)
	if not about.is_empty():
		return about
	var at_spot := _spot_talk(who, run_id, spot)
	if not at_spot.is_empty():
		return at_spot
	var list := Romance.talk_list(state, b, who)
	if list == "any":
		# Close to Mom: her [close] talks, and anyone's [soft] ones, take turns
		# with the everyday ones.
		var lists := ["any"]
		if Family.close(state, b, who) and not b["close"].is_empty():
			lists.append("close")
		if Family.softness(state) >= Family.SOFT_TALKS_FROM and not b["soft"].is_empty():
			lists.append("soft")
		var turn: int = state.get_value(who, "list_turn", 0)
		state.set_value(who, "list_turn", turn + 1)
		list = lists[turn % lists.size()]
	var any: Array = b[list]
	if any.is_empty():
		return []
	var key := "next_" + list
	var n: int = state.get_value(who, key, 0)
	state.set_value(who, key, (n + 1) % any.size())
	return any[n % any.size()]


## The next of their [excuse] talks, in file order, once per run home; when
## they run out the last three take turns. [] if they have none.
func _next_excuse(who: String) -> Array:
	var list: Array = bank(who)["excuse"]
	if list.is_empty():
		return []
	var n: int = state.get_value(who, "next_excuse", 0)
	state.set_value(who, "next_excuse", n + 1)
	if n < list.size():
		return list[n]
	var tail := mini(3, list.size())
	return list[list.size() - tail + (n - list.size()) % tail]


## Their next [about <other> <stage>] talk (Mom on Eco and Ophelia), once a
## hub stay: the first in file order they haven't had whose stage the other's
## romance has reached, else []. Stages are Romance.STAGES names (affection
## reached, romance still undecided), "together" / "friends" (decided that
## way), or "dated" (they've been out on a date, and aren't just friends).
func _about_talk(who: String, run_id: int) -> Array:
	var talks: Array = bank(who)["about"]
	if talks.is_empty() or int(state.get_value(who, "about_run", -1)) == run_id:
		return []
	var had: Array = state.get_value(who, "about_seen", [])
	var count := {}
	for talk in talks:
		# Keyed "<other> <stage> <n>" so new talks in the file don't shift old ones.
		var base := "%s %s" % [talk["who"], talk["stage"]]
		var key := "%s %d" % [base, count.get(base, 0)]
		count[base] = count.get(base, 0) + 1
		if had.has(key) or not about_reached(talk["who"], talk["stage"]):
			continue
		had.append(key)
		state.set_value(who, "about_seen", had)
		state.set_value(who, "about_run", run_id)
		return talk["lines"]
	return []


## True once `other`'s romance with Eco has got to `stage` (see _about_talk).
func about_reached(other: String, stage: String) -> bool:
	var status := Romance.status(state, other)
	if stage in Romance.STATUSES:
		return status == stage
	if stage == "dated":
		return status != "friends" and state.has_section_key(other, "date_run")
	if status != "":
		return false
	for st in Romance.STAGES:
		if st[1] == stage:
			return Romance.affection(state, other) >= int(st[0])
	return false


## The first talk of a hub stay where they're up to something (their idle
## spot) is about that, from its [spot <name>] talks, or its flirty
## [spot <name> flirt] ones once they're flirting.
func _spot_talk(who: String, run_id: int, spot: String) -> Array:
	var tiers: Dictionary = bank(who)["spot"].get(spot, {})
	if tiers.is_empty() or int(state.get_value(who, "spot_run", -1)) == run_id:
		return []
	var tier := "flirt" if tiers.has("flirt") and Romance.flirty(state, bank(who), who) else ""
	var talks: Array = tiers.get(tier, tiers.get("flirt" if tier == "" else "", []))
	if talks.is_empty():
		return []
	state.set_value(who, "spot_run", run_id)
	var key := "next_spot_%s_%s" % [spot, tier]
	var n: int = state.get_value(who, key, 0)
	state.set_value(who, key, (n + 1) % talks.size())
	return talks[n % talks.size()]


## True when talking to them now would open one of their [heart] scenes (the
## prompt hints at it).
func beat_waiting(who: String, run_id: int) -> bool:
	if not state.get_value(who, "met", false):
		return false
	var extra := Romance.TALK_GAIN if int(state.get_value(who, "warm_run", -1)) != run_id else 0
	if not Romance.next_beat(state, bank(who), who, extra).is_empty():
		return true
	var more := Family.TALK_GAIN if int(state.get_value(who, "bond_run", -1)) != run_id else 0
	return not Family.next_scene(state, bank(who), who, more).is_empty()


func romanceable(who: String) -> bool:
	return Romance.romanceable(bank(who))


func affection(who: String) -> int:
	return Romance.affection(state, who)


func has_family(who: String) -> bool:
	return Family.has_family(bank(who))


func bond(who: String) -> int:
	return Family.bond(state, who)


func _add_bond(who: String, delta: int) -> void:
	if delta == 0:
		return
	var v := Family.add(state, who, delta)
	bond_changed.emit(who, v, delta)


## Eco curls up with them (family_scene.gd stages it): one of their [cuddle]
## talks in turn, and the bond, once a hub stay. False if it isn't open yet.
func cuddle(p_npc: Node3D, run_id: int) -> bool:
	var who: String = p_npc.who
	var b := bank(who)
	if not Family.can_cuddle(state, b, who, run_id) or b["cuddle"].is_empty():
		return false
	stop()
	state.set_value(who, "cuddle_run", run_id)
	_add_bond(who, Family.CUDDLE_GAIN)
	_play(p_npc, _take_turn(who, "cuddle"))
	return true


## Eco came home sick and they look after her: one of their [sick] talks.
func care(p_npc: Node3D, run_id: int) -> bool:
	var who: String = p_npc.who
	var b := bank(who)
	if not Family.sick(state, run_id) or b["sick"].is_empty():
		return false
	stop()
	Family.cared_for(state, run_id)
	_add_bond(who, Family.CARE_GAIN)
	_play(p_npc, _take_turn(who, "sick"))
	return true


## The next talk from one of their lists, in turn.
func _take_turn(who: String, list: String) -> Array:
	var talks: Array = bank(who)[list]
	var n: int = state.get_value(who, "next_" + list, 0)
	state.set_value(who, "next_" + list, (n + 1) % talks.size())
	return talks[n % talks.size()]


func _add_affection(who: String, delta: int) -> void:
	if delta == 0:
		return
	var v := Romance.add(state, who, delta)
	affection_changed.emit(who, v, delta)


func start(p_npc: Node3D, run_id: int, won: bool) -> void:
	stop()
	var l := pick(p_npc.who, run_id, won, String(p_npc.get("spot")) if p_npc.get("spot") != null else "")
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
## their [date <place>] lines (the [date <place> m] cut when the content rating
## is Mature and they have one), else [date any], and raises affection once per
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
	_play(p_npc, date_lines(b, place))
	_scene_start()
	return true


## The lines for a date at `place` from a parsed bank (the Mature cut first).
static func date_lines(b: Dictionary, place: String) -> Array:
	if b.get("date_m", {}).has(place):
		return b["date_m"][place]
	return b["date"].get(place, b["date"].get("any", []))


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
	elif Family.has_family(bank(who)):
		_add_bond(who, int(opt["delta"]))
		if opt["flag"] == "later" and bond_scene >= 0:
			Family.unmark_scene(state, who, bond_scene)
		_react_family(who, int(opt["delta"]), opt["flag"])
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
		if bond_scene >= 0 and index < lines.size() and not _answered:
			Family.unmark_scene(state, who, bond_scene)
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
	bond_scene = -1
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
	if speaker == "eco":  # deep in Marrow's Hold her words drift off (vices.gd)
		text = Vices.confuse(text, randf(), randi())
		text = Obsession.drift(text, randf(), randi())  # or off to Ophelia, with her Keepsake in her
	if lines[index].size() > 2 and npc.has_method("mood"):
		npc.mood(lines[index][2])
		if "kiss" in lines[index][2]:
			fade_through_black(1.8)
		for w in lines[index][2]:
			if String(w).begins_with("@"):
				cue.emit(String(w).substr(1))
	# "narrator: ..." lines are stage directions: silent, no name
	var babble := _quiet(text) if speaker == "narrator" else Babble.make(speaker, text)
	var stream: AudioStream = babble["stream"]
	_times = babble["times"]
	_line_t = 0.0
	var length: float = babble["length"]
	_eco_voice.stop()
	if speaker == "eco" or speaker == "narrator":
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


## A silent line's timing (narration): letters at a steady reading pace.
static func _quiet(text: String) -> Dictionary:
	var times := PackedFloat32Array()
	for i in text.length():
		times.append(i * 0.03)
	return {"stream": null, "times": times, "length": text.length() * 0.035 + 0.8}


## Called every frame by the run manager while the hub runs. `pilot` is where
## Eco is, so walking off ends it.
func tick(delta: float, pilot: Vector3) -> void:
	if not active():
		return
	_pilot = pilot
	if not is_instance_valid(npc) or (not hold and pilot.distance_to(npc.global_position) > LEAVE_RANGE):
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
	var family := npc != null and not romanceable(npc.who) and has_family(npc.who)
	var show := npc != null and (romanceable(npc.who) or family)
	_hearts.visible = show
	_stage.visible = show
	if show:
		_hearts.fill = Family.hearts(state, npc.who) if family else Romance.hearts(state, npc.who)
		_hearts.color = HeartMeter.FAMILY if family else HeartMeter.ROMANCE
		_hearts.queue_redraw()
		_stage.text = (Family.stage(state, npc.who) if family else Romance.stage(state, npc.who)).to_upper()
		_stage.add_theme_color_override("font_color", (HeartMeter.FAMILY if family else Color(1.0, 0.6, 0.75)).lerp(Color.WHITE, 0.2) * Color(1, 1, 1, 0.8))


## "Mom loved that." under the caption after an answer in a family scene.
## Warm faces only: no blush here.
func _react_family(who: String, delta: int, flag: String) -> void:
	var name: String = NAMES.get(who, who.to_upper()).capitalize()
	var text := ""
	if flag == "later":
		text = "%s will try again another day." % name
	elif delta >= 6:
		text = "That meant the world to %s." % name
	elif delta > 0:
		text = "%s liked that." % name
	elif delta < 0:
		text = "That stung %s a little." % name
	if npc.has_method("mood"):
		if delta >= 6:
			npc.mood(["joy", "tilt"])
		elif delta > 0:
			npc.mood(["smile", "nod"])
		elif delta < 0 or flag == "later":
			npc.mood(["sad", "down"])
	if text == "":
		return
	_reaction.text = text
	_reaction.add_theme_color_override("font_color", HeartMeter.FAMILY if delta >= 0 else Color(0.6, 0.62, 0.7))
	_reaction.visible = true
	_reaction_left = 2.6


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
	const ROMANCE := Color(1.0, 0.36, 0.55)
	## Family bonds are warm gold, so the two never read alike.
	const FAMILY := Color(1.0, 0.72, 0.35)
	var fill := 0.0
	var color := ROMANCE
	const SIZE := 16.0
	const GAP := 5.0

	func _init() -> void:
		custom_minimum_size = Vector2(5 * (SIZE + GAP), SIZE + 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pink := color
		var dim := Color(color, 0.28)
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
