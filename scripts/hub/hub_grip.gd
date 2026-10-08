extends RefCounted
## The Hub Grip (Mature only, like hymn.gd): the colony's dose getting into
## the people Eco loves. Mom and Ophelia (WHO) each have their own Hymn level
## and their own set of the Shepherd's gear (colony_gear.gd, Hymn.GEAR order):
##   taken     the Shepherd brings Eco in while one of them is within RANGE m:
##             it takes the closest too. They're fitted with their next piece
##             beside her in the dispensary's back room (fitting_scene.gd) and
##             their Hymn jumps TAKEN. Their gear shows on them in the hub.
##   the town  each run while the dispensary runs, DAILY more
##   scenes    crossing 30, 60 and 90 plays that one's scene the next time Eco
##             comes home (hub_grip_scene lines in SCENES); coming back under
##             CLEAN_AT plays their way back
##   removal   Biggie at his table (gear_off_screen.gd) or Doc Imani at the
##             Mercy Clinic, a piece at a time; each piece off takes OFF Hymn
##             out of them
## What a piece does to them while it's on:
##   headphones  they don't hear Eco the first time she talks to them each stay
##   visor       they call her "citizen"
## Saved next to the vices save (path_for()).

const Hymn := preload("res://scripts/hub/hymn.gd")

const WHO := ["mom", "ophelia"]
const NAMES := {"mom": "Mom", "ophelia": "Ophelia"}
const RANGE := 8.0
const TAKEN := 20.0
const DAILY := 3.0
const OFF := 8.0
const MAX := 100.0
const STEPS := [30, 60, 90]
const CLEAN_AT := 30.0

## [speaker, text, moods] lines for each one's scenes (npc_talk.gd's line shape).
const SCENES := {
	"mom": {
		30: [["mom", "Sit down, honey. I made you tea.", ["smile"]],
			["eco", "...It's sweet. Since when do you take sugar?"],
			["mom", "The officer said it helps with the nerves. It does. It really does.", ["closed", "smile"]],
			["narrator", "For a second, her eyes flicker white."]],
		60: [["narrator", "Eco's clothes are laid out on her bed for the dispensary line. Ironed."],
			["mom", "There. You'll look so nice for them.", ["smile"]],
			["narrator", "Mom brushes Eco's hair and hums. It's the tune the whole town hums now."]],
		90: [["narrator", "Mom's at the table with a box of Hymn films, cutting them into neat strips."],
			["mom", "One for you, one for me. We'll do it together. Like when you were little and hated medicine.", ["smile"]],
			["narrator", "She holds one out on her fingertip, and waits."]],
		"clean": [["mom", "Eco? Eco. Oh, sweetheart.", ["sad"]],
			["mom", "I didn't know where I'd gone. I kept smiling and I didn't know why.", ["sad", "down"]],
			["narrator", "She holds on to Eco for a long time."]],
	},
	"ophelia": {
		30: [["ophelia", "You went out without saying bye.", ["smile"]],
			["ophelia", "That's okay. You came back.", ["smile"]],
			["narrator", "No sulking. No smoke. Just that smile. It's wrong, and Eco knows it."]],
		60: [["narrator", "Ophelia's got a grey colony armband on, and she's holding out another."],
			["ophelia", "So they know we're together.", ["smile", "tilt"]],
			["narrator", "Her violet streak's been dyed white."]],
		90: [["narrator", "Ophelia takes Eco's hand and presses something into her palm. A Hymn film. She isn't hiding it."],
			["ophelia", "I want us both to be calm. Forever.", ["smile"]],
			["narrator", "Her eyes are flat white rings."]],
		"clean": [["ophelia", "I'm... I'm me. I think I'm me?", ["sad"]],
			["ophelia", "Don't let them do that to me again. Don't let them do that to you.", ["sad", "down"]]],
	},
}

static var levels := {}
static var gear := {}
## The last scene step each has had (0, 30, 60, 90), and scenes waiting to play.
static var seen := {}
static var pending: Array = []
## Who's been heard from this stay (the headphones' first-talk deafness).
static var heard := {}
static var save_path := "user://hub_grip.cfg"


static func allowed() -> bool:
	return Hymn.allowed()


static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_hub_grip.cfg"


static func level(who: String) -> float:
	return float(levels.get(who, 0.0))


static func gear_of(who: String) -> Array:
	return gear.get(who, [])


static func has(who: String, piece: String) -> bool:
	return allowed() and piece in gear_of(who)


## The closest of WHO within RANGE of `at` ("" for none): `positions` is {who: Vector3}.
static func closest(at: Vector3, positions: Dictionary) -> String:
	var best := ""
	var best_d := RANGE
	for who in positions:
		if not who in WHO:
			continue
		var d: float = (positions[who] as Vector3).distance_to(at)
		if d <= best_d:
			best = who
			best_d = d
	return best


## The Shepherd took `who` with Eco: their next piece goes on. Returns it ("" none left).
static func take(who: String) -> String:
	var mine: Array = gear_of(who).duplicate()
	var piece := ""
	for g in Hymn.GEAR:
		if not g in mine:
			piece = g
			mine.append(g)
			break
	gear[who] = mine
	_raise(who, TAKEN)
	save()
	return piece


static func remove(who: String, piece: String) -> void:
	var mine: Array = gear_of(who).duplicate()
	mine.erase(piece)
	gear[who] = mine
	_raise(who, -OFF)
	save()


## A run's done: the dispensary's been running all day.
static func run_over() -> void:
	if not allowed():
		return
	for who in WHO:
		_raise(who, DAILY)
	heard.clear()
	save()


static func _raise(who: String, by: float) -> void:
	var before := level(who)
	var now := clampf(before + by, 0.0, MAX)
	levels[who] = now
	var step := int(seen.get(who, 0))
	for s in STEPS:
		if now >= s and step < s:
			step = s
			pending.append([who, s])
	if now < CLEAN_AT and step >= int(STEPS[0]) and before >= CLEAN_AT:
		step = 0
		pending.append([who, "clean"])
	seen[who] = step


## The next scene waiting for `present` (who's in the hub): [who, lines], or [].
static func next_scene(present: Array) -> Array:
	for i in pending.size():
		var p: Array = pending[i]
		if p[0] in present:
			pending.remove_at(i)
			save()
			return [p[0], SCENES[p[0]][p[1]]]
	return []


## The first time Eco talks to `who` this stay with the headphones on them,
## they don't hear her. True if that's now.
static func deaf_now(who: String) -> bool:
	if not has(who, "headphones") or heard.get(who, false):
		heard[who] = true
		return false
	heard[who] = true
	return true


static func reset() -> void:
	levels = {}
	gear = {}
	seen = {}
	pending = []
	heard = {}


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	levels = cfg.get_value("grip", "levels", {})
	gear = cfg.get_value("grip", "gear", {})
	for who in gear:
		gear[who] = Hymn.migrate(gear[who])
	seen = cfg.get_value("grip", "seen", {})
	pending = cfg.get_value("grip", "pending", [])


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("grip", "levels", levels)
	cfg.set_value("grip", "gear", gear)
	cfg.set_value("grip", "seen", seen)
	cfg.set_value("grip", "pending", pending)
	cfg.save(save_path)
