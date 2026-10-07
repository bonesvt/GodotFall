extends Node3D
## Sounds around Eco that nothing on screen makes. On a run, the war going on
## over the hills: rifle bursts answering each other, a machine gun, shells
## landing, a titan walking, a dropship going over, a siren. At home, the
## quiet things: wind chimes, birds, a tree creaking, a far-off titan test
## firing at the colony's range.
##
## Each one plays from a random direction a long way off. Run sounds go
## through the "Distant" bus (default_bus_layout.tres: muffled, with a long
## echo, sent into Ambience so the Ambience slider covers it), so they read
## as far away and never as part of Eco's own fight. The positional loops
## (spot()) are the home's campfire, fire bowls, pond and plaza.
##
##   Soundscape.battle(zone_root, "city")
##   Soundscape.hub(zone_root, zone_info)

const SFX := preload("res://scripts/sfx.gd")
const AMBIENCE_DIR := "res://assets/audio/ambience/"
const DISTANT_BUS := "Distant"

## What can happen, how often (weight), and how loud (dB) before the bus.
const BATTLE := {
	"rifles": 6.0,      # a grunt squad's bursts, sometimes answered from elsewhere
	"firefight": 3.0,   # two sides trading shots, colony rifles against stolen guns
	"machine_gun": 2.0, # a long chattering burst
	"shells": 2.5,      # one to three explosions landing
	"titan": 1.2,       # a titan walking, then its gun
	"dropship": 1.0,    # engines passing overhead
	"siren": 0.6,       # a base alarm winding up
}
const HOME := {
	"chimes": 4.0,
	"birds": 5.0,
	"creak": 1.5,
	"far_range": 0.8,   # the colony's titan range, very far, nothing to worry about
}

## Seconds between happenings (min, max).
var gap := Vector2(5.0, 14.0)
var table: Dictionary = BATTLE
var bus := DISTANT_BUS
## Things about to play: [seconds from now, id, world position, dB, pitch].
var _queue: Array = []
var _next := 2.0
var _rng := RandomNumberGenerator.new()


## The war over the hills for a run zone. Busier in the city and at the
## colony's bases, thinner in the marsh.
static func battle(root: Node, biome := "") -> Node3D:
	var s := new()
	s.name = "Soundscape"
	s.table = BATTLE
	s.bus = DISTANT_BUS
	match biome:
		"city", "military":
			s.gap = Vector2(4.0, 11.0)
		"marsh":
			s.gap = Vector2(8.0, 18.0)
	root.add_child(s)
	return s


## The temple and its grounds: a positional loop for each spot builders put in
## info["sound_spots"] ({id, pos, db, size}), and the occasional chime,
## bird or creak, close and soft, on the Ambience bus.
static func hub(root: Node, info: Dictionary) -> Node3D:
	for spec: Dictionary in info.get("sound_spots", []):
		spot(root, spec["id"], spec["pos"], float(spec.get("db", -6.0)), float(spec.get("size", 4.0)))
	var s := new()
	s.name = "Soundscape"
	s.table = HOME
	s.bus = "Ambience"
	s.gap = Vector2(6.0, 16.0)
	root.add_child(s)
	return s


