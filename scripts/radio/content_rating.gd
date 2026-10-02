extends RefCounted
## Content rating for dialogue: "E", "T", "M" or "AO". Saved to
## user://settings.cfg. The radio picks its line bank from this.

const PATH := "user://settings.cfg"
const DEFAULT := "M"
const RATINGS := ["E", "T", "M", "AO"]

static var _rating := ""


static func current() -> String:
	if _rating == "":
		var cfg := ConfigFile.new()
		_rating = DEFAULT
		if cfg.load(PATH) == OK:
			var saved: String = cfg.get_value("content", "rating", DEFAULT)
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
