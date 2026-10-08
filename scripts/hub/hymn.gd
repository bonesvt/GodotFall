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
##   gloves      comfort gloves (touch): numb hands that won't come apart: she has
##               to two-hand her one-handed guns, so reloads are RELOAD_SLOW
##               slower and her shots spread GLOVE_SPREAD wider
##   spine       the Plumb Line (balance): colony posture, a step heavier
##               (SPINE_SPEED)
##   band        the Processed tracker band: heavy grey prison band at her throat,
##               a blinking light and a small speaker. Moving fast (over
##               BAND_SPEED) its speaker pings every BAND_EVERY s: on a run every
##               enemy in BAND_RANGE hears it like a shot, and in town the
##               Shepherd does. While the Shepherd hunts her it also reports
##               where she is every BAND_TRACK s, its pulse locks the band for
##               BAND_LOCK s, and running from it in its sight more than
##               STUN_RANGE m off stuns her every STUN_EVERY s (shepherd.gd).
##               Every Processed NPC wears the same one (hub_grip.gd).
## Biggie can get a piece off at the folding table in his tent (gear_off_screen.gd):
## one try each time she's back in town, a steady-hand job (STEADY: how much room
## he has with each piece), and every slip shocks her (SLIP Hymn) and it stays on.
## All of it is saved next to her vices (path_for()).

const Vices := preload("res://scripts/hub/vices.gd")

const GEAR := ["headphones", "cuff", "visor", "bridge", "gloves", "spine", "band", "crown"]
const GEAR_NAMES := {"headphones": "compliance headphones", "cuff": "dose cuff", "visor": "clarity visor",
	"bridge": "calm bridge", "gloves": "comfort gloves", "spine": "Plumb Line spine", "band": "tracker band", "crown": "Crown"}
## How much room Biggie's hand has getting each piece off (the width of the
## steady band, 0..1): the visor's cups on her eyes and the spine least of all.
const STEADY := {"headphones": 0.22, "cuff": 0.2, "visor": 0.12, "bridge": 0.18, "gloves": 0.2, "spine": 0.1, "band": 0.15, "crown": 0.08}
## Clean holds he needs in a row (pins, needles, cups, tubes, seals, segments).
const HOLDS := 3
## Hymn a slip shocks into her.
const SLIP := 5.0
## The calm bridge's puff: how often, and how much Hymn.
const BRIDGE_EVERY := 60.0
const BRIDGE_PUFF := 1.5
## The Crown, last of all: it ties every piece together. While it's on, Hymn
## never falls below CROWN_FLOOR, his words come in half the time (trigger_words.gd),
## and Biggie can't touch it until everything else is off her (crown_locked()).
const CROWN_FLOOR := 80.0
## The tracker band's speaker: how fast she has to be moving for it to ping,
## how often, how far it carries.
const BAND_SPEED := 6.0
const BAND_EVERY := 0.9
const BAND_RANGE := 22.0
## While the Shepherd hunts her (shepherd.gd): how often the band reports where
## she is, how long its lock holds her, and the stun for running.
const BAND_TRACK := 5.0
const BAND_LOCK := 1.5
const STUN_RANGE := 12.0
const STUN_EVERY := 8.0
const STUN_HOLD := 0.9
## The gloves' numb hands (reload time x), the spine's heavier step (speed x).
const RELOAD_SLOW := 1.3
const GLOVE_SPREAD := 1.35
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
static var _band_t := 0.0
## Biggie's had a go this time in town.
static var biggie_tried := false
## Doc Imani's had a go this time in town (gear_off_screen.gd, the clinic).
static var doc_tried := false
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


## The Crown holds her Hymn up.
static func _crown_floor() -> void:
	if has("crown"):
		level = maxf(level, CROWN_FLOOR)


## The Crown can't come off while anything else is still on her.
static func crown_locked() -> bool:
	return "crown" in gear and gear.size() > 1


## A saved set of gear in today's pieces: the old Hymn bell and detention
## collar are the tracker band now.
static func migrate(old: Array) -> Array:
	var out: Array = []
	for g in old:
		var piece: String = "band" if g in ["bell", "collar"] else String(g)
		if piece in GEAR and not piece in out:
			out.append(piece)
	return out


## Each tick: true when the band's speaker pings (she's on the move, fast, with it on).
static func tick_band(delta: float, speed: float) -> bool:
	if not has("band") or speed < BAND_SPEED:
		_band_t = minf(_band_t, 0.2)
		return false
	_band_t -= delta
	if _band_t > 0.0:
		return false
	_band_t = BAND_EVERY
	return true


## Her reload time multiplier (the gloves' numb hands).
static func reload_scale() -> float:
	return RELOAD_SLOW if has("gloves") else 1.0


## Her gun's spread multiplier (the gloves hold her hands together on a one-handed grip).
static func spread_scale() -> float:
	return GLOVE_SPREAD if has("gloves") else 1.0


## Her move speed multiplier (the spine's colony step).
static func speed_scale() -> float:
	return SPINE_SPEED if has("spine") else 1.0


## Biggie's band for piece, narrower the more Hymn's in her.
static func steady(piece: String) -> float:
	return float(STEADY.get(piece, 0.15)) * lerpf(1.0, 0.7, level / MAX)


## His try at piece came off (true: it's off her) or slipped (a shock).
static func biggie_try(piece: String, clean: bool) -> void:
	biggie_tried = true
	if clean:
		gear.erase(piece)
	else:
		level = minf(level + SLIP, MAX)
	save()


## A run ends: tomorrow's dose is waiting.
static func run_over() -> void:
	_crown_floor()
	biggie_tried = false
	doc_tried = false
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
	biggie_tried = false
	doc_tried = false
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
	gear = migrate(cfg.get_value("hymn", "gear", []))
	biggie_tried = bool(cfg.get_value("hymn", "biggie_tried", false))


static func save() -> void:
	_crown_floor()
	var cfg := ConfigFile.new()
	cfg.set_value("hymn", "level", level)
	cfg.set_value("hymn", "dosed_today", dosed_today)
	cfg.set_value("hymn", "fakes", fakes)
	cfg.set_value("hymn", "refusals", refusals)
	cfg.set_value("hymn", "hunted", hunted)
	cfg.set_value("hymn", "captures", captures)
	cfg.set_value("hymn", "gear", gear)
	cfg.set_value("hymn", "biggie_tried", biggie_tried)
	cfg.save(save_path)