## A looping bed that comes from one place (the campfire, a fountain):
## loudest within `size` metres of it, fading out over a few times that.
static func spot(parent: Node, id: String, pos: Vector3, db := -6.0, size := 4.0) -> AudioStreamPlayer3D:
	var path := AMBIENCE_DIR + id + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream := (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	var p := AudioStreamPlayer3D.new()
	p.name = "Spot_" + id
	p.bus = "Ambience"
	p.stream = stream
	p.volume_db = db
	p.unit_size = size
	p.max_distance = size * 12.0
	p.attenuation_filter_cutoff_hz = 6000.0
	p.position = pos
	p.ready.connect(func() -> void: p.play(randf() * stream.get_length()))
	parent.add_child(p)
	return p


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(1.5, gap.x)


func _process(delta: float) -> void:
	for item: Array in _queue:
		item[0] -= delta
	while not _queue.is_empty() and float(_queue[0][0]) <= 0.0:
		var item: Array = _queue.pop_front()
		_play(item[1], item[2], item[3], item[4])
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(gap.x, gap.y)
		happen(_pick())


## Where the listener is (the camera), or this node when there's none.
func _ear() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else global_position


## A point `far` metres from the listener in a random direction, a little up.
func _somewhere(far: float) -> Vector3:
	var a := _rng.randf() * TAU
	return _ear() + Vector3(cos(a) * far, _rng.randf_range(2.0, 12.0), sin(a) * far)


func _pick() -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := _rng.randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return table.keys()[0]


## Lines up one happening (BATTLE or HOME key). Public so tests and the
## showcase can call one on demand.
func happen(kind: String) -> void:
	match kind:
		"rifles":
			var at := _somewhere(_rng.randf_range(60.0, 110.0))
			var t := _burst(0.0, at, "grunt_shot", _rng.randi_range(3, 7), Vector2(0.09, 0.15), -14.0)
			if _rng.randf() < 0.6:  # someone answers from over there
				var other := _somewhere(_rng.randf_range(70.0, 130.0))
				t = _burst(t + _rng.randf_range(0.3, 1.2), other, "grunt_shot", _rng.randi_range(2, 6), Vector2(0.1, 0.18), -16.0)
				if _rng.randf() < 0.5:
					_burst(t + _rng.randf_range(0.4, 1.0), at, "grunt_shot", _rng.randi_range(2, 5), Vector2(0.09, 0.15), -14.0)
		"firefight":
			var a := _somewhere(_rng.randf_range(70.0, 120.0))
			var b := a + Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30))
			var t := 0.0
			for i in _rng.randi_range(3, 6):
				var colony := i % 2 == 0
				t = _burst(t, a if colony else b, "grunt_shot" if colony else SFX.variant("far_shot"),
						_rng.randi_range(1, 4), Vector2(0.12, 0.3), -14.0 if colony else -12.0)
				t += _rng.randf_range(0.2, 0.9)
		"machine_gun":
			_burst(0.0, _somewhere(_rng.randf_range(80.0, 130.0)), "grunt_shot", _rng.randi_range(9, 16), Vector2(0.07, 0.08), -17.0, 0.85)
		"shells":
			var at := _somewhere(_rng.randf_range(90.0, 150.0))
			var t := 0.0
			for i in _rng.randi_range(1, 3):
				var id: String = ["explosion_far", "explosion_muffled", "far_shell"][_rng.randi() % 3]
				_add(t, id, at + Vector3(_rng.randf_range(-15, 15), 0, _rng.randf_range(-15, 15)), -8.0, SFX.vary(0.08))
				t += _rng.randf_range(0.6, 2.2)
		"titan":
			var at := _somewhere(_rng.randf_range(100.0, 150.0))
			var t := 0.0
			for i in _rng.randi_range(3, 5):
				_add(t, SFX.variant("titan_step"), at, -10.0, 0.8 * SFX.vary(0.05))
				t += _rng.randf_range(0.75, 0.95)
			if _rng.randf() < 0.6:
				_burst(t + 0.4, at, "xo16", _rng.randi_range(6, 12), Vector2(0.075, 0.085), -15.0, 0.9)
		"dropship":
			_flyby("far_dropship", -10.0)
		"siren":
			_add(0.0, "far_siren", _somewhere(_rng.randf_range(120.0, 180.0)), -14.0, SFX.vary(0.03))
		"chimes":
			var at := _somewhere(_rng.randf_range(8.0, 18.0))
			var t := 0.0
			for i in _rng.randi_range(2, 4):
				_add(t, SFX.variant("chime"), at, -24.0, SFX.vary(0.04))
				t += _rng.randf_range(0.35, 1.1)
		"birds":
			_add(0.0, SFX.variant("bird"), _somewhere(_rng.randf_range(10.0, 30.0)), -20.0, SFX.vary(0.06))
		"creak":
			_add(0.0, "tree_creak", _somewhere(_rng.randf_range(10.0, 25.0)), -24.0, SFX.vary(0.1))
		"far_range":
			var at := _somewhere(200.0)
			_add(0.0, "explosion_far", at, -26.0, 0.9)


## Queues `count` shots of `id` at `at`, spaced by `spacing` (min, max), and
## returns when the last one goes off.
func _burst(t: float, at: Vector3, id: String, count: int, spacing: Vector2, db: float, pitch := 1.0) -> float:
	for i in count:
		_add(t, id, at, db + _rng.randf_range(-1.5, 0.5), pitch * SFX.vary(0.05))
		if i < count - 1:
			t += _rng.randf_range(spacing.x, spacing.y)
	return t


func _add(t: float, id: String, at: Vector3, db: float, pitch: float) -> void:
	if id == "":
		return
	_queue.append([t, id, at, db, pitch])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _play(id: String, at: Vector3, db: float, pitch: float) -> AudioStreamPlayer3D:
	if not is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.stream = SFX.stream(id)
	p.volume_db = db
	p.pitch_scale = pitch
	# volume is set by hand; the 3D player only gives it a direction
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.panning_strength = 0.6
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Something passing overhead from one side of the sky to the other.
func _flyby(id: String, db: float) -> void:
	var a := _rng.randf() * TAU
	var across := Vector3(cos(a), 0, sin(a)) * 160.0
	var ear := _ear() + Vector3(_rng.randf_range(-40, 40), 60.0, _rng.randf_range(-40, 40))
	var p := _play(id, ear - across, db, SFX.vary(0.05))
	if p == null:
		return
	var length := p.stream.get_length() / p.pitch_scale
	var tw := p.create_tween()
	tw.tween_property(p, "global_position", ear + across, maxf(length, 1.0))
