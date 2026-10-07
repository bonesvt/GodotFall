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
##
## Hush: glowing Precursor resin Marrow sells in the alley off Low Row
## (hush_den.gd, hush_screen.gd). A dose carries her whole next run: she hits
## harder, heals faster and grunts are slower to notice her, more so the deeper
## his Hold. Each dose raises his Hold and costs her with Mom and Ophelia. A
## run on Hush, or any run once his Hold is at TRANCE_HOLD, ends with her
## coming to in his basement under the cinema, not at the temple, short a
## little scrap. Clean runs loosen his Hold; she can walk away from him for
## good while it's under BREAK_AT, or at any Hold if Mom or Ophelia are close
## enough to her (STRONG_BOND) to pull her out.
##
## The deeper his Hold, the more it shows off the job: her posture slumps
## (eco_model.gd _slump, slump()), her words drift off mid-line (confuse()),
## and she can head out on a run with the wrong gun, knife or kit
## (wrong_gear()). The first time his Hold is full she gets the Hush courier
## suit (eco_model.gd "suit_hush"): she keeps it even after she walks away.

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

## Hush.
const HUSH_COST := {"scrap": 40, "circuits": 1}
const HOLD_PER_DOSE := 15.0
const HOLD_CLEAN_RUN := 10.0
const TRANCE_HOLD := 60.0
const BREAK_AT := 60.0
const STRONG_BOND := 50
## What a dose costs her with the people who love her.
const DOSE_ROMANCE := -4
const DOSE_BOND := -3
## What walking away wins back.
const FREE_ROMANCE := 6
const FREE_BOND := 5
## Scrap Marrow keeps from her pockets each time she comes to at his place.
const TAB := 10
## At full Hold he stops selling: she earns each dose with an errand
## (hush_den.gd ERRANDS), and roaming the hub or town, every PULL_EVERY
## seconds there's a PULL_CHANCE his pull takes her into a trance and walks
## her to his basement for one (hush_pull.gd). A run at full Hold without a
## dose in her is a run in withdrawal.
const MAX_HOLD := 100.0
const PULL_EVERY := 40.0
const PULL_CHANCE := 0.35
## Withdrawal is hard mode: shaky aim, a haze, slow healing, hits hurt more,
## heavier feet. And every EPISODE_EVERY seconds on the run there's an
## EPISODE_CHANCE the swirls come back and she walks off the job to beg him
## for another errand (hush_pull.gd episode): the run ends there.
const WITHDRAWAL_SWAY := 0.75
const WITHDRAWAL_HAZE := 0.5
const WITHDRAWAL_REGEN := 0.45
const WITHDRAWAL_DAMAGE := 1.35
const WITHDRAWAL_SPEED := 0.88
const EPISODE_EVERY := 45.0
const EPISODE_CHANCE := 0.3
## His Hold where her posture starts to go, and where it's gone all the way.
const SLUMP_FROM := 20.0
## His Hold where her words start drifting off, and the most often they do.
const CONFUSE_FROM := 50.0
const CONFUSE_MAX := 0.5
## His Hold where she can grab the wrong gear for a run, and the chance then
## (rising to WRONG_GEAR_MAX at full Hold).
const WRONG_GEAR_FROM := 60.0
const WRONG_GEAR_MIN := 0.2
const WRONG_GEAR_MAX := 0.6
## Where her lines trail off to when his Hold drifts her (confuse()).
const DRIFTS := [
	"...sorry. Lost it. What was I saying?",
	"...wait. Why did I come over here?",
	"...it's so quiet in my head today. Say that again?",
	"...hm? No. Nothing. I'm fine. I'm fine.",
	"...Marrow would know what I mean. He always knows.",
	"...is it violet in here, or is that me?",
	"...I had the end of that sentence a second ago.",
]
## What she says when she notices the wrong gear on her (wrong_gear()).
const WRONG_GEAR_LINE := "Eco looks down at what she's carrying. That's not what she picked. When did she pick it?"

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
## Hush: his Hold (0..100), a dose waiting for her next run, Hush in her this
## run, a trance due when she gets back, and whether she ever walked away.
static var hold := 0.0
static var dosed := false
static var hushed := false
static var trance := false
static var walked_away := false
## Times she's come to at his place (for his lines, in turn).
static var wakes := 0
## His errand (a hush_den.gd ERRANDS id, "" none) and whether she's done it
## and only has to go back to him. Saved.
static var errand := ""
static var errand_done := false
## His pull has taken her once since she got back (one per visit home).
static var pulled := false
## In a trance right now, walking to him (hush_pull.gd).
static var entranced := false
## This run started at full Hold with no dose in her.
static var withdrawal := false
## She walked off a run to beg him (saved): he gives her another errand when
## she comes to at his place.
static var begging := false
## She's earned the Hush courier suit (his Hold was full once): saved, kept.
static var hush_suit := false
## It's just been earned: the run manager says so once and clears it.
static var hush_suit_new := false
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


