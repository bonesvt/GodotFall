extends RefCounted
## Pip's Velvet (the Still behind the dressing room, downtown_below.gd), Mature
## only. Her own drug, cooked from Hush she skims off Marrow and Glass she buys
## off the colony, and the newest, least finished thing in the valley.
##
##   The offer   once Eco has found the Still, the next time she talks to Pip,
##               Pip asks her to be her test subject: she's new at this, Eco
##               has had Marrow's Hush in her and knows what a drug does to a
##               body ([velvet offer] in dialogue/npc/pip_M.txt). No: the
##               offer stands, and a note on the Still's bench takes it back.
##   Check-ups   yes: once a day (a run apart), twelve of them, at the Still
##               (hub/velvet_scene.gd stages [velvet 1]..[velvet 12]). Pip
##               doses with her, same glass, same measure, and writes down
##               what it does to them both. On day 11 she offers to stop.
##   On a run    a check-up's dose rides along on the next run: harder shots,
##               faster feet, hits that land softer, quicker healing. And the
##               drop (run/velvet_run.gd): every so often her body just stops,
##               the world goes violet and black, and it costs her health.
##               Mixed with Hush in her, or Glass cracked, the drop can kill.
##   Always      every dose builds up (level, 0..100) and takes max health with
##               it; a run without it wears some off. Past WITHDRAW_AT, a run
##               without a dose is withdrawal: the shakes, the cold, the crave.
##
## The most dangerous thing anyone sells in Solace, because nobody's finished
## making it. Saved per slot next to the vices save (open()).

const Vices := preload("res://scripts/hub/vices.gd")
const Glass := preload("res://scripts/hub/glass.gd")

const CHECKUPS := 12
## Check-ups that are no dose (day 11: Pip offers to stop instead).
const NO_DOSE := [11]
## How much each dose builds up: a base and a step per day (the batches get
## stronger), up to MAX_LEVEL.
const LEVEL_BASE := 6.0
const LEVEL_STEP := 1.0
const MAX_LEVEL := 100.0
## A run without a dose wears this much off.
const CLEAN_RUN := 8.0
## Max health it takes at MAX_LEVEL.
const HEALTH_AT_MAX := 0.35
## Withdrawal: a run without a dose once it's built up this far, after this
## many check-ups.
const WITHDRAW_AT := 30.0
const WITHDRAW_AFTER := 3

## On a dose: her shots (plus a little a day), her feet, the hits she takes,
## her healing.
const DOSE_DAMAGE := 1.25
const DOSE_DAMAGE_STEP := 0.01
const DOSE_SPEED := 1.15
const DOSE_HURT := 0.75
const DOSE_REGEN := 1.3
## In withdrawal.
const SHAKES_SPEED := 0.9
const SHAKES_HURT := 1.3
const SHAKES_REGEN := 0.7

## The drop on a dosed run: a roll every DROP_EVERY seconds, the chance rising
## with the level, much higher mixed with Hush or Glass; DROP_TIME seconds
## frozen; a cut of her max health, rising with the level.
const DROP_EVERY := 45.0
const FIRST_DROP := 30.0
const DROP_CHANCE := 0.15
const DROP_CHANCE_LEVEL := 0.35
const DROP_CHANCE_MIXED := 0.3
const DROP_TIME := 3.0
const DROP_HURT := 0.15
const DROP_HURT_LEVEL := 0.2

const DOSE_LINE := "Pip's Velvet is still in her from the check-up. Everything's warm, and fast, and a beat behind her."
const SHAKES_LINE := "No Velvet today. Her hands won't stop shaking, and the cold goes all the way in."
const DROP_LINES := [
	"The Velvet drops out from under her. The world goes violet, then black, then very far away.",
	"Her legs stop answering. Somewhere a long way off, Pip is counting.",
	"Gold light, a porch swing, an orange peel. Then the field again, and the grunts, and blood in her mouth.",
	"Her heart skips, and skips, and forgets to come back for a moment.",
]
const MIXED_LINE := "Hush and Velvet meet somewhere behind her eyes, and they don't get along."

## Eco has been through the cupboard into the Still.
static var found := false
## "" not asked, "no" turned down, "yes" on the trial, "out" stopped on day 11,
## "done" all twelve.
static var state := ""
static var checkups := 0
static var level := 0.0
## Runs since the save began (a check-up is once a day: once a run apart), and
## the day of the last check-up.
static var day := 0
static var last_day := -1
## A check-up's dose waiting for the next run, and the run it's in.
static var dosed := false
static var on_run := false
static var withdrawal := false
## Drops she's had, ever (and the deadly ones).
static var drops := 0
static var save_path := "user://velvet.cfg"


static func allowed() -> bool:
	return Vices.allowed()


## Eco went through the cupboard.
static func find() -> void:
	if found:
		return
	found = true
	save()


## Pip asks the next time Eco talks to her.
static func offer_due() -> bool:
	return allowed() and found and state == ""


