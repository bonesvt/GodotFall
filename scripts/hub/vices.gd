extends RefCounted
## Vices at the Rusted Halo, Solace's bar (Mature only: content_rating.gd "M").
## Eco buys drinks with scrap (armory.gd) and plays Scrapjack, the Halo's
## blackjack, at the back table (bar_screen.gd). Under Teen the bar is just
## its old lines and none of this shows.
##
## Drinks add buzz (0..MAX_BUZZ). Buzz wears off with time, in the hub and on a
## run alike, so a drink just before a run carries into it. While buzzed:
##   - the screen blurs and doubles (drunk_screen.gd),
##   - her aim drifts on its own and the gun's cone opens (player.gd, weapon.gd),
##   - her steps wander a little,
##   - but she's numb: hits hurt up to NUMB less (liquid courage).
## Switching to Teen hides the effects at once; the buzz still wears off.
## Buzz lives for the session only (static), like the hub's run counters.
##
## Smokes: packs of Night Owls from Rook. B lights one (hub or run): for
## SMOKE_TIME she's calm (aim drift cut, tighter cone) but heals slower, and
## Mom smells it on her when she gets home.
## Stims: back-alley shots from Sal's side hatch (stim_screen.gd), up to
## BELT_SIZE carried. N jabs the next one: a short burst (STIMS), then a crash
## (slower, hurts more, the view swims). Every jab adds dependence; at
## CRAVE_AT and over, a run without one gives her the shakes. Runs without a
## jab wear it down. Smokes, stims and dependence are saved per save slot.

const ContentRating := preload("res://scripts/radio/content_rating.gd")

## Buzz Rook stops serving at.
const MAX_BUZZ := 5.0
## Buzz the effects top out at (MAX_BUZZ is a bit past it, so the last drink
## before cut-off still matters if you start a run on it).
const FULL_BUZZ := 4.0
## Buzz lost per second: one drink's worth a minute.
const WEAR_OFF := 1.0 / 60.0
## Share of damage she shrugs off at full buzz.
const NUMB := 0.15
## How far her aim drifts at full buzz (degrees: yaw, pitch).
const SWAY_DEG := Vector2(2.6, 1.6)
## Extra cone (degrees) on her gun at full buzz.
const SPREAD_DEG := 1.4
## How far her steps veer at full buzz (radians).
const STAGGER := 0.28

## id -> name, scrap cost, buzz it adds, menu blurb. Water takes buzz away.
const DRINKS := {
	"lager": {"name": "Halo Lager", "cost": {"scrap": 6}, "buzz": 1.0, "blurb": "Cheap, cold and mostly water. Rook brews it in the cellar and won't say what with."},
	"rust_bucket": {"name": "Rust Bucket", "cost": {"scrap": 12}, "buzz": 1.5, "blurb": "Whiskey, bitters and something orange. Tastes like a fistfight you won."},
	"shine": {"name": "Precursor Shine", "cost": {"scrap": 20}, "buzz": 2.5, "blurb": "Moonshine from the temple hills. Glows a little in the glass. Nobody asks why."},
	"water": {"name": "Water", "cost": {}, "buzz": -1.0, "blurb": "Rook slides it over without being asked. Sobers you up a little."},
}
const ORDER := ["lager", "rust_bucket", "shine", "water"]

## Smokes: how long a cigarette keeps her calm, and the effects while it does.
const SMOKE_TIME := 90.0
const SMOKE_SWAY := 0.4
const SMOKE_SPREAD := 0.8
const SMOKE_REGEN := 0.6
const PACK := {"name": "Night Owls (5)", "cost": {"scrap": 10}, "smokes": 5, "blurb": "Black papers, gold filters. Ophelia's brand. Five to a pack."}
const MAX_SMOKES := 20

## Stims: id -> name, cost, seconds, and what they do while they last.
const STIMS := {
	"redline": {"name": "Redline", "cost": {"scrap": 30}, "time": 12.0, "speed": 1.3, "blurb": "Legs like pistons. Twelve seconds of running faster than anyone should."},
	"ironskin": {"name": "Ironskin", "cost": {"scrap": 30, "alloy": 5}, "time": 12.0, "damage": 0.6, "blurb": "Colony trauma juice. You feel the bullets. They just don't matter for a while."},
	"deadeye": {"name": "Deadeye", "cost": {"scrap": 35, "circuits": 1}, "time": 10.0, "sway": 0.0, "spread": 0.3, "blurb": "Ten seconds where your hands are stone and the world holds still."},
}
const STIM_ORDER := ["redline", "ironskin", "deadeye"]
const BELT_SIZE := 3
## The crash after a stim: how long, and how it drags.
const CRASH_TIME := 15.0
const CRASH_SPEED := 0.85
const CRASH_DAMAGE := 1.15
const CRASH_HAZE := 0.35
## Dependence: +1 a jab; cravings from CRAVE_AT; a clean run takes off CLEAN_RUN.
const CRAVE_AT := 3.0
const CLEAN_RUN := 1.5
const CRAVE_HAZE := 0.3

