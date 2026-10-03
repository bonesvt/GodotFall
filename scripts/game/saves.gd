extends RefCounted
## Save slots. Each slot is a folder, user://saves/slot<N>/, holding the files
## the game already saves on its own, one set per slot:
##   armory.cfg       materials, guns, upgrades, titan parts, suit (armory.gd)
##   hub_npcs.cfg     who Eco has talked to and about what (npc_talk.gd)
##   titan_style.cfg  paint jobs (titan_style.gd)
##   progress.cfg     which tutorial hints were seen (tutorial.gd)
##   slot.cfg         this file's own bookkeeping: runs, wins, time played
## use(n) points all of those at slot n before the run scene loads; there is
## no "save" button because each of them already saves as it changes. A run in
## progress isn't saved: Continue puts you back in the temple.
##
## Saves from before slots existed (user://armory.cfg etc.) move into slot 1
## the first time the game starts with this code.

const SLOTS := 3
const FILES := ["armory.cfg", "hub_npcs.cfg", "titan_style.cfg"]

## Where the slots live, where the last slot played is noted, and where saves
## from before slots were (tests point these elsewhere).
static var dir := "user://saves/"
static var settings_path := "user://settings.cfg"
static var legacy_dir := "user://"

## The slot being played (0 = none picked yet).
static var active := 0
## Seconds played this session not yet written to slot.cfg.
static var _unsaved_time := 0.0


static func slot_dir(n: int) -> String:
	return dir + "slot%d/" % n


static func path(n: int, file: String) -> String:
	return slot_dir(n) + file


static func exists(n: int) -> bool:
	return FileAccess.file_exists(path(n, "slot.cfg"))


static func any_exist() -> bool:
	for n in range(1, SLOTS + 1):
		if exists(n):
			return true
	return false


## The slot Continue picks: the last one played, or the newest that exists.
static func last_slot() -> int:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	var n := int(cfg.get_value("saves", "last_slot", 0))
	if n >= 1 and n <= SLOTS and exists(n):
		return n
	var best := 0
	var best_time := -1
	for i in range(1, SLOTS + 1):
		var slot := info(i)
		if not slot.is_empty() and int(slot["last_played"]) > best_time:
			best = i
			best_time = int(slot["last_played"])
	return best


## {level, runs, wins, seconds, last_played (unix), created} or {} if empty.
static func info(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path(n, "slot.cfg")) != OK:
		return {}
	var armory = load("res://scripts/hub/armory.gd").open(path(n, "armory.cfg"))
	return {
		"level": armory.pilot_level(),
		"runs": int(cfg.get_value("slot", "runs", 0)),
		"wins": int(cfg.get_value("slot", "wins", 0)),
		"seconds": float(cfg.get_value("slot", "seconds", 0.0)),
		"last_played": int(cfg.get_value("slot", "last_played", 0)),
		"created": int(cfg.get_value("slot", "created", 0)),
	}


## Wipes slot n and starts it fresh.
static func new_game(n: int) -> void:
	erase(n)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot_dir(n)))
	var cfg := ConfigFile.new()
	var now := int(Time.get_unix_time_from_system())
	cfg.set_value("slot", "created", now)
	cfg.set_value("slot", "last_played", now)
	cfg.save(path(n, "slot.cfg"))


static func erase(n: int) -> void:
	var folder := ProjectSettings.globalize_path(slot_dir(n))
	if not DirAccess.dir_exists_absolute(folder):
		return
	for f in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(f))
	DirAccess.remove_absolute(folder)
	if active == n:
		active = 0


## Makes slot n the one the game reads and writes. The run manager picks up
## the armory and conversation paths from armory_path()/npc_path().
static func use(n: int) -> void:
	if not exists(n):
		new_game(n)
	active = n
	_unsaved_time = 0.0
	load("res://scripts/run/titan_style.gd").path = path(n, "titan_style.cfg")
	load("res://scripts/run/tutorial.gd").settings_path = path(n, "progress.cfg")
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("saves", "last_slot", n)
	cfg.save(settings_path)
	_touch({})


static func armory_path() -> String:
	return path(active, "armory.cfg")


static func npc_path() -> String:
	return path(active, "hub_npcs.cfg")


## Called by the run manager every frame while a slot is in play.
static func tick(delta: float) -> void:
	if active != 0:
		_unsaved_time += delta


## A run ended (won or not); also writes the time played.
static func record_run(won: bool) -> void:
	_touch({"runs": 1, "wins": 1 if won else 0})


## Writes the time played so far (quitting, back to the title).
static func flush() -> void:
	_touch({})


static func _touch(add: Dictionary) -> void:
	if active == 0:
		return
	var cfg := ConfigFile.new()
	cfg.load(path(active, "slot.cfg"))
	for key in add:
		cfg.set_value("slot", key, int(cfg.get_value("slot", key, 0)) + int(add[key]))
	cfg.set_value("slot", "seconds", float(cfg.get_value("slot", "seconds", 0.0)) + _unsaved_time)
	_unsaved_time = 0.0
	cfg.set_value("slot", "last_played", int(Time.get_unix_time_from_system()))
	cfg.save(path(active, "slot.cfg"))


## Moves a pre-slot save (files straight in user://) into slot 1, once.
static func migrate_legacy() -> void:
	if any_exist():
		return
	var found := false
	for f in FILES:
		if FileAccess.file_exists(legacy_dir + f):
			found = true
	if not found:
		return
	new_game(1)
	for f in FILES:
		if FileAccess.file_exists(legacy_dir + f):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(legacy_dir + f), ProjectSettings.globalize_path(path(1, f)))
	# Tutorial hints seen lived in settings.cfg [tutorial].
	var settings := ConfigFile.new()
	if settings.load(settings_path) == OK and settings.has_section("tutorial"):
		var progress := ConfigFile.new()
		for key in settings.get_section_keys("tutorial"):
			progress.set_value("tutorial", key, settings.get_value("tutorial", key))
		progress.save(path(1, "progress.cfg"))


## "3h 12m", "45m", "under a minute".
static func play_time_text(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 1:
		return "under a minute"
	if m < 60:
		return "%dm" % m
	return "%dh %02dm" % [m / 60, m % 60]