## Her answer to a velvet_ choice ("velvet_yes", "velvet_no", day 11's
## "velvet_stop" or "velvet_go").
static func answer(flag: String) -> void:
	match flag:
		"velvet_yes":
			if state in ["", "no"]:
				state = "yes"
				last_day = day  # "Tomorrow, then."
		"velvet_no":
			if state == "":
				state = "no"
		"velvet_stop":
			if state == "yes":
				state = "out"
		"velvet_go":
			pass
	save()


static func on_trial() -> bool:
	return allowed() and state == "yes" and checkups < CHECKUPS


## Today's check-up is waiting at the Still.
static func checkup_due() -> bool:
	return on_trial() and last_day != day


## Which check-up is next (1..12).
static func next_checkup() -> int:
	return mini(checkups + 1, CHECKUPS)


## A check-up starts: the day's dose goes in (both of them; Pip's notes are
## her business). Returns its number, or 0 if none was due.
static func checkup() -> int:
	if not checkup_due():
		return 0
	checkups += 1
	last_day = day
	if not checkups in NO_DOSE:
		level = minf(level + LEVEL_BASE + LEVEL_STEP * checkups, MAX_LEVEL)
		dosed = true
	if checkups >= CHECKUPS:
		state = "done"
	save()
	return checkups


## A run starts: a dose waiting goes in; without one, once it's built up,
## she's in withdrawal.
static func run_started() -> void:
	on_run = dosed and allowed()
	dosed = false
	withdrawal = allowed() and not on_run and level >= WITHDRAW_AT and checkups >= WITHDRAW_AFTER
	save()


## A run ended: a day passes, and one without a dose wears some off her.
static func run_over() -> void:
	if not on_run:
		level = maxf(level - CLEAN_RUN, 0.0)
	on_run = false
	withdrawal = false
	day += 1
	save()


## Dosed, this run.
static func on() -> bool:
	return allowed() and on_run


static func shakes() -> bool:
	return allowed() and withdrawal


# --- what it does to her ------------------------------------------------------

static func damage_out() -> float:
	return DOSE_DAMAGE + DOSE_DAMAGE_STEP * checkups if on() else 1.0


static func speed_scale() -> float:
	return DOSE_SPEED if on() else (SHAKES_SPEED if shakes() else 1.0)


## The damage she takes.
static func damage_scale() -> float:
	return DOSE_HURT if on() else (SHAKES_HURT if shakes() else 1.0)


static func regen_scale() -> float:
	return DOSE_REGEN if on() else (SHAKES_REGEN if shakes() else 1.0)


## Her max health under what's built up.
static func health_scale() -> float:
	if not allowed():
		return 1.0
	return 1.0 - HEALTH_AT_MAX * level / MAX_LEVEL


## The crave the craving screen and the HUD bar show, 0..1.
static func crave() -> float:
	return clampf(level / MAX_LEVEL, 0.0, 1.0) * 0.9 if shakes() else 0.0


## Hush in her or Glass cracked, on top of it.
static func mixed() -> bool:
	return on() and (Vices.hush() > 0.0 or Glass.focusing())


## The chance of a drop at each roll.
static func drop_chance() -> float:
	if not on():
		return 0.0
	return clampf(DROP_CHANCE + DROP_CHANCE_LEVEL * level / MAX_LEVEL + (DROP_CHANCE_MIXED if mixed() else 0.0), 0.0, 1.0)


## How much of her max health a drop takes.
static func drop_hurt() -> float:
	return DROP_HURT + DROP_HURT_LEVEL * level / MAX_LEVEL


## Words for the HUD's status, or "".
static func state_name() -> String:
	if not allowed():
		return ""
	if on():
		return "Velvet"
	if shakes():
		return "Velvet withdrawal"
	if level > 0.0:
		return "Velvet %d%%" % roundi(level)
	return ""


# --- saving -------------------------------------------------------------------

## The save next to the vices save `vices_path`.
static func path_for(vices_path: String) -> String:
	return vices_path.get_basename() + "_velvet.cfg"


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	found = cfg.get_value("velvet", "found", false)
	state = cfg.get_value("velvet", "state", "")
	checkups = cfg.get_value("velvet", "checkups", 0)
	level = cfg.get_value("velvet", "level", 0.0)
	day = cfg.get_value("velvet", "day", 0)
	last_day = cfg.get_value("velvet", "last_day", -1)
	dosed = cfg.get_value("velvet", "dosed", false)
	drops = cfg.get_value("velvet", "drops", 0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("velvet", "found", found)
	cfg.set_value("velvet", "state", state)
	cfg.set_value("velvet", "checkups", checkups)
	cfg.set_value("velvet", "level", level)
	cfg.set_value("velvet", "day", day)
	cfg.set_value("velvet", "last_day", last_day)
	cfg.set_value("velvet", "dosed", dosed)
	cfg.set_value("velvet", "drops", drops)
	cfg.save(save_path)


## Clears everything in memory (tests). Doesn't touch the save.
static func reset() -> void:
	found = false
	state = ""
	checkups = 0
	level = 0.0
	day = 0
	last_day = -1
	dosed = false
	on_run = false
	withdrawal = false
	drops = 0
