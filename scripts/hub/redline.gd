extends RefCounted
## Redline: Cutter's drug (cutter.gd), Mature only like the rest of the vices.
## Ophelia's old dealer won't watch Marrow and the colony take his town: he
## hunts Eco through the hub and Solace, and when he catches her he puts a
## needle of Redline into her eye, seen only through her eyes (cutter_scene.gd).
##   the high   HIGH_TIME s of it: her view runs red and pounds with her
##              heart, and she's faster (speed_scale)
##   the crash  when the high runs out: a scene, down on her knees, the colour
##              gone out of everything, shaking (cutter_scene.gd)
##   changes    the first time is only the high and the crash. Every time he
##              catches her after, Redline changes her body, a change a catch,
##              in CHANGES order, and they stack (redline_body.gd):
##     wiring   red veins up her arms and neck, pulsing with her heart
##     heavy    her whole body a size up, evenly (about 15% more of her): her
##              proportions as they were, slower, but she takes a hit better
##     legs     her shins long: taller, faster, and she jumps higher
##     posture  her muscles lock her upright: back straight, head level, a
##              jerky puppet walk; she can't crouch, and stiff arms reload slow
## Body horror, never anything else: only her veins, her size, her shins and
## her stance change, never her chest, hips or thighs on their own. Doc Imani
## can reverse one, the last first, for DOC_COST scrap (doc_reverse); Biggie's toolkit takes the lot.
## Saved next to the vices save (path_for()).

const ContentRating := preload("res://scripts/radio/content_rating.gd")

const CHANGES := ["wiring", "heavy", "legs", "posture"]
const NAMES := {"wiring": "the red wiring", "heavy": "a heavy body", "legs": "long legs", "posture": "the forced posture"}
## What each change feels like, when it comes on.
const FEEL := {
	"wiring": "Red lines come up under the skin of her arms and climb her neck. They pulse with her heart. They don't fade when the high does.",
	"heavy": "All of her gets heavier at once, every part the same. The floor takes her weight differently. Her boots feel smaller.",
	"legs": "Her shins lengthen with a sound like a knuckle. She's taller. The ground's further away.",
	"posture": "Her back pulls straight and locks. Her head comes level and stays there. Every step is somebody else's idea of walking.",
}
const HIGH_TIME := 60.0
const HIGH_SPEED := 1.15
const HEAVY_SPEED := 0.92
const HEAVY_DAMAGE := 0.9
const LEGS_SPEED := 1.08
const LEGS_JUMP := 1.15
const POSTURE_RELOAD := 1.3
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
	return (HIGH_SPEED if high() else 1.0) * (HEAVY_SPEED if has("heavy") else 1.0) * (LEGS_SPEED if has("legs") else 1.0)


static func reload_scale() -> float:
	return POSTURE_RELOAD if has("posture") else 1.0


static func damage_scale() -> float:
	return HEAVY_DAMAGE if has("heavy") else 1.0


## The forced posture won't let her crouch.
static func can_crouch() -> bool:
	return not has("posture")


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
	changes = Array(cfg.get_value("redline", "changes", [])).filter(func(c): return c in CHANGES)
	catches = int(cfg.get_value("redline", "catches", 0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("redline", "changes", changes)
	cfg.set_value("redline", "catches", catches)
	cfg.save(save_path)
