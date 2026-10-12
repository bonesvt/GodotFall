extends Node
## What the clarity visor (hymn.gd) shows her on a run: the colony's grunts
## wearing the faces of the people she loves. Each grunt is drawn as Ophelia,
## Mom or Biggie (their hub models, hub_npc.gd), standing still in their idle
## and gliding where the grunt goes, and visor_screen.gd tags each one FRIEND.
## Hitting one tears the picture: the grunt shows through for a moment
## (TEAR s) before the friend closes back over it. Off the moment the visor's
## off, or in the hub.

const Hymn := preload("res://scripts/hub/hymn.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")

const FACES := ["ophelia", "mom", "biggie"]
const TEAR := 0.35

var rm: Node
## grunt -> the friend drawn over it
var _friends := {}


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "VisorFriends"


## Whether the visor is lying to her right now.
func on() -> bool:
	return Hymn.has("visor") and rm.in_run()


## The friends standing where grunts are (for the FRIEND tags): [[grunt, who], ...].
func disguised() -> Array:
	var out := []
	for g in _friends:
		if is_instance_valid(g) and is_instance_valid(_friends[g]) and _friends[g].visible:
			out.append([g, _friends[g].who])
	return out


func _process(delta: float) -> void:
	var lying := on()
	for g in _friends.keys():
		if not is_instance_valid(g) or g.get("dead") == true:
			_drop(g)
	if not lying:
		for g in _friends.keys():
			_drop(g)
		return
	for g in get_tree().get_nodes_in_group("enemies"):
		var model: Node3D = g.get("model")
		if model == null or g.get("dead") == true:
			continue
		if not _friends.has(g):
			_dress(g)
		var friend: Node3D = _friends[g]
		# a hit tears the picture for a moment
		var torn: bool = float(g.get("hurt_timer") if g.get("hurt_timer") != null else 0.0) > 0.0
		if torn:
			g.set_meta("visor_tear", TEAR)
		var tear: float = g.get_meta("visor_tear", 0.0)
		if tear > 0.0:
			g.set_meta("visor_tear", maxf(tear - delta, 0.0))
		model.visible = tear > 0.0
		friend.visible = tear <= 0.0


## Draws a friend over grunt `g`: the same one each time for the same grunt.
func _dress(g: Node3D) -> void:
	var who: String = FACES[absi(g.get_instance_id()) % FACES.size()]
	var f: Node3D = HubNpc.create(who, Vector3.ZERO, 0.0)
	f.name = "VisorFriend"
	g.add_child(f)
	f.set_process(false)  # no turning to face her: it stands as the grunt stands
	f.set_physics_process(false)
	if f.get("soft_body") != null and is_instance_valid(f.soft_body):
		f.soft_body.queue_free()  # nothing solid: it's only a picture
	if f.get("voice") != null and is_instance_valid(f.voice):
		f.voice.queue_free()
	_friends[g] = f


func _drop(g) -> void:
	var f = _friends.get(g)
	if is_instance_valid(f):
		f.queue_free()
	if is_instance_valid(g):
		var model = g.get("model")
		if model != null:
			model.visible = true
	_friends.erase(g)