## A run starts: a dose waiting goes in.
static func run_started() -> void:
	hushed = dosed and allowed()
	withdrawal = allowed() and not hushed and hold >= MAX_HOLD
	dosed = false
	errand = ""  # whatever he wanted, she's gone without it
	errand_done = false
	entranced = false
	begging = false
	save()


## A run ended: a clean one wears dependence and his Hold down; a Hush run (or
## a deep enough Hold) sends her to his basement when she gets back.
static func run_over() -> void:
	if not jabbed:
		dependence = maxf(dependence - CLEAN_RUN, 0.0)
	jabbed = false
	if allowed() and (hushed or hold >= TRANCE_HOLD):
		trance = true
	if not hushed and not begging:  # walking off a job to beg him loosens nothing
		hold = maxf(hold - HOLD_CLEAN_RUN, 0.0)
	hushed = false
	withdrawal = false
	pulled = false
	save()


# --- Hush ---------------------------------------------------------------------

## Takes a dose from Marrow (the screen has taken the price): raises his Hold.
## `state` is the hub talks' ConfigFile (npc_talk.state): Ophelia and Mom feel it.
static func dose(state: ConfigFile = null) -> bool:
	if not allowed() or dosed:
		return false
	return _dose(state)


static func _dose(state: ConfigFile) -> bool:
	dosed = true
	hold = minf(hold + HOLD_PER_DOSE, 100.0)
	walked_away = false
	reward_check()
	if state != null:
		_nudge(state, DOSE_ROMANCE, DOSE_BOND)
	save()
	return true


## She can walk away now (not too deep, or someone close enough to pull her out).
static func can_walk_away(state: ConfigFile = null) -> bool:
	if hold <= 0.0 and not dosed:
		return false
	if hold < BREAK_AT:
		return true
	return state != null and (int(state.get_value("ophelia", "affection", 0)) >= STRONG_BOND or int(state.get_value("mom", "bond", 0)) >= STRONG_BOND)


static func walk_away(state: ConfigFile = null) -> bool:
	if not can_walk_away(state):
		return false
	hold = 0.0
	dosed = false
	trance = false
	errand = ""
	errand_done = false
	walked_away = true
	if state != null:
		_nudge(state, FREE_ROMANCE, FREE_BOND)
	save()
	return true


static func _nudge(state: ConfigFile, romance: int, bond: int) -> void:
	if state.has_section_key("ophelia", "affection"):
		state.set_value("ophelia", "affection", clampi(int(state.get_value("ophelia", "affection", 0)) + romance, 0, 100))
	if state.has_section_key("mom", "bond"):
		state.set_value("mom", "bond", clampi(int(state.get_value("mom", "bond", 0)) + bond, 0, 100))


## His Hold just reached full for the first time: the Hush courier suit is
## hers (hush_suit_new until the run manager says so). Returns whether it was now.
static func reward_check() -> bool:
	if hush_suit or hold < MAX_HOLD or not allowed():
		return false
	hush_suit = true
	hush_suit_new = true
	save()
	return true


## How far her posture has gone (0..1, eco_model.gd _slump): from SLUMP_FROM
## to full Hold. 0 under Teen.
static func slump() -> float:
	if not allowed():
		return 0.0
	return clampf((hold - SLUMP_FROM) / (MAX_HOLD - SLUMP_FROM), 0.0, 1.0)


## How often her lines drift off (0..CONFUSE_MAX), deeper in his Hold.
static func confuse_chance() -> float:
	if not allowed() or hold < CONFUSE_FROM:
		return 0.0
	return CONFUSE_MAX * clampf((hold - CONFUSE_FROM + 10.0) / (MAX_HOLD - CONFUSE_FROM + 10.0), 0.0, 1.0)


## One of Eco's lines, maybe drifting off halfway (`roll` 0..1 against
## confuse_chance(); `pick` chooses where it drifts to). Lines in quotes
## ("Eco: \"...\"") drift inside the quote.
static func confuse(text: String, roll: float, pick := 0) -> String:
	if roll >= confuse_chance() or text.length() < 12:
		return text
	var quote := text.find("\"")
	var head := text.substr(0, quote + 1) if quote >= 0 else ""
	var said := text.substr(quote + 1).trim_suffix("\"") if quote >= 0 else text
	var words := said.split(" ", false)
	var keep := maxi(2, words.size() / 2)
	var start := " ".join(words.slice(0, keep)).rstrip(".,!?;:")
	var drifted: String = start + DRIFTS[absi(pick) % DRIFTS.size()]
	return head + drifted + ("\"" if quote >= 0 else "")


