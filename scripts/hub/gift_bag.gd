extends RefCounted
## The gifts Eco is carrying, saved between sessions: bought at Lucky Lantern
## (gift_screen.gd) and given away in the hub (npc_talk.give_gift()).

const DEFAULT_PATH := "user://gifts.cfg"

var path := DEFAULT_PATH
var items := {}


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		items = cfg.get_value("bag", "items", {})


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bag", "items", items)
	cfg.save(path)


func count(id: String) -> int:
	return int(items.get(id, 0))


func add(id: String, n := 1) -> void:
	items[id] = count(id) + n
	save()


## Takes one `id` out of the bag; false if there isn't one.
func take(id: String) -> bool:
	if count(id) <= 0:
		return false
	items[id] = count(id) - 1
	if items[id] == 0:
		items.erase(id)
	save()
	return true


## The ids carried, in the order they went in.
func carried() -> Array:
	return items.keys()
