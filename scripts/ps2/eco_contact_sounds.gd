extends Node
## Soft sounds for Eco's body contact (the jiggle collision in eco_model.gd):
## her suit brushing a wall she runs past or presses into, and the fabric
## swish of her own legs and arms touching. Kept to the suit and its fabric:
## a muffled pat against the wall, a rustle where she touches herself.
##
## It only listens. It reads her springs as eco_model.gd leaves them each
## frame (tip, prev, the "touch" radius each soft part has, and the "pairs"
## that touch each other) and never changes them, so it works with whichever
## version of her model is in the game and stays silent on one without body
## collision (no spring has a "touch" radius).
##
## player.gd adds one under the player; it finds the model in EcoBody (not
## the first-person arm under the camera, which never collides).

const SFX := preload("res://scripts/sfx.gd")

## The soft parts it listens to (spring groups); hair has a touch radius too
## but brushing it on a wall makes no sound worth playing.
const GROUPS := ["bust", "glute", "belly", "thigh", "arm", "calf"]
## How fast (m/s) a part has to be moving into a wall, or two parts into each
## other, for a sound; at FULL it plays at full volume.
const WALL_MIN := 0.25
const SELF_MIN := 0.35
const FULL := 2.5
## Seconds before the same part (or pair) can sound again.
const COOLDOWN := 0.18
## World contact is checked this often (seconds), not every physics frame.
const WALL_EVERY := 1.0 / 30.0

var model: Node3D
var _query: PhysicsShapeQueryParameters3D
var _balls := {}
## "w<bone>" (a part on the world) or "p<bone>_<bone>" (two parts) ->
## [touching at the last check, seconds since it last sounded]
var _state := {}
var _wall_clock := 0.0
var _look_again := 0.0
## How many sounds played (tests read it).
var played := {"wall": 0, "self": 0}


func _physics_process(delta: float) -> void:
	if model == null or not is_instance_valid(model):
		_look_again -= delta
		if _look_again <= 0.0:
			_look_again = 1.0
			model = find_model(get_parent().get_node_or_null("EcoBody"))
		return
	if not model.is_visible_in_tree() or model.get("jiggle_collide") != true:
		return
	var springs = model.get("_springs")
	if not springs is Array:
		return
	for k in _state:
		_state[k][1] += delta
	_wall_clock -= delta
	var check_walls := _wall_clock <= 0.0
	if check_walls:
		_wall_clock = WALL_EVERY
	for s: Dictionary in springs:
		if not s.get("ready", false) or not s.has("prev"):
			continue
		var group: String = s.get("base", {}).get("group", "")
		if not group in GROUPS:
			continue
		var tip: Vector3 = s["tip"]
		var vel: Vector3 = (tip - (s["prev"] as Vector3)) / maxf(delta, 1e-3)
		if check_walls and float(s.get("touch", 0.0)) > 0.0:
			_wall(s, tip, vel)
		for pair: Array in s.get("pairs", []):
			if not pair[1]:  # pairs held together by her pose (her glutes) always touch
				_self(s, pair[0], vel, delta)


## The first EcoModel-like node (one with springs) under `root`.
static func find_model(root: Node) -> Node3D:
	if root == null:
		return null
	for n in root.find_children("*", "Node3D", true, false):
		if n.get("_springs") is Array and n.has_method("nudge"):
			return n
	return null


func _wall(s: Dictionary, tip: Vector3, vel: Vector3) -> void:
	var r: float = float(s["touch"]) * 1.15
	var space := model.get_world_3d().direct_space_state
	if space == null:
		return
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.collide_with_areas = false
		var mine: Array[RID] = []
		var n: Node = model
		while n != null:
			if n is CollisionObject3D:
				mine.append((n as CollisionObject3D).get_rid())
			n = n.get_parent()
		_query.exclude = mine
	if not _balls.has(r):
		var ball := SphereShape3D.new()
		ball.radius = r
		_balls[r] = ball
	_query.shape = _balls[r]
	_query.transform = Transform3D(Basis(), tip)
	var hit := space.get_rest_info(_query)
	var key := "w%d" % int(s["bone"])
	var st: Array = _state.get(key, [false, 99.0])
	var touching := not hit.is_empty()
	if touching and not st[0] and st[1] >= COOLDOWN:
		var into := -vel.dot(hit["normal"] as Vector3)
		if into > WALL_MIN:
			st[1] = 0.0
			played["wall"] += 1
			SFX.play_at(self, tip, SFX.variant("contact_wall"), _volume(into, -18.0, -8.0), SFX.vary(0.08))
	st[0] = touching
	_state[key] = st


func _self(s: Dictionary, other: Dictionary, vel: Vector3, delta: float) -> void:
	if not other.get("ready", false) or not other.has("prev"):
		return
	var a: Vector3 = s["tip"]
	var b: Vector3 = other["tip"]
	var reach := float(s.get("touch", 0.0)) + float(other.get("touch", 0.0))
	if reach <= 0.0:
		return
	var gap := a.distance_to(b)
	var key := "p%d_%d" % [int(s["bone"]), int(other.get("bone", -1))]
	var st: Array = _state.get(key, [false, 99.0])
	var touching := gap < reach * 1.05
	if touching and not st[0] and st[1] >= COOLDOWN:
		var other_vel: Vector3 = (b - (other["prev"] as Vector3)) / maxf(delta, 1e-3)
		var closing := (vel - other_vel).dot((b - a).normalized()) if gap > 1e-4 else 0.0
		if closing > SELF_MIN:
			st[1] = 0.0
			played["self"] += 1
			SFX.play_at(self, (a + b) * 0.5, SFX.variant("contact_self"), _volume(closing, -26.0, -16.0), SFX.vary(0.1))
	st[0] = touching
	_state[key] = st


static func _volume(speed: float, quiet: float, loud: float) -> float:
	return lerpf(quiet, loud, clampf(speed / FULL, 0.0, 1.0))
