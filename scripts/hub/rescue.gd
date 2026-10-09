extends RefCounted
## Rescues (Mature only, like the rest of vices.gd): once Marrow, the colony
## or Cutter has his hooks in Eco, they start reaching for the people she loves.
## In the hub, every ROLL_EVERY s Eco's out and about there's a CHANCE that Mom
## or Ophelia (WHO, whoever's home) is taken, once a stay at most. Biggie runs
## in with it, and she has time() s to get to them (a marker and a countdown,
## rescue_event.gd):
##   marrow   down Marrow's basement, in her armchair, him standing over her
##   colony   in a white colony van parked by the dispensary, a Shepherd at its door
##   cutter   at Cutter's stash, a tarp off the pilgrim road
## In time, she knocks the captor down and gets them out: their bond +BOND_SAVED,
## Town's Grip (vice_looks.gd) -GRIP_SAVED, and that captor's hold on them
## -HOOK_SAVED. Too late, and the scene of what happened plays:
##   marrow   she comes home calm and quiet, and says nothing all night
##   colony   the van door opens on her with the next piece of the colony's gear
##            fitted (hub_grip.gd take())
##   cutter   Wiring: red veins lit under her skin, shaking on a crate
## and the bond -BOND_LATE, Town's Grip +GRIP_LATE, the captor's hold +HOOK_LATE.
## The colony's hold on them is their Hub Grip (hub_grip.gd); Marrow's and
## Cutter's are kept here (hooks), and show on them while it's past SHOWS_AT:
## Marrow's quiet in them, Cutter's Wiring. Each run takes FADE off.
## Saved next to the vices save (path_for()).

const Vices := preload("res://scripts/hub/vices.gd")
const Hymn := preload("res://scripts/hub/hymn.gd")
const Redline := preload("res://scripts/hub/redline.gd")
const Glass := preload("res://scripts/hub/glass.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")

const WHO := ["mom", "ophelia"]
const NAMES := {"mom": "Mom", "ophelia": "Ophelia"}
const CAPTORS := ["marrow", "colony", "cutter"]
const ROLL_EVERY := 60.0
const CHANCE := 0.1
## Seconds to get there: TIME, less up to HYMN_CUT at full Hymn (the calm slows
## her), less REDLINE_CUT for each change Redline's made to her, never under MIN_TIME.
const TIME := 90.0
const HYMN_CUT := 25.0
const REDLINE_CUT := 4.0
const MIN_TIME := 45.0
const BOND_SAVED := 15
const BOND_LATE := -10
const GRIP_SAVED := -10.0
const GRIP_LATE := 10.0
const HOOK_SAVED := -20.0
const HOOK_LATE := 20.0
const SHOWS_AT := 20.0
const FADE := 5.0
const MAX := 100.0

## Where they're taken, for the countdown.
const PLACES := {"marrow": "MARROW'S BASEMENT", "colony": "THE COLONY VAN", "cutter": "CUTTER'S STASH"}
## Biggie, running in: [who][captor].
const ALERT := {
	"marrow": "Biggie, out of breath: \"Eco! They took %s. Marrow's people. Dragged her down the cellar under the cinema. Go!\"",
	"colony": "Biggie, out of breath: \"Eco! They took %s. A colony van, by the dispensary. They're fitting her right now. Go!\"",
	"cutter": "Biggie, out of breath: \"Eco! Cutter's got %s. His stash, off the pilgrim road. You know what he does. Go!\"",
}

static var hooks := {}
## Times each has been saved, and been too late for.
static var saved := 0
static var lost := 0
static var save_path := "user://rescue.cfg"


static func allowed() -> bool:
	return Vices.allowed()


static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_rescue.cfg"


## Whether a captor has started on Eco (and so can reach for her people).
static func active(captor: String) -> bool:
	if not allowed():
		return false
	match captor:
		"marrow":
			return not Glass.broken and (Vices.hold > 0.0 or Vices.wakes > 0)
		"colony":
			return Hymn.allowed() and (Hymn.level > 0.0 or not Hymn.gear.is_empty() or Hymn.hunted)
		"cutter":
			return Redline.allowed() and Redline.catches > 0
	return false


static func active_captors() -> Array:
	return CAPTORS.filter(func(c): return active(c))


## Seconds she has to get there.
static func time() -> float:
	var t := TIME - HYMN_CUT * clampf(Hymn.level / Hymn.MAX, 0.0, 1.0) if Hymn.allowed() else TIME
	if Redline.allowed():
		t -= REDLINE_CUT * Redline.changes.size()
	return maxf(t, MIN_TIME)


## Marrow's or Cutter's hold on `who` (the colony's is their Hub Grip).
static func hook(who: String, captor: String) -> float:
	if captor == "colony":
		return HubGrip.level(who)
	return float(hooks.get(who, {}).get(captor, 0.0))


static func shows(who: String, captor: String) -> bool:
	return allowed() and captor != "colony" and hook(who, captor) >= SHOWS_AT


static func _hook_add(who: String, captor: String, by: float) -> void:
	var mine: Dictionary = hooks.get(who, {}).duplicate()
	mine[captor] = clampf(float(mine.get(captor, 0.0)) + by, 0.0, MAX)
	hooks[who] = mine


## Eco got there in time: their captor's hold eases.
static func rescued(who: String, captor: String) -> void:
	saved += 1
	if captor == "colony":
		HubGrip._raise(who, HOOK_SAVED)
		HubGrip.save()
	else:
		_hook_add(who, captor, HOOK_SAVED)
	save()


## Too late: their captor's hold deepens. Returns the colony's new piece on
## them ("" for none, or another captor).
static func too_late(who: String, captor: String) -> String:
	lost += 1
	var piece := ""
	if captor == "colony":
		piece = HubGrip.take(who)  # its next piece, and their Hymn up with it
	else:
		_hook_add(who, captor, HOOK_LATE)
	save()
	return piece


## A run's done: Marrow's and Cutter's holds fade a little.
static func run_over() -> void:
	for who in hooks:
		for captor in hooks[who]:
			_hook_add(who, captor, -FADE)
	save()


static func reset() -> void:
	hooks = {}
	saved = 0
	lost = 0


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	hooks = cfg.get_value("rescue", "hooks", {})
	saved = int(cfg.get_value("rescue", "saved", 0))
	lost = int(cfg.get_value("rescue", "lost", 0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rescue", "hooks", hooks)
	cfg.set_value("rescue", "saved", saved)
	cfg.set_value("rescue", "lost", lost)
	cfg.save(save_path)
