extends RefCounted
## Romance with the people in the hub. Anyone whose dialogue file has a
## [romance] section can be romanced (Ophelia first); everyone else never
## shows any of this.
##
## Each of them has an affection score (0..100) saved with their talks in
## npc_talk.gd's save file. It goes up a little the first time Eco talks to
## them in each hub stay, and up or down with Eco's answers when a talk gives
## her a choice. Their [heart N] scenes unlock once affection reaches N and
## play once each, in order. The last one decides where it goes: an answer
## flagged !together makes them a couple (their [together] talks replace their
## everyday ones), !friends ends the romance for good, !later puts the scene
## back for another day.
##
## Dates and gifts are hooks for places outside the hub: whatever spot or shop
## calls npc_talk.date() / npc_talk.give_gift() gets the affection, and the
## [date <place>] / [gift <item>] lines if the file has them.
##
## [romance] settings, one per line:
##   likes: tape, candles          gifts they love (+GIFT_LIKE)
##   dislikes: flowers             gifts they hate (GIFT_DISLIKE)
##   date_from: 45                 affection before they'll go on a date
##   flirt_from: 60                affection from which most everyday talks
##                                 are their [flirt] ones

const MAX := 100
## Affection for the first talk in each hub stay.
const TALK_GAIN := 3
const DATE_GAIN := 8
const GIFT_LIKE := 6
const GIFT_DISLIKE := -5
const GIFT_OTHER := 1
const DATE_FROM := 45
const FLIRT_FROM := 60
## Where each stage starts, low to high. Together and friends are statuses on
## top of these, set by a scene's answer.
const STAGES := [[0, "stranger"], [10, "wary"], [25, "friend"], [45, "close"], [65, "crush"], [85, "smitten"]]
const STATUSES := ["together", "friends"]
const HEARTS := 5


static func romanceable(bank: Dictionary) -> bool:
	return bank.has("romance")


## The [romance] section as a dictionary; likes/dislikes as arrays of ids.
static func settings(bank: Dictionary) -> Dictionary:
	var out := {"likes": [], "dislikes": [], "date_from": DATE_FROM, "flirt_from": FLIRT_FROM}
	for kv in bank.get("romance", []):
		if not kv is Array:
			continue
		match kv[0]:
			"likes", "dislikes":
				var ids: Array = []
				for id in String(kv[1]).split(",", false):
					ids.append(id.strip_edges())
				out[kv[0]] = ids
			"date_from", "flirt_from":
				out[kv[0]] = int(kv[1])
	return out


static func affection(state: ConfigFile, who: String) -> int:
	return int(state.get_value(who, "affection", 0))


## Adds `delta` (clamped to 0..MAX) and returns the new score.
static func add(state: ConfigFile, who: String, delta: int) -> int:
	var v := clampi(affection(state, who) + delta, 0, MAX)
	state.set_value(who, "affection", v)
	return v


## "" while it could still go anywhere, "together" or "friends" once decided.
static func status(state: ConfigFile, who: String) -> String:
	return String(state.get_value(who, "status", ""))


static func stage(state: ConfigFile, who: String) -> String:
	var s := status(state, who)
	if s != "":
		return s
	var a := affection(state, who)
	var out: String = STAGES[0][1]
	for st in STAGES:
		if a >= int(st[0]):
			out = st[1]
	return out


## How full the heart meter is, 0..HEARTS in half steps.
static func hearts(state: ConfigFile, who: String) -> float:
	return roundf(float(affection(state, who)) / MAX * HEARTS * 2.0) / 2.0


## Applies an answer's flag: "together" / "friends" set the status, "later"
## re-arms the scene it came from (`beat`, its affection threshold).
static func apply_flag(state: ConfigFile, who: String, flag: String, beat: int) -> void:
	if flag in STATUSES:
		state.set_value(who, "status", flag)
	elif flag == "later" and beat >= 0:
		var seen: Array = state.get_value(who, "beats", [])
		seen.erase(beat)
		state.set_value(who, "beats", seen)


## The next [heart N] scene they're ready for, or {} (none waiting, or the
## romance already settled). `extra` is affection about to be added.
static func next_beat(state: ConfigFile, bank: Dictionary, who: String, extra := 0) -> Dictionary:
	if not romanceable(bank) or status(state, who) != "":
		return {}
	var a := affection(state, who) + extra
	var seen: Array = state.get_value(who, "beats", [])
	for beat in bank.get("heart", []):
		if int(beat["at"]) <= a and not seen.has(int(beat["at"])):
			return beat
	return {}


static func mark_beat(state: ConfigFile, who: String, at: int) -> void:
	var seen: Array = state.get_value(who, "beats", [])
	if not seen.has(at):
		seen.append(at)
	state.set_value(who, "beats", seen)


static func can_date(state: ConfigFile, bank: Dictionary, who: String) -> bool:
	if not romanceable(bank) or status(state, who) == "friends":
		return false
	return status(state, who) == "together" or affection(state, who) >= int(settings(bank)["date_from"])


## How a gift goes down: "like", "dislike" or "other".
static func gift_taste(bank: Dictionary, gift: String) -> String:
	var s := settings(bank)
	if s["likes"].has(gift):
		return "like"
	if s["dislikes"].has(gift):
		return "dislike"
	return "other"


static func gift_delta(taste: String) -> int:
	return {"like": GIFT_LIKE, "dislike": GIFT_DISLIKE}.get(taste, GIFT_OTHER)


## True once they flirt with Eco: from flirt_from on, or as a couple (never
## once they've settled on friends).
static func flirty(state: ConfigFile, bank: Dictionary, who: String) -> bool:
	if not romanceable(bank) or status(state, who) == "friends":
		return false
	return status(state, who) == "together" or affection(state, who) >= int(settings(bank)["flirt_from"])


## Which list their next everyday talk comes from: [any] until flirt_from,
## then mostly [flirt] (two in three); a couple mix [together] and [flirt]
## with the odd [any]. Lists they don't have are skipped.
static func talk_list(state: ConfigFile, bank: Dictionary, who: String) -> String:
	var order := ["any"]
	var st := status(state, who)
	if flirty(state, bank, who):
		order = ["flirt", "flirt", "any"]
	if romanceable(bank) and st == "together":
		order = ["together", "flirt", "together", "flirt", "any"]
	order = order.filter(func(l): return not bank.get(l, []).is_empty())
	if order.is_empty():
		return "any"
	var n := int(state.get_value(who, "talk_n", 0))
	state.set_value(who, "talk_n", n + 1)
	return order[n % order.size()]