static var buzz := 0.0
## Drinks bought this session, for Rook's lines.
static var drinks_had := 0
## Seconds left on the cigarette she's smoking (0: none lit).
static var smoke_left := 0.0
## She's smoked since she last came home (Mom notices).
static var smoked := false
## The stim running now ("" none), its seconds left, and the crash after.
static var stim := ""
static var stim_left := 0.0
static var crash_left := 0.0
## A jab this run (no clean-run credit at the end).
static var jabbed := false
## Saved per slot.
static var smokes := 0
static var belt: Array = []
static var dependence := 0.0
static var save_path := "user://vices.cfg"


## The bar's drinks and cards are open (Mature only).
static func allowed() -> bool:
	return ContentRating.current() == "M"


static func drink_name(id: String) -> String:
	return DRINKS[id]["name"]


static func cost(id: String) -> Dictionary:
	return DRINKS[id]["cost"]


## Rook won't pour her anything stronger than water past this.
static func cut_off() -> bool:
	return buzz >= MAX_BUZZ - 0.5


## Pours `id` (the bar screen has already taken the scrap). Returns false if
## Rook won't serve it.
static func drink(id: String) -> bool:
	if not DRINKS.has(id):
		return false
	var add: float = DRINKS[id]["buzz"]
	if add > 0.0 and cut_off():
		return false
	buzz = clampf(buzz + add, 0.0, MAX_BUZZ)
	if add > 0.0:
		drinks_had += 1
	return true


## Wears the buzz off and burns down smokes and stims. Call while the game is
## running (not under a pause).
static func tick(delta: float) -> void:
	buzz = maxf(buzz - WEAR_OFF * delta, 0.0)
	smoke_left = maxf(smoke_left - delta, 0.0)
	if stim != "":
		stim_left -= delta
		if stim_left <= 0.0:
			stim = ""
			crash_left = maxf(CRASH_TIME + stim_left, 0.0)  # time past the end counts
			stim_left = 0.0
	else:
		crash_left = maxf(crash_left - delta, 0.0)


# --- smokes -------------------------------------------------------------------

static func buy_pack() -> void:
	smokes = mini(smokes + int(PACK["smokes"]), MAX_SMOKES)
	save()


## Lights one up (B). Returns false with none left, one already lit, or under Teen.
static func light_up() -> bool:
	if not allowed() or smokes <= 0 or smoke_left > 0.0:
		return false
	smokes -= 1
	smoke_left = SMOKE_TIME
	smoked = true
	save()
	return true


static func calm() -> bool:
	return smoke_left > 0.0 and allowed()


# --- stims --------------------------------------------------------------------

static func stim_name(id: String) -> String:
	return STIMS[id]["name"]


static func belt_full() -> bool:
	return belt.size() >= BELT_SIZE


## Puts a bought stim on her belt (the screen has taken the price).
static func add_stim(id: String) -> bool:
	if belt_full() or not STIMS.has(id):
		return false
	belt.append(id)
	save()
	return true


## Jabs the next stim on her belt (N). Cuts any crash short (that's the trap).
static func jab() -> String:
	if not allowed() or belt.is_empty() or stim != "":
		return ""
	stim = belt.pop_front()
	stim_left = STIMS[stim]["time"]
	crash_left = 0.0
	dependence += 1.0
	jabbed = true
	save()
	return stim


static func crashing() -> bool:
	return crash_left > 0.0 and stim == "" and allowed()


## How bad the shakes are, 0..1 (dependence at CRAVE_AT and over, nothing in her).
static func craving() -> float:
	if not allowed() or stim != "" or crash_left > 0.0 or dependence < CRAVE_AT:
		return 0.0
	return clampf((dependence - CRAVE_AT + 1.0) / 3.0, 0.0, 1.0)


## A run ended: a clean one wears dependence down.
static func run_over() -> void:
	if not jabbed:
		dependence = maxf(dependence - CLEAN_RUN, 0.0)
	jabbed = false
	save()


static func _stim_stat(key: String, default: float) -> float:
	if stim == "" or not allowed():
		return default
	return float(STIMS[stim].get(key, default))


## Move speed multiplier from stims and crashes.
static func speed_scale() -> float:
	if crashing():
		return CRASH_SPEED
	return _stim_stat("speed", 1.0)


