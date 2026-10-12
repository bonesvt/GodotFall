extends RefCounted
## Loads dialogue from the plain-text files in res://dialogue/, so lines can
## be written and changed without touching code. One file per speaker:
## dialogue/<speaker>/M.txt (speakers: radio, eco, town; the game is rated M).
##
##   # a note, ignored
##   [category]
##   one line (or radio exchange) per row
##
## Banks are cached; reload() re-reads every file.

const DIR := "res://dialogue/"

static var _cache := {}  # speaker -> {category: [lines]}


## {category: [lines]} for a speaker. Empty if there is no file.
static func bank(speaker: String) -> Dictionary:
	if not _cache.has(speaker):
		_cache[speaker] = parse(FileAccess.get_file_as_string("%s%s/M.txt" % [DIR, speaker]))
	return _cache[speaker]


static func reload() -> void:
	_cache.clear()


static func parse(text: String) -> Dictionary:
	var out := {}
	var category := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			category = line.substr(1, line.length() - 2).strip_edges()
			if not out.has(category):
				out[category] = []
			continue
		if category == "":
			push_warning("Dialogue line outside any [category], skipped: %s" % line)
			continue
		out[category].append(line)
	# A category with every line deleted stays quiet rather than empty-handed.
	for c in out.keys():
		if out[c].is_empty():
			out.erase(c)
	return out
