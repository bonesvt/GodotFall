extends RefCounted
## Looping background beds for a level (forest wind and birds, the temple's
## drips and hum), from the CC0 recordings in res://assets/audio/ambience/.
## Each bed starts at a random point so layered loops don't line up.
##
##   Ambience.start(root, {"forest_day": -8.0, "forest_wind": -14.0})

const DIR := "res://assets/audio/ambience/"
const BUS_DB := 0.0


## Adds an "Ambience" node under `parent` playing every bed in `beds`
## (id -> volume in dB). Beds without a recording are skipped.
static func start(parent: Node, beds: Dictionary) -> Node:
	var root := Node.new()
	root.name = "Ambience"
	for id in beds:
		var path: String = DIR + id + ".ogg"
		if not ResourceLoader.exists(path):
			continue
		var stream := (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.name = id
		player.stream = stream
		player.volume_db = float(beds[id]) + BUS_DB
		player.ready.connect(func() -> void: player.play(randf() * stream.get_length()))
		root.add_child(player)
	parent.add_child(root)
	return root