## Health regen multiplier (smoking slows it).
static func regen_scale() -> float:
	return SMOKE_REGEN if calm() else 1.0


## Gun cone multiplier (a smoke steadies her; Deadeye most of all).
static func spread_scale() -> float:
	return _stim_stat("spread", 1.0) * (SMOKE_SPREAD if calm() else 1.0)


## How hazy the screen is: the buzz, a crash or the shakes, whichever's worst.
static func haze() -> float:
	var h := effect()
	if crashing():
		h = maxf(h, CRASH_HAZE * crash_left / CRASH_TIME + 0.1)
	return maxf(h, craving() * CRAVE_HAZE)


# --- saving -------------------------------------------------------------------

## Loads smokes, the stim belt and dependence from `path` (a save slot's).
static func open(path: String) -> void:
	save_path = path
	smokes = 0
	belt = []
	dependence = 0.0
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		smokes = cfg.get_value("vices", "smokes", 0)
		belt = cfg.get_value("vices", "belt", []).filter(func(id): return STIMS.has(id))
		dependence = cfg.get_value("vices", "dependence", 0.0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("vices", "smokes", smokes)
	cfg.set_value("vices", "belt", belt)
	cfg.set_value("vices", "dependence", dependence)
	cfg.save(save_path)


## How drunk she is for the effects, 0..1, eased in so one lager is a light
## haze and four drinks is hard going. 0 under Teen.
static func effect() -> float:
	if buzz <= 0.0 or not allowed():
		return 0.0
	var t := clampf(buzz / FULL_BUZZ, 0.0, 1.0)
	return t * (0.6 + 0.4 * t)


## How a hit is scaled while she's numb.
static func damage_scale() -> float:
	var k := 1.0 - NUMB * effect()
	if crashing():
		k *= CRASH_DAMAGE
	return k * _stim_stat("damage", 1.0)


## Her aim's drift (degrees: yaw, pitch) at time `t` (seconds): slow, uneven
## waves, so it never feels like a metronome.
static func sway(t: float) -> Vector2:
	var e := maxf(effect(), craving() * CRAVE_HAZE)
	if calm():
		e *= SMOKE_SWAY
	e *= _stim_stat("sway", 1.0)
	if e <= 0.0:
		return Vector2.ZERO
	var x := sin(t * 0.83) * 0.6 + sin(t * 1.91 + 1.3) * 0.3 + sin(t * 0.37 + 4.0) * 0.4
	var y := sin(t * 0.71 + 2.1) * 0.6 + sin(t * 1.53) * 0.3 + sin(t * 0.29 + 0.7) * 0.3
	return Vector2(x * SWAY_DEG.x, y * SWAY_DEG.y) * e


## How far her steps veer (radians) at time `t`.
static func stagger(t: float) -> float:
	return sin(t * 0.9 + 0.4) * sin(t * 0.37) * STAGGER * effect()


## Words for the HUD, or "" when sober and clean.
static func state_name() -> String:
	var out := []
	if effect() > 0.0:
		out.append("Tipsy" if buzz < 1.5 else ("Buzzed" if buzz < 3.0 else "Hammered"))
	if calm():
		out.append("Smoking")
	if stim != "" and allowed():
		out.append("%s %ds" % [stim_name(stim), ceili(stim_left)])
	elif crashing():
		out.append("Crashing")
	elif craving() > 0.0:
		out.append("Shakes")
	return "  ".join(out)


## What she's got on her for the HUD: "" under Teen or when she carries nothing.
static func pockets_text() -> String:
	if not allowed():
		return ""
	var out := []
	if smokes > 0:
		out.append("[B] smoke x%d" % smokes)
	if not belt.is_empty():
		out.append("[N] %s" % ", ".join(belt.map(func(id): return stim_name(id))))
	return "    ".join(out)


## What Eco mutters heading out on a run with drink still in her.
static func run_line() -> String:
	if buzz < 1.5:
		return "One drink. I'm fine. I'm totally fine."
	if buzz < 3.0:
		return "Okay, the ground's doing a little dance. I can dance too."
	return "Who put three of everything out here? Shoot the middle one, Eco."


## What she mutters starting a run with the shakes.
static func craving_line() -> String:
	return "Hands won't stop shaking. One Redline. Just one. ...No. Maybe."


## Clears everything in memory (tests). Doesn't touch the save.
static func reset() -> void:
	buzz = 0.0
	drinks_had = 0
	smoke_left = 0.0
	smoked = false
	stim = ""
	stim_left = 0.0
	crash_left = 0.0
	jabbed = false
	smokes = 0
	belt = []
	dependence = 0.0
