extends RefCounted
## Hymn: the colony's daily dose (Mature only, like the rest of vices.gd).
## The colony dispensary on Lantern Row (town.gd, dispensary_screen.gd) hands
## out a dose each time Eco is back in town. She can take it (her Hymn level
## rises), palm it (a timing catch, harder each time she's done it), or refuse.
## A failed palm or a refusal sets the Shepherd on her (shepherd.gd): darts that
## put Hymn in her and a pulse that plays a trigger word. If it brings her in
## she's "processed" and wakes at the dispensary wearing the next piece of its
## gear (GEAR, colony_gear.gd), and the gear stacks:
##   headphones  trigger words twice as often, a shorter window to shake them
##               (trigger_words.gd), and from any Hold, in the colony's voice
##   cuff        a dose cuff: skip the line and it counts down on the HUD, then
##               doses her where she stands
##   visor       the clarity visor: her view crowded with flashing orders,
##               turning rings and false HUD (visor_screen.gd)
##   bridge      the calm bridge (smell): every BRIDGE_EVERY s it puffs a
##               little Hymn up her nose
##   gloves      comfort gloves (touch): numb hands, reloads RELOAD_SLOW slower
##   spine       the Plumb Line (balance): colony posture, a step heavier
##               (SPINE_SPEED)
## All of it is saved next to her vices (path_for()).

const Vices := preload("res://scripts/hub/vices.gd")

const GEAR := ["headphones", "cuff", "visor", "bridge", "gloves", "spine"]
const GEAR_NAMES := {"headphones": "compliance headphones", "cuff": "dose cuff", "visor": "clarity visor",
	"bridge": "calm bridge", "gloves": "comfort gloves", "spine": "Plumb Line spine"}
## The calm bridge's puff: how often, and how much Hymn.
const BRIDGE_EVERY := 60.0
const BRIDGE_PUFF := 1.5
## The gloves' numb hands (reload time x), the spine's heavier step (speed x).
const RELOAD_SLOW := 1.3
const SPINE_SPEED := 0.94
## Hymn a dose puts in her, a Shepherd dart, and being processed.
const DOSE := 12.0
const DART := 4.0
const PROCESSED := 20.0
const MAX := 100.0
## The palm: the officer's back is turned for a slice of the bar, narrower each
## time she's done it (down to MIN_WINDOW).
const WINDOW := 0.3
const WINDOW_SHRINK := 0.05
const MIN_WINDOW := 0.1
## Seconds the dose cuff gives her to get to the line once she's back in town.
const CUFF_TIME := 180.0

static var level := 0.0
## She's been to the line (or fooled it) since she got back.
static var dosed_today := false
static var fakes := 0
static var refusals := 0
## The Shepherd is out for her.
static var hunted := false
static var captures := 0
static var gear: Array = []
static var cuff_left := CUFF_TIME
static var _puff := BRIDGE_EVERY
static var save_path := "user://hymn.cfg"


static func allowed() -> bool:
	return Vices.allowed()


static func has(piece: String) -> bool:
	return allowed() and piece in gear


## Where Hymn is saved for a vices save (user://x_vices.cfg -> user://x_hymn.cfg).
static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_hymn.cfg"


## The slice of the palm bar where the officer's looking away.
static func window() -> float:
	return maxf(WINDOW - WINDOW_SHRINK * fakes, MIN_WINDOW)


## Where that slice starts on the bar (0..1), different each visit.
static func window_start(seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf_range(0.15, 0.85 - window())


static func take_dose() -> void:
	level = minf(level + DOSE, MAX)
	dosed_today = true
	cuff_left = CUFF_TIME
	save()


## The palm: `at` is where on the bar she palmed it (0..1).
static func palm(at: float, start: float) -> bool:
	var ok := at >= start and at <= start + window()
	if ok:
		fakes += 1
		dosed_today = true
		cuff_left = CUFF_TIME
	else:
		hunted = true
	save()
	return ok


static func refuse() -> void:
	refusals += 1
	hunted = true
	save()


static func dart() -> void:
	level = minf(level + DART, MAX)


## The Shepherd brought her in: the next piece of gear goes on.
static func processed() -> String:
	captures += 1
	hunted = false
	dosed_today = true
	cuff_left = CUFF_TIME
	level = minf(level + PROCESSED, MAX)
	var piece := ""
	for g in GEAR:
		if not g in gear:
			piece = g
			gear.append(g)
			break
	save()
	return piece


## She got away: it lost her (she still owes the line).
static func escaped() -> void:
	hunted = false
	save()


static func remove(piece: String) -> void:
	gear.erase(piece)
	save()


## Each tick in the hub while she's roaming free: the dose cuff counts down
## until she's been to the line. Returns true the moment it doses her.
static func tick_cuff(delta: float) -> bool:
	if not has("cuff") or dosed_today:
		return false
	cuff_left -= delta
	if cuff_left > 0.0:
		return false
	take_dose()
	return true


## Each tick (hub or run, not paused): the calm bridge's puff. True when it puffs.
static func tick_bridge(delta: float) -> bool:
	if not has("bridge"):
		return false
	_puff -= delta
	if _puff > 0.0:
		return false
	_puff = BRIDGE_EVERY
	level = minf(level + BRIDGE_PUFF, MAX)
	return true


## Her reload time multiplier (the gloves' numb hands).
static func reload_scale() -> float:
	return RELOAD_SLOW if has("gloves") else 1.0


## Her move speed multiplier (the spine's colony step).
static func speed_scale() -> float:
	return SPINE_SPEED if has("spine") else 1.0


## A run ends: tomorrow's dose is waiting.
static func run_over() -> void:
	dosed_today = false
	cuff_left = CUFF_TIME
	save()


static func reset() -> void:
	level = 0.0
	dosed_today = false
	fakes = 0
	refusals = 0
	hunted = false
	captures = 0
	gear = []
	cuff_left = CUFF_TIME


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	level = float(cfg.get_value("hymn", "level", 0.0))
	dosed_today = bool(cfg.get_value("hymn", "dosed_today", false))
	fakes = int(cfg.get_value("hymn", "fakes", 0))
	refusals = int(cfg.get_value("hymn", "refusals", 0))
	hunted = bool(cfg.get_value("hymn", "hunted", false))
	captures = int(cfg.get_value("hymn", "captures", 0))
	gear = Array(cfg.get_value("hymn", "gear", [])).filter(func(g): return g in GEAR)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hymn", "level", level)
	cfg.set_value("hymn", "dosed_today", dosed_today)
	cfg.set_value("hymn", "fakes", fakes)
	cfg.set_value("hymn", "refusals", refusals)
	cfg.set_value("hymn", "hunted", hunted)
	cfg.set_value("hymn", "captures", captures)
	cfg.set_value("hymn", "gear", gear)
	cfg.save(save_path)
