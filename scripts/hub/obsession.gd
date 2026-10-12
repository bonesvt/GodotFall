extends RefCounted
## Ophelia's obsession (Mature only, like vices.gd). Once she and Eco are
## together (romance.gd), she keeps count of whether Eco comes to see her
## before heading out on a run:
##   skip once      she's upset: the next time Eco tries to talk, she won't
##                  (talk_to: an angry line, then she turns away)
##   skip again     SKIPS_TO_OBSESS in a row and her obsession starts; every
##                  skip after that adds OBSESS_PER_SKIP (0..100)
##   seeing her     before a run brings it down a little (SEEN_EASE)
## From LACE_AT up she starts giving Eco packs of Night Owls (vices.gd smokes),
## once a stay when Eco comes to see her, and she's laced every one of them with
## Keepsake, a rose-coloured something she makes herself. Eco doesn't know:
## each laced one she lights (B) puts LACE in her (keepsake, 0..100). Their smoke
## date stays shut while Keepsake's in her (date_locked()). Keepsake in her:
##   rose spirals in her eyes (eco_model.gd, eco_toon swirl_tint)
##   a pull home to Ophelia on runs: a rose craving that builds with time away
##   (crave, craving_screen.gd tints it rose) and her lines drifting to her (drift())
## Keepsake shows: a tin in Ophelia's tent, the jar and her stained Night Owls
## (hub_rooms.gd "ophelia_papers", there while it's in Eco). Finding them sets up
## the confrontation the next time Eco talks to her (obsession_screen.gd):
##   help her       both of them get better: her obsession and Eco's Keepsake
##                  wear off over runs (HELP_EASE, KEEPSAKE_EASE), no more packs
##   walk away      it stays: she doesn't stop, and it gets worse
## It's a betrayal: Ophelia drugged her, and the game never pretends otherwise.
## Saved next to the vices save (path_for()).

const Vices := preload("res://scripts/hub/vices.gd")

const SKIPS_TO_OBSESS := 2
const OBSESS_PER_SKIP := 25.0
const SEEN_EASE := 10.0
const LACE_AT := 50.0
const LACE := 8.0
## Night Owls in each pack she gives Eco.
const PACK := 5
const MAX := 100.0
## Each run: how fast it fades once Eco's helped her, and on its own.
const HELP_EASE := 25.0
const KEEPSAKE_EASE := 20.0
const KEEPSAKE_FADE := 5.0
## On a run: seconds away from her until the pull home is all the way up, at
## a little Keepsake and at full.
const AWAY_LIGHT := 600.0
const AWAY_FULL := 240.0
## Her lines drifting to Ophelia: the chance at full Keepsake.
const DRIFT_MAX := 0.45
const DRIFTS := [
	"...I should get back to Ophelia.",
	"...Ophelia would like this.",
	"...is she waiting up for me?",
	"...I miss her. Is that weird? It's been an hour.",
	"...she smells like roses. Did you know that?",
]

static var skips := 0
## She's upset: Eco didn't come and see her before the last run.
static var upset := false
static var meter := 0.0
static var keepsake := 0.0
## Eco found the papers in her tent; the talk comes next.
static var found := false
## How the talk went: "", "helped" or "left".
static var resolved := ""
## The stay (runs_ended) Eco last talked to her in.
static var seen_stay := -1
## Laced Night Owls in Eco's pockets, and the stay Ophelia last gave her a pack.
static var laced := 0
static var gift_stay := -1
## The pull home on this run, 0..1 (not saved).
static var crave := 0.0
static var _away := 0.0
static var save_path := "user://obsession.cfg"

static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_obsession.cfg"


## Eco's talked to her this stay (talk_to). Returns the line to play instead
## of her usual talk when she's upset ("" to talk as usual).
static func saw(stay: int) -> String:
	seen_stay = stay
	if not upset:
		return ""
	upset = false
	save()
	return UPSET_LINES[mini(skips, UPSET_LINES.size()) - 1] if skips > 0 else ""


const UPSET_LINES := [
	"Ophelia (angry, lookaway): \"Oh. You're back. You didn't even come and say bye.\"",
	"Ophelia (angry): \"Again? You just... left. Again. Do you know what it's like, waiting here?\"",
	"Ophelia (sad, down): \"I sat by the gate the whole time. Don't. Don't say sorry. Just... don't go without me again.\"",
]