## Her mixed-up gear for a run, if she grabs the wrong things (`rng` rolls):
## {"weapon": id, "knife": id, "weight": kit} with only what she got wrong
## (empty: she got it right). `guns` are the guns she owns, `tier` her suit
## tier (no kit to mix up at 0).
static func wrong_gear(rng: RandomNumberGenerator, guns: Array, gun: String, knives: Array, knife: String,
		tier: int, weight: String, weights: Array) -> Dictionary:
	if not allowed() or hold < WRONG_GEAR_FROM:
		return {}
	var chance := lerpf(WRONG_GEAR_MIN, WRONG_GEAR_MAX, (hold - WRONG_GEAR_FROM) / (MAX_HOLD - WRONG_GEAR_FROM))
	if rng.randf() >= chance:
		return {}
	var options := {}
	var other_guns := guns.filter(func(g): return g != gun)
	if not other_guns.is_empty():
		options["weapon"] = other_guns
	var other_knives := knives.filter(func(k): return k != knife)
	if not other_knives.is_empty():
		options["knife"] = other_knives
	var other_weights := weights.filter(func(w): return w != weight)
	if tier > 0 and not other_weights.is_empty():
		options["weight"] = other_weights
	if options.is_empty():
		return {}
	var keys := options.keys()
	var first: String = keys[rng.randi() % keys.size()]
	var out := {}
	for key: String in keys:
		if key == first or rng.randf() < 0.35:  # one thing for sure, maybe more
			var list: Array = options[key]
			out[key] = list[rng.randi() % list.size()]
	return out


## He's done selling: at full Hold a dose is earned with an errand.
static func earns_only() -> bool:
	return hold >= MAX_HOLD


## His pull can take her now: full Hold, nothing waiting in her, no errand
## running, not already pulled since she got back.
static func can_pull() -> bool:
	return allowed() and hold >= MAX_HOLD and not dosed and errand == "" and not pulled and not entranced


## He gives her errand `id` (pulled: it came with a trance).
static func give_errand(id: String, by_pull := false) -> void:
	errand = id
	errand_done = false
	if by_pull:
		pulled = true
	save()


## She's at errand spot `id`: true if it's the one he sent her to.
static func errand_reached(id: String) -> bool:
	if errand != id or errand_done or not allowed():
		return false
	errand_done = true
	save()
	return true


## Back to him with it done: he pays in Hush. Returns whether he did.
static func errand_paid(state: ConfigFile = null) -> bool:
	if errand == "" or not errand_done or dosed or not allowed():
		return false
	errand = ""
	errand_done = false
	return _dose(state)


## Withdrawal can take her off this run now (once per run: it ends the run).
static func can_episode() -> bool:
	return in_withdrawal() and not begging


## The swirls took her off the job: she'll come to at his place, begging.
static func walk_off_job() -> void:
	begging = true
	trance = true
	save()


## How strong the Hush is in her this run (0 none): stronger the deeper his Hold.
static func hush() -> float:
	if not hushed or not allowed():
		return 0.0
	return 1.0 + hold / 100.0


## Damage her shots deal.
static func damage_out() -> float:
	var h := hush()
	return 1.0 if h == 0.0 else 1.0 + 0.2 * h


## How quickly grunts notice her.
static func notice_scale() -> float:
	var h := hush()
	return 1.0 if h == 0.0 else 1.0 - 0.2 * h


## How strongly the Hush swirls in her eyes, 0..1 (eco_model.gd): faint after
## the first dose, full when she's his; brighter while it's in her on a run.
static func eye_swirl() -> float:
	if not allowed() or hold <= 0.0:
		return 0.0
	if entranced:
		return 3.0  # past 1 the spirals only spin faster (eco_toon.gdshaderinc)
	return clampf(0.35 + 0.65 * hold / 100.0 + (0.2 if hushed else 0.0), 0.0, 1.0)


## His Hold as a word, for Marrow's screen.
static func hold_name() -> String:
	if hold <= 0.0:
		return "None"
	if hold < 30.0:
		return "A taste"
	if hold < TRANCE_HOLD:
		return "Hooked"
	return "His"


static func _stim_stat(key: String, default: float) -> float:
	if stim == "" or not allowed():
		return default
	return float(STIMS[stim].get(key, default))


