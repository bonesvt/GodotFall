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

static var buzz := 0.0
## Drinks bought this session, for Rook's lines.
static var drinks_had := 0


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


## Wears the buzz off. Call while the game is running (not under a pause).
static func tick(delta: float) -> void:
	buzz = maxf(buzz - WEAR_OFF * delta, 0.0)


## How drunk she is for the effects, 0..1, eased in so one lager is a light
## haze and four drinks is hard going. 0 under Teen.
static func effect() -> float:
	if buzz <= 0.0 or not allowed():
		return 0.0
	var t := clampf(buzz / FULL_BUZZ, 0.0, 1.0)
	return t * (0.6 + 0.4 * t)


## How a hit is scaled while she's numb.
static func damage_scale() -> float:
	return 1.0 - NUMB * effect()


## Her aim's drift (degrees: yaw, pitch) at time `t` (seconds): slow, uneven
## waves, so it never feels like a metronome.
static func sway(t: float) -> Vector2:
	var e := effect()
	if e <= 0.0:
		return Vector2.ZERO
	var x := sin(t * 0.83) * 0.6 + sin(t * 1.91 + 1.3) * 0.3 + sin(t * 0.37 + 4.0) * 0.4
	var y := sin(t * 0.71 + 2.1) * 0.6 + sin(t * 1.53) * 0.3 + sin(t * 0.29 + 0.7) * 0.3
	return Vector2(x * SWAY_DEG.x, y * SWAY_DEG.y) * e


## How far her steps veer (radians) at time `t`.
static func stagger(t: float) -> float:
	return sin(t * 0.9 + 0.4) * sin(t * 0.37) * STAGGER * effect()


## A word for the HUD, or "" when sober.
static func state_name() -> String:
	if effect() <= 0.0:
		return ""
	if buzz < 1.5:
		return "Tipsy"
	if buzz < 3.0:
		return "Buzzed"
	return "Hammered"


## What Eco mutters heading out on a run with drink still in her.
static func run_line() -> String:
	if buzz < 1.5:
		return "One drink. I'm fine. I'm totally fine."
	if buzz < 3.0:
		return "Okay, the ground's doing a little dance. I can dance too."
	return "Who put three of everything out here? Shoot the middle one, Eco."


## Clears the buzz (new game, tests).
static func reset() -> void:
	buzz = 0.0
	drinks_had = 0