## A run starts from the hub: did Eco come to see her first? (`together`:
## they're together; `stay`: this stay's runs_ended.)
static func run_started(together: bool, stay: int) -> void:
	_away = 0.0
	crave = 0.0
	if not together:
		return
	if seen_stay == stay:
		skips = 0
		if resolved != "left":
			meter = maxf(meter - SEEN_EASE, 0.0)
	else:
		skips += 1
		upset = true
		if skips >= SKIPS_TO_OBSESS and resolved != "helped":
			meter = minf(meter + OBSESS_PER_SKIP, MAX)
	save()


## Eco came to see her: past LACE_AT she presses a pack of her Night Owls on
## her, once a stay. True if she did (the run manager adds the smokes).
static func give_pack(stay: int) -> bool:
	if meter < LACE_AT or resolved == "helped" or gift_stay == stay:
		return false
	gift_stay = stay
	laced += PACK
	save()
	return true


## Eco lights a Night Owl (B): if it's one of Ophelia's, Keepsake goes in.
## True when it was laced.
static func light_up() -> bool:
	if laced <= 0:
		return false
	laced -= 1
	keepsake = minf(keepsake + LACE, MAX)
	save()
	return true


## Their smoke date's off while Keepsake's in her.
static func date_locked() -> bool:
	return keepsake > 0.0


## Each tick on a run: the pull home builds with time away from her.
static func tick_run(delta: float) -> void:
	if keepsake <= 0.0:
		crave = 0.0
		return
	_away += delta
	var k := keepsake / MAX
	crave = clampf(_away / lerpf(AWAY_LIGHT, AWAY_FULL, k), 0.0, 1.0) * (0.4 + 0.6 * k)


## How strongly the rose shows in her eyes, 0..1.
static func eyes() -> float:
	return clampf(keepsake / MAX, 0.0, 1.0)


## The rose papers are in Ophelia's tent for Eco to find.
static func papers_there() -> bool:
	return keepsake > 0.0 and not found


static func find_papers() -> void:
	found = true
	save()


## The talk with her is waiting (Eco found the papers and hasn't had it out).
static func talk_waiting() -> bool:
	return found and resolved == ""


static func resolve(how: String) -> void:
	resolved = how
	if how == "left":
		meter = MAX
	else:
		laced = 0  # Eco throws out what's left of her packs
	save()


## A run ends: the pull fades, and it all wears off once Eco's helped her.
static func run_over() -> void:
	crave = 0.0
	_away = 0.0
	if resolved == "helped":
		meter = maxf(meter - HELP_EASE, 0.0)
		keepsake = maxf(keepsake - KEEPSAKE_EASE, 0.0)
	else:
		keepsake = maxf(keepsake - KEEPSAKE_FADE, 0.0)
	save()


## One of Eco's lines, drifting off to Ophelia with Keepsake in her: `roll`
## (0..1) under the chance cuts it and adds a drift (`pick` chooses which).
static func drift(text: String, roll: float, pick := 0) -> String:
	var chance := DRIFT_MAX * eyes()
	if roll >= chance or text.length() < 12:
		return text
	var quoted := text.ends_with("\"")
	var body := text.trim_suffix("\"") if quoted else text
	var cut := body.rfind(" ", int(body.length() * 0.55))
	if cut <= 0:
		cut = body.length()
	return body.substr(0, cut) + DRIFTS[pick % DRIFTS.size()] + ("\"" if quoted else "")


static func reset() -> void:
	skips = 0
	upset = false
	meter = 0.0
	keepsake = 0.0
	found = false
	resolved = ""
	seen_stay = -1
	laced = 0
	gift_stay = -1
	crave = 0.0
	_away = 0.0


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	skips = int(cfg.get_value("obsession", "skips", 0))
	upset = bool(cfg.get_value("obsession", "upset", false))
	meter = float(cfg.get_value("obsession", "meter", 0.0))
	keepsake = float(cfg.get_value("obsession", "keepsake", 0.0))
	found = bool(cfg.get_value("obsession", "found", false))
	resolved = String(cfg.get_value("obsession", "resolved", ""))
	seen_stay = int(cfg.get_value("obsession", "seen_stay", -1))
	laced = int(cfg.get_value("obsession", "laced", 0))
	gift_stay = int(cfg.get_value("obsession", "gift_stay", -1))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("obsession", "skips", skips)
	cfg.set_value("obsession", "upset", upset)
	cfg.set_value("obsession", "meter", meter)
	cfg.set_value("obsession", "keepsake", keepsake)
	cfg.set_value("obsession", "found", found)
	cfg.set_value("obsession", "resolved", resolved)
	cfg.set_value("obsession", "seen_stay", seen_stay)
	cfg.set_value("obsession", "laced", laced)
	cfg.set_value("obsession", "gift_stay", gift_stay)
	cfg.save(save_path)