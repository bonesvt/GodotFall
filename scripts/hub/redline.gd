extends RefCounted
## Redline: Cutter's drug (cutter.gd), Mature only like the rest of the vices.
## Ophelia's old dealer won't watch Marrow and the colony take his town: he
## hunts Eco through the hub and Solace, and when he catches her he puts a
## needle of Redline into her eye (cutter_scene.gd).
##   the high   HIGH_TIME s of it: her view runs red and pounds with her
##              heart, and she's faster (speed_scale)
##   the crash  when the high runs out: a scene, down on her knees, the colour
##              gone out of everything, shaking (cutter_scene.gd)
##   changes    the first time is only the high and the crash. Every time he
##              catches her after, Redline changes her body, a change a catch,
##              in CHANGES order, and they stack (redline_body.gd):
##     ears     cat ears on her head, on backwards, twitching
##     body     heavy: 15% more of her, all over, evenly; slower on her feet (speed_scale)
##     eyes     red, swirling: a red cast over her view
##     neck     her neck stretched, her head sitting too high
##     arms     her arms too long, her forearms stretched
##     legs     her shins long: taller, and she jumps higher (jump_scale)
##     posture  forced posture: her spine held straight as a wire, chin up; she
##              can't look down far (pitch_min)
##     tail     a thin red tail that sways
##     head     her head too small for her
## The changes only ever touch those parts. Doc Imani can reverse one, the last
## first, for DOC_COST scrap (doc_reverse); Biggie's toolkit takes the lot.
## Saved next to the vices save (path_for()).

const ContentRating := preload("res://scripts/radio/content_rating.gd")

const CHANGES := ["ears", "body", "eyes", "neck", "arms", "legs", "posture", "tail", "head"]
const NAMES := {"ears": "wrong ears", "body": "a heavy body", "eyes": "red eyes", "neck": "a stretched neck",
	"arms": "arms too long", "legs": "long legs", "posture": "forced posture", "tail": "a tail", "head": "a head too small"}
## What each change feels like, when it comes on.
const FEEL := {
	"ears": "Something pushes up through her hair. Two ears, a cat's, on backwards. They twitch at sounds behind her that aren't there.",
	"body": "All of her thickens at once, evenly, head to toe. More of her. She's heavy on her feet, and the floor knows it.",
	"eyes": "The red doesn't leave her eyes when the high does. It swirls in them now.",
	"neck": "Her neck creaks and stretches. Her head sits higher than it should. Doorframes look lower.",
	"arms": "Her forearms pull long, like taffy. Her hands hang to her knees.",
	"legs": "Her shins lengthen with a sound like a knuckle. She's taller. The ground's further away.",
	"posture": "Something pulls her spine straight as a wire. Chin up. She can't slouch, she can't bow her head, she can't look at her own feet for long.",
	"tail": "A thin red tail. It sways when she's nervous. She's always nervous now.",
	"head": "Her head shrinks. Just a little. Just enough that her hair doesn't sit right. Everyone notices.",
}
const HIGH_TIME := 60.0
const HIGH_SPEED := 1.15
## A heavy body: how much slower she moves; forced posture: how far down she can look (radians).
const BODY_SPEED := 0.92
const POSTURE_PITCH := -0.55
const LEGS_JUMP := 1.15
const DOC_COST := 60

static var changes: Array = []
static var catches := 0
## Seconds of the high left; the crash is owed when it reaches 0.
static var high_left := 0.0
static var crash_owed := false
static var save_path := "user://redline.cfg"


static func allowed() -> bool:
	return ContentRating.current() == "M"


static func path_for(vices_path: String) -> String:
	return vices_path.get_basename().trim_suffix("_vices") + "_redline.cfg"


static func has(change: String) -> bool:
	return allowed() and change in changes


## He caught her: the high starts, and from the second time a change comes on.
## Returns the new change ("" for none).
static func caught() -> String:
	catches += 1
	high_left = HIGH_TIME
	crash_owed = true
	var added := ""
	if catches > 1:
		for c in CHANGES:
			if not c in changes:
				changes.append(c)
				added = c
				break
	save()
	return added


## Each tick of the high; true when it's just run out (the crash is due).
static func tick(delta: float) -> bool:
	if high_left <= 0.0:
		return false
	high_left = maxf(high_left - delta, 0.0)
	return high_left <= 0.0


static func high() -> bool:
	return allowed() and high_left > 0.0


## The crash has played.
static func crashed() -> void:
	crash_owed = false
	save()


static func speed_scale() -> float:
	return (HIGH_SPEED if high() else 1.0) * (BODY_SPEED if has("body") else 1.0)


## How far down she can look (the player's head pitch), radians.
static func pitch_min() -> float:
	return POSTURE_PITCH if has("posture") else -1.55


static func jump_scale() -> float:
	return LEGS_JUMP if has("legs") else 1.0


## Doc Imani reverses the last change. Returns it ("" for none).
static func doc_reverse() -> String:
	if changes.is_empty():
		return ""
	var c: String = changes.pop_back()
	save()
	return c


static func reset() -> void:
	changes = []
	catches = 0
	high_left = 0.0
	crash_owed = false


static func open(path: String) -> void:
	save_path = path
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# saves from before the heavy body took the big hands' place
	changes = Array(cfg.get_value("redline", "changes", [])).map(func(c): return "body" if c == "hands" else c).filter(func(c): return c in CHANGES)
	catches = int(cfg.get_value("redline", "catches", 0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("redline", "changes", changes)
	cfg.set_value("redline", "catches", catches)
	cfg.save(save_path)