## Move speed multiplier from stims and crashes.
static func speed_scale() -> float:
	if crashing():
		return CRASH_SPEED
	return _stim_stat("speed", 1.0) * (WITHDRAWAL_SPEED if in_withdrawal() else 1.0)


## A run at full Hold with no Hush in her (0 under Teen).
static func in_withdrawal() -> bool:
	return withdrawal and allowed()


## Health regen multiplier (smoking slows it).
static func regen_scale() -> float:
	var k := SMOKE_REGEN if calm() else 1.0
	if in_withdrawal():
		k *= WITHDRAWAL_REGEN
	var h := hush()
	return k * (1.0 if h == 0.0 else 1.0 + 0.4 * h)


## Gun cone multiplier (a smoke steadies her; Deadeye most of all).
static func spread_scale() -> float:
	return _stim_stat("spread", 1.0) * (SMOKE_SPREAD if calm() else 1.0)


## How hazy the screen is: the buzz, a crash or the shakes, whichever's worst.
static func haze() -> float:
	var h := effect()
	if crashing():
		h = maxf(h, CRASH_HAZE * crash_left / CRASH_TIME + 0.1)
	if entranced and allowed():
		h = maxf(h, 0.35)
	if in_withdrawal():
		h = maxf(h, WITHDRAWAL_HAZE)
	return maxf(h, craving() * CRAVE_HAZE)


# --- saving -------------------------------------------------------------------

## Loads smokes, the stim belt and dependence from `path` (a save slot's).
static func open(path: String) -> void:
	save_path = path
	smokes = 0
	belt = []
	dependence = 0.0
	hold = 0.0
	dosed = false
	hushed = false
	trance = false
	walked_away = false
	wakes = 0
	errand = ""
	errand_done = false
	pulled = false
	entranced = false
	withdrawal = false
	begging = false
	hush_suit = false
	hush_suit_new = false
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		hush_suit = cfg.get_value("vices", "hush_suit", false)
		hold = cfg.get_value("vices", "hold", 0.0)
		dosed = cfg.get_value("vices", "dosed", false)
		trance = cfg.get_value("vices", "trance", false)
		walked_away = cfg.get_value("vices", "walked_away", false)
		wakes = cfg.get_value("vices", "wakes", 0)
		errand = cfg.get_value("vices", "errand", "")
		errand_done = cfg.get_value("vices", "errand_done", false)
		begging = cfg.get_value("vices", "begging", false)
		smokes = cfg.get_value("vices", "smokes", 0)
		belt = cfg.get_value("vices", "belt", []).filter(func(id): return STIMS.has(id))
		dependence = cfg.get_value("vices", "dependence", 0.0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("vices", "smokes", smokes)
	cfg.set_value("vices", "belt", belt)
	cfg.set_value("vices", "dependence", dependence)
	cfg.set_value("vices", "hold", hold)
	cfg.set_value("vices", "dosed", dosed)
	cfg.set_value("vices", "trance", trance)
	cfg.set_value("vices", "walked_away", walked_away)
	cfg.set_value("vices", "wakes", wakes)
	cfg.set_value("vices", "errand", errand)
	cfg.set_value("vices", "errand_done", errand_done)
	cfg.set_value("vices", "begging", begging)
	cfg.set_value("vices", "hush_suit", hush_suit)
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
	if in_withdrawal():
		k *= WITHDRAWAL_DAMAGE
	return k * _stim_stat("damage", 1.0)


## Her aim's drift (degrees: yaw, pitch) at time `t` (seconds): slow, uneven
## waves, so it never feels like a metronome.
static func sway(t: float) -> Vector2:
	var e := maxf(effect(), craving() * CRAVE_HAZE)
	if in_withdrawal():
		e = maxf(e, WITHDRAWAL_SWAY)
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
	if hush() > 0.0:
		out.append("Hushed")
	if stim != "" and allowed():
		out.append("%s %ds" % [stim_name(stim), ceili(stim_left)])
	elif crashing():
		out.append("Crashing")
	elif craving() > 0.0:
		out.append("Shakes")
	if in_withdrawal():
		out.append("Withdrawal")
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


## What she mutters starting a run in withdrawal.
static func withdrawal_line() -> String:
	return "Skin's crawling. Everything's too loud. He said he'd have work for me. I should've gone."


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
	hold = 0.0
	dosed = false
	hushed = false
	trance = false
	walked_away = false
	wakes = 0
	errand = ""
	errand_done = false
	pulled = false
	entranced = false
	withdrawal = false
	begging = false
	hush_suit = false
	hush_suit_new = false
