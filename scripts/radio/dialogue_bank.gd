extends RefCounted
## Loads dialogue from the plain-text files in res://dialogue/, so lines can
## be written and changed without touching code. One file per speaker and
## rating: dialogue/<speaker>/<rating>.txt (speakers: radio, eco).
##
##   # a note, ignored
##   [category]
##   one line (or radio exchange) per row
##
## AO has no files of its own unless someone writes them: a missing AO file
## falls back to M. Banks are cached; reload() re-reads every file (the HUD
## calls it when the rating key is pressed, so edits show up in game).

const DIR := "res://dialogue/"

static var _cache := {}  # "speaker/rating" -> {category: [lines]}


## {category: [lines]} for a speaker at a rating. Empty if there is no file.
static func bank(speaker: String, rating: String) -> Dictionary:
	var key := speaker + "/" + rating
	if not _cache.has(key):
		var path := "%s%s/%s.txt" % [DIR, speaker, rating]
		if not FileAccess.file_exists(path) and rating == "AO":
			_cache[key] = bank(speaker, "M")
		else:
			_cache[key] = parse(FileAccess.get_file_as_string(path))
	return _cache[key]


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
