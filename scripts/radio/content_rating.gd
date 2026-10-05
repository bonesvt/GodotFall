extends RefCounted
## Content rating for dialogue: "T" (Teen) or "M" (Mature). Saved to
## user://settings.cfg. The radio and Eco's whispers pick their lines from
## this. E and AO were dropped (Bones, 2026-10-04); an old saved E reads as T
## and an old AO as M.

const PATH := "user://settings.cfg"
const DEFAULT := "M"
const RATINGS := ["T", "M"]
const OLD := {"E": "T", "AO": "M"}

static var _rating := ""


static func current() -> String:
	if _rating == "":
		var cfg := ConfigFile.new()
		_rating = DEFAULT
		if cfg.load(PATH) == OK:
			var saved: String = cfg.get_value("content", "rating", DEFAULT)
			saved = OLD.get(saved, saved)
			if saved in RATINGS:
				_rating = saved
	return _rating


static func set_rating(rating: String, save := true) -> void:
	if not rating in RATINGS:
		return
	_rating = rating
	if save:
		var cfg := ConfigFile.new()
		cfg.load(PATH)  # keep other sections
		cfg.set_value("content", "rating", rating)
		cfg.save(PATH)


## Steps to the next rating (wrapping) and returns it.
static func cycle() -> String:
	var i := RATINGS.find(current())
	set_rating(RATINGS[(i + 1) % RATINGS.size()])
	return _rating
